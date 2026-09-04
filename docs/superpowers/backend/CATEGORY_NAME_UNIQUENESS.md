# Quy tắc trùng tên danh mục: ràng buộc CSDL đang khác quy tắc nghiệp vụ

> ## ⚠️ CẬP NHẬT 2026-09-03 — đã làm một phần, còn bốn khoảng hở
>
> `admin.service.js` nay **đã cài quy tắc**, ở cả `addCategory` và `updateCategory`
> (có loại trừ chính bản ghi đang sửa). Ba điểm khớp hoàn toàn với client:
> không tính `Classify`, dùng `mode: 'insensitive'` nên không phân biệt hoa/thường,
> và lọc `delete_at: null` nên hàng đã xoá không giữ chỗ. Rất tốt.
>
> Bốn điểm còn lại, đo trực tiếp từ mã nguồn và CSDL:
>
> | # | Khoảng hở | Hệ quả |
> |---|---|---|
> | 1 | Admin chỉ `trim()`, **không gom khoảng trắng giữa** | `"Cà  phê"` với `"Cà phê"`: client chặn, admin cho qua |
> | 2 | Admin **không chuẩn hoá Unicode NFC** | Hai chuỗi nhìn y hệt nhau nhưng khác byte thì admin coi là khác nhau |
> | 3 | **Thiếu vế chéo "người dùng với mặc định"** | Khi tạo danh mục người dùng, admin chỉ kiểm trong phạm vi `create_by`; không kiểm với danh mục mặc định. Chiều ngược lại cũng vậy. Đây đúng là vế mà mục 3 nói không viết được thành unique index |
> | 4 | **Đường `/sync/push` và CSDL vẫn trống** | `upsertCategory` chỉ khớp theo `idcategory`, không kiểm tên; `pg_indexes` vẫn là hai index cũ và **không có trigger nào** |
>
> Nghĩa là dữ liệu đi qua app vẫn **chỉ được client chặn**. Mục 4.1–4.3 dưới đây vẫn cần làm nguyên vẹn; mục 4.3 nay có thể tái dùng logic đã viết trong `admin.service.js` thay vì viết mới.
>
> Dữ liệu thật kiểm ngày 2026-09-03: **20 danh mục, 0 vi phạm** ở cả ba phép kiểm ở mục 4.2 và 4.3 — vẫn chưa cần chuyển đổi dữ liệu.

