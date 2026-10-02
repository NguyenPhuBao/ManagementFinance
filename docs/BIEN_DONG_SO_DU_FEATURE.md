# Đọc biến động số dư trên máy (D1) — tài liệu bàn giao

> **Cập nhật 2026-10-02:** thêm đường **chia sẻ biên lai** (mục **7**) — bù cho lúc app ngân hàng không đăng thông báo
> biến động. Mã xong, nghiệm thu Realme với biên lai MB Bank thật; còn bản release, đăng xuất, MoMo / ZaloPay.

> **Trạng thái 2026-09-30 tối:** ✅ **xong mã + nghiệm thu hai máy thật** — OnePlus 13R (debug rồi release) và **Realme
> RMX2205** (debug, mục 5b: tin **MB Bank** cả hai chiều qua đường thật, bản sửa chip `802dcd2` đạt). Lượt Realme lộ **bốn
> lỗi**, đã sửa cùng tối (`104a1da` gộp nhầm hai lần chuyển · `3456b69` tóm tắt nhóm rỗng · `bf17877` "sắp cạn" ví mới ·
> `31302d0` gợi ý chạy nền) và **đo lại đạt cả bốn** trên Realme. Spec
> `docs/superpowers/specs/2026-09-28-d1-doc-bien-dong-so-du-design.md`; kế hoạch (gitignore)
> `docs/superpowers/plans/2026-09-28-d1-doc-bien-dong-so-du.md` — nhật ký từng task ở khối *Soát với mã 2026-09-30*.
> Backend duyệt ở `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` (bắt buộc màn xin đồng ý);
> hai ví điện tử báo ở `DA-XONG/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`.

## 1. Tính năng làm gì

Ngân hàng / ví điện tử bắn thông báo *"biến động số dư"* lên máy. FlowMoney **đọc thông báo đã hiện trên máy** (không API,
không liên kết tài khoản, không `READ_SMS`), rồi **mời người dùng ghi** giao dịch ấy bằng một form đã điền sẵn. App
**không tự tạo giao dịch** — người dùng bấm ✓ (bất biến ④ nhóm C). Chỉ Android.

Luồng người dùng:
1. *Cá nhân → Cài đặt thông báo → Tự động hoá giao dịch → Biến động số dư*. Bật lần đầu → **màn xin đồng ý**
   (Stitch `bed4d292…`) → *Đồng ý và mở Cài đặt* → cấp quyền *Truy cập thông báo* trong Cài đặt hệ thống.
2. Tin ngân hàng tới → thông báo tóm tắt *"Có N biến động số dư mới — chạm để ghi"* (**không số tiền**).
3. Chạm tóm tắt, hoặc thẻ *"Có N biến động chưa ghi"* ở Sổ giao dịch → trung tâm thông báo lọc sẵn nhóm *Biến động*.
4. Chạm một dòng → form Thêm giao dịch điền sẵn (Stitch `52d9d2ef…`) → **Lưu** hoặc **Bỏ qua**. Cả hai xoá dòng ấy.

## 2. Kiến trúc

```
App ngân hàng / ví hiện thông báo
  → BienDongListenerService.onNotificationPosted                       (Kotlin)
      [debug: Log.d BienDongThu "gói | hình dạng đã che" — MỌI thông báo]
      cờ SharedPreferences("bien_dong").bat ? → gói ∈ DANH_SACH_TRANG ? → không GROUP_SUMMARY
      → không OTP → có số tiền (±số | số + đ/₫/VND) → nối JSON {goi,tieuDe,noiDung,luc,khoa} vào files/bien_dong_cho.jsonl
      → notify(ID 20260930, kênh flowmoney_bien_dong, tóm tắt không số, extra bien_dong=1)
  → NotificationScanner.start / resumed → NhapBienDong.nhap(idaccount)   (Dart)
      datBat(docBienDong của tài khoản) → rename .dang_nhap → docTinBienDong theo nguồn
      → gộp trùng (mã GD | vân tay số dư khác → KHÔNG trùng | cùng tiền + chiều ≤ 5 phút)
      → AppNotifications loại 20 (deeplink /add?…&vt=…&khoa=…)
      → xoá tệp (kể cả khi cờ tắt) → huyTomTat()
  → Sổ giao dịch: TheBienDongChuaGhi (watchDemBienDong) → /notifications?nhom=bienDong
  → MoTuTomTatBienDong (main.dart): moTuThongBao() lúc start + resumed → cùng route, chờ phiên nếu chưa đăng nhập
  → /add?… → dienSanBienDongTuQuery → ketQuaTuBienDong → _dienKetQua (đường điền của C2)
      → Lưu / Bỏ qua → NotificationDao.xoaCung (+ nhớ ví theo nguồn ở lần Lưu đầu)
```

