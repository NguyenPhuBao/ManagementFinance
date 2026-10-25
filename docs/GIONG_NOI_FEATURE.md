# Giọng nói nhập giao dịch (C4)

> **Trạng thái (2026-10-12):** **mã xong** — Task 1–15 của kế hoạch `docs/superpowers/plans/2026-10-12-c4-giong-noi-nhap-giao-dich.md`
> (gitignore), `flutter test` toàn bộ **7037** ca (+9 `skip`, sau đợt sửa review toàn nhánh 2026-10-12), `flutter analyze` 20 (mức nền).
> ◐ **Nghiệm thu Realme RMX2205CN (CPU) 2026-10-21 tối** — mục **9.1**: cả hai lối chạy được. Lối **Gemma** (tắt mạng) 4 câu,
> lối **Android** (có mạng) 4 câu; kiểm chéo + hai chip đạt; nút Nói ở Trang chủ, hộp hỏi quyền micro đạt. Lượt đo lộ **G102**
> (lối Android tự dừng sau ~2 s; lối Gemma đem bản ghi im lặng đi chép và điền câu lệnh vào ô) và **G103** (Google viết *"mbbank"*
> dính, *"500.000₫"* — ví nguồn trượt, ghi chú sót), cả hai mở và đóng cùng tối. Các mục checklist còn lại ở mục 9.
> 🔧 **Kiểm chéo thu hẹp (người dùng chốt 2026-10-22, mục 4):** Gemma chỉ kiểm số tiền khi câu **còn số tiền khác** ngoài cụm
> luật đã đọc — câu một cụm (*"tiền điện một triệu hai"*, *"đổ xăng năm chục"*) điền ngay, không chờ, không chip. Đường kiểm ở
> nền (dòng *"Đang kiểm số tiền bằng AI…"* + Huỷ) đã **gỡ**: không còn câu nào đi vào nó.
> Spec: `docs/superpowers/specs/2026-10-12-c4-giong-noi-nhap-giao-dich-design.md` (khối 🔧 đầu tệp THẮNG thân spec).
> Nửa *chụp hoá đơn* của C4 đã làm ở A5 — `docs/QUET_ANH_FEATURE.md`; tệp này chỉ là nửa **giọng nói**.

## 1. Người dùng thấy gì

- **Ô Nhập nhanh** (màn Thêm giao dịch, đường tạo mới, Premium): có biểu tượng **micro** bên trái nút *Điền*. Basic không có
  micro (ô vốn khoá — *"Chỉ Premium"*).
- Bấm micro → (lần đầu) Android hỏi quyền Micro (từ chối → toast *"Cần quyền micro để nói"*; bị chặn hẳn → toast kèm nút *Mở cài đặt*) → **đang nghe** (viền ô đổi màu, gợi ý thành *"Đang nghe…"*, micro thành nút dừng ■) (lối Android: chữ hiện dần trong ô; lối Gemma: chấm đỏ + số
  giây) → tự dừng khi im ~2 giây / bấm ■ / đủ 20 giây / chưa nói gì sau 6 giây (`kChoTiengDau`) → lối Gemma có thêm dòng *"Đang chép lời bằng AI trên máy…"* + Huỷ →
  câu nằm trong ô và **tự Điền** qua `ThemGiaoDichCubit.dienTuCau` (đúng đường C2). Nghe sai → sửa chữ trong ô, bấm *Điền* lại.
  Không ghi gì tới khi bấm Lưu (bất biến ④ nhóm C).
- **Kiểm chéo số tiền** khi số được đọc bằng dạng nói mới học (*năm chục · một triệu hai · ba trăm rưỡi*), máy có Gemma, **và
  câu còn số tiền khác** (*"mua 20 quả trứng năm chục"*): số ấy nằm lại trong ghi chú nên màn hỏi Gemma **trước** khi điền (dòng
  *"Đang đọc bằng AI…"* của C2); Gemma chọn số kia → ô số tiền **trống** + **hai chip** (`KhoiChonSoTien`, số AI trước, số luật
  sau); khớp / số AI là bản cụt của cụm luật → điền số luật. Câu một cụm (*"tiền điện một triệu hai"*) **không** hỏi Gemma —
  người dùng chốt 2026-10-22, mục 4.
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
màn Cài đặt AI (không tải, không công tắc), **không** nằm trong `sanSang`. ✅ **Người dùng xác nhận 2026-10-13**: giữ như mã — tài khoản bị hạ xuống Basic mà máy đã có mô hình vẫn rơi về Gemma chép lời (nút micro vẫn chỉ Premium mới có); thân spec §2.2 cũ (tính cả quyền) không áp. *Có mạng* = `ConnectionMonitor.coMangNgay()` (hỏi `checkConnectivity` ngay, lỗi →
`true`; luồng sự kiện cũ có giãn cách 3 giây nên không dùng được cho việc này).

## 3. Luật đọc câu nói (khối 🔧 spec)

Một đường, không nhánh theo nguồn câu: `dienTuCau(cau)` **không biết** câu từ micro hay bàn phím, mọi luật mới áp cả câu gõ.
Luật **chỉ chọn thêm trong tập `cachDocSoTien`** — không có bộ đọc số thứ hai.

