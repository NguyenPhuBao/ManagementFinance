# 📋 KẾ HOẠCH TRIỂN KHAI: XỬ LÝ CÁC VẤN ĐỀ TỒN ĐỌNG HỆ THỐNG

> **Ngày lập kế hoạch:** 05/10/2026  
> **Người thực hiện:** Senior Fullstack & Senior BA / Antigravity AI  
> **Người duyệt:** Product Owner (PO)  
> **Phạm vi:** Cả 3 phân hệ (`src/Backend`, `src/Admin-web`, `src/Client-app`) và CSDL PostgreSQL Supabase.

---

## 🎯 MỤC TIÊU KẾ HOẠCH

Xử lý dứt điểm 3 vấn đề tồn đọng đã được phát hiện trong đợt khảo sát toàn diện:
1. **Vấn đề 1 (Client-app):** Đồng bộ môi trường Flutter SDK trên máy trạm để tương thích với mã nguồn Client-app và gói `background_downloader: ^9.6.2`.
2. **Vấn đề 2 (Backend CI/CD):** Tách bài test tích hợp `chatbot.api.test.js` sang script riêng `"test:integration"`, chuẩn hóa `"test"` chỉ chạy các bài test độc lập/mocked nội bộ (tốc độ < 3s, 100% pass).
3. **Vấn đề 3 (CSDL Supabase):** Báo cáo kết quả kiểm tra thực tế trên Supabase và thiết lập hàng rào bảo vệ kỹ thuật (DB Guard) ngăn chặn hoàn toàn việc vô tình chạy `prisma migrate dev` / `prisma db push` làm mất điều kiện soft-delete.

---

## 🔍 KẾT QUẢ KIỂM TRA ĐIỀU KIỆN TRÊN POSTGRESQL SUPABASE HIỆN TẠI (VẤN ĐỀ 3)

Vào lúc **08:38 ngày 05/10/2026**, hệ thống đã kết nối trực tiếp đến CSDL Cloud Supabase (`aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres`) và truy vấn bảng `pg_indexes` cùng `information_schema.triggers`.

### Kết quả thẩm tra thực tế:
> ✅ **CSDL SUPABASE HOÀN TOÀN NGUYÊN VẸN 100%, CHƯA BỊ ẢNH HƯỞNG!**

* **Toàn bộ 5 Partial Unique Indexes quan trọng vẫn còn nguyên vẹn mệnh đề `WHERE`:**
  1. `[account] account_Email_key`:  
     `CREATE UNIQUE INDEX "account_Email_key" ON public.account USING btree ("Email") WHERE ("Delete_at" IS NULL)`
  2. `[user] user_Email_key`:  
     `CREATE UNIQUE INDEX "user_Email_key" ON public."user" USING btree ("Email") WHERE ("Delete_at" IS NULL)`
  3. `[category] uq_category_default_name`:  
     `CREATE UNIQUE INDEX uq_category_default_name ON public.category USING btree (normalize...) WHERE (("Is_default" = true) AND ("Delete_at" IS NULL))`
  4. `[category] uq_category_owner_name`:  
     `CREATE UNIQUE INDEX uq_category_owner_name ON public.category USING btree ("Create_by", normalize...) WHERE (("Is_default" = false) AND ("Delete_at" IS NULL))`
  5. `[bill] idx_bill_previous_bill`:  
     `CREATE INDEX idx_bill_previous_bill ON public.bill USING btree ("Previous_bill_id") WHERE ("Previous_bill_id" IS NOT NULL)`
  6. `[transaction] idx_transaction_bill`:  
     `CREATE INDEX idx_transaction_bill ON public.transaction USING btree ("Idbill") WHERE ("Idbill" IS NOT NULL)`
  7. `[transaction] idx_transaction_goal`:  
     `CREATE INDEX idx_transaction_goal ON public.transaction USING btree ("Idgoal") WHERE ("Idgoal" IS NOT NULL)`