| Tệp | Vai |
|---|---|
| `android/…/BienDongListenerService.kt` | lọc thô, hàng chờ, tóm tắt, `DANH_SACH_TRANG`, chế độ thu mẫu (debug, đã che) |
| `android/…/MainActivity.kt` | kênh `flowmoney/bien_dong`: `coQuyen · moCaiDat · moCaiDatPin · duocChayNen · moTuThongBao · huyTomTat · datBat` |
| `lib/core/notification/kenh_bien_dong.dart` | bọc kênh; `KenhBienDongTrong` cho web / test |
| `lib/features/transaction/domain/doc_tin_bien_dong.dart` | **nơi DUY NHẤT** đọc số tiền trong tin; `kNguonTheoGoi`, `nguonDangDoc` |
| `lib/core/notification/nhap_bien_dong.dart` | nhập hàng chờ, gộp trùng, `datBat` theo tài khoản, `tatDocMay` |
| `lib/core/notification/mo_tu_tom_tat_bien_dong.dart` | cú chạm tóm tắt Kotlin → trung tâm lọc sẵn |
| `lib/features/notification/presentation/pages/dong_y_bien_dong_page.dart` | màn xin đồng ý |
| `lib/features/transaction/domain/dien_san_bien_dong.dart` | query → `KetQuaDocCau`, dòng nguồn, `khoanCoTheDaGhi` |
| `lib/features/transaction/data/vi_theo_nguon_store.dart` | bảng *nguồn + đuôi TK → ví* (`bien_dong_vi:<id>`) |

## 3. Quyết định đã chốt (kèm lý do)

- **Danh sách trắng chỉ gồm gói ĐÃ ĐO trên máy thật** (spec §2 cấm đoán): `com.mbmobile` → MB Bank,
  `com.mservice.momotransfer` → MoMo, `vn.com.vng.zalopay` → ZaloPay (OnePlus 13R, 2026-09-30). Vietcombank, Techcombank,
  BIDV, Tin nhắn **chưa có** — khuôn BIDV / MB / TCB có sẵn từ `docs/AI/Classify.md` §4.3, nhưng gói chưa đo thì chưa vào.
  Hai bảng (Dart `kNguonTheoGoi`, Kotlin `DANH_SACH_TRANG`) khớp **tay** — `bien_dong_noi_day_test` đọc tệp Kotlin để so.
- **Màn đồng ý và dòng trạng thái liệt kê `nguonDangDoc`** (nguồn đang đọc thật) chứ không bảy nguồn Stitch vẽ — người
  dùng chốt 2026-09-30: hứa đọc một nguồn chưa đọc được là sai với chính yêu cầu *"nêu rõ danh sách trắng"* của backend.
- **Công tắc là cờ riêng `docBienDong`, mặc định TẮT**, kèm `dongYBienDong` (tắt không xoá lần đồng ý) — xem mục 5j
  `NOTIFICATION_FEATURE.md`. Chỉ *Đồng ý* mới gọi `datBat(true)`; *Không, cảm ơn* hay Back không bật gì.
- **Cờ Kotlin gắn MÁY, `docBienDong` gắn TÀI KHOẢN** → mỗi lượt nhập (`start` + `resumed`) ghi lại cờ Kotlin theo tài
  khoản đang đăng nhập, đăng xuất thì tắt. Thiếu bước này thì tài khoản B chưa đồng ý vẫn nhận tóm tắt của A.
- **Bộ lọc thô Kotlin**: `±số` **hoặc** `số + đ/₫/VND` — tin MoMo / ZaloPay **không có dấu ±** (chiều nằm ở chữ *"Nhận"*).
- **Lần đầu một cặp nguồn + đuôi TK thì ví TRỐNG** (không phải ví mặc định): để ví mặc định là để bảng *nguồn → ví* học
  nhầm nó ở lần Lưu đầu. Lần sau chọn sẵn; ví đã lưu trữ / xoá coi như chưa nhớ. Ghi ở lần Lưu đầu, không ghi đè.
- **Danh mục** đoán trên **nội dung tin** bằng đúng luật C2 (`doanDanhMucTuGhiChu`: tên → B1 → từ khoá, hợp chiều) —
  **không** cho tin qua cả `docCauGiaoDich` (bộ ấy đọc số tài khoản / ngày trong tin thành số tiền / ngày).