- **N1** — *X đơn vị Y* (*một triệu hai · năm nghìn hai · 1 triệu 2*) → 1.200.000 · 5.200 · 1.200.000. Chỉ chọn khi Y ở **chỗ
  của tiền** (cuối câu, hoặc ngay trước dấu câu / chữ ví · bằng · trả · qua · từ · sang · vào · đến · tới · hôm · ngày · mùng ·
  thứ — lượt soát kế hoạch, người dùng chọn lối A, **đổi thân spec §3.2**). Vòng sửa Task 3 siết: *ngày / mùng / mồng* chỉ tính khi liền sau là chữ **số**; *hôm* chỉ khi liền sau là *qua / nay / kia*; *thứ* chỉ khi liền sau là số hoặc tên thứ (`_dungChoTien`, `doc_cau_giao_dich.dart`). *"tiền điện một triệu hai"* → 1.200.000; *"chi hai
  triệu năm nay"*, *"một triệu hai tiền sách"* → luật không chọn, và từ **2026-10-23 (G104)** đưa **hai chip** (2.000.000 ·
  2.500.000 / 1.000.000 · 1.200.000), Gemma **không** lấp ô số tiền — trước đó Gemma chọn và từng có thể điền bản cụt không hỏi.
  Dạng viết chữ chỉ nhận X **1–99** (`_docXBacY`, một định nghĩa cho luật điền, chip và `cachDocSoTien`): *"mười lăm triệu hai"*
  → 15.200.000, *"trả hai trăm nghìn tám"* → chưa rõ (trước 2026-10-23 luật điền 200.800).
- **N2** — số **10–999** không đơn vị (*năm chục · ba trăm rưỡi · bốn mươi lăm · 45*) × 1.000, cùng điều kiện vị trí. Cụm có
  đơn vị tiền (*k · nghìn · tr · củ*) vẫn thắng N1/N2; số một chữ số vẫn là số lượng.
- **Ngày bằng chữ / số:** *ngày năm tháng chín*, *ngày 5 tháng 9*, *mùng năm*. *"tháng này"* nói rõ = tháng hiện tại, **không
  lùi** (người dùng đính chính); luật "tương lai > 7 ngày thì lùi" chỉ cho *ngày / mùng X* **không nêu tháng** (và *dd/mm*).
  *Tháng sau · tháng tới* → không đọc ngày (C2 hỏi AI). Số đứng sau *tháng* là số tiền (*"tháng 3 triệu"*, *3tr*, *3.000.000*)
  thì tiền thắng. *Mùng* chỉ nhận dạng có dấu.
- **Ví gọi tắt** (*bằng MB Bank* khi ví tên *Ví MB Bank*): tên bỏ chữ *Ví* chỉ được nhận **ngay sau** *ví · bằng · qua · từ ·
  sang · vào · đến · tới* — làm ở `doc_cau_giao_dich.dart`, không ở `khop_ten.dart` (nhận ở mọi chỗ thì *"mua sách tiết kiệm"*
  chọn ví *Ví tiết kiệm*). Giới từ so **có dấu** khi câu có dấu. Tên gọi tắt khớp cả dạng **viết dính** (*"từ mbbank"* =
  *MB Bank* — Google viết như thế, G103), vẫn chỉ sau giới từ.
- **Ký hiệu ₫** (*"500.000₫"*, Google viết như thế, G103) là đơn vị như *đ*: `_chuanCau` đổi *₫ → đ* ở đầu vào của cả ba phép đọc
  (`docCauGiaoDich`, `cachDocSoTien`, `chonSoTienTrongCau`).
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

`KetQuaDocCau.soTienDangNoi` = số tiền đến từ N1/N2; `soTienKhac` = cách đọc số tiền **còn sót trong ghi chú** của luật
(`cachDocSoTien(ghiChu)`, bỏ số bằng số luật — số tiền khác mà chưa ô nào dùng); getter **`soTienCanKiem`** = cả hai. Số AI đi
qua **cùng lưới C2** — `soTienAiHopLe(cau, ai, now)` (tách từ `docCauGiaoDich`, một định nghĩa): số ∈ `cachDocSoTien`.
`chotSoTienCau(luat:, ai:, khac:)` → `ChotTong` (không dùng lại `chotTongQuet` của OCR): **hai chip chỉ khi số AI ∈ `khac`**;
số AI khác số luật mà ngoài `khac` là Gemma đọc lại **chính cụm luật** theo cách khác → giữ số luật. Khi lệch, tóm tắt
"Đã điền" bỏ phần số tiền (P7) — chỉ còn số tiền thì bỏ hẳn dòng, còn ô khác thì giữ phần ấy (*"Đã điền: Hôm qua"*); ca canh
đòi đúng tóm tắt (2026-10-22, sau code-review — trước chỉ đòi *"không chứa 50.000"*, để lọt một dòng *"Đã điền: "* cụt).

