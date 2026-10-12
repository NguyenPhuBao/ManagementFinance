# C4 — Giọng nói nhập giao dịch — thiết kế

> **Trạng thái:** thiết kế duyệt từng phần trong chat 2026-10-12 (bốn phần + năm câu chọn, mục 1). **Kế hoạch 16 task đã
> viết** (`plans/2026-10-12-c4-giong-noi-nhap-giao-dich.md`, gitignore); **chưa có mã** — người dùng để phiên sau thi công. **Phạm vi lần này dừng trước phần kiểm thử trên máy** (mục 9): làm spec → kế hoạch → mã kèm test tự động, rồi
> dừng; đo trên điện thoại để dành cho lúc người dùng cầm máy.
>
> Nguồn: spike C4 (`plans/2026-09-28-c4-spike-giong-noi-chup-hoa-don.md`, gitignore; mục **9.44** `AI_EDGE_FEATURE.md`),
> C2 (`specs/2026-09-28-c2-nhap-giao-dich-bang-cau-design.md`), A5 (`specs/2026-10-07-a5-quet-hoa-don-bien-lai-design.md`
> — nửa *chụp hoá đơn* của C4 đã làm ở đó). C4 nay chỉ còn **nửa giọng nói**.

> 🔧 **Soát với mã lúc lập kế hoạch (2026-10-12)** — khối này THẮNG thân spec ở chỗ hai bên khác nhau:
>
> 1. **§4.2:** dời hai hàm đóng hàng thành **hàm thường** ở `transaction/data/dong_hang_bien_dong.dart`
>    (`dongHangBienDong`, `dongHangChuyenKhoan` — nhận `ThemGiaoDichNguon`), không thêm phương thức vào interface: interface
>    và bản giả `NguonThemGiaoDichGia` không đổi.
> 2. **§3.2 N1 sửa luôn một lỗi sẵn có:** câu chữ số *"1 triệu 2"* hôm nay luật đọc **1.000.000, im lặng** —
>    `_mauSoDonVi` khớp *"1 triệu"*, còn `_mauTrieuLe` (đọc đúng 1.200.000) chỉ nằm trong `cachDocSoTien`.
> 3. **§3.3 chuyển ví bằng chữ:** nguyên nhân là `_sauLaChuSoChu` so trên chữ **bỏ dấu** — *"từ"* thành `tu` = *tư* (4),
>    cả cụm *"năm trăm nghìn"* bị gạt là "chưa rõ". Sửa: so chữ số chữ **có dấu** (gõ không dấu hoàn toàn vẫn nhận).
> 4. **§3.3 ví gọi tắt:** tên bỏ chữ *Ví* chỉ được nhận **ngay sau** *ví · bằng · qua · từ · sang · vào · đến · tới*
>    (lookbehind), và làm ở `doc_cau_giao_dich.dart`, không ở `khop_ten.dart` — nhận ở mọi chỗ thì *"mua sách tiết kiệm"*
>    chọn ví *Ví tiết kiệm*.
> 5. **§3.2 N2:** chữ đứng sau con số so **có dấu** — *"quả"* bỏ dấu là `qua`, trùng *"qua"* (trả qua ví).
> 6. **§3.3 *mùng X*:** tháng này; rơi vào tương lai > 7 ngày thì tháng trước (cùng nếp *dd/mm* lùi năm).
> 7. **Lan sang C3:** lệnh tạo ở màn Trợ lý dùng chung `chonSoTienTrongCau` (một định nghĩa) → N1 / N2 áp luôn cho câu lệnh
>    tạo (*"đặt ngân sách ăn uống 2 triệu 5"* → 2.500.000). Cố ý; test C3 mã hoá chỗ hụt cũ phải sửa theo.
> 8. **§4.3:** `chepLoi` ở interface riêng **`SlmChepLoi`** (khuôn `SlmDocAnh`) — 8 bản giả `SlmRuntime` trong test không
>    đổi. Luật nạp tách thành hàm thuần **`quyetDinhNap`** (`ai_edge/domain/nap_da_phuong_thuc.dart`) để test bốn chuỗi.
> 9. **§2.2 *có mạng*:** thêm `ConnectionMonitor.coMangNgay()` (hỏi `checkConnectivity` ngay, lỗi → `true`); lớp này vốn
>    chỉ có luồng sự kiện ổn định 3 giây.