- **Giờ trong tin là giờ giao dịch** — ô ngày hiện `dd/MM/yyyy HH:mm` khi mở từ biến động.
- **Xoá CỨNG hàng loại 20** khi Lưu / Bỏ qua / vuốt — ngoại lệ có chủ ý của nếp xoá mềm (mục 4.3 `NOTIFICATION_FEATURE.md`).
- **Chuyển giữa hai ví của chính mình sinh HAI dòng** (MB chi + MoMo thu) — D1 không ghép cặp.
- **Gộp trùng dùng VÂN TAY SỐ DƯ SAU GD** (`TinBienDong.vanTaySoDu`, SHA-256 cắt 12 hex của `SD:` / `Số dư cuối:` /
  `Số dư: VND`) khi tin không có mã GD: hai bên cùng có vân tay mà khác → **không** trùng. Lý do đo được: Realme
  2026-09-30, chuyển −10.000 đ từ MB hai lần cách 4 phút, tin không có *"Ma GD"* → luật 5 phút gộp làm một, khoản thứ hai
  **mất im lặng**. SMS + app của **cùng** giao dịch mang cùng số dư nên vẫn gộp được. Vân tay cũng vào `dedupeKey` (hai
  giao dịch cùng phút không đè khoá) và `deeplink` (`vt`, để so hàng đã có). ⚠️ Không lưu con số (quy tắc §13.6), nhưng
  cũng **không** phải bảo vệ mật mã — không gian số dư nhỏ, dò ngược được. MoMo / ZaloPay không mang số dư → luật cũ.
- **Gợi ý cho phép chạy nền** (Stitch `2ff589c7…`, người dùng duyệt): hàng *"Tin có thể đến trễ khi app chạy nền"* +
  *Mở cài đặt* → trang thông tin ứng dụng. Chỉ hiện khi đang đọc **và** `isIgnoringBatteryOptimizations` = false; đọc
  lại khi quay về. Không dùng hộp thoại xin miễn tối ưu pin (quyền Play giới hạn). Câu chữ theo tên mục thật trên Realme
  (*"Cho phép hoạt động dưới nền"*), khác bản Stitch một cụm.
- **Chế độ thu mẫu chỉ ở bản debug và chỉ log hình dạng đã che** (chữ số → 9, từ ngoài danh sách cấu trúc → …) — quy tắc
  §13.6 `progress/Client-app.md` cấm log số dư / số TK kể cả lúc phát triển. Bản release không log gì (đo: 0 byte).

## 4. Bẫy

- ⚠️ **Tin đến TRƯỚC lúc bật quyền không bao giờ tới listener** — muốn đo thì bật quyền trước rồi mới chuyển tiền.
- ⚠️ **Logcat `main` của OnePlus chỉ 256 KiB, trôi trong ~30 s**: `adb logcat -G 16M` + ghi liên tục ra tệp ngoài repo.
- ⚠️ **Bản release không `run-as`** — tệp hàng chờ và CSDL chỉ kiểm được ở bản debug; bản release kiểm bằng thứ nhìn thấy.
- ⚠️ **MoMo / ZaloPay KHÔNG bắn thông báo khi chuyển tiền ĐI** — khoản chi bằng số dư ví lọt khỏi D1 (khoản trừ vào ngân
  hàng liên kết thì tin ngân hàng vẫn có). Hướng đã chốt: *chia sẻ biên lai* vào FlowMoney, gộp vào C4.
- ⚠️ **Hai thẻ lối vào (D1 + C1) cùng có làm phần đầu cố định của Sổ giao dịch tràn 89 px** ở 360 × 640 — nay hai thẻ
  cuộn cùng danh sách (`CustomScrollView`). Thêm khối vào trang ấy thì đặt trong vùng cuộn.
- ⚠️ Màn quét cài đặt của OnePlus chặn `adb install` tới khi chạm *Cài đặt* (≈ `1089 476` ở 1264 × 2780).
- ⚠️ **ColorOS (Hans) đóng băng FlowMoney khi ở nền** — callback của listener xếp hàng tới lúc giải băng (bật màn hình /
  mở app); tin **không mất**, chỉ trễ (~84 giây ở lượt đo). Đo đối chứng Realme 2026-09-30: *Mức sử dụng pin → Cho phép
  hoạt động dưới nền* TẮT → đóng băng sau ~12 giây; BẬT → không (2 × 110 giây). Công tắc ấy **chính là** danh sách miễn tối
  ưu pin chuẩn (`dumpsys deviceidle whitelist`), nhưng ⚠️ `cmd deviceidle whitelist +…` **không** bật lại công tắc của
  ColorOS — trả lại phải bấm trên màn. Log: `OplusHansManager … freeze uid: <uid>`.
