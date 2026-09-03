# Quy tắc trùng tên danh mục: ràng buộc CSDL đang khác quy tắc nghiệp vụ

**Người nhận:** đội Backend
**Trạng thái:** phía Client-app **đã thi hành xong** quy tắc (2026-09-03). CSDL thì chưa — cần backend thay ràng buộc.
**Mức độ:** đang có đường ghi dữ liệu vi phạm quy tắc, và một đường **hỏng âm thầm** khi đồng bộ.
**Ngày khảo sát:** 2026-09-03.

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
  ON "category" ("Create_by", lower(regexp_replace(btrim("NameCategory"), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL;

-- Danh mục mặc định: duy nhất theo tên chuẩn hoá
CREATE UNIQUE INDEX "uq_category_default_name"
  ON "category" (lower(regexp_replace(btrim("NameCategory"), '\s+', ' ', 'g')))
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
```

`lower`, `btrim`, `regexp_replace` đều IMMUTABLE nên dùng được trong index biểu thức.

> ⚠️ Prisma không mô hình hoá được index biểu thức có mệnh đề `WHERE`. Giữ chúng trong **migration SQL viết tay** và ghi chú lại trong `schema.prisma`, nếu không `prisma migrate` sẽ đề nghị xoá chúng đi ở lần chạy sau.

### 4.2. Kiểm tra dữ liệu TRƯỚC khi tạo index

`CREATE UNIQUE INDEX` sẽ **thất bại** nếu đang có hàng vi phạm. Chạy trước:

```sql
-- A. Trùng trong cùng một tài khoản
SELECT "Create_by", lower(regexp_replace(btrim("NameCategory"), '\s+', ' ', 'g')) AS k, COUNT(*)
FROM "category" WHERE "Is_default" = FALSE AND "Delete_at" IS NULL
GROUP BY 1, 2 HAVING COUNT(*) > 1;

-- B. Danh mục mặc định trùng tên
SELECT lower(regexp_replace(btrim("NameCategory"), '\s+', ' ', 'g')) AS k, COUNT(*)
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
 AND lower(regexp_replace(btrim(d."NameCategory"), '\s+', ' ', 'g'))
   = lower(regexp_replace(btrim(u."NameCategory"), '\s+', ' ', 'g'))
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
