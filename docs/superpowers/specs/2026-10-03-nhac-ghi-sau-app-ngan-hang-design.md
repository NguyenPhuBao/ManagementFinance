# Nhắc ghi sau khi dùng app ngân hàng — thiết kế

**Ngày:** 2026-10-03. **Trạng thái:** thiết kế duyệt trong chat (mười lượt AskUserQuestion — năm câu hỏi rồi duyệt
từng phần 1–5); bản viết người dùng **duyệt** cùng ngày (*"Ok duyệt"*). Kế hoạch:
`docs/superpowers/plans/2026-10-03-nhac-ghi-sau-app-ngan-hang.md` (gitignore). Chưa có mã.

Việc sau D1 số 3b (`docs/BIEN_DONG_SO_DU_FEATURE.md` mục 6), bản thiết kế thứ hai của cùng lượt với *chia sẻ biên lai*
(spec `2026-10-02-chia-se-bien-lai-design.md` mục 11). Hai việc bù cho nhau: biên lai cứu giao dịch **khi người dùng
nhớ** chia sẻ; bản này nhắc **khi người dùng quên**.

## 1. Vì sao

D1 chỉ đọc thông báo đã hiện trên máy. Đo Realme 2026-10-02: sáu lần chuyển từ MB Bank, **một lần (19:46) không có
thông báo biến động**. MoMo / ZaloPay **không bao giờ** bắn tin khi chuyển tiền đi. Những khoản ấy chỉ vào FlowMoney nếu
người dùng nhớ chia sẻ biên lai hoặc tự ghi.

Tín hiệu hợp lệ duy nhất để biết *"vừa dùng app ngân hàng"* là quyền **Truy cập dữ liệu sử dụng**
(`PACKAGE_USAGE_STATS`, `UsageStatsManager.queryEvents`): giờ một app lên / rời màn hình. Quyền Trợ năng (đọc cả màn
hình) đã bị loại ở D1; Android không có broadcast nào báo app khác vừa rời tiền cảnh — nên FlowMoney phải **tự đi kiểm**.

**Đo 2026-10-03 trên Realme** (`dumpsys usagestats`, chỉ lấy dòng MB Bank, dump thô đã xoá):

| Đo | Kết quả |
|---|---|
| MB Bank có màn chuyển tiền riêng không | **Không** — app Flutter một màn (`io.flutter.plugins.MainActivity`); màn phụ duy nhất là xác thực khuôn mặt (`…SingalarityAuthenSessionActivity`), xuất hiện cả ở phiên không chuyển tiền nên không dùng được |
| Phiên (gộp khi quay lại trong 60 s) | 9 phiên / ~17 giờ: 4 phiên lướt 1–14 s · 5 phiên 62–95 s trên màn, 3 trong số ấy có tin / biên lai |
| Phiên dài không có gì | 19:41 hôm 02/10 (74 s) và 11:19 hôm 03/10 (95 s — người dùng mở để chia sẻ cho một phép đo) |

Hệ quả cho thiết kế: **thời lượng phiên không tách được "xem số dư" với "chuyển tiền"** (phiên 95 s không chuyển tiền dài
hơn mọi phiên có chuyển tiền) → nhắc oan là chuyện thường, nên lời nhắc phải **im lặng** và bỏ được bằng **một chạm**.

## 2. Quyết định người dùng đã chốt

| # | Quyết định |
|---|---|
| 1 | **Cả hai**: dòng trong danh sách *Biến động* (nền, luôn có) + thông báo ở nền (lớp thêm, chỉ khi thử trên Realme thấy chạy được) |
| 2 | Thông báo **im lặng, gộp một**, có nút **Không có giao dịch** |
| 3 | App theo dõi = **danh sách của D1** (`kNguonTheoGoi`): MB Bank · MoMo · ZaloPay. Không màn tự chọn app |
| 4 | **Công tắc riêng**, mặc định TẮT, bật lần đầu qua **màn đồng ý**; dùng được khi D1 tắt |
| 5 | Chạy nền bằng **cả hai đường**: WorkManager định kỳ 15 phút + ăn theo dịch vụ nghe thông báo của D1. Thử trên Realme trước, đường nào không chạy thì bỏ |
| 6 | Thẻ ở Sổ giao dịch đổi chữ thành **"Có N mục chờ ghi"** |
| 7 | Ngưỡng mục 4.1 (người dùng chọn bộ ngưỡng đề xuất, không chọn ≥ 45 s) |
| 8 | Kotlin phát hiện + bắn thông báo; Dart quyết định dòng nào được tạo. Luật dựng phiên viết hai lần, hằng số khớp tay |
| 9 | Đăng xuất → mốc đã xét của tài khoản đặt về lúc đăng xuất |
| 10 | Kèm một **thông báo** cho backend trong `CAN-LAM/` (không xin đổi mã) |