- ⚠️ **MB Bank đăng tin theo HAI đường**: push từ server (kênh `fcm_fallback_notification_channel`, tag `FCM-…`) và tin
  cục bộ khi app MB đang mở (kênh `NotificationManager`). Cả hai cùng khuôn chữ; tin chiều trừ thêm trường
  `DEN: <tên> - PSP<số>` — tài khoản ĐÍCH, **không** phải mã GD.
- ⚠️ **Bản tóm tắt nhóm của badge không có con thì Realme vẫn hiện nó** thành thông báo rỗng *"Nhắc tài chính"* (OnePlus
  giấu) — đã sửa `3456b69`, xem mục badge `NOTIFICATION_FEATURE.md`.

## 5. Nghiệm thu máy thật — OnePlus 13R, 2026-09-30

| Phép thử | Kết quả |
|---|---|
| Bật lần đầu → màn đồng ý (3 nguồn) → Đồng ý | ✅ `bien_dong.xml bat=true`; quyền có sẵn nên không mở Cài đặt thừa; dòng *Đã cấp quyền — đang đọc 3 nguồn* |
| Tin MoMo thật → hàng chờ + tóm tắt | ✅ 1 dòng gói MoMo; tóm tắt *"Có 1 biến động số dư mới"* không số |
| Chạm → form → Lưu | ✅ giao dịch thu 10.000 đ, `provider = Manual`, `pending`; loại 20 = 0, tệp hàng chờ đã xoá (debug) |
| Lần hai cùng nguồn | ✅ chọn sẵn ví MoMo |
| Bỏ qua | ✅ dòng biến mất, không tạo giao dịch (release) |
| Tắt công tắc → biến động mới | ✅ không tóm tắt (release) |
| Logcat `BienDongThu` bản release | ✅ 0 byte cả buổi |
| Chưa đo | tin **MB Bank** qua đường thật (máy không bắn thông báo MB lượt ấy) · bản sửa chip `802dcd2` trên máy |

Lỗi lộ ra lúc đo, đã sửa: bảng *Chọn ví* tràn 13 px khi 5 ví (`41dfc9c`, có từ trước D1) · chip *Biến động* ngoài mép
phải khi mở trung tâm lọc sẵn (`802dcd2`).

## 5b. Nghiệm thu máy thật — Realme RMX2205 (360 dp, ColorOS), 2026-09-30 tối

Bản debug `39a2d86d…` rồi các bản sửa (`8abfd661…`, `deafeb66…`). Quyền *Truy cập thông báo* cấp mới trên máy này.

| Phép thử | Kết quả |
|---|---|
| Luồng đồng ý + cấp quyền ở 360 dp | ✅ màn đồng ý 3 nguồn không tràn; dòng trạng thái đổi ngay khi quay về |
| Tin **MB Bank +10.000 đ** (app đang mở) | ✅ hàng loại 20 đúng số / chiều / đuôi `262` / giờ trong tin; tóm tắt gỡ sau khi nhập |
| Thẻ *"Có 1 biến động chưa ghi"* → trung tâm lọc sẵn | ✅ **chip *Biến động* nằm trọn trong khung** (`802dcd2` đạt) |
| Form lần đầu cặp MB · 262 | ✅ ví **trống** (tái hiện sạch; một lần ví + danh mục điền sẵn lúc 19:10 là trạng thái sót từ lúc người dùng tạo ví trong form) |
| Lưu | ✅ thu 10.000 đ vào *Ví MB Bank*, giờ 19:04 của tin; hàng loại 20 xoá cứng |
| Tin **MB −10.000 đ** (app ở nền) | ⚠️ trễ ~84 giây vì Hans → gợi ý chạy nền (`31302d0`); lần hai (app không bị băng) bắt ngay |
| Chạm tóm tắt | ✅ mở thẳng trung tâm lọc *Biến động* |
| Lần hai cùng cặp MB · 262 | ✅ chọn sẵn *Ví MB Bank* |
| Hai lần −10.000 đ cách 4 phút | ❌ gộp làm một → sửa `104a1da`; ✅ đo lại: năm lần chuyển thử (20:02–20:20) ra **năm** hàng, kể cả **hai khoản +10.000 đ cùng phút 20:03** (khoá mang vân tay) |
| Bản tóm tắt nhóm rỗng | ❌ *"Nhắc tài chính"* trống → sửa `3456b69`; ✅ đo lại: `badge=40, khay=0`, không đăng |
| Tạo ví 0 đ | ❌ báo ngay *"sắp cạn"* → sửa `bf17877`; ✅ đo lại: *Ví MoMo* 0 đ (chưa giao dịch) không có hàng *"sắp cạn"* |
| Hàng gợi ý pin | ✅ hiện đúng Stitch ở 360 dp, *Mở cài đặt* mở *Thông tin ứng dụng*; máy đã cho chạy nền → ẩn |

