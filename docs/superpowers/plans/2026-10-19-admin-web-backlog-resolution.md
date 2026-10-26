# Kế Hoạch Toàn Diện: Giải Quyết Các Vấn Đề Tồn Đọng Admin-Web & Backend

> **Dành cho Agentic Workers:** Yêu cầu sử dụng sub-skill `superpowers:subagent-driven-development` để thực thi từng task. Mỗi task tuân thủ quy tắc **TDD (Test-Driven Development)** và **Test 2 Tầng (UI Rendering & Real System Impact)** theo Rule 11.

**Mục tiêu (Goal):** Khảo sát, xác thực toàn bộ nguyên nhân gốc rễ và triển khai giải pháp dứt điểm cho 7 nhóm vấn đề tồn đọng tại `Admin-web` và `Backend`, nâng tầm trải nghiệm quản trị, bảo mật và tính chính xác của dữ liệu hệ thống.

**Kiến trúc tổng thể (Architecture):**
Hệ thống kết hợp giữa Frontend React (Admin-web) và Backend Node.js/Express. Các tương tác bảo mật chí mạng (Hoàn tiền, Xóa người dùng, Bảo trì khẩn cấp) được bảo vệ bằng tầng xác thực lại (Re-authentication PIN/Password). Chỉ số phần cứng máy chủ được nhận diện tự động theo môi trường (Cloud cgroup v1/v2 vs Local Host). Giao diện quản lý được tinh giản, dữ liệu cá nhân (SĐT) được che mờ (masking) theo chuẩn pháp lý, và dữ liệu kiểm toán/giao dịch được hỗ trợ xuất báo cáo CSV chuẩn UTF-8 BOM.

```mermaid
graph TD
    subgraph "Admin-web (Frontend)"
        A[LockScreen Overlay] -->|Unlock + Sync Session| B[AuthContext & ProtectedRoute]
        C[Critical Action: Refund / Soft Delete / Maint] -->|Yêu cầu xác nhận| D[SecurityConfirmModal: PIN / Pass]
        E[UserListPage] -->|Bộ lọc CSDL: Type/Status/Time| F[Masking SĐT: 098****321]
        G[PermissionsPage Drawer] -->|Chỉ cấu hình Trụ 3| H[Scope JSON Editor]
        I[AuditLog & Payments] -->|Export UTF-8 BOM| J[File CSV Export]
        K[AIOps Sentinel] -->|Thủ công + Bộ lọc| L[Manual Quarantine IP/Account]
    end

    subgraph "Backend (Node.js & Resilience)"
        M[SystemHardwareMonitor] -->|Detect cgroups v1/v2 vs os.cpus| N[Cloud vs Host Metrics]
        O[Admin Service / SLA] -->|Uptime thực tế SLA 99.9%| P[System Health API]
        Q[AIOps Engine] -->|Threat Score: 0 -> 100| R[Anomaly Stream Socket.io]
        S[AuditLog Format] -->|Prefix [AUTH], [PAYMENT], [USER]| T[Realtime Activity Feed]
    end

    D -->|Verify PIN/Pass API| S
    N -->|Socket nhịp tim 3s| K
```

**Tech Stack:** React 19, Tailwind CSS, Lucide / Material Symbols, Node.js, Express, Prisma ORM, Socket.io, Vitest, Jest.

## Global Constraints
- Tuân thủ 100% `Rule 11`: Mọi tính năng đều có **Test 2 Tầng** (Tầng 1: UI Rendering & Interaction; Tầng 2: Real System Impact & Persistence).
- Tuân thủ `Rule 9` & `Data_Security.md`: Che mờ số điện thoại (giữ 3 đầu + 3 cuối, che 4 số giữa `098****321`), không log plaintext credentials.
- Tuân thủ `Rule 2`: Mọi lệnh shell/CLI đều sử dụng tiền tố `rtk`.
- Tuân thủ `Rule 10`: DB Guard bảo vệ CSDL Supabase, không tự ý sửa đổi schema hay chạy migrate bừa bãi.

---

## Task 1: Khắc Phục Lỗi Khóa Màn Hình (Auto-lock / Screen Lock) Bị Out Ra Login