## 3. Người dùng thấy gì

### 3.1. Bật

*Cá nhân → Cài đặt thông báo →* thẻ **Tự động hoá giao dịch**: dưới khối *Biến động số dư* có khối mới **"Nhắc ghi sau
khi dùng app ngân hàng"** (mô tả: *"Nhắc khi bạn dùng MB Bank, MoMo, ZaloPay mà chưa ghi giao dịch"* — danh sách app suy
từ `nguonDangDoc`), công tắc mặc định tắt.

- Bật lần đầu → **màn đồng ý** (mới, khuôn `DongYBienDongPage`): liệt kê 3 app; cam kết — chỉ đọc **giờ mở / giờ rời**
  3 app ấy · không đọc màn hình hay nội dung app · không gửi gì ra khỏi máy · không tự tạo giao dịch. *Đồng ý và mở
  Cài đặt* → trang *Truy cập dữ liệu sử dụng* của hệ thống (máy đã có quyền thì bỏ bước này). *Không, cảm ơn* / Back →
  công tắc vẫn tắt.
- Khi bật: dòng trạng thái quyền, hai biến thể — *"Chưa cấp quyền — Mở Cài đặt"* / *"Đã cấp quyền — đang theo dõi 3
  app"*; đã có quyền mà máy chưa cho chạy nền thì hiện lại dòng gợi ý pin của D1 (`_dongTreNen`, cùng điều kiện
  `duocChayNen`).
- Tắt: dừng hẳn (huỷ lịch nền, gỡ thông báo). Quyền hệ thống app không tự thu hồi được — dòng nhắc chỗ thu hồi như D1.
- Web / iOS: khối vẫn hiện như khối D1 (kênh trống — không có quyền nào để cấp, không làm gì). Đính chính câu *"dòng cài
  đặt không hiện (theo khuôn D1)"* lúc duyệt Phần 4: thẻ D1 hiện trên mọi nền tảng, bản này theo đúng khuôn ấy.

### 3.2. Thông báo ở nền

Chỉ khi có ít nhất một phiên đáng nhắc (mục 4) **và FlowMoney chưa được mở sau khi phiên bắt đầu**:

- Một thông báo id cố định, kênh riêng mức **LOW** (không kêu, không rung, không bật lên đầu màn hình).
- Chữ: *"Vừa dùng MB Bank — có giao dịch cần ghi?"*; nhiều app: *"Vừa dùng MB Bank, MoMo — có giao dịch cần ghi?"*.
  **Không số tiền, không giờ.**
- Nút **Không có giao dịch** → gỡ thông báo; các phiên ấy không bao giờ thành dòng.
- Chạm → mở FlowMoney vào `/notifications?nhom=bienDong` (đúng đường của tóm tắt D1).
- Mở FlowMoney (bằng bất kỳ cách nào) → lượt nhập tạo dòng rồi **gỡ** thông báo — dòng đã nằm trong danh sách.

### 3.3. Dòng trong danh sách *Biến động*

Cùng danh sách với tin ngân hàng và biên lai (hàng loại 20):

- Tiêu đề *"MB Bank · 11:19 – 11:20"* (cùng phút thì một mốc), thân *"Chưa thấy giao dịch nào — chạm để ghi"*.
- Chạm → form Thêm giao dịch (mục 3.4). Vuốt → xoá cứng có hoàn tác, như mọi hàng loại 20 (`_xoaCoHoanTac`).
- Phiên đã thành dòng, đã bị bỏ qua hay đã được ghi thì **không bao giờ** quay lại.

### 3.4. Form

