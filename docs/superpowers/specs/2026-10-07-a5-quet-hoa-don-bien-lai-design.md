# A5 — Nút "Quét": chụp / chọn ảnh hoá đơn hoặc biên lai → form Thêm giao dịch điền sẵn

**Ngày:** 2026-10-07 · **Trạng thái:** bản viết **duyệt 2026-10-08**; cùng ngày thêm **mục 11 — tách theo danh mục**
(thiết kế duyệt trong chat, ba phần + 11.2b chọn món), người dùng duyệt kế hoạch và **thi công trọn mã 2026-10-08**
(`a0e068b`, chờ nghiệm thu Realme — chỗ bản thi công khác bản viết: mục 12) · **Mục UX:** A5
(`docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`) · **Stitch:** ba màn mục 7 **đã có** và người dùng
**xác nhận** 2026-10-08; màn của mục 11 ở 11.7.

## 1. Bối cảnh

Nút **Quét** ở Trang chủ (`home_page.dart`, hàng bốn nút *Thêm thu · Thêm chi · Chuyển · Quét*) hôm nay chỉ hiện toast
*"Tính năng Quét QR đang phát triển"* — nút chết từ lượt đánh giá UX 2026-09-19. Người dùng chọn (2026-10-07) làm nó
thành tính năng thật thay vì gỡ.

**Quan hệ với C4** (lộ trình AI: *giọng nói + chụp hoá đơn*): A5 là **nửa OCR** của C4 theo lối A (ML Kit + luật) có AI
lấp ô thiếu; bước nghiệm thu ≥ 5 hoá đơn thật (mục 9) thay phần đo ảnh của spike C4. **Nửa giọng nói** làm **ngay sau A5**
bằng spec riêng (người dùng chốt 2026-10-07): đo bộ 20 câu nói thật trên Realme, kiểm `speech_to_text` có chạy offline,
chọn lối bằng số đo.

Các khâu đã có sẵn và được dùng lại:

| Khâu | Ở đâu | Tình trạng |
|---|---|---|
| Đọc chữ trên ảnh (ML Kit) + ghép dòng theo HÀNG | `core/ocr/doc_chu_anh.dart` (giao diện), `doc_chu_anh_mlkit.dart` (bản thật), `dong_ocr.dart` (`ghepDongTheoHang`) | Chạy thật từ chia sẻ biên lai (2026-10-02), bản release đã đo |
| Đọc **biên lai chuyển khoản** (ảnh chụp màn hình app ngân hàng / ví) | `transaction/domain/doc_bien_lai.dart` (`docBienLai`) | Mẫu riêng MB Bank đo trên ảnh thật; luật chung cho nguồn khác |
| Đọc **hoá đơn giấy** (tổng tiền, cửa hàng, ngày) | `ai_chat/spike/spike_c4.dart` (`docHoaDonTuChu`) | Mã spike, **chưa có bảng đo** (15 ảnh hoá đơn của spike C4 chưa chụp) |
| Form điền sẵn có ảnh thu nhỏ | `add_transaction_page.dart` chế độ `DienSanBienDong` (D1 / biên lai, Stitch `805cd430…`) | Chạy thật |
| Phiên AI một tool + lưới kiểm | `ai_edge/data/phien_mot_loi_goi.dart` (`PhienMotLoiGoi`), khuôn C2 `transaction/data/doc_cau_bang_ai.dart` | Chạy thật |

## 2. Quyết định người dùng (2026-10-07, AskUserQuestion)

1. **Đọc cả hai loại ảnh**, app tự nhận — biên lai chuyển khoản và hoá đơn giấy.
2. **Đọc xong mở thẳng form điền sẵn** (không qua hàng chờ ghi / thông báo).
3. **Luật trước, AI lấp chỗ trống** — cùng khuôn C2. AI đọc **chữ OCR**, không đọc ảnh. Basic hoặc máy chưa có mô hình
   → chỉ phần luật.
4. **Lối A — đường riêng** cho ảnh quét (không đi qua `NhapBienLai`).
5. Luồng màn: bảng chọn nguồn ảnh → màn *"Đang đọc ảnh…"* (có Huỷ) → form → Lưu (giữ bảng chọn, không mở thẳng máy ảnh).
6. **`image_picker` thành gói chính thức** (đang là gói spike C4) — người dùng duyệt đích danh.

## 3. Luồng người dùng

1. Trang chủ → chạm **Quét** → bottom sheet hai dòng: **Chụp ảnh** · **Chọn ảnh có sẵn**. Đóng sheet = không gì xảy ra.
2. Chụp / chọn xong → màn `/quet` (navigator gốc): ảnh mờ làm nền, vòng xoay, chữ *"Đang đọc ảnh…"*, nút **Huỷ**.
   - Phần luật (ML Kit + luật) mất ~1–2 s.
   - Còn ô thiếu và AI được dùng (mục 5.4) → chữ đổi *"Đang đọc bằng AI…"* (~12–17 s trên Realme CPU).
   - **Huỷ** ở pha luật → về Trang chủ, xoá ảnh. **Huỷ** ở pha AI → dừng lượt sinh, mở form với kết quả luật.
3. Màn `/quet` **thay chính nó** bằng form `/add` (không để `/quet` trong ngăn xếp — Back từ form về Trang chủ):
   số tiền · chiều · ngày giờ · ghi chú điền sẵn, ảnh thu nhỏ (chạm để xem to), dải nguồn *"Từ ảnh quét · 30/09 16:30"*.
   Ô nào do AI lấp thì dải nguồn thêm *"Đọc bằng AI"* (như C2). Danh mục: chuỗi gợi ý sẵn có của form (B1 → từ khoá) trên
   ghi chú — **không** do AI quét điền (mục 5.4).
4. Người dùng bấm **Lưu** (đường lưu thường) hoặc thoát / **Bỏ qua** → ảnh bị xoá. Không ghi gì khi chưa bấm Lưu
   (bất biến ④ *"không tool nào ghi thẳng"*).
5. Không đọc ra số tiền → form vẫn mở, ô số tiền trống, toast *"Chưa đọc được số tiền — nhập tay nhé"*. Ảnh không có chữ
   / ML Kit lỗi → như vậy, toast *"Chưa đọc được ảnh — nhập tay nhé"*.