> ## 🔴 ĐO ĐƯỢC TRÊN APP THẬT 2026-09-03 — hậu quả rộng hơn tài liệu này mô tả
>
> Tài liệu này vẫn ghi hậu quả là "vi phạm trùng tên hỏng âm thầm khi đồng bộ".
> Chạy app thật cho thấy nó **kéo chậm toàn bộ việc đồng bộ**, không riêng danh mục.
>
> Kịch bản: tài khoản đã có 5 danh mục cá nhân trên backend (Chi khác, Thu khác,
> Làm thêm, Trả nợ, Thu nợ). Đăng nhập trên một **máy mới**. Client sinh lại đúng
> 5 danh mục đó với UUID khác — **nguyên nhân này thuộc về client**, xem ghi chú
> ở cuối khung. Log của `SyncEngine` trong trình duyệt:
>
> ```
> [SyncEngine] Push failed [transient]: entity=category, localId=6d16eab1-…, reason=
> … (5 danh mục, lặp ở MỌI chu kỳ)
> [SyncEngine] Real Sync Complete: 0/5 synced successfully.
> [SyncEngine] Đang trong thời gian giãn cách sau 2 chu kỳ hỏng — hoãn tới 19:50:31
> ```
>
> **Điểm mấu chốt: `reason=` rỗng.** `/sync/push` trả `status: "failed"` mà không
> kèm message lẫn mã lỗi. Client không có gì để nhận diện nên xếp vào `transient`
> và **thử lại vĩnh viễn**. Mọi chu kỳ đồng bộ vì thế kết thúc ở trạng thái hỏng,
> kích hoạt giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p — và **mọi thay đổi
> khác** (ví, giao dịch, ngân sách) bị đẩy chậm theo. Đã đo: một thao tác xoá
> ngân sách hoàn toàn hợp lệ không lên tới backend cho tới lần mở app sau.
>
> **Việc rẻ nhất mà backend làm được ngay, độc lập với mục 4:** cho `/sync/push`
> trả một **mã lỗi ổn định** khi từ chối vì trùng tên:
>
> ```json
> { "localId": "...", "status": "failed", "code": "CATEGORY_NAME_DUPLICATE",
>   "message": "Tên danh mục đã tồn tại trong tài khoản này" }
> ```
>
> Có mã đó, client thêm đúng **một dòng** vào `_classifyFailure` để xếp nó thành
> `permanent`; thao tác hỏng sẽ bị chặn theo thời gian như mọi lỗi vĩnh viễn khác
> thay vì kéo cả chu kỳ xuống.
>
> **Cập nhật 2026-09-04 — client đã tự xử lý phần cấp bách, nhưng bằng cách dễ vỡ.**
> Không chờ được mã ổn định, client thêm một phép **khớp chuỗi** bắt
> `23505 | violates unique constraint | unique constraint failed` rồi xếp
> `permanent`. Vế "kéo chậm mọi thực thể khác" vì thế đã hết.
>
> Nhưng đây là phép khớp chuỗi **thứ ba** trong `_classifyFailure`, và nó phải
> đoán ba biến thể câu chữ cho cùng một lỗi vì không biết Prisma phiên bản nào
> đang chạy. Đổi phiên bản Prisma là mất khả năng phân loại, **không có lỗi nào
> báo ra**. Mã `CATEGORY_NAME_DUPLICATE` (hoặc `UNIQUE_VIOLATION` chung, xem
> mục 8.2 của `2026-09-04-backend-idempotent-delete.md`) vẫn đáng làm — nay với
> vai trò **thay thế một lớp phòng thủ dễ vỡ**, chứ không còn là việc cấp cứu.
>
> ### Nguyên nhân gốc thuộc về client — backend không phải chờ nó
>
> Bản đầu của khung này quy sai cho `CATEGORY_STABLE_IDS.md`. Kiểm lại mã nguồn
> thì không phải: `PersonalDefaultCategories.ensureForAccount()` **có** kiểm
> trùng theo tên đã chuẩn hoá trước khi tạo. Vấn đề là **thứ tự** — nó chạy
> trước `SyncEngine.start()` (chủ ý, để việc chuyển dữ liệu `cat_*` cũ xong
> trước chu kỳ đồng bộ đầu tiên). Trên máy mới, CSDL cục bộ rỗng nên phép kiểm
> không thấy gì, tạo 5 UUID mới; pull sau đó mới kéo về 5 bản của backend.
>
> Nghĩa là **client tự sửa được** phần gốc, không phải chờ backend. Phần backend
> ở trên (mã lỗi ổn định) vẫn đáng làm, nhưng với vai trò **lớp phòng thủ thứ
> hai**: bất kỳ vi phạm trùng tên nào khác cũng sẽ hỏng theo đúng kiểu này
> chừng nào `/sync/push` còn trả message rỗng.

**Người nhận:** đội Backend
**Trạng thái:** Client-app **đã thi hành xong**. Admin-web **đã thi hành một phần** (cập nhật 2026-09-03, xem khung ở đầu tài liệu). Đường `/sync/push` thì **chưa có phép kiểm nào**. CSDL **có hai unique index nhưng chúng thi hành một quy tắc khác** — lệch theo cả hai chiều, xem bảng ở mục 2; đừng đọc câu này thành "CSDL chưa có ràng buộc gì".
**Mức độ:** đang có đường ghi dữ liệu vi phạm quy tắc, và một đường sinh bản ghi kẹt **tự lặp ở mỗi lần mở app** (mục 2, khung cập nhật 2026-09-04). Vế "làm chậm đồng bộ của mọi thực thể khác" đo ngày 2026-09-03 **không còn đúng** kể từ khi client xếp vi phạm UNIQUE vào `permanent`.
**Ngày khảo sát:** 2026-09-03 · **Kiểm lại cùng ngày** sau khi gộp `main` tới `0e8f0b2`, và đo trên app thật.

