# Khoá ứng dụng bằng PIN + vân tay — thiết kế

**Ngày:** 2026-10-24 (phiên 4) · **Nhánh:** `TranQuangDat` · **Trạng thái:** người dùng duyệt từng phần trong phiên (Phần 1–4),
spec chờ người dùng đọc lại.
**Nguồn yêu cầu:** người dùng chọn *"Bảo mật tiếp"* (khoá app PIN / vân tay là mục còn lại của khối 🔒 mục 14
`docs/PROJECT_CONTEXT.md`) và yêu cầu *"tìm hiểu các app khác xem hệ thống bảo mật của mình đã đủ chưa"*.

## 1. Bối cảnh

- FlowMoney chưa có lớp khoá nào ngoài đăng nhập tài khoản. Ai cầm máy đang mở khoá (người nhà, bạn mượn máy) là thấy toàn bộ
  sổ tài chính. Ảnh trong Đa nhiệm đã trống từ đợt 3 (`setRecentsScreenshotEnabled(false)`, Android 13+); cờ cửa sổ bảo mật
  (`FLAG_SECURE`) người dùng **không** chọn (đợt 3) — chụp màn hình vẫn được.
- Tài liệu backend `docs/Functional-Mobile/01_XAC_THUC_VA_BAO_MAT.md` §2.3 tả "vân tay qua `local_auth`" như đã có — sai (đơn
  CAN-LAM 51). Spec này là lần đầu client làm tính năng ấy.
- Stitch: chưa có màn khoá nào. Màn *"Cài đặt & Bảo mật tài khoản"* `05fc2d46…` có hàng *"Bảo mật 2 yếu tố (MFA)"* (chưa làm, ngoài
  phạm vi spec này), không có khoá app.

## 2. Đối chiếu thị trường (khảo sát 2026-10-24, agent tra cứu; nguồn ở mục 10)

| Mẫu | Kết luận cho FlowMoney |
|---|---|
| PIN riêng + vân tay / khuôn mặt, PIN là đường lùi (Money Manager, Spendee, Wallet, Money Lover, MoMo) | Làm đúng mẫu này |
| App ghi chép: khoá là tuỳ chọn người dùng tự bật; thời điểm khoá theo thời gian ở nền (Money Manager "time lapse"; MoMo mặc định 5 phút, cho "mỗi lần mở") | Tự bật; người dùng chọn mức |
| Sai nhiều lần: chỉ ví điện tử công bố — trễ tăng dần rồi khoá (MoMo 3 → 30 s, 6 → 60 s…) | Chờ tăng dần, không xoá dữ liệu |
| Quên PIN: app ghi chép không công bố; ví điện tử khôi phục bằng xác minh chính chủ | Đăng xuất → đăng nhập lại bằng mật khẩu tài khoản |
| Ẩn số tiền hiếm (Wallet: mở lại tự hiện); không app nào công bố chặn chụp / che Đa nhiệm | Đa nhiệm đã che; ẩn số tiền ngoài phạm vi |
| OWASP MASVS-AUTH-2 / MASWE-0020: sinh trắc chỉ dựa callback đúng/sai là yếu; nên gắn phép mã hoá với khoá Keystore. MASWE-0022: thêm vân tay mới thì vô hiệu | Hướng B (mục 5) |

## 3. Quyết định người dùng chốt (2026-10-24, câu hỏi chọn được)

1. **Cách mở:** PIN riêng của FlowMoney + vân tay / khuôn mặt (không dùng khoá màn hình của máy — người nhà biết mã máy).
2. **Thời điểm khoá:** người dùng chọn *Tự khoá sau* — Ngay · 30 giây (**mặc định**) · 1 phút · 5 phút ở nền. Mở app từ đầu luôn khoá.
3. **Sai / quên:** chờ tăng dần (đếm giữ qua lần tắt app); *"Quên mã PIN?"* = đăng xuất rồi đăng nhập lại bằng mật khẩu tài khoản.
4. **Gói:** miễn phí cho mọi gói (không thêm quyền vào bảng quyền theo gói).
5. **Độ dài PIN:** 6 số.
6. **Sinh trắc:** hướng **B** — tự viết kênh Kotlin dùng `BiometricPrompt` của hệ điều hành, gắn khoá Keystore; **không** dùng gói
   `local_auth` (sẽ phải đổi `MainActivity` sang `FlutterFragmentActivity` + theme AppCompat, đụng G100; và chỉ dựa callback).

