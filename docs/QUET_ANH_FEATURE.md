# Quét ảnh hoá đơn / biên lai (A5) — và tách khoản chi theo danh mục

> **Trạng thái (2026-10-08):** **mã xong cả hai phần** — Quét (Task 1–8) và Tách theo danh mục + chọn món
> (Task 10–13) của kế hoạch `docs/superpowers/plans/2026-10-08-a5-quet-va-tach-danh-muc.md` (gitignore).
> 🚧 **Nghiệm thu OnePlus 2026-10-08 lật một phần thiết kế** — spec mục **13**: tick món TẠM TẮT
> (`kChonMonTuAnhQuet = false`), ngày tương lai đảo ngày/tháng, luật sửa theo OCR thật (`367cefbd`). Người dùng chốt
> **AI làm chính (Gemma nhìn ảnh), luật dự phòng**, lệch > 1% → hai chip chọn số — **CHƯA THI CÔNG**. Bảng đo 6 hoá đơn ở
> spec mục 13.
> ✅ **Luật sửa theo 15 hoá đơn thật trên Realme (2026-10-08 chiều)** — chốt 9–12 ở mục 3.
> ✅ **AI làm chính đã nối (2026-10-08 tối, mã + test; 🚧 chưa nghiệm thu máy thật)**: hoá đơn + Premium → Gemma NHÌN
> ẢNH đọc món + tổng (`DocAnhBangGemma`), luật đọc phần còn lại; số chốt bằng `chotTongQuet` — khớp → điền, lệch → ô
> trống + hai chip trên form. Đường cũ *"AI đọc chữ OCR"* (`DocAnhBangAi`, `lapTuAi`) **đã bỏ**.
> Spec: `docs/superpowers/specs/2026-10-07-a5-quet-hoa-don-bien-lai-design.md` (mục 1–9 quét, 10 ngoài phạm vi / A5b,
> 11 tách + 11.2b chọn món).

## 1. Luồng

Trang chủ → **Quét** → bottom sheet *Chụp ảnh · Chọn ảnh có sẵn* (`moQuet`) → `image_picker` (máy ảnh / trình chọn ảnh
hệ thống, `maxWidth 1280`) → màn `/quet` *"Đang đọc ảnh…"* (`QuetAnhPage`):

1. Chép ảnh vào `KhoAnhQuet` (`filesDir/anh_quet/`, xoá ảnh cũ trước — mỗi lúc một ảnh).
2. ML Kit qua `DocChuAnh` → `ghepDongTheoHang` → `docAnhQuet` (luật): nhận loại ảnh (`loaiAnhQuet`), đọc
   hoá đơn (`docHoaDonTuChu` + `docMonHang`) hoặc biên lai (`docBienLai`).
3. **Hoá đơn** + **Premium** + mô hình + công tắc AI → *"Đang đọc bằng AI…"*: `DocAnhBangGemma` (Gemma nhìn ảnh,
   câu hỏi `kPromptMonTong` — chỉ món + tổng) → `chotTongQuet(luat, ai, vanBan)`: số AI chỉ dùng khi có in trên ảnh
   hoặc khác số luật đúng một chữ số; khớp ≤ 1% → điền số AI; lệch → ô số tiền trống + query `chon=<AI>,<luật>`.
   Biên lai chỉ luật (Gemma chưa đo biên lai). Gemma CPU (Mali) 21–42 s / ảnh, GPU 4–11 s; trần 90 s.
   Rồi **Gemma lần hai chọn danh mục** (`DocDanhMucBangAi`, người dùng chốt "AI chọn danh mục"): tên cửa hàng + các
   món (của Gemma, không có thì của luật) → tool `chon_danh_muc` với enum danh mục CHI của tài khoản → query `dm=<tên>`
   → `ketQuaTuBienDong` chọn nó, THẮNG từ khoá ghi chú; tên không có / sai chiều → từ khoá như cũ. Huỷ thì không gọi.
4. `pushReplacement('/add?khoa=quet:<ảnh>&…')` (`deeplinkQuet`) — form Thêm giao dịch điền sẵn, dải *"Từ ảnh quét ·
   dd/MM HH:mm"* (+ *"· Đọc bằng AI"*). Không ghi gì cho tới khi người dùng bấm Lưu.

Huỷ ở pha luật → về Trang chủ, xoá ảnh. Huỷ ở pha AI → dừng lượt sinh, mở form với kết quả luật. Back = Huỷ.
Không đọc ra chữ / số tiền → form vẫn mở + toast *"Chưa đọc được ảnh / số tiền — nhập tay nhé"*.

## 2. Tệp