### Khảo sát & Xác thực nguyên nhân gốc rễ (Root Cause):
- Trong `src/Admin-web/src/store/settings.context.jsx`, hàm `lockScreen()` xóa `ACCESS_TOKEN` khỏi `localStorage`, làm `AuthContext.isAuthenticated` trở thành `false`.
- Khi người dùng nhập đúng mật khẩu mở khóa trong `LockScreen.jsx`, hàm `unlockScreen(password)` gọi `authApi.login()` thành công và lưu lại token vào `localStorage`, đồng thời set `isLocked = false`.
- **Tuy nhiên**, `unlockScreen` KHÔNG hề cập nhật state session vào `AuthContext` (`setUser`, `setIsAuthenticated(true)`). Khi modal khóa ẩn đi, `ProtectedRoute.jsx` phát hiện `isAuthenticated === false` nên lập tức điều hướng (redirect) người dùng về `/login`!

### Giải pháp kỹ thuật:
1. Mở rộng `AuthContext` trong `src/Admin-web/src/store/auth.context.jsx` để cung cấp hàm `syncAuthSession(userData, accessToken, refreshToken)`.
2. Trong `src/Admin-web/src/store/settings.context.jsx`, import và gọi `syncAuthSession` sau khi `authApi.login()` thành công trong `unlockScreen`, đảm bảo `AuthContext` giữ trạng thái `isAuthenticated = true`.
3. Giữ nguyên trang hiện tại của admin sau khi mở khóa thay vì bị đá về login.

**Files:**
- Modify: `src/Admin-web/src/store/auth.context.jsx`
- Modify: `src/Admin-web/src/store/settings.context.jsx`
- Test: `src/Admin-web/src/tests/lockscreen.session.test.jsx`

- [x] **Step 1: Viết test 2 tầng cho LockScreen Session Recovery**
  - Tầng 1: Hiển thị Modal LockScreen, nhập mật khẩu admin và bấm "Mở Khóa Màn Hình".
  - Tầng 2: Xác nhận `AuthContext.isAuthenticated` được giữ `true`, `localStorage` có token hợp lệ và KHÔNG bị điều hướng về `/login`.
- [x] **Step 2: Chạy test kiểm tra trạng thái Red (Fail)**
- [x] **Step 3: Triển khai `syncAuthSession` trong `auth.context.jsx` và tích hợp vào `unlockScreen` trong `settings.context.jsx`**
- [x] **Step 4: Chạy lại test đảm bảo Green (Pass)**
- [x] **Step 5: Commit `fix: resolve lockscreen unlock redirecting to login page`**

---

## Task 2: Đo Lường Chỉ Số Phần Cứng Máy Chủ (Cloud vs Local / Bare-metal Host)

### Khảo sát & Xác thực nguyên nhân gốc rễ (Root Cause):
- Trong `src/Backend/core/resilience/system-hardware-monitor.js` và `src/Backend/modules/admin/admin.service.js`, hệ thống đang đọc trực tiếp `os.cpus()` và `os.totalmem()`.
- Trên các nền tảng Cloud / Container (Render, Docker, Railway, AWS ECS, Kubernetes), `os.cpus()` trả về số core của máy chủ vật lý mẹ (ví dụ 32 cores, 64 cores) chứ không phản ánh đúng Quota được cấp phát (ví dụ gói Free/Standard chỉ có 0.5 CPU hoặc 1 vCPU). Tương tự, `os.totalmem()` trả về 128GB RAM của Host mẹ thay vì giới hạn 512MB RAM của container, khiến tỷ lệ % RAM đo được bị sai lệch hoàn toàn và không cảnh báo được nguy cơ OOMKilled (Out Of Memory)!

### Giải pháp kỹ thuật:
1. Xây dựng module nhận diện môi trường thông minh `src/Backend/core/resilience/runtime-environment.js`:
   - Kiểm tra các biến môi trường đặc trưng của Cloud: `RENDER`, `RAILWAY_ENVIRONMENT`, `VERCEL`, `AWS_EXECUTION_ENV`, `CONTAINER`, hoặc `SERVER_RUNTIME=cloud`.
   - Nếu là Cloud Container chạy Linux: đọc quota tài nguyên thực tế từ hệ thống Linux cgroups:
     - **cgroup v2:** Đọc CPU quota từ `/sys/fs/cgroup/cpu.max` (tỷ lệ quota / period) và RAM limit từ `/sys/fs/cgroup/memory.max`.
     - **cgroup v1:** Đọc từ `/sys/fs/cgroup/cpu/cpu.cfs_quota_us` và `/sys/fs/cgroup/memory/memory.limit_in_bytes`.
     - Cho phép ghi đè cấu hình qua ENV: `CLOUD_CPU_CORES`, `CLOUD_RAM_LIMIT_MB` nếu nhà cung cấp cloud ẩn cgroups.
   - Nếu là Môi trường Local / Máy chủ vật lý riêng (Bare-metal Host): Sử dụng `os.cpus()` và `os.totalmem()`.
