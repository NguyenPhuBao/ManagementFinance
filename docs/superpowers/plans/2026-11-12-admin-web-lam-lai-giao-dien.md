# Kế hoạch thi công: làm lại giao diện Admin-web

- Ngày: 2026-11-12. Đặc tả: `docs/superpowers/specs/2026-11-12-admin-web-giao-dien-design.md` (hệ thiết kế mục 3, thành phần mục 4, **danh mục chức năng mục 5**, quy tắc nội dung mục 6, kiểm thử mục 7).
- Mockup đã duyệt: https://claude.ai/artifact/CMuRNJCzF45LJYtyBjs9k8
- Phạm vi tệp: chỉ `src/Admin-web/**` và tài liệu Admin-web. Không đụng Backend, Client-app, API, sự kiện socket, nghiệp vụ.
- Vai: Lead PO + Lead BA (Opus 5.5 Medium) lập đặc tả từng bước và nghiệm thu; Lead FullStack (Sonnet 5.5 High) hiện thực. Chủ dự án tự đổi model; Claude dừng và báo khi cần chuyển vai.
- Commit / push: chỉ khi Chủ dự án ra lệnh, không dòng ghi công AI.

## Công thức làm một màn hình (áp cho mọi bước G1–G4)

1. **Đặc tả (Lead PO):** chép dòng của màn hình ở đặc tả mục 5 thành danh sách AC đánh số; liệt kê chuỗi chữ cần rút gọn (mục 6).
2. **Test đỏ (FullStack):** viết `src/tests/<man-hinh>.test.jsx`, mock API, có cả hai tầng. Có ít nhất một ca khẳng định cấu trúc mới (vd. `h1` từ `PageHeader`, `role="tablist"`, `Badge`) để chắc ca đỏ trên mã cũ. Chạy, ghi lại ca đỏ.
3. **Làm lại (FullStack):** thay JSX bằng thành phần `components/ui`; trang dài thì tách khối con vào thư mục của trang; xóa chú thích; rút chữ ở `vi.js` + `en.js`; bỏ hex viết cứng và cỡ chữ `text-[..px]`.
4. **Xanh:** `npm test`, `npm run lint`, `npm run build` đều qua.
5. **Nghiệm thu (Lead PO):** đọc diff; tích từng AC; chạy lại test; xem trên trình duyệt cả Sáng và Tối (cần Backend chạy cục bộ với CSDL thử, không dùng Supabase chung; nếu chưa có thì báo Chủ dự án trước).
6. **Báo Chủ dự án:** AC đạt / chưa đạt, ảnh chụp, lệnh đã chạy. Chờ lệnh commit.

Kiểm tra máy móc cuối mỗi màn hình (lệnh chạy từ `src/Admin-web`):
- Chú thích còn sót: `grep -nE '^\s*(//|/\*|\*|\{/\*)' <tệp> | grep -v eslint-disable` → rỗng.
- Hex viết cứng: `grep -nE '#[0-9a-fA-F]{6}' <tệp>` → rỗng (ngoại lệ: màu trong biểu đồ SVG lấy từ token).
- Cỡ chữ tùy ý: `grep -n 'text-\[' <tệp>` → rỗng.

## G0. Nền

### G0.1 Gỡ bộ test cũ, sửa lint
- Xóa `src/tests/*.test.jsx` (52 tệp). Giữ `src/tests/setup.js`.
- `.eslintrc.cjs`: thêm `overrides` cho `src/tests/**` với các biến toàn cục của vitest (`describe`, `it`, `test`, `expect`, `vi`, `beforeEach`, `afterEach`, `beforeAll`, `afterAll`); thêm plugin `react-hooks` (đã có trong devDependencies) để hai chỉ thị `react-hooks/exhaustive-deps` ở `PermissionManagementPage.jsx` hết lỗi (hoặc gỡ khi xóa chú thích ở G3).
- AC: `npm run lint` 0 lỗi; `npm test` không lỗi cấu hình (chưa có ca nào là chấp nhận được ở bước này, dùng `--passWithNoTests` trong script `test` cho tới khi G0.3 có test).

### G0.2 Token
- `src/styles/theme.css`: biến CSS theo đặc tả mục 3 cho `:root` và `.dark`.
- `tailwind.config.js`: thêm màu ngữ nghĩa trỏ tới biến CSS (`bg`, `surface`, `subtle`, `border`, `text`, `text-muted`, `text-faint`, `primary`, `primary-soft`, `success`, `warning`, `danger`, `neutral`, `info` kèm biến thể nền). **Giữ token cũ tới G5** để trang chưa làm vẫn chạy.
- AC: `npm run build` qua; giao diện các trang cũ không đổi.

