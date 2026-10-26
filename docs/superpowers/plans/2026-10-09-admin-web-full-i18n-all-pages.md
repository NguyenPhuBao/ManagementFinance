# Kế Hoạch Triển Khai: Chuyển Đổi Ngôn Ngữ Đa Trang Toàn Diện Cho Admin-web (Full I18n Engine)

> **Mã kế hoạch:** `PLAN-2026-10-09-FULL-I18N-ADMIN-WEB`  
> **Ngày lập:** 2026-10-09  
> **Người thực hiện:** Antigravity AI Pair Programmer  
> **Người phê duyệt (PO):** Tieu Bao  
> **Phạm vi:** Áp dụng toàn diện 100% các trang và thành phần giao diện của `src/Admin-web`.

---

## 1. Bối Cảnh & Mục Tiêu

### 1.1. Hiện Trạng
- Hệ thống đã có bộ chuyển đổi `[ EN | VI ]` trên Header và `LanguageContext` hoạt động chuẩn xác với cơ chế lưu `localStorage` và tác động Root DOM (`lang`, `data-language`).
- Tuy nhiên, hiện tại chỉ mới áp dụng cho **Menu (Sidebar) và Header/LockScreen/SettingsModal**.
- Khi người dùng chọn `EN`, toàn bộ nội dung trong trang (như trang Dashboard trong hình ảnh PO gửi: tiêu đề *"Tổng quan hệ thống"*, bộ lọc thời gian *"Hôm nay / 7 Ngày / 1 Tháng / 1 Năm"*, các thẻ KPI, bảng *"Hoạt động gần đây"*, v.v.) vẫn đang là Tiếng Việt do còn chứa các chuỗi văn bản hardcoded.

### 1.2. Mục Tiêu Nghiệp Vụ
- Chuyển ngữ toàn diện **toàn bộ nội dung** trong **toàn bộ các trang** của Admin-web.
- Khi người dùng nhấn `EN`, toàn bộ giao diện từ tiêu đề, mô tả, bộ lọc, thẻ thống kê, bảng dữ liệu, nhãn trạng thái (Status badge), thông báo tải, modal, nút bấm đều lập tức chuyển sang Tiếng Anh.
- Khi người dùng nhấn `VI`, toàn bộ giao diện phục hồi về Tiếng Việt mượt mà.
- Bảo toàn tuyệt đối tính nhất quán thuật ngữ tài chính, 0 dependency nặng, bảo toàn kiểm thử 2 tầng (Rule 11) và không làm hồi quy bất kỳ test suites nào hiện có.

---

## 2. Danh Sách Các Trang & Thành Phần Cần Phủ Sóng Ngôn Ngữ

