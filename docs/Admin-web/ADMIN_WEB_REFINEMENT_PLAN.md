# 📋 KẾ HOẠCH CHI TIẾT SỬA CHỮA & TINH CHỈNH ADMIN-WEB
> **Dự án:** Personal Finance Management — Module `src/Admin-web` & `src/Backend`  
> **Tài liệu lưu trữ kế hoạch:** `docs/Admin-web/ADMIN_WEB_REFINEMENT_PLAN.md`  
> **Người lập:** Lead BA + Lead FullStack + Lead Tester  
> **Phê duyệt bởi:** Product Owner (PO)  
> **Ngày lập:** 2026-10-20  

---

## 🎯 I. TỔNG QUAN YÊU CẦU & KẾT QUẢ KHẢO SÁT

Theo các issue log thực tế từ PO, hệ thống Admin-web và Backend cần được xử lý 4 nhóm vấn đề trọng điểm:

| STT | Nhóm Issue | Mô tả yêu cầu | Hiện trạng & Nguyên nhân kỹ thuật |
|---|---|---|---|
| **1** | **Bắt buộc Admin đổi mật khẩu & tạo mã PIN lần đầu** | Khi Admin đăng nhập lần đầu, hiển thị Modal bắt buộc (không thể tắt, không backdrop click, không ESC) yêu cầu nhập mật khẩu mới và tạo mã PIN 6 số. Xác nhận xong cập nhật ngay vào CSDL và giữ nguyên phiên làm việc (không bắt login lại). | CSDL chưa có cột `is_first_login`. Admin mới tạo dùng mật khẩu mặc định `123456` và mã PIN `123456` nhưng chưa có cơ chế cưỡng chế đổi bảo mật ở lần đầu. |
| **2** | **Bổ sung Tab Quản lý Admin trong Cài đặt hệ thống** | Thêm tab "Quản lý admin" gồm 3 tính năng: (1) Đổi mã PIN (nhập mật khẩu, mã PIN cũ, mã PIN mới, xác nhận); (2) Đổi mật khẩu (nhập mật khẩu cũ, mã PIN cũ, mật khẩu mới, xác nhận); (3) Cấp tài khoản admin mới (nhập username, email -> xác thực mã PIN của admin đang thao tác -> tạo tài khoản admin mới với pass và pin mặc định 123456, lưu ID admin người cấp). | SettingsModal chưa có tab Quản lý admin; CSDL chưa có cột `created_by_admin_id` để ghi nhận ai là người cấp tài khoản admin; Backend chưa có endpoint cấp admin mới với xác thực PIN. |
| **3** | **Sửa lỗi Auto-lock văng ra màn hình đăng nhập** | Khi hệ thống tự động khóa an toàn sau thời gian nhàn rỗi, người dùng nhập đúng mật khẩu mở khóa nhưng lại bị văng ra trang `/login` thay vì mở lại giao diện hiện tại để tiếp tục làm việc. | **Root cause:** Khi khóa màn hình, token bị xóa. Các background polling (AIOps, Dashboard, ServerHealth) tiếp tục gửi request ngầm -> bị HTTP 401 -> Axios interceptor gọi `handleLogoutRedirect()` ép `window.location.href = '/login'`. |
| **4** | **Thu nhỏ phóng to — Auto co dãn theo sở thích** | Giao diện toàn hệ thống phải tự động co dãn thích ứng mượt mà khi người dùng thu nhỏ / phóng to theo sở thích (zoom trình duyệt 50% - 200%, các kích thước màn hình). | `AppLayout` đang dùng fixed `md:pl-[304px]`, container `max-w-[1440px]`, Sidebar cố định 280px không cho thu gọn linh hoạt trên desktop. Khi zoom to, không gian màn hình bị bóp hẹp gây tràn vỡ bảng và thẻ. |

---

## 🏛️ II. THIẾT KẾ KIẾN TRÚC & TÁC ĐỘNG 2 CHIỀU (DUAL-AXIS IMPACT)