### G0.3 Thành phần `src/components/ui/`
- Tạo: `Icon`, `Button`, `PageHeader`, `StatCard`, `Tabs`, `SearchInput`, `Card`, `DataTable`, `Pagination`, `Badge`, `Modal`, `ConfirmModal`, `SecurityConfirmModal`, `Spinner`, `EmptyState`, `index.js` (xuất gộp).
- `components/common/ConfirmModal.jsx`, `SecurityConfirmModal.jsx`, `Pagination.jsx`, `Loading.jsx`, `EmptyState.jsx`: chuyển thành tệp tái xuất từ `ui/` để nơi đang import không vỡ; xóa ở G5.
- Test `src/tests/ui.test.jsx` (viết trước, đỏ):
  - Tầng 1: `Button` `loading` thì `disabled`; nút `icon` có `aria-label`; `Tabs` có `role="tablist"` và đúng một `aria-selected="true"`; `Modal` đóng bằng Esc; `DataTable` hiện `EmptyState` khi rỗng và `Spinner` khi tải; `Badge` đúng tông.
  - Tầng 2: `Tabs` gọi `onChange` với khóa đúng; `Pagination` gọi `onPageChange(n)`; `ConfirmModal` gọi `onConfirm` một lần; `SecurityConfirmModal` gọi `verifySecurityAction` với PIN đã nhập và chỉ gọi `onSuccess` khi API trả thành công.
- AC: test xanh, lint sạch, build qua.

## G1. Khung
Tệp: `components/layout/AppLayout.jsx`, `Sidebar.jsx`, `Header.jsx`, `components/common/RealtimeStatusBadge.jsx`, `LanguageToggle.jsx`.
Test `src/tests/layout.test.jsx`: 8 mục menu đúng đường dẫn, mục đang chọn có `aria-current="page"`; thu gọn sidebar; đăng xuất gọi `logout`; danh sách cảnh báo tải từ `getAdminAlerts`, đánh dấu đã đọc gọi `markAdminAlertAsRead(id)`; sự kiện `admin.notification` thêm cảnh báo mới; `admin.maintenance_changed` hiện / ẩn banner bảo trì; nút giảm thiểu nhanh gọi đúng API.

## G2. Bốn trang danh sách (theo thứ tự)
1. **Người dùng** `pages/users/UserListPage.jsx` (mẫu cho các trang sau, bám mockup) + `components/common/UserDetailModal.jsx`. Gỡ `pages/users/UserDetailPage.jsx`, route `/users/:id`, khóa `users.detail.*` nếu không còn nơi dùng (kiểm bằng `grep` trước khi xóa). Test `users.test.jsx`.
2. **Danh mục** `pages/categories/CategoryPage.jsx`: thay hộp PIN tự dựng bằng `SecurityConfirmModal`, giữ cơ chế bản nháp. Test `categories.test.jsx`.
3. **Thanh toán** `pages/payments/PaymentHistoryPage.jsx`: tách khối (bộ lọc, bảng, hộp chi tiết, hộp hoàn tiền) vào `pages/payments/components/`. Test `payments.test.jsx`.
4. **Nhật ký** `pages/system/AuditLogPage.jsx`. Test `audit.test.jsx`.

## G3. Trang chức năng
1. **Tổng quan** `pages/dashboard/DashboardPage.jsx`: tách biểu đồ thành `pages/dashboard/components/LineChart.jsx`, màu lấy từ token. Test `dashboard.test.jsx`.
2. **Phân quyền** `pages/system/PermissionManagementPage.jsx` + 4 tệp `pages/system/components/Permission*.jsx`. Test `permissions.test.jsx`.
3. **Bảo trì & Thông báo** `pages/system/BroadcastPage.jsx`: tách hai tab vào `pages/system/broadcast/`. Test `broadcast.test.jsx`.