| STT | Phân hệ / Trang | Tệp nguồn | Nội dung chính cần chuyển ngữ |
|---|---|---|---|
| **1** | **Tổng quan hệ thống (Dashboard)** | `src/pages/dashboard/DashboardPage.jsx` | Tiêu đề, mô tả, bộ lọc nhanh (`Hôm nay`, `7 Ngày`, `1 Tháng`, `1 Năm`), bộ lọc chi tiết Date Picker (`Theo Ngày`, `Theo Tháng`, `Theo Năm`), các thẻ KPI (`Tổng người dùng`, `Tổng danh mục`, `Uptime Hệ thống`, `Người dùng mới`), bảng `Hoạt động gần đây`, cột dữ liệu (`NGƯỜI DÙNG`, `HÀNH ĐỘNG`, `LÝ DO`, `TRẠNG THÁI`, `THỜI GIAN`), các badge trạng thái (`Thành công`, `Đang xử lý`, `Thất bại`,...), overlay loading. |
| **2** | **Quản lý người dùng (Users)** | `src/pages/users/UserListPage.jsx`<br>`src/pages/users/UserDetailPage.jsx` | Tiêu đề trang, thanh tìm kiếm, bộ lọc vai trò/trạng thái, các cột bảng người dùng, nút thao tác (Khóa/Mở khóa, Đặt lại mật khẩu, Xem chi tiết), Modal chi tiết thông tin người dùng, popup xác nhận. |
| **3** | **Quản lý danh mục (Categories)** | `src/pages/categories/CategoryPage.jsx` | Tiêu đề trang, tab Thu / Chi, nút Thêm danh mục mới, modal thêm/sửa danh mục, danh sách danh mục mặc định vs tùy chỉnh, xác nhận xóa. |
| **4** | **Phân quyền gói cước (Permissions)** | `src/pages/system/PermissionManagementPage.jsx` | Tiêu đề trang, ma trận phân quyền theo gói (Free, Standard, Premium), các quyền tính năng động, cấu hình hạn mức ví/giao dịch/ngân sách, nút Lưu phân quyền, cảnh báo. |
| **5** | **Nhật ký kiểm toán (Audit Log)** | `src/pages/system/AuditLogPage.jsx` | Tiêu đề trang, bộ lọc đa chiều (Khoảng ngày, Hành động, Mã HTTP, IP, Email), bảng nhật ký kiểm toán, modal chi tiết JSON log. |
| **6** | **Bảo trì & Thông báo (Broadcast)** | `src/pages/system/BroadcastPage.jsx` | Công tắc chế độ bảo trì hệ thống (Chuẩn vs Khẩn cấp), form tạo thông báo đẩy realtime, danh sách thông báo đã phát. |
| **7** | **AIOps Sentinel (AIOps)** | `src/pages/system/AIOpsPage.jsx` | Bảng điều khiển giám sát AIOps, chỉ số đe dọa Threat Score, 13 vector giám sát, danh sách IP phong tỏa, nút mở phong tỏa, biểu đồ thời gian thực. |
| **8** | **Xác thực & Tài khoản (Auth)** | `src/pages/auth/LoginPage.jsx`<br>`src/pages/auth/ForgotPasswordPage.jsx` | Form đăng nhập (Email, Mật khẩu, Ghi nhớ, Đăng nhập), Quên mật khẩu, thông báo lỗi validation. |
| **9** | **Thành phần dùng chung (Common)** | `src/components/common/Pagination.jsx`<br>`src/components/common/ServerHealthPanel.jsx`<br>`src/utils/constants.js` | Thanh phân trang ("Hiển thị X - Y trong tổng số Z", "Trang trước", "Trang sau"), panel sức khỏe server (CPU, RAM, Event Loop, DB Pool), từ điển trạng thái dùng chung. |

---

## 3. Kiến Trúc Kỹ Thuật & Cấu Trúc Từ Điển Mở Rộng

### 3.1. Cấu Trúc Namespaces Trong Từ Điển (`src/locales/vi.js` & `en.js`)
Mở rộng từ điển hiện có thêm các khối namespace chuyên biệt:
```javascript
export const vi = {
  common: { /* các từ chung: lưu, hủy, đóng, tìm kiếm, xác nhận, trạng thái... */ },
  nav: { /* menu sidebar */ },
  header: { /* chuông, pill toggle, cài đặt */ },
  settings: { /* modal cài đặt 4 tabs */ },
  lockScreen: { /* màn hình khóa */ },
  
  // Mở rộng mới:
  dashboard: {
    title: 'Tổng quan hệ thống',
    subtitle: 'Dữ liệu tài chính và hoạt động được cập nhật liên tục để cung cấp cái nhìn toàn diện về hiệu suất.',
    loadingOverlay: {
      title: 'Đang tải dữ liệu báo cáo',
      wait: 'Vui lòng chờ trong giây lát...',
    },
    filters: {
      today: 'Hôm nay',
      sevenDays: '7 Ngày',
      oneMonth: '1 Tháng',
      oneYear: '1 Năm',
      byDay: 'Theo Ngày',
      byMonth: 'Theo Tháng',
      byYear: 'Theo Năm',
    },
    kpi: {
      totalUsers: 'Tổng người dùng',
      totalCategories: 'Tổng danh mục',
      systemUptime: 'Uptime Hệ thống',
      newUsers: 'Người dùng mới',
      stable: 'Ổn định',
      loading: 'Đang tải...',
      unsupported: 'Chưa hỗ trợ API',
      error: 'Lỗi kết nối',
    },
    recentActivities: {
      title: 'Hoạt động gần đây',
      realtime: 'Thời gian thực',
      columns: {
        user: 'NGƯỜI DÙNG',
        action: 'HÀNH ĐỘNG',
        reason: 'LÝ DO',
        status: 'TRẠNG THÁI',
        time: 'THỜI GIAN',
      },
      justNow: 'Vừa xong',
    },
  },

  users: { ... },
  categories: { ... },
  permissions: { ... },
  auditLogs: { ... },
  broadcast: { ... },
  aiops: { ... },
  auth: { ... },
  serverHealth: { ... },
};
```

