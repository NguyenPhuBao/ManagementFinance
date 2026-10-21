# Quét ảnh hoá đơn / biên lai (A5) — và tách khoản chi theo danh mục

> **Trạng thái (2026-10-08):** **mã xong cả hai phần** — Quét (Task 1–8) và Tách theo danh mục + chọn món
> (Task 10–13) của kế hoạch `docs/superpowers/plans/2026-10-08-a5-quet-va-tach-danh-muc.md` (gitignore).
> 🚧 **Nghiệm thu OnePlus 2026-10-08 lật một phần thiết kế** — spec mục **13**: tick món TẠM TẮT
> (`kChonMonTuAnhQuet = false`), ngày tương lai đảo ngày/tháng, luật sửa theo OCR thật (`367cefbd`). Người dùng chốt
> **AI làm chính (Gemma nhìn ảnh), luật dự phòng**, lệch > 1% → hai chip chọn số — đã thi công tối 2026-10-08 (dòng ✅ dưới).
> Bảng đo 6 hoá đơn ở spec mục 13.
> ✅ **Luật sửa theo 15 hoá đơn thật trên Realme (2026-10-08 chiều)** — chốt 9–12 ở mục 3.
> ✅ **Nghiệm thu OnePlus (GPU) trọn 8 tờ 2026-10-08** — không tờ nào điền sẵn số sai, ba tờ lệch hỏi bằng chip, chạm
> chip đạt; bảng ở spec mục 13.
> ✅ **Nghiệm thu Realme (CPU) 2026-10-21** — mục 7: 1 hoá đơn giấy mới (chụp dọc) điền đúng; 15 tờ cũ qua `/quet` thật: 12
> điền đúng · 1 hỏi chip · ⚠️ **2 điền sẵn SAI không hỏi** (R13 2.127 thay 72.127, R08 75.706 thay 75.700 — **G101**). Huỷ pha
> AI đạt; mô hình giữ qua 15 lượt quét không nạp lại, không sập. Lộ thêm **G100**: Back thoát app rồi mở lại thì mô hình nạp
> thêm một bản (Native Heap 1,89 → 3,72 GB) — đường Back đã sửa cùng ngày (Back hai lần = xuống nền).
> ✅ **AI làm chính đã nối (2026-10-08 tối, mã + test)**: hoá đơn + Premium → Gemma NHÌN
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
| `features/transaction/data/datasources/kho_anh_quet.dart` (dời từ `core/ocr/` 2026-10-16) | `KhoAnhQuet` — ảnh + `<tên>.mon.json` |
| `transaction/domain/dien_san_bien_dong.dart` | khoá `quet:`, `kNguonAnhQuet`, `DienSanBienDong.laQuet/ai`, `deeplinkQuet` |
| `transaction/presentation/pages/quet_anh_page.dart` | `moQuet`, `QuetAnhPage` — tệp DUY NHẤT import `image_picker` |
| `transaction/domain/tach_giao_dich.dart` | `PhanTach`, `conLai`, `kiemTach`, `gopKhiDoiDanhMucChinh`, `dungGiaoDichTach` |
| `TransactionRepository.addTransactions` · `TransactionLocalDataSource.addTransactions` · `AddTransactionsEvent` | Lưu N giao dịch trong một giao tác, một `actionSuccess` |

## 3. Chốt hỏng im lặng

1. **Khoá `quet:` KHÔNG đi đường nguồn → ví của D1** — ảnh quét không gắn ngân hàng; giữ ví mặc định. Chép nhầm đường
   D1 là ví trống ở mọi lần quét. Gợi ý chuyển khoản và nhắc trùng của D1 cũng bỏ (spec 5.6).
2. **Ảnh xoá trong `close()` của `ThemGiaoDichCubit`** (trang gọi `close()` từ `dispose()` của nó) — một chỗ cho mọi
   đường thoát (Lưu, Bỏ qua, ←, Back hệ thống); `_dongBienDong` (cũng ở Cubit) với khoá `quet:` chỉ xoá ảnh, **không**
   gọi `xoaBienDong` (không có hàng loại 20).
2b. **Bản sao `image_picker` trong `cache/` xoá trong `dispose()` của `/quet`** (`xoaTepTamChonAnh`,
   `core/ocr/tep_tam_chon_anh.dart`): `cache/scaled_<tên>` + bản chép `cache/<uuid>/<tên>` — gói không tự dọn
   (nghiệm thu OnePlus 2026-10-08: 45 thư mục, 13 MB). Chỉ xoá tệp nằm thẳng trong thư mục tên `cache`. Bản sao từ
   trước bản sửa vẫn nằm đó cho tới khi quét lại đúng ảnh ấy hoặc hệ điều hành dọn cache.