* **Toàn bộ các Triggers CSDL bảo vệ dữ liệu vẫn đang hoạt động:**
  - `[audit_log] trg_protect_auditlog`: Chặn `UPDATE` và chặn `DELETE` dưới 12 tháng (NĐ 53/2022/NĐ-CP).
  - `[transaction] trg_protect_transaction`: Chặn `DELETE` vật lý dưới 5 năm (Luật Kế toán 2015).
  - `[user] trg_check_phone_encrypted`: Chặn lưu số điện thoại dạng bản rõ (NĐ 13/2023/NĐ-CP).
  - `[bank_account] trg_check_bank_account_encrypted`: Chặn lưu số tài khoản dạng bản rõ.

---

## 🛠️ CHI TIẾT CÁC BƯỚC THỰC HIỆN

### BƯỚC 1: Xây Dựng Hàng Rào Bảo Vệ CSDL (DB Safety Guard) & Ràng Buộc Quy Tắc (Vấn đề 3)

#### 1.1. Tạo script bảo vệ `src/Backend/scripts/db-guard.js`:
* Tác vụ: Bắt chặn trước khi các lệnh Prisma có nguy cơ phá hủy CSDL được gọi.
* Cơ chế:
  - Phân tích `DATABASE_URL` và `DIRECT_URL`.
  - Nếu kết nối trỏ tới Supabase Cloud (`supabase.co`, `supabase.com`, port `6543`, port `5432` trên cloud host) hoặc `NODE_ENV === 'production'`:
    - Nếu tham số là `migrate` hoặc `push`: Lập tức ngắt lệnh với mã lỗi `1` kèm thông điệp cảnh báo màu đỏ chi tiết.
    - Hướng dẫn kỹ sư: Bắt buộc viết script migration `.sql` vào `database/`, thực thi qua SQL Editor của Supabase hoặc script kiểm soát an toàn, sau đó chỉ chạy `prisma generate`.
  - Nếu ở môi trường local SQLite/Docker dev tách biệt: Cho phép kèm cảnh báo nhắc nhở.

#### 1.2. Tạo script tự động kiểm tra tính toàn vẹn CSDL `src/Backend/scripts/verify-db-indexes.js`:
* Cho phép Quản trị viên/DevOps kiểm tra nhanh tình trạng của 5 Partial Indexes và Triggers bất cứ lúc nào qua lệnh:
  ```bash
  rtk npm run db:verify-indexes
  ```
* Tự động trả về `Exit 0` nếu tất cả 5 Partial Indexes còn nguyên điều kiện `WHERE "Delete_at" IS NULL`, hoặc `Exit 1` nếu phát hiện có index bị biến dạng.

#### 1.3. Cập nhật `src/Backend/package.json`:
* Thay thế lệnh trần:
  ```json
  "prisma:migrate": "node scripts/db-guard.js migrate",
  "prisma:push": "node scripts/db-guard.js push",
  "db:verify-indexes": "node scripts/verify-db-indexes.js"
  ```

#### 1.4. Cập nhật tài liệu quy tắc:
* Cập nhật `.agents/AGENTS.md` (mục RULE CSDL) và `docs/Rule_Project/Rule_project.md`.

---

### BƯỚC 2: Tách Biệt Bài Test Tích Hợp Chatbot & Chuẩn Hóa Lệnh `npm test` Backend (Vấn đề 2)

#### 2.1. Cập nhật cấu hình kịch bản kiểm thử trong `src/Backend/package.json`:
* Phân tách rành mạch:
  ```json
  "scripts": {
    "test": "node --test tests/unit/**/*.test.js tests/v2/**/*.test.js",
    "test:unit": "node --test tests/unit/**/*.test.js",
    "test:v2": "node tests/run-v2.js",
    "test:integration": "node --test tests/integration/**/*.test.js",
    "test:all": "node --test tests/**/*.test.js"
  }
  ```
