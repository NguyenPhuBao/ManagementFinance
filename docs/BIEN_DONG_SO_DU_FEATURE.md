# Đọc biến động số dư trên máy (D1) — tài liệu bàn giao

> **Cập nhật 2026-10-03:** thêm **nhắc ghi sau khi dùng app ngân hàng** (mục **8**) — quyền *Truy cập dữ liệu sử dụng*,
> dòng *"Chưa thấy giao dịch nào"* trong danh sách *Biến động* + thông báo im lặng; xong 10 task, nghiệm thu Realme debug
> + release. Thẻ Sổ giao dịch đổi chữ thành **"Có N mục chờ ghi"**.

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
3. Chạm tóm tắt, hoặc thẻ *"Có N mục chờ ghi"* ở Sổ giao dịch (chữ cũ *"…biến động chưa ghi"* tới 2026-10-03, mục 8)
   → trung tâm thông báo lọc sẵn nhóm *Biến động*.
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
      → gộp trùng (mã GD | vân tay số dư khác → KHÔNG trùng | hai TIN cùng app không phân biệt được: khoá thông báo
        khác → KHÔNG trùng, cùng khoá ≤ 10 giây → trùng | còn lại cùng tiền + chiều ≤ 5 phút)
      → AppNotifications loại 20 (deeplink /add?…&vt=…&kt=…&khoa=…)
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
- ✅ **2026-10-05 — hai TIN của CÙNG app không phân biệt được (MoMo, ZaloPay) thôi dùng cửa sổ 5 phút** (người dùng
  báo: hai khoản MoMo đến liên tiếp, app chỉ bắt được một). Tin MoMo không mang mã GD lẫn số dư, nên hai lần nhận
  cùng số tiền cách vài phút bị gộp; và khoá trùng tính tới **phút** nên hai tin cùng phút còn bị `insertAllIfAbsent`
  bỏ thêm lần nữa. Luật mới (`trungBienDong`, `kCuaSoCungTin`): hai bên đều là **tin** (không phải biên lai), cùng
  nguồn, không cùng vân tay → trùng chỉ khi là **cùng thông báo app đăng lại** — khoá thông báo Android
  (`StatusBarNotification.key`, băm 12 hex, deeplink `kt`) khác nhau thì KHÔNG trùng; cùng khoá hoặc hàng cũ không có
  khoá thì trùng khi cách ≤ **10 giây**. Khoá trùng của tin không mã, không vân tay tính tới **giây**. Cửa sổ 5 phút
  giữ cho hai KÊNH (SMS + app) và cho biên lai ↔ tin (`dauBienDong(…, tuTin: false)`; hàng có `doc` đọc ngược là
  biên lai). ✅ **Đo OnePlus 13R cùng ngày** (bản debug, log `BienDongThu` nay in thêm `id=… tag=…`): MoMo đăng mọi
  tin với `id=0` nhưng **tag riêng từng tin** (mốc thời gian + mã), nên khoá thông báo luôn khác nhau giữa hai giao
  dịch — kể cả cách < 10 giây. Hai lần nhận 10.000 đ cách 31 giây → **hai** mục chờ ghi (người dùng xác nhận).
  Bản tóm tắt nhóm của MoMo mang tag `…|g:Aggregate_AlertingSection` và nội dung rỗng — bộ lọc thô đã bỏ.
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
   biên lai MB Bank thật (2026-10-02); Task 11 xong 2026-10-03** (debug + release trên Realme, mục **7.7**; còn mở:
   mẫu riêng MoMo / ZaloPay khi có biên lai thật); chi tiết ở mục **7**. Tách khỏi C4 và làm trước vì người dùng báo chuyển khoản
   ngay trong app ngân hàng thì có lần app ấy không đăng thông báo biến động. Cùng lượt người dùng chọn thêm **nhắc ghi
   sau khi rời app ngân hàng** — ✅ **xong 2026-10-03** (10 task, nghiệm thu Realme debug + release), mục **8**. Còn
   mở: đo chuyển thật **có** tin (không được nhắc) và Doze (tắt màn, rút cáp).
4. Đo thêm nguồn: Vietcombank, Techcombank, BIDV, Tin nhắn (chế độ thu mẫu bản debug — hình dạng đã che).

## 7. Chia sẻ biên lai (2026-10-02)

> **Trạng thái:** ✅ **xong trọn kế hoạch 11 task** — Task 1–10 (`86b7b91` → `ebfb9d98`) nghiệm thu Realme bản debug
> với **năm** lượt chia sẻ biên lai MB Bank thật (2026-10-02); Task 11 (2026-10-03, mục **7.7**): Lưu / Bỏ qua / chưa
> đọc được / đăng xuất / gỡ khỏi Recents trên máy, **bản release** (lượt ấy lộ R8 gãy từ 01/10 — đã sửa) và nút ✕ của
> màn xem ảnh. Stitch (người dùng xác nhận): `805cd430…` *"Thêm giao dịch - Từ biên lai"* · `c0597919…` *"…- Biên lai
> chưa đọc được"* · `55431838…` *"Xem biên lai - FlowMoney"* (vẽ ✕ không nền — bản thi công thêm nền tròn tối, lệch có
> chủ ý). ⏳ **Còn mở:** mẫu riêng MoMo / ZaloPay — chờ biên lai thật (người dùng chốt: làm khi có giao dịch). Spec
> `docs/superpowers/specs/2026-10-02-chia-se-bien-lai-design.md`; kế hoạch (gitignore)
> `docs/superpowers/plans/2026-10-02-chia-se-bien-lai.md` — nhật ký thi công ở cuối tệp ấy. Thông báo cho backend:
> `docs/superpowers/backend/DA-XONG/CLIENT_CHIA_SE_BIEN_LAI.md` — backend đóng 2026-10-03, hai câu trả lời trùng mặc
> định của client (không màn đồng ý riêng; nguồn biên lai ghi vào `LogicBusinessAI.md`).

