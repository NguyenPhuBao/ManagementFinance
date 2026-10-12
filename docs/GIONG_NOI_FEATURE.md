# Giọng nói nhập giao dịch (C4)

> **Trạng thái (2026-10-12):** **mã xong** — Task 1–15 của kế hoạch `docs/superpowers/plans/2026-10-12-c4-giong-noi-nhap-giao-dich.md`
> (gitignore), `flutter test` toàn bộ **7032** ca (+9 `skip`), `flutter analyze` 20 (mức nền). 🚧 **CHƯA KIỂM THỬ TRÊN MÁY** —
> người dùng dặn dừng trước phần đo trên điện thoại; mọi con số "chưa đo" bên dưới và checklist mục 9 là việc của lúc cầm máy.
> Spec: `docs/superpowers/specs/2026-10-12-c4-giong-noi-nhap-giao-dich-design.md` (khối 🔧 đầu tệp THẮNG thân spec).
> Nửa *chụp hoá đơn* của C4 đã làm ở A5 — `docs/QUET_ANH_FEATURE.md`; tệp này chỉ là nửa **giọng nói**.

## 1. Người dùng thấy gì

- **Ô Nhập nhanh** (màn Thêm giao dịch, đường tạo mới, Premium): có biểu tượng **micro** bên trái nút *Điền*. Basic không có
  micro (ô vốn khoá — *"Chỉ Premium"*).
- Bấm micro → (lần đầu) Android hỏi quyền Micro (từ chối → toast *"Cần quyền micro để nói"*; bị chặn hẳn → toast kèm nút *Mở cài đặt*) → **đang nghe** (viền ô đổi màu, gợi ý thành *"Đang nghe…"*, micro thành nút dừng ■) (lối Android: chữ hiện dần trong ô; lối Gemma: chấm đỏ + số
  giây) → tự dừng khi im ~2 giây / bấm ■ / đủ 20 giây / chưa nói gì sau 6 giây (`kChoTiengDau`) → lối Gemma có thêm dòng *"Đang chép lời bằng AI trên máy…"* + Huỷ →
  câu nằm trong ô và **tự Điền** qua `ThemGiaoDichCubit.dienTuCau` (đúng đường C2). Nghe sai → sửa chữ trong ô, bấm *Điền* lại.
  Không ghi gì tới khi bấm Lưu (bất biến ④ nhóm C).
- **Kiểm chéo số tiền** khi số được đọc bằng dạng nói mới học (*năm chục · một triệu hai · ba trăm rưỡi*) và máy có Gemma: số
  điền ngay, dòng *"Đang kiểm số tiền bằng AI…"* + Huỷ; khớp → dòng biến mất; lệch → ô số tiền **trống** + **hai chip**
  (`KhoiChonSoTien`, số AI trước, số luật sau). Người dùng đã đổi số trước khi AI về → AI không đụng.
- **Nút Nói ở Trang chủ**: hàng nút nhanh thành năm (Thêm thu · Thêm chi · Chuyển · Quét · **Nói**). Bấm → `/add?noi=1` →
  màn Thêm giao dịch mở và nghe ngay. Basic → `/premium?quyen=ai_quick_input`.
- **Không làm:** giọng nói ở màn sửa giao dịch, ở Trợ lý AI, ở form điền từ biến động / ảnh quét. Không lưu âm thanh — WAV của
  lối Gemma nằm ở thư mục tạm và xoá ngay sau khi chép (kể cả lỗi / Huỷ / rời màn).

## 2. Chọn lối nghe — app tự chọn, không công tắc

Người dùng chốt 2026-10-12: **Android trước, Gemma dự phòng**. Hàm thuần `chonLoiNghe` (`transaction/domain/chon_loi_nghe.dart`):

