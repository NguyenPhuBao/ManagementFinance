# Vì sao phần Danh mục phải thay đổi

> **Tài liệu này trả lời câu "tại sao", không phải câu "cái gì".**
> Mô tả trạng thái hiện tại nằm ở mục 4 và mục 12 của `PROJECT_CONTEXT.md`;
> quy tắc tóm tắt nằm ở `CLAUDE.md`. Ở đây chỉ ghi **lý do buộc phải thay đổi**,
> **bằng chứng đo được**, và **những phương án đã cân nhắc rồi loại bỏ** — đó là
> phần dễ mất nhất khi người khác đọc lại đoạn mã sau này.

**Ngày:** 2026-09-03 · **Phạm vi:** `src/Client-app` · **Commit:** `6b93ee8`, `0f8a820`, `d2cea8c`, `e7c7a44`, `103d381`

---

## 0. Tóm tắt cho người vội

Bốn thay đổi, mỗi cái do một lỗi **có thật** buộc phải làm — không có cái nào là dọn dẹp cho đẹp:

| Thay đổi | Lỗi buộc phải sửa |
|---|---|
| Quy tắc trùng tên: bỏ `classify` và nhóm cha khỏi khoá, tính cả danh mục mặc định | Bốn đường tạo được danh mục trùng tên; ba trong số đó client cho tạo còn PostgreSQL chặn, nên thao tác đẩy **thất bại im lặng** |
| Gom mọi phép so tên về **một định nghĩa duy nhất**, thêm bước gộp Unicode NFC | Ba biến thể so tên cùng tồn tại và đã lệch nhau; một trong số đó nằm trên đường đồng bộ và **không chuẩn hoá gì cả** |
| Bộ danh mục mặc định khớp đúng 13 mục của backend; 5 mục thừa thành danh mục cá nhân | Hai phía chỉ khớp **10/18** tên, khiến giao dịch dùng 8 mục còn lại **không bao giờ đẩy lên được** |
| ✅ *(backend làm xong 2026-09-07)* ID cố định cho danh mục mặc định | Nguyên nhân gốc của cả bốn lỗi 11.3–11.6 |

Kết quả: `flutter test` từ **144 → 180 test**, `flutter analyze` **29 issue, không error**.

---

## 1. Một nguyên nhân gốc, nhiều triệu chứng

Vùng danh mục là nơi nhiều lỗi nhất dự án. Không phải ngẫu nhiên — nó có hai đặc điểm mà cộng lại thì mọi sai sót đều **hỏng âm thầm**:

**(a) Tên đang bị dùng làm khoá nối giữa hai phía.** Backend sinh ID danh mục mặc định bằng `crypto.randomUUID()`, client thì seed id dạng `cat_food`. Hai bên không có khoá chung nào, nên `_resolveCategoryId` phải dò theo **tên**. Bất kỳ khác biệt nào về dấu, hoa/thường, dạng Unicode hay danh sách seed đều làm ánh xạ trượt.

**(b) Danh mục mặc định là hàng dùng chung.** Nó không thuộc về ai (`Create_by = 1` ở backend, `idaccount = 0` ở client), nên mọi quy tắc "theo từng người dùng" đều phải có một vế riêng cho nó.

Và điều khiến cả hai trở nên nguy hiểm: **`/sync/push` trả HTTP 200 kể cả khi mọi thao tác đều hỏng.** Thao tác thất bại chỉ nằm trong `results[]` với `status: "failed"`. Không có ngoại lệ nào được ném ra, không có gì hiện lên màn hình. Người dùng chỉ thấy dữ liệu "không lên server" mà không ai biết vì sao.

> Đây là lý do vì sao mọi thay đổi dưới đây đều đi kèm test tái hiện viết **trước**: lớp lỗi này không tự lộ ra khi dùng tay.

---

## 2. Thay đổi 1 — Quy tắc trùng tên

### Lỗi buộc phải sửa

Bộ kiểm tra cũ khoá theo `(idaccount, classify, parentId, tên)` và tách nhóm với danh mục con làm hai không gian tên riêng. PostgreSQL thì khoá theo `(Create_by, NameCategory, Classify)`. **Hai bên khác nhau**, nên có những trường hợp client cho tạo mà CSDL từ chối:

