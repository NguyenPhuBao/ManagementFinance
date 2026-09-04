# Từ khoá phân loại danh mục: hai kho dữ liệu độc lập, không có đường nối

> ## ⚠️ CẬP NHẬT 2026-09-04 — lỗ hổng phân quyền VẪN CÒN NGUYÊN, và nay **nguy hiểm hơn trước**
>
> Kiểm lại tại `fcf7659`, sau khi gộp `origin/main` `dfda862` (mô-đun OCR F013 và
> bộ phân loại hai cấp F012). Phần phân quyền ở mục 4 **vẫn chưa đụng tới**:
>
> - `recordFeedback()` (`classify.service.js:196`) vẫn chỉ chuyền `idcategory`
>   xuống repository.
> - `appendCategoryKeyword()` (`classify.repository.js:64`) vẫn
>   `select: { idcategory: true, keyword: true }` — **không đọc `create_by`,
>   không đối chiếu chủ sở hữu**.
>
> Nghĩa là hai hệ quả ở mục 4 còn nguyên: bất kỳ tài khoản đã đăng nhập nào biết
> `idcategory` của người khác vẫn ghi được từ khoá vào danh mục của họ, và phản
> hồi trên một danh mục mặc định vẫn ghi vào hàng mà **mọi người cùng đọc**.
>
> **Mức nghiêm trọng đã tăng.** Khi tài liệu này viết lần đầu, từ khoá phía
> backend là dữ liệu gần như nằm im: không có tính năng nào đọc tới nó trên
> đường chạy thật. Nay `keyword.matcher` là **Tầng 1** của bộ phân loại, và bộ
> phân loại nằm ngay trên đường quét hoá đơn:
> `ocr.service.js:123` → `classifyExtractedReceipt` → `classifySingle` →
> `matchKeywords` (`classify.service.js:48`). Một từ khoá ghi bậy vào danh mục
> mặc định giờ **làm sai kết quả phân loại hoá đơn của mọi người dùng**.
>
> Bề mặt cũng rộng ra: từ một endpoint `/feedback` thành năm —
> `/api/ai/classify/{single,batch,feedback,transaction}` và `/api/ai/ocr/parse`.
> Bốn cái sau chỉ **đọc** từ khoá, nhưng chúng là nơi hậu quả biểu hiện.
>
> Bản vá ở mục 4 chỉ vài dòng và **độc lập hoàn toàn** với phần đồng bộ ở mục 5 —
> làm được ngay mà không cần quyết định gì về mô hình dữ liệu.
>
> Phần đồng bộ từ khoá (mục 5) cũng chưa bắt đầu: `UPSERT_MAP`
> (`sync.service.js:7-14`) vẫn đúng 6 entity.
>
> Xem thêm `2026-09-04-ocr-classify-review.md` — bốn vấn đề khác của cùng đợt đẩy.

> ## ✅ CẬP NHẬT 2026-09-04 (lần hai) — chiều XUỐNG đã nối xong, không cần backend làm gì
>
> Khảo sát ban đầu kết luận "client không thể tự nối". Điều đó **chỉ đúng với
> chiều lên**. Kiểm lại thì backend **vốn đã gửi cột `Keyword`** trong
> `/sync/pull` (`sync.repository.js`, khối `select` của `getCategoriesByAccount`
> có `keyword: true`) — chính client bỏ qua nó ở nhánh kéo về.
>
> Client đã vá ngày 2026-09-04: pull tách chuỗi CSV rồi ghi vào bảng
> `CategoryKeywords`, **chỉ gieo khi danh mục đó chưa có từ khoá nào**. Bộ từ
> khoá do admin soạn nay tới được máy người dùng, và thẻ gợi ý danh mục — vốn
> **không bao giờ hiện** vì bảng từ khoá rỗng tuyệt đối trên máy mới cài — đã
> chạy. Test canh chừng: `test/core/sync/sync_pull_category_keyword_test.dart`.
>
> **Vì sao "chỉ gieo khi trống" chứ không ghi đè:** cột `Keyword` phía backend
> là **một chuỗi dùng chung mọi tài khoản**, còn bảng client là dữ liệu **riêng
> từng người dùng, sửa được**. Ghi đè ở mỗi chu kỳ pull sẽ khiến thao tác xoá
> từ khoá của người dùng không bao giờ dính. Đây chính là vấn đề mô hình dữ
> liệu ở mục 3 — nó **chưa biến mất**, chỉ là chiều xuống né được nó.
>
> **Việc còn lại cho backend vẫn nguyên hai phần:** lỗ hổng phân quyền ở mục 4,
> và quyết định mô hình cho chiều **lên** ở mục 5.

