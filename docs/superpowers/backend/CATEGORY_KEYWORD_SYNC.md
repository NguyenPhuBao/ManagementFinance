# Từ khoá phân loại danh mục: hai kho dữ liệu độc lập, không có đường nối

> ## ⚠️ CẬP NHẬT 2026-09-03 — lỗ hổng phân quyền VẪN CÒN NGUYÊN
>
> `classify.repository.js` có được sửa trong đợt vừa rồi, nhưng **chỉ đổi ký tự
> tách từ khoá** (`split(/[,;]/)` thành `split(',')`). Phần phân quyền ở mục 4
> **chưa đụng tới**:
>
> - `recordFeedback()` vẫn chỉ chuyền `idcategory` xuống repository.
> - `appendCategoryKeyword()` vẫn `select: { idcategory: true, keyword: true }`
>   — **không đọc `create_by`, không đối chiếu chủ sở hữu**.
>
> Nghĩa là hai hệ quả ở mục 4 còn nguyên: bất kỳ tài khoản đã đăng nhập nào biết
> `idcategory` của người khác vẫn ghi được từ khoá vào danh mục của họ, và phản
> hồi trên một danh mục mặc định vẫn ghi vào hàng mà **mọi người cùng đọc**.
>
> Bản vá ở mục 4 chỉ vài dòng và **độc lập hoàn toàn** với phần đồng bộ ở mục 5 —
> làm được ngay mà không cần quyết định gì về mô hình dữ liệu.
>
> Phần đồng bộ từ khoá (mục 5) cũng chưa bắt đầu: `UPSERT_MAP` vẫn đúng 6 entity.

**Người nhận:** đội Backend
**Trạng thái:** cần backend quyết định. Phía Client-app **không thể tự nối** (lý do ở mục 3).
**Mức độ:** không gây lỗi hiện tại, nhưng làm tính năng AI tự học **không nhận được dữ liệu từ client**, và có một lỗ hổng phân quyền đi kèm (mục 4).
**Ngày khảo sát:** 2026-09-03 · **Kiểm lại cùng ngày** sau khi gộp `main` tới `0e8f0b2`.

---

## 1. Tóm tắt

Từ khoá dùng để phân loại giao dịch đang tồn tại ở **hai nơi hoàn toàn tách biệt**, mỗi
nơi có một bộ phân loại riêng, và **không có đường đồng bộ nào giữa chúng**:

| | Client-app | Backend |
|---|---|---|
| Nơi lưu | bảng `CategoryKeywords` (`categories_table.dart:49`) | cột `category.Keyword` (`schema.prisma:113`) |
| Hình dạng | **mỗi từ khoá một dòng**, có `idaccount` | **một chuỗi** nối bằng `', '` trên hàng category |
| Phạm vi | theo **từng người dùng** (`UNIQUE(idaccount, categoryId, normalizedKeyword)`) | theo **hàng category**, không có khái niệm người dùng |
| Ai ghi | `CategoryDao.replaceKeywords()` (`category_dao.dart:130`) | `appendCategoryKeyword()` (`classify.repository.js:58`) |
| Ai đọc | `CategorySuggestionEngine` (`category_suggestion_engine.dart:4`) | `keyword.matcher.js`, `nlp.matcher.js` |
| Chuẩn hoá | `trim().toLowerCase()` + gom khoảng trắng (`category_dao.dart:247`) | `preprocess()` rồi `trim().toLowerCase()` |

Hệ quả: người dùng dạy cho app một từ khoá trên điện thoại thì **backend không bao giờ
biết**, và ngược lại. Tính năng tự học qua `POST /api/ai/classify/feedback` chỉ nhận được
dữ liệu từ những nơi gọi thẳng endpoint đó.

## 2. Đã kiểm chứng những gì

Đọc mã nguồn hai phía, không suy đoán:

- `SyncEntityType` (`sync_models.dart:11`) chỉ có **6 giá trị**: `wallet, transaction,
  category, budget, bill, goal`. **Không** có từ khoá.
- Tìm toàn bộ `src/Client-app/lib/core/sync/`: **không một tham chiếu nào** tới `keyword`.
- Tìm toàn bộ `src/Client-app/lib/`: client **không gọi** bất kỳ endpoint nào dưới
  `/api/ai/classify/*`. Nó dùng bộ gợi ý cục bộ `CategorySuggestionEngine`.
- Backend đọc `category.Keyword` bằng `.split(/[,;]/)` và ghi bằng `.join(', ')` — nội bộ
  nhất quán. (Thay đổi `;` → `,` ở `nlp.matcher.js` trong commit `c9f4f45` chỉ là đưa
  matcher về khớp với thứ repository thật sự ghi ra; **không** phá vỡ gì.)

## 3. Vì sao client không tự nối được

Giống hệt tình trạng đã mô tả ở `CATEGORY_GROUP_MEMBERSHIP_SYNC.md`:

1. Không có `SyncEntityType` cho từ khoá, và thêm một entity lạ vào batch sẽ nhận
   `Unknown entity` rồi kẹt vĩnh viễn (`sync.service.js`, `UPSERT_MAP` chỉ có 6 entity).
2. Quan trọng hơn: **cột `Keyword` nằm trên hàng `category` dùng chung**. Với danh mục
   mặc định (`Create_by = 1`), ghi từ khoá của một người vào đó sẽ **đổi cách phân loại
   cho toàn bộ người dùng**. Đây đúng là vấn đề mô hình dữ liệu mà client không có quyền
   quyết định.

## 4. Một vấn đề phân quyền phát hiện kèm theo — **nên xem trước**

`recordFeedback()` (`classify.service.js:177`) **nhận** `idaccount` nhưng chỉ dùng để ghi
log; nó gọi thẳng:

