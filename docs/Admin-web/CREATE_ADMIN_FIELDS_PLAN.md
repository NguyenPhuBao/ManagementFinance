# Kế Hoạch Triển Khai: Mở Rộng Các Trường Cấp Tài Khoản Admin (Create Admin Account Fields)

> **Mã kế hoạch:** PLAN-ADMIN-CREATE-001  
> **Áp dụng theo:** Bộ quy tắc cứng cao nhất (AGENTS.md), Quy tắc 2 Tầng (Rule 11), Data Security (Rule 9), DB Guard (Rule 10).  
> **Mục tiêu:** Cập nhật bảng/modal "Cấp Tài Khoản Admin" bổ sung 4 trường nghiệp vụ mới: FullName, Phone, Address, Country code; đảm bảo Username, Email, FullName, Phone là bắt buộc; đồng bộ từ Frontend UI -> Backend Controller/Service/Repository -> CSDL PostgreSQL có mã hóa an toàn.

---

## 1. Phân Tích Hiện Trạng & Khảo Sát Hệ Thống (Horizontal & Vertical Reasoning)

### 1.1. Hiện trạng Frontend
- Modal **Cấp Tài Khoản Admin** nằm trong [`src/Admin-web/src/components/layout/SettingsModal.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/components/layout/SettingsModal.jsx).
- Luồng cấp tài khoản hiện tại qua 2 bước:
  - **Bước 1/2:** Chỉ có 2 trường `username` (Tên đăng nhập) và `email` (Email quản trị viên).
  - **Bước 2/2:** Nhập mã PIN 6 chữ số của Admin hiện tại để phê duyệt ủy quyền.
  - **Bước 3 (Thành công):** Hiển thị kết quả tài khoản đã cấp kèm mật khẩu và PIN mặc định `123456`.
- **Thiếu sót:** Chưa thu thập thông tin nhân thân quản trị viên gồm Họ tên (`FullName`), Số điện thoại (`Phone`), Địa chỉ (`Address`), Mã quốc gia (`Country code`).

### 1.2. Hiện trạng Backend & CSDL (PostgreSQL Cloud Supabase)
- **Model `User` trong CSDL PostgreSQL** ([`schema.prisma`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/prisma/schema.prisma)):
  - `fullname`: `String @db.VarChar(100)` (Đã có sẵn).
  - `email`: `String @unique @db.VarChar(100)` (Đã có sẵn).
  - `phone`: `String? @db.VarChar(256)` (Đã có sẵn).
  - `address`: `String? @db.Text` (Đã có sẵn).
  - `country_code`: `String? @db.Char(4)` (Đã có sẵn, tối đa 4 ký tự ví dụ `+84`).
- **Ràng buộc an ninh & DB Triggers (Data_Security.md & Rule 9, 10):**
  - Database có Trigger bảo mật pháp lý: `trg_check_phone_encrypted` trên bảng `user`.
  - **Trigger CSDL sẽ throw Exception ngay lập tức** nếu `phone` được ghi dưới dạng plaintext (chuỗi số thuần 7-15 chữ số).
  - Do đó, số điện thoại (`phone`) và địa chỉ (`address`) **bắt buộc phải được mã hóa AES-256-GCM** (tiền tố `enc:`) thông qua [`src/Backend/utils/crypto.util.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/utils/crypto.util.js) trước khi insert vào CSDL!
- **Repository Backend hiện tại:**
  - [`src/Backend/modules/admin/admin.repository.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/admin/admin.repository.js): Hàm `createAdminAccount` đang gán cứng `fullname: 'Quản trị viên ' + username`, bỏ trống `phone`, `address`, `country_code`. Cần cập nhật để nhận và lưu đầy đủ 4 trường mới kèm mã hóa.
- **Service Backend hiện tại:**
  - [`src/Backend/modules/admin/admin.service.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/admin/admin.service.js): Hàm `createAdminAccount` mới chỉ validate `username`, `email`, `pin`. Cần bổ sung validation: `fullName` (bắt buộc, >= 2 ký tự), `phone` (bắt buộc, 9-15 ký tự số), `countryCode` (tùy chọn, tối đa 4 ký tự, mặc định `+84`), `address` (tùy chọn).

---

## 2. Chi Tiết Các Hạng Mục Cần Triển Khai

### Task 1: Backend — Validation & Persistence Mã Hóa An Toàn
1. **`src/Backend/modules/admin/admin.service.js`:**
   - Cập nhật hàm `createAdminAccount(data, currentUser)`:
     - Nhận các trường: `username`, `email`, `pin`, `fullName`, `phone`, `address`, `countryCode`.
     - Hỗ trợ linh hoạt cả `fullName`/`fullname`, `countryCode`/`country_code`.
     - Kiểm tra bắt buộc:
       + `fullName`: Bắt buộc, tối thiểu 2 ký tự, tối đa 100 ký tự.
       + `phone`: Bắt buộc, định dạng hợp lệ (9 - 15 chữ số).
       + `countryCode`: Mặc định `+84` nếu để trống, tối đa 4 ký tự.
       + `address`: Chuỗi tùy chọn.
     - Ghi Audit Log chi tiết có gắn tên quản trị viên và số điện thoại đã che giấu (masking).