- Dải nguồn *"Dùng MB Bank · 03/10 11:19"* (giờ = lúc mở app).
- Ngày giờ = lúc mở app; số tiền **trống** → 16 phím số hiện (luật bàn phím số ẩn chỉ áp khi đã có số tiền); loại mặc
  định của form (Chi); danh mục trống (không có chữ để đoán); ghi chú trống.
- Ví: nhớ theo nguồn (mục 5.4) — chưa biết thì **trống**, không ví mặc định (bẫy 4 của D1).
- Lưu / Bỏ qua → xoá cứng dòng (đường `_dongBienDong` / `_boQuaBienDong` sẵn có); Lưu lần đầu nhớ ví cho cặp
  *nguồn + đuôi trống*.

### 3.5. Thẻ ở Sổ giao dịch

`TheBienDongChuaGhi`: *"Có N biến động chưa ghi"* → **"Có N mục chờ ghi"** — dòng nhắc chưa chắc đã có giao dịch. N vẫn
đếm mọi hàng loại 20 chưa gạt (`watchDemBienDong` không đổi).

## 4. Luật phiên và "đáng nhắc"

### 4.1. Hằng số

| Tên (Dart / Kotlin) | Giá trị | Nghĩa |
|---|---|---|
| `kGopPhien` / `GOP_PHIEN_MS` | 3 phút | Quay lại app trong khoảng này là **cùng phiên**; rời đủ khoảng này mới là **phiên đã kết thúc** |
| `kToiThieuTrenMan` / `TOI_THIEU_TREN_MAN_MS` | 20 giây | Tổng thời gian trên màn tối thiểu để nhắc |
| `kTruocPhien` / `TRUOC_PHIEN_MS` | 2 phút | Bằng chứng tính từ *mở − 2 phút* |
| `kSauPhienTin` / `SAU_PHIEN_TIN_MS` | 10 phút | Tin / biên lai tính tới *rời + 10 phút* |
| `kSauPhienGiaoDich` | 30 phút | Giao dịch tính tới *rời + 30 phút* (chỉ Dart — Kotlin không thấy sổ) |
| `kLuiToiDa` | 7 ngày | Không xét phiên cũ hơn (Kotlin: 1 ngày — phần cũ hơn để Dart) |

Hằng nào có cột Kotlin thì **khớp tay** hai phía; một test đọc tệp Kotlin để so (khuôn `bien_dong_noi_day_test`).

### 4.2. Dựng phiên (`phienTuSuKien`, Dart thuần — Kotlin viết lại đúng thuật toán này)

Đầu vào: sự kiện `(goi, lop, loai: vao | ra, luc)` của các gói theo dõi, sắp theo `luc`.

1. Theo từng **gói**, giữ tập *lớp đang ở tiền cảnh*: `vao` thêm lớp, `ra` bỏ lớp. Tập rỗng → khác rỗng: mở một khoảng;
   khác rỗng → rỗng: đóng khoảng. Theo **lớp** chứ không theo gói vì hai activity của cùng app đổi chỗ cùng một mili
   giây có thể đến lộn thứ tự (đo: `PAUSED Main` và `RESUMED eKYC` cùng 18:30:29).
2. Bỏ sự kiện có `luc` sau *bây giờ* và khoảng có độ dài âm (đồng hồ máy bị chỉnh); `ra` lẻ (không có `vao` trước) bỏ.
3. Gộp các khoảng liên tiếp của cùng gói khi khe hở ≤ `kGopPhien`.
4. Phiên = `(goi, batDau, ketThuc, trenMan = Σ độ dài khoảng)`. Khoảng cuối chưa đóng → phiên **đang mở**.
5. Phiên **đã kết thúc** ⇔ không đang mở ∧ `bây giờ − ketThuc ≥ kGopPhien`. Phiên chưa kết thúc thì chưa xét — lượt sau.

### 4.3. Phiên đáng nhắc (`phienCanNhac`, Dart thuần)

Phiên đã kết thúc, `batDau > mốc` (mục 4.4), `trenMan ≥ kToiThieuTrenMan`, và **không** có bằng chứng nào sau:

1. **Tin / biên lai:** một hàng loại 20 **không phải dòng nhắc** (khoá không mang tiền tố `bienDong:phien|`), cùng nguồn
   (tham số `nguon` của deeplink), `createdAt ∈ [batDau − kTruocPhien, ketThuc + kSauPhienTin]`. `createdAt` của hàng
   loại 20 là mốc **sự kiện** (giờ trong tin / giờ in trên biên lai).
2. **Giao dịch đã ghi:** **mọi** giao dịch sống, `date ∈ [batDau − kTruocPhien, ketThuc + kSauPhienGiaoDich]`. Biết ví
   của nguồn (mục 5.4) → chỉ tính giao dịch có `walletId` hoặc `walletTransfer` là ví ấy; chưa biết → mọi giao dịch.
   Giao dịch ghi tay mang **giờ nhập** (`_selectedDate = DateTime.now()`); chọn ngày bằng lịch thì giờ về 00:00 và giao
   dịch ấy không được tính — chấp nhận. *(Sửa lúc viết kế hoạch, 2026-10-03: bản duyệt ghi "không tính giao dịch máy
   tạo — `laGhiChuMay`", nhưng hàm ấy đi qua `khoanVaoThongKe` nên loại cả **chuyển khoản người dùng tự ghi** — đúng
   thứ hay đi sau một phiên ngân hàng. Giao dịch máy tạo mang ngày của KỲ — tự trả hoá đơn `occurredAt: bill.dueDate`,
   trích mục tiêu `occurredAt: ky` — nên hầu như không rơi vào cửa sổ quanh một phiên.)*

Thứ tự trong lượt nhập là **bắt buộc**: `NhapBienDong` → `NhapBienLai` → `NhapPhienNganHang`, để tin và biên lai đang
chờ đã thành hàng trước khi xét bằng chứng 1.

### 4.4. Mốc

- **`daXetDen`** (Dart, theo **tài khoản**, `MocPhienStore`): chỉ xét phiên có `batDau > daXetDen`. Sau mỗi lượt nhập
  `daXetDen = ketThuc` lớn nhất trong các phiên **đã kết thúc** vừa xét (tạo dòng hay không). Đặt về **bây giờ** khi:
  bật công tắc · đăng xuất · lượt nhập thấy **thiếu quyền** (phiên lúc không có quyền không bao giờ được nhắc — cấp lại
  quyền không đổ một tràng dòng cũ).
- **`boDen`** (Kotlin, theo **máy**): nút *Không có giao dịch* ghi `boDen = ketThuc` lớn nhất của các phiên đang nằm
  trong thông báo. Lượt nhập Dart bỏ phiên có `ketThuc ≤ boDen`.
- Không lùi quá `kLuiToiDa` (lịch sử sử dụng của hệ thống cũng không giữ lâu).

### 4.5. Áp thử lên số đo 02–03/10

Gộp 3 phút: `18:30–18:31` (có tin) · `19:37–19:47` (có tin + biên lai — gồm cả phiên 19:41) · `20:17`, `20:23`, `11:32`
(< 20 s) · **`11:19–11:20`** (95 s, không bằng chứng) → **một dòng nhắc, và là nhắc oan**. Lần chuyển 19:46 không có
tin nằm trong phiên có tin khác → không nhắc (đã có biên lai).

### 4.6. Giới hạn

1. Một phiên có hai lần chuyển mà chỉ một lần có tin → lần kia **không được nhắc** (không có tín hiệu đếm số lần chuyển).
2. Xem số dư ≥ 20 s → nhắc oan; bỏ bằng một chạm.
3. Mở FlowMoney khi phiên chưa kết thúc rồi *Bỏ qua* (xoá) hàng tin của chính phiên ấy → vài phút sau phiên ấy có thể
   thành dòng nhắc (bằng chứng 1 đã bị xoá). Hiếm.
4. Tin đến **sau** khi thông báo nhắc đã bắn (trễ hơn 3 phút sau khi rời app) → thông báo nhắc là thừa; mở app thì dòng
   không được tạo nếu tin đã thành hàng.

## 5. Kiến trúc

### 5.1. Sơ đồ