| Tình huống | Lối |
|---|---|
| `uuTienGemma` (lượt trước mất mạng / thiếu gói tiếng Việt) và Gemma sẵn sàng | Gemma |
| Có mạng, Android dùng được | Android, `onDevice: false` (giọng gửi lên dịch vụ nhận dạng của máy — như gõ bằng giọng trên bàn phím) |
| Có mạng, Android không dùng được, Gemma sẵn sàng | Gemma (`chon_loi_nghe.dart`) |
| Mất mạng, Gemma sẵn sàng | Gemma (ghi WAV → chép lời) |
| Mất mạng, Gemma không sẵn sàng | Android, `onDevice: true` |
| Không lối nào dùng được | `null` → toast *"Cần mạng hoặc mô hình AI trên máy để nói"* + nút sang *Cài đặt AI* |

*Gemma sẵn sàng* = `MoHinhTaiVe.daCo() && CongTacAi.doc()` — closure `sanSang` **chép ở năm chỗ** trong
`injection_container.dart` (~851, 863, 870, 880, 914); C4 dùng bản ~880 qua `ChepLoiBangGemma`. Quyền `ai_edge_model` chặn ở
màn Cài đặt AI (không tải, không công tắc), **không** nằm trong `sanSang`. *Có mạng* = `ConnectionMonitor.coMangNgay()` (hỏi `checkConnectivity` ngay, lỗi →
`true`; luồng sự kiện cũ có giãn cách 3 giây nên không dùng được cho việc này).

## 3. Luật đọc câu nói (khối 🔧 spec)

Một đường, không nhánh theo nguồn câu: `dienTuCau(cau)` **không biết** câu từ micro hay bàn phím, mọi luật mới áp cả câu gõ.
Luật **chỉ chọn thêm trong tập `cachDocSoTien`** — không có bộ đọc số thứ hai.

- **N1** — *X đơn vị Y* (*một triệu hai · năm nghìn hai · 1 triệu 2*) → 1.200.000 · 5.200 · 1.200.000. Chỉ chọn khi Y ở **chỗ
  của tiền** (cuối câu, hoặc ngay trước dấu câu / chữ ví · bằng · trả · qua · từ · sang · vào · đến · tới · hôm · ngày · mùng ·
  thứ — lượt soát kế hoạch, người dùng chọn lối A, **đổi thân spec §3.2**). Vòng sửa Task 3 siết: *ngày / mùng / mồng* chỉ tính khi liền sau là chữ **số**; *hôm* chỉ khi liền sau là *qua / nay / kia*; *thứ* chỉ khi liền sau là số hoặc tên thứ (`_dungChoTien`, `doc_cau_giao_dich.dart`). *"tiền điện một triệu hai"* → 1.200.000; *"chi hai
  triệu năm nay"*, *"một triệu hai tiền sách"* → luật để trống, Gemma chọn như trước C4.
- **N2** — số **10–999** không đơn vị (*năm chục · ba trăm rưỡi · bốn mươi lăm · 45*) × 1.000, cùng điều kiện vị trí. Cụm có
  đơn vị tiền (*k · nghìn · tr · củ*) vẫn thắng N1/N2; số một chữ số vẫn là số lượng.
- **Ngày bằng chữ / số:** *ngày năm tháng chín*, *ngày 5 tháng 9*, *mùng năm*. *"tháng này"* nói rõ = tháng hiện tại, **không
  lùi** (người dùng đính chính); luật "tương lai > 7 ngày thì lùi" chỉ cho *ngày / mùng X* **không nêu tháng** (và *dd/mm*).
  *Tháng sau · tháng tới* → không đọc ngày (C2 hỏi AI). Số đứng sau *tháng* là số tiền (*"tháng 3 triệu"*, *3tr*, *3.000.000*)
  thì tiền thắng. *Mùng* chỉ nhận dạng có dấu.
- **Ví gọi tắt** (*bằng MB Bank* khi ví tên *Ví MB Bank*): tên bỏ chữ *Ví* chỉ được nhận **ngay sau** *ví · bằng · qua · từ ·
  sang · vào · đến · tới* — làm ở `doc_cau_giao_dich.dart`, không ở `khop_ten.dart` (nhận ở mọi chỗ thì *"mua sách tiết kiệm"*
  chọn ví *Ví tiết kiệm*). Giới từ so **có dấu** khi câu có dấu.