### 1. Suy luận theo chiều ngang (Horizontal Reasoning)
- **CSDL PostgreSQL (Supabase):**
  - Bảng `account`: Thêm cột `is_first_login BOOLEAN NOT NULL DEFAULT TRUE` và `created_by_admin_id INT NULL` (FK tới `account.Idaccount` ON DELETE SET NULL).
  - Khởi tạo: Admin hiện tại (`admin`, `phubaonguyen1802@gmail.com`) được cập nhật `is_first_login = FALSE` để không bị chặn; admin mới tạo sau này mặc định `TRUE`.
  - Bảng `user`: Khi cấp admin mới, tự động tạo bản ghi hồ sơ tương ứng để bảo đảm toàn vẹn quan hệ 1-1 với `account`.
- **Backend API & Middleware:**
  - Route mới:
    + `POST /api/admin/first-login-setup`: Cập nhật mật khẩu mới + mã PIN cho admin đăng nhập lần đầu.
    + `POST /api/admin/change-pin`: Nâng cấp kiểm tra cả mật khẩu hiện tại + mã PIN cũ.
    + `POST /api/admin/change-password`: Đổi mật khẩu có xác thực cả mật khẩu cũ + mã PIN cũ.
    + `POST /api/admin/create-admin`: Cấp tài khoản admin mới kèm xác thực mã PIN của admin người cấp.
  - Auth routes: `auth.service.login` và `/auth/me` trả về cờ `is_first_login`.
- **Admin-web Frontend:**
  - `FirstLoginModal.jsx`: Modal khóa cứng hiển thị khi `user?.is_first_login === true`.
  - `SettingsModal.jsx`: Thêm tab `admin_mgmt` gồm 3 dialog (Đổi PIN, Đổi Mật khẩu, Cấp Admin).
  - `axios-client.js` & `settings.context.jsx`: Chặn `handleLogoutRedirect` khi đang khóa màn hình; tạm dừng background intervals khi `isLocked`.
  - `AppLayout.jsx` & `Sidebar.jsx`: Chuyển sang Responsive Fluid Layout, dynamic sidebar collapse, fluid container, universal scrollable table wrappers.

### 2. Suy luận theo chiều sâu (Vertical / Deep-Impact Reasoning)
- **Zero Regressions:** 
  - Đảm bảo migration dùng `ALTER TABLE ADD COLUMN IF NOT EXISTS`, không phá vỡ Partial Indexes và Triggers (tuân thủ Rule 10 DB Guard).
  - Không làm ảnh hưởng tới luồng người dùng thường (Mobile Client-app không có `idrole = 1`, không bị ảnh hưởng bởi first login modal của admin).
  - Phiên làm việc của Admin được giữ nguyên vẹn sau khi hoàn tất setup lần đầu hoặc mở khóa màn hình.

---

## 📋 III. KẾ HOẠCH TRIỂN KHAI TỪNG BƯỚC (STEP-BY-STEP IMPLEMENTATION)

### 🔹 Giai Đoạn 1: CSDL & Backend Service (DB Migration 34 & APIs)
- [x] **Bước 1.1: Viết Script Migration 34 (`34_add_admin_first_login_and_created_by.sql`)**
  - Thêm cột `is_first_login BOOLEAN NOT NULL DEFAULT TRUE` vào bảng `account`.
  - Thêm cột `created_by_admin_id INT NULL` có khóa ngoại tới `account("Idaccount")`.
  - Cập nhật `is_first_login = FALSE` cho tài khoản Admin hiện có.
- [x] **Bước 1.2: Cập nhật `schema.prisma` & Sinh Prisma Client**
  - Khai báo 2 trường mới trong model `account`.
  - Áp dụng migration bằng script an toàn `apply_migration_34.js` qua `pg` client.
  - Chạy `rtk npm run prisma:generate` và `rtk npm run db:verify-indexes`.
- [x] **Bước 1.3: Cập nhật Auth Service & Controller**
  - Bổ sung `is_first_login` vào payload trả về của `authService.login` và `authController.me`.