```
Cài đặt (Dart) ─ bật/tắt ─► NotificationPrefs.nhacSauNganHang (+ dongYNhacSauNganHang)   [TÀI KHOẢN]
                            MocPhienStore.daXetDen                                         [TÀI KHOẢN]
NotificationScanner.start / resumed → _nhapBienDong:
  NhapBienDong → NhapBienLai → NhapPhienNganHang.nhap(idaccount)                           ← thứ tự bắt buộc
     datBat(cờ CỦA TÀI KHOẢN NÀY, daXetDen) — mỗi lượt, kể cả khi tắt (bẫy 3 của D1: cờ máy, công tắc tài khoản)
     cờ tắt → dừng · KenhPhienNganHang.coQuyen? (thiếu: daXetDen = bây giờ, dừng)
     → suKien(tu) → phienTuSuKien → phienCanNhac(hàng loại 20, giao dịch, ví theo nguồn, boDen)
     → insertAllIfAbsent hàng loại 20 → daXetDen → datBat(true, daXetDen) → huyNhac()
NotificationScanner.stop → NhapPhienNganHang.dongKhiDangXuat(id): daXetDen = bây giờ, datBat(false)

Kotlin (không chạm SQLite):
  PhienNganHang.kiem(ctx)  ← NhacGhiWorker (WorkManager, định kỳ 15 phút, unique "nhac_ghi")
                           ← BienDongListenerService.onNotificationPosted (SAU khi ghi hàng chờ D1) + onListenerConnected
     cờ máy "nhac_bat" ∧ "co_phien" ∧ quyền ∧ (≥ 60 s từ lần kiểm trước)
     → queryEvents(tu = max(daXetDen, boDen, daBaoDen, bây giờ − 1 ngày)) → dựng phiên (khớp tay §4.2)
     → bỏ phiên có tin/biên lai trong HÀNG CHỜ (bien_dong_cho.jsonl, bien_lai_cho.jsonl — cùng gói, trong cửa sổ)
     → bỏ phiên nếu FlowMoney có sự kiện `vao` sau batDau (để Dart xét)
     → còn phiên → thông báo im lặng (cập nhật tại chỗ), daBaoDen + tập nguồn đang báo
  NhacGhiReceiver ("Không có giao dịch") → boDen = daBaoDen, gỡ thông báo
```

### 5.2. Phần Android gốc

| Tệp | Vai |
|---|---|
| `PhienNganHang.kt` (mới) | `object`: hằng §4.1, `coQuyen` (AppOps `OPSTR_GET_USAGE_STATS` = `MODE_ALLOWED`), `suKien(tu)` (lọc gói theo dõi **trước** khi trả), `kiem(ctx)`, bắn / gỡ thông báo. **Chỉ Android 10+ (API 29)** — `ACTIVITY_RESUMED` / `ACTIVITY_PAUSED`, `unsafeCheckOpNoThrow`; máy cũ hơn coi như không có quyền |
| `NhacGhiWorker.kt` (mới) | `Worker` gọi `PhienNganHang.kiem`, luôn `Result.success()` |
| `NhacGhiReceiver.kt` (mới) | nút *Không có giao dịch*; `exported="false"`, intent tường minh |
| `BienDongListenerService.kt` | cuối `onNotificationPosted` (sau khi ghi hàng chờ) và `onListenerConnected`: `PhienNganHang.kiem` trên luồng nền, giãn ≥ 60 s. Danh sách gói = `DANH_SACH_TRANG` (một danh sách cho cả hai tính năng) |
| `MainActivity.kt` | kênh `flowmoney/phien_ngan_hang`: `coQuyen` · `moCaiDat` (`Settings.ACTION_USAGE_ACCESS_SETTINGS`, kèm `package:` rồi lùi về trang danh sách nếu máy không mở được) · `suKien(tu)` → `[{goi, lop, loai, luc}]` · `boDen` · `datBat(bat, daXetDen)` (bật: `enqueueUniquePeriodicWork(KEEP)`; tắt: huỷ work + gỡ thông báo) · `huyNhac` |
| `AndroidManifest.xml` | `PACKAGE_USAGE_STATS` (`tools:ignore="ProtectedPermissions"`), receiver |
| `app/build.gradle.kts` | `androidx.work:work-runtime-ktx:2.11.0` — đúng bản `background_downloader` 9.6.3 đang kéo vào (trùng bản, không xung đột). ⚠️ Thêm xong **dựng `--release` ngay** (bài học R8 01/10) |