---

## 1. Quy tắc nghiệp vụ đã chốt

Trong phạm vi **một tài khoản**, tên danh mục là **duy nhất**:

1. **Không tính `Classify`.** Một tài khoản không được có cả "Ăn uống" loại Thu và "Ăn uống" loại Chi.
2. **Không tính nhóm cha (`Idgroup`).** Hai nhóm khác nhau *không* phải hai không gian tên riêng.
3. **Nhóm, danh mục con và danh mục MẶC ĐỊNH dùng chung một không gian tên.** Người dùng nhìn thấy tất cả trong cùng một danh sách chọn nên hai mục trùng tên là không phân biệt được.
4. **Hàng đã xoá mềm không giữ chỗ** (`Delete_at IS NOT NULL` thì tên được dùng lại).
5. **So tên không phân biệt hoa/thường** và gom khoảng trắng thừa.

Hai tài khoản **khác nhau** thì được đặt trùng tên — `Create_by` nằm trong khoá.
Danh mục mặc định là hàng dùng chung nên tên của nó chiếm chỗ với **mọi** tài khoản.

## 2. Hiện trạng CSDL — đo trực tiếp từ `pg_indexes`

```
uq_category_owner_name_classify   UNIQUE ("Create_by", "NameCategory", "Classify")
uq_category_default_name_classify UNIQUE ("NameCategory", "Classify") WHERE "Is_default" = true
```

Lệch quy tắc theo **cả hai chiều**, nên không thể chỉ "siết thêm":

| Điểm | CSDL hiện tại | Quy tắc |
|---|---|---|
| `Classify` trong khoá | có → **lỏng hơn** | không |
| `Idgroup` trong khoá | không → đúng | không |
| Người dùng vs mặc định | hai khoá tách rời → **lỏng hơn** | chung không gian tên |
| Hàng đã xoá mềm | vẫn giữ chỗ → **chặt hơn** | không giữ chỗ |
| Hoa/thường | phân biệt → **lỏng hơn** | không phân biệt |

Hệ quả của dòng "chặt hơn": người dùng xoá một danh mục rồi tạo lại **cùng tên** thì client cho qua (nó lọc hàng đã xoá), nhưng CSDL từ chối. Thao tác đó trả `failed` trong `results[]` của `/sync/push` và **không có gì hiện ra màn hình** — đúng khuôn mẫu hỏng âm thầm đã lặp lại nhiều lần trong dự án này.

> **Cập nhật 2026-09-04 — dòng "chặt hơn" này KHÔNG còn là rủi ro lý thuyết.**
>
> Nó có một đường kích hoạt **tự lặp**, không cần người dùng chủ động tạo lại gì:
> xoá một trong 5 danh mục cá nhân mặc định → `PersonalDefaultCategories.ensureMissing()`
> tạo lại nó với UUID mới ở **mỗi lần mở app** (hàm đó hỏi `getNamesInUse`, mà
> `getNamesInUse` lọc hàng đã xoá nên không thấy) → mỗi bản mới đụng
> `uq_category_owner_name_classify` và nhận `23505`. Chi tiết: G16 trong
> `docs/CLIENT_APP_KNOWN_GAPS.md`.
>
> **Client đã cầm máu cùng ngày:** `_classifyFailure` nay xếp vi phạm UNIQUE vào
> `permanent`, nên bản ghi bị chặn theo thời gian thay vì đẩy lại ở mọi chu kỳ,
> và `syncError` có ghi lại nguyên nhân. Nghĩa là nó **không còn hoàn toàn âm
> thầm** và **không còn kéo chậm hàng đợi** — nhưng bản ghi vẫn được sinh ra ở
> mỗi lần mở app và vẫn không bao giờ lên được server.
>
> Chỉ mệnh đề `WHERE "Delete_at" IS NULL` ở mục 4.1 mới dứt điểm được: có nó thì
> mọi bản ghi đang bị chặn **tự quay lại hàng đợi** và đồng bộ thành công, người
> dùng không phải làm gì cả.