🔧 **Người dùng chốt 2026-10-22 — thu hẹp quyết định số 5 của spec.** Đo Realme 2026-10-21 (mục 9.1): Gemma đọc *"tiền điện một
triệu hai"* thành **1.000.000** 2/2 lần (cả hai lối) → hai chip oan mỗi lần, sau ~16 s chờ. Phép đo `cachDocSoTien` trên 14 câu
mẫu cho thấy câu một cụm chỉ có hai kiểu: N2 (*năm chục · 45 · ba trăm rưỡi*) — tập cách đọc **chỉ có số luật**, Gemma không thể
tạo chip, lượt chờ là thừa; N1 (*một triệu hai · 1 triệu 2*) — cách đọc khác duy nhất là **bản cụt** X·đơn vị, đúng kiểu sai của
Gemma. Bản cụt không phải ý thật vì luật chỉ chọn N1 khi chữ số lẻ đứng ở chỗ của tiền; ca *"học phí hai triệu năm"* (mỗi năm)
người dùng loại: *sổ ghi một lần trả tiền đã xảy ra, ít khi nói "hàng năm, hàng tháng"*.

- **Không có đường kiểm ở nền.** `soTienCanKiem` ⇒ ghi chú luật còn số tiền ⇒ ở lượt **chỉ có luật** (lượt quyết có hỏi AI)
  `oThieu` có `OThieu.ghiChu` ⇒ C2 hỏi Gemma **trước** khi điền, và Cubit dùng luôn kết quả ấy (`_chotSoTien` nhận kết quả
  lượt luật — số luật và `soTienKhac` không đọc từ kết quả đã lấp AI). Đường cũ *điền luật ngay rồi một lượt `DocCauBangAi.doc` ở nền*
  (`dangKiemSoTien`, `huyKiemSoTien`, dòng *"Đang kiểm số tiền bằng AI…"* + Huỷ ở `ONhapNhanh`) chỉ còn chạy cho câu một cụm —
  đúng những câu thôi kiểm — nên đã **gỡ** cùng ngày. Ca canh bất biến ở `doc_cau_noi_test` (nhóm *soTienKhac*).
- ⚠️ **Tính trên ghi chú, không trên cả câu** — số trong tên ví đã đọc (*"bằng thẻ 365"*) không phải số tiền; tính trên câu
  là Gemma được phép đưa chip rác 365.000 (ca canh trong cùng nhóm; bản sai cấy thử làm 5 ca đỏ).