Khoá trong `SharedPreferences("bien_dong")` (cùng tệp với cờ D1 và `co_phien`): `nhac_bat`, `nhac_da_xet_den`,
`nhac_bo_den`, `nhac_da_bao_den`, `nhac_nguon_dang_bao`, `nhac_kiem_luc`.

### 5.3. Phần Dart

| Tệp | Vai |
|---|---|
| `core/notification/phien_ngan_hang.dart` (mới, Dart thuần) | hằng §4.1, `SuKienSuDung`, `PhienNganHang`, `phienTuSuKien`, `phienCanNhac`, `kTienToKhoaPhien = 'bienDong:phien\|'`, `dedupeKeyPhien`, `deeplinkPhien`, `tieuDePhien` |
| `core/notification/kenh_phien_ngan_hang.dart` (mới) | `KenhPhienNganHang` + bản Android + `KenhPhienNganHangTrong` (web / test — không quyền, không làm gì; DI chọn theo nền tảng như `KenhBienDong`) |
| `core/notification/moc_phien_store.dart` (mới) | `daXetDen` theo tài khoản, khoá secure storage `nhac_phien:<idaccount>`; bản trong RAM cho test |
| `core/notification/nhap_phien_ngan_hang.dart` (mới) | `NhapPhienNganHang.nhap(idaccount)` (không bao giờ ném, `debugPrint` khi hỏng), `dongKhiDangXuat(idaccount)` |
| `core/notification/notification_scanner.dart` | `_nhapBienDong` thêm bước thứ ba; `stop` gọi `dongKhiDangXuat` (cạnh `tatDocMay`) |
| `core/notification/prefs/notification_prefs.dart` | `nhacSauNganHang`, `dongYNhacSauNganHang` (mặc định `false`; `toJson` / `fromJson` / `copyWith`) |
| `features/notification/presentation/pages/dong_y_nhac_sau_ngan_hang_page.dart` (mới) | màn đồng ý |
| `features/notification/presentation/pages/notification_settings_page.dart` | khối mới trong `_theBienDong()`, `_doiNhacSauNganHang(bool)` theo khuôn `_doiBienDong` |
| `features/transaction/domain/dien_san_bien_dong.dart` | `DienSanBienDong.phien` (giờ rời); `dongNguonBienDong` nói *"Dùng <nguồn> · …"* khi `phien != null` |
| `features/transaction/data/vi_theo_nguon_store.dart` | `docTheoNguon(idaccount, nguon)` (mục 5.4) |
| `features/transaction/presentation/widgets/the_chua_gan_danh_muc.dart` | chữ thẻ (mục 3.5) |
| `core/di/injection_container.dart` | đăng ký kênh, store, `NhapPhienNganHang`; truyền vào scanner |

### 5.4. Hợp đồng dữ liệu

- **Hàng loại 20 (dòng nhắc):** `kind = bienDongSoDu`, `dedupeKey = 'bienDong:phien|<nguồn>|<batDau yyyy-MM-ddTHH:mm>'`,
  `title = tieuDePhien`, `body = 'Chưa thấy giao dịch nào — chạm để ghi'`, `severity = info`, `subjectType = 'bienDong'`,
  `createdAt = batDau`, `deeplink = /add?date=<batDau ISO>&nguon=<nguồn>&phien=<ketThuc ISO>&khoa=<dedupeKey>`.
  Không `amount` / `huong` → `dauTuDeeplink` trả `null` (không tham gia gộp trùng của D1); không `anh` → không bị
  `NhapBienLai.donKhiDangXuat` xoá; luật giữ 30 ngày (`giuBienDong`) áp nguyên.
- **`docTheoNguon`:** cặp `<nguồn>|` (đuôi trống) đã nhớ → ví ấy; không có thì mọi cặp `<nguồn>|*` đã nhớ trỏ về **một**
  ví → ví ấy; còn lại `null`. Form dùng nó khi `doc(nguon, duoi)` trả `null` **và** hàng là dòng nhắc; cũng là "ví của
  nguồn" trong bằng chứng 2 của mục 4.3.