## 4. Hành vi người dùng thấy (Phần 1 — đã duyệt)

- **Bật:** Cá nhân → thẻ *Bảo mật & Tuỳ chọn* → hàng **"Khoá ứng dụng"** → trang Khoá ứng dụng: công tắc *Khoá FlowMoney*. Bật →
  đặt PIN 6 số (nhập hai lần) → nếu máy đủ điều kiện, hộp vân tay của hệ điều hành *"Chạm vân tay để bật"* tự hiện (chạm = bật vân
  tay; huỷ = chỉ dùng PIN — không có hộp hỏi riêng). Trang còn: *Đổi mã PIN*, công tắc *Vân tay*,
  ô *Tự khoá sau*. Tắt khoá / đổi PIN phải nhập PIN hiện tại.
- **Bị khoá:** màn khoá phủ toàn bộ app, kể cả toast: logo, *"Nhập mã PIN"*, 6 chấm, bàn phím số, nút vân tay, *"Quên mã PIN?"*.
  Bật vân tay thì hộp vân tay tự hiện khi màn khoá mở.
- **Khi nào:** mở app từ đầu (kể cả engine Flutter dựng lại khi tiến trình còn sống — G100) → khoá. Quay lại sau khi ở nền ≥ mức
  đã chọn → khoá. Hộp vân tay / hộp cấp quyền (chỉ `inactive`, không `hidden` / `paused`) không tính là rời app.
- **Chạm thông báo / tóm tắt D1 / nút "Trả ngay":** màn khoá hiện trước; router vẫn điều hướng tới trang đích **bên dưới** lớp phủ;
  mở khoá là thấy trang đó.
- **Sai PIN:** lần thứ 5 → chờ 30 giây; 6 → 1 phút; 7 → 5 phút; từ 8 → 15 phút mỗi lần. Đang chờ: bàn phím khoá + đếm ngược.
- **Quên PIN:** hộp hỏi lại → đăng xuất → đăng nhập lại cùng tài khoản thì dữ liệu máy giữ nguyên, khoá đã tắt (đặt lại nếu
  muốn). Cần mạng.
- **PIN gắn tài khoản trên máy;** đăng xuất là xoá. Màn Đăng nhập không có khoá app.
- **Không đổi:** chia sẻ biên lai (`NhanBienLaiActivity`, không giao diện), nút *"Hoãn 1 ngày"* (chạy nền), engine nền tự trả /
  tự trích, dịch vụ D1, ảnh Đa nhiệm (đã trống).
- **Giới hạn đã nói với người dùng:** phần lớn máy Android xếp khuôn mặt là sinh trắc *yếu* (Class 2) → không mở được khoá Keystore
  → chỉ **vân tay** dùng được trên các máy ấy; Android 7–8.1 (API 24–27, `minSdk` 24) chỉ có PIN; thêm vân tay mới trên máy thì
  phải nhập PIN rồi bật lại.

## 5. Cấu trúc mã (Phần 2 — đã duyệt; theo mục 4 và 8 `docs/KIEN_TRUC_CLIENT_APP.md`)

Mảng mới **`lib/features/khoa_app/`** (không đặt ở `core/` — danh sách 15 chủ đề cố định, quét 25; khoá app không phải hạ tầng).

