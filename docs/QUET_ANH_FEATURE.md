# Quét ảnh hoá đơn / biên lai (A5) — và tách khoản chi theo danh mục

> **Trạng thái (2026-10-08):** **mã xong cả hai phần** — Quét (Task 1–8) và Tách theo danh mục + chọn món
> (Task 10–13) của kế hoạch `docs/superpowers/plans/2026-10-08-a5-quet-va-tach-danh-muc.md` (gitignore).
> 🚧 **Chưa nghiệm thu máy thật** (Task 14 — cần người dùng chụp ≥ 5 hoá đơn giấy, mục 7).
> Spec: `docs/superpowers/specs/2026-10-07-a5-quet-hoa-don-bien-lai-design.md` (mục 1–9 quét, 10 ngoài phạm vi / A5b,
> 11 tách + 11.2b chọn món).

## 1. Luồng

Trang chủ → **Quét** → bottom sheet *Chụp ảnh · Chọn ảnh có sẵn* (`moQuet`) → `image_picker` (máy ảnh / trình chọn ảnh
hệ thống, `maxWidth 1280`) → màn `/quet` *"Đang đọc ảnh…"* (`QuetAnhPage`):

1. Chép ảnh vào `KhoAnhQuet` (`filesDir/anh_quet/`, xoá ảnh cũ trước — mỗi lúc một ảnh).
2. ML Kit qua `DocChuAnh` → `ghepDongTheoHang` → `docAnhQuet` (luật): nhận loại ảnh (`loaiAnhQuet`), đọc
   hoá đơn (`docHoaDonTuChu` + `docMonHang`) hoặc biên lai (`docBienLai`).
3. Còn ô thiếu (`oThieu`) + **Premium** + mô hình + công tắc AI → *"Đang đọc bằng AI…"*: `DocAnhBangAi` (phiên một tool
   `dien_anh_quet`) → lưới `lapTuAi`.
4. `pushReplacement('/add?khoa=quet:<ảnh>&…')` (`deeplinkQuet`) — form Thêm giao dịch điền sẵn, dải *"Từ ảnh quét ·
   dd/MM HH:mm"* (+ *"· Đọc bằng AI"*). Không ghi gì cho tới khi người dùng bấm Lưu.

Huỷ ở pha luật → về Trang chủ, xoá ảnh. Huỷ ở pha AI → dừng lượt sinh, mở form với kết quả luật. Back = Huỷ.
Không đọc ra chữ / số tiền → form vẫn mở + toast *"Chưa đọc được ảnh / số tiền — nhập tay nhé"*.

## 2. Tệp

| Tệp | Vai |
|---|---|
| `transaction/domain/doc_hoa_don.dart` | Luật hoá đơn giấy (tổng, cửa hàng, ngày, **giờ**) — nâng từ spike C4; spike giữ bí danh qua `export` |
| `transaction/domain/doc_mon_hang.dart` | `MonHang`, `docMonHang` — danh sách món |
| `transaction/domain/doc_anh_quet.dart` | `loaiAnhQuet`, `docAnhQuet`, `KetQuaAnhQuet`, `KetQuaAiAnh`, `chuGuiMoHinh`, `lapTuAi` |
| `transaction/data/doc_anh_bang_ai.dart` | `DocAnhBangAi` — chỗ DUY NHẤT ảnh quét gọi mô hình |
| `core/ocr/kho_anh_quet.dart` | `KhoAnhQuet` — ảnh + `<tên>.mon.json` |
| `transaction/domain/dien_san_bien_dong.dart` | khoá `quet:`, `kNguonAnhQuet`, `DienSanBienDong.laQuet/ai`, `deeplinkQuet` |
| `transaction/presentation/pages/quet_anh_page.dart` | `moQuet`, `QuetAnhPage` — tệp DUY NHẤT import `image_picker` |
| `transaction/domain/tach_giao_dich.dart` | `PhanTach`, `conLai`, `kiemTach`, `gopKhiDoiDanhMucChinh`, `dungGiaoDichTach` |
| `TransactionRepository.addTransactions` · `TransactionLocalDataSource.addTransactions` · `AddTransactionsEvent` | Lưu N giao dịch trong một giao tác, một `actionSuccess` |

## 3. Chốt hỏng im lặng

1. **Khoá `quet:` KHÔNG đi đường nguồn → ví của D1** — ảnh quét không gắn ngân hàng; giữ ví mặc định. Chép nhầm đường
   D1 là ví trống ở mọi lần quét. Gợi ý chuyển khoản và nhắc trùng của D1 cũng bỏ (spec 5.6).
2. **Ảnh xoá trong `dispose()` của form** — một chỗ cho mọi đường thoát (Lưu, Bỏ qua, ←, Back hệ thống); `_dongBienDong`
   với khoá `quet:` chỉ xoá ảnh, **không** gọi `xoaBienDong` (không có hàng loại 20).