### 7.1. Vì sao

D1 chỉ đọc thông báo đã hiện trên máy. Đo trên Realme 2026-10-02: sáu lần chuyển từ MB Bank trong buổi, năm lần có
thông báo, **một lần (19:46) không có** — khoản ấy D1 không thấy. MoMo / ZaloPay không bắn tin khi chuyển đi. Android
không cho đọc màn hình app khác; quyền Trợ năng (đọc cả số dư, OTP) và liên kết ngân hàng qua server (nhóm bỏ
2026-09-18) đều bị loại. Còn lại: người dùng tự đưa biên lai bằng nút *Chia sẻ* của app ngân hàng.

### 7.2. Luồng

1. Màn *"Giao dịch thành công"* → *Chia sẻ* → **"Ghi vào FlowMoney"**.
2. Vẫn ở app ngân hàng (người dùng chốt — để còn chuyển tiếp). Toast *"FlowMoney đã nhận biên lai"* + tóm tắt không số
   của D1, N đếm cả tin ngân hàng lẫn biên lai đang chờ.
3. Mở FlowMoney → chữ trên ảnh được đọc → dòng loại 20 trong trung tâm thông báo / thẻ *"Có N mục chờ ghi"*.
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
  ✅ **2026-10-05 — luật chung đọc CHIỀU tiền** (người dùng báo: biên lai MoMo *"Nhận tiền qua mã QR từ …"* +10.000đ
  được ghi thành **chi** — luật chung khi ấy luôn cho `chi`): dấu `+` / `-` trên số tiền có đơn vị thắng (bỏ hàng phí /
  số dư; `+3 Xu` không có đơn vị nên không tính); không dấu thì một hàng **mở đầu** bằng *"Nhận tiền / Nhận chuyển
  khoản"* → `thu` (neo đầu hàng để *"Người nhận"* của biên lai chuyển đi không lọt); còn lại `chi`. Đi kèm: biên lai
  thu nay ghép được vào hàng tin MoMo *"Nhận chuyển khoản"* của cùng giao dịch (trước đó lệch chiều nên thành hàng thứ
  hai).
  ✅ **2026-10-05 — luật chung thêm bước *tiêu đề thành công*** (người dùng báo: biên lai MoMo thanh toán cửa hàng
  39.000đ được điền **5.000.000**): biên lai MoMo không có nhãn số tiền, và bước cũ *"số có đơn vị LỚN NHẤT"* chọn câu
  quảng cáo *"Liệu đã tới 5.000.000đ?"* bên dưới. Nay thứ tự là: nhãn số tiền → **số có đơn vị đầu tiên trên hàng
  "… thành công" hoặc hai hàng kế** → số có đơn vị lớn nhất; hai bước sau bỏ hàng phí / số dư và hàng **câu hỏi**
  (kết thúc bằng `?`). Ca test dựng lại hình dạng biên lai ấy bằng tên và số giả. ✅ Đo OnePlus 13R 2026-10-05
  (bản debug): biên lai Bách Hóa Xanh ra 39.000 đ chi, biên lai nhận tiền QR ra +10.000 đ **thu** — người dùng xác nhận.
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
- **`google_mlkit_text_recognition` thành gói chính thức** (người dùng duyệt). Giá, đo trên **APK release**
  2026-10-03 (bằng con số trên APK debug 02/10): thư viện gốc `libmlkit_google_ocr_pipeline.so` **11,06 MB** arm64 ·
  6,78 MB armeabi-v7a · 11,63 MB x86_64, mô hình `assets/mlkit-google-ocr-models/` **1,49 MB** → một máy arm64 tải thêm
  khoảng **12,5 MB**; APK gộp ba ABI thêm ~31 MB. APK release 30/09 (trước spike C4) 202,2 MB → nay 234,6 MB (+32,4 MB,
  gồm cả ba gói spike C4 và phần dex). Không dựng bản *không có* gói để so: gỡ gói phải gỡ cả đường DI lẫn màn spike, mà
  phần gói mang vào nằm trọn trong hai thư mục trên — đọc thẳng từ APK. Ba gói spike C4 còn lại vẫn là gói tạm.