- ⚠️ **`cachDocSoTien` vẫn giữ bản cụt** — nó là lưới số tiền AI của mọi câu (*"chi hai triệu năm nay"* = 2.000.000 ở câu khác).
  Đường luật bỏ trống *"một triệu hai tiền sách"* (Y không ở chỗ của tiền) từng để Gemma điền 1.000.000 im lặng — ✅ **G104 đóng
  2026-10-23**: luật đưa hai chip `[cụt, dài]` (`KetQuaDocCau.luaChonSoTien`), Gemma không lấp ô số tiền, lời nhắc không đổi
  (mã + test, chưa đo trên máy). Câu trộn dấu *"một triệu tu"* vẫn để Gemma chọn.

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
| `transaction/data/datasources/nghe_android.dart` | **duy nhất** import `speech_to_text`; `NgheAndroidThat` (singleton mỗi tiến trình; nhận `stt` tiêm được cho test) | `nghe_android_test` (gói thật qua kênh giả + `fakeAsync`: chờ tiếng đầu 6 s, có chữ rồi 2 s, chữ sau `notListening` không mất — G102), quét 26; hợp đồng một lượt ở `luot_nghe_test` |
| `transaction/data/datasources/luot_nghe.dart` | chuẩn hoá một lượt nghe: chữ tạm rồi **ĐÚNG MỘT** kết thúc; lỗi thắng `done`; `kChoLoiSauDone` = 300 ms | `luot_nghe_test` |
| `transaction/data/datasources/ghi_am.dart` | **duy nhất** import `record`; WAV 16 kHz mono vào thư mục tạm | quét 26 |
| `transaction/data/datasources/kenh_micro.dart` + `MainActivity.kt` | kênh `flowmoney/micro`: `biChan`, `moCaiDat` | `giong_noi_noi_day_test` |
| `transaction/data/nguon_giong_noi.dart` | cổng DI: `donTepGiongNoiSot`, `tepGiongNoiMoi`, quyền | `don_tep_giong_noi_sot_test` |
| `transaction/data/chep_loi_bang_gemma.dart` | gọi `SlmRuntime.chepLoi`; hàng đợi chép toàn cục | `chep_loi_bang_gemma_test` |
| `transaction/application/dong_hang_bien_dong.dart` | `dongHangBienDong`, `dongHangChuyenKhoan` dời khỏi Cubit (chừa chỗ, §4.2 spec) | `dong_hang_bien_dong_test` |
| `transaction/domain/chon_loi_nghe.dart` | chọn lối, hằng mã lỗi, `kThuGemmaLuotSau`, câu thông báo | `chon_loi_nghe_test` |
| `transaction/domain/do_im_lang.dart` | `BoDoIm` (dừng khi im), `kNguongCoTieng` −35 dBFS, `kNgheToiDa` 20 s | `do_im_lang_test` |
| `transaction/domain/chep_loi.dart` · `chot_so_tien_cau.dart` | chuẩn hoá lời chép; `chotSoTienCau` (chip chỉ khi số AI ∈ `soTienKhac`) | `chep_loi_test`, `chot_so_tien_cau_test` |
| `transaction/domain/doc_cau_giao_dich.dart` · `core/utils/ngay_trong_cau.dart` · `so_bang_chu.dart` | N1, N2, ngày, ví gọi tắt, `soTienAiHopLe`, `soTienDangNoi` / `soTienKhac` / `soTienCanKiem` | `doc_cau_noi_test`, `bo_20_cau_noi_test`, `ngay_trong_cau_test` |
| `transaction/presentation/bloc/nghe_giong_noi_cubit.dart` (+ `_state`) | máy trạng thái micro (**Cubit riêng**, không vào `ThemGiaoDichCubit`); `kHanNgheAndroid` = `kNgheToiDa` + 5 s | `nghe_giong_noi_cubit_test` |
| `transaction/presentation/bloc/them_giao_dich_cubit.dart` | kiểm chéo (3.4 spec, mục 4): `luaChonTienCau`, `_chotSoTien` trên kết quả AI của C2 | `them_giao_dich_kiem_cheo_test` |
| `transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart` · `dong_dang_nghe.dart` | nút micro; dòng đang nghe / chép lời | `nhap_nhanh_test`, `nhap_nhanh_micro_hep_test` |
| `home/presentation/widgets/hang_nut_nhanh.dart` | hàng năm nút nhanh, nút Nói | `hang_nut_nhanh_test`, `trang_chu_gon_test` |
| `ai_edge/domain/nap_da_phuong_thuc.dart` · `ai_edge/data/bo_nap_mo_hinh.dart` | luật nạp một bản hai cờ; tuần tự hoá nạp | `nap_da_phuong_thuc_test`, `bo_nap_mo_hinh_test` |
| `core/router/app_router.dart` | `/add?noi=1` (**query, không `extra`** — `extra is String` là chiều tiền đặt sẵn) | `nhap_nhanh_test` có ca dựng trang với `batDauNghe`; phép đọc `queryParameters['noi']` (`app_router.dart`) chưa có ca |
| `AndroidManifest.xml` (main) | `RECORD_AUDIO`, `<queries>` `RecognitionService` (dời từ manifest debug) | `giong_noi_noi_day_test` |
| **Test quét 26** `transaction/chi_mot_noi_import_giong_noi_test.dart` | `speech_to_text` chỉ ở `nghe_android.dart`, `record` chỉ ở `ghi_am.dart`; có ca tiền đề | — |

Spike đã **gỡ** (C4 Task 2): `lib/features/ai_chat/spike/`, route `/spike-c4`, nhánh `kSpikeC4`, `spikeDaPhuongThuc`; miễn trừ
quét 25 cho `ai_chat/spike/` đã rỗng. Gói `speech_to_text ^7.5.0` và `record ^7.1.1` thành **gói chính thức**.

## 7. ⚠️ Chốt hỏng-im-lặng — phá thì sao

- ✅ **`pauseFor` của `speech_to_text` 7.5.0 tính từ lúc BẮT ĐẦU nghe** (`_lastSpeechEventAt = _listenStartedAt`, chỉ đặt lại khi
  có chữ) — G102, đo Realme 2026-10-21. Bản đầu đặt thẳng `pauseFor: kImDeDung` (2 s): gói tự `stop()` sau ~1,7 s âm thanh, người
  dùng chưa kịp nói, Google trả `NO_SPEECH_DETECTED` → *"Không nghe rõ"*. Nay `listen` với `kChoTiengDau` (6 s, cùng mốc lối
  Gemma), chữ tạm **khác rỗng** đầu tiên thì `changePauseFor(kImDeDung)`. Phía native, `pauseFor` thành
  `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` — bộ hẹn giờ phía Dart vẫn là thứ dừng lượt.
- ✅ **`changePauseFor` NÉM `ListenNotStartedException` khi gói không còn ở trạng thái nghe** — mà `notListening` có thể tới
  trước chữ cuối. Gọi trần trong `onResult` là mất luôn chữ của lượt; bọc `try`, `luot.chu` luôn chạy.
- ✅ **Bản ghi im lặng KHÔNG đem đi chép** (G102): `BoDoIm` dừng vì *chưa nói gì sau 6 giây* (`daCoTieng == false`) → `_dungGhi(coTieng:
  false)` báo *"Không nghe rõ"*, xoá tệp, không gọi Gemma. Đo Realme: Gemma nhận bản ghi rỗng thì **trả lại câu lệnh**, app điền
  nó vào ô và C2 còn tốn ~10 s đọc nó. Bấm ■ thì vẫn chép (ngưỡng −35 dBFS chưa đo mọi máy). Lưới thứ hai: `lamSachLoiChep` trả
  rỗng khi lời chép chứa một mảnh của câu lệnh (`_manhCauLenh`).