- **Kênh:** sự kiện `{goi: String, lop: String, loai: 'vao' | 'ra', luc: int ms}` — Kotlin chỉ trả gói trong
  `DANH_SACH_TRANG`; `datBat` nhận `{bat: bool, daXetDen: int ms}`.

## 6. Thông báo

| Thuộc tính | Giá trị |
|---|---|
| Kênh | `flowmoney_nhac_ghi`, tên *"Nhắc ghi sau khi dùng app ngân hàng"*, `IMPORTANCE_LOW` |
| Id | `PhienNganHang.ID_NHAC = 20261003` (khác `ID_TOM_TAT = 20260930` của D1) |
| Tiêu đề / chữ | *"FlowMoney"* / *"Vừa dùng <nguồn>[, <nguồn>] — có giao dịch cần ghi?"* |
| Hành động | *Không có giao dịch* → `NhacGhiReceiver` |
| Chạm | `MainActivity` + `EXTRA_MO_TU_TOM_TAT` (đường `MoTuTomTatBienDong` sẵn có) |
| Gỡ | lượt nhập Dart (`huyNhac`), nút, tắt công tắc, đăng xuất |
| Cập nhật | thêm nguồn thì đăng lại tại chỗ, `setOnlyAlertOnce(true)` |

Thông báo do Kotlin bắn nên không vào nhật ký B5a (như tóm tắt D1) — B5b không đề xuất tắt nó; công tắc ở Cài đặt là
đường tắt duy nhất.

## 7. Riêng tư

- Kotlin lọc sự kiện còn **3 gói theo dõi** (+ FlowMoney cho luật tự bỏ của chính Kotlin) **trước** khi dùng hay trả
  về; không lưu, không log app nào khác. Bản debug chỉ log **số đếm** (số sự kiện, số phiên, số phiên đáng nhắc).
- Dòng nhắc chỉ mang nguồn và giờ. Không gì đi lên server — hàng loại 20 là bảng cục bộ, không trong `SyncEntityType`.

## 8. Giao diện

Stitch trước khi dựng (người dùng xác nhận trên Stitch):
- **Màn mới:** *"Nhắc ghi sau khi dùng app ngân hàng"* — màn đồng ý, khuôn `bed4d292…` của D1.
- **Sửa màn có sẵn:** thẻ *Tự động hoá giao dịch* (`d42ce712…`) thêm khối mới; danh sách *Biến động* thêm một dòng
  nhắc mẫu; thẻ ở Sổ giao dịch (`e59155ff…`) đổi chữ.
- Dải nguồn của form chỉ đổi chữ (*"Dùng MB Bank · …"*) — không màn mới.

Kiểm 360 dp, một widget test dựng bằng `AppTheme.lightTheme` (bẫy 4.11).

## 9. Thứ tự làm và cổng dừng

1. **Thử chạy nền trên Realme (cổng).** Phần Kotlin (`PhienNganHang`, worker, móc vào D1, receiver, kênh) + bản debug;
   bật cờ máy bằng tay. Người dùng cấp quyền trong Cài đặt và dùng MB Bank thật vài lần (xem số dư ≥ 20 s). Đo:
   (a) `queryEvents` lúc FlowMoney ở nền có sự kiện MB Bank kịp không; (b) số lần worker chạy trong ~2 giờ — app ở nền /
   bị vuốt khỏi Recents / tắt màn hình; (c) đường D1: rời MB Bank tới lúc có thông báo; (d) nút *Không có giao dịch* khi
   FlowMoney đang bị đóng băng. **Trình bảng đo, người dùng quyết đường nào giữ**; cả hai hỏng → bỏ lớp thông báo, chỉ
   còn dòng trong app.
2. **Stitch** (mục 8), người dùng xác nhận.
3. **Dart thuần** (`phien_ngan_hang.dart`) theo TDD.
4. **`NhapPhienNganHang` + store + nối scanner / DI.**
5. **Giao diện:** khối cài đặt + màn đồng ý, chữ thẻ, form (`phien`, `docTheoNguon`).
6. **Dựng `--release`**, nghiệm thu máy thật (mục 10).
7. **Tài liệu + thông báo `CAN-LAM/`.**