- **Bản release cần `android/app/proguard-rules.pro`** (2026-10-03): plugin tham chiếu lớp tuỳ chọn của bốn hệ chữ
  Trung · Devanagari · Nhật · Hàn mà nó chỉ khai `compileOnly`; R8 coi lớp thiếu là lỗi. Tệp chỉ có bốn dòng
  `-dontwarn` — app chỉ dùng `TextRecognitionScript.latin` (nhánh 0 của `TextRecognizer.initialize` phía Kotlin) nên
  bốn nhánh kia không bao giờ chạy; **không** `-keep` gì của ML Kit (lỗi là lớp thiếu, không phải lớp bị cắt nhầm).
  Flutter Gradle plugin tự nạp tệp khi nó tồn tại. Canh: `test/core/ocr/ban_release_r8_mlkit_test.dart`.
- **Nút ✕ của màn xem ảnh to có nền tròn tối** (`Colors.black54`) — lệch có chủ ý với màn Stitch `55431838…` (✕ không
  nền): nút nằm đè góc ảnh, ✕ trắng không nền chìm hẳn trên biên lai nền sáng. Ca test đo **tương phản** ✕ trắng / nền
  nút đặt lên ảnh trắng ≥ 3:1 (WCAG 1.4.11) chứ không đo chi tiết cài đặt.

### 7.5. Bẫy

- ⚠️ **Tên tệp ảnh đi vào deeplink rồi thành đường dẫn** — mọi chỗ ghép đường dẫn phải qua `tenTepBienLaiHopLe`
  (`KhoBienLai`, `anhTuDeeplink`, `dienSanBienDongTuQuery`).
- ⚠️ **Dọn mồ côi phải tính cả hàng chờ ĐANG CÓ**: Kotlin có thể vừa nhận thêm một biên lai trong lúc lượt nhập đọc
  chữ — quên là xoá ảnh người dùng vừa chia sẻ, im lặng.
- ⚠️ **`NhapBienLai` phải chạy SAU `NhapBienDong`** trong cùng lượt; ngược lại biên lai không bao giờ gắn được vào hàng
  tin của cùng giao dịch. Ca test của `NotificationScanner` canh.
- ⚠️ **`adb shell am start … SEND` không cấp được quyền đọc URI của MediaStore** → `SecurityException` → Toast *"chỉ
  nhận ảnh biên lai"*. Tự thử đường thành công bằng `file://` trong vùng riêng của app. ⚠️ Đưa ảnh vào vùng ấy bằng
  `adb shell "run-as … sh -c 'cat > cache/x.png'" < x.png` **chỉ chép được 5 byte** (stdin của `adb shell` không đi nhị
  phân — đo 2026-10-03) và Toast *"chỉ nhận ảnh"* trông y như lỗi của app; dùng `adb push x.png /data/local/tmp/` →
  `chmod 644` → `run-as … cp /data/local/tmp/x.png cache/`, rồi `ls -l` kiểm kích thước.
- ⚠️ **Sửa mã Dart bằng script Python trong heredoc làm hỏng mọi dấu gạch chéo ngược** (`\b` → ký tự backspace trong
  regex; `'\n'` → xuống dòng thật) — vấp hai lần trong lượt này. Dùng công cụ Edit / Write.
- ⚠️ **`KhoBienLai.xoa` xoá ĐỒNG BỘ** (`deleteSync`): bản `await f.delete()` treo trong widget test (I/O thật không
  chạy dưới FakeAsync) nên Bỏ qua không bao giờ `pop`.
- ⚠️ Ảnh chia sẻ từ MB Bank là ảnh **toàn màn** 1080 × 2400, thẻ biên lai nằm giữa — ảnh nhỏ canh đỉnh chỉ thấy nền.
- ⚠️ **Bản release đã KHÔNG dựng được từ lúc spike C4 thêm gói ML Kit (01/10) tới 2026-10-03** — `minifyReleaseWithR8`
  dừng ở *"Missing class com.google.mlkit.vision.text.chinese…"*. Bản debug không chạy R8; `flutter test`, `flutter
  analyze` và mọi lượt nghiệm thu bản debug đều xanh; không ai dựng release giữa hai mốc nên không lộ. **Thêm gói có
  mã Android gốc thì dựng thử `--release` ngay**, đừng đợi tới lúc nghiệm thu.
- ⚠️ **Lệnh dựng chạy nền báo `exit 0` không có nghĩa là dựng được**: lượt đầu chạy `flutter build … ; tail` nên mã thoát
  là của `tail`, và tệp `app-release.apk` trong thư mục là bản **cũ 30/09** — đo dung lượng trên nó cho ra kết luận sai
  *"bản release không có ML Kit"*. Xoá APK cũ trước khi dựng, ghi `echo $?` ngay sau `flutter`, so thời gian tệp.
- ⚠️ **Thư viện ảnh ColorOS tự vẽ bảng chia sẻ** (7 trang; *"Ghi vào FlowMoney"* ở trang 3 trên Realme) — vẫn đúng
  `ACTION_SEND` kèm quyền đọc URI, nên đây là đường thử **bản release** không cần app ngân hàng: đẩy ảnh vào
  `/sdcard/Pictures/…`, quét media, mở bằng `am start -a VIEW -d content://media/external/images/media/<id>` rồi chạm
  *Chia sẻ*. Nguồn ra `Biên lai` (gói gửi là thư viện ảnh).
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
hàng"* (cùng commit).