- [x] **Bước 1.4: Viết các API Quản trị Admin trong Backend**
  - Triển khai `POST /api/admin/first-login-setup` (validate mật khẩu mới khác 123456, mã PIN 6 số khác 123456, hash bcrypt, tắt cờ `is_first_login`, ghi audit log).
  - Nâng cấp `POST /api/admin/change-pin` (yêu cầu mật khẩu + mã PIN cũ + mã PIN mới 6 số).
  - Triển khai `POST /api/admin/change-password` (yêu cầu mật khẩu cũ + mã PIN cũ + mật khẩu mới).
  - Triển khai `POST /api/admin/create-admin` (xác thực mã PIN của admin người cấp, kiểm tra username/email, tạo `account` + `user` với pass 123456, pin 123456, `is_first_login = true`, lưu `created_by_admin_id`).

### 🔹 Giai Đoạn 2: Frontend — First Login Modal & Sửa Lỗi Auto-Lock
- [x] **Bước 2.1: Sửa triệt để lỗi Auto-Lock văng ra Login**
  - Trong `src/Admin-web/src/api/axios-client.js`: Thêm điều kiện chặn `handleLogoutRedirect()` nếu `localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true'`.
  - Trong `AppLayout.jsx`, `DashboardPage.jsx`, `ServerHealthPanel.jsx`: Kiểm tra `if (isLocked) return;` trước khi gửi background polling API.
  - Trong `settings.context.jsx` (`unlockScreen`): Đảm bảo token được lưu vào `localStorage`, đồng bộ `syncAuthSession` trước khi gỡ cờ khóa và phục hồi trạng thái bình thường.
- [x] **Bước 2.2: Xây dựng Component `FirstLoginModal.jsx`**
  - Hiển thị khi `user?.is_first_login === true`.
  - Khóa chặt modal: không nút tắt, không click backdrop, chặn ESC.
  - Form validation: mật khẩu mới, xác nhận mật khẩu, mã PIN mới (6 số), xác nhận mã PIN.
  - Nút Xác nhận: gọi API `firstLoginSetup`, cập nhật session local, tự đóng modal và hiển thị Toast chào mừng.

### 🔹 Giai Đoạn 3: Frontend — Tab Quản Lý Admin trong Cài Đặt Hệ Thống
- [x] **Bước 3.1: Bổ sung Tab "Quản lý admin" vào `SettingsModal.jsx`**
  - Thêm tab `admin_mgmt` với giao diện thẻ phẳng hiện đại.
- [x] **Bước 3.2: Triển khai Modal Đổi Mã PIN**
  - Form nhập: Mật khẩu hiện tại, mã PIN cũ, mã PIN mới (6 số), xác nhận mã PIN mới.
  - Gọi API `changePin`, thông báo kết quả.
- [x] **Bước 3.3: Triển khai Modal Đổi Mật Khẩu**
  - Form nhập: Mật khẩu cũ, mã PIN cũ, mật khẩu mới, xác nhận mật khẩu mới.
  - Gọi API `changePassword`, thông báo kết quả.
- [x] **Bước 3.4: Triển khai Modal Cấp Tài Khoản Admin**
  - Bước 1: Nhập `username` và `email`.
  - Bước 2: Modal xác thực mã PIN của Admin hiện tại.
  - Gọi API `createAdmin`, hiển thị thông tin tài khoản vừa tạo (mật khẩu mặc định 123456, mã PIN mặc định 123456, nhắc nhở sẽ đổi ở lần đầu đăng nhập).

### 🔹 Giai Đoạn 4: Frontend — Tinh Chỉnh Thu Nhỏ Phóng To (Responsive Fluid Layout)
- [x] **Bước 4.1: Tối ưu Dynamic Sidebar & Canvas Padding**
  - Cho phép Sidebar thu gọn linh hoạt trên desktop (chế độ mini 76px hoặc đầy đủ 260px).
  - `main` canvas tự động điều chỉnh padding theo trạng thái Sidebar: `sidebarCollapsed ? 'md:pl-[92px]' : 'md:pl-[276px]'`.