- **Ba lỗi sẵn có (có từ trước C4) đã sửa cùng lượt:** (1) *"1 triệu 2"* luật đọc **1.000.000 im lặng** (`_mauSoDonVi` khớp
  *"1 triệu"*, `_mauTrieuLe` chỉ nằm trong `cachDocSoTien`); (2) *"từ"* bỏ dấu thành `tu` = *tư* (4) → câu chuyển ví bằng chữ
  *"chuyển năm trăm nghìn từ MB Bank sang tiết kiệm"* mất cả số tiền (nay so chữ số chữ **có dấu**); (3) *"quả"* bỏ dấu là `qua`,
  trùng *"qua"* (trả qua ví). Thêm: `_truocLaNam` — *"anh Nam 500.000"* từng mất tiền (lỗi từ `20ee096d`); mốt/bẩy từng chép tay.
- **Lan sang C3:** lệnh tạo ở màn Trợ lý dùng chung `chonSoTienTrongCau` → N1/N2 áp luôn (*"đặt ngân sách ăn uống 2 triệu 5"*
  → 2.500.000). Cố ý; C3 không có cờ "cần kiểm".
- **Cảnh báo nhiều số tiền** (`kCanhBaoNhieuSoTien`): khi số cụm chắc + nói ≥ 2 → chỉ điền một khoản và báo. Có thể nổ oan
  với *"ăn phở 45k quận 10"* (đánh đổi với *"45k, gửi xe 10"*; review cuối xét).
- Bộ 20 câu của spec mục 5: `test/features/transaction/domain/bo_20_cau_noi_test.dart` (hai dạng: chữ như người nói, chữ số
  như máy nghe trả về); luật chi tiết: `doc_cau_noi_test.dart`, `ngay_trong_cau_test.dart`.
- **Giới hạn đã chấp nhận (P16):** (a) *"ngay"* không dấu mở đầu mẫu *ngày X tháng Y* (*"trả ngay 5 tháng 9…"* đọc thành
  ngày 05/09 — `ngay_trong_cau.dart`, nhánh `t == 'ngay'`); (b) *"ngày X tháng Y năm Z"* bỏ qua Z (năm luôn theo luật hiện có).
  Minor hoãn của Task 5 (chưa sửa, hiếm): *"mùng 2.9"* (dd.mm) không ra ngày; *"nghỉ mùng 5,6 tháng 10"* (liệt kê hai ngày)
  → ngày null; *"tháng 300"* → 05/10 kèm ghi chú "tháng 300".
- **Giả định P18:** `hasPermission()` của `record` mặc định `request: true` nên **XIN quyền**. `KenhMicro.biChan` (qua
  `NguonGiongNoi.micro`) gọi **TRƯỚC** lần xin đầu thì trả **true** — chưa cấp ∧ Android chưa từng hỏi nên
  `shouldShowRequestPermissionRationale` = false → báo "bị chặn" oan (`MainActivity.kt`, nhánh `biChan`). Cubit tránh được vì
  gọi `ghiAm.coQuyen()` (xin quyền) trước, `biChan` chỉ sau khi bị từ chối (`nghe_giong_noi_cubit.dart`, `_batDau`).

## 4. Kiểm chéo số tiền

`KetQuaDocCau.soTienCanKiem` = số tiền đến từ N1/N2. `chotSoTienCau(luat:, ai:)` → `ChotTong` (không dùng lại `chotTongQuet`
của OCR). Số AI đi qua **cùng lưới C2** — `soTienAiHopLe(cau, ai, now)` (tách từ `docCauGiaoDich`, một định nghĩa): số ∈
`cachDocSoTien`, nên "lệch" luôn là hai cách đọc thật của cùng một câu. Cubit: câu còn ô thiếu → dùng luôn kết quả AI của C2
(không gọi hai lần); ngược lại điền luật ngay rồi một lượt `DocCauBangAi.doc` ở nền (`dangKiemSoTien`). **Người dùng thắng:**
chỉ áp khi `chuoiSoTien` vẫn bằng chuỗi luật đã điền. Khi lệch, tóm tắt "Đã điền" bỏ phần số tiền (P7).