### 7.7. Nghiệm thu máy thật — Realme RMX2205, 2026-10-03 (Task 11)

Bản debug `f80653cb…` (= `ebfb9d98`). Lưu / Bỏ qua dùng **biên lai thử** (người dùng chọn): một ảnh PNG trơn không
chữ, và một biên lai giả dựng bằng PIL (*"Chuyển tiền thành công · 12,345 VND · 08:45 - 03/10/2026"*), chia sẻ qua
`file://` từ `com.android.shell` — nguồn ra `Biên lai`. Giao dịch thử 12.345 đ lưu vào ví *test* rồi xoá qua giao diện.

| Phép thử | Kết quả |
|---|---|
| Chia sẻ hai biên lai thử khi FlowMoney đang ở nền | ✅ tiêu điểm giữ ở màn hình chính; tóm tắt *"Có 2 biến động số dư mới — chạm để ghi"* (không số) |
| Chạm tóm tắt | ✅ trung tâm thông báo nhóm *Biến động*: *"-12.345 đ · Biên lai"* và *"Biên lai chưa đọc được · Biên lai — Chạm để nhìn ảnh và nhập số tiền"* |
| Form *chưa đọc được* | ✅ `0 đ`, 16 phím hiện, ảnh nhỏ, dòng phụ cam *"Chưa đọc được số tiền — nhìn ảnh để nhập"*, ví trống |
| Xem ảnh to | ✅ nền đen, ảnh vừa khung, nút ✕ — ⚠️ ✕ trắng **gần như chìm trên ảnh sáng màu** (ảnh thử xám nhạt); biên lai MB nền xanh đậm thì rõ → **đã sửa**: nền tròn `black54`, nhìn lại trên bản release `04de3221…` với cùng ảnh xám — ✕ rõ |
| **Bỏ qua** | ✅ dòng biến mất, tệp ảnh bị xoá, hàng chờ đã tiêu thụ |
| Form *đọc theo luật chung* | ✅ 12.345 đ, giờ `03/10/2026 08:45` lấy từ chữ trên ảnh, ghi chú *"bien lai thu nghiem"*, dòng *"Đọc từ ảnh — hãy kiểm lại"* |
| Ảnh nhỏ canh giữa (`ebfb9d98`) | ✅ với biên lai giả **và** biên lai MB thật 19:46 (thấy thẻ *"Chuyển tiền thành công"*) |
| **Lưu** | ✅ dòng biến mất, tệp ảnh bị xoá; giao dịch vào sổ |
| Gỡ FlowMoney khỏi Recents rồi chia sẻ | ✅ nhận. ⚠️ Lần này ColorOS **chỉ gỡ task, không giết tiến trình** (khác ghi nhận 22/09 ở `AI_EDGE_FEATURE.md` — nhiều khả năng dịch vụ nghe thông báo của D1 giữ tiến trình) |
| `am force-stop` rồi chia sẻ | ✅ nhận; cờ phiên phía native còn nguyên |
| Đăng xuất | ✅ `files/bien_lai/` mất hẳn, hàng chờ mất, **3 dòng mang ảnh bị xoá cứng** (hai hàng tin MB 19:38 / 19:44 được gắn ảnh, một hàng từ biên lai 19:46 — người dùng cho phép), 10 dòng tin còn lại; không còn thông báo nào đang hiện |
| Chia sẻ khi đã đăng xuất | ✅ Toast *"Đăng nhập FlowMoney để ghi biên lai"*, không tệp |
| Bố cục 360 dp | ✅ logcat 0 dòng `overflowed` / `RenderFlex` / `EXCEPTION CAUGHT` |

**Bản release** `0d2d03da…` (sau khi thêm `proguard-rules.pro`; bản `04de3221…` thêm nền nút ✕), chia sẻ qua **Thư viện ảnh ColorOS** — đường thật có
cấp quyền URI, không cần `run-as` (bản release không `run-as` được nên phần *tệp đã xoá* chỉ kiểm ở bản debug):

| Phép thử | Kết quả |
|---|---|
| `flutter build apk --release` | ✅ sau khi thêm `proguard-rules.pro` (trước đó gãy ở R8 — mục 7.5) |
| Bảng chia sẻ của Thư viện có *"Ghi vào FlowMoney"* | ✅ trang 3/7 |
| Chưa đăng nhập | ✅ Toast *"Đăng nhập FlowMoney để ghi biên lai"*, vẫn ở Thư viện |
| Đã đăng nhập | ✅ Toast *"FlowMoney đã nhận biên lai"*, vẫn ở Thư viện; tóm tắt *"Có 1 biến động số dư mới — chạm để ghi"* |
| Chạm tóm tắt → ML Kit của **bản release** đọc chữ | ✅ dòng *"-12.345 đ · Biên lai — bien lai thu nghiem"*; form 12.345 đ, giờ 08:45 từ ảnh, *"Đọc từ ảnh — hãy kiểm lại"* |
| Bỏ qua | ✅ dòng biến mất |

**OnePlus 13R (`CPH2691`, 1264 × 2780), bản release `04de3221…`** — người dùng yêu cầu làm lại trên máy này cùng ngày;
chia sẻ qua Thư viện `com.oneplus.gallery`. **Không** thử đăng xuất (phép đăng xuất người dùng cho là cho Realme).