- **Thứ tự sự kiện của `speech_to_text` 7.5.0** (đọc mã, chưa đo): lỗi khi **chưa có chữ** thì `done` tới **TRƯỚC** `error`; có
  chữ tạm thì chỉ `error`, không `done`. Bỏ `LuotNghe` (hoặc cho `done` đi thẳng) → lỗi mạng bị đọc là "xong, không có gì" →
  người dùng thấy *"Không nghe rõ"* thay vì được gợi ý nói lại bằng Gemma; và một lượt có thể kết thúc **hai lần**.
  `kChoLoiSauDone` 300 ms **chưa đo** — máy chậm hơn thì vẫn mất lỗi.
- **Một bản mô hình HAI cờ, đóng ≤ 1 lần mỗi tiến trình.** OnePlus 13R GPU **sập native** ở lần đóng thứ hai (A5). Quay về
  luật cũ "từ chối bản có âm thanh" → chuỗi *Quét → Nói → Quét* đóng hai lần → sập, và `flutter test` không thấy (runtime giả).
  Canh bằng `quyetDinhNap` + `BoNapMoHinh` (chuỗi Trợ lý/Quét/Nói đủ thứ tự).
- **Nút Điền khoá khi micro không ở `cho`**; bắt đầu micro thì **huỷ lượt Điền bằng AI trước** (`huyDocAi` — lượt ấy kiểm luôn
  số tiền; đường kiểm nền `huyKiemSoTien` gỡ 2026-10-22) — chỉ có **một** mô hình, hai lượt chồng nhau là lượt AI bị cắt hoặc
  micro trễ.
- **`_dungGhi` chỉ xoá tệp của lượt mình** (chụp vào biến cục bộ trước `await chep`) — đọc trường `_tep` sau `await` là xoá nhầm
  WAV của lượt mới (Gemma huỷ chậm ~5 s) → "không nghe rõ" oan.
- **Hint ô Nhập nhanh khi có micro là `'45k tiền mặt'`** (không micro giữ `'phở 45k tiền mặt'`). Đo (font thật ×1,1, trang
  thật có `giongNoi`): `'phở 45k tiền mặt'` không vừa ô có micro ở 320 / 300 dp; `'45k tiền mặt'` rộng 91,1 dp, ô 120,9 dp
  (320) / 100,9 dp (300) — vừa. Giữ nguyên tắc G84 (ví dụ nêu tên ví); ca G84 "ví dụ phải nêu ví" nay chạy cả có / không
  micro (review toàn nhánh, I2 — bản cũ `'phở 45k'` bỏ ví ở mọi bề rộng Android Premium và ca xanh giả vì dựng không micro). ✅ **Người dùng xác nhận 2026-10-13**: giữ `'45k tiền mặt'`, không đổi theo bề rộng màn.
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
- ✅ **`donTepGiongNoiSot` chỉ xoá `giong_noi_*.wav` cũ hơn `kNgheToiDa` + `kThoiHanChepLoi`** (M2, review toàn nhánh) — hai
  trang `/add` cùng sống thì WAV đang ghi của trang kia còn mới, được giữ.
- ✅ **`stopGeneration()` có hạn `kHanDungSinh` = 2 s** ở `SlmRuntimeThat.huy` / `_PhienThat.huy` (I1): treo thì `huy()` vẫn
  trả (nuốt lỗi + log). Một chỗ phủ C4, C2, A5, Trợ lý. `ChepLoiBangGemma` onTimeout từng dùng `unawaited(moHinh.huy())`; từ
  2026-10-22 nó chỉ huỷ thẻ `HuyLuot` của lượt (đồng bộ — runtime dừng chat ở nền, bẫy 4.60), nên hàng đợi càng không chờ
  engine. Phần native không test được (chỉ ghi lý do); phần hàng đợi có ca `I1` ở `chep_loi_bang_gemma_test` — nay canh
  *"hết giờ không chờ `huy()` toàn cục"* (`huyTreo` treo mãi mà lượt kế vẫn chạy).
- ✅ **`NgheGiongNoiCubit._dungGhi` kiểm lượt ngay trước `gemma.chep`** (M1): Huỷ rơi vào khe đọc tệp không tốn lượt mô hình.
- ⚠️ **M8:** `NguonGiongNoi` đăng ký cả iOS mà `ios/Runner/Info.plist` chưa có `NSMicrophoneUsageDescription` /
  `NSSpeechRecognitionUsageDescription` (dự án chỉ chạy Android).
- **`"quả"` bỏ dấu = `qua`**: chữ đứng sau con số so **có dấu** (N2). Gõ không dấu hoàn toàn vẫn nhận.
- **Quét 23:** Cubit form 1.132 dòng (trần 1.200, còn 68) — thêm logic là phải chừa chỗ trước.
- Chuỗi mã lỗi của gói (`kLoiMatMang`, `kLoiKhongCoGoi`…) theo **tài liệu gói, chưa đo** — sai chuỗi thì mọi lỗi rơi `loiChung`.

## 8. Lệch Stitch — ✅ người dùng chốt 2026-10-16: app theo Stitch

