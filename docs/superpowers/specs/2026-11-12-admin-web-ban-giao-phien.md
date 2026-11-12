# Bàn giao phiên: làm lại giao diện Admin-web

Ngày: 2026-11-12. Đọc tệp này đầu tiên khi mở phiên mới, rồi làm theo mục "Bắt đầu phiên mới".

## Lệnh mở phiên (dán cho Claude)

> #build Tiếp tục làm lại giao diện Admin-web theo `docs/superpowers/specs/2026-11-12-admin-web-ban-giao-phien.md`. Đọc tệp bàn giao, đặc tả và kế hoạch trước, báo lại trạng thái rồi chờ lệnh.

## Bắt đầu phiên mới

1. Đọc theo thứ tự:
   - `CLAUDE.md` (chế độ `[BUILD]`, vai và model, Chủ dự án quyết định cuối).
   - `docs/superpowers/specs/2026-11-12-admin-web-giao-dien-design.md`: hệ thiết kế (mục 3), thành phần (4), danh mục chức năng = chuẩn nghiệm thu (5), quy tắc nội dung (6), kiểm thử (7), **tiến độ (8)**.
   - `docs/superpowers/plans/2026-11-12-admin-web-lam-lai-giao-dien.md`: công thức làm một màn hình, G0–G5.
2. Kiểm trạng thái: `git log --oneline -5`, `git status --short | grep -v src/Client-app`.
3. Chạy mức nền trong `src/Admin-web`: `npm test` (mong đợi 78/78), `npm run lint`, `npm run build`.

## Trạng thái

- Nhánh `NguyenPhuBao`. Đã commit: G0 `92d29c61`, G1 `43ef61df`, G2.1 `1ce28def`, G2.2 `f832176a`, G2.3 `56befb6a`, G2.4 `4ea70c7f`, G2.5 xóa đơn mẫu (commit kế sau, xem `git log`).
- Không thuộc việc này, đừng đưa vào commit: `.gitignore`, `CLAUDE.md`, `Project.md`, `docs/AI/*` (sửa dở từ trước), `src/Client-app/*` (tệp sinh tự động của Flutter).
- Việc kế tiếp: G3.1 Tổng quan → G3.2 Phân quyền → G3.3 Bảo trì & Thông báo → G4 → G5 (bảng ở mục 8.4).
- Khi cần commit tách từng phần của `vi.js` / `en.js`: mỗi trang là một khối khóa cấp 1 riêng; ghép khối vào chỉ mục bằng `git hash-object -w --path=<tệp>` + `git update-index --cacheinfo`.

## Quy tắc làm việc đã chốt trong phiên

- Commit / push chỉ khi Chủ dự án ra lệnh; **không** thêm dòng `Co-Authored-By` hay "Generated with Claude Code".
- Chủ dự án tự đổi model. Chủ dự án đã cho làm luôn bằng model hiện tại, không cần chuyển sang Sonnet.
- Chỉ sửa trong thư mục dự án này; không đụng hai worktree NCKH (`../FlowMoney-NCKH-*`) và không đụng `src/Client-app`.
- Mỗi màn hình: viết test hai tầng trước (phải đỏ) → làm lại giao diện → xóa chú thích → rút chữ ở cả `vi.js` và `en.js` → `npm test`, lint, build → thử một bản sai có chủ ý → chụp trình duyệt Sáng / Tối → báo Chủ dự án.
- Giữ nguyên lời gọi API, tên sự kiện socket, `data-testid` đang có. Danh mục chức năng mục 5 của đặc tả là chuẩn, không bỏ chức năng nào.

## Môi trường thử cục bộ

- CSDL `flowmoney_adminweb` (PostgreSQL 18 cục bộ, sao từ `flowmoney_nckh`). Tài khoản thử chỉ có ở CSDL này: `admin.local` / `AdminWeb@2026`, PIN `246810`.
- Bật Backend (cổng 3010, Redis cục bộ DB 3) + Admin-web (cổng 5180): chạy nền `node scratch/adminweb/khoi_dong_adminweb.js "<gốc repo>"`. Không sửa `.env`. Log ở `scratch/adminweb/*.log`; kiểm dòng `PostgreSQL connected {"database":"flowmoney_adminweb"}`.
- Chụp màn hình bằng Playwright Python có sẵn + Edge (`agent-browser` chưa cài): xem mẫu `scratch/adminweb/chup_*.py`, chạy bằng `python` thường (không `-I`). Kiểm dữ liệu: `scratch/adminweb/check_*.js` (dùng `pg.js`, đọc mật khẩu `postgres` từ `scratch/setup_test_db.js`).
- Thay cả một khối khóa ngôn ngữ: `node scratch/adminweb/splice.js <vi.js|en.js> <tệp khối> <khóa> <khóa kế tiếp>`; khối cuối tệp dùng `splice_last.js`.
- Không bấm "Tạo đơn thử" ở trang Thanh toán khi kiểm: Backend gọi PayOS thật.
- Dữ liệu thử còn lại: danh mục "Thử giao diện mới" đã xóa mềm (để nguyên, không xóa vật lý); đơn thật thử `#990000052603` (EXPIRED) chèn tay để đối chứng khi xóa đơn mẫu.
- Thử nút "Xóa đơn mẫu" không cần PayOS: `node scratch/adminweb/seed_don_mau.js "<gốc repo>" seed` chèn đơn mẫu thẳng vào `flowmoney_adminweb` (đối số `xem` chỉ in bảng đơn), rồi `python scratch/adminweb/chup_xoa_mau.py <thư mục ảnh>`.
- Backend chạy `node index.js` (không tự nạp lại): sửa mã Backend thì tắt tiến trình `khoi_dong_adminweb.js` cùng hai tiến trình con rồi bật lại.

## Bẫy đã gặp

- Biểu tượng Material Symbols là chữ ligature: luôn dùng `<Icon>` (có `aria-hidden`), và không đặt biểu tượng hay dòng gợi ý bên trong `<label>`; dùng `htmlFor` + `id`.
- Token mới tên `canvas`, `card`, `muted`, `line`, `ink*`, `brand*`, `success|warning|danger|quiet|info(-soft)`, `overlay`; token cũ (`surface`, `primary`, `on-surface`…) còn giữ tới G5 nên đừng xóa sớm.
- Trang chưa làm lại vẫn lệch màu ở chế độ Tối (dùng token cũ + luật `.dark` cũ trong `index.css`); hết dần khi làm lại từng trang.
- `Tabs` cho phép `value` không khớp tab nào (ví dụ bộ lọc mặc định của trang Người dùng).
- `SecurityConfirmModal` tự gọi `verifySecurityAction` rồi mới gọi `onConfirm`; nếu `onConfirm` ném lỗi thì hộp giữ nguyên và hiện lỗi, nên hàm lưu phải ném lỗi khi thất bại.
- Kiểm tra máy móc cuối mỗi tệp: không còn dòng chú thích (`^\s*(//|/\*|\*|\{/\*)`), không mã màu hex, không `text-[..px]`.