```js
const updatedCategory = await classifyRepository.appendCategoryKeyword(idcategory, keywordToLearn);
```

Còn `appendCategoryKeyword()` (`classify.repository.js:58`) tra danh mục **chỉ bằng
`idcategory`**, không kiểm tra `Create_by`. Hệ quả có hai mức:

1. **Nhiễu dữ liệu dùng chung.** Người dùng gửi phản hồi trên một danh mục mặc định thì từ
   khoá riêng của họ được ghi vào hàng mà **mọi người cùng đọc**.
2. **Ghi được sang danh mục của người khác.** Một tài khoản đã đăng nhập chỉ cần biết
   `idcategory` của người khác là ghi được từ khoá vào đó, vì không có bước đối chiếu chủ
   sở hữu nào.

Cách vá tối thiểu, không cần đổi mô hình dữ liệu:

```js
// trong appendCategoryKeyword, hoặc ngay trong recordFeedback trước khi gọi
const category = await prisma.category.findUnique({
  where: { idcategory },
  select: { idcategory: true, keyword: true, create_by: true, is_default: true },
});
if (!category) throw ...404...;
if (category.create_by !== idaccount) {
  // Danh mục mặc định hoặc của người khác — KHÔNG ghi vào hàng dùng chung.
  throw Object.assign(new Error('Khong the hoc tu khoa tren danh muc dung chung'), { statusCode: 403 });
}
```

Việc này độc lập với chuyện đồng bộ và **đáng làm dù chọn phương án nào ở mục 5**.

## 5. Hai lựa chọn cho việc đồng bộ

### Lựa chọn A — Bảng từ khoá theo người dùng · **khuyến nghị**

Tách từ khoá ra khỏi hàng `category`, đúng hình dạng client đang dùng:

```sql
CREATE TABLE "category_keyword" (
  "Idkeyword"   VARCHAR(36) PRIMARY KEY,
  "Idaccount"   INT         NOT NULL,
  "Idcategory"  VARCHAR(36) NOT NULL,
  "Keyword"     VARCHAR(200) NOT NULL,
  "Normalized"  VARCHAR(200) NOT NULL,
  "Update_at"   TIMESTAMP   NOT NULL,
  "Delete_at"   TIMESTAMP   NULL,
  CONSTRAINT "fk_keyword_account"  FOREIGN KEY ("Idaccount")  REFERENCES "account"("Idaccount"),
  CONSTRAINT "fk_keyword_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory"),
  CONSTRAINT "uq_keyword_owner_category_norm" UNIQUE ("Idaccount", "Idcategory", "Normalized")
);
```

Rồi bổ sung phía sync, **đặt sau `category` trong `ENTITY_PRIORITY`** (ví dụ `15`) vì nó
tham chiếu tới hàng category:

1. `UPSERT_MAP`: `categoryKeyword: 'upsertCategoryKeyword'`
2. `PULL_MAP` + `getCategoryKeywordsByAccount(idaccount, since)`
3. `mapEntityFields()`: `categoryId → idcategory`, `keyword → keyword`,
   `normalizedKeyword → normalized`, `idaccount → idaccount`
4. Kiểm tra quyền sở hữu như các entity khác: `payload.idaccount === token.idaccount`
5. Bộ phân loại đọc **hợp** của hai nguồn: `category.Keyword` (từ khoá chung do admin đặt)
   và `category_keyword` của chính người dùng đó.

Giữ nguyên `category.Keyword` cho từ khoá dùng chung, nên không phải chuyển đổi dữ liệu cũ.

> ⚠️ **Chuẩn hoá phải khớp hai phía.** Client dùng
> `trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')`. Nếu backend chuẩn hoá khác đi thì
> `UNIQUE(..., Normalized)` sẽ cho lọt bản trùng, và hỏng **âm thầm** đúng theo khuôn mẫu
> quen thuộc của dự án này. Chốt một định nghĩa và ghi vào tài liệu.

### Lựa chọn B — Giữ nguyên, coi từ khoá là dữ liệu chỉ có ở từng nơi

Chấp nhận rằng gợi ý trên app và phân loại phía server học riêng. Chi phí bằng không, nhưng
phải **ghi rõ vào tài liệu API** để người sau không tưởng nhầm là bug, và vẫn nên vá phần
phân quyền ở mục 4.

## 6. Phía Client-app cần làm gì sau khi backend xong (nếu chọn A)

1. Thêm `categoryKeyword` vào `SyncEntityType` (`sync_models.dart`).
2. Thêm nhánh gom/đẩy trong `_collectPendingOps` — xếp **sau** category trong batch.
3. Thêm nhánh đọc trong `_pullFromBackend`, dùng `insertAllOnConflictUpdate`
   (**không** `insertOrReplace` — xem mục 11.8 của `PROJECT_CONTEXT.md`).
4. Bảng `CategoryKeywords` hiện **chưa có** các cột đồng bộ (`syncStatus`, `updatedAt` đã
   có nhưng không có `syncStatus`) — cần bump `schemaVersion` (hiện là 9) và bổ sung.
5. **Cập nhật `test/core/sync/sync_payload_contract_test.dart` cùng lúc.** Tên trường đi qua
   ba nơi định nghĩa độc lập và một tên sai **không gây lỗi, chỉ lặng lẽ bị bỏ qua**.

## 7. Ghi chú

Toàn bộ khảo sát chỉ **đọc** mã nguồn. **Không có dòng mã backend nào bị thay đổi.**

Xem thêm `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` (cùng thư mục) — cùng một khuôn mẫu: một quan
hệ thuộc về từng người dùng nhưng lại được gắn vào hàng danh mục dùng chung.