> ✅ **Đã sửa 2026-10-16** (commit `c65092c1`, `796250ce`):
> - **Năm nút** (`c8f09f19…`): chỉ *Thêm chi* nền đặc `#1A1A19` (bỏ gradient), bốn nút còn lại trắng viền `#D5D5CE` + bóng;
>   biểu tượng `arrow_downward` · `arrow_upward` · `sync_alt` · `qr_code_scanner` · `mic`; nhãn cách vòng 6 dp. **Giữ**
>   `Expanded` thay `justify-between` (kiểu Stitch tràn ở 320 dp). Test `hang_nut_nhanh_kieu_test.dart` + ca quét nguồn ở
>   `trang_chu_gon_test.dart`.
> - **Ô Nhập nhanh lúc nói** (`d696e81e…`): nhãn *"Giọng nói & Gõ"* (chờ, Premium có micro) / *"● Đang nghe…"* ở đầu thẻ
>   thay chữ gợi ý; đỏ lỗi `#BA1A1A` cho viền ô · nút dừng ■ (vòng 32 dp nền đỏ 10 % + ô vuông 14 dp) · chấm đang ghi; khối
>   hai chip (`KhoiChonSoTien`) vào TRONG thẻ (tham số `khoiChonSoTien`). **Giữ có chủ ý**: dòng *"Đang ghi âm / chép lời"* và
>   *"Đang kiểm"* hiện LẦN LƯỢT (hai việc nối tiếp); tia sét giữ `#F25F5C` — màn C2 `8afdfe11…` vẽ `#F25F5C`, màn C4 vẽ
>   `#BA1A1A`, hai màn Stitch mâu thuẫn. `KhoiChonSoTien` giữ kiểu (dùng chung D1 / Quét). Test
>   `o_nhap_nhanh_stitch_c4_test.dart` + ca trong thẻ ở `nhap_nhanh_test.dart`.
>
> Bảng lệch gốc giữ bên dưới.


- Màn **`d696e81e4d984bb9bf7b4fdd2afca517`** (Thêm giao dịch, ô Nhập nhanh): màu đỏ `expense` thay `error`; hint thay badge
  "Đang nghe…"; nút ■ là icon; trạng thái 3 (đang chép lời / kiểm) hai dòng **loại trừ nhau** còn Stitch vẽ cùng lúc; khối hai
  chip nằm ngoài thẻ; thiếu tag "Giọng nói & Gõ".
- Màn **`c8f09f19e73a4c99a7eaa8ef8adcdd1b`** (Trang chủ, năm nút nhanh): *Thêm thu* nền đậm (Stitch trắng viền); biểu tượng
  khác (arrow_downward / arrow_upward / qr_code_scanner / mic vs wallet / payments / document_scanner / mic_none); khoảng cách
  nhãn 10 vs 6; `Expanded` vs `justify-between`. Chữ ×1,3 ở 320 dp nhãn "Thêm thu" co 0,740.

## 9.1 Nghiệm thu Realme RMX2205CN (CPU, Premium — tài khoản 10), 2026-10-21 tối

Người dùng đọc câu vào máy; Claude chấm bằng `uiautomator` + logcat. Không bấm Lưu. Bản `bf988d6f…` (trước G102) và `de459fab…`
(sau G102).

**Lối Gemma** (Wi-Fi + dữ liệu tắt → `chonLoiNghe` chọn Gemma), qua nút **Nói** ở Trang chủ và micro ở ô Nhập nhanh:

| Câu đọc | Lời chép | Form | Thời gian |
|---|---|---|---|
| Ăn phở bốn mươi lăm nghìn | *Anh phở 45 nghìn* | 45.000 đ · Ăn uống ✅ (ghi chú *"Anh phở"*) | ghi 9,4 s · chép 5,5 s · C2 gọi AI ~16 s |
| Đổ xăng năm chục | *Đỗ Săng 50* | 50.000 đ ✅ (N2), kiểm chéo khớp · danh mục **Ăn uống** ❌ — B1 học *"Săng"* 3/3 lần trên máy này | chép 3,4 s · kiểm ~16 s |
| Tiền điện một triệu hai | đúng từng chữ | ô trống + **hai chip 1.000.000 · 1.200.000** (luật N1 đúng, Gemma kiểm chéo sai — đúng thiết kế), Hóa đơn | chép 3,4 s · kiểm ~17 s |
| Mua áo hai trăm nghìn bằng MB Bank | đúng từng chữ | 200.000 đ · **Ví MB Bank** · Mua sắm ✅ | chép 3,7 s · C2 ~17 s |

- Mô hình: lần Nói đầu trong tiến trình (đang giữ bản chữ) đóng một lần rồi nạp bản hai cờ — `nạp mô hình xong sau 962 ms (CPU ·
  ảnh · âm thanh)`, không sập. Bản ghi dài nhất 16,3 s chép trong 6,4 s, không vỡ trần token.