## 5. Gemma chép lời, một bản mô hình hai cờ

- Prompt `kPromptChepLoi` **giữ nguyên chữ của spike** (*"Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về
  câu ấy, không giải thích."*) — đổi chữ là mất điểm đo duy nhất đang có (spike: số đúng, chữ sai *phở → vợ*). Kết quả cắt khoảng
  trắng, bỏ ngoặc kép / chấm cuối thừa; rỗng → *"Không nghe rõ — nói lại"*.
- `SlmRuntime` giữ **một** bản mô hình mang **cả** cờ ảnh lẫn âm thanh, dùng chung cho `docAnh` (A5), `chepLoi` (C4) và đường
  chữ. Quyết định nạp là hàm thuần `quyetDinhNap` (`ai_edge/domain/nap_da_phuong_thuc.dart`); phần điều phối nạp là
  `BoNapMoHinh` (`ai_edge/data/bo_nap_mo_hinh.dart`).
- Tuần tự hoá ở **hai** tầng: `BoNapMoHinh` tuần tự hoá **NẠP** (hàng đợi nối chuỗi — mỗi lượt tính lại `quyetDinhNap` trên trạng thái mới của lượt trước; bộ đếm huỷ → `LuotNapBiHuy`; `bo_nap_mo_hinh.dart`);
  `ChepLoiBangGemma` (singleton) tuần tự hoá lượt **CHÉP** toàn cục, và `huy()` huỷ cả lượt đang xếp hàng.

## 6. Tệp và test

| Tệp | Vai trò | Test |
|---|---|---|
| `transaction/data/datasources/nghe_android.dart` | **duy nhất** import `speech_to_text`; `NgheAndroidThat` (singleton mỗi tiến trình) | chỉ quét 26 — `NgheAndroidThat` chưa có test; hợp đồng một lượt canh ở `luot_nghe_test` |
| `transaction/data/datasources/luot_nghe.dart` | chuẩn hoá một lượt nghe: chữ tạm rồi **ĐÚNG MỘT** kết thúc; lỗi thắng `done`; `kChoLoiSauDone` = 300 ms | `luot_nghe_test` |
| `transaction/data/datasources/ghi_am.dart` | **duy nhất** import `record`; WAV 16 kHz mono vào thư mục tạm | quét 26 |
| `transaction/data/datasources/kenh_micro.dart` + `MainActivity.kt` | kênh `flowmoney/micro`: `biChan`, `moCaiDat` | `giong_noi_noi_day_test` |
| `transaction/data/nguon_giong_noi.dart` | cổng DI: `donTepGiongNoiSot`, `tepGiongNoiMoi`, quyền | `don_tep_giong_noi_sot_test` |
| `transaction/data/chep_loi_bang_gemma.dart` | gọi `SlmRuntime.chepLoi`; hàng đợi chép toàn cục | `chep_loi_bang_gemma_test` |
| `transaction/data/dong_hang_bien_dong.dart` | `dongHangBienDong`, `dongHangChuyenKhoan` dời khỏi Cubit (chừa chỗ, §4.2 spec) | `dong_hang_bien_dong_test` |
| `transaction/domain/chon_loi_nghe.dart` | chọn lối, hằng mã lỗi, `kThuGemmaLuotSau`, câu thông báo | `chon_loi_nghe_test` |
| `transaction/domain/do_im_lang.dart` | `BoDoIm` (dừng khi im), `kNguongCoTieng` −35 dBFS, `kNgheToiDa` 20 s | `do_im_lang_test` |
| `transaction/domain/chep_loi.dart` · `chot_so_tien_cau.dart` | chuẩn hoá lời chép; `chotSoTienCau` | `chep_loi_test`, `chot_so_tien_cau_test` |
| `transaction/domain/doc_cau_giao_dich.dart` · `core/utils/ngay_trong_cau.dart` · `so_bang_chu.dart` | N1, N2, ngày, ví gọi tắt, `soTienAiHopLe` | `doc_cau_noi_test`, `bo_20_cau_noi_test`, `ngay_trong_cau_test` |
| `transaction/presentation/bloc/nghe_giong_noi_cubit.dart` (+ `_state`) | máy trạng thái micro (**Cubit riêng**, không vào `ThemGiaoDichCubit`); `kHanNgheAndroid` = `kNgheToiDa` + 5 s | `nghe_giong_noi_cubit_test` |
| `transaction/presentation/bloc/them_giao_dich_cubit.dart` | kiểm chéo (3.4 spec): `luaChonTienCau`, `dangKiemSoTien`, `huyKiemSoTien` | `them_giao_dich_kiem_cheo_test` |
| `transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart` · `dong_dang_nghe.dart` | nút micro; dòng đang nghe / chép lời / kiểm | `nhap_nhanh_test`, `nhap_nhanh_micro_hep_test` |
| `home/presentation/widgets/hang_nut_nhanh.dart` | hàng năm nút nhanh, nút Nói | `hang_nut_nhanh_test`, `trang_chu_gon_test` |
| `ai_edge/domain/nap_da_phuong_thuc.dart` · `ai_edge/data/bo_nap_mo_hinh.dart` | luật nạp một bản hai cờ; tuần tự hoá nạp | `nap_da_phuong_thuc_test`, `bo_nap_mo_hinh_test` |
| `core/router/app_router.dart` | `/add?noi=1` (**query, không `extra`** — `extra is String` là chiều tiền đặt sẵn) | `nhap_nhanh_test` có ca dựng trang với `batDauNghe`; phép đọc `queryParameters['noi']` (`app_router.dart`) chưa có ca |
| `AndroidManifest.xml` (main) | `RECORD_AUDIO`, `<queries>` `RecognitionService` (dời từ manifest debug) | `giong_noi_noi_day_test` |
| **Test quét 26** `transaction/chi_mot_noi_import_giong_noi_test.dart` | `speech_to_text` chỉ ở `nghe_android.dart`, `record` chỉ ở `ghi_am.dart`; có ca tiền đề | — |

Spike đã **gỡ** (C4 Task 2): `lib/features/ai_chat/spike/`, route `/spike-c4`, nhánh `kSpikeC4`, `spikeDaPhuongThuc`; miễn trừ
quét 25 cho `ai_chat/spike/` đã rỗng. Gói `speech_to_text ^7.5.0` và `record ^7.1.1` thành **gói chính thức**.

## 7. ⚠️ Chốt hỏng-im-lặng — phá thì sao

- **Thứ tự sự kiện của `speech_to_text` 7.5.0** (đọc mã, chưa đo): lỗi khi **chưa có chữ** thì `done` tới **TRƯỚC** `error`; có
  chữ tạm thì chỉ `error`, không `done`. Bỏ `LuotNghe` (hoặc cho `done` đi thẳng) → lỗi mạng bị đọc là "xong, không có gì" →
  người dùng thấy *"Không nghe rõ"* thay vì được gợi ý nói lại bằng Gemma; và một lượt có thể kết thúc **hai lần**.
  `kChoLoiSauDone` 300 ms **chưa đo** — máy chậm hơn thì vẫn mất lỗi.
- **Một bản mô hình HAI cờ, đóng ≤ 1 lần mỗi tiến trình.** OnePlus 13R GPU **sập native** ở lần đóng thứ hai (A5). Quay về
  luật cũ "từ chối bản có âm thanh" → chuỗi *Quét → Nói → Quét* đóng hai lần → sập, và `flutter test` không thấy (runtime giả).
  Canh bằng `quyetDinhNap` + `BoNapMoHinh` (chuỗi Trợ lý/Quét/Nói đủ thứ tự).
- **Nút Điền khoá khi micro không ở `cho`**; bắt đầu micro thì **huỷ Điền / kiểm chéo bằng AI trước** (`huyDocAi`,
  `huyKiemSoTien`) — chỉ có **một** mô hình, hai lượt chồng nhau là lượt AI bị cắt hoặc micro trễ.
- **`_dungGhi` chỉ xoá tệp của lượt mình** (chụp vào biến cục bộ trước `await chep`) — đọc trường `_tep` sau `await` là xoá nhầm
  WAV của lượt mới (Gemma huỷ chậm ~5 s) → "không nghe rõ" oan.
- **Hint ô Nhập nhanh khi có micro là `'phở 45k'`.** Đo: `'phở 45k tiền mặt'` không vừa ô có micro ở 320 / 300 dp ×1,1.
  ⚠️ Hệ quả: hint ngắn áp ở **mọi** bề rộng khi Android Premium (luôn có micro), mất ví dụ có tên ví mà G84 sinh ra; ca G84
  "ví dụ phải nêu ví" dựng không `giongNoi` nên xanh giả — cần quyết ở review cuối.
- **`initialize` của `speech_to_text` chỉ nhận callback lần đầu** → `NgheAndroidThat` là **một đối tượng mỗi tiến trình** (DI
  singleton); dựng cái thứ hai thì callback của nó **im lặng không bao giờ gọi**.
- **`luc` của `BoDoIm` = số mẫu × `kNhipBienDo` (100 ms)**, không phải đồng hồ tường. Bộ ghi phát mẫu chậm / dồn thì "im 2 giây"
  lệch thật; ngưỡng −35 dBFS chưa đo.
- **`hasPermission()` của `record` mặc định `request: true`** (P18) → nó **XIN quyền**; `KenhMicro.biChan` chỉ đúng SAU một
  lần xin bị từ chối. Gọi `biChan` trước lần xin đầu → **true** (báo "bị chặn" oan).
- **`notListening` đến TRƯỚC chữ cuối** của `speech_to_text`: chốt lượt nghe ở đó là lấy chữ tạm thay chữ cuối. Nên
  `NgheAndroidThat` chỉ chốt ở `SpeechToText.doneStatus` (`nghe_android.dart`, `onStatus`) — đổi sang `notListening` là câu
  nói bị cụt chữ cuối, `flutter test` không thấy (bản giả).
- **RAM bản hai cờ chưa đo** (ảnh riêng 2,93 GB, âm riêng 2,53 GB — Realme CPU): một bản mang cả hai có thể bị hệ điều hành giết.
- **`donTepGiongNoiSot` xoá mọi `giong_noi_*.wav` ở thư mục tạm.** `NguonGiongNoi` là singleton: hai trang `/add` cùng sống
  (deeplink đè form đang ghi lối Gemma) thì trang sau xoá WAV đang ghi của trang trước → "không nghe rõ". Chặn rẻ chưa làm:
  chỉ xoá tệp cũ hơn `kNgheToiDa` + biên.
- **`ChepLoiBangGemma` onTimeout chờ `moHinh.huy()` KHÔNG giới hạn** — `stopGeneration` native treo thì hàng đợi chép toàn cục
  kẹt suốt tiến trình (đáng sửa trước gộp; hiếm).
- **`"quả"` bỏ dấu = `qua`**: chữ đứng sau con số so **có dấu** (N2). Gõ không dấu hoàn toàn vẫn nhận.
- **Quét 23:** Cubit form 1.132 dòng (trần 1.200, còn 68) — thêm logic là phải chừa chỗ trước.
- Chuỗi mã lỗi của gói (`kLoiMatMang`, `kLoiKhongCoGoi`…) theo **tài liệu gói, chưa đo** — sai chuỗi thì mọi lỗi rơi `loiChung`.

## 8. Lệch Stitch đã biết — chờ người dùng quyết (KHÔNG sửa trong C4)

- Màn **`d696e81e4d984bb9bf7b4fdd2afca517`** (Thêm giao dịch, ô Nhập nhanh): màu đỏ `expense` thay `error`; hint thay badge
  "Đang nghe…"; nút ■ là icon; trạng thái 3 (đang chép lời / kiểm) hai dòng **loại trừ nhau** còn Stitch vẽ cùng lúc; khối hai
  chip nằm ngoài thẻ; thiếu tag "Giọng nói & Gõ".
- Màn **`c8f09f19e73a4c99a7eaa8ef8adcdd1b`** (Trang chủ, năm nút nhanh): *Thêm thu* nền đậm (Stitch trắng viền); biểu tượng
  khác (arrow_downward / arrow_upward / qr_code_scanner / mic vs wallet / payments / document_scanner / mic_none); khoảng cách
  nhãn 10 vs 6; `Expanded` vs `justify-between`. Chữ ×1,3 ở 320 dp nhãn "Thêm thu" co 0,740.

## 9. Checklist kiểm thử trên máy (chưa làm)

Chép nguyên mục 9 spec (Realme và/hoặc OnePlus — máy nào cắm đo máy đó):

- [ ] Đọc 20 câu mục 5 bằng giọng thật: lối Android **có mạng**, lối Android **chế độ máy bay** (`onDevice`), lối Gemma —
      bảng *câu đọc · lời chép · ô điền đúng · thời gian*.
- [ ] Mã lỗi thật của `speech_to_text` cho mất mạng / không gói ngôn ngữ → chỉnh hằng ở `chon_loi_nghe.dart` nếu khác.
- [ ] RAM đỉnh bản mô hình hai cờ (PSS + swap) khi Quét rồi Nói và ngược lại; không sập native ở OnePlus GPU.
- [ ] Hộp hỏi quyền micro trên ColorOS; trạng thái *bị chặn* → nút Mở cài đặt.
- [ ] Hàng năm nút Trang chủ trên máy 320 dp thật; màn Thêm giao dịch bốn trạng thái so với Stitch.
- [ ] Thời gian thật của kiểm chéo; chip hiện đúng khi lệch.
- [ ] Sau bảng đo: người dùng quyết giữ hai lối hay bỏ một (gỡ gói của lối bỏ).

**Thêm từ lượt soát:**

- [ ] RAM bản hai cờ (nhắc lại ở trên, nhưng đo cả chuỗi *Trợ lý → Nói → Quét* và *Nói → Quét → Nói*, đếm số lần đóng).
- [ ] Cờ âm thanh có **vô hại với đường chữ** (cùng một bản mô hình giờ phục vụ cả Trợ lý, Nhập nhanh, C3): tốc độ, bộ nhớ,
      chất lượng câu trả lời có tụt không.
- [ ] Prefill âm thanh **dài nhất** (20 giây) nằm trong trần `maxTokens` 4096 (nếu vỡ: `FAILED_PRECONDITION` như bẫy 4.29).
- [ ] Chuỗi mã lỗi `speech_to_text` thật (đủ cả `error_insufficient_permissions`, `error_server_disconnected` — chưa có ca).
- [ ] Ngưỡng `kNguongCoTieng` = −35 dBFS ở phòng ồn / yên; nhịp `kNhipBienDo` 100 ms của bộ ghi thật.
- [ ] Nhịp `kChoLoiSauDone` (300 ms) đủ để lỗi thắng `done` trên máy chậm.
- [ ] `ChepLoiBangGemma.huy()` **giữa** `record.start`; `dung()` ném lỗi thì micro có kẹt không (`ghiAm.huy()` best-effort).
- [ ] Hai trang `/add` cùng sống (deeplink `/add?noi=1` đè form đang ghi Gemma): `donTepGiongNoiSot` có xoá WAV đang ghi không.
- [ ] Chữ lớn ×1,3 ở 320 dp: nhãn "Thêm thu" co 0,740 có đọc được không; hint `'phở 45k'` có vừa.
- [ ] "Cảnh báo nhiều số tiền" có nổ oan với câu nói tự nhiên (*"ăn phở 45k quận 10"*) không.