## 1. Quyết định người dùng chốt (2026-10-12)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Điểm dừng | Làm spec, kế hoạch, mã + test tự động; **dừng trước bước đo trên điện thoại** |
| 2 | Cách nghe | **Android trước, Gemma dự phòng** — bộ nhận giọng nói của máy khi dùng được; mất mạng thì Gemma nghe |
| 3 | Chỗ đặt micro | **Ô Nhập nhanh** (màn Thêm giao dịch) **và** nút **Nói** ở Trang chủ |
| 4 | Dạng nói tiền (*năm chục · một triệu hai · ba trăm rưỡi*) | **Luật trước, Gemma sau** — luật học thêm các dạng ấy; ô nào luật vẫn trống mới hỏi Gemma |
| 5 | Luật đọc sai thì sao | **Gemma kiểm chéo, lệch thì hai chip** — riêng số tiền đọc bằng dạng nói mới học |
| 6 | Lúc mất mạng | **Gemma chép lời → câu đi đường Nhập nhanh** (không cho Gemma nghe-và-điền trong một lượt) |
| 7 | Nói xong có tự điền không | **Có** — câu vào ô rồi tự Điền; sai thì sửa chữ trong ô, bấm Điền lại |

Bất biến ④ nhóm C giữ nguyên: AI **điền sẵn**, chỉ ghi khi người dùng bấm Lưu; không chạm tầng 4, không xoá.

## 2. Người dùng thấy gì

### 2.1 Ô Nhập nhanh (màn Thêm giao dịch, đường tạo mới, Premium)

1. Trong khung ô có biểu tượng **micro**, bên trái nút *Điền*. Basic không có micro (ô vốn khoá — *"Chỉ Premium"* + nút
   Nâng cấp, spec Premium 8.2).
2. Bấm micro lần đầu → Android hỏi quyền Micro. Từ chối → toast *"Cần quyền micro để nói"*. Bị chặn hẳn (không hỏi lại
   được) → toast kèm nút *Mở cài đặt* (trang thông tin ứng dụng).
3. **Đang nghe:** viền ô đổi màu, gợi ý thành *"Đang nghe…"*, micro thành nút dừng ■.
   - Lối Android: chữ **hiện dần** trong ô khi đang nói.
   - Lối Gemma: chấm đỏ + số giây đang ghi.
4. **Dừng:** tự dừng khi im ~2 giây, hoặc bấm ■; tối đa 20 giây.
5. Lối Gemma sau khi dừng: dòng *"Đang chép lời bằng AI trên máy…"* + **Huỷ** (spike: ~10 s trên Realme CPU, giọng tổng
   hợp — cận trên).
6. Câu nằm trong ô → **tự Điền** qua đúng `ThemGiaoDichCubit.dienTuCau` (C2): dòng *"Đã điền: …"*, dòng nguồn *Đọc bằng
   luật / AI*. Nghe sai → sửa chữ trong ô, bấm *Điền* lại. Không ghi gì tới khi bấm Lưu.
7. **Kiểm chéo số tiền** (mục 3.4) — khi số tiền đọc bằng dạng nói mới học và máy có Gemma: số điền ngay, dòng nhỏ
   *"Đang kiểm số tiền bằng AI…"* + Huỷ. Khớp → dòng biến mất. Lệch → ô số tiền **trống** + **hai chip** (khối
   `KhoiChonSoTien` có sẵn của biến động / ảnh quét; số AI trước, số luật sau). Người dùng đã đổi số trước khi AI về →
   AI không đụng.

### 2.2 Chọn lối nghe — app tự chọn, không công tắc

| Tình huống | Lối | Ghi chú |
|---|---|---|
| Có mạng, Android dùng được | Android, `onDevice: false` | giọng gửi lên dịch vụ nhận dạng của máy (thường là Google) — như gõ bằng giọng trên bàn phím |
| Mất mạng, Gemma sẵn sàng | Gemma (ghi WAV → chép lời) | |
| Mất mạng, Gemma không sẵn sàng | Android, `onDevice: true` | máy có gói tiếng Việt offline thì chạy; không thì lỗi → câu ở dòng cuối |
| Android báo lỗi **mạng** giữa chừng | — | *"Mất mạng — bấm micro nói lại, lần này nghe bằng AI trên máy"* (nếu Gemma sẵn sàng); lượt sau đi Gemma. Âm thanh lượt trước không có — Android giữ micro, app không ghi song song |
| Không lối nào dùng được | — | toast *"Cần mạng hoặc mô hình AI trên máy để nói"* + nút sang *Cài đặt AI* |

