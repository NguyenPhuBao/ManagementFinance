# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH & SỬA LỖI TRANG QUẢN LÝ NGƯỜI DÙNG (ADMIN-WEB)
> **Dự án:** Personal Finance Management — Module `src/Admin-web` & `src/Backend`  
> **Tài liệu nguồn sự thật kế hoạch:** `docs/Admin-web/USERS_REFINEMENT_PLAN.md`  
> **Người lập:** Lead BA + Lead FullStack cao cấp + Lead Tester  
> **Phê duyệt bởi:** Product Owner (PO)  
> **Ngày lập:** 2026-10-21  

---

## 🎯 I. TỔNG QUAN YÊU CẦU & KẾT QUẢ KHẢO SÁT THỰC TẾ

Dựa trên khảo sát thực tế tại URL `https://management-finance-gamma.vercel.app/users`, ảnh chụp màn hình thực tế và kiểm tra mã nguồn tại `src/Admin-web/src/pages/users/UserListPage.jsx`, các vấn đề được xác định nguyên nhân kỹ thuật chi tiết như sau:

| STT | Vị trí / Thành phần | Yêu cầu từ PO | Hiện trạng & Nguyên nhân kỹ thuật | Giải pháp kỹ thuật |
|---|---|---|---|---|
| **1** | **Header trang Quản lý người dùng** | - Bỏ nút nhỏ *"Realtime Sync"* (không cần thiết).<br>- Bỏ dòng ghi chú phụ đề: *"Giám sát người dùng, kiểm soát trạng thái kích hoạt và bảo vệ quyền riêng tư theo Nghị định 13/2023/NĐ-CP"*.<br>- Bỏ icon *"manage_accounts"*. | Trong `UserListPage.jsx` (dòng 371-389):<br>- Icon `manage_accounts` nằm trong ô bo góc `w-12 h-12`.<br>- Badge `Realtime Sync` nhấp nháy xanh lá.<br>- Thẻ `<p>{t('users.subtitle')}</p>` phụ đề dài chiếm diện tích. | Loại bỏ icon `manage_accounts`, badge `Realtime Sync` và thẻ phụ đề `<p>`. Giữ lại tiêu đề trang `Quản lý người dùng` và nút `Làm mới` (Refresh) tinh gọn, thanh thoát. |
| **2** | **Tên mục Lọc Gói dịch vụ / Membership (i18n)** | Hiển thị là *"Gói dịch vụ"* khi chọn ngôn ngữ tiếng Việt (`vi`) và *"Membership"* khi chọn tiếng Anh (`en`). | Trong `UserListPage.jsx` (dòng 744), nhãn trường lọc đang bị hardcode tĩnh: `<label>Gói dịch vụ / Membership</label>`. Các thẻ `<option>` cũng bị hardcode tiếng Việt xen lẫn tiếng Anh. Cả `vi.js` và `en.js` chưa khai báo key `packageLabel`, `allPackages`, `basicPackage`, `premiumPackage`. | - Bổ sung key ngôn ngữ vào `src/Admin-web/src/locales/vi.js` và `en.js`.<br>- Cập nhật JSX dùng `{t('users.filterModal.packageLabel')}` và các thẻ `<option>` theo ngôn ngữ tương ứng. |
| **3** | **Sửa lỗi lọc Gói dịch vụ (Premium / Basic)** | Tài khoản `BaoNP` (`phubao9as@gmail.com`) trong CSDL có gói `Premium`, nhưng khi chọn lọc gói VIP (Premium) thì danh sách không lọc được và ra 0 kết quả.<br>*Định hướng PO:* Khi nạp dữ liệu thì nạp toàn bộ thông tin người dùng nhưng ẩn ngầm phía dưới giao diện (không cần hiện cột trên bảng), khi áp dụng bộ lọc thì lọc chuẩn xác theo gói của tài khoản. | - **Root Cause:** Backend `/admin/getuser` có trả về `type: "Premium"` hoặc `"Basic"`. Tuy nhiên, trong hàm `fetchUsers()` của `UserListPage.jsx` (dòng 100-113), khi map dữ liệu từ API về state, code đã **bỏ sót không map trường `type`** (`u.type` bị undefined).<br>- Hệ quả: Hàm `filteredUsers` khi chạy `(u.type || u.package || 'Basic')` luôn fallback về `'Basic'` cho 100% người dùng. Khi admin chọn lọc gói `Premium`, không có bản ghi nào khớp! | - Bổ sung map `type: u.type || 'Basic'` vào cả `fetchUsers()` và luồng Socket `handleUserRegistered`.<br>- Dữ liệu gói cước được giữ nguyên trong state dữ liệu ngầm (xem được trong modal Chi tiết khi bấm 👁️), không hiển thị thêm cột trên bảng.<br>- Hàm lọc `filteredUsers` so sánh chuẩn xác `filter.packageType` với `u.type` (case-insensitive). |