`en.js` có cấu trúc khóa tương ứng 1-1 với văn phong Tiếng Anh chuẩn Enterprise.

### 3.2. Chuyển Đổi Dynamic Constants & Status Badges
Chuyển đổi `STATUS_CONFIG` và `TIME_FILTER_LABELS` sang dạng hàm hoặc hook-compatible:
```javascript
// Thay vì nhãn cố định tiếng Việt:
const getStatusLabel = (status, t) => {
  return t(`common.status.${status}`) || status;
};
```

---

## 4. Lộ Trình Triển Khai Tuần Tự (4 Đợt)

### 🚀 Đợt 1: Trang Dashboard & Các Thành Phần Dùng Chung (Ưu tiên số 1 - Khắc phục ngay trang PO gửi)
1. Mở rộng từ điển `vi.js` và `en.js` cho namespace `dashboard`, `common.status`, `serverHealth`.
2. Tích hợp `useLanguageSafe()` và áp dụng `t()` vào `DashboardPage.jsx`:
   - Tiêu đề & mô tả
   - Bộ lọc thời gian (Hôm nay, 7 Ngày, 1 Tháng, 1 Năm, Date Picker: Ngày / Tháng / Năm)
   - 4 Thẻ KPI và nhãn tăng trưởng
   - Bảng Hoạt động gần đây, tên cột, trạng thái badge, thời gian
   - Loading overlay
3. Chuyển ngữ `Pagination.jsx` và `ServerHealthPanel.jsx`.
4. Kiểm thử trực tiếp và xác nhận Dashboard chuyển sang Tiếng Anh 100%.

### 🚀 Đợt 2: Các Phân Hệ Quản Lý Dữ Liệu (Users, Categories, Permissions)
1. Bổ sung từ điển cho `users`, `categories`, `permissions`.
2. Tích hợp `t()` vào:
   - `UserListPage.jsx` & `UserDetailPage.jsx`
   - `CategoryPage.jsx`
   - `PermissionManagementPage.jsx`
3. Kiểm thử tương tác và xác nhận dữ liệu form/bảng hiển thị đúng cả 2 ngôn ngữ.

### 🚀 Đợt 3: Các Phân Hệ Vận Hành & Bảo Mật (Audit Logs, Broadcast, AIOps, Auth)
1. Bổ sung từ điển cho `auditLogs`, `broadcast`, `aiops`, `auth`.
2. Tích hợp `t()` vào:
   - `AuditLogPage.jsx`
   - `BroadcastPage.jsx`
   - `AIOpsPage.jsx`
   - `LoginPage.jsx` & `ForgotPasswordPage.jsx`

### 🚀 Đợt 4: Kiểm Thử 2 Tầng, Build Production & Đồng Bộ CodeGraph (Rule 8 & 11)
1. Cập nhật và mở rộng bộ test 2 tầng `language.system.test.jsx`:
   - Kiểm tra chuyển ngữ thực tế trên DOM của `DashboardPage`.
   - Kiểm tra chuyển ngữ trên `UserListPage` và `CategoryPage`.
2. Chạy toàn bộ test suites (`rtk npm test` - 13 suites).
3. Chạy `rtk npm run build` bảo đảm Vite build sạch sẽ.
4. Cập nhật `Project.md` và chạy `rtk npx codegraph build`.

---

## 5. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

- [ ] Khi chọn `EN`, toàn bộ chữ trên trang `/dashboard` (tiêu đề, thẻ thống kê, bộ lọc, bảng dữ liệu gần đây, date picker) hiển thị bằng Tiếng Anh.
- [ ] Khi chọn `EN`, tất cả các trang khác (`/users`, `/categories`, `/permissions`, `/audit-logs`, `/broadcast`, `/aiops`, `/login`) hiển thị nội dung Tiếng Anh đồng bộ.
- [ ] Khi chuyển về `VI`, mọi nội dung phục hồi lại Tiếng Việt chuẩn xác.
- [ ] F5 reload trang giữ nguyên ngôn ngữ đã chọn (Persistence qua LocalStorage).
- [ ] Toàn bộ 13/13 test files của Admin-web PASS 100%.
- [ ] Build production `npm run build` không có lỗi.
- [ ] Đã cập nhật `Project.md` và chạy lại `codegraph build`.