## 6. Việc sau D1 (người dùng chốt 2026-09-30)

1. ✅ **Bàn phím số ẩn khi màn Thêm giao dịch mở với số tiền đã có** (xong 2026-09-30 tối, Stitch `b52c0651…`, nghiệm
   thu Realme). Cờ `_hienBanPhimSo` của `add_transaction_page.dart`: tắt khi mở với số tiền (sửa · biến động có
   `soTien`) hoặc khi ô Nhập nhanh điền được số tiền; chạm khối số tiền để đảo — bàn phím **hệ thống** đang mở thì
   chạm là đóng nó và **mở** 16 phím (đảo cờ lúc ấy là tắt phím mà không thấy gì đổi). **Một luật cho nút lưu:** 16 phím
   không trên màn — theo cờ **hoặc** vì bàn phím hệ thống mở (G58) — thì ✓ ở thanh tiêu đề (*Bỏ qua · ✓* ở form biến
   động); trước đó lúc gõ ghi chú không có nút lưu nào. Ẩn theo cờ thì dưới số tiền là *"Chạm để sửa số tiền"* (biểu
   thức gõ dở thì dòng `= tổng` thắng). Ca test: `ban_phim_so_an_test.dart`.
2. ✅ **Gợi ý Chuyển khoản** (xong 2026-09-30 tối, spec `specs/2026-09-30-goi-y-chuyen-khoan-bien-dong-design.md`,
   Stitch `8ae63d90…`, nghiệm thu Realme). ⚠️ Dữ liệu thật lật luật ban đầu: **MoMo không bắn tin nào** khi chuyển với MB
   (cả hai chiều), nên luật *cặp* một mình 0 lần gợi ý — người dùng chốt **cặp + nội dung tin**. Hàm thuần
   `transaction/domain/goi_y_chuyen_khoan.dart`: cặp (khác chiều, cùng tiền, ≤ 5 phút, nguồn khác; hai ứng viên cùng lệch
   → im) rồi nội dung (tin nhắc **đúng một** nguồn khác — `MOMO149…` nhận, `mb` trần không). Thẻ *"Có vẻ là chuyển khoản ·
   Từ MoMo sang MB Bank"* trên form biến động → bấm đổi sang Chuyển khoản, ví phía tin theo luật D1, phía kia đã nhớ →
   ví duy nhất trùng tên nguồn → trống. Lưu: nhớ ví **theo phía** (tin thu thì ví của nguồn tin là ví ĐÍCH — nhớ
   `_selectedWallet` là chọn sẵn sai mãi), xoá cả hàng cặp. Giới hạn: tin MB chiều trừ đã mất phần `DEN: … PSP…` nên
   chuyển **sang** MoMo không nhận ra (3/5 hàng thật được gợi ý). Ca test `goi_y_chuyen_khoan_test.dart`,
   `goi_y_chuyen_khoan_form_test.dart`.
3. ✅ **Chia sẻ biên lai** vào FlowMoney → đọc chữ trên máy → điền sẵn — **mã xong Task 1–10, nghiệm thu Realme với
   biên lai MB Bank thật (2026-10-02)**; chi tiết ở mục **7**. Tách khỏi C4 và làm trước vì người dùng báo chuyển khoản
   ngay trong app ngân hàng thì có lần app ấy không đăng thông báo biến động. Cùng lượt người dùng chọn thêm **nhắc ghi
   sau khi rời app ngân hàng** — bản thiết kế riêng, **chưa viết**.
4. Đo thêm nguồn: Vietcombank, Techcombank, BIDV, Tin nhắn (chế độ thu mẫu bản debug — hình dạng đã che).

## 7. Chia sẻ biên lai (2026-10-02)