* Lợi ích:
  - Khi chạy `rtk npm test` cho CI/CD: 100% tests chạy là unit/v2 test độc lập (chạy mock, không phụ thuộc internet/Google Gemini API, hoàn tất trong < 3 giây, đạt 100% PASS).
  - Khi cần kiểm thử liên thông thực tế tới Google Gemini API: Chạy lệnh riêng biệt `rtk npm run test:integration`.

#### 2.2. Hoàn thiện bộ bẫy timeout cho `tests/integration/chatbot.api.test.js`:
* Cấu hình `timeout: 60000` (60 giây) cho các bài test tích hợp mạng để tránh bị timeout đột ngột khi Google Gemini phản hồi chậm.

#### 2.3. Kiểm chứng:
* Chạy `rtk npm test` $\rightarrow$ Xác nhận 100% PASS (< 3s).
* Chạy `rtk npm run test:integration` $\rightarrow$ Xác nhận chạy đúng bài test tích hợp khi có nhu cầu.

---

### BƯỚC 3: Đồng Bộ & Nâng Cấp Phiên Bản Flutter Cho Client-app (Vấn đề 1)

#### 3.1. Phân tích hiện trạng:
* Mã nguồn `src/Client-app` yêu cầu Dart SDK `>= 3.13.0` do gói `background_downloader: ^9.6.2` (tải mô hình Edge AI Gemma 4 E2B).
* Máy trạm cục bộ hiện có Flutter `3.44.5` (Dart `3.12.2`).

#### 3.2. Phương án thực hiện:
* **Phương án A (Khuyến nghị chuẩn của dự án):**
  1. Hướng dẫn và hỗ trợ người dùng chạy nâng cấp Flutter SDK máy trạm lên phiên bản `3.47.6` hoặc phiên bản Stable mới nhất:
     ```powershell
     flutter upgrade
     ```
  2. Sau khi nâng cấp hoàn tất:
     ```powershell
     cd d:\Tai_Lieu_IUH\Tailieu_Nam5_HK1\DoAnTotNghiep\Personal_Finance_Management\src\Client-app
     rtk flutter --version
     rtk flutter pub get
     rtk flutter analyze
     ```
  3. Dọn dẹp các cảnh báo nhỏ nếu có sau khi nâng cấp SDK (như `withOpacity` $\rightarrow$ `.withValues()`).

* **Phương án B (Dự phòng qua FVM - Flutter Version Management):**
  - Nếu PO cần giữ Flutter 3.44.5 cho các dự án khác trên máy trạm: Cài đặt `fvm` (`dart pub global activate fvm`) và chạy `fvm use 3.47.6` riêng cho thư mục `src/Client-app`.

---

## 📊 TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| Hạng mục | Tiêu chí nghiệm thu (Exit Criteria) | Phương pháp kiểm chứng |
|---|---|---|
| **CSDL Guard** | Lệnh `npm run prisma:push` và `npm run prisma:migrate` bị chặn đứng khi trỏ vào Supabase Cloud. Lệnh `npm run db:verify-indexes` trả về PASS 5/5 Partial Indexes. | Chạy thử nghiệm các lệnh trong `src/Backend`. |
| **Backend Test Suite** | `rtk npm test` chạy 100% tests nội bộ (unit + v2) đạt 100% PASS trong thời gian $< 5$ giây, không phụ thuộc vào kết nối mạng tới Google Gemini. | Chạy `rtk npm test` và đối soát log. |
| **Test Integration** | `rtk npm run test:integration` chạy riêng biệt bài test chatbot tích hợp mạng. | Chạy `rtk npm run test:integration`. |
| **Flutter Client-app** | Sau khi nâng cấp Flutter SDK, `flutter pub get` thành công 100% không còn lỗi giải quyết dependency của `background_downloader`. | Chạy `flutter pub get` và `flutter analyze`. |

---

## 📌 QUY TRÌNH CHỜ DUYỆT

Theo **RULE 6** của dự án:
> *Kế hoạch trên đã được soạn thảo chi tiết. AI đang ở trạng thái **CHỜ DUYỆT** từ Product Owner (PO) trước khi thực hiện chỉnh sửa mã nguồn và cấu hình.*