*Gemma sẵn sàng* = **đúng** điều kiện mà ô Nhập nhanh dùng để gọi AI (`DocCauBangAi.sanSang` — tệp mô hình, công tắc AI,
quyền `ai_edge_model`); không định nghĩa thứ hai. *Có mạng* đọc từ nguồn kết nối app đã có (`ConnectionMonitor` /
`connectivity_plus` qua DI), không gọi mạng thử.

⚠️ **Mã lỗi cụ thể của `speech_to_text` cho "mất mạng" và "không có gói ngôn ngữ"** (`SpeechRecognitionError.errorMsg`,
`.permanent`) **chưa đo trên máy** — kế hoạch đặt tên hằng ở một chỗ (`chon_loi_nghe.dart`) với giá trị theo tài liệu
gói, và phần kiểm thử (mục 9) xác nhận chuỗi thật trên Realme / OnePlus.

### 2.3 Nút **Nói** ở Trang chủ

- Hàng nút nhanh thành năm: Thêm thu · Thêm chi · Chuyển · Quét · **Nói** (biểu tượng micro).
- Bấm → `context.push('/add?noi=1')` → màn Thêm giao dịch mở và **bắt đầu nghe ngay** (như bấm micro trong ô).
- Basic (không quyền `ai_quick_input`) → `context.push('/premium?quyen=ai_quick_input')` (khuôn `NutNangCap`).
- ⚠️ **Query, không `extra`:** route `/add` đọc `extra is String` làm *chiều tiền đặt sẵn* (`'chi' | 'thu' | 'transfer'`
  — ba nút tắt cũ); một chuỗi `'noi'` sẽ bị nuốt thành chiều. Thêm tham số `batDauNghe` cho `AddTransactionPage`, route
  đọc `state.uri.queryParameters['noi'] == '1'`.

### 2.4 Không làm

Giọng nói ở màn **sửa** giao dịch (ô Nhập nhanh không có ở đó), ở **Trợ lý AI**, ở form điền từ **biến động / ảnh quét**.
Không lưu âm thanh: WAV của lối Gemma nằm ở thư mục tạm của app và **xoá ngay** sau khi chép (kể cả lỗi / Huỷ / rời màn).
Không bỏ lối nào trước khi đo (mục 9).

## 3. Luật đọc câu nói và kiểm chéo

### 3.1 Một đường, không nhánh theo nguồn câu

`dienTuCau(cau)` **không biết** câu đến từ micro hay bàn phím, và **không** thêm tham số `nguon:`. Mọi luật mới ở 3.2 áp
cho cả câu gõ (người dùng chốt ở phần 2). Lý do: một định nghĩa của "đọc câu"; câu gõ *"ăn phở 45"* hưởng cùng lợi ích.

### 3.2 Luật mới — **chọn thêm trong tập `cachDocSoTien` đã có**

`cachDocSoTien` (`doc_cau_giao_dich.dart:485`) đã liệt kê mọi cách đọc hợp lệ của các con số trong câu, kể cả *"X triệu Y"*
và *"số chữ không đơn vị có hàng chục × 1.000"*. C2 cố ý **không cho luật chọn** chúng (`_chonSoTien` đặt `chuaRo` cho
*X triệu Y*, bỏ số < 1.000) để Gemma chọn. C4 cho luật **chọn** thêm hai họ — **không** viết bộ đọc số mới:

| Họ | Ví dụ | Đọc | Điều kiện |
|---|---|---|---|
| **N1** — *X đơn vị Y* (Y một chữ số ngay sau đơn vị, không đơn vị nào sau Y) — **đúng các dạng `cachDocSoTien` đã có**: chữ *X nghìn / triệu / tỷ Y* (`_bacCuoi` + `_sauLaChuSoChu`), chữ số *X triệu / tr / củ / tỷ Y* (`_mauTrieuLe`) | *một triệu hai* · *năm nghìn hai* · *1 triệu 2* | 1.200.000 · 5.200 · 1.200.000 | — |
| **N2** — số **10–999** không đơn vị (chữ hoặc chữ số) mà `cachDocSoTien` đã có cách đọc × 1.000, kể cả *rưỡi* sau *trăm* | *năm chục* · *ba trăm rưỡi* · *bốn mươi lăm* · *45* · *350* | 50.000 · 350.000 · 45.000 · 45.000 · 350.000 | cụm đứng **cuối câu**, hoặc ngay trước chữ nói về ví / ngày / cách trả (*bằng · trả · qua · từ · sang · vào · hôm · ngày · mùng · thứ*, dấu câu). Đứng trước danh từ khác (*quả · ly · cái · phút · người · lần…*) → **không** đọc (để Gemma như cũ) |