## 4. Nhận loại ảnh

Hàm thuần `loaiAnhQuet(List<String> hang)` trên chữ đã bỏ dấu, viết thường (cùng `_bo` của `doc_bien_lai.dart`):

- **Điểm biên lai** = số hàng khớp một trong: `thanh cong` · `nguoi nhan` · `tai khoan nhan` · `ma giao dich` / `ma gd` ·
  `noi dung` · `chuyen khoan` / `chuyen tien` · hàng **mở đầu** bằng `nhan tien` / `nhan chuyen khoan`.
- **Điểm hoá đơn** = số hàng khớp một trong: `don gia` · `so luong` / `sl` · `thanh tien` · `khach dua` · `tien thoi` /
  `tien thua` · `tong cong` · `tam tinh` · `vat` · `hoa don`.
- Hoá đơn thắng khi điểm hoá đơn **lớn hơn** điểm biên lai; còn lại (kể cả hoà, kể cả 0–0) → **biên lai** — luật biên lai
  là luật đã đo trên ảnh thật, và luật chung của nó đã có đường "số có đơn vị lớn nhất" cho ảnh lạ.

⚠️ Máy POS in *"GIAO DỊCH THÀNH CÔNG"* trên hoá đơn quẹt thẻ — một điểm biên lai, nhưng hoá đơn có nhiều nhãn hơn nên vẫn
thắng. Ca test bắt buộc có hoá đơn mang chữ *"thành công"*.

## 5. Thành phần

### 5.1 `transaction/domain/doc_hoa_don.dart` (mới) — nâng từ spike

Chuyển `docHoaDonTuChu`, `KetQuaHoaDon`, `_nhanTong`, `_nhanLoai`, `_ngay` từ `ai_chat/spike/spike_c4.dart` sang đây
(tên công khai giữ nguyên). `spike_c4.dart` **giữ** `docHoaDonTuChu` làm bí danh gọi lại hàm mới (khuôn `docSoHoaDon`), để
`spike_c4_test` và màn đo spike không đổi. Phần còn lại của spike (prompt lối B, `docHoaDonTuJson`, `kSpikeC4`) ở nguyên.
Thêm: **giờ** in trên hoá đơn (`HH:mm`) đi cùng ngày nếu có.

### 5.2 `transaction/domain/doc_anh_quet.dart` (mới, hàm thuần)

`KetQuaAnhQuet docAnhQuet({required String vanBan, required DateTime luc})`:

- `vanBan` là đầu ra `ghepDongTheoHang`; `luc` là lúc quét (mặc định ngày giờ khi ảnh không in ngày).
- Loại theo mục 4. Biên lai → `docBienLai(vanBan:, nguon: null, luc:)`. Hoá đơn → `docHoaDonTuChu` → chiều `chi`, ghi chú
  = tên cửa hàng (rỗng nếu không đọc ra).
- Trả `{loai, soTien?, chieu, thoiGian, ghiChu, oThieu}` — `oThieu ⊆ {soTien, thoiGian, ghiChu}`: ô luật không đọc ra
  (`thoiGian` thiếu khi ảnh không in ngày — đang mang `luc`).
- Đặt ở `transaction/` (không ở `ai_edge/`) vì trả chiều `'thu'`/`'chi'` — test quét 14 cấm so chiều trong `ai_edge/`.

### 5.3 `core/ocr/` — không đổi

Màn `/quet` đi qua giao diện `doc_chu_anh.dart` (`DocChuAnh`). **Không** import `google_mlkit_text_recognition`: test quét
thứ 17 chỉ cho `doc_chu_anh_mlkit.dart` và màn spike.

### 5.4 `transaction/data/doc_anh_bang_ai.dart` (mới) — AI lấp ô thiếu

- Chỉ chạy khi: `oThieu` khác rỗng **và** tài khoản Premium (`context.read<GoiCubit>()`, không `BlocProvider.of`) **và**
  mô hình có trên máy + công tắc AI bật (cùng điều kiện ô Nhập nhanh).
- Phiên **một tool** `dien_anh_quet` qua `PhienMotLoiGoi`, ba tham số: `cach_doc_so_tien` (AI **chọn** một số đã có trong
  chữ — khuôn `cachDocSoTien` của C2, không tự viết chữ số), `ngay` (dd/MM/yyyy), `noi_dung` (tên cửa hàng / nội dung,
  chỉ được bớt chữ của `vanBan`). **Không** có tham số danh mục — form tự gợi ý trên ghi chú (YAGNI).
- **Lưới kiểm** (luật thắng mọi ô đã điền; AI chỉ lấp ô trong `oThieu`):
  - số tiền AI chọn phải xuất hiện trong `vanBan` (`vanBan` chứa chuỗi số ấy sau chuẩn hoá ngăn nghìn) và qua trần
    `kSoChuSoToiDaSoTien`;
  - ngày phải xuất hiện trong `vanBan` và không ở tương lai;
  - nội dung phải là chuỗi con (sau chuẩn hoá) của `vanBan`.
- **Cắt chữ gửi mô hình** (bẫy 4.51 — prompt dài làm hỏng chuỗi số; `maxTokens` 4096): chỉ gửi hàng có chữ số hoặc nhãn
  của `_nhanTong` / `_nhanLoai` / tên cửa hàng (3 hàng đầu), trần **1.200 ký tự**. Độ dài prompt đo được ghi vào nghiệm thu.
- Đặt ở `transaction/data/` (cùng lý do test quét 14, cùng chỗ `doc_cau_bang_ai.dart`).

### 5.5 Kho ảnh quét — `core/ocr/kho_anh_quet.dart` (mới)

- Thư mục riêng `filesDir/anh_quet/` — **tách khỏi** `bien_lai/`: `KhoBienLai.donMoCoi` chạy ở mỗi lượt nhập (app
  resume) và xoá ảnh không có hàng loại 20 trỏ tới; ảnh quét không có hàng nào, dùng chung thư mục là người dùng chuyển
  app giữa chừng thì ảnh trên form biến mất.
- Mỗi lúc **một** ảnh. Xoá khi: Lưu, Bỏ qua / thoát form, bắt đầu lần quét kế, đăng xuất (`AuthBloc` cùng chỗ
  `KhoBienLai.xoaHet`). Tên tệp đi qua `tenTepBienLaiHopLe` (tên vào query của `/add`).