3. **`anh_quet/` tách khỏi `bien_lai/`** — `KhoBienLai.donMoCoi` xoá ảnh không có hàng loại 20 ở mỗi lượt nhập.
4. **AI chỉ lấp ô trong `oThieu`**, mỗi ô một chốt: số tiền phải là số tiền có trên ảnh (`tienTrenDong`), ngày phải in
   trên ảnh và không ở tương lai, nội dung là chuỗi con của chữ. Không tham số danh mục.
5. **Nhãn dừng đọc món ≠ nhãn tổng**: bỏ `thanh tien · so tien · thanh toan` (tiêu đề cột), thêm `tam tinh · subtotal`,
   so theo **từ trọn** — chuỗi con là món *"BANH TONGHOP"* cắt cụt danh sách.
6. **Dòng món đòi số cuối có ngăn nghìn** — loại ngày / giờ / năm (`2026` ≥ 1.000 mà `tienTrenDong` vẫn nhận).
7. **`TransactionDao.insert` là `insertOrReplace`** — trùng id KHÔNG làm hỏng giao tác; test "ghi hết hoặc không" dùng
   khoá ngoại ví (`PRAGMA foreign_keys = ON`).
8. Test quét `lib/` thứ **20**: `chi_mot_noi_import_image_picker_test.dart`.

## 3b. Tách theo danh mục (mục 11 spec)

Form Thêm giao dịch, **tạo mới + Chi** (gõ tay, ảnh quét, biến động, biên lai đều có): dòng *"Tách theo danh mục"*
dưới ô Danh mục → sheet *Thêm phần* (`sheet_them_phan.dart`: danh mục chi khác danh mục chính, rồi tick món nếu form
từ ảnh quét loại hoá đơn, không thì nhập số) → khối *TÁCH THEO DANH MỤC* (`khoi_tach.dart`). Ô số tiền trên cùng vẫn là
**tổng**; danh mục chính (*"Danh mục chính"*) nhận phần còn lại.

Chốt:
1. **Ghi hết hoặc không gì** — `addTransactions` một giao tác Drift; neo số dư đặt một lần TRƯỚC khi ghi sổ.
2. **Một `actionSuccess`** — `AddTransactionsEvent`; hai lượt là form pop hai lần. Toast *"Đã lưu N giao dịch"*
   (`_soGiaoDichVuaLuu`), kèm tên ngân sách khi có ngân sách *Cảnh báo* bị vượt.
3. **Ngân sách từng phần**, ngân sách *Chặn* bị vượt → **một** hộp liệt kê mọi phần, *Huỷ* / *Vẫn ghi* cho cả lô.
4. Đổi danh mục chính sang danh mục đang tách → phần ấy **gộp**; đổi sang Thu / Chuyển → bỏ hết phần; đường lưu chỉ
   tách khi `type == 'chi'` (lưới thứ hai).
5. Món một phần (`kiemTach` → `monHaiPhan`); món của phần khác mờ, không tick được.
6. Phản hồi gợi ý B1 chỉ cho danh mục chính (`_ghiPhanHoiKhiLuu`).
7. Tên danh mục dài **xuống dòng**, không "…" (test bố cục 320 / 360 dp font thật bắt được lúc thi công).
8. Các phần không nối với nhau — không cột, không schema mới; payload đồng bộ không đổi.

Khác Stitch có chủ ý: không nút *"Lưu N giao dịch"* ở đáy (form chỉ lưu bằng ✓) — chân khối nói *"Sẽ lưu N giao
dịch"*, tooltip ✓ nói *"Lưu N giao dịch"*; chip đầu khối nói *"Tổng: …"* thay *"Khớp: …"*.

## 4. Premium

Nút Quét + luật mở cho mọi người. AI lấp ô thiếu chỉ Premium (`_laPremium` ở `QuetAnhPage`, cùng khuôn
`AddTransactionPage`); Basic không thấy chữ "AI" nào ở luồng quét. Tách theo danh mục là luật → mở cho cả Basic.

## 5. Android

Không thêm quyền `CAMERA` (intent máy ảnh hệ thống), không quyền đọc bộ nhớ (trình chọn ảnh hệ thống). Bản `--release`
dựng được ngày 2026-10-08 (224,9 MB) — R8 không cần quy tắc mới cho `image_picker`.

## 6. Stitch

`8027b781…` sheet chọn nguồn · `353934f2…` Đang đọc ảnh · `14d9a417…` form Từ ảnh quét · `01f8cdc6…` khối tách ·
`98133eb8…` sheet chọn món (spec mục 7, 11.7).

## 7. Nghiệm thu máy thật (Realme) — CHƯA LÀM

Bảng điền ở Task 14: (a) biên lai MB từ thư viện · (b) ≥ 5 hoá đơn giấy người dùng chụp — tiền / ngày / ghi chú (chỉ
luật · luật + AI), **món đọc đúng / tổng món**, thời gian chờ, độ dài chữ gửi mô hình (logcat `[Quet][AI]`) · (c) Huỷ hai
pha · (d) ảnh dọc máy ảnh (EXIF) · (e) bản `--release` · (f) Basic · tách 3 phần bằng tick món → số dư, Sổ, PostgreSQL.
