# Màu danh mục: client gửi lên mỗi lần đồng bộ, backend không có chỗ để nhận

> **Xin đúng một cột.** Không đổi API, không đổi hợp đồng đồng bộ, không cần
> client sửa gì. Chi phí: một migration cộng hai dòng.

## 1. Triệu chứng

Người dùng chọn màu cho một danh mục trên điện thoại. Đăng nhập máy khác — hoặc
cài lại app trên chính máy ấy — thì màu **biến mất**, quay về màu mặc định.

Không có lỗi nào báo ra. Không có dòng log nào. Danh mục vẫn đúng tên, đúng
biểu tượng, đúng loại; chỉ riêng màu là sai.

## 2. Nguyên nhân, đo được ngày 2026-09-07

Bảng `category` có **đúng 12 cột**, và không cột nào dành cho màu:

```
Idcategory, Create_by, NameCategory, Classify, Is_default, Is_group,
Idgroup, Keyword, Icon, Create_at, Update_at, Delete_at
```

Trong khi đó client **vẫn gửi màu lên ở mỗi lần đẩy**. Payload danh mục
(`sync_engine.dart:950` và `:1025`) có khoá `colour`:

```dart
payload: {
  'id': validId,
  'name': c.name,
  'namecategory': c.name,
  'classify': validClassify,
  'icon': c.icon,
  'colour': c.colour,      // ← gửi đi mỗi lần, không ai nhận
  'is_default': c.isDefault,
  …
}
```

`SyncPayloadNormalizer.categoryForPush()` **không** đổi tên khoá này — phép đổi
`colour` → `color` chỉ tồn tại ở `walletForPush()`. Nên thứ tới `/sync/push` là
đúng chữ `colour`.

Phía backend, `mapEntityFields('category')` (`sync.repository.js:102–113`) không
chạm tới `colour`, và cả hai nhánh của `upsertCategory` đều không liệt kê nó:

```js
// nhánh tạo — sync.repository.js:124
return prisma.category.create({
  data: {
    idcategory, create_by, name_category, classify,
    is_default, is_group, idgroup, keyword, icon, update_at,
    // không có màu
  },
});
```

Trường thừa trong payload bị Prisma bỏ qua lặng lẽ. **Đây đúng là kiểu hỏng mà
quy tắc 4 của `CLAUDE.md` mô tả: tên trường không khớp thì im lặng, không báo
lỗi.** Lần này còn khó thấy hơn, vì tên trường không sai — chỉ là không có chỗ
nào để ghi.

Chiều **kéo về** cũng đã sẵn sàng chờ: `sync_engine.dart:555` đọc
`c['colour']`, và vì server không bao giờ trả nó nên giá trị luôn `null`.

## 3. Vì sao đáng làm

Ba lý do, xếp theo mức thuyết phục:

1. **Đây là dữ liệu người dùng tự nhập, và nó đang mất.** Không phải giá trị
   suy ra được, không phải cache. Người dùng chọn màu là một hành động có chủ ý.
2. **Sắp có nhiều màu hơn hẳn.** Client đang chuyển bộ danh mục mặc định thành
   **bản sao riêng của từng tài khoản** (spec
   `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`).
   Sau thay đổi ấy, mỗi tài khoản có 18 danh mục **của riêng mình** và sửa được
   màu của cả 18 — nên bán kính của lỗi này rộng ra gấp nhiều lần.
3. **Client không sửa được.** Không có cột thì không có chỗ ghi. Đây là một
   trong số ít việc mà client đã làm xong phần của mình từ lâu và chỉ đang chờ.

## 4. Đề xuất

### 4.1 Migration

```sql
ALTER TABLE category ADD COLUMN "Color" VARCHAR(9);
```