2c. ⚠️ **`/quet` chỉ `pushReplacement` / `pop` khi chính nó ở TRÊN CÙNG** — cả hai lệnh tác động lên màn trên cùng. Có
   màn khác đè lên trong lúc đọc (nút + bấm nhanh sau trình chọn ảnh, deeplink thông báo) thì form được `push` lên trên
   và `/quet` đặt `_xong`, tự đóng khi người dùng quay về tới nó (`ModalRoute.isCurrentOf` trong
   `didChangeDependencies` — phải gọi TRƯỚC khi xét `_xong`, kẻo lần đầu không đăng ký phụ thuộc). Thiếu chốt này
   (nghiệm thu OnePlus 2026-10-08): form thay mất màn người dùng, `/quet` nằm lại dưới form với Huỷ / Back chết — kẹt ở
   *"Đang đọc bằng AI…"*, phải tắt app.
3. **`anh_quet/` tách khỏi `bien_lai/`** — `KhoBienLai.donMoCoi` xoá ảnh không có hàng loại 20 ở mỗi lượt nhập.
4. **AI chỉ chạm SỐ TIỀN** (ngày, cửa hàng là của luật — người dùng chốt). Số AI không in trên ảnh thì bỏ (4/5 lần
   Gemma CPU sai là loại ấy); chỉ điền sẵn khi khớp số luật, lệch thì hỏi bằng chip (`DienSanBienDong.luaChonTien`,
   khối `khoi-chon-so-tien` dưới dải nguồn, chạm chip đi qua `themPhimSoTien`).
4b. ⚠️ **`docAnh` KHÔNG đóng mô hình sau khi đọc** — OnePlus 13R (Adreno, GPU) 2026-10-08 **sập native** (SIGSEGV
   `gl_release_context` ← `LiteRtDestroyEnvironment`) ở lần ĐÓNG thứ hai trong một tiến trình: quét 1 nạp bản ảnh rồi
   đóng → chọn danh mục nạp bản chữ → quét 2 đóng bản chữ → sập. Nay bản có ảnh được GIỮ, phiên chữ (chọn danh mục,
   Nhập nhanh, Trợ lý) dùng luôn nó; chỉ đóng khi bản đang nạp là bản chữ. Đo lại sau sửa: 3 lần quét liên tiếp không
   sập. `PhienMotLoiGoi.chuanBi` vẫn nạp lại khi `!runtime.dangSan` (sửa cùng ngày — giữ làm lưới).
5. **Nhãn dừng đọc món ≠ nhãn tổng**: bỏ `thanh tien · so tien · thanh toan` (tiêu đề cột), thêm `tam tinh · subtotal`,
   so theo **từ trọn** — chuỗi con là món *"BANH TONGHOP"* cắt cụt danh sách.
6. **Dòng món đòi số cuối có ngăn nghìn** — loại ngày / giờ / năm (`2026` ≥ 1.000 mà `tienTrenDong` vẫn nhận).
7. **`TransactionDao.insert` là `insertOrReplace`** — trùng id KHÔNG làm hỏng giao tác; test "ghi hết hoặc không" dùng
   khoá ngoại ví (`PRAGMA foreign_keys = ON`).
8. Test quét `lib/` thứ **20**: `chi_mot_noi_import_image_picker_test.dart`. Sheet chọn nguồn mở bằng
   `useRootNavigator: true` — trong navigator nhánh thì thanh dưới + nút + đè lên và che nút Huỷ.
9. Nghiệm thu OnePlus 2026-10-08 (BHX nhoè, ảnh Google Photos): OCR đọc *"Tổng tiền"* thành *"Tng tien"* (mất
   nguyên âm), *"Tbng tiễn"* (nguyên âm thành phụ âm) — `kNhanTongDocNham` nhận `t(?!a)[a-z]?ng`, cố ý không *tang*;
   ngày *"3O/08/2026"* — chữ O sát chữ số là 0 khi tìm ngày; không nhãn thì luật lấy mã nhân viên *99.184* — rơi về số lớn
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
   (`_soGiaoDichVuaLuu` của `ThemGiaoDichCubit`), kèm tên ngân sách khi có ngân sách *Cảnh báo* bị vượt.
3. **Ngân sách từng phần**, ngân sách *Chặn* bị vượt → **một** hộp liệt kê mọi phần, *Huỷ* / *Vẫn ghi* cho cả lô.
4. Đổi danh mục chính sang danh mục đang tách → phần ấy **gộp**; đổi sang Thu / Chuyển → bỏ hết phần; đường lưu chỉ
   tách khi `type == 'chi'` (lưới thứ hai).