- Bấm micro khi đang kiểm chéo / chép → `[SLM] đã huỷ lượt sinh giữa chừng` (ba lần), lượt cũ ra 0 ký tự, không kẹt.
- Ngưỡng −35 dBFS với giọng nói thường cầm tay: lượt nói tự dừng sau 2 s im; lượt im dừng ở giây 6.
- ⚠️ Lượt im lặng (người dùng chưa đọc) trên bản cũ: Gemma trả **nguyên câu lệnh** (*"Chép lại chính xác câu tiếng Việt…"*), app
  điền nó vào ô rồi C2 báo *"Mình chưa đọc được câu này"* → **G102**. Bản sửa: ô trống, không lượt Gemma nào trong log.

**Lối Android** (có mạng; dịch vụ nhận dạng là *Speech Services by Google* `com.google.android.tts`, chạy lai trực tuyến + SODA
trên máy): hộp hỏi quyền micro của ColorOS hiện đúng (*Cho phép khi sử dụng · Chỉ lần này · Từ chối*). Bản cũ tự dừng sau ~1,7 s
âm thanh (**G102**). ⚠️ Một lượt đo bản sửa đọc *"lỗi của máy"* — dịch vụ có `onStartOfSpeech` mà trả 0 giả thuyết, cả Gboard
cũng không nhận — nhưng người dùng lúc ấy cho **Google Dịch phát câu từ chính chiếc Realme**; nói bằng giọng thật thì chạy:

| Câu nói | Google nghe | Form | Ghi chú |
|---|---|---|---|
| Ăn phở bốn mươi lăm nghìn | *ăn phở 45.000* | 45.000 đ · Ăn uống ✅ | luật đọc đủ, điền ngay |
| Đổ xăng năm chục | *đổ xăng 50* | 50.000 đ · Di chuyển ✅ | kiểm chéo ~13 s, khớp |
| Tiền điện một triệu hai | đúng từng chữ | hai chip 1.000.000 · 1.200.000, Hóa đơn | Gemma kiểm chéo đọc sai lần thứ 2/2 (cả lối Gemma) |
| Chuyển năm trăm nghìn từ MB Bank sang tiết kiệm | *…từ **mbbank**…* rồi *…500.000**₫**…* | ví nguồn **Tiền mặt** ❌, ghi chú sót → **G103**; bản sửa: Ví MB Bank → Tiết kiệm ✅ | lượt cuối Google viết đúng *MB Bank* |

Mỗi lượt nghe dừng ~2 s sau chữ cuối (bắt đầu → dừng 5,3–6,6 s). Thêm: ColorOS (HANS) đóng băng `com.google.android.tts` ~8 s sau
một lượt và chặn mạng của nó; một lượt lúc 20:30 không vào trạng thái nghe, kết thúc sau ~20 s với *"Không nghe được — thử lại
sau"* — các lượt từ 20:53 trở đi dịch vụ chạy bình thường (chưa rõ lúc nào được rã băng). Chưa sửa gì cho chuyện này.

⚠️ Bẫy đo: **đừng phát câu mẫu bằng app khác trên CHÍNH máy đang nghe** (Google Dịch…) — bộ nhận dạng nghe thấy tiếng
(`onStartOfSpeech`) nhưng trả rỗng, trông y như lỗi của máy.

## 9. Checklist kiểm thử trên máy

Mục đã đo ở 9.1 đánh dấu tại chỗ. Chép nguyên mục 9 spec (Realme và/hoặc OnePlus — máy nào cắm đo máy đó):

- [ ] Đọc 20 câu mục 5 bằng giọng thật: lối Android **có mạng**, lối Android **chế độ máy bay** (`onDevice`), lối Gemma —
      bảng *câu đọc · lời chép · ô điền đúng · thời gian*. *(◐ 2026-10-21 Realme: lối Gemma 4 câu, lối Android có mạng 4 câu —
      9.1; lối Android chế độ máy bay và 12 câu còn lại chưa đo.)*
- [ ] Mã lỗi thật của `speech_to_text` cho mất mạng / không gói ngôn ngữ → chỉnh hằng ở `chon_loi_nghe.dart` nếu khác.
- [ ] RAM đỉnh bản mô hình hai cờ (PSS + swap) khi Quét rồi Nói và ngược lại; không sập native ở OnePlus GPU.
- [ ] Hộp hỏi quyền micro trên ColorOS; trạng thái *bị chặn* → nút Mở cài đặt. *(◐ 2026-10-21 Realme: hộp hỏi quyền hiện đúng,
      cấp được; nhánh *bị chặn* chưa đo.)*
