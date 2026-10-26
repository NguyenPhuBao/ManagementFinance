# Kế Hoạch: Đập Đi Xây Lại Giao Diện Quản Lý Phân Quyền Gói Cước 4 Trụ Cột (Enterprise Minimalist Matrix)

> **Mục tiêu:** Xóa bỏ hoàn toàn giao diện dạng box/card to cồng kềnh, màu sắc lòe loẹt kiểu trẻ em; tái thiết kế từ đầu thành **Bảng Ma Trận Dữ Liệu Phẳng Mật Độ Cao (Data-Dense Minimalist Matrix Table)** chuẩn B2B SaaS (tương tự Stripe, AWS, Linear, Cloudflare), hiển thị trực diện và rõ nét **ĐẦY ĐỦ 4 TRỤ CỘT** trên giao diện:
> - **Trụ 1: Truy Cập (Access)**: Switch toggle phẳng nhỏ gọn kèm trạng thái rõ ràng.
> - **Trụ 2: Định Mức (Quota / Limit)**: Hiển thị và chỉnh sửa trực tiếp giá trị trần (ví dụ `5`, `30`, `100` hoặc `Vô hạn ∞`).
> - **Trụ 3: Phạm Vi (Scope)**: Tóm tắt phạm vi áp dụng (ví dụ: `PDF, Excel`, `Model Edge 250MB`, `12 tháng`, `Tất cả ví`...) kèm nút mở cấu hình nâng cao.
> - **Trụ 4: Chính Sách Hạ Cấp (Downgrade Policy)**: Dropdown chọn trực tiếp trên từng dòng: `BLOCK_CREATE`, `LOCK_FEATURE`, `READ_ONLY`, `GRACE_PERIOD_3D`, `FALLBACK_DEFAULT`.

---

## 1. Cấu Trúc Giao Diện Mới

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [Tiêu đề] Quản Lý Phân Quyền Tính Năng (4 Trụ Cột)         [Đặt Lại Mặc Định]  [Lưu Thay Đổi (N)]    │
│ [Tab Segmented]: [ Tất Cả Gói (Đối Chiếu) ]  |  [ Gói Basic (Cơ Bản) ]  |  [ Gói Premium (Trả Phí) ] │
├──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [🔍 Tìm kiếm tính năng...]  [Phân hệ: Tất cả ▼]  [Chỉ dòng đã sửa]  36 Tính năng · 5 Có trần Quota   │
├──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ BẢNG MA TRẬN DỮ LIỆU PHẲNG (DENSE ENTERPRISE MATRIX TABLE)                                           │
│ ┌──────────────────────┬──────┬──────────────┬──────────────┬──────────────────┬───────────────────┐ │
│ │ TÍNH NĂNG (MÃ & TÊN) │ GÓI  │ TRỤ 1: ACCESS│ TRỤ 2: QUOTA │ TRỤ 3: SCOPE     │ TRỤ 4: DOWNGRADE  │ │
│ ├──────────────────────┼──────┼──────────────┼──────────────┼──────────────────┼───────────────────┤ │
│ │ ▼ BÁO CÁO & PHÂN TÍCH (4 tính năng)                                                              │ │
│ │ Xuất báo cáo         │BASIC │ [○ Off] Khóa │ 0 bản/tháng  │ [PDF cơ bản]     │ [LOCK_FEATURE  ▼] │ │
│ │ export_reports       │PREM  │ [● On] Bật   │ ∞ Không giới │ [PDF, Excel, CSV]│ [READ_ONLY     ▼] │ │
│ ├──────────────────────┼──────┼──────────────┼──────────────┼──────────────────┼───────────────────┤ │
│ │ Quản lý ví           │BASIC │ [● On] Bật   │ 3 ví         │ [Ví nội bộ]      │ [BLOCK_CREATE  ▼] │ │
│ │ wallets              │PREM  │ [● On] Bật   │ ∞ Không giới │ [Tất cả loại ví] │ [READ_ONLY     ▼] │ │
│ └──────────────────────┴──────┴──────────────┴──────────────┴──────────────────┴───────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Các Bước Thực Thi (Tasks)

- [x] **Task 1:** Tạo Component Bảng Ma Trận Phẳng Mật Độ Cao `PermissionMatrixTable.jsx`
  - Render bảng phẳng viền mảnh 1px (`border-slate-200`), phông chữ sắc nét 11px - 13px.
  - Hỗ trợ 3 chế độ xem (View Mode): `ALL` (Đối chiếu 2 gói), `Basic` (Xem riêng gói Basic), `Premium` (Xem riêng gói Premium).
  - Phân tách rõ ràng 4 cột Trụ Cột cho mỗi gói:
    - Cột 1: Access (Toggle On/Off phẳng).
    - Cột 2: Quota (Input số hoặc Badge ∞ Vô hạn).
    - Cột 3: Scope (Badge tóm tắt phạm vi + nút Sửa).
    - Cột 4: Downgrade Policy (Dropdown chọn trực tiếp 1 trong 5 chính sách).
  - Header phân hệ phẳng, có icon thư mục, đếm số tính năng, thu gọn/mở rộng.

- [x] **Task 2:** Tái Cấu Trúc Thanh Công Cụ `PermissionFilterToolbar.jsx`
  - Thêm Segmented Control Tab chuyển đổi giữa `Tất Cả (Đối Chiếu)`, `Gói Basic`, `Gói Premium`.
  - Ô tìm kiếm thanh lịch, dropdown phân hệ tối giản.
  - Nút "Đặt Lại Mặc Định" và "Lưu Thay Đổi (N)" chỉ sáng khi có draft dirty.

- [x] **Task 3:** Cập Nhật `PermissionScopeDrawer.jsx`
  - Giao diện phẳng tối giản phục vụ việc xem và chỉnh sửa chuyên sâu Scope Schema JSON và Downgrade Policy khi cần.

- [x] **Task 4:** Viết Lại Trang Chính `PermissionManagementPage.jsx`
  - Tích hợp View Mode, quản lý state draft, dirty check, batch update, socket realtime.

- [x] **Task 5:** Cập Nhật Từ Điển i18n `vi.js` và `en.js`
  - Bổ sung toàn diện các nhãn mới cho 4 trụ cột, bảng ma trận và các tab.

- [x] **Task 6:** Kiểm Thử 2 Tầng (Rule 11 Compliance)
  - Cập nhật và chạy `rtk npm test src/tests/permission.4pillars.page.test.jsx` (đảm bảo 100% pass cả UI và System Impact: 9/9 PASS).
  - Chạy full test suite Admin-web (100% PASS, bao gồm cả test cũ 5/5 PASS).

- [x] **Task 7:** Cập Nhật CodeGraph & Tài Liệu (Rule 8)
  - Chạy `rtk npx codegraph build`.