---

## 🏛️ II. PHÂN TÍCH TÁC ĐỘNG THEO 2 CHIỀU (DUAL-AXIS REASONING)

### 1. Suy luận theo chiều ngang (Horizontal Reasoning)
- **Module Frontend `src/Admin-web`:**
  - `src/Admin-web/src/locales/vi.js` & `en.js`: Bổ sung dịch thuật chuẩn hóa cho `users.filterModal`.
  - `src/Admin-web/src/pages/users/UserListPage.jsx`:
    + Tinh chỉnh gọn gàng Header (bỏ icon, bỏ phụ đề, bỏ badge).
    + Sửa mapping state `users` bổ sung `type`.
    + Đa ngôn ngữ hóa dropdown lọc gói cước.
  - `src/Admin-web/src/components/common/UserDetailModal.jsx`: Giữ nguyên tính năng hiển thị badge `Gói dịch vụ` (`Basic`/`Premium`) khi bấm xem chi tiết người dùng.
- **Module Backend `src/Backend`:**
  - Backend API `GET /admin/getuser` đã có sẵn trường `type: u.account ? (u.account.type || 'Basic') : 'Basic'` từ `admin.service.js`. Không cần chỉnh sửa Backend, đảm bảo tính ổn định và tính tương thích cao.

### 2. Suy luận theo chiều sâu (Vertical / Deep-Impact Reasoning)
- **Zero Regressions & An toàn dữ liệu CSDL (DB Guard Rule 10):**
  - Không thay đổi bảng CSDL, không vi phạm cấu trúc Partial Indexes hay Triggers.
  - Tôn trọng nguyên tắc bảo mật thông tin (Data Security `Data_Security.md`): Số điện thoại tiếp tục được che mờ (`maskPhone`), email được che mờ theo chuẩn an toàn.
  - Bộ lọc hoạt động phía client (client-side in-memory filter) trên tập dữ liệu đã fetch, phản hồi tức thì với độ trễ 0ms, không gây tăng tải request về Database Supabase.
  - Khi người dùng đăng ký mới qua Socket `user_registered`, state ngầm lập tức cập nhật đúng `type` để bộ lọc hoạt động tức thời mà không cần reload trang.

---

## 📋 III. KẾ HOẠCH TRIỂN KHAI CHI TIẾT TỪNG BƯỚC

### 🔹 Giai đoạn 1: Chuẩn hóa Đa ngôn ngữ (i18n) cho Bộ Lọc Gói Cước
- [x] **Bước 1.1:** Cập nhật `src/Admin-web/src/locales/vi.js`:
  - Thêm vào `users.filterModal`:
    ```javascript
    packageLabel: 'Gói dịch vụ',
    allPackages: 'Tất cả gói cước',
    basicPackage: 'Gói Cơ bản (Basic)',
    premiumPackage: 'Gói VIP (Premium)',
    ```
- [x] **Bước 1.2:** Cập nhật `src/Admin-web/src/locales/en.js`:
  - Thêm vào `users.filterModal`:
    ```javascript
    packageLabel: 'Membership',
    allPackages: 'All Packages',
    basicPackage: 'Basic Package',
    premiumPackage: 'VIP (Premium) Package',
    ```

### 🔹 Giai đoạn 2: Tinh chỉnh Giao diện Header & Khắc phục Lỗi Lọc Gói Cước
- [x] **Bước 2.1:** Chỉnh sửa `src/Admin-web/src/pages/users/UserListPage.jsx` - Khối Header:
  - Xóa thẻ `div` bọc icon `manage_accounts`.
  - Xóa badge `Realtime Sync`.
  - Xóa thẻ `<p>{t('users.subtitle')}</p>`.
  - Giữ lại tiêu đề `<h2>{t('users.title')}</h2>` và nút "Làm mới".
