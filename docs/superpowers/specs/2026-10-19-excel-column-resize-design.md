# Thiết Kế Chi Tiết: Tính Năng Co Dãn Cột Kiểu Excel & Truncate Văn Bản Cho Bảng Admin-Web

- **Ngày tạo:** 19/10/2026
- **Trạng thái:** Chờ người dùng duyệt (Pending Approval)
- **Module áp dụng:** `src/Admin-web`

---

## 1. Mục Tiêu & Yêu Cầu

### 1.1. Yêu cầu của người dùng
1. **Co dãn cột như Excel (Column Resizing):** Cho phép người dùng kéo thả vạch phân cách giữa các cột ở thanh tiêu đề (`<th>`) để tùy chỉnh độ rộng từng cột một cách mượt mà và trực quan.
2. **Ẩn chữ vượt quá độ dài bằng dấu ba chấm (`...`):** Toàn bộ nội dung văn bản bên trong các ô dữ liệu nếu vượt quá độ rộng cột sẽ tự động ẩn đi và hiển thị dấu ba chấm (`truncate` / `overflow-hidden text-ellipsis whitespace-nowrap`).
3. **Hiển thị Tooltip đầy đủ:** Khi rê chuột (hover) vào các ô bị rút gọn, hiển thị Tooltip đầy đủ nội dung nguyên bản để quản trị viên đọc được dữ liệu mà không làm vỡ bố cục bảng.
4. **Ghi nhớ cấu hình (LocalStorage Persistence):** Tự động lưu độ rộng các cột đã tùy chỉnh vào LocalStorage theo từng bảng. Khi F5 tải lại trang hoặc đăng nhập lại phiên làm việc, giao diện vẫn giữ nguyên kích thước cột mà người dùng đã chỉnh.
5. **Phạm vi áp dụng:** Toàn bộ 7 trang bảng biểu dữ liệu chính trong hệ thống quản trị `Admin-web`.

---

## 2. Kiến Trúc Giải Pháp & Các Thành Phần (Reusable Architecture)

Thay vì viết lặp đi lặp lại logic xử lý chuột ở 7 trang riêng lẻ, kiến trúc được thiết kế thành một bộ công cụ dùng chung (Modular & Reusable):

```
src/Admin-web/
  ├── hooks/
  │    └── useResizableColumns.js        # Quản lý state width, drag events, LocalStorage
  ├── components/common/
  │    ├── ResizableTh.jsx               # Header <th> có divider kéo thả, cursor col-resize
  │    └── TruncateCell.jsx              # Cell wrapper tự động truncate với tooltip
  └── pages/
       ├── users/UserListPage.jsx        # Bảng Người dùng
       ├── system/AuditLogPage.jsx       # Bảng Nhật ký hệ thống
       ├── payments/PaymentHistoryPage.jsx # Bảng Lịch sử thanh toán
       ├── categories/CategoryPage.jsx   # Bảng Danh mục
       ├── system/AIOpsPage.jsx          # Bảng Cách ly IP (Quarantine)
       ├── system/BroadcastPage.jsx      # Bảng Lịch sử bảo trì / thông báo
       └── dashboard/DashboardPage.jsx   # Bảng Hoạt động gần đây
```

---

## 3. Chi Tiết Kỹ Thuật Từng Thành Phần

### 3.1. Custom Hook: `useResizableColumns({ tableKey, defaultWidths, minWidth = 60 })`
- **Quản lý state:**
  - `widths`: Đối tượng `{ [colKey]: number }` lưu trữ độ rộng tính bằng pixel (`px`).
  - `isResizing`: Trạng thái boolean khi đang kéo chuột.
  - `activeCol`: Tên cột đang được kéo.
- **LocalStorage:**
  - Tự động nạp từ `localStorage.getItem('admin_tbl_widths_' + tableKey)` khi khởi tạo.
  - Tự động debounce lưu vào LocalStorage khi người dùng thả chuột (`mouseup`).
- **Xử lý sự kiện kéo thả mượt mà:**
  - Bắt đầu: Khi nhấn chuột trái (`mousedown`) vào thanh divider của cột.
  - Kéo: Lắng nghe `mousemove` trên toàn bộ `document` để tránh chuột bị trượt khỏi mép cột khi kéo nhanh.
  - Kết thúc: Lắng nghe `mouseup` trên `document`, hủy bỏ event listener, cập nhật state cuối cùng và lưu vào LocalStorage.
  - Giới hạn: Đảm bảo độ rộng cột không nhỏ hơn `minWidth` (mặc định 60px) và không lớn hơn 1000px để chống vỡ layout.
- **Khôi phục mặc định (Reset):**
  - Hàm `resetWidths()` để khôi phục lại toàn bộ độ rộng ban đầu nếu người dùng muốn.
  - Hàm `resetColumn(colKey)` khi double-click vào divider.