2. Cập nhật `SystemHardwareMonitor`:
   - Trả về trường `environment`: `{ type: 'cloud' | 'local' | 'host', provider: 'Render' | 'Docker' | 'Host', isContainer: boolean }`.
   - Tính toán `ramPercent` và `cpuCores` theo quota thực tế của gói Cloud đang chạy.
3. Cập nhật `ServerHealthPanel.jsx` trên Admin-web:
   - Hiển thị badge môi trường: `[☁️ Cloud Container: 1 vCPU / 512 MB]` hoặc `[🖥️ Bare-metal Host: 8 Cores / 16 GB]`.

**Files:**
- Create: `src/Backend/core/resilience/runtime-environment.js`
- Modify: `src/Backend/core/resilience/system-hardware-monitor.js`
- Modify: `src/Backend/modules/admin/admin.service.js`
- Modify: `src/Admin-web/src/components/common/ServerHealthPanel.jsx`
- Test: `src/Backend/tests/runtime-environment.test.js`
- Test: `src/Admin-web/src/tests/server-health-environment.test.jsx`

- [x] **Step 1: Viết test Backend cho `runtime-environment.js` (detect cgroups & env fallback)**
- [x] **Step 2: Triển khai `runtime-environment.js` và tích hợp vào `SystemHardwareMonitor`**
- [x] **Step 3: Viết test 2 tầng cho `ServerHealthPanel.jsx` (hiển thị đúng badge và quota)**
- [x] **Step 4: Cập nhật `ServerHealthPanel.jsx`**
- [x] **Step 5: Chạy toàn bộ test Backend + Admin-web và commit**

---

## Task 3: Cơ Chế Xác Thực Lại (Re-Authentication PIN/Password) Cho Các Hành Động Chí Mạng

### Khảo sát & Khuyến nghị danh sách hành động cần bảo vệ:
Một quản trị viên nếu bị người ngoài thao tác lén trên máy hoặc click nhầm có thể gây hậu quả nghiêm trọng. Khảo sát toàn bộ hệ thống cho thấy **3 hành động chí mạng** bắt buộc phải kích hoạt cơ chế Xác thực lại:
1. **Hoàn tiền giao dịch (Refund Order):** Tác động trực tiếp đến dòng tiền ngân quỹ của doanh nghiệp và trạng thái thanh toán.
2. **Xóa mềm người dùng (Soft Delete User):** Vô hiệu hóa quyền truy cập và đưa tài khoản vào chu kỳ chuẩn bị tiêu hủy dữ liệu 30 ngày.
3. **Kích hoạt Bảo trì khẩn cấp (Emergency Maintenance Switch):** Chặn đứng toàn bộ người dùng trên cả Client-app và Web khỏi hệ thống.

*Đề xuất phương thức xác thực:*
- Sử dụng **Mã PIN quản trị an toàn (Security PIN - 6 chữ số)** hoặc Mật khẩu đăng nhập của Admin hiện tại.
- Để thuận tiện nhất cho PO và Admin thao tác nhanh chóng nhưng vẫn tuyệt đối an toàn, Modal cho phép Admin nhập **Mã PIN 6 số** (mặc định cấu hình trong hệ thống hoặc mật khẩu đăng nhập của Admin).
- Backend cung cấp endpoint `POST /api/admin/verify-security-pin` để xác thực mã PIN/mật khẩu trước khi cấp authorization token cho hành động chí mạng.

### Giải pháp kỹ thuật:
1. Tạo component dùng chung `SecurityConfirmModal.jsx` tại `src/Admin-web/src/components/common/SecurityConfirmModal.jsx`:
   - Giao diện nhập mã PIN 6 số (hoặc toggle sang mật khẩu Admin).
   - Tự động autofocus, hiển thị thông tin cảnh báo hành động chí mạng (Tên đơn hàng refund, Tên user bị xóa, hoặc Lý do bảo trì khẩn cấp).
   - Gọi API xác thực bảo mật trước khi thực thi callback hành động chính.