- [ ] Hàng năm nút Trang chủ trên máy 320 dp thật; màn Thêm giao dịch bốn trạng thái so với Stitch.
      *(2026-10-16 app đã sửa theo Stitch — mục 8. Lúc nói phải thấy: nhãn đỏ "● Đang nghe…" ở góc trên thẻ, viền ô đỏ
      `#BA1A1A`, nút dừng là ô vuông đỏ trong vòng nhạt, hai chip số tiền nằm TRONG thẻ. Lệch có chủ ý: hai dòng "đang
      ghi / chép lời" và "đang kiểm" hiện lần lượt; tia sét `#F25F5C`. Từ 2026-10-22 dòng "đang kiểm" đã gỡ — mục 4.)*
- [x] Thời gian thật của kiểm chéo; chip hiện đúng khi lệch. *(2026-10-21 Realme CPU: ~16–17 s — mở phiên ~3 s + sinh ~13 s;
      "một triệu hai" → chip 1.000.000 · 1.200.000.)* → dẫn tới đợt thu hẹp 2026-10-22 (mục 4).
- [ ] Sau đợt thu hẹp 2026-10-22: *"tiền điện một triệu hai"* điền 1.200.000 **ngay** (không dòng chờ, không chip);
      *"mua 20 quả trứng năm chục"* hiện *"Đang đọc bằng AI…"* rồi điền / hai chip.
- [ ] Sau bảng đo: người dùng quyết giữ hai lối hay bỏ một (gỡ gói của lối bỏ).

**Thêm từ lượt soát:**

- [ ] **CỔNG (đứng đầu):** chạy lại Quét A5 trên OnePlus GPU và Realme CPU với bản mô hình HAI cờ (ảnh+âm), cả khởi động
      lạnh — Quét đã nghiệm thu nay phụ thuộc bản chưa đo; nạp hai cờ hỏng thì chuỗi Nói → đóng → nạp hỏng → Trợ lý nạp bản
      chữ → Nói lại sẽ đóng LẦN HAI (kiểu sập A5).
      *(2026-10-21, **vế Realme CPU đạt**: nghiệm thu A5 trên Realme nạp bản hai cờ — log `[SLM] nạp mô hình xong sau 1249–1476
      ms (CPU … · ảnh · âm thanh)` — cả ở tiến trình mới; 16 lượt quét + chọn danh mục + Nhập nhanh không sập, PSS 3,0–3,26 GB.
      Chưa đo OnePlus GPU, chưa đo chuỗi có Nói. Mục 7 `QUET_ANH_FEATURE.md`; lộ G100 — mô hình nạp thêm bản khi engine dựng
      lại; ✅ G100 đóng cùng ngày, thân ở `CLIENT_APP_KNOWN_GAPS.md`.)*
- [x] Thời gian lượt Gemma đầu tiên trên CPU (nạp chữ + đóng + nạp hai cờ + suy luận) so với trần 60 s (`kThoiHanChepLoi`).
      *(2026-10-21 Realme: đang giữ bản chữ → đóng + nạp hai cờ 962 ms + chép 7,4 s — xa trần; chuỗi *bản chữ → Nói* không sập.)*
- [x] `stopGeneration` có trả về trong `kHanDungSinh` (2 s) không — log `[SLM] đã huỷ lượt sinh giữa chừng` hay `huỷ lượt sinh hỏng`.
      *(2026-10-21 Realme: ba lần "đã huỷ lượt sinh giữa chừng", không lần nào hỏng.)*
- [ ] RAM bản hai cờ (nhắc lại ở trên, nhưng đo cả chuỗi *Trợ lý → Nói → Quét* và *Nói → Quét → Nói*, đếm số lần đóng).
- [ ] Cờ âm thanh có **vô hại với đường chữ** (cùng một bản mô hình giờ phục vụ cả Trợ lý, Nhập nhanh, C3): tốc độ, bộ nhớ,
      chất lượng câu trả lời có tụt không.
- [ ] Prefill âm thanh **dài nhất** (20 giây) nằm trong trần `maxTokens` 4096 (nếu vỡ: `FAILED_PRECONDITION` như bẫy 4.29).
      *(◐ 2026-10-21 Realme: bản ghi 16,3 s chép trong 6,4 s, không vỡ; 20 s chưa đo.)*
- [ ] Chuỗi mã lỗi `speech_to_text` thật (đủ cả `error_insufficient_permissions`, `error_server_disconnected` — chưa có ca).
- [ ] Ngưỡng `kNguongCoTieng` = −35 dBFS ở phòng ồn / yên; nhịp `kNhipBienDo` 100 ms của bộ ghi thật. *(◐ 2026-10-21 Realme,
      phòng yên, giọng thường cầm tay: nói → dừng sau 2 s im; im → dừng ở giây 6. Phòng ồn chưa đo.)*
- [ ] Nhịp `kChoLoiSauDone` (300 ms) đủ để lỗi thắng `done` trên máy chậm.
- [ ] `ChepLoiBangGemma.huy()` **giữa** `record.start`; `dung()` ném lỗi thì micro có kẹt không (`ghiAm.huy()` best-effort).
- [ ] Hai trang `/add` cùng sống (deeplink `/add?noi=1` đè form đang ghi Gemma): WAV đang ghi còn nguyên (đã chặn theo tuổi tệp, M2).
- [ ] Chữ lớn ×1,3 ở 320 dp: nhãn "Thêm thu" co 0,740 có đọc được không; hint `'45k tiền mặt'` có vừa (đo ×1,1 đã vừa; ×1,3 chưa).
- [ ] "Cảnh báo nhiều số tiền" có nổ oan với câu nói tự nhiên (*"ăn phở 45k quận 10"*) không.