`VARCHAR(9)` chứ không phải `VARCHAR(7)`: client lưu dạng `#RRGGBB` nhưng
`Color(int)` của Flutter mang cả kênh alpha, và một bản sau muốn ghi `#AARRGGBB`
thì không phải migrate lần nữa. **Nullable, không đặt `DEFAULT`** — hàng cũ để
`NULL` nghĩa là "chưa biết", và client đã có sẵn màu dự phòng cho trường hợp ấy
(`budgetColorFrom(hex, fallback: …)`).

⚠️ **Đừng đặt `DEFAULT '#XXXXXX'`.** Nó biến 18 danh mục mặc định và mọi hàng cũ
thành "người dùng đã chọn màu này", và client không phân biệt được nữa. Cùng loại
sai lầm với `@default(0)` của `Threshold_Warning_Percent` — việc D trong
`2026-09-04-backend-idempotent-delete.md`.

### 4.2 Prisma schema

```prisma
model category {
  …
  icon          String?   @db.VarChar(20) @map("Icon")
  color         String?   @db.VarChar(9)  @map("Color")   // ← thêm
  …
}
```

### 4.3 `sync.repository.js` — hai dòng

Trong `mapEntityFields`, nhánh `case 'category'`, thêm phép đổi tên vì client
dùng chính tả Anh-Anh:

```js
if (m.colour !== undefined) { m.color = m.colour; delete m.colour; }
```

Rồi liệt kê nó ở **cả hai** nhánh của `upsertCategory`:

```js
// nhánh tạo
color: mapped.color || null,

// nhánh cập nhật
color: mapped.color !== undefined ? mapped.color : existing.color,
```

Đúng khuôn `icon` đang dùng ngay bên cạnh, kể cả cách nhánh cập nhật giữ giá trị
cũ khi client không gửi gì.

### 4.4 Đường trả về

Chỗ nào đang trả `icon` cho client thì trả thêm `color`. Client đọc khoá
`colour` **hoặc** `color` ở nhánh pull sẽ an toàn cho cả hai chính tả; nếu chỉ
trả một dạng thì trả `color` cho khớp tên cột, và **báo lại** để client nới nhánh
đọc — hiện `sync_engine.dart:555` chỉ đọc `c['colour']`.

> Đây là điểm **duy nhất** cần thống nhất trước khi làm. Mọi phần còn lại không
> đụng tới client.

## 5. Cái này KHÔNG giải quyết

- **Màu của nhóm danh mục** đi cùng đường, nhưng việc gán danh mục mặc định vào
  nhóm còn chặn ở `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` (G10). Cột màu không gỡ
  được việc ấy.
- **Từ khoá phân loại** là việc khác và **không** cần backend làm gì: cột
  `Keyword` đã có và `/sync/push` đã nhận. Xem `CATEGORY_KEYWORD_SYNC.md` cho
  phần còn lại (lỗ hổng phân quyền ở `POST /api/ai/classify/feedback`).

## 6. Cách kiểm sau khi làm

```bash
# 1. Từ client: đổi màu một danh mục, chờ một chu kỳ đồng bộ.
# 2. Truy vấn đọc:
cd src/Backend && node -e "const {PrismaClient}=require('@prisma/client');
const p=new PrismaClient();(async()=>{
  console.log(await p.\$queryRawUnsafe('SELECT \"NameCategory\",\"Color\" FROM category WHERE \"Create_by\"=10 AND \"Color\" IS NOT NULL'));
  await p.\$disconnect();})();"
```

Chờ: hàng vừa đổi có đúng mã màu client gửi.

Phép kiểm thật sự là **vòng đẩy–kéo**: đổi màu, đẩy lên, xoá CSDL cục bộ, pull
lại, màu vẫn còn. Kiểm mỗi ở CSDL không chứng minh được chiều trả về đã nối.

## 7. Bối cảnh

Phát hiện ngày 2026-09-07 trong lúc dựng spec đưa danh mục mặc định thành bản
sao riêng của từng tài khoản. Không phải lỗi mới — nó đã im lặng như vậy từ khi
có đường đồng bộ danh mục, và không ai báo vì màu sai trông giống một lựa chọn
thiết kế hơn là một lỗi.