**Người nhận:** đội Backend
**Trạng thái:** cần backend quyết định **chiều lên**. Chiều **xuống** client đã tự nối xong (xem khung ngay trên); lý do chiều lên vẫn bế tắc ở mục 3.
**Mức độ:** làm tính năng AI tự học **không nhận được dữ liệu từ client**, và có một lỗ hổng phân quyền đi kèm (mục 4) — lỗ hổng này nay ảnh hưởng trực tiếp tới kết quả quét hoá đơn, xem khung cập nhật ở trên.
**Ngày khảo sát:** 2026-09-03 · **Kiểm lại 2026-09-04** tại `fcf7659`, sau khi gộp `origin/main` `dfda862`.

---

## 1. Tóm tắt

Từ khoá dùng để phân loại giao dịch đang tồn tại ở **hai nơi hoàn toàn tách biệt**, mỗi
nơi có một bộ phân loại riêng, và **không có đường đồng bộ nào giữa chúng**:

| | Client-app | Backend |
|---|---|---|
| Nơi lưu | bảng `CategoryKeywords` (`categories_table.dart:49`) | cột `category.Keyword` (`schema.prisma:113`) |
| Hình dạng | **mỗi từ khoá một dòng**, có `idaccount` | **một chuỗi** nối bằng `','` (không khoảng trắng) trên hàng category |
| Phạm vi | theo **từng người dùng** (`UNIQUE(idaccount, categoryId, normalizedKeyword)`) | theo **hàng category**, không có khái niệm người dùng |
| Ai ghi | `CategoryDao.replaceKeywords()` (`category_dao.dart:130`) | `appendCategoryKeyword()` (`classify.repository.js:64`) |
| Ai đọc | `CategorySuggestionEngine` | `keyword.matcher.js`, `nlp.matcher.js` |
| Chuẩn hoá khi **lưu** | `trim().toLowerCase()` + gom khoảng trắng (`CategoryDao._normalizeKeyword`) | `preprocess()` rồi `trim().toLowerCase()` |
| Chuẩn hoá khi **so khớp** | `normalizeCategoryName` (NFC + thường + gom khoảng trắng), rồi vòng dự phòng `removeVietnameseTones` — *cập nhật 2026-09-04* | `cleanVietnameseText` + nhánh `cleanNoTone` |

Hệ quả: người dùng dạy cho app một từ khoá trên điện thoại thì **backend không bao giờ
biết**, và ngược lại. Tính năng tự học qua `POST /api/ai/classify/feedback` chỉ nhận được
dữ liệu từ những nơi gọi thẳng endpoint đó.

## 2. Đã kiểm chứng những gì

Đọc mã nguồn hai phía, không suy đoán:

- `SyncEntityType` (`sync_models.dart:11`) chỉ có **6 giá trị**: `wallet, transaction,
  category, budget, bill, goal`. **Không** có từ khoá.
- ~~Tìm toàn bộ `src/Client-app/lib/core/sync/`: **không một tham chiếu nào** tới `keyword`.~~
  **Không còn đúng từ 2026-09-04**: nhánh kéo về nay đọc `c['keyword']`, tách CSV và gieo
  vào `CategoryKeywords`. Chiều **đẩy lên** thì vẫn không có tham chiếu nào.
- Tìm toàn bộ `src/Client-app/lib/`: client **không gọi** bất kỳ endpoint nào dưới
  `/api/ai/classify/*`. Nó dùng bộ gợi ý cục bộ `CategorySuggestionEngine`.