> **Trạng thái:** ✅ mã xong Task 1–10 của kế hoạch (`86b7b91` → `ebfb9d98`), nghiệm thu Realme bản debug với **năm**
> lượt chia sẻ biên lai MB Bank thật. ⏳ **Còn lại (Task 11):** bản release · đăng xuất trên máy · vuốt app khỏi Recents
> rồi chia sẻ · MoMo và ZaloPay (chưa có biên lai thật) · người dùng xác nhận màn Stitch. Spec
> `docs/superpowers/specs/2026-10-02-chia-se-bien-lai-design.md`; kế hoạch (gitignore)
> `docs/superpowers/plans/2026-10-02-chia-se-bien-lai.md` — nhật ký thi công ở cuối tệp ấy. Thông báo cho backend:
> `docs/superpowers/backend/CAN-LAM/CLIENT_CHIA_SE_BIEN_LAI.md`.

### 7.1. Vì sao

D1 chỉ đọc thông báo đã hiện trên máy. Đo trên Realme 2026-10-02: sáu lần chuyển từ MB Bank trong buổi, năm lần có
thông báo, **một lần (19:46) không có** — khoản ấy D1 không thấy. MoMo / ZaloPay không bắn tin khi chuyển đi. Android
không cho đọc màn hình app khác; quyền Trợ năng (đọc cả số dư, OTP) và liên kết ngân hàng qua server (nhóm bỏ
2026-09-18) đều bị loại. Còn lại: người dùng tự đưa biên lai bằng nút *Chia sẻ* của app ngân hàng.

### 7.2. Luồng

1. Màn *"Giao dịch thành công"* → *Chia sẻ* → **"Ghi vào FlowMoney"**.
2. Vẫn ở app ngân hàng (người dùng chốt — để còn chuyển tiếp). Toast *"FlowMoney đã nhận biên lai"* + tóm tắt không số
   của D1, N đếm cả tin ngân hàng lẫn biên lai đang chờ.
3. Mở FlowMoney → chữ trên ảnh được đọc → dòng loại 20 trong trung tâm thông báo / thẻ *"Có N biến động chưa ghi"*.
4. Chạm dòng → form điền sẵn, dải nguồn có **ảnh nhỏ** (chạm để xem to) → **Lưu** / **Bỏ qua** → hàng và ảnh bị xoá.

Không cần công tắc *Đọc biến động số dư*, không qua màn xin đồng ý: mỗi ảnh là người dùng tự chia sẻ.

### 7.3. Kiến trúc

```
App ngân hàng: Chia sẻ → "Ghi vào FlowMoney"
  → NhanBienLaiActivity (Kotlin, Theme.NoDisplay — KHÔNG mở MainActivity)
      cờ SharedPreferences("bien_dong").co_phien ? → EXTRA_STREAM là ảnh, ≤ 12 MB, giải mã được ? → ≤ 20 biên lai chờ ?
      → chép vào files/bien_lai/<uuid>.<đuôi> → nối {tep, goi (getReferrer), luc} vào files/bien_lai_cho.jsonl
      → Toast → BienDongListenerService.baoTomTat (đếm CẢ HAI hàng chờ) → finish()
  → NotificationScanner.start / resumed → NhapBienDong.nhap → NhapBienLai.nhap(idaccount)        (Dart, ĐÚNG thứ tự ấy)
      [debug: thuMauBienLai — hình dạng đã che] → rename .dang_nhap
      → DocChuAnh.doc (ML Kit, trên máy) → ghepDongTheoHang → docBienLai(nguồn theo gói)
      → (1) chia sẻ lặp ? xoá ảnh · (2) hàng tin cùng giao dịch chưa có ảnh ? gắn ảnh · (3) hàng mới
      → dọn ảnh mồ côi → huyTomTat()
  → /add?…&anh=…&doc=…&blt=… → DienSanBienDong.anh / cachDoc → dải nguồn có ảnh → Lưu / Bỏ qua → xoaCung + xoá tệp
  → NotificationScanner.stop → datCoPhien(false) → NhapBienLai.donKhiDangXuat
```