| Phép thử | Kết quả |
|---|---|
| Bảng chia sẻ của Thư viện | ⚠️ *"Ghi vào FlowMoney"* **không** nằm ở hàng app mặc định — phải chạm **Khác** rồi cuộn danh sách *Tất cả các ứng dụng* (hàng mặc định gồm Gemini, Maps, Tin nhắn, Photos…). Người dùng lần đầu có thể không tìm thấy; bảng chia sẻ của app ngân hàng chưa đo trên máy này |
| Chia sẻ biên lai giả rồi ảnh trơn | ✅ cả hai: Toast *"FlowMoney đã nhận biên lai"*, vẫn ở Thư viện; tóm tắt *"Có 2 biến động số dư mới — chạm để ghi"* |
| Chạm tóm tắt → ML Kit release đọc chữ | ✅ *"-12.345 đ · Biên lai — bien lai thu nghiem"* và *"Biên lai chưa đọc được · Biên lai"* |
| Form đọc được | ✅ 12.345 đ, giờ 08:45 từ ảnh, ảnh nhỏ canh giữa, *"Đọc từ ảnh — hãy kiểm lại"* |
| Xem ảnh to | ✅ ✕ nền tròn tối rõ trên biên lai trắng. Màn rộng nên ảnh không phủ hết bề ngang — nút lấn ra viền đen, nửa phải vòng tròn lẫn vào nền đen (✕ vẫn rõ) |
| Form chưa đọc được | ✅ `0 đ`, 16 phím, ảnh nhỏ, dòng phụ cam; giờ là **lúc chia sẻ** (ảnh không có chữ giờ) |
| Bỏ qua cả hai | ✅ không còn dòng biên lai nào |

Đăng nhập lại cần backend dev (người dùng cho bật): lượt đồng bộ đầu tiên sau nhiều ngày — 65 thao tác, **45 lên · 10
xung đột · 10 lỗi**. Mười lỗi **có từ trước, không do tính năng này**: hai ví trên Realme trùng tên với ví đã có trên
server (`Unique constraint (Idaccount, Name)` → `WALLET_NAME_DUPLICATE`), kéo theo giao dịch trong hai ví ấy vỡ
`fk_transaction_wallet`, và một lần trả hoá đơn bị `chanTraHaiLan` chặn — chính là *"10 failed"* ghi từ 28/09.

## 8. Nhắc ghi sau khi dùng app ngân hàng (2026-10-03)

> **Trạng thái:** ✅ **xong trọn kế hoạch 10 task** (`77b0ff8` → `5cfb429` + bốn bản sửa lúc nghiệm thu), **nghiệm thu
> Realme RMX2205** bản debug và bản release (mục 8.7). ⏳ **Chưa đo:** chuyển tiền thật **có** tin biến động → không
> được nhắc (lần chuyển thật trong buổi MB không bắn tin — đo được ca ngược), và chạy nền lúc **Doze** (tắt màn, rút
> cáp — người dùng tự đo). Spec `docs/superpowers/specs/2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md`; kế hoạch
> (gitignore) cùng tên ở `plans/` — nhật ký thi công cuối tệp. Stitch: màn đồng ý mới + ba màn sửa, người dùng xác
> nhận bằng mắt (API trễ hơn giao diện > 2 giờ, chưa lấy được id màn mới). Thông báo cho backend:
> `docs/superpowers/backend/CAN-LAM/CLIENT_NHAC_SAU_APP_NGAN_HANG.md`.

### 8.1. Vì sao

D1 chỉ đọc thông báo đã hiện; chia sẻ biên lai (mục 7) chỉ cứu được khoản người dùng **nhớ** chia sẻ. Đo Realme
02/10: sáu lần chuyển MB, một lần không có tin; MoMo / ZaloPay không bắn tin khi chuyển đi. Bản này nhắc **khi người
dùng quên**. Tín hiệu hợp lệ duy nhất là quyền **Truy cập dữ liệu sử dụng** (`PACKAGE_USAGE_STATS`,
`UsageStatsManager.queryEvents`): giờ một app lên / rời màn hình — không đọc màn hình, không đọc nội dung. Đo
`dumpsys usagestats`: MB Bank là app Flutter một màn, và **thời lượng phiên không tách được "xem số dư" với "chuyển
tiền"** (phiên 95 s không chuyển dài hơn mọi phiên có chuyển) → nhắc oan là chuyện thường, nên lời nhắc **im lặng** và
bỏ được bằng **một chạm**.

### 8.2. Luồng