| Đường tạo trùng | Client | PostgreSQL | Hậu quả |
|---|---|---|---|
| Cùng tên, khác `classify` | cho qua | cho qua | trái quy tắc nghiệp vụ |
| Cùng tên, khác nhóm cha | **cho qua** | **chặn** | đẩy lên vỡ ràng buộc → `failed` im lặng |
| Nhóm trùng tên danh mục con | **cho qua** | **chặn** | như trên |
| Trùng tên danh mục mặc định | **cho qua** | cho qua | hai mục không phân biệt được trong danh sách chọn |

### Một lỗi nằm ngay trong chính lớp kiểm tra

Cả hai hàm kiểm tra đều quét trên kết quả của `getCategoryRows`, mà hàm đó **khử trùng lặp theo tên trước khi trả về**. Nếu bản sống sót là danh mục mặc định thì bộ lọc `!category.isDefault` lại loại nó ra — hàm báo "không trùng" dù tên đó đã tồn tại. Đây là **âm tính giả sinh ra từ chính công cụ đang dùng để kiểm tra**, không phải do thiếu điều kiện.

Vì vậy bản sửa không thêm tham số cho hàm cũ mà tách hẳn một truy vấn riêng (`CategoryDao.getNamesInUse`) không lọc `classify` và không khử trùng lặp.

### Vì sao chỉ xét trùng khi tên **thật sự đổi**

Quy tắc mới áp cho cả thao tác sửa. Nhưng bản client trước đây loại danh mục mặc định khỏi phép kiểm tra, nên máy người dùng có thể đang giữ một danh mục riêng trùng tên với danh mục mặc định. Chặn tuyệt đối sẽ khiến họ **không sửa nổi danh mục đó nữa** — kể cả chỉ đổi icon — và không có đường thoát nào ngoài việc đổi tên.

Đây là chủ ý, không phải lỗ hổng: tạo mới và đổi tên sang một tên đã bị chiếm vẫn bị chặn đầy đủ.

---

## 3. Thay đổi 2 — Một định nghĩa chuẩn hoá duy nhất

### Lỗi buộc phải sửa

Trong cùng một dự án có **ba biến thể so tên** cùng tồn tại:

| Nơi | Cách so |
|---|---|
| 6 khoá khử trùng lặp trong `CategoryDao` | `trim().toLowerCase()` |
| `_normalize` trong repository | `trim().toLowerCase()` + gom khoảng trắng |
| **`CategoryDao.getByName`** | **`t.name.equals(name)` — không chuẩn hoá gì** |

`getByName` là hàm `_resolveCategoryId` dùng để ánh xạ danh mục mặc định cục bộ sang UUID backend. Nó nằm **đúng trên đường đồng bộ**, và so phân biệt hoa/thường: lệch một chữ hoa là ánh xạ trượt, trả `null`, giao dịch bị hoãn đẩy **vĩnh viễn**. Đó chính là lớp lỗi 11.4 và 11.6, chỉ đợi một lần lệch tên là tái phát.

### Vì sao thêm bước gộp Unicode NFC

Đo bằng Dart, không phải suy đoán:

```
"Cà phê" dạng dựng sẵn (NFC) : 6 ký tự
"Cà phê" dạng tách dấu (NFD) : 8 ký tự
Bằng nhau sau khi trim + toLowerCase : false
```

Hai chuỗi **nhìn y hệt nhau** mà hệ thống coi là hai tên khác nhau — nên vẫn tạo trùng được, và không có cách nào nhìn ra bằng mắt. Tiếng Việt gõ từ bàn phím iOS, Android hay dán từ web đều có thể ra dạng khác nhau.

### Vì sao chốt đủ bốn bước ngay thay vì thêm dần

> **Nới lỏng về sau là miễn phí. Siết chặt về sau thì phải dọn dữ liệu.**

Nếu hôm nay chỉ so bằng chữ thường, mai muốn thêm gom khoảng trắng, thì những cặp `"Ca  phe"` / `"Ca phe"` đã tồn tại sẽ **vi phạm ràng buộc mới** — `CREATE UNIQUE INDEX` phía PostgreSQL sẽ thất bại cho tới khi có người đi sửa dữ liệu của người dùng thật. Ngược lại, bỏ bớt một bước thì không dòng nào vi phạm.

Chi phí làm bây giờ gần như bằng không: dữ liệu mặc định trên CSDL hiện **13/13 đều ở dạng NFC**.

---