- [x] **Bước 4.2: Tối ưu Fluid Containers & Breakpoints**
  - Đổi `max-w-[1440px]` cố định thành `w-full max-w-[1720px] mx-auto px-3 sm:px-4 md:px-6`.
  - Khi zoom out (50% - 80%): Giao diện mở rộng tự nhiên.
  - Khi zoom in (125% - 200%): Các cột bento-grid và dashboard cards tự động gộp dòng (`auto-fit, minmax(260px, 1fr)`).
- [x] **Bước 4.3: Chuẩn hóa Scrollable Wrappers cho toàn bộ Bảng Dữ Liệu**
  - Rà soát các bảng dữ liệu (Users, Payments, Audit Logs, AIOps, Broadcast, Dashboard): đảm bảo 100% bọc trong container `overflow-x-auto` mượt mà, không làm tràn khung trang khi zoom lớn.

### 🔹 Giai Đoạn 5: Kiểm Thử 2 Tầng (2-Tier Testing), Xác Minh & Cập Nhật CodeGraph
- [x] **Bước 5.1: Viết bài test 2 tầng cho First Login Modal**
  - Tầng 1: Render form đầy đủ, chặn tắt modal, nhập validation.
  - Tầng 2: Gọi API cập nhật CSDL, cập nhật session, tắt modal mà không reload trang.
- [x] **Bước 5.2: Viết bài test 2 tầng cho Quản lý Admin (Đổi PIN, Đổi Pass, Cấp Admin)**
  - Tầng 1: Click nút mở từng modal, nhập dữ liệu.
  - Tầng 2: Backend hash mật khẩu/PIN, tạo tài khoản admin mới với `created_by_admin_id` chuẩn xác.
- [x] **Bước 5.3: Viết bài test 2 tầng cho Auto-Lock Screen Recovery**
  - Tầng 1: Giao diện khóa, nhập mật khẩu mở khóa.
  - Tầng 2: Không bị redirect về `/login`, giữ nguyên URL và state hiện tại.
- [x] **Bước 5.4: Chạy toàn bộ test suites (`rtk npm test`)**
- [x] **Bước 5.5: Cập nhật tài liệu nguồn sự thật (`Project.md`) & chạy `rtk npx codegraph build`**

---

## 🧪 IV. TIÊU CHÍ NGHIỆM THU ĐO LƯỜNG ĐƯỢC (ACCEPTANCE CRITERIA)

1. **First Login Modal:**
   - Admin mới tạo khi đăng nhập lần đầu bắt buộc phải thấy modal thiết lập mật khẩu & mã PIN.
   - Không thể tắt modal dưới mọi hình thức trước khi điền hợp lệ.
   - Khi bấm Xác nhận: Cập nhật thành công vào CSDL, phiên làm việc giữ nguyên, modal tắt và tiếp tục dùng web bình thường.
2. **Tab Quản lý Admin:**
   - Tab "Quản lý admin" hiển thị rõ ràng trong Settings.
   - Đổi mã PIN đòi hỏi đúng cả mật khẩu và mã PIN cũ.
   - Đổi mật khẩu đòi hỏi đúng cả mật khẩu cũ và mã PIN cũ.
   - Cấp tài khoản admin yêu cầu xác thực mã PIN của admin người cấp; tài khoản mới được tạo có pass & pin 123456, `is_first_login = true`, lưu đúng `created_by_admin_id`.
3. **Mở khóa Auto-lock:**
   - Khi nhàn rỗi bị khóa màn hình, nhập đúng mật khẩu thì mở khóa ngay tại trang hiện tại, tuyệt đối KHÔNG bị văng về `/login`.
4. **Thu nhỏ / Phóng to:**
   - Khi phóng to trình duyệt tới 150%, 175%, 200% hoặc thu nhỏ 75%, 50%: giao diện không bị vỡ layout, sidebar thu gọn mượt mà, các bảng có thanh cuộn ngang mượt mà.
5. **Chất lượng:**
   - 100% test cases Pass (cả Tầng 1 và Tầng 2).
   - CodeGraph đã được build cập nhật đầy đủ.