| Tầng | Tệp | Việc |
|---|---|---|
| `domain/` | `luat_khoa_app.dart` | `enum TuKhoaSau { ngay, giay30, phut1, phut5 }` + `Duration`; `canKhoaKhiQuayLai({roiLuc, nay, muc})`; `thoiGianCho(soLanSai)` (< 5 → `null`; 5 → 30 s; 6 → 1 ph; 7 → 5 ph; ≥ 8 → 15 ph); `maPinHopLe` (đúng 6 chữ số ASCII) |
| `domain/` | `bam_ma_pin.dart` | PBKDF2-HMAC-SHA256 (gói `crypto` sẵn có, Dart thuần); `soSanhHangThoiGian` |
| `data/models/` | `cau_hinh_khoa_app.dart` | `salt`, `bam`, `soVong`, `tuKhoaSau`, `vanTay` (bản mã + IV + băm SHA-256 của bí mật, hoặc `null`), `soLanSai`, `choDen` — **không** có cờ `bat`: có cấu hình trong kho ⇔ khoá đang bật, *tắt* = xoá cấu hình |
| `data/` | `khoa_app_store.dart` | bọc `flutter_secure_storage`, khoá `khoa_app_<idaccount>`, JSON; đọc hỏng → `null` |
| `data/datasources/` | `kenh_sinh_trac.dart` | cổng kênh `flowmoney/sinh_trac` (interface + bản thật + bản `Noop` cho web / test) |
| `application/` | `khoa_app_service.dart` | `datPin` (đặt / đổi) · `kiemPin` (cập nhật đếm, ghi trước khi trả) · `tatKhoa` · `datTuKhoaSau` · `batVanTay` / `tatVanTay` / `moBangVanTay` · `xoaHet` (đăng xuất: mọi cấu hình `khoa_app_*` + mọi alias Keystore tiền tố `flowmoney_khoa_app_` — máy chỉ có một tài khoản đăng nhập mỗi lúc) |
| `presentation/bloc/` | `khoa_app_cubit.dart` (+ state) | `dangXet` · `tat` · `mo` · `khoa(soLanSai, choDen, coVanTay, loiNhan)`; nghe `AppLifecycleWatcher.stream` + `AuthBloc.stream` |
| `presentation/bloc/` | `cai_dat_khoa_app_cubit.dart` | trạng thái trang Khoá ứng dụng |
| `presentation/widgets/man_khoa/` | lớp phủ, màn khoá, tấm xác nhận quên PIN | widget của **một** trang |
| `presentation/widgets/` | chấm PIN, bàn phím số | dùng chung màn khoá + trang Đặt PIN (luật mục 8) |
| `presentation/pages/` | `khoa_app_page.dart`, `dat_ma_pin_page.dart` | cài đặt; đặt / đổi PIN |

**Chỗ nối:**
- `main.dart`: lớp phủ bọc **ngoài cùng** trong `MaterialApp.router(builder:)` (ngoài `AppToast`). Trạng thái đầu `dangXet` = lớp
  phủ **đặc** (màu nền splash) cho tới khi đọc xong cấu hình — mở lạnh không lọt khung nội dung nào.
- `core/router/app_router.dart`: `/settings/khoa-app`, `/settings/khoa-app/dat-pin?che=dat|doi|tat` (ngoài shell → `push`; cùng
  khuôn `/settings/change-password` — sửa khi lập kế hoạch, bản duyệt ghi `/profile/…`); hàng *Khoá ứng dụng* thêm vào thẻ
  *Bảo mật & Tuỳ chọn* của `profile/presentation/widgets/noi_dung_cai_dat.dart` (định nghĩa duy nhất, dùng chung tab Cá nhân và
  `/settings`).
- Lớp phủ nằm **ngoài** `Navigator` (trong `MaterialApp.builder`): `showDialog` sẽ hiện **dưới** lớp phủ và không có `Overlay` cho
  `Tooltip` → hộp *"Quên mã PIN?"* là tấm xác nhận vẽ **trong** màn khoá (Stitch *"Màn khoá - Xác nhận quên mã PIN"*), phím vân tay
  là `InkResponse` + `Semantics` chứ không `IconButton`.
- `core/auth/phien_dieu_phoi_that.dart`: `dongPhien` thêm hook xoá cấu hình + khoá Keystore của tài khoản (vẫn là chỗ duy nhất
  đóng phiên).
- `core/di/injection_container.dart`: store, cổng, service (lazy singleton). **`KhoaAppCubit` không đăng ký DI** — dựng ở
  `main.dart` (sống suốt app cùng lớp phủ), nghe **đúng** `AuthBloc` của app: `AuthBloc` trong DI là factory, `sl<AuthBloc>()` ra một
  bloc mới chưa đăng nhập.
- Kotlin: tệp mới `SinhTrac.kt`; `MainActivity` chỉ đăng ký thêm **một** kênh, **giữ** `FlutterActivity`; manifest `USE_BIOMETRIC`.
- Cấu hình khoá là **cục bộ** — không vào `SyncEntityType`, không lên server.

## 6. Vân tay, PIN, ca lỗi (Phần 3 — đã duyệt)

**Kênh `flowmoney/sinh_trac` (Kotlin, `android.hardware.biometrics.BiometricPrompt`, API ≥ 28):**
- `trangThai()` → `{ hoTro: bool (API ≥ 28 và có phần cứng sinh trắc mạnh), daDangKy: bool }`.
- `bat(idaccount, biMatB64)` → tạo khoá AES-256-GCM trong `AndroidKeyStore`, alias `flowmoney_khoa_app_<idaccount>`:
  `setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`; API ≥ 30
  `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)`, API 28–29 xác thực mỗi lần dùng. Khởi `Cipher` ENCRYPT → hộp
  *"Chạm vân tay để bật"* với `CryptoObject` → mã hoá bí mật → trả `{ banMa, iv }`.