## 4. Thay đổi 3 — Bộ danh mục mặc định

### Lỗi buộc phải sửa

Đối chiếu trực tiếp hai danh sách (client seed với truy vấn CSDL):

| | Số mục |
|---|---|
| Client seed | 18 |
| Backend | 13 |
| **Khớp tên** | **10** |
| Chỉ có ở client | 8 |
| Chỉ có ở backend | 3 |

Vì danh mục mặc định được ánh xạ **bằng tên**, 8 mục chỉ có ở client không tìm được bản UUID nào → `_resolveCategoryId` trả `null` → **mọi giao dịch dùng chúng bị hoãn đẩy vĩnh viễn**.

Trong 8 mục đó có `Chi khác` và `Thu khác` — thứ người dùng bấm khi không có mục nào hợp, tức **đường hay đi nhất lại đang là đường hỏng** — cùng `Trả nợ` và `Thu nợ`, một nửa nghiệp vụ vay nợ.

Đáng chú ý cặp `"Hoá đơn & Dịch vụ"` với `"Hóa đơn"`: khác cả hậu tố lẫn vị trí dấu (`Hoá` với `Hóa`). Chuẩn hoá chữ thường **không** cứu được — đó là hai chuỗi khác nhau thật.

### Vì sao 8 mục được chia làm hai nhóm

**Ba mục chỉ khác nhãn** (`Sức khoẻ`→`Y tế`, `Nhà ở`→`Nhà cửa`, `Hoá đơn & Dịch vụ`→`Hóa đơn`) — cùng một khái niệm. Đổi tên seed là xong, và bộ máy sẵn có tự ánh xạ chúng sang UUID khi pull.

**Năm mục backend không có** — không sửa được bằng cách đổi tên. Chỉ có ba lựa chọn: backend thêm vào, client xoá đi, hoặc chuyển chủ sở hữu.

### Vì sao chuyển thành danh mục cá nhân chứ không xoá

Xoá là cách hiểu đen của "bỏ phần thừa", nhưng nó hỏng ở hai chỗ:

1. **Xoá hàng seed khi giao dịch còn trỏ vào nó chính là lỗi 11.6** — lỗi mà dự án đã dính đúng một lần. Làm với 5 mục cùng lúc là tái hiện nó hàng loạt.
2. **Không có đích nào hợp lý để chuyển giao dịch sang.** Bộ 13 của backend không có mục "Khác" nào cả.

Chuyển chủ sở hữu giải quyết trọn vẹn: bộ **mặc định** của client còn đúng 13 mục khớp backend, không ai mất danh mục, và 5 mục kia **đẩy lên được** — vì danh mục người dùng thì có đồng bộ, còn danh mục mặc định thì không. Backend không phải thêm gì.

### Một chi tiết suýt làm hỏng cả cách sửa

Ban đầu định chuyển tại chỗ, giữ nguyên id `cat_other_chi` cho khỏi phải repoint. Nhưng `_resolveCategoryId` chỉ chấp nhận danh mục **không phải mặc định** khi id là **UUID hợp lệ**:

```dart
if (!localCategory.isDefault) {
  return _isValidUuidFormat(categoryId) ? categoryId : null;
}
```

Giữ id dạng slug thì giao dịch kẹt y như cũ, chỉ đổi nguyên nhân. Nên bắt buộc phải tạo UUID mới và repoint dữ liệu cũ — ở **cả ba bảng** có `categoryId` (transactions, budgets, bills), và **repoint trước, xoá mềm sau**.

---

## 5. Thay đổi 4 — ID cố định (✅ backend đã làm, 2026-09-07)

> ✅ **Đã xong 2026-09-07.** `seed.js` nay đóng băng **13 stable UUID**, hết
> `crypto.randomUUID()` cho danh mục; backend còn cấp thêm
> `GET /api/sync/default-categories`. Phần dưới giữ làm hồ sơ vì nó ghi *vì sao*
> tên danh mục từng bị dùng làm khoá nối.

`prisma/seed.js` **từng** sinh ID bằng `crypto.randomUUID()`, nên seed lại là ra bộ khác hoàn toàn. Đây là lý do tên bị dùng làm khoá nối ngay từ đầu, và là nguyên nhân gốc của bốn lỗi 11.3–11.6 cùng cả lớp mã vá víu quanh chúng.