Thứ hạng: cụm có đơn vị tiền (*k · nghìn · tr · củ*…) vẫn **thắng** N1/N2 — *"mua hai mươi quả trứng ba mươi nghìn"* →
30.000. Số một chữ số vẫn là số lượng (*"2 ly"*).

**Bất biến kiểm chéo:** số của luật ∈ `cachDocSoTien(cau)`, số Gemma được chọn ∈ `cachDocSoTien(cau)` (lưới C2 §2.8 có
sẵn). Nên "lệch" luôn là **hai cách đọc thật** của cùng một câu — không số nào bịa, không cần phép kiểm `vanBan` như ảnh.

### 3.3 Luật mới ngoài số tiền

| Chỗ | Hôm nay | Mới | Tệp |
|---|---|---|---|
| Ngày bằng chữ / số: *ngày năm tháng chín*, *ngày 5 tháng 9*, *mùng năm* | không ra ngày | 05/09 (năm nay; tương lai > 7 ngày → năm trước, theo luật ngày hiện có) | `core/utils/ngay_trong_cau.dart` |
| Ví gọi tắt: *bằng MB Bank* khi ví tên *Ví MB Bank* | không khớp | khớp — bỏ chữ *Ví* đầu **tên ví** khi so (chỉ ví, chỉ chữ đầu) | `core/utils/khop_ten.dart` / `cauNhacViTheoTen` |
| Chuyển ví, số tiền bằng chữ: *chuyển năm trăm nghìn từ MB Bank sang tiết kiệm* | không ra số tiền (spike câu 19) | 500.000 | `doc_cau_giao_dich.dart` (kế hoạch tìm nguyên nhân trước khi sửa) |

### 3.4 Kiểm chéo số tiền

- `KetQuaDocCau` thêm cờ **`soTienCanKiem`** (bool): `true` ⇔ số tiền được chọn đến từ **N1 hoặc N2**. Đặt trong
  `_chonSoTien` theo **loại cụm** thắng.
- Hàm thuần mới **`chotSoTienCau({required double luat, required double? ai})` → `ChotTong`** (`domain/`) — **không**
  dùng lại `chotTongQuet` (luật `vanBan` và "lệch một chữ số" của nó là của OCR). `ai == null` hoặc `|ai − luat| ≤ 0,5` →
  `ChotTong(soTien: luat)`; khác → `ChotTong(luaChon: [ai, luat])`.
- Luồng trong `ThemGiaoDichCubit.dienTuCau`:
  1. Câu còn **ô thiếu** → C2 vốn đã hỏi Gemma trước khi điền → kết quả AI ấy dùng luôn cho kiểm chéo, **không gọi lần
     hai**.
  2. Không ô thiếu, `soTienCanKiem` và Gemma sẵn sàng → điền ngay bằng luật, rồi **một** lượt `DocCauBangAi.doc` ở nền,
     trạng thái `dangKiemSoTien` (dòng nhỏ + Huỷ).
  3. AI về: số AI = `KetQuaAi.soTien` **qua đúng lưới C2** — tách phép kiểm đang nằm trong `docCauGiaoDich`
     (`doc_cau_giao_dich.dart:317`: `st < 1e13 && cachDocSoTien(cau, now: now).any((v) => (v - st).abs() <= 0.5)`)
     thành hàm công khai **`soTienAiHopLe(cau, ai, now)` → `double?`**, và dòng 317 gọi lại nó — một định nghĩa, không
     lưới thứ hai. Số không qua lưới → coi như AI không có số (giữ số luật).
  4. **Người dùng thắng:** chỉ áp kết quả khi `chuoiSoTien` hiện **vẫn bằng** chuỗi luật đã điền; khác → bỏ kết quả.
  5. `chotSoTienCau` → lệch: `chuoiSoTien` rỗng + `luaChonTienCau = [ai, luat]` → `KhoiChonSoTien` (chạm chip qua
     `chonSoTien` như D1/A5). Khớp / AI lỗi / AI không có số → giữ số luật, tắt dòng.
  6. Huỷ / rời màn / điền câu mới → lượt kiểm bị bỏ (bộ đếm `_luotDien` có sẵn).

