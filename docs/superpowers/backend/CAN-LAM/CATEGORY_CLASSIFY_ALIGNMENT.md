# Thống nhất giá trị `Classify` cho danh mục Vay/nợ

> ## ✅ ĐÃ CHỌN LỰA CHỌN A — 2026-09-03 (còn 1 bước nhỏ)
>
> Backend đã chốt `Vay/no` đúng như khuyến nghị:
>
> - `New_Database.md` đã sửa (dòng 87 và 304) → `Check in (Thu, Chi, Vay/no)`. ✅
> - `sync.service.js` chuẩn hoá mọi biến thể (`Vay/nợ`, `Vay`, `no`, `vay_no`,
>   `vay_nợ`, `Vay/ng`) về `Vay/no` trước khi ghi. ✅
> - **Còn thiếu — bước 3:** `sync.validation.js` dòng 103 vẫn chấp nhận danh sách
>   rộng `['Thu','Chi','Vay/nợ','Vay/no','Vay/ng','Vay','no','thu','chi']`.
>   Thu hẹp về đúng `['Thu','Chi','Vay/no']` để giá trị sai bị chặn sớm thay vì
>   trôi xuống tận CHECK constraint. Không gấp: `sync.service.js` đã chuẩn hoá
>   trước khi ghi nên hiện không có đường nào để giá trị sai lọt xuống CSDL.
>
> Phía client không phải đổi gì: hằng số `canonicalDebtClassify` vốn đã là `Vay/no`.


**Người nhận:** đội Backend
**Trạng thái:** cần quyết định + thực hiện phía backend. Phía Client-app đã xử lý xong phần của mình.
**Mức độ:** không gây lỗi ở hiện tại, nhưng sẽ làm **hỏng toàn bộ đồng bộ danh mục vay/nợ** nếu làm sai thứ tự.

---

## 1. Vấn đề

Cột `category.Classify` có ba giá trị hợp lệ: `Thu`, `Chi`, và giá trị thứ ba dành cho vay/nợ.
Giá trị thứ ba đang **không thống nhất** giữa tài liệu và mã nguồn đang chạy:

| Nơi | Giá trị đang dùng | Ghi chú |
|---|---|---|
| `docs/superpowers/backend/New_Database.md` | **`Vay/nợ`** (có dấu) | Được coi là "nguồn sự thật" |
| `docs/superpowers/plans/2026-09-01-align-postgresql-schema.md` | **`Vay/nợ`** (có dấu) | Ghi rõ "canonical category class" |
| `src/Backend/database/New_Database.sql` (dòng 109) | `Vay/no` (không dấu) | CHECK constraint |
| `src/Backend/prisma/migrations/20260901090000_align_new_database/migration.sql` (dòng 96) | `Vay/no` (không dấu) | **Migration đã áp dụng vào CSDL** |
| `src/Backend/prisma/seed.js` (dòng 23–24) | `Vay/no` (không dấu) | Dữ liệu seed thực tế |
| Client-app khi push | `Vay/no` (không dấu) | Khớp với CSDL |

Nói ngắn gọn: **tài liệu nói `Vay/nợ`, còn CSDL và mã nguồn đang chạy `Vay/no`.**
Kế hoạch align schema mới được thực hiện một nửa — phần test đã viết theo `Vay/nợ`, phần migration/seed thì đi theo `Vay/no`.

### Hiện tại có hỏng gì không?

**Không.** Toàn hệ thống đang nhất quán ở `Vay/no`, và `src/Backend/modules/sync/sync.validation.js` (dòng 103) còn chấp nhận rộng rãi cả hai dạng. Mọi thứ chạy bình thường.

### Vậy vì sao phải xử lý?

Vì đây là **bom hẹn giờ**. Bất kỳ ai đọc `New_Database.md` rồi đổi CHECK constraint sang `Vay/nợ` mà không đổi client cùng lúc sẽ khiến:

- client vẫn gửi `Vay/no`
- PostgreSQL từ chối vì vi phạm `ck_category_classify`
- thao tác đồng bộ trả về `failed`, danh mục kẹt ở trạng thái `pending` và **thử lại vô hạn**
- giao dịch tham chiếu danh mục đó bị hoãn đồng bộ theo

Và theo đúng khuôn mẫu đã lặp lại nhiều lần trong dự án này, nó sẽ hỏng **âm thầm** — không có thông báo lỗi nào tới người dùng.

---

## 2. Client-app đã làm gì (đã xong, không cần backend làm gì thêm)

Trong `src/Client-app/lib/core/sync/sync_payload_normalizer.dart`:

1. **Đọc khoan dung.** `categoryClassifyFromBackend()` và `sameCategoryClassify()` nay coi `Vay/no`, `Vay/nợ`, `vay_no`, `vay_nợ` là **cùng một giá trị**. Nghĩa là client chạy đúng bất kể backend đã migrate hay chưa — **backend có thể đổi trước mà không cần chờ client**.

2. **Ghi qua một hằng số duy nhất.**

   ```dart
   static const String canonicalDebtClassify = 'Vay/no';
   ```

   Mọi biến thể đầu vào đều được chuẩn hoá về đúng hằng số này trước khi push. Khi backend đã xong, đổi **một dòng** này là client chuyển sang giá trị mới.

3. **Test bám vào hằng số**, nên không phải sửa test khi lật công tắc.

---

## 3. Hai lựa chọn

### Lựa chọn A — Chốt `Vay/no` (không dấu) · **khuyến nghị**

Giữ nguyên thứ đang chạy, chỉ sửa **tài liệu** cho khớp thực tế.

**Việc cần làm:**

