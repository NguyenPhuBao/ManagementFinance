# Ví chung ngay trong form Thêm giao dịch + khoản của nhà ở Trang chủ / Sổ giao dịch

**Ngày:** 2026-11-16 · **Nhánh:** `TranQuangDat-backend` (worktree `.superpowers/backend-worktree`) · **Phạm vi:** chỉ `src/Client-app`.

Người dùng (2026-11-16): *"ví gia đình — cho nó hiển thị lúc tạo giao dịch thông thường luôn — khi tạo giao dịch có thể chọn ví gia
đình luôn — chứ đừng bắt user vào mục gia đình mới thanh toán được"*; bổ sung: *"phần lịch sử giao dịch ở trang chủ hoặc tab lịch sử
thì vẫn hiện giao dịch thuộc nhà"*. Mở lại chốt mã (memory *chốt mã*, 2026-11-02) cho đúng việc này.

## 0. Đảo một quyết định cũ

`docs/Family/02A` mục 4 và chú thích `AddTransactionPage.nha` chốt: khoản của nhà mở từ khu **Nhà mình**, **không** từ nút + của thanh
dưới (quyết định #5 — nút ấy giữ cho dữ liệu cá nhân). Lý do khi ấy: form cá nhân học gợi ý / từ khoá / ngân sách từ lịch sử riêng; khoản
của nhà không được dạy mô hình cá nhân. Thiết kế này **giữ lý do ấy** (khi ví đang chọn là ví chung, mọi thứ học / gợi ý của cá nhân tắt
như ở `/nha/khoan`) và **bỏ phần "phải đi qua Nhà mình"**. Mục 4 của `02A` và chú thích `nha` sửa theo.

Tương tự luật quét 37 (*"dữ liệu của nhà không lọt vào màn cá nhân"*): mở **đúng hai danh sách** (mục 3), mọi con số vẫn chỉ cá nhân.

## 1. Quyết định của người dùng (2026-11-16)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Danh mục khi chọn ví chung | Đổi sang danh mục của nhà; giữ danh mục đang chọn nếu nhà có danh mục **cùng tên** (so `normalizeCategoryName`, cùng classify), không có thì để trống |
| 2 | Ví chung ở đoạn Chuyển khoản | **Không** hiện (góp / rút vẫn ở màn Góp / Rút) |
| 3 | Lối vào | Chỉ bộ chọn ví bằng tay; Nhập nhanh / giọng nói / quét / biến động / C3 / ví tự chọn sẵn vẫn chỉ ví cá nhân |
| 4 | Cách đổi | Đổi **ngay trên form**, không chuyển trang; chọn lại ví cá nhân là form về như cũ |
| 5 | Khoản của nhà ở danh sách | Hiện ở *Giao dịch gần đây* (Trang chủ) và Sổ giao dịch — **chỉ khoản tôi ghi** (`idaccount` = phiên) |
| 6 | Cộng vào tổng | **Không** (người dùng chọn sau ví dụ đếm trùng: góp quỹ đã là một khoản chi cá nhân, cộng thêm khoản chi từ ví chung là một đồng tiền đếm hai lần) |
| 7 | Bấm vào khoản của nhà ở danh sách | Được ghi khoản của nhà → mở form sửa `/nha/khoan`; không (Chỉ xem, nhà chỉ xem, đã rời) → chỉ xem chi tiết |

## 2. Phần 1 — chọn ví chung ở form Thêm giao dịch

### 2.1 Người dùng thấy gì

- Bộ chọn ví (`moBangChonVi`) có thêm nhóm **"VÍ CHUNG · <tên nhà>"** dưới nhóm ví cá nhân. Nhóm chỉ hiện khi **cùng lúc**: đang ở một
  nhà, `duocLamViecNha(ViecNha.ghiKhoan, …)` (Chủ / Thành viên, nhà đang hoạt động), form **tạo mới** thường (không sửa, không mở từ biến
  động / biên lai / ảnh quét), đoạn **Chi tiêu / Thu nhập**, và nhà có ít nhất một ví chung đang hoạt động. Bộ chọn ví ĐÍCH không bao giờ có nhóm này.
- Chọn ví chung ⇒ form đổi tại chỗ: nhãn `NhanNha` "Khoản của nhà · <tên nhà>" dưới hàng chip; nhãn ô ví "Ví chung"; tiêu đề
  `tieuDeFormNha`; danh mục đổi theo quyết định 1; ẩn Nhập nhanh, micro, tách, thẻ gợi ý, đề xuất từ khoá; nút chọn danh mục mở
  `/nha/khoan/category`. Số tiền, ghi chú, ngày giữ nguyên. Chip Chuyển khoản: bấm ⇒ form về ví cá nhân chọn sẵn (`chonViChonSan`) rồi mới sang
  Chuyển khoản.
- Chọn lại ví cá nhân ⇒ form về chế độ cá nhân: danh mục đổi ngược theo cùng luật cùng tên, gợi ý chạy lại.
- Lưu ⇒ khoản mang `idhousehold` của ví; về trang trước như mọi lần lưu.

### 2.2 Bên dưới

- **Cổng `ViChungChoForm`** — interface Dart thuần ở `transaction/data/` (mảng giao dịch không import gia đình), bản thật ở
  `household/data/vi_chung_cho_form_nha.dart`, đăng ký DI. Một lời gọi `nap()` → `({int idNha, String tenNha, List<WalletEntity> vi,
  CheDoNhaForm cheDo, ThemGiaoDichNguon nguon})?`: `await choNapKho()` (G92) trước khi đọc vai; `null` khi không có nhà / không được ghi /
  không có ví chung. `vi` = `DuLieuNhaRepository.viChungChoForm(idNha)`; `nguon` = `ThemGiaoDichNguonNha`; `cheDo.conDuocGhi` = closure
  `conDuocLamViecNha` như route `/nha/khoan`; `cheDo.choChuyen = false` (quyết định 2).
- **State:** `ThemGiaoDichState` thêm `viChung` (danh sách RIÊNG, không trộn vào `vi`) và `nhaDangGhi` (`CheDoNhaForm?`). `state.vi` giữ
  nguyên nghĩa, nên `dienKetQua`, `vi_chon_san`, `vi_hay_dung`, ví theo nguồn tin không bao giờ thấy ví chung (quyết định 3).
- **Cubit:** nguồn đang dùng = `nhaDangGhi == null ? nguồn cá nhân : nguồn nhà`. Phép đổi chế độ (đổi nguồn, nạp lại danh mục, ghép tên danh
  mục, xoá gợi ý / tách / đề xuất từ khoá, quay về ví cá nhân khi sang Chuyển khoản) tách ra tệp riêng
  `presentation/bloc/doi_che_do_nha.dart` (cubit đang 1.140 / trần 1.200 của quét 23). `chonVi(w)` rẽ: `w` thuộc `viChung` ⇒ vào chế độ nhà.
  Mọi phép học / ghi phản hồi đọc nguồn đang dùng, nên ở chế độ nhà chúng không làm gì (nguồn nhà là no-op).
- **Trang:** mọi chỗ đang đọc `widget.nha` đổi sang `_nha` = `widget.nha ?? _s.nhaDangGhi` (một getter). Route `/nha/khoan` vẫn truyền
  `widget.nha` như cũ; ở route ấy cổng không nạp (form đã cố định ở nhà).
- **Lưu:** `idhousehold` = `_nha?.idNha`; hỏi lại quyền `_nha?.conDuocGhi` ngay lúc Lưu (khuôn FINAL I-3). Khoản sửa không bao giờ đổi
  `idhousehold` (đường sửa không có nhóm ví chung).
- **Route `/add`** (và các route `/add*` dựng trang tạo mới thường) truyền `viChung: sl<ViChungChoForm>()`; test dựng trang không truyền ⇒
  không có nhóm (hành vi cũ).

## 3. Phần 2 — khoản của nhà ở Trang chủ và Sổ giao dịch

- **DAO:** thêm truy vấn danh sách "của tôi kèm khoản nhà tôi ghi": `idaccount = tôi ∧ (idhousehold IS NULL ∨ idhousehold IS NOT NULL)` cho
  khoảng `[from, to)` (Sổ) và cho danh sách gần đây (Trang chủ). Hai hàm ấy vào `_mienTru` của quét 37 kèm lý do; mọi truy vấn khác không đổi.
- **Danh sách:** *Giao dịch gần đây* (Trang chủ) và danh sách Sổ dùng truy vấn mới. Dòng của nhà có nhãn nhỏ "Ví chung · <tên nhà>"; tên ví
  và danh mục tra qua bảng tra của nhà (cổng đọc tên ví chung + danh mục nhà, bản thật ở `household/data`), vì bảng tra cá nhân không có chúng.
- **Tổng (quyết định 6):** một định nghĩa `vaoTongCaNhan(tx)` ở `transaction/domain/` = `tx.idhousehold == null && khoanVaoThongKe(…)`. Thẻ
  tổng Sổ, tổng theo ngày (`summarizeTransactions`) đi qua nó. Trang chủ: thu chi tháng, số dư, khối Nhận xét giữ stream chỉ-cá-nhân hiện
  có (`watchAll`); chỉ danh sách gần đây đổi stream. Phân tích, Ngân sách, Báo cáo, trợ lý AI, gợi ý / học: không đổi.
- **Bộ lọc Sổ:** không thêm ví chung / danh mục nhà vào bộ lọc; lọc theo ví hay danh mục cá nhân thì khoản của nhà tự rơi khỏi danh sách.
  Thẻ *"Có N giao dịch chưa có danh mục"* (C1) vẫn đếm chỉ cá nhân.
- **Bấm dòng (quyết định 7):** cổng `MoKhoanNha` (bản thật gọi lại `mo_khoan_nha.dart`, kiểm `ViecNha.ghiKhoan` sau `choNapKho`) — được ghi
  ⇒ `push('/nha/khoan', extra: EditTransactionArgs(...))`; không ⇒ sheet chi tiết không nút sửa / xoá.

## 4. Giao diện mới → Stitch trước

Nhóm "VÍ CHUNG · <tên nhà>" trong bảng chọn ví; nhãn nhà trên dòng giao dịch ở Sổ / Trang chủ. Đưa lên dự án Stitch `FlowMoney`, người dùng
duyệt rồi mới dựng.

## 5. Kiểm thử

Viết test trước (TDD): cubit đổi chế độ hai chiều (giữ số tiền / ghi chú / ngày, ghép danh mục cùng tên, sang Chuyển khoản thì về ví cá nhân,
`state.vi` không chứa ví chung, gợi ý không chạy ở chế độ nhà); cổng `ViChungChoForm` (Viewer / nhà chỉ xem / không nhà ⇒ `null`; chờ kho);
trang (nhóm hiện / ẩn theo điều kiện 2.1, lưu mang `idhousehold`, quyền đổi lúc Lưu ⇒ không lưu); DAO (khoản nhà của người khác không vào);
`vaoTongCaNhan` (khoản nhà hiện trong danh sách, không vào thẻ tổng / tổng ngày); quét 37 (mục miễn trừ mới); bấm dòng nhà theo vai. Rồi
`flutter test` + `flutter analyze` so mốc nền. Đo trên Realme: tài khoản đang ở một nhà có ví chung, backend Render.

## 6. Tài liệu đi kèm

`docs/Family/02A` mục 4 (bỏ "không từ nút +", trỏ spec này); chú thích `AddTransactionPage.nha` và `CheDoNhaForm`; docstring quét 37; hàng
*Đụng vào gia đình* ở `CLAUDE.md`; khối 🏠 mục 14 `PROJECT_CONTEXT.md`; memory *chốt mã*.