### 3.5 Lối Gemma chép lời

- Prompt **giữ nguyên** `kPromptChepLoi` của spike: *"Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về
  câu ấy, không giải thích."* — đổi chữ là mất điểm đo duy nhất đang có (spike: số đúng, chữ sai *phở → vợ*). Hằng dời ra
  khỏi tệp spike **trước** khi xoá tệp ấy.
- Kết quả: cắt khoảng trắng, bỏ ngoặc kép / dấu chấm cuối thừa; rỗng → *"Không nghe rõ — nói lại"*.

## 4. Kiến trúc và vị trí tệp

### 4.1 Tệp

| Tệp | Thư mục | Vai trò |
|---|---|---|
| `nghe_android.dart` | `features/transaction/data/datasources/` | tệp **duy nhất** import `speech_to_text`; bọc `initialize` / `listen` / `stop` / `cancel` sau một interface tiêm được |
| `ghi_am.dart` | `features/transaction/data/datasources/` | tệp **duy nhất** import `record`; WAV 16 kHz mono vào thư mục tạm, dừng khi im ~2 s (luồng biên độ của gói) hoặc 20 s; xoá tệp |
| `chep_loi_bang_gemma.dart` | `features/transaction/data/` | gọi `SlmRuntime.chepLoi`; tiền lệ `doc_anh_bang_gemma.dart` cùng thư mục |
| `chon_loi_nghe.dart` | `features/transaction/domain/` | hàm thuần chọn lối (bảng 2.2) + hằng mã lỗi |
| `doc_cau_giao_dich.dart` · `chot_so_tien_cau.dart` | `features/transaction/domain/` | N1, N2, `soTienCanKiem`, chuyển ví bằng chữ; `chotSoTienCau` |
| `ngay_trong_cau.dart` · `khop_ten.dart` | `core/utils/` | ngày bằng chữ / số; ví gọi tắt |
| `nghe_giong_noi_cubit.dart` + `_state.dart` | `features/transaction/presentation/bloc/` | trạng thái micro — **Cubit riêng**, không vào `ThemGiaoDichCubit` |
| `them_giao_dich_cubit.dart` | như trên | kiểm chéo (3.4) |
| `o_nhap_nhanh.dart` · `dong_dang_nghe.dart` | `features/transaction/presentation/widgets/them_giao_dich/` | nút micro; dòng *đang nghe / đang chép lời / đang kiểm* |
| `add_transaction_page.dart` | `…/presentation/pages/` | nối hai Cubit; `batDauNghe`; hiện `KhoiChonSoTien` dưới ô Nhập nhanh khi `luaChonTienCau` khác rỗng (hôm nay khối ấy chỉ dựng ở nhánh biến động) |
| `slm_runtime.dart` | `features/ai_edge/data/` | `chepLoi(duongTep, wav)` thay `spikeDaPhuongThuc` (quét 16) |
| `home_page.dart` | `features/home/presentation/pages/` | nút Nói |
| `app_router.dart` | `core/router/` | `/add?noi=1` |
| `MainActivity.kt` | `android/…/flowmoney/` | kênh `flowmoney/micro`: `trangThai` (`co` · `hoiDuoc` · `biChan`), `moCaiDat` |
| `AndroidManifest.xml` (main) | `android/app/src/main/` | `RECORD_AUDIO`, `<queries>` `android.speech.RecognitionService` (dời từ manifest debug) |

### 4.2 Chừa chỗ trong `ThemGiaoDichCubit` — việc đầu

Cubit **1.097** dòng (trần quét 23: 1.200). Dời `_dongBienDong` (17 dòng) + `_dongChuyenKhoan` (16 dòng) — không `emit`,
chỉ gọi `_nguon` — thành hai phương thức công khai của `ThemGiaoDichNguon` (đếm 2026-10-12: **33** dòng). Cubit ≈ 1.067,
thêm kiểm chéo (~40) ≈ **1.107**, còn ~90 dòng. Test của hai hàm đi theo chúng sang `them_giao_dich_nguon_test`.

