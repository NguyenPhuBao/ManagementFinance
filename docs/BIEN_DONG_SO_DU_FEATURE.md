# Đọc biến động số dư trên máy (D1) — tài liệu bàn giao

> **Trạng thái 2026-09-30 tối:** ✅ **xong mã + nghiệm thu hai máy thật** — OnePlus 13R (debug rồi release) và **Realme
> RMX2205** (debug, mục 5b: tin **MB Bank** cả hai chiều qua đường thật, bản sửa chip `802dcd2` đạt). Lượt Realme lộ **bốn
> lỗi**, đã sửa cùng tối (`104a1da` gộp nhầm hai lần chuyển · `3456b69` tóm tắt nhóm rỗng · `bf17877` "sắp cạn" ví mới ·
> `31302d0` gợi ý chạy nền) và **đo lại đạt cả bốn** trên Realme. Spec
> `docs/superpowers/specs/2026-09-28-d1-doc-bien-dong-so-du-design.md`; kế hoạch (gitignore)
> `docs/superpowers/plans/2026-09-28-d1-doc-bien-dong-so-du.md` — nhật ký từng task ở khối *Soát với mã 2026-09-30*.
> Backend duyệt ở `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` (bắt buộc màn xin đồng ý);
> hai ví điện tử báo ở `CAN-LAM/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`.

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
2. **Cặp chi + thu cùng tiền, ≤ 5 phút, hai nguồn khác** → gợi ý mở form *Chuyển khoản* điền sẵn ví nguồn / đích.
3. **Chia sẻ biên lai** ví điện tử vào FlowMoney → đọc chữ trên máy → điền sẵn (gộp C4).
4. Đo thêm nguồn: Vietcombank, Techcombank, BIDV, Tin nhắn (chế độ thu mẫu bản debug — hình dạng đã che).