2. Tích hợp `SecurityConfirmModal` vào:
   - `PaymentHistoryPage.jsx` khi bấm "Xác nhận hoàn tiền".
   - `UserListPage.jsx` khi bấm "Xác nhận xóa mềm".
   - `BroadcastPage.jsx` và `DashboardPage.jsx` khi bật "Bảo trì khẩn cấp".

**Files:**
- Create: `src/Admin-web/src/components/common/SecurityConfirmModal.jsx`
- Modify: `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx`
- Modify: `src/Admin-web/src/pages/users/UserListPage.jsx`
- Modify: `src/Admin-web/src/pages/system/BroadcastPage.jsx`
- Modify: `src/Backend/modules/admin/admin.controller.js`
- Modify: `src/Backend/modules/admin/admin.service.js`
- Modify: `src/Backend/api/admin.routes.js`
- Test: `src/Admin-web/src/tests/security-confirm-modal.test.jsx`

- [x] **Step 1: Viết test Backend xác thực Security PIN/Password**
- [x] **Step 2: Viết test 2 tầng cho `SecurityConfirmModal` (UI PIN inputs + Gọi API xác thực thành công/thất bại)**
- [x] **Step 3: Triển khai Endpoint Backend và Modal Frontend**
- [x] **Step 4: Ghép nối vào 3 hành động: Refund, Delete User, Emergency Maintenance**
- [x] **Step 5: Kiểm tra và commit**

---

## Task 4: Thay Đổi Công Thức Tính Uptime SLA & Bổ Sung Nhãn Phân Loại [TAG] Cho Audit Log

### Khảo sát & Xác thực:
1. **Công thức Uptime:**
   - Hiện tại hàm `calcUptimePercent(uptimeSeconds)` cố định mẫu số `30 * 86400 = 2,592,000s`. Server mới chạy 1 ngày hiển thị `3.33%`, gây hiểu nhầm nghiêm trọng cho quản trị viên rằng hệ thống bị lỗi 96.67%.
   - **Công thức chuẩn quốc tế (SLA Availability):**
     $$\text{Uptime \%} = \max\left(0, 100 - \frac{\text{Thời gian gián đoạn bảo trì (giây)}}{\text{Thời gian chu kỳ quan sát (giây)}} \times 100\right)$$
     Khi không có sự cố, hệ thống luôn đạt `99.9x%` đến `100.0%`.
2. **Nhãn Phân loại Audit Log:**
   - Cả Dashboard và trang Nhật ký kiểm toán chỉ in ra chuỗi text thô của endpoint (ví dụ `/api/admin/getuser`).
   - Cần bổ sung nhãn phân loại trực quan (Colored Badges) theo tiền tố:
     - `[AUTH]`: Đăng nhập, đăng xuất, cấp phát lại token, gửi mã OTP.
     - `[PAYMENT]`: Nâng cấp gói cước, hoàn tiền, webhook thanh toán.
     - `[USER]`: Cập nhật thông tin, kích hoạt, vô hiệu hóa, xóa người dùng.
     - `[SYSTEM]`: Bật/tắt bảo trì khẩn cấp, cập nhật hạn mức hệ thống.
     - `[AIOps]`: Cách ly IP, phát hiện bất thường, phong tỏa tài khoản.
     - `[CATEGORY]`: Thêm, sửa, xóa danh mục thu chi.
     - `[API]`: Các truy vấn dữ liệu thông thường khác.

### Giải pháp kỹ thuật:
1. Trong `src/Backend/modules/admin/admin.service.js`, sửa hàm `calcUptimePercent` tính toán dựa trên tổng thời gian hoạt động thực tế trừ đi thời gian bảo trì từ `defaultMaintenanceManager.getHistory()`.
2. Tạo helper tiện ích `src/Admin-web/src/utils/audit-tags.util.js` phân tích chuỗi request và trả về `{ tag: '[AUTH]', label: 'Xác thực', color: 'indigo' }`.
3. Áp dụng hiển thị badge nhãn phân loại trên cả `DashboardPage.jsx` (Hoạt động gần đây) và `AuditLogPage.jsx` (Bảng nhật ký kiểm toán).

**Files:**
- Modify: `src/Backend/modules/admin/admin.service.js`
- Create: `src/Admin-web/src/utils/audit-tags.util.js`
- Modify: `src/Admin-web/src/pages/dashboard/DashboardPage.jsx`
- Modify: `src/Admin-web/src/pages/system/AuditLogPage.jsx`
- Test: `src/Admin-web/src/tests/audit-tags.test.jsx`
- Test: `src/Backend/tests/admin-uptime-sla.test.js`