### 4.3 `SlmRuntime` — một bản đa phương thức, **sửa** luật của A5

Hôm nay `docAnh` nạp lại khi `_model == null || !_coAnh || _coAm` (tức **từ chối** bản có âm thanh). A5 ghi: OnePlus 13R
GPU **sập native** ở lần **đóng thứ hai** trong một tiến trình. Nếu `chepLoi` nạp bản *chỉ âm thanh* thì chuỗi
*Quét → Nói → Quét* đóng hai lần → sập. Luật mới, **chung** cho `docAnh` và `chepLoi`:

> Bản đang nạp đã có **cả** cờ ảnh lẫn âm thanh → dùng luôn. Thiếu → đóng (nếu đang có bản) **một lần** rồi nạp bản có
> **cả hai** cờ. Mọi đường chữ sau đó dùng chung bản ấy (như A5 đã làm với bản ảnh).

Chuỗi phải không đóng quá một lần (canh bằng test runtime giả): *Trợ lý → Quét → Nói*, *Trợ lý → Nói → Quét*, *Nói →
Quét → Nói*, *Quét → Trợ lý → Nói*. ⚠️ **RAM bản hai cờ chưa đo** (ảnh riêng 2,93 GB, âm riêng 2,53 GB — Realme CPU) →
mục 9.

### 4.4 Đối chiếu luật kiến trúc

| Luật | Khớp |
|---|---|
| Quét 22 — presentation không cầm CSDL | ✅ micro / Gemma qua datasource + DI |
| Quét 23 — ≤ 1.200 dòng | ✅ Cubit ~1.107 · trang Thêm giao dịch 779 → ~820 · Trang chủ 674 → ~690 |
| Quét 25 — vị trí tệp | ✅ không thêm chủ đề `core/`; **bỏ** miễn trừ `ai_chat/spike/` cùng task xoá spike |
| Quét 16 — `flutter_gemma` một chỗ | ✅ |
| **Quét 26 (mới)** | `speech_to_text` chỉ ở `nghe_android.dart`, `record` chỉ ở `ghi_am.dart`; ca tiền đề "phép quét thấy chính tệp được phép" |
| G88 gạch 2 (bốn trang lớn) · 3 (Entity) · 4 (`core/notification`) · 5 (DI đồng bộ) · 6 (`data/services/`) | ✅ không đụng, không thêm nợ: không trang lớn, không kiểu hàng Drift mới ở giao diện, không tệp mới ở `data/services/` |

### 4.5 Gói, quyền, dọn spike

- `speech_to_text ^7.5.0` và `record ^7.1.1` thành **gói chính thức**; sửa chú thích `pubspec.yaml` dòng 85–87 (đang ghi
  *gói SPIKE*). Không thêm gói.
- Quyền: `speech_to_text.initialize` / `record.hasPermission` tự xin; trạng thái *bị chặn* và mở cài đặt qua kênh
  `flowmoney/micro` (dự án không có `permission_handler`). Test đọc manifest + Kotlin (vùng mù của `flutter test`, bẫy
  7.11).
- **Xoá spike:** `lib/features/ai_chat/spike/` (hai tệp), route `/spike-c4`, nhánh `kSpikeC4` ở nút Quét, `spikeDaPhuongThuc`,
  `test/features/ai_chat/spike_c4_test.dart`. Gỡ **theo `grep`** (13 tệp nhắc tới lúc viết spec, nhiều chỗ chỉ là chú
  thích) — không sửa hàm nào ngoài xoá bí danh / chú thích trỏ về spike. `docHoaDonTuChu`, `DongOcr`… đã ở `domain/`,
  `core/ocr` từ A5 / chia sẻ biên lai.

### 4.6 Stitch — trước mã giao diện

Màn **Thêm giao dịch** với ô Nhập nhanh ở bốn trạng thái (chờ có micro · đang nghe có chữ hiện dần · đang chép lời bằng
AI · đang kiểm / hai chip) và **Trang chủ** với năm nút nhanh. Dự án Stitch `FlowMoney`; người dùng xác nhận trên Stitch
(lượt gọi `timeout` vẫn có thể tạo màn — không gọi lại).

## 5. Bộ 20 câu — test bảng (luật thuần)