Sau thay đổi 3 thì ánh xạ **đang chạy đúng** (13/13 khớp tên), nên việc này không còn gấp. Nhưng nó vẫn là thứ duy nhất khiến không phải làm lại lần nữa: chỉ cần ai đó sửa một nhãn cho đẹp hơn là ánh xạ đứt, **không test hay lỗi nào bắt được**; và reset CSDL vẫn phá mọi thứ.

Đề xuất chi tiết: `docs/superpowers/backend/DA-XONG/CATEGORY_STABLE_IDS.md`.

---

## 5b. Thay đổi 5 — bản sao riêng cho từng tài khoản (2026-09-07)

**Đảo lại thay đổi 3.** Thay đổi 3 đẩy năm danh mục *ra khỏi* bộ riêng để chúng
thành mặc định toàn cục; thay đổi 5 làm ngược: **toàn bộ** bộ mặc định được sao
chép *vào* từng tài khoản, còn hàng toàn cục lui về làm **khuôn** và không hiện
ra ở đâu nữa.

### Vì sao đổi hướng

Danh mục mặc định là hàng dùng chung, nên người dùng **không sửa, không đổi tên,
không xoá** được — mọi thao tác ấy sẽ đụng vào dữ liệu của mọi người. Bản sao
riêng gỡ được điều đó, và kéo theo hai thứ miễn phí:

- **`CategoryGroupMemberships` hết việc.** Bảng phụ ấy tồn tại chỉ vì không ghi
  `Idgroup` riêng cho từng tài khoản lên một hàng dùng chung được. Bản sao thì
  ghi thẳng vào `parentId` — cột đã có và đã đồng bộ. **G10 đóng mà backend
  không phải làm gì.**
- **Lỗ hổng phân quyền của `appendCategoryKeyword()` hẹp bán kính lại**: phản
  hồi phân loại không còn ghi vào hàng mọi người cùng đọc. Nó **chưa được vá** —
  xem `CATEGORY_KEYWORD_SYNC.md`.

### Chỗ dễ làm hỏng nhất

Luật tạo bản sao đếm **cả hàng đã xoá mềm**. Ba chữ ấy là khác biệt **duy nhất**
với `ensureMissing()` — thứ đã sinh ra G16. Bỏ chúng đi là danh mục người dùng
vừa xoá mọc lại ở mỗi lần mở app, và mỗi lần mọc lại là một thao tác đẩy hỏng
vĩnh viễn.

### Hai giới hạn đã biết

- **Bản sao chỉ đầy đủ khi bộ mặc định cục bộ đầy đủ.** Pull tăng dần theo
  `since`, nên một máy có thể chỉ biết một phần bộ mặc định của server. Đo được
  2026-09-07 (sáng): server có 18 hàng, máy kiểm thử tạo được 13 bản sao.
  ⚠️ **Chiều cùng ngày con số đổi:** đợt migration của backend thu bộ khuôn về
  đúng 13 stable UUID, **xoá mềm** 5 hàng `Chi khác`, `Thu khác`, `Làm thêm`,
  `Trả nợ`, `Thu nợ`. Server nay có **13 hàng sống + 5 hàng đã xoá mềm**; máy
  nào đã pull 5 hàng ấy sẽ nhận cờ xoá ở lượt pull sau.
- **Màu không theo được.** Bảng `category` không có cột màu, nên màu của bản sao
  chỉ sống trên máy đã tạo. Tài liệu xin: `CATEGORY_COLOUR_COLUMN.md`.