| Tệp | Vai |
|---|---|
| `android/…/NhanBienLaiActivity.kt` | nhận `SEND image/*`, chép ảnh, hàng chờ, Toast, tóm tắt; log thu mẫu bản debug (gói, kiểu, kích thước, kiểu lỗi) |
| `lib/core/ocr/` | `DongOcr` + `ghepDongTheoHang`, `tienTrenDong` (dời từ spike C4) · `DocChuAnh` + `DocChuAnhMlKit` · `cheHinhDang` |
| `lib/features/transaction/domain/doc_bien_lai.dart` | chữ trên ảnh → `BienLaiDoc`; mẫu riêng MB Bank, luật chung cho phần còn lại |
| `lib/core/notification/nhap_bien_lai.dart` | `docDongBienLai`, `thuMauBienLai`, lớp `NhapBienLai` |
| `lib/core/notification/kho_bien_lai.dart` | thư mục ảnh: xoá, dọn mồ côi, xoá hết |
| `lib/core/notification/ten_tep_bien_lai.dart` | hằng tên tệp + `tenTepBienLaiHopLe` (Dart thuần) |
| `lib/core/notification/nhap_bien_dong.dart` | `deeplinkBienDong(anh, cachDoc)`, `deeplinkBienLaiChuaDoc`, `anhTuDeeplink`, `gioBienLaiTuDeeplink`, `themAnhVaoDeeplink` |
| `lib/features/transaction/domain/dien_san_bien_dong.dart` | `anh`, `cachDoc`, `dongNguonBienDong`, `dongPhuBienLai` |
| `lib/features/transaction/presentation/widgets/xem_anh_bien_lai.dart` | xem ảnh to |

### 7.4. Quyết định (kèm lý do)

- **Không nhảy sang FlowMoney khi chia sẻ** (người dùng chốt). `Theme.NoDisplay` + `finish()` trong `onCreate`; đo
  Realme: tiêu điểm giữ nguyên ở app đang đứng, Toast hiện.
- **Đọc chữ khi FlowMoney mở**, không phải lúc chia sẻ — lúc chia sẻ hai lối cho ra thứ nhìn thấy y hệt (thông báo
  không mang số), mà lối này để toàn bộ phần đọc ở Dart, test được.
- **Cùng loại 20, cùng tên nguồn với D1** (`nguonCuaGoi` trên gói của app gửi) — trung tâm thông báo, thẻ Sổ giao dịch,
  bảng *nguồn → ví*, gợi ý chuyển khoản dùng nguyên. App gửi không rõ → nguồn `Biên lai`.
- **Biên lai MB Bank KHÔNG có nhãn** (*Số tiền*, *Nội dung*…): mẫu riêng đọc theo vị trí — tiêu đề *"Chuyển tiền thành
  công"* → hàng số tiền → hàng giờ → … → nội dung ngay trên chân *"Giao dịch được xác nhận bởi MB."*. Hàng chữ liền
  số là **tài khoản người nhận** (người dùng xác nhận; ví dụ dạng `PSP…` của ví MoMo) — không làm mã giao dịch, không
  bao giờ thành ghi chú.
- **MoMo, ZaloPay và mọi app khác: luật chung** (nhãn *số tiền* → số có đơn vị đ / VND; không nhãn và không đơn vị thì
  để trống), form ghi *"Đọc từ ảnh — hãy kiểm lại"*. Mẫu riêng cho hai ví thêm khi có biên lai thật.
- **Không đọc ra số tiền vẫn giữ làm khoản chờ ghi** (người dùng chốt): hàng *"Biên lai chưa đọc được · ‹nguồn›"*, form
  số tiền trống, 16 phím hiện, ảnh để nhìn mà gõ.
- **Chia sẻ lặp nhận ra bằng GIỜ IN TRÊN BIÊN LAI (`blt`), không bằng cửa sổ 5 phút** — hai lần chuyển cùng số tiền
  cách vài phút là hai giao dịch thật (đúng lỗi D1 từng vấp trên Realme 30/09). Cửa sổ 5 phút chỉ dùng để ghép biên
  lai với **tin ngân hàng** của cùng giao dịch: ảnh gắn vào hàng tin gần giờ nhất, mỗi hàng một ảnh.
- **`doc` có mặt ⇔ số liệu của hàng đọc từ ảnh.** Hàng tin được gắn ảnh thì **không** có `doc`: form vẫn nói *"Từ
  thông báo MB Bank…"*, ảnh chỉ để đối chiếu.
- **Ảnh xoá khi Lưu / Bỏ qua / đăng xuất / quá 30 ngày**; không đính kèm vào giao dịch. Một luật: ảnh sống khi còn một
  hàng loại 20 hoặc một dòng hàng chờ trỏ tới nó — `NhapBienLai` dọn ảnh mồ côi ở mỗi lượt.
- **Chỉ nhận khi máy có phiên** (cờ `co_phien`, `NotificationScanner` ghi ở `start` / `stop`): hàng chờ gắn máy.
- **`google_mlkit_text_recognition` thành gói chính thức** (người dùng duyệt). Giá: thư viện gốc
  `libmlkit_google_ocr_pipeline.so` **11,1 MB** cho arm64 (6,8 MB armeabi-v7a) + mô hình **1,3 MB** — đo trên APK debug
  2026-10-02. Ba gói spike C4 còn lại vẫn là gói tạm.