Từ spike (soạn 2026-10-01, tên ví / danh mục tài khoản 10). Chạy `docCauGiaoDich` với `now` cố định **2026-10-01**, mỗi câu
**hai dạng**: chữ như người nói, và chữ số như máy nghe trả về. Cột *Mới* đánh dấu chỗ C4 đổi kết quả; *Kiểm* = 
`soTienCanKiem`.

| # | Câu (dạng chữ) | Dạng chữ số | Số tiền | Ô khác | Mới | Kiểm |
|---|---|---|---|---|---|---|
| 1 | Ăn phở bốn mươi lăm nghìn | Ăn phở 45.000 | 45.000 | — | | |
| 2 | Cà phê hai mươi lăm nghìn | Cà phê 25.000 | 25.000 | — | | |
| 3 | Đổ xăng năm chục | Đổ xăng 50 | 50.000 | — | ✓ N2 | ✓ |
| 4 | Gửi xe năm nghìn | Gửi xe 5.000 | 5.000 | — | | |
| 5 | Mua sách một trăm hai mươi nghìn | Mua sách 120.000 | 120.000 | — | | |
| 6 | Tiền điện một triệu hai | Tiền điện 1,2 triệu | 1.200.000 | — | ✓ N1 (chữ) | ✓ (chữ) |
| 7 | Tiền nhà hai triệu rưỡi | Tiền nhà 2,5 triệu | 2.500.000 | — | | |
| 8 | Sửa xe ba trăm rưỡi | Sửa xe 350 | 350.000 | — | ✓ N2 | ✓ |
| 9 | Nhận lương chín triệu | Nhận lương 9 triệu | 9.000.000 | thu · Lương | | |
| 10 | Thưởng tết ba triệu | Thưởng tết 3 triệu | 3.000.000 | thu · Thưởng | | |
| 11 | Hôm qua ăn trưa bốn mươi lăm nghìn | Hôm qua ăn trưa 45.000 | 45.000 | 30/09 | | |
| 12 | Hôm kia đi grab ba mươi lăm nghìn | Hôm kia đi grab 35.000 | 35.000 | 29/09 | | |
| 13 | Ngày năm tháng chín mua sách một trăm hai mươi nghìn | Ngày 5 tháng 9 mua sách 120.000 | 120.000 | 05/09 | ✓ ngày | |
| 14 | Thứ hai đổ xăng năm mươi nghìn | Thứ hai đổ xăng 50.000 | 50.000 | 28/09 | | |
| 15 | Đầu tháng đóng học phí hai triệu | Đầu tháng đóng học phí 2 triệu | 2.000.000 | 01/10 | | |
| 16 | Mua áo hai trăm nghìn bằng MB Bank | Mua áo 200.000 bằng MB Bank | 200.000 | ví *Ví MB Bank* | ✓ ví | |
| 17 | Trà sữa ba mươi nghìn trả bằng MoMo | Trà sữa 30.000 trả bằng MoMo | 30.000 | ví *Ví MoMo* | ✓ ví | |
| 18 | Hôm qua đi chợ một trăm năm mươi nghìn bằng tiền mặt | … 150.000 bằng tiền mặt | 150.000 | 30/09 · *Tiền mặt* | | |
| 19 | Chuyển năm trăm nghìn từ MB Bank sang tiết kiệm | Chuyển 500.000 từ MB Bank sang tiết kiệm | 500.000 | chuyển · *Ví MB Bank* → *Tiết kiệm* | ✓ tiền (chữ) · ví nguồn | |
| 20 | Thu nợ anh Nam năm trăm nghìn | Thu nợ anh Nam 500.000 | 500.000 | — | | |

Ca thêm (chặn N2 đọc nhầm số lượng): *"mua hai mươi quả trứng"* → **không** số tiền · *"mua hai mươi quả trứng ba mươi
nghìn"* → 30.000 · *"mua 2 ly cà phê"* → không · *"đi xe 15 phút"* → không · *"ăn phở 45 bằng tiền mặt"* → 45.000 ✓ Kiểm.

Dạng chữ số ở cột 3 là **giả định** về cách máy nghe trả về (Android có thể trả *"45 nghìn"*, *"45k"*…); phần kiểm thử
(mục 9) ghi lời chép thật, và mọi dạng thật khác bảng thành ca test bổ sung.

## 6. Test tự động (trong phạm vi)

TDD từng task, bản sai có chủ ý cho ca canh xanh-ngay.