- Backend đọc `category.Keyword` bằng `.split(',')` (`classify.repository.js:77`) và ghi
  bằng `.join(',')` (`:89`) — nội bộ nhất quán, không có khoảng trắng sau dấu phẩy.
  (Thay đổi `;` → `,` ở `nlp.matcher.js` trong commit `c9f4f45` chỉ là đưa matcher về khớp
  với thứ repository thật sự ghi ra; **không** phá vỡ gì.)

## 3. Vì sao client không tự nối được **chiều LÊN**

> Chiều xuống đã nối xong ngày 2026-09-04 mà không cần backend đổi gì — xem khung ✅ ở
> đầu tài liệu. Mục này chỉ nói về chiều **đẩy từ khoá của người dùng lên server**.

Giống hệt tình trạng đã mô tả ở `CATEGORY_GROUP_MEMBERSHIP_SYNC.md`:

1. Không có `SyncEntityType` cho từ khoá, và thêm một entity lạ vào batch sẽ nhận
   `Unknown entity` rồi kẹt vĩnh viễn (`sync.service.js`, `UPSERT_MAP` chỉ có 6 entity).
2. Quan trọng hơn: **cột `Keyword` nằm trên hàng `category` dùng chung**. Với danh mục
   mặc định (`Create_by = 1`), ghi từ khoá của một người vào đó sẽ **đổi cách phân loại
   cho toàn bộ người dùng**. Đây đúng là vấn đề mô hình dữ liệu mà client không có quyền
   quyết định.

## 4. Một vấn đề phân quyền phát hiện kèm theo — **nên xem trước**

`recordFeedback()` (`classify.service.js:178`) **nhận** `idaccount` nhưng chỉ dùng để ghi
log; nó gọi thẳng:

```js
const updatedCategory = await classifyRepository.appendCategoryKeyword(idcategory, keywordToLearn);
```

Còn `appendCategoryKeyword()` (`classify.repository.js:64`) tra danh mục **chỉ bằng
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

> ⚠️ **Chuẩn hoá phải khớp hai phía.** Cột `Normalized` phía client được sinh bằng
> `CategoryDao._normalizeKeyword`: `trim().toLowerCase()` + gom khoảng trắng. Nếu backend
> chuẩn hoá khác đi thì `UNIQUE(..., Normalized)` sẽ cho lọt bản trùng, và hỏng **âm thầm**
> đúng theo khuôn mẫu quen thuộc của dự án này. Chốt một định nghĩa và ghi vào tài liệu.
>
> ⚠️ **Đừng nhầm nó với phép chuẩn hoá lúc SO KHỚP.** Từ 2026-09-04, bộ gợi ý phía client
> so khớp bằng `normalizeCategoryName` (có thêm bước **NFC**) rồi một vòng dự phòng
> `removeVietnameseTones`. Hai phép này **cố ý khác nhau**: phép lưu phải ổn định vì nó là
> khoá duy nhất trong CSDL, còn phép so khớp được phép lỏng hơn vì đoán sai chỉ tốn một cú
> chạm để sửa. Nếu chọn Lựa chọn A thì cột `Normalized` dùng phép **lưu**, không phải phép
> so khớp — trộn hai cái sẽ khiến "đá" và "da" chiếm chỗ của nhau trong ràng buộc duy nhất.

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
   có nhưng không có `syncStatus`) — cần bump `schemaVersion` (hiện là **12**) và bổ sung.
5. **Cập nhật `test/core/sync/sync_payload_contract_test.dart` cùng lúc.** Tên trường đi qua
   ba nơi định nghĩa độc lập và một tên sai **không gây lỗi, chỉ lặng lẽ bị bỏ qua**.

## 7. Ghi chú

Toàn bộ khảo sát chỉ **đọc** mã nguồn. **Không có dòng mã backend nào bị thay đổi.**

Xem thêm `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` (cùng thư mục) — cùng một khuôn mẫu: một quan
hệ thuộc về từng người dùng nhưng lại được gắn vào hàng danh mục dùng chung.
