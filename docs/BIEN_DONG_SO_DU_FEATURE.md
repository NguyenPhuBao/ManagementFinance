# Đọc biến động số dư trên máy (D1) — tài liệu bàn giao

> **Trạng thái 2026-09-30:** ✅ **xong mã + nghiệm thu máy thật** (OnePlus 13R, bản debug rồi bản release) — chưa đo tin
> **MB Bank** qua đường thật, và bản sửa chip ở trung tâm (`802dcd2`) chưa cài lên máy. Spec
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
      → gộp trùng (mã GD | cùng tiền + chiều ≤ 5 phút) → AppNotifications loại 20 (deeplink /add?…&khoa=…)
      → xoá tệp (kể cả khi cờ tắt) → huyTomTat()
  → Sổ giao dịch: TheBienDongChuaGhi (watchDemBienDong) → /notifications?nhom=bienDong
  → MoTuTomTatBienDong (main.dart): moTuThongBao() lúc start + resumed → cùng route, chờ phiên nếu chưa đăng nhập
  → /add?… → dienSanBienDongTuQuery → ketQuaTuBienDong → _dienKetQua (đường điền của C2)
      → Lưu / Bỏ qua → NotificationDao.xoaCung (+ nhớ ví theo nguồn ở lần Lưu đầu)
```

| Tệp | Vai |
|---|---|
| `android/…/BienDongListenerService.kt` | lọc thô, hàng chờ, tóm tắt, `DANH_SACH_TRANG`, chế độ thu mẫu (debug, đã che) |
| `android/…/MainActivity.kt` | kênh `flowmoney/bien_dong`: `coQuyen · moCaiDat · moTuThongBao · huyTomTat · datBat` |
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

## 6. Việc sau D1 (người dùng chốt 2026-09-30)

1. **Bàn phím số ẩn khi màn Thêm giao dịch mở với số tiền đã có** (từ biến động / Nhập nhanh / sửa) — chạm số tiền mới
   hiện; màn trống giữ như nay; nút Lưu ✓ ra thanh tiêu đề khi bàn phím ẩn. Vẽ Stitch trước.
2. **Cặp chi + thu cùng tiền, ≤ 5 phút, hai nguồn khác** → gợi ý mở form *Chuyển khoản* điền sẵn ví nguồn / đích.
3. **Chia sẻ biên lai** ví điện tử vào FlowMoney → đọc chữ trên máy → điền sẵn (gộp C4).
4. Đo thêm nguồn: Vietcombank, Techcombank, BIDV, Tin nhắn (chế độ thu mẫu bản debug — hình dạng đã che).