- `mo(idaccount, banMa, iv)` → khởi `Cipher` DECRYPT; `KeyPermanentlyInvalidatedException` → trả mã `VO_HIEU` **không** hiện hộp;
  ngược lại hộp *"Mở FlowMoney"*, nút phụ *"Dùng mã PIN"* → giải mã → trả `{ biMat }`.
- `xoaHet()` → xoá **mọi** alias tiền tố `flowmoney_khoa_app_` (không có lệnh xoá theo tài khoản — tắt khoá, tắt vân tay, `VO_HIEU`
  và đăng xuất đều dùng lệnh này; máy chỉ có một tài khoản đăng nhập mỗi lúc).
- Mã lỗi: `HUY` (người dùng huỷ / chọn PIN), `VO_HIEU`, `TAM_KHOA` (hệ điều hành khoá sinh trắc), `KHONG_HO_TRO`, `LOI`.

**Dart:** bí mật 32 byte `Random.secure()`; cất **bản mã + IV + SHA-256(bí mật)**, không bao giờ cất bí mật. Mở: SHA-256(bí mật
trả về) so hằng thời gian với băm đã cất → khớp mới mở. `VO_HIEU` → tắt vân tay, gọi `xoaHet`, câu *"Vân tay trên máy đã thay đổi —
nhập mã PIN rồi bật lại trong Cài đặt"*. `HUY` → ở lại màn PIN. `TAM_KHOA` → *"Thử lại sau, hoặc nhập mã PIN"*. Sai vân tay
**không** cộng vào đếm sai PIN.

**PIN:** đặt = nhập 6 số, nhập lại khớp; salt 16 byte ngẫu nhiên; PBKDF2 với `soVong` chọn bằng đo trên Realme (nhắm 0,2–0,3 s),
chạy trong isolate; `soVong` cất cùng băm (đổi số vòng về sau không vỡ PIN cũ). Kiểm sai: tăng `soLanSai`, tính `choDen` theo
`thoiGianCho`, **ghi kho trước** khi trả kết quả. Đúng (PIN hoặc vân tay) → `soLanSai = 0`, `choDen = null`. Giới hạn chấp nhận:
`choDen` theo giờ máy — chỉnh giờ máy rút được thời gian chờ.

**Phiên:** *"Quên mã PIN?"* → hộp *"Đăng xuất để đặt lại mã PIN? …"* → `LogoutRequested` → `dongPhien` xoá cấu hình + alias.
`AuthUnauthenticated` (tự đăng xuất / bị cưỡng chế) → cubit về `tat`, lớp phủ gỡ. Mở app khi **chưa** đăng nhập (không token —
`main()` không gửi `AuthCheckRequested`, `AuthBloc` đứng ở `AuthInitial`) → `tat` ngay, không chờ phiên (preflight P2, 2026-10-24). `AuthSuccess` của tài khoản khác → nạp cấu hình
của tài khoản đó. Đọc kho hỏng → coi như **chưa bật** (token cùng kho; kho hỏng thì phiên đã hỏng — khớp `AuthBloc`).

**Vòng đời:** ghi `roiLuc` ở trạng thái `hidden` / `paused` đầu tiên (không ở `inactive`); `resumed` → `bat` ∧
`canKhoaKhiQuayLai(roiLuc, now, muc)` → `khoa`. `TuKhoaSau.ngay` = mọi lần `paused` / `hidden`.

## 7. Giao diện, kiểm thử, nghiệm thu (Phần 4 — đã duyệt)

**Stitch trước khi viết giao diện** — đã tạo 2026-10-24 tối (bốn lượt gọi timeout, màn hiện sau ~40 phút; không gọi lại):
(1) *Màn khoá ứng dụng (2 biến thể)* `2f0896e011874b4e84c8217c4f56346e`; (2) *Đặt mã PIN (3 bước)*
`34c3cadedf024a62a7865669f310bc15`; (3) *Khoá ứng dụng - Cài đặt (2 biến thể)* `129c2d77d97d4cff9322d05be9142a92`; (4) *Cá nhân -
Hàng Khoá ứng dụng* `3469341eadbb47629947a4757c507ffb` (màn vẽ lại cả ba hàng của thẻ — app giữ kiểu hàng hiện có, chỉ thêm hàng
+ viên *Đang bật*); (5) *Màn khoá - Xác nhận quên mã PIN* `aa95222fc5bc40c3a2c329d75b112830`. Số đo từng màn ở bảng Stitch của kế
hoạch thi công (`docs/superpowers/plans/2026-10-24-khoa-app-pin-sinh-trac.md`, gitignore).