5. Món một phần (`kiemTach` → `monHaiPhan`); món của phần khác mờ, không tick được.
6. Phản hồi gợi ý B1 chỉ cho danh mục chính (`_ghiPhanHoiKhiLuu` của `ThemGiaoDichCubit`).
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
`98133eb8…` sheet chọn món (spec mục 7, 11.7). Khối hai chip: màn `bd764b70…` *"Thêm giao dịch - Từ ảnh quét - Hai số
khác nhau"* xuất hiện sau lượt gọi `timeout` — ✅ **người dùng xác nhận 2026-10-08**.

## 7. Nghiệm thu máy thật (Realme) — đo 2026-10-21

Bảng điền ở Task 14: (a) biên lai MB từ thư viện · (b) ≥ 5 hoá đơn giấy người dùng chụp — tiền / ngày / ghi chú (chỉ
luật · luật + AI), **món đọc đúng / tổng món**, thời gian chờ, độ dài chữ gửi mô hình (logcat `[Quet][AI]`) · (c) Huỷ hai
pha · (d) ảnh dọc máy ảnh (EXIF) · (e) bản `--release` · (f) Basic · tách 3 phần bằng tick món → số dư, Sổ, PostgreSQL.

**Lượt đo 2026-10-21** — Realme RMX2205, Gemma **CPU** (cờ `slm_gpu_hong`), bản debug `b174b8d6…`, tài khoản Premium (số 10),
app trỏ `10.0.2.2` nên không đồng bộ. Người dùng chốt: **không bấm Lưu** (chấm trên form rồi *Bỏ qua*). Chỉ có **một** hoá đơn
giấy mới. 15 tờ còn lại là R01–R16 của buổi 08/10, lấy từ `app_flutter/spike_c4/do1/` (bản đã thu về rộng 1280), chép tạm
sang `Download/`, chọn qua trình chọn ảnh hệ thống, đã xoá sau buổi đo. ⚠️ `image_picker` **nén lại** các ảnh này (R08 98.970 →
83.192 byte), nên OCR chạy trên ảnh nén hai lần và khác chữ lưu trong `hoa_don_that_du_lieu.dart`. Lượt này là **kiểm hồi quy
đầu-cuối của `/quet`**, không phải phép đo trên ảnh chưa từng thấy (trừ tờ mới).

| Tờ | Đáp án | Luật | Gemma CPU | Form hiện | Gemma · danh mục (s) | Danh mục | Ngày | Ghi chú |
|---|---|---|---|---|---|---|---|---|
| **Mới** ỦA TEA (chụp dọc) | 398.800 | ✅ | ❌ 161.000 (không trên ảnh → bỏ) | điền ✅ | 30,8 · 9,7 | Ăn uống | 14/10 ✅, giờ 00:00 (in *"1407"*) | ỦA TEA |
| R01 Starbucks | 262.000 | ✅ | ✅ | điền ✅ | 35,0 · 8,6 | Ăn uống | 28/09 14:19 ✅ | *STARBUCKS"* ◐ |
| R02 ÙA TEA | 158.000 | ✅ | ✅ | điền ✅ | 37,8 · 7,6 | Ăn uống | 02/10 14:26 ✅ | ỦA TEA |
| R03 ÙA TEA | 217.500 | ✅ | ✅ | điền ✅ | 33,9 · 8,7 | Ăn uống | 02/10 14:33 ✅ | ỦA TEA |
| R04 BHX | 55.500 | ✅ | ✅ | điền ✅ | 19,8 · 7,6 | Ăn uống | lúc quét (đúng luật) | tiêu đề OCR méo ◐ |
| R05 eco-shop | 57.000 | ✅ | ✅ | điền ✅ | 26,5 · 8,1 | Mua sắm | 30/08 ✅ | eco-shop Invoice |
| R06 Pharmacity | 76.872 | ✅ | ✅ | điền ✅ | 20,9 · 8,9 | Y tế | 20/08 16:43 ✅ | NHÀ THUỐc |
| R07 MAXIDI | 44.700 | ✅ | ✅ | điền ✅ | 25,1 · 7,8 | Ăn uống | 21/09 18:55 ✅ | trống (đúng luật) |
| R08 MAXIDI | 75.700 | ❌ 75.706 | ❌ 55.000 | ⚠️ **điền 75.706** (G101) | 20,6 · 7,9 | Ăn uống | 11/09 19:42 ✅ | MAXIDI ORE |
| R10 | 45.000 | ✅ | ✅ | điền ✅ | 18,5 · 7,5 | Ăn uống | 19/09 18:06 ✅ | trống (đúng luật) |
| R11 BHX nhoè | 79.243 | ✅ | ❌ 119.180 (bỏ) | điền ✅ | 28,4 · 8,1 | Mua sắm | lúc quét (đúng luật) | tiêu đề ◐ |
| R12 Dookki | 300.240 | ✅ | ✅ | điền ✅ | 18,8 · 7,8 | Ăn uống | lúc quét (đúng luật) | DOOKKI Topokki Buftet |
| R13 MAXIDI | 72.127 | ❌ 2.127 | ✅ 72.127 (bỏ) | ⚠️ **điền 2.127** (G101) | 31,3 · 7,6 | Mua sắm | lúc quét ❌ (OCR *"912/2025"*) | MAXIDI |
| R14 MAXIDI | 44.745 | ✅ | ✅ | điền ✅ | 27,2 · 8,0 | Ăn uống | 01/10 20:02 ✅ | trống (đúng luật) |
| R15 BHX | 30.000 thực trả | 32.160 (*Tổng tiền*) | ❌ 13.500 | hai chip 13.500 · 32.160 ◐ | 19,5 · 7,9 | Ăn uống | lúc quét (đúng luật) | tiêu đề rác ❌ |
| R16 Bee Bee Mart | 36.000 | ✅ | ✅ | điền ✅ | 18,4 · 7,9 | Ăn uống | 19/09 21:29 ✅ | BEE BEE MART 18K |