### 3.2. Component: `<ResizableTh>`
- **Giao diện & Trực quan (Excel Style):**
  - Đóng vai trò là thẻ `<th>`, nhận `className`, `style`, `align`, `children`.
  - Có thanh điều khiển kéo thả (Resize Handle Divider) đặt ở mép phải của thẻ `<th>`:
    - Chiều rộng vùng bắt chuột: `w-2` (8px) bao phủ mép cột để người dùng dễ rê chuột trúng.
    - Con trỏ chuột: `cursor-col-resize` (con trỏ hai đầu mũi tên `↔` giống Excel).
    - Hiệu ứng thị giác: Khi hover, thanh phân cách hiển thị vạch sáng `bg-primary/40`; khi đang click kéo (`active`), thanh chuyển thành đường kẻ xanh đậm rõ nét `bg-primary shadow-sm`.
  - Hỗ trợ Double-click: Double-click vào vạch phân cách sẽ khôi phục độ rộng mặc định của cột đó.

### 3.3. Component / Helper: `<TruncateCell>`
- **Cơ chế cắt chữ & Tooltip:**
  - Sử dụng class Tailwind `truncate block max-w-full overflow-hidden text-ellipsis whitespace-nowrap`.
  - Tự động gán thuộc tính `title={text}` native của trình duyệt để hiển thị tooltip nhanh, chuẩn, không tốn tài nguyên DOM.
  - Hỗ trợ truyền tùy biến tooltip nếu nội dung hiển thị dạng component phức tạp (ví dụ badge, avatar kèm text).

---

## 4. Danh Sách Các Bảng Áp Dụng (7 Trang)

| # | Trang | Tên Bảng | Các Cột Hỗ Trợ Co Dãn |
|---|---|---|---|
| 1 | `UserListPage.jsx` | Quản lý Người dùng | Họ tên/Tài khoản, Email, Số điện thoại, Trạng thái, Thao tác |
| 2 | `AuditLogPage.jsx` | Nhật ký Hệ thống (Audit Logs) | Mã Log, Tài khoản/IP, Yêu cầu/Endpoint, Trạng thái, Lý do/Chi tiết, Thời gian gửi, Thời gian nhận |
| 3 | `PaymentHistoryPage.jsx` | Lịch sử Thanh toán | Mã giao dịch, Người dùng, Gói cước, Số tiền, Phương thức, Trạng thái, Thời gian |
| 4 | `CategoryPage.jsx` | Quản lý Danh mục | Icon/Tên danh mục, Loại (Thu/Chi), Ngày tạo, Trạng thái, Thao tác |
| 5 | `AIOpsPage.jsx` | Bảng Cách ly IP (Quarantine) | Địa chỉ IP, Lý do chặn, Thời gian cách ly, Mức độ rủi ro, Thao tác mở khóa |
| 6 | `BroadcastPage.jsx` | Lịch sử Bảo trì & Thông báo | Tiêu đề thông báo, Loại thông báo, Thời gian bắt đầu/kết thúc, Trạng thái, Thao tác |
| 7 | `DashboardPage.jsx` | Hoạt động gần đây (Recent Activities) | Thời gian, Người thực hiện, Hành động, Mô tả chi tiết |

---

## 5. Kế Hoạch Kiểm Thử 2 Tầng (2-Tier Testing Architecture)

Tuân thủ nghiêm ngặt **Rule 11** của dự án:

### 🧱 Tầng 1: Kiểm thử Hiển thị & Thao tác Giao diện (UI Rendering & Interaction)
1. Kiểm tra tất cả các thẻ `<th>` của bảng đều render đúng thanh điều khiển kéo thả (Resize Handle) có class `cursor-col-resize`.
2. Kiểm tra các ô dữ liệu dài đều có class `truncate` và thuộc tính `title` để hiển thị tooltip khi hover.
3. Người dùng có thể rê chuột vào divider và click giữ chuột mà không gây ra runtime error hay văng màn hình.

### ⚡ Tầng 2: Kiểm thử Tác động Hệ thống Thực tế (System Impact & Behavioral Verification)
1. **Tác động DOM & Kích thước Pixel:** Mô phỏng sự kiện `mousedown` -> `mousemove` kéo sang phải 50px -> `mouseup`. Xác nhận thuộc tính `style.width` của thẻ `<th>` và cột tương ứng thực sự thay đổi từ `W` thành `W + 50px`.
2. **Tác động Lưu trữ (LocalStorage Persistence):** Sau khi kéo thả, kiểm tra `localStorage.getItem('admin_tbl_widths_...')` được cập nhật với giá trị mới đo lường được.
3. **Bảo toàn khi F5:** Khi unmount và mount lại component, bảng tự động đọc từ LocalStorage và áp dụng đúng kích thước đã kéo trước đó.
4. **Giới hạn an toàn (Boundary Clamping):** Kéo chuột quá hẹp về bên trái không làm cột bị co dưới ngưỡng an toàn `minWidth` (60px).