1. *Cá nhân → Cài đặt thông báo → Tự động hoá giao dịch*: khối **"Nhắc ghi sau khi dùng app ngân hàng"** dưới *Biến
   động số dư*, mặc định TẮT, dùng được khi D1 tắt. Bật lần đầu → **màn đồng ý** (thanh tiêu đề *"Nhắc ghi giao
   dịch"*) → *Đồng ý và mở Cài đặt* → trang *Truy cập dữ liệu sử dụng* (máy đã có quyền thì bỏ bước này). Dòng trạng
   thái *"Đã cấp quyền — đang theo dõi 3 app"* / *"Chưa cấp quyền truy cập dữ liệu sử dụng · Mở Cài đặt"*.
2. Dùng MB Bank / MoMo / ZaloPay (danh sách của D1) **≥ 20 giây** mà quanh phiên không có tin, biên lai hay giao dịch
   → khi FlowMoney chưa được mở lại: thông báo **im lặng** *"Vừa dùng MB Bank — có giao dịch cần ghi?"* (nhiều app thì
   gộp *"MB Bank, MoMo"*), nút **Không có giao dịch**.
3. Mở FlowMoney (bất kỳ đường nào) → dòng *"MB Bank · 18:44 – 18:45 — Chưa thấy giao dịch nào, chạm để ghi"* trong
   danh sách *Biến động*; thẻ Sổ giao dịch nay là **"Có N mục chờ ghi"**; thông báo nhắc tự gỡ.
4. Chạm dòng → form: dải *"Dùng MB Bank · 03/10 18:44"*, số tiền **trống** (16 phím hiện), ngày giờ = **lúc mở app
   ngân hàng**, ví theo nguồn (chưa biết thì trống) → **Lưu** (nhớ ví cho nguồn) / **Bỏ qua** / vuốt — dòng xoá cứng.

### 8.3. Kiến trúc

```
Cài đặt (Dart) ─ bật/tắt ─► NotificationPrefs.nhacSauNganHang (+ dongYNhacSauNganHang)       [TÀI KHOẢN]
                            MocPhienStore.daXetDen                                             [TÀI KHOẢN]
                            MocPhienStore.danhDauDangXuat (cờ "vừa đăng xuất")                 [MÁY]
NotificationScanner.start / resumed → _nhapBienDong:
  NhapBienDong → NhapBienLai → NhapPhienNganHang.nhap(idaccount)                                ← thứ tự bắt buộc
     cờ "vừa đăng xuất" ? → daXetDen = bây giờ (lượt nhập đầu sau đăng xuất = lần đăng nhập kế)
     cờ tài khoản tắt → datBat(false) · thiếu quyền → daXetDen = bây giờ
     → suKien(tu) → phienTuSuKien → phienCanXet → phienCanNhac(hàng loại 20, giao dịch, ví theo nguồn)
     → insertAllIfAbsent hàng loại 20 (khoá bienDong:phien|…) → daXetDen → datBat(true) → huyNhac()
NotificationScanner.stop → dongKhiDangXuat: daXetDen = bây giờ, cờ "vừa đăng xuất", datBat(false)

Kotlin (không chạm SQLite): PhienNganHang.kiem ← NhacGhiWorker (WorkManager 15 phút) ← BienDongListenerService
  (sau khi ghi hàng chờ D1; giãn ≥ 60 s) → queryEvents → dựng phiên (khớp tay §4.2 spec) → bỏ phiên có tin / biên lai
  trong hàng chờ, bỏ phiên nếu FlowMoney đã lên sau batDau → thông báo im lặng id 20261003
  NhacGhiReceiver ("Không có giao dịch") → boDen = daBaoDen, gỡ thông báo
```

| Tệp | Vai |
|---|---|
| `lib/core/notification/phien_ngan_hang.dart` | hằng (khớp tay với Kotlin), `SuKienSuDung`, `phienTuSuKien`, `phienCanXet`, `mocSauKhiXet`, `phienCanNhac`, khoá / deeplink / tiêu đề — Dart thuần |
| `lib/core/notification/kenh_phien_ngan_hang.dart` | kênh `flowmoney/phien_ngan_hang` + bản trống (web / test) |
| `lib/core/notification/moc_phien_store.dart` | `daXetDen` theo tài khoản (`nhac_phien:<id>`) + cờ máy `nhac_phien_dang_xuat` |
| `lib/core/notification/nhap_phien_ngan_hang.dart` | lượt nhập + `dongKhiDangXuat` |
| `lib/core/notification/notification_scanner.dart` | bước thứ ba của `_nhapBienDong`, `stop()` |
| `lib/features/transaction/…` | `DienSanBienDong.phien`, `dongNguonBienDong`, `ViTheoNguonStore.docTheoNguon`, chữ thẻ |
| `lib/features/notification/presentation/pages/` | `man_dong_y.dart` (khung dùng chung với D1) · `dong_y_nhac_sau_ngan_hang_page.dart` · khối ở `notification_settings_page.dart` |
| `android/…/PhienNganHang.kt` · `NhacGhiWorker.kt` · `NhacGhiReceiver.kt` | đọc sử dụng, dựng phiên, thông báo, lịch · worker · nút |
| `android/…/BienDongListenerService.kt` · `MainActivity.kt` · `AndroidManifest.xml` · `build.gradle.kts` | móc kiểm · kênh · quyền + receiver · `work-runtime-ktx:2.11.0` |

### 8.4. Quyết định (kèm lý do)

- **Cả hai: dòng trong app (luôn có) + thông báo ở nền (lớp thêm).** Thông báo **im lặng, gộp một**, không số tiền,
  không giờ; nút *Không có giao dịch* — vì nhắc oan là chuyện thường (8.1).
- **Danh sách app = danh sách D1** (`kNguonTheoGoi` ↔ `DANH_SACH_TRANG`), không màn tự chọn app; **công tắc riêng**,
  mặc định TẮT, màn đồng ý bắt buộc (cùng khuôn D1 backend yêu cầu); lần đồng ý được nhớ khi tắt.
- **Giữ CẢ HAI đường nền** (người dùng chốt sau đo Task 3, mục 8.6): WorkManager 15 phút + `kiem` ăn theo dịch vụ nghe
  thông báo của D1. Phép đo Doze chỉ để ghi tài liệu.
- **Kotlin phát hiện + bắn thông báo; Dart quyết định dòng nào được tạo.** Luật dựng phiên viết hai lần, hằng khớp tay
  có test đọc tệp Kotlin; lượt nhập Dart luôn gỡ thông báo nên hai bên lệch thì thông báo cũng không đứng lâu.
- **Ngưỡng:** gộp phiên 3 phút · trên màn ≥ 20 s · tin / biên lai trong [mở − 2 phút, rời + 10 phút] · giao dịch trong
  [mở − 2 phút, rời + 30 phút] · lùi tối đa 7 ngày.
- **Bằng chứng giao dịch = MỌI giao dịch sống** (soát với mã, sửa spec cùng ngày): `laGhiChuMay` đi qua
  `khoanVaoThongKe` nên loại cả **chuyển khoản** người dùng tự ghi — đúng thứ hay đi sau một phiên ngân hàng. Biết ví
  của nguồn thì chỉ tính giao dịch ở ví ấy.
- **Mốc theo tài khoản**, `boDen` (nút *Không có giao dịch*) theo máy. **Đăng xuất đặt mốc = giờ đăng xuất VÀ ghi cờ
  máy "vừa đăng xuất"** — cờ thêm sau nghiệm thu (`8deeeb5`): chỉ mốc thì phiên giữa đăng xuất và lần đăng nhập kế vẫn
  thành dòng, kể cả cho **tài khoản khác** đăng nhập sau.
- **Thẻ Sổ giao dịch đổi chữ "Có N mục chờ ghi"** — dòng nhắc chưa chắc đã có giao dịch.
- **Chỉ Android 10+** (`ACTIVITY_RESUMED` / `ACTIVITY_PAUSED`); máy cũ coi như không có quyền.
- **Thanh tiêu đề màn đồng ý *"Nhắc ghi giao dịch"*** (`4818bcf`, người dùng chọn): tên đầy đủ cụt ở 360 dp; tên đầy
  đủ vẫn là tiêu đề khối ở Cài đặt.

### 8.5. Bẫy

- ⚠️ **Thứ tự nhập bắt buộc: `NhapBienDong` → `NhapBienLai` → `NhapPhienNganHang`** — tin và biên lai đang chờ phải
  thành hàng trước khi xét bằng chứng; ngược lại là nhắc oan. Ca canh ở `notification_scanner_test`.
- ⚠️ **Cờ máy gắn MÁY, công tắc gắn TÀI KHOẢN** (bẫy 3 của D1): lượt nhập ghi lại cờ máy theo người đang đăng nhập ở
  **mọi** lượt — vì thế cài bản mới lên máy đang mang cờ đo thì lượt đầu tự tắt nhắc.
- ⚠️ **Sự kiện dùng app là của MÁY** — mọi mốc theo tài khoản phải chặn được phiên lúc không ai đăng nhập (`8deeeb5`).
- ⚠️ **Hằng Dart ↔ Kotlin khớp tay**; `phien_ngan_hang_noi_day_test` đọc tệp Kotlin để so.
- ⚠️ **Không dùng `laGhiChuMay` làm bằng chứng** — nó loại chuyển khoản tự ghi (8.4).
- ⚠️ **Hàng gợi ý pin** của D1 và của khối này cùng điều kiện — D1 đã hiện thì khối này không lặp.
- ⚠️ **WorkManager chạy lượt ĐẦU ngay lúc `enqueueUniquePeriodicWork`**, không đợi 15 phút.
- ⚠️ **Cắm cáp USB = đang sạc → Android không vào Doze** — đo tắt màn phải rút cáp.
- ⚠️ `appops set … GET_USAGE_STATS` bị ColorOS từ chối — người dùng tự bật ở `USAGE_ACCESS_SETTINGS -d package:…`.
- ⚠️ Log `NhacGhi` (chỉ bản debug, chỉ số đếm): `su_kien` đếm cả sự kiện của chính FlowMoney — `su_kien=3 phien=0` là
  *chưa có MB*.
- ⚠️ ColorOS thu gọn thông báo im lặng: nút *Không có giao dịch* chỉ hiện khi **vuốt mở rộng**; `uiautomator dump`
  **không thấy** nó trong khay — nghiệm thu nhờ người dùng bấm (đừng chụp khay — lẫn thông báo app khác).
- ⚠️ Widget test dựng `GoRouter` riêng cho form phải khai `/add/category` (hàng *Danh mục* `push` trang chọn).
- ⚠️ **Lỗi chung lộ ra ở lượt này, không riêng tính năng:** `SnackBar` có `action` không tự ẩn ở Flutter 3.47 (đặt
  `persist: false` — `c18e095`); *Đăng xuất* ở drawer không làm gì (`c2d6985`, mục 14 `PROJECT_CONTEXT.md`).
- ⚠️ Quan sát mở: một lần (1/6, bản release, chạm thật từ khay) dải chip **không tự cuộn** tới *Biến động* — lọc vẫn
  đúng; `am start` lúc nền ×3, khởi động nguội ×2 đều cuộn đúng.

### 8.6. Đo chạy nền — Realme RMX2205, 2026-10-03

Task 3 (bản đo `SPIKE_NHAC`, FlowMoney ở nền / đã vuốt Recents):

| Lần | Phiên MB | Nhắc | Đường | Trễ sau khi rời MB |
|---|---|---|---|---|
| 1 | 14:14:00–14:14:53 (53 s) | 14:21:10 | D1 | 6 phút 17 giây |
| 2 | 14:26:19–14:27:03 (44 s) | 14:33:59 | D1 | 6 phút 56 giây |
| 3 | 15:08:09–15:08:34 (6 + 19 s gộp = 25 s) | 15:13:30 | worker | 4 phút 56 giây |
| 4 | 15:27:43–15:27:58 (**15 s**) | không nhắc ✅ (dưới 20 s) | — | — |
| 5 | 15:33:22–15:34:08 (46 s, đã vuốt Recents) | 15:38:09 | D1 | 4 phút 1 giây |

Task 9 (bản đủ tính năng): 18:33:04 → 18:40:03 (D1, 6 phút 59 giây) · 19:24:28 → 19:30:36 (worker, 6 phút 8 giây) ·
bản release 20:45:20 → ~20:58 (~13 phút; release không log nên không biết đường nào). Worker đúng 15 phút, kể cả lúc rút
cáp và sau khi vuốt Recents (ColorOS chỉ gỡ task, tiến trình sống). Doze: **chưa đo**.

### 8.7. Nghiệm thu máy thật — Realme RMX2205, 2026-10-03 (Task 9)

Bản debug (`127.0.0.1` tạm) rồi release `6029c7fc…`; tài khoản 10; phiên ngân hàng tạo bằng `adb shell monkey -p <gói>`
(để yên ~26 s ở màn đầu, không chạm, không chụp app ngân hàng — người dùng chọn), riêng dòng 8 là chuyển tiền thật.

| # | Phép thử | Kết quả |
|---|---|---|
| 1 | Bật lần đầu → màn đồng ý; *Không, cảm ơn* | ✅ công tắc tắt, cờ máy tắt. Tiêu đề thanh cụt ở 360 dp → `4818bcf` |
| 2 | Đồng ý → quyền | ✅ máy đã có quyền: không mở Cài đặt thừa, *"Đã cấp quyền — đang theo dõi 3 app"*; thiếu quyền: *Mở Cài đặt* → đúng trang của FlowMoney → bật → Back → dòng đổi ngay |
| 3 | MB 27 s, không chuyển, không mở FlowMoney | ✅ thông báo im lặng sau 6 phút 59 giây (`importance=2`, kênh `flowmoney_nhac_ghi`, không âm / rung) |
| 4 | *Không có giao dịch* → mở app | ✅ thông báo mất, không dòng |
| 5 | MB + MoMo + ZaloPay liền nhau → chạm thông báo | ✅ thông báo gộp 2 nguồn (ZaloPay chưa đủ 3 phút) → danh sách có **3** dòng |
| 6 | Chạm dòng → form | ✅ số tiền trống, 16 phím, dải *"Dùng MB Bank · 03/10 18:44"*, ngày = lúc mở MB, ví trống (chưa biết) |
| 7 | Lưu / Bỏ qua / vuốt | ✅ Lưu → giao dịch đúng 18:44 (khoản thử, đã xoá); Bỏ qua, vuốt → dòng mất. Dải *"Đã xoá thông báo"* đứng yên > 7 phút → `c18e095`, đo lại tự ẩn |
| 8 | Chuyển tiền thật **có** tin | ⏳ chưa đo — lần chuyển thật MB không bắn tin → **có** nhắc (6 phút 8 giây), form **tự điền Ví MB Bank** (nhớ từ lần Lưu ở dòng 7) — đúng ca tính năng sinh ra để bắt |
| 9 | Mở MB rồi ghi tay ngay vào Ví MB Bank | ✅ không thông báo, không dòng |
| 10 | Rút quyền | ✅ không thông báo, không dòng; dòng *"Chưa cấp quyền truy cập dữ liệu sử dụng · Mở Cài đặt"* |
| 11 | Đăng xuất → dùng MB → đăng nhập lại | ❌→✅ không thông báo lúc đã đăng xuất, nhưng đăng nhập lại ra dòng cho phiên ấy → `8deeeb5`, đo lại đạt. *Đăng xuất* ở drawer không làm gì → `c2d6985`, đo lại đạt |
| 12 | 360 dp | ✅ 0 pixel vàng thuần `#FFFF00` trên 32 ảnh (Cài đặt, màn đồng ý, danh sách, form, Sổ giao dịch); đối chứng dương 100/100 |
| 13 | Bản release một vòng | ✅ thông báo → chạm → dòng → form (ví tự điền) → Bỏ qua |