Tổng hợp:
- **Tờ mới:** điền đúng 1/1.
- **15 tờ cũ:** 12 điền đúng · 1 hỏi chip · **2 điền sẵn SAI không hỏi** (G101).
- Luật đúng tổng 13/15 (R15 tính *Tổng tiền* 32.160 như quy ước 08/10); Gemma CPU 12/15 cũ, 0/1 tờ mới.
- So với 08/10: R11 nay điền đúng (số Gemma không có trên ảnh nên bị bỏ). R15 lùi: hôm 08/10 Gemma đọc 30.000 nên chip có số thực
  trả, hôm nay chip không có. R08, R13 lùi vì OCR trên ảnh nén lại.
- Ngày: 10 tờ đúng, 4 tờ không in / không đọc nên lấy lúc quét đúng luật, R13 không đọc ra. **0 ngày sai im lặng.**
- Thời gian: OCR + luật < 1 s; nạp mô hình 1,2–1,5 s (cache XNNPACK); Gemma nhìn ảnh **18–38 s**; chọn danh mục 7,5–9,7 s.

Các mục khác:
- **(d) ảnh dọc máy ảnh — đạt** (tờ mới, Quét → Chụp ảnh).
- **(c) Huỷ pha AI — đạt**: form mang kết quả luật, không *"Đọc bằng AI"*, không gọi lượt chọn danh mục. Màn *"Đang đọc bằng
  AI…"* còn đứng ~5 s sau khi bấm, vì lời gọi đọc ảnh native không ngắt được (huỷ 14:23:53, native trả 14:23:58). Huỷ pha
  luật: OCR < 1 s, adb không chạm kịp (widget test canh).
- **Chốt 4b trên CPU — đạt**: 15 lượt quét liên tiếp + chọn danh mục + Nhập nhanh (*"mua quà sinh nhật mẹ 250k"*, mô hình chọn
  danh mục) dùng chung bản có ảnh, không nạp lại, không sập. PSS ổn định 3,0–3,26 GB (swap tăng dần 0,1 → 0,95 GB).
- Dọn ảnh: `anh_quet/` rỗng sau mỗi *Bỏ qua*; `cache/` không còn bản sao `image_picker`.
- ⚠️ **G100**: Back thoát app (tiến trình còn sống nhờ dịch vụ D1) rồi mở lại thì mô hình nạp thêm một bản, Native Heap 1,89 →
  3,72 GB. Đường Back đã sửa cùng ngày (Back hai lần đưa app xuống nền, nghiệm thu OnePlus GPU); gỡ task còn mở.
- Chưa làm: (a) biên lai MB (thư viện Realme không có), (e) bản `--release` (đã đo trên OnePlus), (f) Basic (đã đo trên OnePlus),
  tách bằng tick món (tính năng tạm tắt, `kChonMonTuAnhQuet = false`).

Ứng viên sửa (chưa mở mục G, chưa đo): giờ in không dấu hai chấm *"Giờ vào: 1407"* → 14:07; ghi chú dính ký tự rác của OCR
(*STARBUCKS"*); màn Huỷ pha AI nên đóng ngay thay vì chờ native trả về.