- [x] **Step 1: Viết test Backend cho công thức Uptime SLA**
- [x] **Step 2: Viết test 2 tầng cho bộ lọc và render nhãn phân loại [TAG] trên Frontend**
- [x] **Step 3: Triển khai mã nguồn và xác nhận Uptime hiển thị chuẩn 99.9% - 100%**
- [x] **Step 4: Commit**

---

## Task 5: Tái Cấu Trúc Bộ Lọc Quản Lý Người Dùng & Masking Số Điện Thoại Theo Pháp Luật

### Khảo sát CSDL thực tế:
- Bảng `account`: Chứa `type` (`Basic`, `Premium`), `status` (`Active`, `Inactive`, `PendingDelete`, `Deleted`), `create_at`, `delete_at`.
- Bảng `user`: Chứa `fullname`, `phone`, `address`, `country_code`.
- Bộ lọc hiện tại trong `UserListPage.jsx` chỉ lọc chuỗi text địa chỉ theo "hcm, hn, dn, ct" một cách cứng nhắc, không có ý nghĩa thực tế.
- Cột số điện thoại đang in trực tiếp `{item.phone}` thô không che mờ.

### Đề xuất Bộ Lọc Quản Lý Người Dùng Mới:
1. **Loại Gói Cước (Account Type):** Tất cả | Basic | Premium.
2. **Trạng Thái Tài Khoản (Status):** Tất cả | Hoạt động (Active) | Tạm khóa (Inactive) | Chờ xóa (PendingDelete - 30 ngày) | Đã xóa (Deleted).
3. **Khoảng Thời Gian Gia Nhập (Joined Time):** Tất cả | Hôm nay | 7 ngày gần nhất | 30 ngày gần nhất | Tháng này.
4. **Tìm Kiếm Đa Năng (Search Query):** Họ tên, Email, Username, SĐT (tìm theo tiền tố hoặc số đã mask).

### Giải pháp Masking Số Điện Thoại:
- Bổ sung hàm tiện ích `maskPhone(phone)` tại `src/Admin-web/src/utils/format.js`:
  - Giữ lại 3 số đầu và 3 số cuối, che 4 số giữa bằng `****` (Ví dụ: `0987654321` $\rightarrow$ `098****321`).
  - Nếu số ngắn hơn 10 số: giữ 2 số đầu + 2 số cuối.
- Áp dụng `maskPhone` tại cột SĐT của `UserListPage.jsx` và trong `UserDetailModal.jsx`.

**Files:**
- Modify: `src/Admin-web/src/utils/format.js`
- Modify: `src/Admin-web/src/pages/users/UserListPage.jsx`
- Modify: `src/Admin-web/src/components/common/UserDetailModal.jsx`
- Test: `src/Admin-web/src/tests/user-filter-and-masking.test.jsx`

- [x] **Step 1: Viết test 2 tầng cho Masking SĐT và Bộ Lọc CSDL người dùng mới**
- [x] **Step 2: Cập nhật `format.js` với thuật toán masking 3 đầu + 4 sao + 3 cuối**
- [x] **Step 3: Cập nhật lại giao diện Filter Bar trong `UserListPage.jsx`**
- [x] **Step 4: Chạy test và commit**

---

## Task 6: Tinh Giản Drawer Cấu Hình Phân Quyền (Bỏ Trụ 4, Chỉ Cấu Hình Trụ 3)

### Khảo sát & Xác thực:
- Trong `src/Admin-web/src/pages/system/components/PermissionScopeDrawer.jsx`, phần chọn "Chính sách hạ cấp" (Trụ 4 - Downgrade Policy) đang bị lặp lại không cần thiết, vì tại bảng chính của `PermissionsPage.jsx` đã có dropdown chọn trực tiếp Trụ 4 cho từng dòng tính năng.
- Sự xuất hiện của Trụ 4 trong Drawer vừa chiếm diện tích vừa gây rối mắt cho người quản trị.

### Giải pháp kỹ thuật:
1. Loại bỏ toàn bộ phần UI chọn `downgrade_policy` (Trụ 4) khỏi `PermissionScopeDrawer.jsx`.
2. Giữ Drawer tập trung 100% vào **Trụ 3: Scope Config (JSON Schema hạn mức chuyên sâu)** với Monaco/JSON editor, hiển thị template mẫu và validate cú pháp JSON trực quan.
3. Cập nhật các test liên quan đến drawer phân quyền.