### 7.5. Bẫy

- ⚠️ **Tên tệp ảnh đi vào deeplink rồi thành đường dẫn** — mọi chỗ ghép đường dẫn phải qua `tenTepBienLaiHopLe`
  (`KhoBienLai`, `anhTuDeeplink`, `dienSanBienDongTuQuery`).
- ⚠️ **Dọn mồ côi phải tính cả hàng chờ ĐANG CÓ**: Kotlin có thể vừa nhận thêm một biên lai trong lúc lượt nhập đọc
  chữ — quên là xoá ảnh người dùng vừa chia sẻ, im lặng.
- ⚠️ **`NhapBienLai` phải chạy SAU `NhapBienDong`** trong cùng lượt; ngược lại biên lai không bao giờ gắn được vào hàng
  tin của cùng giao dịch. Ca test của `NotificationScanner` canh.
- ⚠️ **`adb shell am start … SEND` không cấp được quyền đọc URI của MediaStore** → `SecurityException` → Toast *"chỉ
  nhận ảnh biên lai"*. Tự thử đường thành công bằng `file://` trong vùng riêng của app (`run-as … cat > cache/x.png`).
- ⚠️ **Sửa mã Dart bằng script Python trong heredoc làm hỏng mọi dấu gạch chéo ngược** (`\b` → ký tự backspace trong
  regex; `'\n'` → xuống dòng thật) — vấp hai lần trong lượt này. Dùng công cụ Edit / Write.
- ⚠️ **`KhoBienLai.xoa` xoá ĐỒNG BỘ** (`deleteSync`): bản `await f.delete()` treo trong widget test (I/O thật không
  chạy dưới FakeAsync) nên Bỏ qua không bao giờ `pop`.
- ⚠️ Ảnh chia sẻ từ MB Bank là ảnh **toàn màn** 1080 × 2400, thẻ biên lai nằm giữa — ảnh nhỏ canh đỉnh chỉ thấy nền.
- ⚠️ **Giới hạn còn lại:** tin ngân hàng của một giao dịch KHÁC, cùng số tiền, đến trong 5 phút quanh một hàng sinh từ
  biên lai (hàng ấy không mang vân tay số dư) sẽ bị `NhapBienDong` coi là trùng. Hiếm — cần hai lần chuyển cùng tiền
  trong 5 phút, một lần chỉ có biên lai, lần kia chỉ có tin — và chưa sửa.

### 7.6. Nghiệm thu máy thật — Realme RMX2205, 2026-10-02 (bản debug)

| Phép thử | Kết quả |
|---|---|
| Android nhận FlowMoney là đích `SEND image/png` | ✅ |
| Chưa có phiên | ✅ Toast *"Đăng nhập FlowMoney để ghi biên lai"*, không tệp, tiêu điểm giữ nguyên |
| Bảng chia sẻ của **MB Bank** có *"Ghi vào FlowMoney"*; vẫn ở MB; có Toast | ✅ (người dùng xác nhận) |
| MB Bank đưa ra thứ gì | ✅ `image/png`, 1080 × 2400, ~1,25 MB; `getReferrer` ra `com.mbmobile` |
| Năm lượt chia sẻ (ba biên lai khác nhau, hai lượt lặp) → mở FlowMoney | ✅ hai biên lai (19:38, 19:44) **gắn ảnh** vào hàng tin MB sẵn có · một (19:46, không có tin) thành **hàng mới**, đọc bằng mẫu MB · hai lượt lặp bị bỏ, còn đúng 3 ảnh |
| Trung tâm thông báo, thẻ *"Có 13 biến động chưa ghi"* | ✅ dòng biên lai nằm cùng danh sách |
| Form từ biên lai (360 dp) | ✅ số tiền, giờ `02/10/2026 19:46`, nội dung đúng với ảnh; dải *"Từ biên lai MB Bank · 02/10 19:46"* có ảnh nhỏ; ví trống (lần đầu của nguồn) |
| Xem ảnh to | ✅ |
| Log thu mẫu | ✅ chỉ hình dạng đã che |

Lỗi lộ ra lúc đo, đã sửa: ảnh nhỏ canh đỉnh chỉ thấy nền (`ebfb9d98`) · thẻ Sổ giao dịch chỉ nói *"từ thông báo ngân
hàng"* (cùng commit). **Chưa đo:** Lưu / Bỏ qua trên máy (giữ nguyên các dòng cho người dùng tự xử lý) · biên lai *chưa
đọc được* trên máy · bản release · đăng xuất · MoMo, ZaloPay.