2. **`src/Backend/modules/admin/admin.repository.js`:**
   - Cập nhật hàm `createAdminAccount`:
     - Nhận `fullName`, `phone`, `address`, `countryCode`.
     - Thực hiện mã hóa `encPhone = encrypt(phone)` và `encAddress = address ? encrypt(address) : null` tuân thủ trigger `trg_check_phone_encrypted`.
     - Lưu vào `tx.User.create`.
     - Trả về đối tượng quản trị viên đã tạo kèm `phone` và `address` đã được format rõ cho client.
3. **`src/Backend/tests/unit/admin.security.refinement.test.js`:**
   - Cập nhật unit test `createAdminAccount` kiểm tra validation bắt buộc của `fullName`, `phone` và lưu thành công.

---

### Task 2: Frontend — Thiết Kế Form & Trải Nghiệm Người Dùng (Admin-web)
1. **Mở rộng State Form trong `SettingsModal.jsx`:**
   ```javascript
   const [createAdminForm, setCreateAdminForm] = useState({
     username: '',
     email: '',
     fullName: '',
     phone: '',
     address: '',
     countryCode: '+84',
     pin: '',
   });
   ```
2. **Nâng cấp Bố Cục Giao Diện Modal (Bước 1/2):**
   - Mở rộng kích thước modal từ `max-w-md` (448px) lên `max-w-lg` (512px) để form thoáng đãng, sang trọng.
   - Bố cục lưới 2 cột khoa học:
     - **Hàng 1 (2 cột):**
       + Cột trái: *Họ và tên quản trị viên* (`fullName` *)
       + Cột phải: *Tên đăng nhập mới* (`username` *)
     - **Hàng 2:**
       + *Email quản trị viên* (`email` *)
     - **Hàng 3 (2 cột kết hợp):**
       + Cột trái (1/3): *Mã vùng / Quốc gia* (`countryCode`, mặc định `+84`)
       + Cột phải (2/3): *Số điện thoại liên hệ* (`phone` *)
     - **Hàng 4:**
       + *Địa chỉ liên hệ* (`address`, tùy chọn)
     - **Hàng 5:**
       + Hộp thông tin khởi tạo mật khẩu & PIN mặc định (123456).
3. **Cập nhật Bước 2/2 (Xác thực PIN):**
   - Hiển thị tóm tắt đầy đủ: Tài khoản, Họ tên, Email, SĐT (`+84 ...`), Địa chỉ.
4. **Cập nhật Bước 3 (Kết quả thành công):**
   - Hiển thị đầy đủ Họ tên, Username, Email, Phone của quản trị viên vừa được cấp.
5. **Đa ngôn ngữ (i18n):**
   - Bổ sung các nhãn, placeholder và lỗi tương ứng vào [`src/Admin-web/src/locales/vi.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/locales/vi.js) và [`src/Admin-web/src/locales/en.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/locales/en.js).

---

### Task 3: Kiểm Thử 2 Tầng (Rule 11) & Hồi Quy Toàn Bộ Hệ Thống
1. **Tạo Test Suite chuyên sâu: `src/Admin-web/src/tests/create-admin-fields.2tier.test.jsx`:**
   - **Tầng 1 (UI Rendering & Interaction):**
     - [x] Hiển thị đầy đủ 6 controls: `fullName`, `username`, `email`, `countryCode`, `phone`, `address`.
     - [x] Hiển thị ký hiệu bắt buộc `*` cho `Username`, `Email`, `FullName`, `Phone`.
     - [x] Validation chặn chuyển bước khi bỏ trống `FullName`, `Phone`, `Username`, hoặc `Email`.
     - [x] Validation chặn số điện thoại sai định dạng.
   - **Tầng 2 (Real System Impact & Persistence):**
     - [x] Nhập đầy đủ 6 trường hợp lệ -> Chuyển sang Bước 2 hiển thị đúng bản tóm tắt.
     - [x] Nhập PIN -> Gửi API `adminApi.createAdmin` với đầy đủ payload `{ username, email, fullName, phone, address, countryCode, pin }`.
     - [x] Nhận phản hồi thành công -> Hiển thị màn hình hoàn tất kèm thông tin chi tiết.
2. **Kiểm thử hồi quy:**
   - Chạy `src/Admin-web/src/tests/admin.refinement.2tier.test.jsx`.
   - Chạy `src/Backend/tests/unit/admin.security.refinement.test.js`.
   - Chạy toàn bộ test suite Backend 421 tests.

---

### Task 4: Cập Nhật Tài Liệu & Đồng Bộ CodeGraph (Rule 8)
1. Cập nhật tài liệu [`docs/Admin-web/01-authentication-and-authorization.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Admin-web/01-authentication-and-authorization.md) ghi nhận các trường mở rộng của API cấp tài khoản Admin.
2. Chạy `rtk npx codegraph build` đồng bộ CodeGraph trước khi hoàn thành.