**Files:**
- Modify: `src/Admin-web/src/pages/system/components/PermissionScopeDrawer.jsx`
- Test: `src/Admin-web/src/tests/permission-scope-drawer-minimal.test.jsx`

- [x] **Step 1: Cập nhật test xác nhận Drawer chỉ render cấu hình Trụ 3 và không có select Trụ 4**
- [x] **Step 2: Refactor `PermissionScopeDrawer.jsx` loại bỏ Trụ 4**
- [x] **Step 3: Chạy test và commit**

---

## Task 7: Nâng Cấp AIOps Sentinel, Quản Lý Cách Ly Thủ Công & Công Cụ Xuất Báo Cáo CSV

### Khảo sát & Yêu cầu của PO:
1. **Threat Score AIOps:**
   - Trong `src/Backend/index.js:114`, giá trị đang bị gán cứng fallback là `aiopsStatus.threatScore ?? 5`. Phải sửa thành `0` và đo lường trực tiếp từ các vectơ an ninh trong dải từ `0 -> 100`.
   - Dọn sạch toàn bộ các chuỗi placeholder/mockup (như fallback IP `192.168.xxx.xxx`) trong `AIOpsPage.jsx`.
2. **Quản lý Cách ly & Tạm khóa Thủ công (Manual Quarantine):**
   - Bổ sung bộ lọc IP và Tên tài khoản trong bảng Nguồn theo dõi đặc biệt (Quarantine Table).
   - Thêm ô nhập form "Tạm Khóa Nhanh (Manual Quarantine)": Cho phép quản trị viên nhập trực tiếp Địa chỉ IP hoặc Username để tạm khóa ngay lập tức (kèm lý do và thời hạn tạm khóa), phục vụ phản ứng nhanh khi theo dõi Audit Log.
3. **Công cụ Xuất Báo Cáo CSV (Export to CSV):**
   - Xây dựng helper `exportToCsv(filename, columns, data)` hỗ trợ UTF-8 BOM chống lỗi font tiếng Việt trong Excel.
   - Bổ sung nút **"Xuất CSV" (Export to CSV)** tại:
     - Trang Nhật ký kiểm toán `AuditLogPage.jsx` (phục vụ thanh tra an ninh).
     - Trang Lịch sử thanh toán `PaymentHistoryPage.jsx` (phục vụ kế toán và đối soát hoàn tiền).
4. **Nút Bật Bảo Trì Khẩn Cấp:**
   - Đảm bảo cơ chế Bảo trì khẩn cấp xuất hiện trang trọng tại `DashboardPage.jsx` và `BroadcastPage.jsx`, đồng bộ trạng thái khẩn cấp toàn hệ thống qua Socket.io.

**Files:**
- Modify: `src/Backend/index.js`
- Modify: `src/Admin-web/src/pages/system/AIOpsPage.jsx`
- Create: `src/Admin-web/src/utils/csv-exporter.util.js`
- Modify: `src/Admin-web/src/pages/system/AuditLogPage.jsx`
- Modify: `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx`
- Modify: `src/Admin-web/src/pages/dashboard/DashboardPage.jsx`
- Test: `src/Admin-web/src/tests/aiops-manual-quarantine.test.jsx`
- Test: `src/Admin-web/src/tests/csv-export.test.jsx`

- [x] **Step 1: Viết test 2 tầng cho Tạm khóa thủ công AIOps và Xuất báo cáo CSV**
- [x] **Step 2: Sửa Backend `index.js:114` bỏ fallback threatScore = 5**
- [x] **Step 3: Triển khai form Tạm khóa nhanh IP/Account và bộ lọc trong `AIOpsPage.jsx`**
- [x] **Step 4: Triển khai helper `csv-exporter.util.js` và gắn nút Export CSV vào AuditLogPage & PaymentHistoryPage**
- [x] **Step 5: Bổ sung nút Bảo trì khẩn cấp tại DashboardPage đồng bộ với BroadcastPage**
- [x] **Step 6: Chạy kiểm thử toàn hệ thống và commit**

---

## Kế hoạch Kiểm Thử Tích Hợp & Bàn Giao (Verification & Handover)
1. Chạy toàn bộ test suite của Backend: `rtk npm test`
2. Chạy toàn bộ test suite của Admin-web: `rtk npm test`
3. Kiểm tra TypeScript / Lint: `rtk npm run lint` (hoặc test build)
4. Xác thực thủ công trên trình duyệt các luồng nghiệp vụ quan trọng.