**Test (TDD, thử bản sai cho đỏ):**
- domain: bảng `TuKhoaSau`, `thoiGianCho` ở ca biên 4 / 5 / 8, PBKDF2 khớp vector RFC 7914 §11, `maPinHopLe`;
- service (kho + kênh giả): đặt / đổi / tắt; lần sai thứ 5 có `choDen`; đếm ghi trước khi trả; `VO_HIEU` tự tắt vân tay; xoá theo
  tài khoản;
- cubit (vòng đời + đồng hồ giả): mở lạnh → `khoa`; ở nền < mức → `mo`; ≥ mức → `khoa`; `inactive` không khoá; đăng xuất → `tat`;
- widget (`AppTheme.lightTheme`, 360 × 800): lớp phủ che và chặn chạm; điều hướng bên dưới rồi mở khoá thấy trang đích; bàn
  phím không tràn; `dangXet` không lộ nội dung;
- nối dây (đọc `SinhTrac.kt`, `MainActivity.kt`, manifest): `setUserAuthenticationRequired`, `setInvalidatedByBiometricEnrollment`,
  sinh trắc mạnh, `CryptoObject`; `MainActivity` đăng ký kênh và vẫn `: FlutterActivity()`; `USE_BIOMETRIC`.

**Nghiệm thu Realme (vân tay):** bật / tắt; mở lạnh; ở nền 30 s; chạm thông báo khi khoá; sai 5 lần; mở bằng vân tay; thêm vân
tay mới trên máy → vân tay tự tắt (người dùng thao tác); *Quên mã PIN?* → đăng xuất (đăng nhập lại cần backend `PersonFinance` +
`DATA_ENCRYPTION_KEY` dev + mật khẩu postgres của người dùng); soát G100 (Back hai lần; gỡ khỏi Đa nhiệm).

**Tài liệu:** `docs/KHOA_APP_FEATURE.md` (quyết định + bẫy), hàng *"Đụng vào khoá app"* trong `CLAUDE.md`, khối mục 14
`PROJECT_CONTEXT.md`, cập nhật đơn CAN-LAM 51 (*"chưa có khoá PIN"* → đã có).

## 8. Ngoài phạm vi

Ẩn số tiền; 2FA / MFA tài khoản (hàng Stitch có sẵn); danh sách thiết bị / đăng xuất từ xa; mã hoá SQLite; khoá khi tắt màn hình
(ngoài vòng đời app); miễn khoá khi rời app do chính app mở (camera, chọn ảnh, trang PayOS) — người dùng chỉnh *Tự khoá sau*;
iOS (Face ID) — chưa có máy Mac.

## 9. Thứ tự với việc khác

Làm trên `flutter_secure_storage` 9.2.4 hiện tại. Nâng lên 10 / 11 trình riêng sau: changelog 11.0.0 ghi dữ liệu cất bằng thuật
toán cũ *"will be unusable"*, phải qua 10 (`migrateOnAlgorithmChange`) trước — nếu không mất token (bị đăng xuất) và mọi thứ trong
kho, kể cả cấu hình khoá app.

## 10. Nguồn khảo sát

Money Lover `u.moneylover.me/beecost_playstore`, `note.moneylover.me/video-tutorials-for-money-lover/`; Money Manager
`help.realbyteapps.com/hc/en-us/articles/360043501233-How-to-use-passcode`; Wallet
`support.budgetbakers.com/hc/en-us/articles/7181476227474-Setup-Fingerprint-or-Face-ID-recognition`; Spendee
`www.spendee.com/bank-connect`; MoMo `www.momo.vn/hoi-dap/cai-dat-xac-thuc-mat-khau-khi-mo-man-hinh-ung-dung`,
`www.momo.vn/hoi-dap/tai-khoan-cua-toi-bi-khoa`; Android `developer.android.com/identity/sign-in/biometric-auth`;
OWASP `mas.owasp.org/MASVS/controls/MASVS-AUTH-2/`, `mas.owasp.org/MASWE/MASVS-AUTH/MASWE-0020/`. Một số trang trợ giúp chặn tải
trực tiếp (403) — agent trích qua đoạn trích của kết quả tìm kiếm.