- Không hàm nào ném (khuôn `KhoBienLai`).

### 5.6 Form `/add` — mở rộng chế độ điền sẵn

- `dien_san_bien_dong.dart`: thêm `kTienToKhoaQuet = 'quet:'` và `kNguonAnhQuet = 'Ảnh quét'`; `dienSanBienDongTuQuery`
  nhận khoá `quet:` (hôm nay chỉ nhận `bienDong:`) và tham số `ai=1` (ô nào đó do AI lấp). `dongNguonBienDong` thêm
  nhánh *"Từ ảnh quét · dd/MM HH:mm"* (+ *" · Đọc bằng AI"*).
- `add_transaction_page.dart`: khoá `quet:` → ảnh tìm qua **kho ảnh quét** (không qua `KhoBienLai`); Lưu / Bỏ qua
  **bỏ bước** `_xoaHangBienDong` (không có hàng loại 20) và xoá ảnh trong kho ảnh quét. Thoát bằng Back cũng xoá ảnh.
  Dải gợi ý chuyển khoản / nhắc trùng của D1 không áp cho khoá `quet:`.

### 5.7 Màn `/quet` — `transaction/presentation/pages/quet_anh_page.dart` (mới)

- Route gốc (ngoài shell — từ Trang chủ phải `push`, đúng luật điều hướng nhóm D).
- Nhận ảnh từ `image_picker` (`maxWidth: 1280`, như spike); **tệp duy nhất** import `image_picker` ngoài màn spike —
  test quét `lib/` thứ **20**.
- Chép ảnh vào kho ảnh quét → `DocChuAnh` → `ghepDongTheoHang` → `docAnhQuet` → (AI nếu được) → `pushReplacement('/add?…')`.
- Nút Quét ở Trang chủ: giữ nhánh `kSpikeC4` (bản spike mở màn đo); bản thường mở bottom sheet chọn nguồn.

### 5.8 Android

- **Không** thêm quyền `CAMERA` vào manifest: `image_picker` dùng intent máy ảnh hệ thống; khai quyền này là bắt buộc
  xin quyền lúc chạy mà luồng không xử lý.
- Thư viện ảnh dùng trình chọn ảnh hệ thống — không cần quyền đọc bộ nhớ.
- Ảnh máy ảnh mang **EXIF xoay**; ảnh chụp màn hình không bao giờ có — nghiệm thu bắt buộc một ảnh chụp dọc bằng máy ảnh.
- `image_picker` có mã Android gốc → dựng thử `--release` ngay sau khi thêm (bản release từng gãy ở R8 vì ML Kit,
  `proguard-rules.pro`).

### 5.9 Premium

AI của ảnh quét là đặc quyền Premium (cùng nhóm *Trợ lý AI & Nhập nhanh*); phần luật mở cho cả Basic. Cập nhật
`docs/PREMIUM_FEATURE.md` và mục đặc quyền của spec `2026-10-06-premium-payos-client-design.md` một dòng. Màn Basic
không hiện chữ "AI" ở luồng quét.

## 6. Lỗi và biên

| Ca | Hành vi |
|---|---|
| Huỷ máy ảnh / không chọn ảnh | Về Trang chủ, không gì |
| ML Kit lỗi / ảnh không chữ | Form mở với ảnh, ô trống, toast *"Chưa đọc được ảnh — nhập tay nhé"* |
| Không đọc ra số tiền | Form mở, ô số tiền trống, toast *"Chưa đọc được số tiền — nhập tay nhé"* |
| AI lỗi / hết giờ / Huỷ / lưới kiểm loại | Giữ kết quả luật, mở form, không dòng *"Đọc bằng AI"* |
| Nhận nhầm loại | Chiều mặc định `chi`; người dùng sửa trên form |
| App bị giết giữa chừng | Ảnh mồ côi trong `anh_quet/` bị xoá ở lần quét kế / đăng xuất |
| Offline | Chạy trọn (ML Kit và Gemma trên máy) |

## 7. Stitch (vẽ sau khi spec duyệt, chờ người dùng xác nhận)

1. Trang chủ — bottom sheet *"Quét"* hai dòng (Chụp ảnh · Chọn ảnh có sẵn) — `8027b781b73444cd99c370b35e150be2`
   (Stitch tự thêm nút *Huỷ* đáy sheet).
2. Màn *"Đang đọc ảnh…"* (ảnh mờ nền, vòng xoay, nút Huỷ; biến thể *"Đang đọc bằng AI…"*) —
   `353934f28e754647b41823a69311930e` (dạng bảng trình bày `DESKTOP`, hai biến thể, có ✕ góc).
3. Form Thêm giao dịch mở từ ảnh quét (dải *"Từ ảnh quét · …"*, ảnh thu nhỏ) — chỉnh từ `805cd430…` —
   `14d9a41758bf4d24bf02519fa04bf357` (khổ 1280 như `805cd430…`; Stitch sinh kèm ảnh minh hoạ hoá đơn `ae61d07d…`).

Cả ba lượt gọi trả `timeout` ngày 2026-10-07; màn thứ ba chỉ thấy ở lượt kiểm 2026-10-08. Người dùng xác nhận cả ba 2026-10-08.

## 8. Kiểm thử

Test viết trước, mỗi chốt kiểm bằng bản sai có chủ ý:

- `doc_hoa_don_test` — chép ca của `spike_c4_test` phần hoá đơn + chữ OCR của hoá đơn thật (mục 9).
- `doc_anh_quet_test` — phân loại (biên lai MB từ fixture có sẵn của `doc_bien_lai_test`; hoá đơn; hoá đơn có *"thành
  công"*; hoà điểm → biên lai), `oThieu`.
- `doc_anh_bang_ai_test` — phiên giả: số không có trong chữ bị loại; ngày tương lai bị loại; nội dung không là chuỗi con
  bị loại; ô luật đã điền không bị ghi đè; cắt chữ ≤ 1.200 ký tự.
- `kho_anh_quet_test` — một ảnh; xoá khi quét kế / Lưu / bỏ / đăng xuất; tên tệp hỏng không ghép đường dẫn.
- `dien_san_bien_dong_test` — khoá `quet:`, `ai=1`, dải nguồn.
- Widget: luồng `/quet` với picker giả + `DocChuAnh` giả → form điền sẵn; Huỷ hai pha; Basic không gọi AI; form khoá
  `quet:` không gọi `xoaCung`.
- Test quét `lib/` thứ 20 — `image_picker` chỉ một nơi (ngoài màn spike), có vế tiền đề như test quét 17.

## 9. Nghiệm thu máy thật (Realme)

- (a) Biên lai MB Bank chọn từ thư viện → form đúng số tiền / chiều / ngày giờ.
- (b) **≥ 5 hoá đơn giấy thật** người dùng chụp → bảng: số tiền · ngày · ghi chú đúng/sai, cột *chỉ luật* và *luật + AI*,
  thời gian chờ, độ dài prompt.
- (c) Huỷ ở pha luật và pha AI.
- (d) Chụp bằng máy ảnh hệ thống, **ảnh dọc (EXIF xoay)**.
- (e) Bản `--release`: Quét → chụp → form.
- (f) Basic: chỉ luật, không chữ "AI".
- Không đặt ngưỡng chặn — kết quả chỉ là điền sẵn; bảng đo chỉ hướng cải thiện.

## 10. Ngoài phạm vi

QR / VietQR; quét nhiều ảnh một lần (hàng chờ ghi); AI đọc thẳng ảnh (lối B của spike C4 — 24,5 s, RAM 2,9 GB); gỡ màn
đo spike C4; **giọng nói** (spec riêng ngay sau A5 — mục 1).

**Gợi ý danh mục từng món → A5b**, làm **sau** bảng đo ≥ 5 hoá đơn thật của mục 9 (người dùng chốt 2026-10-08: *"tay
trước, tự động sau"*). **Đọc danh sách món thì nằm TRONG A5** (mục 11.2b — người dùng chọn *chạm từng món để gán*); A5b
chỉ thêm việc đoán sẵn danh mục cho từng món (từ khoá / B1 / AI) rồi **điền sẵn khối tách của mục 11** — không dựng
giao diện thứ hai. Lý do hoãn: chưa có ảnh hoá đơn thật nào; tên món trên hoá đơn nhiệt viết tắt, không dấu (*"SUA
TUOI VNM 180ML"*) nên chưa biết từ khoá / B1 đoán được bao nhiêu. Đối chiếu thị trường
(2026-10-08): gắn danh mục **từng món tự động** hiếm — phần lớn app một danh mục cho cả hoá đơn hoặc để người dùng tự
tách (Veryfi: nút Split, gán tay từng dòng; EasyExpense: yêu cầu tính năng còn "In Review"); không xác nhận được Money
Lover / Sổ Thu Chi MISA có tách.

## 11. Tách theo danh mục (thêm 2026-10-08)

Người dùng hỏi: hoá đơn siêu thị nhiều món thuộc nhiều danh mục thì tách thành nhiều giao dịch thế nào. Chốt
(AskUserQuestion, 2026-10-08): **tách tay trước** (mục này), app đoán danh mục từng món sau (A5b, mục 10). Cùng ngày
người dùng hỏi *"làm sao để chọn các món hàng cho từng danh mục"* và chọn **chạm từng món để gán** (mục 11.2b): app đọc
danh sách món từ ảnh hoá đơn, người dùng tự gán — không đoán.

### 11.1 Quyết định người dùng

1. **Mọi khoản chi mới** — dòng tách có trên form Thêm giao dịch khi **tạo mới** và chiều **Chi**, bất kể form mở từ
   đâu (gõ tay, ảnh quét, biến động số dư, biên lai). **Không** khi sửa giao dịch cũ, Thu, Chuyển ví.
2. **Phần chính tự nhận phần còn lại** — ô số tiền trên cùng vẫn là **tổng**; danh mục đang chọn trên form nhận
   `tổng − Σ các phần`; chặn Lưu khi phần ấy ≤ 0.
3. Không trùng danh mục giữa các phần (kể cả với danh mục chính).
4. Các phần **không nối với nhau** — không cột mới, không schema mới.
5. Ảnh quét loại hoá đơn → **chạm từng món để gán** (mục 11.2b); app **không** đoán danh mục món (việc của A5b).

### 11.2 Giao diện và luồng

- Dòng *"Tách theo danh mục"* ngay dưới ô Danh mục (điều kiện mục 11.1 ý 1).
- Chạm → bottom sheet *"Thêm phần"*: bảng chọn danh mục chi (loại danh mục đã có trong khối tách, kể cả danh mục chính)
  + ô số tiền bàn phím số hệ thống, `GioiHanSoChuSo(kSoChuSoToiDaSoTien)` (test quét `lib/` thứ tám canh).
- Có ≥ 1 phần → **khối tách** trên form: dòng đầu là danh mục chính + số *còn lại* (tự tính, không sửa tay); mỗi phần
  một dòng — chạm để sửa (mở lại sheet), ✕ để bỏ; *"+ Thêm phần"* cuối khối. Bỏ hết phần → form như cũ.
- Đổi **tổng** (bàn phím 16 phím, Nhập nhanh, điền sẵn từ ảnh) → còn lại tính lại. Đổi **danh mục chính** → còn lại đi
  theo danh mục mới; nếu danh mục mới trùng một phần đang tách → phần ấy **gộp** vào phần chính (bỏ dòng ấy).
- Nút Lưu (✓ thanh tiêu đề và nút đáy nếu đang hiện) mang nhãn *"Lưu N giao dịch"* khi có phần. Phần chính ≤ 0 →
  toast lỗi *"Phần còn lại phải lớn hơn 0"*, không lưu.
- Ví, ngày giờ, ghi chú **dùng chung** cho mọi phần.
- Lưu xong: **một** toast *"Đã lưu N giao dịch"*, form đóng **một** lần; ảnh quét / hàng loại 20 / ảnh biên lai dọn
  **một** lần như đường lưu một giao dịch.
- A5b (sau) điền sẵn chính khối này.

### 11.2b Chọn món (form mở từ ảnh quét loại **hoá đơn**)

**Đọc danh sách món** — hàm thuần `transaction/domain/doc_mon_hang.dart` (mới), `List<MonHang> docMonHang(List<String>
hang)` trên đầu ra `ghepDongTheoHang`; `MonHang { id, ten, soTien }` (`id` = chỉ số dòng, ổn định trong một ảnh):

- **Dòng món** = dòng có chữ cái và **kết thúc** bằng một số tiền có ngăn nghìn, giá trị tuyệt đối ≥ 1.000.
- **Món hai dòng**: dòng chỉ có chữ (tên) đứng ngay trên dòng chỉ có số (*SL × đơn giá = thành tiền*) → **một** món,
  tên của dòng trên, tiền = **số cuối** dòng dưới.
- **Dừng** ở dòng tổng đầu tiên (nhãn `_nhanTong` của `doc_hoa_don.dart`, dùng chung — không chép danh sách thứ hai).
- **Bỏ**: dòng nhãn `_nhanLoai` (*khách đưa · tiền thối …*); dòng ngày / giờ; dòng có dãy ≥ 9 chữ số liền không ngăn
  (số điện thoại, mã hoá đơn, mã số thuế).
- **Số âm**: dòng chứa *giảm giá · KM · khuyến mãi · chiết khấu* hoặc số mang dấu `-` → `soTien` âm.
- **VAT** vẫn là một món (người dùng để nguyên thì nó về phần chính).
- Ảnh loại **biên lai**, form gõ tay, biến động, biên lai chia sẻ → **không** có danh sách món.

**Đưa sang form** — `KhoAnhQuet` lưu kèm `<tên ảnh>.mon.json` cạnh ảnh (cùng vòng đời: xoá cùng ảnh ở mọi chỗ mục 5.5);
form khoá `quet:` đọc tệp ấy. Không qua `extra` của router (mất khi màn dựng lại). Tệp hỏng / thiếu → coi như không có
món (chỉ nhập số).

**Sheet *"Thêm phần"* khi có món** — chọn danh mục, rồi **danh sách món có ô tick**:
- Dòng đáy *"Đã chọn N món · X đ"*; tiền của phần = Σ món đã tick (có thể ra số âm / 0 → nút *Xong* tắt).
- Món đã thuộc phần **khác** hiện mờ kèm tên danh mục của phần ấy, **không** tick được — muốn chuyển thì bỏ ở phần kia.
- Link *"Nhập số tiền"* chuyển sang ô số (khi đọc sai); phần nhập số thì `monIds` rỗng.
- Chạm một phần trên form → mở lại sheet với các món đã tick.
- **Phần chính** nhận phần còn lại = món chưa gán + VAT / giảm giá để nguyên + lệch giữa Σ món và tổng hoá đơn → tổng
  luôn khớp hoá đơn (luật mục 11.1 ý 2 không đổi).

### 11.3 Tầng thuần — `transaction/domain/tach_giao_dich.dart` (mới)

- `PhanTach { categoryId, soTien, monIds }` — `monIds` rỗng khi phần nhập số; một món chỉ thuộc **một** phần
  (kiểm hợp lệ).
- `conLai(tong, phan)` = `tong − Σ phan.soTien`.
- Kiểm hợp lệ: còn lại > 0 (ngưỡng **nửa đồng** `kDungSaiTien` như `KhoangTien`, vì `amount` là `double`); mỗi phần
  > 0; không trùng danh mục; số phần ≥ 1 mới gọi là tách.
- `gopKhiDoiDanhMucChinh(chinh, phan)` — bỏ phần trùng danh mục chính mới.
- `dungGiaoDichTach(mau, chinh, phan)` → `List<TransactionEntity>`: phần chính đứng **đầu**, mỗi hàng `Uuid().v4()`
  riêng, chung `walletId · idaccount · type 'chi' · note · date`, `syncStatus 'pending'`.
- Đặt ở `transaction/` (không `ai_edge/`) — so chiều `'chi'` (test quét 14).

### 11.4 Lưu — tất cả hoặc không

- `TransactionRepository.addTransactions(List<TransactionEntity>)`: `soDuVi.datNeoNhieuVi(hợp các ví)` **một** lần →
  chèn cả N hàng trong **một** giao tác Drift (datasource thêm `addTransactions`) → `tinhLaiNhieuVi` **một** lần →
  `scheduleSync()`. Hỏng giữa chừng → không hàng nào được ghi. ⚠️ Giữ thứ tự **neo trước khi ghi sổ** (chú thích
  `addTransaction`: đặt sau là neo hấp thụ giao dịch vừa ghi).
- Bloc: `AddTransactionsEvent(List<TransactionEntity>)` → phát **một** `actionSuccess` (cùng khuôn `_onAddTransaction`).
- Không đổi schema (vẫn v29), không đổi payload đồng bộ — mỗi phần là một giao dịch thường.

### 11.5 Ngân sách và gợi ý

- `_budgetImpactFor` chạy cho **từng** phần (danh mục của chính nó). Có phần `requiresConfirmation` (ngân sách *Chặn*) →
  **một** hộp *"Vượt ngân sách"* liệt kê từng danh mục bị vượt (mỗi dòng một `budgetImpactDialogText`), *Huỷ* / *Vẫn ghi*
  cho cả lô. Chỉ *Cảnh báo* → toast sau lưu *"Đã lưu N giao dịch"* kèm tên ngân sách bị vượt.
- Phản hồi gợi ý B1 (`_ghiPhanHoi`) chỉ cho **danh mục chính** — thẻ gợi ý hiện cho nó; phần chọn tay không ghi.
- Tách không dùng AI → mở cho **cả Basic**.

### 11.6 Kiểm thử (viết trước, mỗi chốt bản sai có chủ ý)

- `tach_giao_dich_test` — còn lại; chặn ≤ 0 (cả đuôi lẻ `double`); trùng danh mục; một món hai phần bị chặn; gộp khi
  đổi danh mục chính; N hàng id khác nhau, trường chung đúng.
- `doc_mon_hang_test` — món một dòng; món hai dòng; dừng ở dòng tổng; bỏ khách đưa / tiền thối, ngày giờ, số điện
  thoại / mã HĐ; giảm giá âm; VAT là món. Chữ OCR **giả lập** trước, thêm chữ OCR hoá đơn thật khi có (mục 9).
- `kho_anh_quet_test` — `.mon.json` xoá cùng ảnh; tệp hỏng → không món.
- Widget sheet — tick món → tiền phần = Σ; món của phần khác mờ, không tick được; *"Nhập số tiền"*; mở lại phần giữ tick.
- Repository `addTransactions` — hỏng ở hàng thứ hai → **0** hàng, số dư ví không đổi; thành công → số dư = tổng; neo
  đặt một lần.
- Bloc — một `actionSuccess` cho N giao dịch.
- Widget — dòng tách chỉ khi tạo mới + Chi; sheet loại danh mục đã dùng; đổi tổng → còn lại đổi; một toast, đóng một
  lần; hộp ngân sách nhiều danh mục; form từ ảnh quét / biến động có tách → dọn ảnh / hàng loại 20 đúng một lần.
- **Bố cục 320 dp và 360 dp, font thật** (`test/helpers/font_that.dart`) — họ lỗi G74–G84; số tiền 13 chữ số trong
  dòng phần không cắt / không tràn.

### 11.7 Stitch

Một lượt gọi: *"Thêm giao dịch - Tách theo danh mục"* (khối tách trên form + sheet *Thêm phần*). `timeout` thì **không
gọi lại**, chờ người dùng xác nhận. Lượt gọi 2026-10-08 trả `timeout`; lượt kiểm ngay sau (01:40 UTC) **chưa thấy** màn.
Lượt gọi thứ hai (sau khi thêm 11.2b): *"Thêm phần - Chọn món"* (sheet danh sách món có ô tick).

✅ **Người dùng xác nhận đã có 2026-10-08** (các lượt gọi đều `timeout` / `ECONNRESET`, người dùng xin gọi lại một lần):
- `98133eb8d35f425dbaba1b73cd230c3f` *Thêm phần - Chọn món*.
- `01f8cdc65e6d49a4b7aac6a0d54e24e5` *Thêm giao dịch - Tách theo danh mục - FlowMoney Mobile* và
  `7aca2eb47fb84e8badea38796ec4bde1` *… - FlowMoney* — **hai** bản do hai lượt gọi. **Dùng `01f8cdc6…`** (đọc HTML
  2026-10-08: *"2 món · 165.000 đ"*, còn lại *247.000 đ*, *"Lưu 2 giao dịch"* — khớp 11.2b); `7aca2eb4…` là bản lượt
  đầu (ba phần nhập số, *"Lưu 3"*, chưa có chọn món). Cả ba mang `deviceType: DESKTOP`.

### 11.8 Nghiệm thu Realme

Bảng mục 9 (b) thêm cột **số món đọc đúng / tổng số món** mỗi hoá đơn. Chụp hoá đơn siêu thị thật → form từ ảnh quét →
tách 3 phần bằng **tick món** → Lưu: số dư ví giảm đúng tổng; Sổ giao dịch có 3 hàng
cùng ngày giờ + ghi chú; sau đồng bộ PostgreSQL có 3 hàng. Thêm một lượt gõ tay (không ảnh) tách 2 phần. Ở cỡ hiển thị
320 dp và 360 dp.

### 11.9 Thứ tự thi công

Cùng **một** kế hoạch với A5: phần quét (mục 3–9) trước, tách (mục 11) sau. Tách không phụ thuộc OCR nên kiểm được độc
lập.

## 12. Chỗ bản thi công KHÁC bản viết (2026-10-08)

1. **Không nút *"Lưu N giao dịch"* ở đáy** (11.2, Stitch `01f8cdc6…`): form chỉ lưu bằng ✓ (thanh tiêu đề / phím ✓ của 16
   phím). ✓ giữ nguyên, tooltip nói *"Lưu N giao dịch"*, chân khối tách nói *"Sẽ lưu N giao dịch"*. Chip đầu khối nói
   *"Tổng: …"* thay *"Khớp: …"*.
2. **Ảnh quét xoá trong `dispose()` của form** — một chỗ cho mọi đường thoát (Lưu, Bỏ qua, ←, Back hệ thống) thay vì
   viết ở từng nút (5.6).
3. **Nhãn dừng đọc món ≠ nhãn tổng** (11.2b): bỏ *thanh tien · so tien · thanh toan* (tiêu đề cột / nhãn từng món),
   thêm *tam tinh · subtotal*. Dùng nguyên nhãn tổng thì dòng *"SL Đơn giá Thành tiền"* dừng đọc trước món đầu.
4. **So nhãn dừng theo TỪ trọn** (`\btong\b`) — chuỗi con thì món *"BANH TONGHOP"* cắt cụt danh sách.
5. **Dòng món đòi số cuối có ngăn nghìn** — loại ngày / giờ / năm mà không cần luật ngày riêng.
6. **Tách chỉ khi `type == 'chi'`** ở đường lưu (lưới thứ hai cạnh việc bỏ hết phần khi đổi sang Thu / Chuyển).
7. Toast có ngân sách *Cảnh báo* bị vượt chỉ nêu **một** ngân sách (cái đầu) — cùng nếp `budgetImpactSnackText`.
8. Tên danh mục dài trong khối tách **xuống dòng**, không "…" (test bố cục 320 / 360 dp font thật bắt được lúc thi công).

## 13. Đổi sau nghiệm thu OnePlus 2026-10-08 — AI làm chính, luật dự phòng (CHƯA THI CÔNG)

**Số đo** (OnePlus 13R GPU, 6 hoá đơn thật người dùng chọn từ thư viện: MAXIDI #1 nhăn + ảnh nén 720 px, QA TEA, Starbucks,
eco-shop, MAXIDI #2, ÙA TEA có chiết khấu; đáp án chấm bằng mắt trên ảnh; màn đo spike C4):

| Đường | Tổng đúng | Món đúng trọn | Thời gian | Ghi chú |
|---|---|---|---|---|
| Luật (sau các sửa của `367cefbd`) | 4/6 (2 lần lệch vài đồng do OCR đọc nhầm chữ số) | 2/6 | 0,2–0,4 s | MAXIDI #1: Σ món tình cờ khớp tổng mà tên lệch giá |
| AI đọc chữ OCR (`DocAnhBangAi`) | = luật (chữ OCR sai thì AI sai theo) | — | ~5 s | ghi chú *"Tiền mặt"*, ngày bịa (hôm nay) |
| Gemma nhìn ảnh, prompt chỉ hỏi tổng/cửa hàng/ngày | MAXIDI #1 ra **757.000** (gấp 10) | — | 2,6 s | |
| Gemma nhìn ảnh, prompt **đọc món** (`kPromptMonHoaDon` bản đầu) | **6/6**, lặp lại y hệt 3/3 lần mỗi ảnh | 1/6 | 3,7–11 s | |
| Gemma nhìn ảnh, prompt đọc món **+ cửa hàng / ngày / giờ** | **5/6** (MAXIDI #2 ra 59.100, đúng 72.127) | — | 4,7–16,6 s | cửa hàng 3/6, ngày 3/6 (năm *2020*), giờ 3/6 |

Kết luận: Gemma **tất định** nhưng **rất nhạy với câu hỏi** — thêm ba trường là tổng tụt; AI không đáng tin cho ngày /
cửa hàng. Vì sao OCR đọc sai số: ảnh độ phân giải thấp (720 × 1280, ảnh đã nén), giấy nhăn làm hàng chữ cong — ML Kit
ghép chữ hai hàng kề, nhầm 0↔6, 5↔6, chấm↔phẩy, *"Tổng"* → *"Teng"*; `image_picker` còn thu ảnh máy ảnh về
`maxWidth: 1280`.

**Quyết định người dùng (2026-10-08, AskUserQuestion):**
1. **Tick món tạm TẮT** (`kChonMonTuAnhQuet = false`, đã làm `367cefbd`) — A5b.
2. **Ngày in ở tương lai → đảo ngày/tháng** nếu ra quá khứ, không thì lúc quét (đã làm).
3. **AI làm chính, luật dự phòng**: Premium + có mô hình → Gemma nhìn ảnh; Basic / chưa tải mô hình / AI lỗi / Huỷ →
   luật. Người dùng hỏi *"nếu luật đọc sai thì sao"* → khi có CẢ HAI tổng mà lệch **> 1%** → ô số tiền TRỐNG + dòng
   *"Đọc ra hai số khác nhau — chọn số đúng:"* + **hai chip** (số AI · số luật), chạm là điền; lệch ≤ 1% → số AI.
4. Người dùng từng hỏi *"bỏ hẳn luật, AI đọc hết"* — đã trình hệ quả (Basic không đọc được gì, chậm, không lưới kiểm,
   biên lai chưa đo) và họ chọn hướng 3.

**Đo lại trên Realme RMX2205 (2026-10-08 trưa) — "AI đọc món + tổng, luật đọc phần còn lại".** Người dùng: *"kiểm với
tất cả hoá đơn có trên máy"*, *"lấy những ảnh hoá đơn hoặc biên lai thôi"*. Máy tự lọc 248 ảnh thư viện (OCR + điểm dấu
hiệu, nút *Lô* của màn spike, mã `loc…`) → 36 ảnh có dấu hiệu → xem ảnh thu nhỏ: **16 hoá đơn** (2 ảnh Pharmacity trùng
nhau → 15 hoá đơn khác nhau), **0 biên lai chuyển khoản** (hai ảnh máy chấm "biên lai" là ảnh chụp màn FlowMoney). Ảnh
máy ảnh thu về rộng 1280 như `image_picker` của `/quet`. Gemma chạy **CPU** (Mali, canary GPU), prompt `kPromptMonTong`
(chỉ món + tổng). Đáp án chấm bằng mắt; R15 tính *số tiền thực trả* (30.000 sau trừ điểm). Log: `[C4][LO-*]`.

| | Đúng | Ghi chú |
|---|---|---|
| Tổng — Gemma CPU | **10/15** | sai: lấy giá gạch (83.500), lấy một dòng món (16.588, 17.800), 78.000, 55.000 |
| Tổng — luật | 9/15 | sai: năm in làm tiền (2026), tổng trước chiết khấu / trước VAT, 9.243, 72.121, điểm 2.160 |
| Hai bên khớp nhau | 6/15 | **cả 6 đều đúng** |
| Hai bên lệch → hai chip | 9/15 | 7 có số đúng trong chip · 2 không chip nào đúng (BHX nhòe, MAXIDI #2) |
| Món — Gemma CPU đúng trọn | 3/15 | chỉ hoá đơn 1 món + Starbucks; còn lại sót dòng / lấy đơn giá thay thành tiền |
| Cửa hàng — luật | 4 ✅ · 3 ◐ · 8 ❌ | 4/8 ❌ là nhãn dán laptop phía sau (ASUS, CORE, IRIS, "rtel"); 2 là địa chỉ |
| Ngày — luật | 7 ✅ · **2 sai im lặng** · 6 lúc quét | MAXIDI in **tháng/ngày**: *9/2/2026* → 09/02, *10/1/2026* → 10/01 (đúng là 02/09, 01/10) |

Thời gian: OCR 0,4–0,9 s; Gemma CPU **21–42 s/ảnh**. ⚠️ **CPU khác GPU**: cả 6 hoá đơn của bộ OnePlus đều có trên Realme — GPU đúng
tổng 6/6, CPU 3/6 (ÙA TEA #1, MAXIDI #1, MAXIDI #2 sai) — "tổng 6/6" ở trên là số của GPU, không phải của mọi máy. OCR cũng
đổi theo ảnh: MAXIDI #1 luật nay 75.700 ✅ (OnePlus 75.706), ÙA TEA #2 nay 246.000 ❌ (OnePlus 217.500).

**Sửa sau lượt đo Realme (2026-10-08 chiều, người dùng duyệt ba việc):** (1) hàm thuần `chotTongQuet` — số AI chỉ
dùng khi có trên ảnh hoặc khác số luật đúng một chữ số; khớp ≤ 1% → điền, lệch → hai chip; (2) luật tổng: bỏ ngày / giờ
khỏi dòng, số ở dòng trên nhãn, *"tổng"* đọc méo, *Payment* trên *Total*; (3) ngày: in thiếu số 0 → gần lúc quét nhất,
bỏ dấu ảnh, đọc *Sep 28, 2026* và *Ngày … tháng … năm*; kèm tên cửa hàng (bỏ chữ trên đồ vật phía sau, trống thay vì
đoán). Trên chính 15 tờ ấy: luật tổng **15/15** (R15 tính *Tổng tiền* 32.160), ngày 9 đúng cả giờ + 2 đúng ngày (giờ không đọc ra) · 4 không đọc ra
· **0 sai im lặng**, cửa hàng 8 đúng · 3 trống · 4 tạm được; chốt AI + luật **13/15 điền sẵn đều đúng, 2 tờ hỏi chip**
(số đúng có trong chip). ⚠️ Luật sửa trên đúng bộ đo — cần hoá đơn MỚI để kiểm. `chotTongQuet` **chưa nối** vào `/quet`.

**Nối vào `/quet` (2026-10-08 tối — mã + test, 🚧 chưa nghiệm thu máy thật):** `SlmDocAnh.docAnh` (runtime nạp lại
bản có ảnh, đóng sau khi đọc) → `DocAnhBangGemma` (trần 90 s, Huỷ) → `docJsonGemmaAnh` → `chotTongQuet` → query `chon`
→ khối hai chip trên form. Chỉ hoá đơn, chỉ Premium. `DocAnhBangAi` / `lapTuAi` bỏ. Sheet `moQuet` `useRootNavigator`.
Lỗi kèm: `PhienMotLoiGoi.chuanBi` nhớ "đã nạp" mãi — sau một lần quét đóng mô hình, Nhập nhanh âm thầm thôi dùng AI (đã
sửa). Màn Stitch khối chip: gọi 2026-10-08, lượt gọi `timeout` — chờ hiện. Chưa làm: nâng `maxWidth`, dùng món của AI
(tick món vẫn tắt).

**Nghiệm thu OnePlus 13R trọn 8 tờ (2026-10-08 chiều, GPU, ảnh Google Photos, bản có `7d44b159`):**

| Tờ | Luật | Gemma (ảnh) | Form hiện | Gemma · danh mục |
|---|---|---|---|---|
| ÙA TEA 158.000 | ✅ | ✅ | điền sẵn · Ăn uống | 9,5–12,6 s · 3,7–4,2 s (ba tờ đầu) |
| ÙA TEA 217.500 | ✅ | ✅ | điền sẵn · Ăn uống | ″ |
| Starbucks 262.000 | ✅ | ✅ | điền sẵn · Ăn uống | ″ |
| BHX 55.500 | ❌ 2.006 → ✅ sau sửa | ✅ | hai chip → **điền sẵn** sau sửa · Ăn uống | 5,3 s · 4,0 s |
| MAXIDI 72.127 | ❌ 12.127 | ✅ | hai chip (đúng đứng trước) · Ăn uống | 9,8 s · 3,6 s |
| eco-shop 57.000 | ✅ | ✅ | điền sẵn · Mua sắm | 4,4 s · 3,7 s |
| BHX nhoè 79.243 | ✅ | ❌ 16.588 | hai chip (đúng đứng sau) · Ăn uống | 3,6 s · 3,6 s |
| Dookki 300.240 | ✅ | ✅ | điền sẵn · Ăn uống | 3,9 s · 3,7 s |

**Không tờ nào điền sẵn số sai**; ba tờ lệch đều có số đúng trong chip. Chín lần quét liên tiếp không sập (bản sửa
`7d44b159` giữ). Chạm chip *55.500 đ*: số điền vào, chip tô xanh kèm ✓, bàn phím ẩn, ✓ lên thanh tiêu đề (không bấm
Lưu — tài khoản thật). Ngày: 4/5 tờ sau rơi về lúc quét vì OCR OnePlus hỏng năm (*202b*, *2326*, *912/2026*,
*06/09/29 9/2326*) — đúng luật đã định. **Hai sửa luật từ chữ OCR OnePlus** (dữ liệu `kHoaDonOnePlus` P04 · P05 · P07):
*"Tbng tiễn"* là nhãn tổng (`kNhanTongDocNham` nhận mọi chữ trừ *a* giữa *t* và *ng*); ngày *"3O/08/2026"* (O sát chữ
số là 0). Đo lại hai tờ trên máy: BHX luật 55.500 khớp Gemma → điền sẵn; eco-shop ngày 30/08/2026, giờ 00:00 (in
*"21 33 37"* không dấu hai chấm — như R05). Chưa sửa (ứng viên): câu văn xuôi *"…và thanh toán tin mặt"* khớp nhãn
*thanh toán* rồi mượn số dòng kế; MAXIDI OCR đọc *12,127* (chip đỡ được). 🚧 **Realme (Mali, CPU) chưa chạy `/quet`
thật** — 8/8 là số của GPU OnePlus.

**Việc phiên sau (chưa làm, chưa có trong kế hoạch):**
- Chọn PROMPT bằng số đo: prompt đọc món bản đầu (chỉ `mon` + `tong`) đúng tổng 6/6; thêm trường là tụt. Đề xuất: lấy
  **chỉ tổng** từ Gemma bằng prompt bản đầu; ngày / cửa hàng vẫn do luật (AI đúng ~một nửa). Đo lại 6 ảnh trước khi
  chốt; đo thêm biên lai MB (Gemma chưa đo biên lai lần nào).
- `SlmRuntime` thêm hàm chính thức đọc ảnh (thay `spikeDaPhuongThuc`) — nạp lại mô hình `supportImage`, đóng sau khi
  đọc (RAM). Lớp gọi (`transaction/data/`, khuôn `DocCauBangAi`), parse JSON chịu số dạng `"75,700"` (chuỗi có phẩy).
- Hàm thuần chốt tổng (luật / AI / lệch → hai lựa chọn); query `/add` mang hai lựa chọn; form hiện dải chip (Stitch:
  gọi một lần). Bỏ `DocAnhBangAi` (AI đọc chữ OCR) khỏi luồng `/quet`.
- Nâng `maxWidth` ảnh máy ảnh (1280 → 2048 hoặc bỏ) — đo OCR trước/sau.
- Lỗi lượt nghiệm thu chưa sửa: **sheet chọn nguồn ảnh bị thanh dưới + nút + đè** (nút *Huỷ* khuất) — `moQuet` cần
  `showModalBottomSheet(useRootNavigator: true)`.
- Luật ngày chưa đọc dạng tiếng Anh *"Sep 28, 2026 2:19PM"* (Starbucks); giờ có thể lấy nhầm dấu ảnh *"Shot on … 08:15"*.