Thiết kế đầy đủ:
`docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.

---

## 6. Những phương án đã cân nhắc rồi loại bỏ

Ghi lại để người sau không mất công đề xuất lại:

| Phương án | Vì sao loại |
|---|---|
| Giữ bản mặc định hiện **song song** với bản sao (2026-09-07) | Người dùng thấy 36 dòng với 18 cặp trùng tên, và quy tắc trùng tên chặn họ đổi tên bất kỳ bản nào |
| Đếm bản sao **theo tài khoản** thay vì theo từng danh mục (2026-09-07) | Tài khoản đã có sẵn danh mục riêng sẽ bị từ chối seed, trong khi bản mặc định của nó đã bị ẩn — nó còn lại đúng vài danh mục |
| Đếm bản sao **bỏ qua hàng đã xoá mềm** (2026-09-07) | Chính là `ensureMissing()` cũ, tức tái hiện nguyên vẹn G16 |
| Xoá hẳn 5 mục backend không có | Tái hiện lỗi 11.6 hàng loạt; mất cả hai mục "Khác" và một nửa nghiệp vụ vay nợ; giao dịch cũ không có đích để chuyển sang |
| Chuyển 5 mục tại chỗ, giữ id `cat_*` | `_resolveCategoryId` từ chối danh mục người dùng có id không phải UUID → giao dịch vẫn kẹt |
| Giữ mỗi nhóm là một không gian tên riêng | PostgreSQL không có `Idgroup` trong unique index nên vẫn chặn — client cho tạo rồi đẩy lên mới vỡ |
| Chỉ chuẩn hoá chữ thường, chưa cần NFC | Siết chặt về sau đắt hơn hẳn: dữ liệu đang tồn tại sẽ vi phạm và `CREATE UNIQUE INDEX` thất bại |
| Chặn tuyệt đối cả khi sửa | Người dùng có dữ liệu cũ sẽ không sửa nổi danh mục đó nữa, kể cả chỉ đổi icon |
| Sửa `getCategoryRows` cho dùng chung | Hàm đó khử trùng lặp theo tên — sửa nó sẽ đổi hành vi hiển thị ở nhiều nơi khác; tách truy vấn riêng an toàn hơn |
| Đổi tên 3 mục ngay, làm ID cố định sau | Hai lần migration trên máy người dùng cho cùng một vấn đề |

---

## 7. Nguyên tắc rút ra

Bốn điều lặp lại trong suốt đợt thay đổi này, đáng nhớ cho lần sau:

1. **Nới lỏng về sau là miễn phí, siết chặt về sau thì phải dọn dữ liệu.** Quyết định mức chặt của một ràng buộc thì chọn chặt ngay từ đầu.
2. **Repoint trước, xoá sau.** Mọi lần đụng tới danh mục mà có dữ liệu trỏ vào nó. Đây là bài học của 11.6 và nó lặp lại nguyên vẹn ở thay đổi 3.
3. **Một phép so, một định nghĩa.** Ba biến thể so tên trong cùng dự án đã lệch nhau, và cái lệch nhất lại nằm đúng trên đường đồng bộ.
4. **Đo trước, kết luận sau.** Trong đợt này có hai lần test **xanh giả**: ký tự Unicode dạng tách dấu bị công cụ ghi file âm thầm gộp về NFC, nên hai chuỗi "khác nhau" hoá ra bằng nhau. Chỉ khi dựng fixture bằng escape code point và khẳng định cả độ dài chuỗi thì test mới thật sự canh được thứ nó nói là đang canh.

Cũng trong đợt này, ba lần test đỏ hoá ra là **fixture sai chứ không phải mã sai** — do đặt tên trùng danh mục seed sẵn, hoặc thiếu ví nên vỡ khoá ngoại. Đọc thông báo lỗi trước khi sửa mã.

---

## 8. Cái gì còn phụ thuộc backend

Quy tắc hiện **chỉ được client thi hành**. Admin-web và mọi đường ghi khác vẫn tạo được dữ liệu vi phạm, và trường hợp "xoá rồi tạo lại cùng tên" vẫn bị CSDL từ chối khi đẩy lên — **hỏng âm thầm**.

| Tài liệu trong `docs/superpowers/backend/` | Nội dung |
|---|---|
| `CATEGORY_NAME_UNIQUENESS.md` | Thay hai unique index; vế "người dùng với mặc định" cần trigger vì không viết được thành index |
| `CATEGORY_STABLE_IDS.md` | Đóng băng 13 UUID đang có |
| `CATEGORY_KEYWORD_SYNC.md` | Từ khoá phân loại không đồng bộ, kèm một lỗ hổng phân quyền |
| `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` | Việc gán danh mục mặc định vào nhóm chỉ tồn tại trên một máy |

---

## 9. Kiểm chứng

```bash
cd src/Client-app
flutter test test/features/category/ test/core/category/ test/core/database/category_dao_test.dart
flutter analyze
```

Mức nền sau đợt thay đổi: **180/180 test pass**, **29 issue, không error**.

Riêng phần danh mục có **74 test** trải trên 5 file, trong đó nhiều test ghi rõ trong `reason:` là nó đang canh chừng lỗi nào — vì lớp lỗi này không tự lộ ra khi dùng tay.