## 10. Kiểm thử

- **Hàm thuần:** `phienTuSuKien` — gộp đúng biên 3 phút, phiên đang mở, hai lớp đổi chỗ cùng mili giây (thứ tự lộn),
  `ra` lẻ, sự kiện tương lai, nhiều gói xen nhau. `phienCanNhac` — từng bằng chứng (tin, biên lai, giao dịch), đúng mép
  cửa sổ (2 / 10 / 30 phút), ví đã biết / chưa biết, dòng nhắc cũ không là bằng chứng,
  `boDen`, `daXetDen`, ngưỡng 20 s, 7 ngày; chuyển khoản tự ghi **là** bằng chứng. Khoá, deeplink khứ hồi, `dienSanBienDongTuQuery` với `phien`,
  `dongNguonBienDong`, `tieuDePhien`.
- **`NhapPhienNganHang`:** cờ tắt / thiếu quyền → không dòng (thiếu quyền thì `daXetDen` = bây giờ); không tạo trùng khi
  gọi hai lần; mốc tiến đúng; gọi `huyNhac`; không bao giờ ném; `dongKhiDangXuat`. Scanner gọi nó **sau**
  `NhapBienLai` (ca canh thứ tự).
- **`docTheoNguon`**, `NotificationPrefs` khứ hồi JSON (hai trường mới; JSON cũ thiếu trường → `false`).
- **Widget:** công tắc mở màn đồng ý; *Không, cảm ơn* giữ tắt; đồng ý → `datBat(true)` + mở Cài đặt khi chưa có quyền;
  hai biến thể dòng quyền; chữ thẻ mới; form từ dòng nhắc (số tiền trống, 16 phím hiện, dải nguồn). 360 dp, đo vị trí.
- **Nối dây (đọc tệp):** manifest có quyền + receiver; tên kênh Dart ↔ `MainActivity`; hằng §4.1 Dart ↔ Kotlin;
  `BienDongListenerService` gọi `PhienNganHang.kiem` **sau** khi ghi hàng chờ.
- **Máy thật** (Realme; OnePlus nếu cắm): bật → đồng ý → cấp quyền → MB Bank ≥ 20 s không chuyển → thông báo im lặng →
  *Không có giao dịch* → không dòng; lặp lại → chạm thông báo → dòng → form → Lưu / Bỏ qua / vuốt; phiên có tin → không
  nhắc; rút quyền → dòng cài đặt báo, không dòng mới; đăng xuất → không còn gì; 0 tràn ở 360 dp; **bản release**.

## 11. Không làm trong bản này

- Học ngưỡng theo phản hồi (*Không có giao dịch* nhiều lần → tự nâng ngưỡng). Đo một tuần dùng thật rồi tính.
- Người dùng tự chọn app theo dõi; app ngân hàng chưa đo (VCB, TCB, BIDV) — thêm vào `kNguonTheoGoi` /
  `DANH_SACH_TRANG` khi đo được thì cả D1 lẫn bản này cùng có.
- Thông báo riêng từng phiên; thông báo có âm thanh.
- Đếm số lần chuyển trong một phiên; đọc màn hình app ngân hàng; tự tạo giao dịch (bất biến ④).
- iOS.

## 12. Rủi ro đã biết

- **ColorOS chặn cả hai đường nền** → không có thông báo; dòng trong app vẫn có. Bước 1 sinh ra để biết điều này trước.
- **Nhắc oan nhiều** khiến người dùng tắt hẳn tính năng — đo số dòng nhắc / số dòng thật sau một tuần dùng.
- **`queryEvents` trên một số máy trả sự kiện trễ** hoặc gộp — phép đo (a) bước 1.
- **Luật dựng phiên lệch giữa Dart và Kotlin** → thông báo hứa một dòng mà danh sách không có (hoặc ngược lại). Chặn bằng
  thuật toán ngắn, hằng khớp tay có test, và lượt nhập Dart luôn gỡ thông báo.
- **Quyền *Truy cập dữ liệu sử dụng* là quyền nhạy cảm** — màn đồng ý bắt buộc; thông báo cho backend (mục 9 bước 7)
  vì D1 từng phải qua backend duyệt.
