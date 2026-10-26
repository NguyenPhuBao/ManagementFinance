# Kế Hoạch Triển Khai: Bước 4 — Xây Dựng Tính Năng Phân Quyền Động Tại Admin-Web

> **Dành cho Agentic Workers:** REQUIRED SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` để triển khai kế hoạch này theo từng tác vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng trọn gói tính năng Quản lý phân quyền tính năng động theo loại tài khoản (`Basic`, `Premium`) trên giao diện Admin-web:
1. Cho phép nhập số cho các tính năng có số lượng (`LIMIT`: ví dụ hạn mức ví, ngân sách, mục tiêu) kèm tùy chọn "Không giới hạn".
2. Cho phép bật/tắt dạng Checkbox cho các tính năng logic (`TOGGLE`: ví dụ Trợ lý AI, Nhập nhanh).
3. Trình bày trực quan theo từng **Nhóm chức năng** (`category_group`: Tài nguyên, Trí tuệ nhân tạo, ...).
4. Cung cấp API Backend admin bảo mật, kiểm tra quyền admin và lưu vết Audit Log.

---

## 1. Thiết Kế Giao Diện & Trải Nghiệm Người Dùng (Admin-Web UI UX)

### Bố Cục Trang Quản Lý Phân Quyền (`/permissions`)
* **Header:**
  - Tiêu đề: *Quản lý Phân quyền Gói cước (Feature Permissions)*
  - Mô tả: *Thiết lập hạn mức tài nguyên và tính năng mở rộng cho từng loại tài khoản (Basic & Premium)*
  - Các nút hành động:
    + Nút "Làm mới" (Reload / Reset): Đọc lại cấu hình từ CSDL.
    + Nút "Lưu tất cả thay đổi" (Save Changes): Nút nổi bật (Primary), tự động kích hoạt khi có thay đổi chưa lưu, hiển thị số lượng thay đổi đang chờ lưu (pending changes badge).
* **Bảng Ma Trận Phân Nhóm Theo Chức Năng (Grouped Matrix)**:
  - Phân nhóm lớn theo `category_group` (ví dụ: 📦 *Tài nguyên & Danh mục*, 🤖 *Trí tuệ nhân tạo (AI)*).
  - Trong mỗi nhóm, hiển thị danh sách các tính năng với các cột:
    1. **Tên & Mô tả tính năng**: Tên tiếng Việt, icon nhận diện, nhãn kiểu phân quyền (`LIMIT` / `TOGGLE`), mã slug (`wallets`, `budgets`, `goals`, `ai_assistant`, `ai_quick_input`).
    2. **Gói Basic (Tài khoản Cơ bản)**:
       - Nếu kiểu `LIMIT`: Ô nhập số (Number Input) để cấu hình hạn mức tối đa. Có checkbox "Không giới hạn" (unlimited -> giá trị `null`).
       - Nếu kiểu `TOGGLE`: Checkbox hoặc Toggle Switch. Check = Bật (`true`), Not check = Tắt (`false`).
    3. **Gói Premium (Tài khoản Trả phí)**:
       - Nếu kiểu `LIMIT`: Ô nhập số hoặc checkbox "Không giới hạn". Mặc định của Premium là không giới hạn (`limit_value = null`).
       - Nếu kiểu `TOGGLE`: Checkbox / Toggle Switch. Mặc định là bật (`true`).
    4. **Trạng thái / Thao tác**: Badge hiển thị khi có thay đổi cục bộ so với CSDL.

---

## 2. Thiết Kế API Backend Admin (`/api/admin/permissions`)

### Endpoint 1: `GET /api/admin/permissions`
* **Xác thực:** `authenticate`, `authorize('admin')`.
* **Dữ liệu trả về:**
  ```json
  {
    "success": true,
    "data": {
      "features": [
        {
          "id": "wallets",
          "name": "Tạo ví",
          "description": "Giới hạn số lượng ví hoạt động đồng thời",
          "type": "LIMIT",
          "category_group": "Tài nguyên",
          "default_limit": 3,
          "default_enabled": true
        },
        {
          "id": "ai_assistant",
          "name": "Trợ lý AI & Lệnh tạo",
          "description": "Hỗ trợ chat tài chính và tạo giao dịch thông minh",
          "type": "TOGGLE",
          "category_group": "Trí tuệ nhân tạo",
          "default_limit": null,
          "default_enabled": false
        }
      ],
      "permissions": {
        "Basic": {
          "wallets": { "is_enabled": true, "limit_value": 3 },
          "budgets": { "is_enabled": true, "limit_value": 3 },
          "goals": { "is_enabled": true, "limit_value": 3 },
          "ai_assistant": { "is_enabled": false, "limit_value": null },
          "ai_quick_input": { "is_enabled": false, "limit_value": null }
        },
        "Premium": {
          "wallets": { "is_enabled": true, "limit_value": null },
          "budgets": { "is_enabled": true, "limit_value": null },
          "goals": { "is_enabled": true, "limit_value": null },
          "ai_assistant": { "is_enabled": true, "limit_value": null },
          "ai_quick_input": { "is_enabled": true, "limit_value": null }
        }
      }
    }
  }
  ```

### Endpoint 2: `PUT /api/admin/permissions`
* **Xác thực:** `authenticate`, `authorize('admin')`.
* **Payload:**
  ```json
  {
    "updates": [
      {
        "account_type": "Basic",
        "feature_id": "wallets",
        "is_enabled": true,
        "limit_value": 5
      },
      {
        "account_type": "Basic",
        "feature_id": "ai_assistant",
        "is_enabled": true,
        "limit_value": null
      }
    ]
  }
  ```
* **Xử lý:**
  - Validate dữ liệu: `account_type` thuộc `['Basic', 'Premium']`, `feature_id` tồn tại trong bảng `feature`.
  - Nếu `LIMIT`: `limit_value` là số nguyên >= 0 hoặc `null`.
  - Cập nhật thông qua `permissionRepository.updatePermission`.
  - Ghi Audit Log: Thao tác cấu hình phân quyền bởi Admin.
  - Xóa cache phân quyền nếu có.

---

## 3. Danh Sách Tác Vụ Chi Tiết

### Tác Vụ 1: Backend Admin API — Controller & Route
**Files:**
- Modify: `src/Backend/modules/admin/admin.service.js`
- Modify: `src/Backend/modules/admin/admin.controller.js`
- Modify: `src/Backend/api/admin.routes.js`
- Create: `src/Backend/tests/unit/admin.permission.test.js`

- [x] Viết hàm `getPermissionsMatrix()` và `updatePermissionsMatrix(updates, adminUser)` trong `admin.service.js`.
- [x] Thêm controller `getPermissions` và `updatePermissions` trong `admin.controller.js`.
- [x] Đăng ký route `GET /permissions` và `PUT /permissions` trong `admin.routes.js`.
- [x] Viết unit test kiểm thử quyền truy cập admin, đọc dữ liệu ma trận và cập nhật thành công (5/5 tests pass).
- [x] Chạy `rtk npm test` đảm bảo toàn bộ tests pass (256/256 tests pass).

### Tác Vụ 2: Admin-Web API Client Layer
**Files:**
- Modify: `src/Admin-web/src/api/admin.api.js`

- [x] Thêm `getPermissions()` gọi `GET /admin/permissions`.
- [x] Thêm `updatePermissions(updates)` gọi `PUT /admin/permissions`.

### Tác Vụ 3: Admin-Web UI — Trang Quản Lý Phân Quyền
**Files:**
- Create: `src/Admin-web/src/pages/system/PermissionManagementPage.jsx`
- Modify: `src/Admin-web/src/router/routes.jsx`
- Modify: `src/Admin-web/src/components/layout/Sidebar.jsx`

- [x] Tạo component `PermissionManagementPage.jsx`:
  + State quản lý: `features`, `permissions`, `draftPermissions`, `hasChanges`, `loading`, `saving`.
  + Phân nhóm `features` theo `category_group`.
  + Giao diện nhập số cho `LIMIT` (kèm checkbox "Không giới hạn" toggle null).
  + Giao diện Checkbox (Check = Bật, Uncheck = Tắt) cho `TOGGLE`.
  + Xử lý lưu thay đổi hàng loạt kèm thông báo Toast Alert thành công/thất bại.
- [x] Đăng ký route `/permissions` trong `routes.jsx`.
- [x] Thêm item `Phân quyền gói cước` vào thanh Sidebar menu (`Sidebar.jsx`).

### Tác Vụ 4: Kiểm Thử Frontend & Tích Hợp Toàn Diện
**Files:**
- Test trong `src/Admin-web` (chạy build thử nghiệm: `rtk npm run build`).
- Chạy toàn bộ backend test: `rtk npm test`.

- [x] Kiểm tra Vite build thành công không có lỗi cú pháp/import (Built in 7.33s).
- [x] Cập nhật `Project.md` và chạy `rtk npx codegraph build`.