## 3. Điểm khó: vế thứ ba KHÔNG diễn đạt được bằng unique index

"Tên của người dùng không được đụng tên danh mục mặc định" là quan hệ giữa **hai hàng có `Create_by` khác nhau** (người dùng `10` với admin `1`). Unique index chỉ so được các hàng có **cùng** giá trị khoá, nên không có cách nào viết vế này thành index.

Phải dùng **trigger** hoặc kiểm tra ở **tầng ứng dụng**. Xem mục 4.3.

## 4. Đề xuất

### 4.1. Thay hai unique index

```sql
DROP INDEX IF EXISTS "uq_category_owner_name_classify";
DROP INDEX IF EXISTS "uq_category_default_name_classify";

-- Danh mục của người dùng: duy nhất theo (chủ sở hữu, tên chuẩn hoá)
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL;

-- Danh mục mặc định: duy nhất theo tên chuẩn hoá
CREATE UNIQUE INDEX "uq_category_default_name"
  ON "category" (lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
```

`lower`, `btrim`, `regexp_replace` và `normalize` đều IMMUTABLE nên dùng được trong index biểu thức. `normalize(text, NFC)` cần **PostgreSQL 13 trở lên**.

> **Bước `normalize(..., NFC)` là bắt buộc, không phải tuỳ chọn.** "Cà phê" gõ từ hai bàn phím khác nhau có thể ra hai chuỗi khác byte (6 ký tự với dạng dựng sẵn, 8 ký tự với dạng tách dấu) mà mắt thường không phân biệt được. Client đã gộp NFC từ 2026-09-03 (`src/Client-app/lib/core/category/category_name.dart`); nếu CSDL không gộp thì hai phía hiểu khác nhau về "trùng tên" và sẽ lệch **âm thầm**.
>
> Dữ liệu mặc định hiện có trên CSDL đã được kiểm: **13/13 đều ở dạng NFC**, nên thêm bước này bây giờ không làm hỏng dòng nào.

> ⚠️ Prisma không mô hình hoá được index biểu thức có mệnh đề `WHERE`. Giữ chúng trong **migration SQL viết tay** và ghi chú lại trong `schema.prisma`, nếu không `prisma migrate` sẽ đề nghị xoá chúng đi ở lần chạy sau.

### 4.2. Kiểm tra dữ liệu TRƯỚC khi tạo index

`CREATE UNIQUE INDEX` sẽ **thất bại** nếu đang có hàng vi phạm. Chạy trước:

```sql
-- A. Trùng trong cùng một tài khoản
SELECT "Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')) AS k, COUNT(*)
FROM "category" WHERE "Is_default" = FALSE AND "Delete_at" IS NULL
GROUP BY 1, 2 HAVING COUNT(*) > 1;

-- B. Danh mục mặc định trùng tên
SELECT lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')) AS k, COUNT(*)
FROM "category" WHERE "Is_default" = TRUE AND "Delete_at" IS NULL
GROUP BY 1 HAVING COUNT(*) > 1;
```

**Đo ngày 2026-09-03 bằng đúng biểu thức chuẩn hoá ở trên: cả hai đều trả về 0 dòng**, và phép kiểm vế thứ ba (mục 4.3) cũng 0 dòng — nên hiện chưa cần chuyển đổi dữ liệu. Vẫn nên chạy lại ngay trước khi migrate vì dữ liệu có thể đã đổi.

### 4.3. Vế "người dùng với mặc định"

Phép kiểm dữ liệu hiện có:

