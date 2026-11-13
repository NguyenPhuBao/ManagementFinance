# Bàn giao phiên: làm lại giao diện Admin-web

Ngày: 2026-11-12, cập nhật 2026-11-13. Đọc tệp này đầu tiên khi mở phiên mới, rồi làm theo mục "Bắt đầu phiên mới".

## Lệnh mở phiên (dán cho Claude)

> #build Tiếp tục làm lại giao diện Admin-web theo `docs/superpowers/specs/2026-11-12-admin-web-ban-giao-phien.md`. Đọc tệp bàn giao, đặc tả và kế hoạch trước, báo lại trạng thái rồi chờ lệnh.

## Bắt đầu phiên mới

1. Đọc theo thứ tự:
   - `CLAUDE.md` (chế độ `[BUILD]`, vai và model, Chủ dự án quyết định cuối).
   - `docs/superpowers/specs/2026-11-12-admin-web-giao-dien-design.md`: hệ thiết kế (mục 3), thành phần (4), danh mục chức năng = chuẩn nghiệm thu (5), quy tắc nội dung (6), kiểm thử (7), **tiến độ (8)**.
   - `docs/superpowers/plans/2026-11-12-admin-web-lam-lai-giao-dien.md`: công thức làm một màn hình, G0–G5.
2. Kiểm trạng thái: `git log --oneline -5`, `git status --short | grep -v src/Client-app`.
3. Chạy mức nền trong `src/Admin-web`: `npm test` (mong đợi 141/141, 12 tệp), `npm run lint`, `npm run build`.

## Trạng thái

- Nhánh `NguyenPhuBao`. Đã commit: G0 `92d29c61`, G1 `43ef61df`, G2.1 `1ce28def`, G2.2 `f832176a`, G2.3 `56befb6a`, G2.4 `4ea70c7f`, G2.5 `2ee34db5`, G3.1 `abd7b496`, G3.2 `d5a959ef`, G3.3 `b4118641`, G4.2 `a0c15b0d` (hộp Cài đặt, kèm sửa "Đã trừ 0 phút bảo trì" ở Tổng quan).
- G4.3 đã làm xong, đã kiểm trên trình duyệt, **chưa commit** (chờ lệnh). Tệp thuộc commit G4.3: `pages/auth/{LoginPage,ForgotPasswordPage,AuthShell}.jsx`, `components/layout/{LockScreenModal,FirstLoginModal}.jsx`, `components/ui/{Modal,PasswordInput,index}`, `locales/{vi,en}.js` (khối `lockScreen`, `firstLogin`, `auth`), `tests/{auth,ui}.test.jsx`, hai tài liệu `2026-11-12-admin-web-*.md`.
- Việc kế tiếp sau commit G4.3: G4.1 AIOps, chờ lệnh Chủ dự án.
- Không thuộc việc này, đừng đưa vào commit: `.gitignore`, `CLAUDE.md`, `Project.md`, `docs/AI/*` (sửa dở từ trước), `src/Client-app/*` (tệp sinh tự động của Flutter).
- Việc kế tiếp (Chủ dự án chốt 2026-11-13): G4.3 Đăng nhập, Quên mật khẩu, Khóa màn hình, Đăng nhập lần đầu → G4.1 AIOps (chia 2–3 commit theo khối) → G5. Kế hoạch không có G6.
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
- Chụp trang Tổng quan (Sáng, Tối, tooltip, bộ chọn ngày, điện thoại): `python scratch/adminweb/chup_dash.py <thư mục ảnh>`.
- Chụp trang Phân quyền và lưu thật (đổi một hạn mức rồi trả lại): `python scratch/adminweb/chup_perm.py <thư mục ảnh>`. Tìm phần tử gây cuộn ngang trên điện thoại: `python scratch/adminweb/do_tran.py <đường dẫn không có / đầu>`.
- Nhãn `sr-only` trong bảng định vị tuyệt đối: khung cuộn của bảng phải có `relative`, nếu không nhãn thoát ra làm cả trang cuộn ngang.
- Chụp trang Bảo trì & Thông báo và chạy thật (lên lịch rồi hủy, bật khẩn cấp rồi kết thúc): `python scratch/adminweb/chup_bt.py <thư mục ảnh>`. Bật / tắt khẩn cấp làm Backend tự phát thông báo hệ thống (chỉ tới client đang nối máy chủ cục bộ); không bấm "Gửi thông báo" thật.
- Khóa `broadcast.banner.emergencyBadge` / `silentBadge` còn được `ServerHealthPanel` dùng, giữ tới G4.1.
- Biểu đồ SVG: vẽ theo bề rộng đo thật (`ResizeObserver`), đừng dùng `viewBox` cố định + `preserveAspectRatio="none"` (chữ co theo khung).
- `useLanguageSafe` ngoài provider (trong test) trả `t` mới mỗi lần render: đừng đặt `t` vào mảng phụ thuộc của `useEffect` có gọi API.
- Thử nút "Xóa đơn mẫu" không cần PayOS: `node scratch/adminweb/seed_don_mau.js "<gốc repo>" seed` chèn đơn mẫu thẳng vào `flowmoney_adminweb` (đối số `xem` chỉ in bảng đơn), rồi `python scratch/adminweb/chup_xoa_mau.py <thư mục ảnh>`.
- Chụp hộp Cài đặt và chạy thật: `python scratch/adminweb/chup_settings.py <thư mục ảnh>`. Kịch bản đổi PIN `admin.local` 246810 → 135790 rồi trả về 246810; nếu kịch bản dừng giữa chừng, PIN có thể đang là 135790, đổi lại trước khi dùng. Không bấm "Cấp tài khoản" thật (tạo tài khoản trong CSDL thử, không xóa vật lý được).
- Chụp bốn màn hình đăng nhập và chạy thật: `python scratch/adminweb/chup_auth.py <thư mục ảnh>` (đăng nhập sai rồi đúng, Khóa ngay rồi mở khóa, hộp xác nhận đăng xuất bấm Hủy, Quên mật khẩu VI / EN, Đăng nhập lần đầu giả lập bằng chặn phản hồi `/auth/me` trong trình duyệt, Sáng / Tối, điện thoại). Kiểm PIN và cờ lần đầu của `admin.local` chỉ đọc: `node scratch/adminweb/check_pin.js "<gốc repo>"`.
- Quên mật khẩu là trang tĩnh (số điện thoại hỗ trợ), không gửi OTP hay email.
- Backend chạy `node index.js` (không tự nạp lại): sửa mã Backend thì tắt tiến trình `khoi_dong_adminweb.js` cùng hai tiến trình con rồi bật lại.