## G4. Trang lớn và hộp thoại
1. **AIOps** `pages/system/AIOpsPage.jsx` (3.956 dòng) → `pages/system/aiops/` theo khối: quy mô + hiệu chuẩn, chỉ số an ninh, xu hướng, sự cố + điều tra, cách ly + chặn, vector. Trang chính chỉ ghép khối và giữ đăng ký socket. `components/common/ServerHealthPanel.jsx` làm lại cùng bước. Test `aiops.test.jsx` (có thể tách theo khối).
2. **Cài đặt** `components/layout/SettingsModal.jsx` (1.498 dòng) → tách theo nhóm cài đặt. Test `settings.test.jsx`, gồm chế độ Tối gắn lớp `.dark` lên `<html>`.
3. **Đăng nhập, Quên mật khẩu, Khóa màn hình, Đăng nhập lần đầu.** Test `auth.test.jsx`.

## G5. Dọn và đồng bộ tài liệu
- Xóa token cũ trong `tailwind.config.js`, `theme.css`; lớp cũ trong `index.css` (`bento-grid`, `stat-card`, `modal-overlay`…); các tệp tái xuất ở `components/common/`.
- Quét toàn `src/`: không chú thích, không hex viết cứng ngoài token, không `text-[..px]`, không `style={{` trừ giá trị động (độ rộng thanh tiến trình…).
- Xóa khóa ngôn ngữ không còn dùng (so `vi.js` với `en.js`, hai tệp cùng bộ khóa).
- Cập nhật `Project.md` mục 3.4 (Admin-web), `docs/Admin-web/README.md`, `docs/progress/Backend.md` hoặc tệp tiến độ Admin-web tương ứng.
- AC cuối: `npm test` xanh toàn bộ, `npm run lint` 0 lỗi, `npm run build` qua; Chủ dự án duyệt trên trình duyệt từng màn hình.

**Danh mục dọn theo khảo sát 2026-11-14** (đếm bằng script, chưa sửa mã):
- Tài liệu: đã đồng bộ `Project.md` 3.4, `docs/Admin-web/README.md` (cài đặt, test, bố cục), `04` (§6, API thiết bị / chính sách / bản sao), `06` (§6 có tab Sự cố dữ liệu, API sổ sự cố, IP đã che), `09` (§6 theo giao diện G4.1, bảng API đúng route thật).
- `tailwind.config.js`: 47 token màu cũ; chỉ 10 còn dùng, và chỉ trong `src/index.css` → xóa cùng luật CSS dùng chúng.
- `src/index.css`: 3 lớp không còn nơi dùng (`keyword-scrollbar`, `table-responsive-container`, `responsive-table-wrapper`); luật `.dark header` cũ.
- `components/common/` tái xuất: `ConfirmModal`, `EmptyState`, `Pagination`, `SecurityConfirmModal` không còn nơi import → xóa; `Loading` còn 1 nơi (`router/ProtectedRoute.jsx`) → đổi import sang `components/ui` rồi xóa.
- Chú thích còn ở 18 tệp (236 dòng; nhiều nhất `api/payment.api.js`, `store/settings.context.jsx`); hex còn ở `utils/format.js` (8); `text-[..px]` 0; `style={{` 6 tệp đều là giá trị động (giữ).
- Khóa ngôn ngữ: vi / en cùng 1.208 khóa; khoảng 34 khóa có thể không dùng (31 ở `common`) → kiểm tay khóa ghép động trước khi xóa.
- ✅ Đã dọn 2026-11-14: hàm API không nơi gọi (`getDashboardStats`, `syncCategories`, `unblockQuarantine`, `broadcastNotification`, `getPayosQr`), `api/sync.api.js`, `hooks/usePagination.js`, 5 tệp tái xuất ở `components/common/`, `useAuthSafe`, `useLanguage`, 9 hằng số và 6 hàm định dạng không dùng; route Backend `DELETE /aiops/quarantine/:hash`, `GET /payments/payos-qr`.
- Đặc tả 8.4: chuyển `Field`, `FormError`, `inputClass` từ `components/layout/settings/settingsUi` sang `components/ui`.

## Rủi ro và cách lùi

| Rủi ro | Cách xử lý |
|---|---|
| Sót chức năng khi viết lại | Danh mục mục 5 là AC; test tầng 2 cho từng API / socket của màn hình |
| Bỏ test cũ làm mất lưới an toàn trong lúc làm | Mỗi màn hình có test mới trước khi đụng mã; màn hình chưa làm thì chưa có test (chấp nhận theo quyết định Chủ dự án) |
| Trang cũ vỡ khi đổi token | Giữ token cũ tới G5 |
| Xem trình duyệt cần Backend + CSDL | Dùng CSDL thử cục bộ; chưa có thì báo, không chạy trên Supabase chung |
| Mỗi bước hỏng | Mỗi màn hình là một commit riêng, lùi bằng `git revert` |