| Tệp | Vai |
|---|---|
| `transaction/domain/doc_hoa_don.dart` | Luật hoá đơn giấy (tổng, cửa hàng, ngày, **giờ**) — nâng từ spike C4; spike giữ bí danh qua `export` |
| `transaction/domain/doc_mon_hang.dart` | `MonHang`, `docMonHang` — danh sách món |
| `transaction/domain/chot_tong_quet.dart` | `chotTongQuet` — số AI chỉ dùng khi có trên ảnh (hoặc khác số luật đúng một chữ số); khớp luật ≤ 1% → điền, lệch → hai chip |
| `transaction/domain/doc_anh_quet.dart` | `loaiAnhQuet`, `docAnhQuet`, `KetQuaAnhQuet` (`voiSoTien` đặt số đã chốt, kể cả `null`) |
| `transaction/domain/doc_anh_gemma.dart` | `kPromptMonTong` (câu hỏi ĐÃ ĐO — đổi là đo lại), `docJsonGemmaAnh` (số `"75,700"` và `39,000` không ngoặc) |
| `transaction/data/doc_danh_muc_bang_ai.dart` | `DocDanhMucBangAi` — Gemma lần hai (chữ) chọn MỘT danh mục chi; tên soát lại với danh sách |
| `transaction/data/doc_anh_bang_gemma.dart` | `DocAnhBangGemma` — chỗ DUY NHẤT ảnh quét gọi mô hình; đi qua `SlmDocAnh` (`slm_runtime.dart`: nạp lại bản có ảnh, ĐÓNG sau khi đọc) |
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
4. **AI chỉ chạm SỐ TIỀN** (ngày, cửa hàng là của luật — người dùng chốt). Số AI không in trên ảnh thì bỏ (4/5 lần
   Gemma CPU sai là loại ấy); chỉ điền sẵn khi khớp số luật, lệch thì hỏi bằng chip (`DienSanBienDong.luaChonTien`,
   khối `khoi-chon-so-tien` dưới dải nguồn, chạm chip đi qua `themPhimSoTien`).
4b. **`docAnh` đóng mô hình sau khi đọc** → `PhienMotLoiGoi.chuanBi` (Nhập nhanh, lệnh tạo) phải nạp lại khi
   `!runtime.dangSan` — trước đây nó nhớ "đã nạp" mãi và Nhập nhanh âm thầm thôi dùng AI sau một lần quét.
5. **Nhãn dừng đọc món ≠ nhãn tổng**: bỏ `thanh tien · so tien · thanh toan` (tiêu đề cột), thêm `tam tinh · subtotal`,
   so theo **từ trọn** — chuỗi con là món *"BANH TONGHOP"* cắt cụt danh sách.
6. **Dòng món đòi số cuối có ngăn nghìn** — loại ngày / giờ / năm (`2026` ≥ 1.000 mà `tienTrenDong` vẫn nhận).
7. **`TransactionDao.insert` là `insertOrReplace`** — trùng id KHÔNG làm hỏng giao tác; test "ghi hết hoặc không" dùng
   khoá ngoại ví (`PRAGMA foreign_keys = ON`).
8. Test quét `lib/` thứ **20**: `chi_mot_noi_import_image_picker_test.dart`. Sheet chọn nguồn mở bằng
   `useRootNavigator: true` — trong navigator nhánh thì thanh dưới + nút + đè lên và che nút Huỷ.
9. Nghiệm thu OnePlus 2026-10-08 (BHX nhoè, ảnh Google Photos): OCR đọc *"Tổng tiền"* thành *"Tng tien"* (mất
   nguyên âm — `kNhanTongDocNham` nhận `t[eouy]?ng`), không nhãn thì luật lấy mã nhân viên *99.184* — rơi về số lớn
   nhất nay ưu tiên số có NGĂN NGHÌN; tiêu đề *"Phiếu thanh toán"* là nhãn loại. Cùng tờ ấy OCR trên Realme khác hẳn.
9a. **Tìm số tổng trên dòng đã bỏ ngày / giờ** (`_dongTien`) — *"20/08/2026 16:43 Thành Tiền"* từng cho tổng **2026**.
   Nhãn không có số thì dòng TRÊN chỉ-có-số thắng dòng dưới (BHX / MAXIDI in số cao hơn nhãn). Chữ *"tổng"* OCR đọc
   méo (*Téng, Töng*) được thay bằng *tong* TRƯỚC khi xếp hạng nhãn (`hangNhanTong`), nên *"Téng tiên"* thắng
   *"Thành tiền"* trước chiết khấu. *"Payment"* đứng trên *"Total"* (thực trả đã VAT) — nên dòng phương thức trả / tiền khách đưa / tiền thối
   (`method · phuong thuc · cash · change`) phải nằm trong `kNhanLoaiHoaDon`, kẻo *"Payment Method: Cash"* rồi *"Cash
   150,000"* thành tổng.
10. **Ngày in thiếu số 0 (`ngayDuHaiSo = false`) thì chọn cách đọc gần lúc quét nhất** — máy POS MAXIDI in tháng/ngày
    (*9/2/2026* = 02/09); ngày in đủ hai chữ số vẫn đọc ngày/tháng trước (*05/03* không thành *03/05*).
11. **Dòng dấu ảnh *"Shot on …"* bị bỏ khi tìm ngày giờ** — giờ trên đó là giờ chụp. Đọc thêm *"Sep 28, 2026 2:19PM"* và
    *"Ngày 19 tháng 09 năm 2026"*.
12. **Tên cửa hàng chỉ tìm TRƯỚC thân hoá đơn**, bỏ chữ trên đồ vật phía sau (*ASUS, CORE, IRIS*), mẩu một từ ≤ 4 chữ
    cái (*"tel"*), địa chỉ / liên hệ, tiêu đề chứng từ; không thấy → **trống** (không đoán bằng dòng địa chỉ chợ).
    Dữ liệu test: `test/features/transaction/domain/hoa_don_that_du_lieu.dart` (chữ OCR thật, đã che số điện thoại).
    ⚠️ Luật sửa trên **chính** 15 tờ này — cần hoá đơn mới để biết nó có chỉ khớp riêng bộ này không. Chỗ dễ vỡ nhất:
    *"dòng trên chỉ-có-số thắng"* (đo đúng 5 ca) — một dòng món đứng ngay trước nhãn tổng sẽ bị bốc nhầm.
    Đo lại trên Realme bằng nút *Lô* mã `luat:do1` (bản spike, chỉ luật): khớp đúng dữ liệu test.

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