## Bẫy đã gặp

- Biểu tượng Material Symbols là chữ ligature: luôn dùng `<Icon>` (có `aria-hidden`), và không đặt biểu tượng hay dòng gợi ý bên trong `<label>`; dùng `htmlFor` + `id`.
- Token mới tên `canvas`, `card`, `muted`, `line`, `ink*`, `brand*`, `success|warning|danger|quiet|info(-soft)`, `overlay`; token cũ (`surface`, `primary`, `on-surface`…) còn giữ tới G5 nên đừng xóa sớm.
- Trang chưa làm lại vẫn lệch màu ở chế độ Tối (dùng token cũ + luật `.dark` cũ trong `index.css`); hết dần khi làm lại từng trang.
- `Tabs` cho phép `value` không khớp tab nào (ví dụ bộ lọc mặc định của trang Người dùng).
- `SecurityConfirmModal` tự gọi `verifySecurityAction` rồi mới gọi `onConfirm`; nếu `onConfirm` ném lỗi thì hộp giữ nguyên và hiện lỗi, nên hàm lưu phải ném lỗi khi thất bại.
- Hộp con có biểu mẫu (đổi PIN, mật khẩu, cấp tài khoản…): chỉ dựng khi mở (`{open && <Hop />}`) để mỗi lần mở là trạng thái mới; đừng xóa trắng bằng `useEffect([open])` vì dữ liệu cũ hiện ra một nhịp và đè lên phần người dùng vừa gõ.
- Hộp chồng hộp: hộp cha đặt `closeDisabled` khi hộp con đang mở để phím Esc chỉ đóng hộp con.
- Hộp che trang vì lý do an toàn (Khóa màn hình, Đăng nhập lần đầu) dùng `Modal backdrop="solid"`; lớp phủ mặc định chỉ mờ 50% nên vẫn đọc được số liệu phía sau.
- Luật cũ `.dark header { background: #0f172a !important }` trong `index.css` đè màu của mọi thẻ `<header>` ở chế độ Tối tới G5; đặt `bg-card` cho thẻ `header` mới để hai chế độ khớp nhau.
- Đăng nhập lần đầu lấy cờ `is_first_login` từ `/auth/me` mỗi lần tải trang, sửa `localStorage` không giả lập được.
- Kiểm tra máy móc cuối mỗi tệp: không còn dòng chú thích (`^\s*(//|/\*|\*|\{/\*)`), không mã màu hex, không `text-[..px]`.