- **Luật:** bảng mục 5 (hai dạng × 20 câu + ca số lượng); N1, N2 từng điều kiện đứng sau; ngày bằng chữ / số; ví gọi tắt
  — và không khớp nhầm: tên ví đã bỏ chữ *Ví* chỉ được nhận ở chỗ câu **đang nhắc ví** theo đúng luật `cauNhacViTheoTen`
  hiện có (*"mua sách tiết kiệm"* không chọn ví *Ví tiết kiệm*); chuyển ví bằng chữ; `soTienCanKiem` đúng / sai từng họ.
- **Kiểm chéo:** `chotSoTienCau`; luồng Cubit — khớp · lệch → trống + chip · người dùng đã sửa → bỏ · Huỷ · AI lỗi · câu
  còn ô thiếu → **một** lượt AI.
- **Chọn lối:** bảng 2.2 đủ tổ hợp; lỗi mạng giữa chừng → gợi ý nói lại bằng Gemma.
- **Cubit micro:** chờ → nghe → (chép lời) → điền; quyền từ chối / bị chặn; không lối nào; Huỷ; rời màn khi đang nghe →
  dừng micro + xoá WAV.
- **Runtime:** bốn chuỗi ở 4.3 đóng ≤ 1 lần; `docAnh` không nạp lại khi bản có đủ hai cờ.
- **Giao diện:** micro chỉ Premium; dòng trạng thái; chip; năm nút Trang chủ ở **320 dp font thật** (`test/helpers/font_that.dart`)
  không tràn / không cắt nhãn; `/add?noi=1` tự nghe; Basic bấm Nói → `/premium?quyen=ai_quick_input`.
- **Quét:** 26 mới; quét 25 sau khi bỏ miễn trừ; test đọc manifest main (`RECORD_AUDIO`, `RecognitionService`) và
  `MainActivity.kt` (kênh `flowmoney/micro`).
- Cuối: `flutter test` toàn bộ + `flutter analyze` (mức nền **20**).

## 7. Tài liệu

`docs/GIONG_NOI_FEATURE.md` (mới — trạng thái, quyết định, bẫy, *chưa đo*) · hàng **"Đụng vào giọng nói"** trong `CLAUDE.md`
· mục 14 `PROJECT_CONTEXT.md` · mục 9.44 `AI_EDGE_FEATURE.md` (spike chốt lối, mã spike gỡ) · banner spec này · chú thích
`pubspec.yaml`.

## 8. Rủi ro đã biết

- **RAM bản hai cờ** trên Realme (CPU, swap) — có thể bị giết; chưa đo.
- Chất lượng nghe **giọng thật** của cả hai lối chưa đo (spike chỉ có giọng tổng hợp cho Gemma, Android chưa chạy).
- ColorOS có thể không có dịch vụ nhận dạng của Google / gói tiếng Việt offline → lối Android chỉ chạy khi có mạng.
- N2 có thể đọc nhầm một câu số lượng lọt qua danh sách chữ đứng sau — chặn bởi: chỉ cuối câu / trước chữ ví-ngày, kiểm
  chéo khi có Gemma, và người dùng xem lại trước khi Lưu.

## 9. Ngoài phạm vi lần này — phần kiểm thử (dừng ở đây)

Checklist cho lúc người dùng cầm máy (Realme và/hoặc OnePlus — máy nào cắm đo máy đó):

- [ ] Đọc 20 câu mục 5 bằng giọng thật: lối Android **có mạng**, lối Android **chế độ máy bay** (`onDevice`), lối Gemma —
      bảng *câu đọc · lời chép · ô điền đúng · thời gian*.
- [ ] Mã lỗi thật của `speech_to_text` cho mất mạng / không gói ngôn ngữ → chỉnh hằng ở `chon_loi_nghe.dart` nếu khác.
- [ ] RAM đỉnh bản mô hình hai cờ (PSS + swap) khi Quét rồi Nói và ngược lại; không sập native ở OnePlus GPU.
- [ ] Hộp hỏi quyền micro trên ColorOS; trạng thái *bị chặn* → nút Mở cài đặt.
- [ ] Hàng năm nút Trang chủ trên máy 320 dp thật; màn Thêm giao dịch bốn trạng thái so với Stitch.
- [ ] Thời gian thật của kiểm chéo; chip hiện đúng khi lệch.
- [ ] Sau bảng đo: người dùng quyết giữ hai lối hay bỏ một (gỡ gói của lối bỏ).
