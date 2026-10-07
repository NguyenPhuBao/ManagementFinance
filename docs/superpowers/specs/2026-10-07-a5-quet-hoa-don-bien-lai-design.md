# A5 — Nút "Quét": chụp / chọn ảnh hoá đơn hoặc biên lai → form Thêm giao dịch điền sẵn

**Ngày:** 2026-10-07 · **Trạng thái:** thiết kế duyệt trong chat (ba phần), bản viết chờ người dùng đọc · **Mục UX:** A5
(`docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`) · **Stitch:** chưa có — ba màn ở mục 7, chờ xác nhận.

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

1. Trang chủ — bottom sheet *"Quét"* hai dòng (Chụp ảnh · Chọn ảnh có sẵn).
2. Màn *"Đang đọc ảnh…"* (ảnh mờ nền, vòng xoay, nút Huỷ; biến thể *"Đang đọc bằng AI…"*).
3. Form Thêm giao dịch mở từ ảnh quét (dải *"Từ ảnh quét · …"*, ảnh thu nhỏ) — chỉnh từ `805cd430…`.

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

QR / VietQR; quét nhiều ảnh một lần (hàng chờ ghi); đọc từng dòng món hàng; AI đọc thẳng ảnh (lối B của spike C4 —
24,5 s, RAM 2,9 GB); gỡ màn đo spike C4; **giọng nói** (spec riêng ngay sau A5 — mục 1).