- [x] **Bước 2.2:** Cập nhật hàm `fetchUsers` và `handleUserRegistered`:
  - Bổ sung `type: u.type || 'Basic'` vào object được map.
- [x] **Bước 2.3:** Cập nhật Modal Lọc (`modals.filter`):
  - Thay nhãn tĩnh bằng `{t('users.filterModal.packageLabel')}`.
  - Thay các `<option>` bằng `{t('users.filterModal.allPackages')}`, `{t('users.filterModal.basicPackage')}`, `{t('users.filterModal.premiumPackage')}`.

### 🔹 Giai đoạn 3: Kiểm thử 2 Tầng (2-Tier Testing Architecture - Rule 11) & Build Verification
- [x] **Bước 3.1:** Viết bộ test 2 tầng mới `src/Admin-web/src/tests/users.refinement.2tier.test.jsx`:
  - **Tầng 1 (UI Rendering & Interaction):**
    + Header render sạch sẽ, không còn icon `manage_accounts`, không còn badge `Realtime Sync`, không còn subtitle.
    + Mở modal Lọc: Nhãn hiển thị đúng `Gói dịch vụ` khi ngôn ngữ là `vi`, và `Membership` khi ngôn ngữ là `en`.
    + Các tùy chọn trong dropdown gói cước hiển thị đầy đủ và tương tác mượt mà.
  - **Tầng 2 (Real System Impact & Behavioral Verification):**
    + Nạp danh sách người dùng mẫu có cả Basic và Premium (ví dụ tài khoản `BaoNP`).
    + Khi chọn lọc `Gói VIP (Premium)` và nhấn "Áp dụng": Chỉ hiển thị đúng các tài khoản Premium (bao gồm `BaoNP`), các tài khoản Basic bị ẩn khỏi danh sách.
    + Khi chọn lọc `Gói Cơ bản (Basic)`: Chỉ hiển thị các tài khoản Basic, tài khoản Premium bị ẩn.
    + Khi nhấn "Đặt lại": Danh sách khôi phục đầy đủ toàn bộ người dùng.
- [x] **Bước 3.2:** Chạy toàn bộ test suite của Admin-web (`rtk npm test` hoặc `rtk npx vitest run` - 38/38 pass).
- [x] **Bước 3.3:** Kiểm tra production build (`rtk npm run build` - 0 lỗi).
- [x] **Bước 3.4:** Cập nhật Nguồn Sự Thật (`Project.md`) và xây dựng lại CodeGraph (`rtk npx codegraph build`) theo Rule 8.

---

## 🧪 IV. TIÊU CHÍ NGHIỆM THU 2 TẦNG (2-TIER ACCEPTANCE CRITERIA)

### 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering)
1. **Header:** Không còn icon `manage_accounts`, không còn chữ `Realtime Sync`, không còn dòng chú thích Nghị định 13/2023/NĐ-CP.
2. **Modal Lọc (Tiếng Việt):** Nhãn dropdown hiển thị là **"GÓI DỊCH VỤ"**.
3. **Modal Lọc (Tiếng Anh):** Nhãn dropdown hiển thị là **"MEMBERSHIP"**.
4. **Bảng người dùng:** Giữ nguyên cấu trúc giao diện sạch sẽ (5 cột chuẩn), không bị xáo trộn layout.

### ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (System Impact & Filtering)
1. **Lọc Gói VIP (Premium):** Khi chọn `Gói VIP (Premium)` và Áp dụng, hệ thống lọc chính xác tài khoản `BaoNP` (`phubao9as@gmail.com`) và các tài khoản Premium khác trong CSDL; các tài khoản Basic bị ẩn.
2. **Lọc Gói Cơ bản (Basic):** Khi chọn `Gói Cơ bản (Basic)` và Áp dụng, hệ thống lọc đúng các tài khoản Basic; tài khoản `BaoNP` bị ẩn.
3. **Lọc Tất cả (All):** Khi chọn `Tất cả gói cước`, hệ thống hiển thị toàn bộ người dùng.
4. **Zero Regressions:** Các bộ lọc trạng thái (Hoạt động, Vô hiệu hóa, Chờ xóa, Đã xóa) và chức năng xem chi tiết 👁️, khóa/xóa tài khoản vẫn hoạt động trơn tru 100%.