```sql
SELECT u."Create_by", u."NameCategory"
FROM "category" u
JOIN "category" d
  ON d."Is_default" = TRUE AND d."Delete_at" IS NULL
 AND lower(regexp_replace(btrim(normalize(d."NameCategory", NFC)), '\s+', ' ', 'g'))
   = lower(regexp_replace(btrim(normalize(u."NameCategory", NFC)), '\s+', ' ', 'g'))
WHERE u."Is_default" = FALSE AND u."Delete_at" IS NULL;
```

Cách thi hành, chọn một trong hai:

**(a) Trigger — bảo đảm ở mọi đường ghi · khuyến nghị**

Đặt `ERRCODE = '23505'` (unique_violation) để Prisma báo lỗi cùng loại với vi phạm index, đỡ phải xử lý riêng một nhánh lỗi mới. Trigger cần chặn **cả hai chiều**: thêm danh mục người dùng đụng tên mặc định, và thêm danh mục mặc định đụng tên người dùng. Gắn `BEFORE INSERT OR UPDATE OF "NameCategory", "Is_default", "Delete_at"`.

**(b) Kiểm tra ở tầng ứng dụng** trong `upsertCategory` (`sync.repository.js`) **và** đường tạo danh mục của Admin-web.

Khuyến nghị **(a)**: dự án đã có hai đường ghi (sync và Admin-web) và sắp có thêm luồng AI. Trigger là chỗ duy nhất không sót được; phương án (b) chỉ cần quên một nơi là quy tắc thủng.

### 4.4. Trả mã lỗi máy đọc được

Khi `/sync/push` gặp vi phạm này, xin gắn `code` ổn định vào `results[i]` — giống cách đã làm rất tốt với `ACCOUNT_NOT_FOUND`:

```json
{ "localId": "...", "status": "failed", "code": "CATEGORY_NAME_DUPLICATE",
  "message": "Tên danh mục đã tồn tại trong tài khoản" }
```

Hiện client không có cách nào phân biệt vi phạm trùng tên với các lỗi khác, nên nó chỉ đánh dấu bản ghi là hỏng rồi im lặng. Có `code` thì client báo được cho người dùng biết đúng danh mục nào cần đổi tên.

## 5. Client-app đã làm gì (để backend không làm trùng)

| Việc | Cách làm |
|---|---|
| Thi hành đủ 5 điểm của quy tắc | `CategoryManagementRepositoryImpl._hasDuplicateName()` |
| Quét đúng phạm vi | `CategoryDao.getNamesInUse(accountId)` — gồm danh mục của tài khoản **và** danh mục mặc định, bỏ hàng đã xoá |
| Không làm kẹt dữ liệu cũ | Chỉ xét trùng khi tên **thật sự đổi**, để người dùng còn sửa được danh mục cũ do bản client trước tạo ra |
| Khoá lại bằng test | `test/features/category/data/category_management_repository_test.dart` |

Client **không** phụ thuộc việc backend có sửa hay không — nhưng chừng nào CSDL chưa đổi thì quy tắc chỉ được bảo đảm ở client, còn Admin-web và các đường ghi khác vẫn tạo được dữ liệu vi phạm.

## 6. Cách kiểm chứng sau khi làm

Các trường hợp phải bị **TỪ CHỐI**:

- cùng tài khoản, cùng tên, khác `Classify`
- cùng tài khoản, cùng tên, khác `Idgroup`
- danh mục người dùng trùng tên một danh mục mặc định
- cùng tên chỉ khác hoa/thường hoặc khác khoảng trắng

Các trường hợp phải được **CHẤP NHẬN**:

- hai tài khoản KHÁC nhau cùng đặt tên "Ăn uống"
- xoá mềm một danh mục rồi tạo lại đúng tên đó

Phía client:

```bash
cd src/Client-app && flutter test test/features/category/
```

## 7. Ghi chú

Toàn bộ khảo sát chỉ **đọc** mã nguồn backend và **truy vấn chỉ đọc** vào CSDL. **Không có dòng mã backend nào bị thay đổi, không có dữ liệu nào bị sửa.**

Xem thêm `CATEGORY_CLASSIFY_ALIGNMENT.md` (cùng thư mục) — cũng liên quan tới cột `Classify` của bảng này.