1. Sửa `docs/superpowers/backend/New_Database.md`:
   - dòng 87: `Check in (Thu, Chi, Vay/nợ)` → `Check in (Thu, Chi, Vay/no)`
   - dòng 304: `Classify IN ('Thu', 'Chi', 'Vay/nợ')` → `... 'Vay/no')`
2. Sửa `docs/superpowers/plans/2026-09-01-align-postgresql-schema.md` cho khớp, hoặc đánh dấu kế hoạch đó là đã thay thế bởi tài liệu này.
3. Thu hẹp danh sách hợp lệ trong `src/Backend/modules/sync/sync.validation.js` (dòng 103) xuống đúng `['Thu', 'Chi', 'Vay/no']` để giá trị sai bị chặn sớm thay vì trôi xuống tận CHECK constraint.

**Không cần** migration dữ liệu. **Không cần** đổi client. **Rủi ro: gần như bằng không.**

**Đánh đổi:** giá trị hiển thị trong CSDL thiếu dấu tiếng Việt. Đây thuần tuý là giá trị enum nội bộ, người dùng không bao giờ nhìn thấy — giao diện tự dịch sang nhãn riêng.

---

### Lựa chọn B — Chốt `Vay/nợ` (có dấu)

Làm đúng như tài liệu đang mô tả. Tốn công hơn hẳn và **bắt buộc đúng thứ tự**.

**Việc cần làm — theo đúng thứ tự này:**

1. **Nới CHECK constraint để chấp nhận cả hai** (bước đệm, tránh gián đoạn):

   ```sql
   ALTER TABLE "category" DROP CONSTRAINT IF EXISTS "ck_category_classify";
   ALTER TABLE "category" ADD CONSTRAINT "ck_category_classify"
     CHECK ("Classify" IN ('Thu', 'Chi', 'Vay/no', 'Vay/nợ'));
   ```

2. **Chuyển đổi dữ liệu đang có:**

   ```sql
   UPDATE "category" SET "Classify" = 'Vay/nợ' WHERE "Classify" = 'Vay/no';
   ```

   > Kiểm tra trước: `SELECT "Classify", COUNT(*) FROM "category" GROUP BY 1;`

3. **Sửa `src/Backend/prisma/seed.js`** (dòng 23–24): `classify: 'Vay/no'` → `'Vay/nợ'`.

4. **Sửa `src/Backend/database/New_Database.sql`** (dòng 109) và tạo migration Prisma mới cho CHECK constraint.

5. **Báo cho Client-app** đổi hằng số `canonicalDebtClassify` thành `'Vay/nợ'` và phát hành bản mới.

6. **Chỉ sau khi phần lớn người dùng đã cập nhật app**, mới siết CHECK constraint về đúng một giá trị:

   ```sql
   ALTER TABLE "category" DROP CONSTRAINT IF EXISTS "ck_category_classify";
   ALTER TABLE "category" ADD CONSTRAINT "ck_category_classify"
     CHECK ("Classify" IN ('Thu', 'Chi', 'Vay/nợ'));
   ```

**Cảnh báo quan trọng:** không được làm bước 6 trước bước 5. Người dùng chưa cập nhật app vẫn gửi `Vay/no` — siết constraint sớm sẽ làm hỏng đồng bộ của họ.

**Lưu ý kỹ thuật:** cột là `VarChar(7)`. `Vay/nợ` dài 6 **ký tự** nên vẫn vừa (PostgreSQL đếm ký tự, không đếm byte) — nhưng nếu có nơi nào đo bằng byte thì `Vay/nợ` chiếm 8 byte trong UTF-8, cần để ý.

---

## 4. Khuyến nghị

**Chọn A.** Lợi ích của B chỉ là dấu tiếng Việt trong một giá trị enum mà người dùng không nhìn thấy, trong khi cái giá là migration dữ liệu, hai lần đổi constraint, và một cửa sổ thời gian mà app cũ và app mới phải cùng chạy được.

Dù chọn phương án nào, **hãy chốt bằng văn bản và cập nhật `New_Database.md`** — nguyên nhân gốc của cả vấn đề này là tài liệu và mã nguồn nói hai điều khác nhau suốt một thời gian dài mà không ai phát hiện.

---

## 5. Cách kiểm chứng sau khi làm

```sql
-- 1. Không còn giá trị lẫn lộn
SELECT "Classify", COUNT(*) FROM "category" GROUP BY 1;

-- 2. CHECK constraint đúng như mong đợi
SELECT pg_get_constraintdef(oid) FROM pg_constraint
WHERE conname = 'ck_category_classify';
```

Phía client, chạy:

```bash
cd src/Client-app && flutter test test/core/sync/
```

Bộ test `sync_payload_contract_test.dart` khoá lại toàn bộ ánh xạ tên trường giữa hai phía — nếu hợp đồng bị phá, test sẽ đỏ ngay thay vì hỏng âm thầm.

---

## 6. Bối cảnh thêm

Đây không phải lần đầu lệch tên trường giữa client và backend gây lỗi ngầm trong dự án này. Ba nơi cùng định nghĩa tên trường mà không chia sẻ một hợp đồng chung:

1. Client dựng payload thủ công trong `sync_engine.dart`
2. `SyncPayloadNormalizer` đổi tên một số khoá
3. `mapEntityFields()` phía backend ánh xạ tiếp sang tên Prisma

Một tên sai ở bất kỳ đâu trong chuỗi này đều **không gây lỗi** — nó chỉ lặng lẽ bị bỏ qua. Nếu backend bổ sung trường mới cho sync, hãy cập nhật `src/Client-app/test/core/sync/sync_payload_contract_test.dart` cùng lúc để giữ hai phía khớp nhau.
