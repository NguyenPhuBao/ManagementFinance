# Khoá ứng dụng bằng PIN 6 số + vân tay — tài liệu bàn giao

> **Trạng thái (2026-10-25):** ✅ **mã xong, đã qua review toàn nhánh và đợt sửa cuối** — 12 task của kế hoạch
> `docs/superpowers/plans/2026-10-24-khoa-app-pin-sinh-trac.md` (gitignore) + đợt sửa sau review (C1, I1–I4, mục nhỏ). Dải commit
> `a0c6dacf..393e626f` (30 commit, đếm 2026-10-25 trước commit tài liệu này: 22 commit thi công `a0c6dacf..92b69200` · `f6699e64`
> tài liệu Task 13 · 7 commit đợt sửa `5fa1b69c` `29405da5` (C1) · `7cef81df` (I2) · `d5cfb994` (I3) · `62cad490` (I4) · `fb4f245b` (I1) ·
> `393e626f` (mục nhỏ)).
> 🚧 **CHƯA nghiệm thu trên máy thật** — người dùng chốt *"nghiệm thu thì để phiên sau"*. Mọi thứ dưới đây là **mã + test**; chưa
> ai nhìn lớp khoá trên Realme. Checklist ở mục **9** (phải làm đúng thứ tự: chép CSDL Realme → đo số vòng PBKDF2 trên release →
> nghiệm thu; **không đăng xuất ở đầu buổi**). ⚠️ **`kSoVongMacDinh` = 30.000 là số TẠM của kế hoạch, chưa đo trên bản release**
> (mục 9, bước B). ⚠️ **Hai thứ chỉ máy thật chứng minh được:** đồng hồ khởi động `CLOCK_BOOTTIME` qua `dart:ffi` (host Windows của test
> luôn trả `null`) và C1 (lớp che không lộ khung nào lúc chuyển sang màn Đăng nhập — cần quay màn hình).
> Spec: `docs/superpowers/specs/2026-10-24-khoa-app-pin-sinh-trac-design.md` (đã sửa theo thiết kế cuối 2026-10-25).
> Mảng mã: `src/Client-app/lib/features/khoa_app/` (21 tệp, 2.260 dòng, đếm 2026-10-25) + `android/…/SinhTrac.kt`.

## 1. Người dùng thấy gì

- **Bật:** Cá nhân → thẻ *Bảo mật & Tuỳ chọn* → hàng **Khoá ứng dụng** (viên xanh *Đang bật* khi đã bật) → trang Khoá ứng dụng →
  công tắc *Khoá FlowMoney* → đặt PIN 6 số (nhập hai lần) → nếu máy đủ điều kiện, hộp vân tay hệ thống *"Chạm vân tay để bật"*
  **tự hiện** (chạm = bật vân tay; huỷ = chỉ dùng PIN, không có hộp hỏi riêng). Trang còn: *Đổi mã PIN*, công tắc *Vân tay*, ô
  *Tự khoá sau* (Ngay khi rời app · 30 giây **mặc định** · 1 phút · 5 phút). Tắt khoá / đổi PIN đòi PIN hiện tại.
- **Bị khoá:** màn khoá phủ toàn app kể cả toast: logo, *"Nhập mã PIN"*, 6 chấm, bàn phím số, nút vân tay, *"Quên mã PIN?"*. Bật
  vân tay thì hộp vân tay tự hiện **một lần** mỗi lần khoá.
- **Khi nào khoá:** mở app từ đầu (kể cả engine Flutter dựng lại khi tiến trình còn sống — G100) · quay lại sau khi ở nền ≥ mức đã
  chọn (đo bằng **hai** đồng hồ — giờ tường và đồng hồ khởi động, mục 5 bẫy 23). Hộp vân tay / hộp cấp quyền (`inactive`) không tính là rời app.
- **Chạm thông báo / tóm tắt D1 / nút Trả ngay khi đang khoá:** router vẫn điều hướng tới trang đích **bên dưới** lớp phủ; mở khoá
  là thấy trang đó.
- **Sai PIN:** lần 5 → chờ 30 giây; 6 → 1 phút; 7 → 5 phút; từ 8 → 15 phút mỗi lần. Đang chờ: phím số mờ + *"Thử lại sau mm:ss"*;
  **vân tay vẫn mở được**.
- **Quên PIN:** tấm xác nhận → *Đăng xuất* → đăng nhập lại bằng **mật khẩu tài khoản** thì khoá đã tắt (đặt lại nếu muốn), dữ liệu
  máy giữ nguyên. Cần mạng. ⚠️ Đăng nhập lại bằng **tài khoản khác** thì dữ liệu cục bộ của tài khoản cũ bị dọn (mục 1b).
- **Giới hạn đã nói với người dùng:** khuôn mặt phần lớn máy Android là sinh trắc *yếu* (Class 2) → không mở được khoá Keystore →
  chỉ **vân tay**; Android 7–8.1 (API 24–27, `minSdk` 24) chỉ PIN; thêm vân tay mới trên máy thì vân tay của app tự tắt, phải nhập
  PIN rồi bật lại.
- **Không đổi:** chia sẻ biên lai (`NhanBienLaiActivity`, không giao diện), nút *Hoãn 1 ngày* (chạy nền), engine nền tự trả / tự
  trích, dịch vụ D1. Khoá ứng dụng **miễn phí mọi gói** (không có trong bảng quyền theo gói).

## 1b. Mô hình đe doạ và giới hạn (ghi để phiên sau không hứa quá)

Khoá chặn **người cầm một chiếc máy đang mở khoá** (người nhà, bạn mượn máy) xem sổ tài chính qua giao diện app. Nó **không** phải
lớp bảo vệ dữ liệu khi kho bị đọc ra:

- **Khoá là lớp GIAO DIỆN.** SQLite của app **không mã hoá** — root máy hoặc công cụ pháp y đọc thẳng `flowmoney.db`; PIN 6 số + PBKDF2
  không bảo vệ dữ liệu khi tệp bị đọc ra. (Mã hoá SQLite nằm ngoài phạm vi — spec mục 8.)
- **Nội dung thông báo** FlowMoney trên khay thông báo / màn khoá của máy vẫn hiện (khoá app không che thông báo hệ điều hành).
- **Chụp / ghi màn hình được** — không `FLAG_SECURE` (người dùng không chọn, đợt 3).
- **Ảnh trong Đa nhiệm chỉ trống từ Android 13** (`setRecentsScreenshotEnabled(false)`); API 24–32 vẫn có ảnh trang cuối.
- **Khuôn mặt Class 2 không dùng được** (không mở được khoá Keystore); **API 24–27 chỉ PIN**.
- **Giờ máy:** `choDen` (thời gian chờ sau sai PIN) tính theo giờ máy — chỉnh giờ rút được thời gian chờ (spec chấp nhận). Riêng **tự
  khoá** đã chặn bằng đồng hồ khởi động (bẫy 23): chỉnh giờ lùi không vượt được khoá.
- **Đọc kho hỏng:** mở lạnh = *chưa bật* (token cùng kho; kho hỏng thì phiên đã hỏng — spec chấp nhận); nhưng sau đó màn khoá /
  kiểm PIN đọc **nghiêm ngặt** và hỏng thì **vẫn khoá** (bẫy 6).
- **Hệ quả thiết kế (Ruling T12 + I4):** cấu hình PIN xoá ở **mọi lần đăng nhập bằng mật khẩu** (không chỉ sau Quên PIN) — kể cả
  sau hết phiên, cưỡng chế đăng xuất, đổi mật khẩu (`change_password_page` → `LogoutRequested`). Người dùng có thể tưởng app còn khoá;
  *chưa có dòng nhắc "khoá đã tắt"* (M11, hỏi người dùng — mục 8). Băm PIN (PBKDF2, trong kho `flutter_secure_storage`) nằm lại trên máy
  từ lúc đăng xuất tới lần đăng nhập mật khẩu kế — chỉ đọc được khi root.
- **Quên PIN rồi đăng nhập TÀI KHOẢN KHÁC:** `moPhienCucBo` → `purgeDataForOtherAccounts` dọn dữ liệu cục bộ của tài khoản cũ — phần
  **chưa đồng bộ mất**, lịch sử thông báo / dữ liệu học gợi ý (không có trên server) mất. Tấm xác nhận Quên PIN chỉ nói vế "đăng nhập
  lại đúng tài khoản".

## 2. Quyết định

**Sáu quyết định người dùng chốt (2026-10-24, spec mục 3):**

| # | Quyết định |
|---|---|
| 1 | PIN **riêng** của FlowMoney + vân tay / khuôn mặt — không dùng khoá màn hình của máy (người nhà biết mã máy) |
| 2 | *Tự khoá sau* do người dùng chọn: Ngay · 30 giây (mặc định) · 1 phút · 5 phút. Mở app từ đầu luôn khoá |
| 3 | Sai → chờ tăng dần, đếm giữ qua lần tắt app, **không xoá dữ liệu**; quên = đăng xuất rồi đăng nhập lại bằng mật khẩu |
| 4 | Miễn phí mọi gói |
| 5 | PIN đúng 6 số |
| 6 | Sinh trắc hướng **B**: tự viết kênh Kotlin dùng `BiometricPrompt` gắn khoá Keystore; **không** `local_auth` (sẽ phải đổi `MainActivity` sang `FlutterFragmentActivity` + theme AppCompat — đụng G100 — và chỉ dựa callback đúng / sai, yếu theo OWASP MASVS-AUTH-2) |

**Quyết định thi công (từ ledger SDD, 2026-10-24 → 25) — mỗi dòng: quyết định · vì sao:**

- **Cấu hình có mặt ⇔ khoá bật; tắt = xoá cấu hình** (không cờ `bat`) · bớt một trạng thái có thể lệch.
- **Mảng `features/khoa_app/`, không đặt ở `core/`** · danh sách 15 chủ đề `core/` cố định (quét 25); khoá app không phải hạ tầng.
- **`KhoaAppCubit` dựng ở `main.dart`, không đăng ký DI** · `AuthBloc` trong DI là factory, `sl<AuthBloc>()` ra bloc mới chưa đăng nhập.
- **Route `/settings/khoa-app` (+ `/dat-pin?che=dat|doi|tat`)**, không `/profile/…` · khuôn `/settings/change-password`; trang mở từ thẻ Cá nhân là route ngoài shell → `push`.
- **Tấm xác nhận Quên PIN vẽ trong màn khoá**, phím vân tay là `InkResponse` + `Semantics` · lớp phủ ngoài `Navigator` không có `Overlay` (xem bẫy 1).
- **Băm PIN = PBKDF2-HMAC-SHA256 Dart thuần** trên gói `crypto` sẵn có, chạy qua `compute` (chạy được cả web); `soVong` cất cùng băm nên đổi `kSoVongMacDinh` không vỡ PIN cũ · không thêm gói pub.
- **Khoá chấm PIN theo chỉ số** `cham-day-$i` / `cham-rong-$i` + finder `chamPin()` ở helper (P1) · hai loại chấm trùng khoá thì test mù.
- **`lanKiem` thay khung `dangKiem` trung gian** (P13) · xem bẫy 10.
- **Đăng xuất chỉ xoá alias Keystore; cấu hình PIN xoá khi đăng nhập bằng mật khẩu** (Ruling T12, đổi thân spec 2026-10-25; **I4 cùng ngày: chuyển hook từ `sauDangNhap` sang `sauXacThucMatKhau`, gọi ngay sau `login()`**) · xem bẫy 5.
- **`khiQuenPin` chỉ `add(LogoutRequested())`** · đường lùi `tatKhoa` sau `AuthUnauthenticated` bị gỡ cùng `application/xoa_khoa_sau_dang_xuat.dart` khi Ruling T12 đổi.
- **`xoaHet` của kho: mỗi `delete` một `try` riêng**, `readAll` hỏng thì nuốt · **đăng nhập** không được hỏng vì khoá app (service bọc thêm `try`); đường lùi cho `readAll` hỏng là `datLaiSauDangNhap` xoá thẳng theo khoá.
- **Kho phân biệt vắng / hỏng** (I2, 2026-10-25): `doc` nuốt lỗi → `null` (đường mở lạnh: hỏng = chưa bật, spec mục 6); `docNghiemNgat` vắng → `null`, hỏng / JSON lạ / hình lạ → **ném** (màn khoá, `kiemPin`, `_mo`, `napLai`) · "kho hỏng ⇒ mở bằng chuỗi bất kỳ" là lỗ hổng chiều mở.
- **`kiemPin` không có cấu hình → đúng** (`dung: true`) · vắng thật = chưa bật; còn đọc hỏng thì ném (bẫy 6).
- **Một định nghĩa "đang chờ"** `conCho(choDen, nay)` + `chuDemNguoc(Duration)` ở `domain/luat_khoa_app.dart` · trang PIN, màn khoá và service từng chép riêng và đã lệch (T10 review).
- **Câu "Thử lại sau" hiện khi `choDen` còn ở tương lai**, không chỉ khi `dangCho` · lần sai thứ 5 trả `dangCho=false` kèm `choDen` (T10).
- **Kho hỏng khi kiểm / đặt PIN có câu riêng** (hằng ở `khoa_app_state.dart`): `kCauKhongKiemDuoc` *"Không kiểm được mã PIN — thử lại"* (không nói "không đúng", không tính sai), `kCauKhongLuuPin` *"Không lưu được mã PIN — thử lại"*, `kCauKhoAppKhongLuu` *"Không lưu được cài đặt khoá — thử lại"*; `kCauSaiPin` một hằng; màu chữ phụ `kXamChuKhoaApp` (`presentation/widgets/mau_khoa_app.dart`) thay bốn chỗ chép · nói sai với người dùng là lỗi.
- **`resumed` khoá ngay bằng bản RAM rồi làm tươi từ kho** (P9, chỉ emit khi còn cùng `lanKhoa`) · không để lọt khung nội dung, nhưng `soLanSai` / `choDen` ở kho có thể mới hơn.
- **`_daBietPhien` + `id == _id` → bỏ qua** · `verifySession` phát lại `AuthSuccess` (bẫy 3).
- **`ExcludeFocus` + `ExcludeSemantics` bật theo cờ** (P5/T9 review) · bẫy 1; cờ che gồm cả `KhoaAppDangRoi`.
- **Cờ `_dangLam` ở `CaiDatKhoaAppCubit`** (chống chạm đôi) · bẫy 11; I3 thêm cờ `_dangMoTrangPin` + `_moMotLan` ở `KhoaAppPage` cho công tắc và hàng *Đổi mã PIN*.
- **`DatMaPinPage` chế độ `dat` mà kho đã có cấu hình → chạy như `doi`** (hỏi PIN hiện tại, tiêu đề *"Đổi mã PIN"*; M4) · `datPin` ghi đè PIN không cần PIN cũ là lối vòng luật "đổi PIN phải nhập PIN hiện tại".
- **Tấm Quên PIN khoá cả hai nút + lớp mờ sau lần *Đăng xuất* đầu** (M9, `TamXacNhanQuenPin` là StatefulWidget) · chạm đôi = hai `LogoutRequested`.
- **Phép rẽ phiên đầu của `main.dart` là hàm thuần** `phienDauChoKhoaApp` + `laTrangThaiPhienRo` (`presentation/state/phien_dau_khoa_app.dart`, M10) · `main.dart` không có test; năm ca phủ `AuthSuccess` · `AuthUnauthenticated` · `AuthInitial` + `/login` · `AuthInitial` + route khác · `AuthChecking`.
- **`USE_FINGERPRINT` `maxSdkVersion=29`** (P10); **build `--release` bắt buộc trước commit Task 5** (P11).
- **Phím số: `ExcludeSemantics` trong `_Phim`**, không `excludeSemantics: true` ở `Semantics` ngoài (cắt tap) · TalkBack từng đọc "7\n7".
- **Màn khoá căn giữa theo Stitch** (Padding ngang 24 cho dòng phụ / câu lỗi) · bản đầu lệch trái (dx 133 thay 180 ở 360 × 800).
- **Bỏ mọi `runAsync` ở bốn widget test** (P14) · bẫy 15.

## 3. Luồng

```
Bật      Trang Khoá ứng dụng → công tắc → /settings/khoa-app/dat-pin?che=dat → KhoaAppService.datPin (salt 16 B, PBKDF2, ghi kho)
         → CaiDatKhoaAppCubit.sauDatPin (nạp lại trang) rồi batVanTay (nếu máy hỗ trợ + đã đăng ký + CHƯA bật): Kotlin bat → hộp "Chạm vân tay để bật"
         → cất {banMa, iv, bamBiMat}; KhoaAppCubit.napLai() (đọc lại cấu hình, KHÔNG khoá)
Khoá     (a) nhanPhien(id) lần đầu của phiên: có cấu hình → KhoaAppKhoa; không → KhoaAppMo(daBat:false)
         (b) vòng đời: hidden/paused đầu tiên ghi _roiLuc (giờ tường) + _roiKhoiDong (đồng hồ khởi động);
             resumed + canKhoaKhiQuayLai(roiLuc, nay, muc, oNenTheoKhoiDong) → KhoaAppKhoa
Mở PIN   ManKhoa gõ đủ 6 số → cubit.nhapPin → service.kiemPin: chờ? → dangCho (không băm) ; đúng → soLanSai=0 → KhoaAppMo ;
         sai → soLanSai+1, choDen=thoiGianCho(n), GHI KHO RỒI MỚI trả ; đọc/ghi kho hỏng → ném → giữ Khoa + kCauKhongKiemDuoc
Mở vân tay  ManKhoa tự gọi moBangVanTay mỗi lanKhoa → Kotlin mo → SHA-256(biMat) so hằng thời gian với bamBiMat → mở
         (VO_HIEU → tatVanTay + xoaHet + câu "Vân tay trên máy đã thay đổi…"; HUY → ở lại; sai vân tay KHÔNG cộng soLanSai)
Quên PIN Tấm xác nhận trong ManKhoa → LogoutRequested → AuthBloc → dongPhien (xoaVanTayHet: CHỈ alias Keystore) → logout() (POST, xoá token sau)
         → AuthUnauthenticated → cubit.nhanPhien(null): đang Khoa/DangXet có tài khoản → KhoaAppDangRoi (lớp ĐẶC) cho tới khi
         TheoDoiRouteCongKhai.dungYenOCongKhai (route trên cùng công khai + hiệu ứng vào xong; van an toàn 3 s) → KhoaAppTat (lớp phủ gỡ, màn Đăng nhập)
         (Quên PIN: router đã sang /login từ AuthLoading → tín hiệu đã true → Tat ngay ; cưỡng chế đăng xuất khi đang khoá: chưa yên → DangRoi → Tat)
Đăng nhập lại bằng MẬT KHẨU → AuthBloc._onLoginSubmitted: login() trả id hợp lệ → PhienDieuPhoi.sauXacThucMatKhau(id) → datLaiSauDangNhap(id)
         xoá cấu hình (id + mọi tài khoản) + alias → moPhienCucBo → batThoiGianThuc → batDongBo(cho) → sauDangNhap → AuthSuccess
         → cubit nhanPhien(id) → không cấu hình → KhoaAppMo(daBat:false)
Đổi tài khoản  AuthSuccess của id khác → nhanPhien(id mới) → KhoaAppDangXet (lớp đặc) → đọc cấu hình của id đó
Mở app chưa đăng nhập  main.dart: phienDauChoKhoaApp(AuthInitial, '/login') → nhanPhien(null) → KhoaAppTat ngay (bẫy 4)
```

## 4. Bản đồ tệp → việc

`src/Client-app/lib/features/khoa_app/` (đếm 2026-10-25: 21 tệp, 2.260 dòng):

| Tệp | Việc |
|---|---|
| `domain/luat_khoa_app.dart` | `TuKhoaSau` (+ `macDinh`, `tuTen`), `maPinHopLe`, `canKhoaKhiQuayLai` (**ba vế**: giờ tường lùi ∨ giờ tường ≥ mức ∨ đồng hồ khởi động âm / ≥ mức), `thoiGianCho`, **`conCho`**, **`chuDemNguoc`**, `kDoDaiPin`, `kSaiBatDauCho` |
| `domain/bam_ma_pin.dart` | `pbkdf2HmacSha256`, `bamMaPin`, `soSanhHangThoiGian`, `kSoVongMacDinh` (**30000, chưa đo**) |
| `data/models/cau_hinh_khoa_app.dart` | `CauHinhKhoaApp` (salt, bam, soVong, tuKhoaSau, vanTay, soLanSai, choDen) + `VanTayDaBat` |
| `data/khoa_app_store.dart` | `KhoaAppStore` + bản `flutter_secure_storage` (khoá `khoa_app_<idaccount>`) + `InMemoryKhoaAppStore`; `doc` không ném (hỏng = `null`), **`docNghiemNgat`** ném khi hỏng, `ghi` ném |
| `data/datasources/kenh_sinh_trac.dart` | cổng kênh `flowmoney/sinh_trac` (`trangThai · bat · mo · xoaHet`), `LoiSinhTrac`, bản `KenhSinhTracTrong` (web / test — chỉ PIN) |
| `data/datasources/dong_ho_khoi_dong*.dart` | `docThoiGianKhoiDong()` — `dong_ho_khoi_dong.dart` (cổng, import có điều kiện `if (dart.library.ffi)`) · `_ffi.dart` (`clock_gettime(CLOCK_BOOTTIME = 7)` qua `DynamicLibrary.process()`, chỉ Android / Linux, mọi lỗi → `null`) · `_stub.dart` (`null`) |
| `application/khoa_app_service.dart` | `datPin · kiemPin · tatKhoa · datTuKhoaSau · batVanTay · tatVanTay · moBangVanTay · xoaVanTayHet · datLaiSauDangNhap` + `doc` / `docNghiemNgat` |
| `presentation/bloc/khoa_app_cubit.dart` + `khoa_app_state.dart` | trạng thái cả app: `KhoaAppDangXet · DangRoi · Tat · Mo(daBat) · Khoa(coVanTay, soLanSai, choDen, loiNhan, dangKiem, lanKhoa, lanKiem)`; ctor nhận `dungYenOCongKhai` (`ValueListenable<bool>?`), `vanAnToanRoi` (3 s), `dongHoKhoiDong` |
| `presentation/bloc/cai_dat_khoa_app_cubit.dart` | trạng thái trang Khoá ứng dụng, cờ `_dangLam` |
| `presentation/widgets/man_khoa/` | `lop_khoa_app.dart` (lớp phủ), `man_khoa.dart`, `tam_xac_nhan_quen_pin.dart` |
| `presentation/widgets/` | `cham_pin.dart`, `ban_phim_pin.dart` (dùng chung màn khoá + trang đặt PIN), `mau_khoa_app.dart` (`kXamChuKhoaApp`) |
| `presentation/pages/` | `khoa_app_page.dart`, `dat_ma_pin_page.dart` |
| `presentation/state/phien_dau_khoa_app.dart` | `laTrangThaiPhienRo`, `phienDauChoKhoaApp` — phép rẽ phiên đầu (P2) |

Chỗ nối ngoài mảng: `lib/main.dart` (dựng `KhoaAppCubit` + `TheoDoiRouteCongKhai`, bọc `LopKhoaApp` ngoài `AppToast`, rẽ P2 qua `phienDauChoKhoaApp`) ·
`lib/core/router/theo_doi_route_cong_khai.dart` (`TheoDoiRouteCongKhai`, `NavigatorObserver`) + `app_router.dart` (hai route · `createRouter(observers:)` ·
`AppRouter.laRouteCongKhai` — **một** định nghĩa route công khai dùng chung với `authRedirect`) · `lib/core/auth/phien_dieu_phoi.dart` + `phien_dieu_phoi_that.dart`
(hook **`sauXacThucMatKhau`** → `datLaiKhoaApp`; `dongPhien` → `xoaKhoaApp`; `sauDangNhap` **không** đụng khoá app) · `lib/features/auth/presentation/bloc/auth_bloc.dart`
(`_onLoginSubmitted` gọi `sauXacThucMatKhau` ngay sau `login()` trả id hợp lệ) · `lib/core/di/injection_container.dart` (store, kênh, service; hai hook nối vào
`PhienDieuPhoiThat`) · `lib/features/profile/presentation/widgets/noi_dung_cai_dat.dart` (hàng + viên `_NhanKhoaApp`) · Kotlin `SinhTrac.kt` + một dòng đăng ký kênh ở
`MainActivity.kt` + `USE_BIOMETRIC` / `USE_FINGERPRINT` (`maxSdkVersion="29"`) ở manifest. Cấu hình khoá là **cục bộ** — không vào `SyncEntityType`, không lên server.

## 5. Bẫy hỏng im lặng — phá thì sao

1. **Lớp phủ nằm NGOÀI `Navigator`** (trong `MaterialApp.builder`): không `showDialog` (hiện **dưới** lớp phủ), không `IconButton` (cần
   `Overlay` cho `Tooltip`), không `SnackBar` (quét 19). Phần nội dung phía dưới phải bị **`ExcludeFocus(excluding: che)` +
   `ExcludeSemantics(excluding: che)`** — thiếu `ExcludeFocus` thì Tab + Enter bấm được nút dưới lớp khoá (người soát đo
   `nutNoiDung=2`); thiếu `ExcludeSemantics` thì TalkBack đọc nội dung dưới. Hai widget **luôn có mặt, bật theo cờ** (đổi cây widget
   theo trạng thái là dựng lại toàn bộ app). Hệ quả chấp nhận: ô autofocus của trang mở bằng deeplink không tự lấy focus sau mở khoá.
2. **`inactive` không tính rời app.** `_roiLuc ??= now` chỉ ở `hidden` / `paused` **đầu tiên**; hộp vân tay, hộp cấp quyền chỉ cho
   `inactive` — tính chúng thì mở khoá bằng vân tay xong là bị khoá lại ngay.
3. **`AuthSuccess` lặp** (`verifySession` phát lại cùng tài khoản sau lượt mở app từ bộ nhớ đệm — G86): `nhanPhien` có
   `if (_daBietPhien && id == _id) return` — thiếu là vừa mở khoá xong lại bị khoá lần nữa. Ca canh cả hai phía: lần đầu
   `nhanPhien(null)` từ `DangXet` → `Tat` (bản sai bỏ vế `_daBietPhien &&` tái hiện P2 mà mọi ca khác xanh).
4. **Mở app khi chưa đăng nhập (P2).** `main()` không gửi `AuthCheckRequested` khi không token → `AuthBloc` đứng ở `AuthInitial`,
   không phát gì → cubit kẹt `KhoaAppDangXet` = lớp **đặc** che màn Đăng nhập, không chạm được gì. `main.dart` rẽ qua
   `phienDauChoKhoaApp(authBloc.state, initialRoute)` (`initialRoute == '/login'` → `nhanPhien(null)`). Phép rẽ nay là **hàm thuần có 5 ca** (M10);
   dây nối `main.dart` → hàm vẫn không có test — nghiệm thu máy (bước 10 mục 9: mở app đã đăng xuất → màn Đăng nhập chạm được).
5. **Đăng xuất chỉ xoá alias Keystore; cấu hình PIN xoá ở `PhienDieuPhoi.sauXacThucMatKhau`** (Ruling T12 2026-10-25 sau soát Task 12; **I4 sau review toàn nhánh**:
   hook chuyển từ `sauDangNhap` sang `sauXacThucMatKhau`). Lý do T12: `AuthBloc._onLogoutRequested` = emit loading → `dongPhien` → `authRepository.logout()` (POST
   `/auth/logout` trước, xoá token **sau**, trần 30 + 30 s) → `AuthUnauthenticated`. Bản đầu xoá cấu hình ở `dongPhien` → **kịch bản vượt khoá đã chặn**: Quên PIN →
   Đăng xuất → vuốt app khỏi Đa nhiệm lúc POST treo → token còn, cấu hình mất → mở lại: `AuthSuccess` từ bộ nhớ đệm, không cấu hình = vào thẳng app không PIN. Lý do I4:
   bản T12 xoá ở `sauDangNhap`, **sau cả vòng đồng bộ đầu** (`batDongBo(cho: true)`) → giết tiến trình trong cửa sổ ấy = token mới + PIN cũ còn = hỏi lại đúng PIN vừa quên; và
   `_seedTaiKhoanMoi` ném thì cấu hình không bao giờ bị xoá. Nay `AuthBloc._onLoginSubmitted` gọi `sauXacThucMatKhau(idAcc)` **ngay sau khi `login()` trả id hợp lệ**, trước `moPhienCucBo`
   (`auth_bloc.dart:266`; ca thứ tự `['xoaPinCu 11', 'moPhienCucBo', 'sauDangNhap']` ở `auth_bloc_buoc_dang_xuat_test`). ⚠️ **Đừng đặt vào `moPhienCucBo`** (chạy cả lúc mở lạnh — xoá PIN mỗi
   lần mở app) và **đừng dời về `sauDangNhap`**. Hệ quả: xem mục 1b. Giết tiến trình giữa đăng xuất → mở lại **vẫn khoá** (an toàn). Vân tay chết ngay lúc đăng xuất (alias mất →
   `moBangVanTay` trả `VO_HIEU`, tự tắt). Còn mở rất hẹp: giết tiến trình giữa `login()` trả về và `datLaiSauDangNhap` xong → cấu hình còn, token mới → đòi PIN đã quên (chiều đóng; gỡ bằng
   Quên PIN → đăng xuất → đăng nhập lại).
6. **Kho đọc hỏng — mở lạnh coi như chưa bật, các đường sau thì CHỌN CHIỀU ĐÓNG (I2).** `store.doc` nuốt lỗi → `null` (đường `nhanPhien` mở lạnh, spec chấp nhận: token cùng kho). Nhưng
   `kiemPin` / `_mo` / `napLai` dùng `docNghiemNgat`: **vắng** → `null` (= chưa bật: `kiemPin` trả đúng), **hỏng** → ném. Hậu quả của ném: `kiemPin` hỏng → cubit giữ `Khoa` + `kCauKhongKiemDuoc`,
   không `dung`, không ghi đếm (không có "mở bằng chuỗi bất kỳ" khi kho hỏng lúc màn khoá đang hiện); `_mo` ném thì **giữ `_cauHinh` trong RAM** (kiểm `_id == id` TRƯỚC khi gán) để lần rời app kế vẫn
   tự khoá, và emit `Mo(daBat: _cauHinh != null)`; `napLai` ném thì `return` (giữ cấu hình cũ). ⚠️ Chỉ giữ cấu hình cũ khi **đọc ném**, KHÔNG khi `null` thật (vắng thật, vd. vừa *Tắt khoá* ở trang Cài
   đặt: `napLai` phải xoá cấu hình RAM, nếu không app còn tự khoá bằng cấu hình đã xoá và màn khoá mở bằng PIN bất kỳ). `ghi` cũng **ném** khi hỏng, để `kiemPin` không báo "sai" khi chưa ghi được lần sai.
7. **Thời gian chờ (`choDen`) theo giờ máy** (`DateTime`): chỉnh giờ máy rút được thời gian chờ — giới hạn chấp nhận (spec mục 6). Đồng hồ lùi lúc quay lại app thì `canKhoaKhiQuayLai` trả **khoá**.
   (Tự khoá thì không còn lệ thuộc giờ tường — bẫy 23.) `choDen` ở tương lai xa (giờ máy từng chạy trước rồi chỉnh lại) ⇒ chờ dài tuỳ ý — M8, mục 8.
8. **Một định nghĩa `conCho` / `chuDemNguoc`** (`luat_khoa_app.dart`) cho service, màn khoá và trang PIN. Đang chờ → `kiemPin` **không băm** (không lộ oracle đúng / sai lúc chờ). Ca ghim đã có (M3,
   2026-10-25): PIN sai lúc chờ — đếm lời gọi `bam` = 0, `soLanSai` / `choDen` không đổi, kết quả sai = đúng.
9. **Bật vân tay: Kotlin `bat` xoá alias cũ TRƯỚC khi hiện hộp.** Huỷ giữa chừng khi vân tay đã bật ⇒ khoá cũ mất, `mo` trả `LOI` (không `VO_HIEU`) — vân tay hỏng vĩnh viễn tới khi tắt / bật lại.
   Ba lớp chặn (I3, 2026-10-25): **`KhoaAppService.batVanTay` trả `null` ngay khi `c.vanTay != null`, không gọi kênh** (đường duy nhất vào kênh `bat` là service); trang Khoá ứng dụng chỉ gọi `batVanTay` khi công
   tắc đang tắt / vừa bật khoá (`sauDatPin`); cờ `_dangLam` ở cubit chặn chạm đôi công tắc vân tay (hai `SinhTrac.bat` song song, lượt sau xoá alias của lượt trước) và `_dangMoTrangPin` / `_moMotLan` ở trang chặn
   chạm đôi công tắc Khoá / hàng *Đổi mã PIN* (mở hai trang PIN).
10. **`lanKiem` thay khung `dangKiem` trung gian (P13).** Màn khoá xoá 6 chấm khi `lanKiem` đổi. Nhìn khung `dangKiem: true` trung gian thì sai: `nhapPin` phát `dangKiem` rồi `await kiemPin`; băm hoàn tất trong
    microtask thì cả hai state phát xong **trước** khi khung nào được dựng — `didUpdateWidget` chỉ thấy `false → false`, 6 chấm kẹt. Trên máy thật PBKDF2 ~200 ms nên khung ấy "tình cờ" tồn tại — logic phụ thuộc thời gian.
11. **Chấm PIN theo chỉ số** (`cham-day-$i` / `cham-rong-$i`, P1): hai loại chấm cùng khoá thì test đếm sai. Ca chấm đòi kết quả (`chamPin()` ở helper), không chỉ vắng mặt.
12. **Khuôn mặt Class 2 không mở được khoá Keystore**; `trangThai()` trả `hoTro`: API ≥ 30 = `canAuthenticate(BIOMETRIC_STRONG)` ∈ {`SUCCESS`, `NONE_ENROLLED`}; API 28–29 = có phần cứng vân tay (`FEATURE_FINGERPRINT` +
    `FingerprintManager.isHardwareDetected`) — máy API 29 chỉ có khuôn mặt mạnh (vd. Pixel 4) ra `hoTro=false` (plan-mandated). **API 24–27: chỉ PIN.** Khoá AES-GCM: `setUserAuthenticationRequired(true)`,
    `setInvalidatedByBiometricEnrollment(true)`; API ≥ 30 `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)`. Realme / OnePlus đều API ≥ 30 → nhánh API 28–29 và P10 / P11 (bẫy 21) **không đo được** bằng hai máy hiện có.
13. **Thêm vân tay mới trên máy → Keystore vô hiệu khoá** → `mo` trả `VO_HIEU` **không hiện hộp** → service `tatVanTay` + `xoaHet` → câu *"Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại trong Cài đặt"*;
    ở màn khoá nút vân tay biến mất (`coVanTay:false`).
14. **Back khi đang khoá gỡ route bên dưới** (kế hoạch chấp nhận; M5): `LopKhoaApp` nằm ngoài `Navigator` và không có `PopScope` / `BackButtonListener` (Grep 0) → Back đi tới router, pop route dưới lớp phủ. Không lộ gì, nhưng
    `PopScope` của trang dưới có thể mở hộp thoại **nằm dưới** lớp khoá, form dở bị bỏ, deeplink mở lúc khoá có thể mất trang đích. Ở tab khác Back đổi về Trang chủ (`ThoatHaiLan.veTabDau`); ở Trang chủ Back thứ nhất
    bật toast *"Nhấn lần nữa để thoát"* **dưới** lớp khoá (người dùng không thấy), Back thứ hai đưa app xuống nền (`main_shell.dart`). Back khi tấm Quên PIN mở cũng gỡ route dưới thay vì đóng tấm. **Chưa có ca test — nghiệm thu máy.**
15. **Test: `google_fonts` + `tester.runAsync` làm ca ĐẦU tệp đỏ (P14).** `AppTheme.lightTheme` → `GoogleFonts.interTextTheme()` tải font qua HTTP; `HttpClient` của `flutter_test` trả 400 → `Exception: Failed to load font…`
    ném vào zone của ca đang chạy khi phản hồi về — phản hồi chỉ về khi có lượt event-loop **thật** (`runAsync`). `GoogleFonts.config.allowRuntimeFetching = false` **không cứu** (đổi sang ném *"font was not found in the application
    assets"*). Cách đúng: **không `runAsync`** khi kho giả + `bamNhanh` chỉ dùng microtask; riêng `lop_khoa_app_test` còn dựng `phien`/`vongDoi`/`cubit` trong `setUp` (ngoài FakeAsync) nên gọi thẳng
    `await cubit.nhanPhien(…); await t.pump();` thay vì đẩy vào stream.
16. **Ca canh bằng `Completer` không được `await` mù.** Ca chống chạm đôi của trang Khoá ứng dụng từng **treo ~10 phút** (timeout mặc định `testWidgets`) khi hồi quy, thay vì đỏ — `await b` chờ Completer không bao giờ hoàn tất.
    Đã dời sang `test()` ở cubit (`3d6a9d78`) để **đỏ ngay**. Ca mới cùng khuôn: thử bản sai và thấy nó **đỏ**, không treo.
17. **`ExcludeSemantics` trong `_Phim` (phím số)**, không `excludeSemantics: true` ở `Semantics` ngoài: cái sau cắt tap. TalkBack từng đọc "7\n7" (label + `Text` bên trong gộp).
18. **Bàn phím số chỉ co khi cha cho chiều cao giới hạn** (T8 ⚠️) — màn khoá và trang PIN đều có ca ở 360 × 640 / 800.
19. **Không log PIN / bí mật / bản mã.** Mảng hiện **0** lời gọi `debugPrint` / `print` / `log`. ⚠️ **Quét 38 KHÔNG canh việc này** — nó chỉ bắt `.balance · .amount · .note · .args · .noiDung · .ghiChu`; thêm
    `debugPrint('$pin')` vẫn xanh. Phía Kotlin thì `kenh_sinh_trac_noi_day_test` cấm `Log.`. Dòng đo tạm ở bước B mục 9 chỉ in số mili-giây. Cất **bản mã + IV + SHA-256(bí mật)**, không bao giờ cất bí mật 32 byte
    (`Random.secure()`); so SHA-256 bằng `soSanhHangThoiGian` (hằng thời gian; ca M2 phủ khác ở byte đầu / giữa — bản sai `khac = a^b` từng lọt). (Một quét thật cho `pin` / `biMat` là việc mới, số 39 — ngoài phạm vi.)
20. **Kênh Dart ↔ Kotlin khớp tay**: tên lệnh `trangThai · bat · mo · xoaHet`, khoá `idaccount · biMat · banMa · iv · hoTro · daDangKy · loi`, mã `HUY · VO_HIEU · TAM_KHOA · KHONG_HO_TRO · LOI`. `kenh_sinh_trac_noi_day_test`
    đọc `SinhTrac.kt`, `MainActivity.kt`, manifest — đòi `setUserAuthenticationParameters(0,`, `AUTH_BIOMETRIC_STRONG`, `cryptoObject?.cipher`, và `maxSdkVersion="29"` nằm trên chính phần tử `USE_FINGERPRINT` (T5) — và canh `MainActivity`
    vẫn `: FlutterActivity()` (đổi sang `FlutterFragmentActivity` là đụng G100).
21. **`lintVitalRelease` có thể không chạy `NewApi` / `MissingPermission`** (mức error nhưng không fatal) — build release xanh chưa chứng minh P10 / P11; chỉ máy thật chứng minh được (và máy API 28–29, hiện không có).
22. **C1 — lớp che phải giữ tới khi router ĐỨNG YÊN ở route công khai (`KhoaAppDangRoi`).** Phiên mất (Quên PIN → Đăng xuất, cưỡng chế đăng xuất khi đang khoá, phiên chết lúc mở lạnh) mà gỡ lớp phủ ngay thì trang được bảo
    vệ — route cũ ở trạng thái `removing`, vẫn được vẽ **dưới** trang Đăng nhập đang trượt vào — lộ ra không cần PIN (người cầm máy tự kích được qua Quên PIN + chế độ máy bay: `logout()` treo, nên thấy trang thật hơn 1 s). Nay
    `nhanPhien(null)` khi đang `Khoa`, hoặc `DangXet` đã có tài khoản → `KhoaAppDangRoi` (lớp ĐẶC, **cùng hình** với `DangXet`, `ExcludeFocus`/`ExcludeSemantics` bật), nghe `dungYenOCongKhai`, gỡ khi tín hiệu `true`; **van an toàn
    3 s** (`vanAnToanRoi`) nếu tín hiệu không tới — màn che vĩnh viễn tệ hơn một khung lộ. Tín hiệu đã `true` sẵn (Quên PIN: router sang `/login` từ `AuthLoading`) → `Tat` ngay. Lần đầu nhận `null` (chưa từng có phiên) và đang
    `Mo` → `Tat` ngay như cũ (P2 không hồi quy). `dungYenOCongKhai == null` → mất phiên là `Tat` ngay (chỉ test cũ; `main.dart` luôn truyền). Cơ chế: `TheoDoiRouteCongKhai` (`NavigatorObserver`, `GoRouter(observers:)`) — route trên cùng có
    tên khớp `AppRouter.laRouteCongKhai` **và** hiệu ứng vào xong. ⚠️ **`route.animation` (ProxyAnimation) báo `completed` thoáng qua ngay trong `didPush` rồi mới sang `forward`** — đọc ngay là tưởng hiệu ứng xong và gỡ sớm (ca
    đỏ 28 khung lộ lúc đo); observer nghe status nhưng **đánh giá lại SAU một microtask** (`scheduleMicrotask(_tinh)`). Phụ thuộc hành vi nội bộ của Navigator / GoRouter (tên route = `settings.name`, route công khai đều ở gốc) — đổi
    phiên bản `go_router` thì chạy lại `lop_khoa_app_roi_phien_test.dart` (GoRouter thật, đo từng khung 16 ms). Route công khai lồng nhau (nếu sau này có) sẽ không khớp tên.
    ⚠️ **Observer bỏ qua `PopupRoute`** ở cả bốn callback (`be3bdf26`, sau soát lại): màn Đăng nhập mở hộp thoại lý do (`showDialog`, route không tên) ngay khung đầu ở đường cưỡng chế
    đăng xuất / phiên chết lúc mở lạnh — coi hộp thoại là route trên cùng thì tín hiệu không bao giờ `true`, van an toàn thành cơ chế chính (màn đặc 3 s che cả hộp thoại).
    Phép canh nối router thật: `test/core/router/route_cong_khai_ten_route_test.dart` (route công khai không có `name:`, go_router đặt tên trang = đường dẫn) — mới ghim chắc `/login`.
23. **I1 — tự khoá đo bằng HAI đồng hồ; đừng thay bằng `Stopwatch`.** Giờ tường (`DateTime.now`) chỉnh được bằng Cài đặt giờ: ở nền 10 phút rồi đặt giờ lùi về sau mốc rời thì `nay − roiLuc` nhỏ — vượt khoá. Nay mốc rời ghi cả
    **đồng hồ khởi động** `CLOCK_BOOTTIME` (đơn điệu, tính cả lúc máy ngủ — khác `uptimeMillis`/`Stopwatch` ngừng khi ngủ; chỉ reset khi khởi động lại), đọc bằng `clock_gettime` qua `dart:ffi`
    (`DynamicLibrary.process()`, `malloc`/`free` tra qua libc, `timespec` đọc bằng `IntPtr` ×2 — đúng 32 và 64 bit; không thêm gói). Luật ba vế: khoá khi giờ tường lùi ∨ giờ tường ≥ mức ∨ (đồng hồ khởi động `≠ null` ∧ (âm ∨ ≥ mức)).
    Đồng hồ khởi động `null` (web, Windows, iOS, lỗi) → chỉ còn giờ tường (ca cũ giữ nguyên). `choDen` vẫn theo giờ tường (bẫy 7). **Chưa đo trên Android thật** (host test trả `null`; web build đạt) — mục 9 bước 13.
    Import có điều kiện: `flutter build web --debug` đạt, nhưng đổi cấu trúc ba tệp `dong_ho_khoi_dong*.dart` phải dựng lại web.
24. **Hệ quả thiết kế đăng nhập mật khẩu (M11, mục 1b).** Mọi lần đăng nhập bằng mật khẩu — không riêng Quên PIN — tắt khoá, và đăng nhập tài khoản KHÁC dọn dữ liệu cục bộ tài khoản cũ. Đây là hành vi đã chốt (spec), không phải lỗi;
    đừng "sửa" bằng cách đặt hook vào `moPhienCucBo` (bẫy 5). Muốn nhắc người dùng thì thêm dòng báo sau đăng nhập (hỏi người dùng trước — mục 8).

## 6. Giao diện — Stitch (dự án `5106367939423432838`)

| Màn | Id |
|---|---|
| Màn khoá ứng dụng (2 biến thể: bình thường / chờ) | `2f0896e011874b4e84c8217c4f56346e` |
| Đặt mã PIN (3 bước) | `34c3cadedf024a62a7865669f310bc15` |
| Khoá ứng dụng - Cài đặt (2 biến thể: bật / tắt) | `129c2d77d97d4cff9322d05be9142a92` |
| Cá nhân - Hàng Khoá ứng dụng | `3469341eadbb47629947a4757c507ffb` |
| Màn khoá - Xác nhận quên mã PIN | `aa95222fc5bc40c3a2c329d75b112830` |

Người dùng xác nhận cả năm màn đúng ý (cuối phiên 4). **Lệch có chủ ý:**
(1) Stitch `3469341e…` vẽ lại **cả ba** hàng thẻ *Bảo mật & Tuỳ chọn* với ô icon vuông — người dùng chốt **giữ kiểu hàng cũ, chỉ thêm
hàng** + viên *Đang bật*; (2) Stitch dùng icon `shield_lock` ở trang Đặt PIN — Material Icons của Flutter không có, dùng
`Icons.shield_outlined`; (3) công tắc trang Khoá ứng dụng **rãnh đen** theo Stitch, khác công tắc xanh của trang Cài đặt thông báo (theo
theme) — màn này theo Stitch; (4) màu chữ phụ `#454743` (`kXamChuKhoaApp`), **không** `AppColors.onSurfaceVariant` (`#767872`).

## 7. Test và quét

- **128 ca** khai báo trong 16 tệp dưới `test/features/khoa_app/` (đếm bằng grep `^\s*(test|testWidgets)\(` 2026-10-25, sau đợt sửa cuối), cộng `test/core/router/theo_doi_route_cong_khai_test.dart` (observer), ca ở `phien_dieu_phoi_that_test.dart`
  (hook `sauXacThucMatKhau` / `xoaKhoaApp` / `datLaiKhoaApp`), `auth_bloc_buoc_dang_xuat_test.dart` (thứ tự mở phiên với `PhienDieuPhoiThat` thật) và `noi_dung_cai_dat_khoa_app_test.dart` (viên *Đang bật*, kể cả `Mo(daBat:false)` và `Tat`).
- Mốc toàn bộ: **8.017 pass / 10 skip**, `flutter analyze` **20** (đo 2026-10-25 sau bản vá cuối `be3bdf26`; xem *Lệnh hay dùng* `CLAUDE.md`). Bản vá ấy thêm 4 ca: hai ở
  `lop_khoa_app_roi_phien_test.dart` (`/login` tự `showDialog` → gỡ trước van; popup trên trang được bảo vệ không làm tín hiệu `true`) và hai ở `test/core/router/route_cong_khai_ten_route_test.dart`.
- Mảng mới phải qua các quét sẵn có: 22 (`presentation/` không chạm CSDL), 25 (vị trí tệp — `core/router` là chủ đề sẵn có), 27 (không `<dynamic>` trần ở `data/` +
  `application/`), 38 (không log PII — **không** canh PIN / bí mật, bẫy 19). Không thêm test quét mới.
- **Ca test còn MÙ** (chỉ máy thật / chưa có ca): dây nối `main.dart` → `phienDauChoKhoaApp` (hàm thuần đã có ca); **I1 bản ffi** (host Windows trả `null`; ca `dong_ho_khoi_dong_test` chỉ canh "null hoặc số không âm đơn điệu"); C1 trên máy thật
  (ca GoRouter thật phủ ba đường nhưng animation nền tảng khác — cần quay 60 fps); Back khi khoá (bẫy 14); BiometricPrompt thật, ColorOS `inactive` vs `paused`; TalkBack; bàn phím vật lý; bản release R8.

## 8. Việc còn mở (chưa sửa — từ review toàn nhánh 2026-10-25, đáng xem trước khi sửa mã)

- **M5** Back khi đang khoá pop route bên dưới (bẫy 14) — cách sửa: chặn Back ở tầng lớp phủ (`BackButtonListener` / `didPopRoute` trả `true`) hoặc đưa app xuống nền bằng kênh `flowmoney/xuong_nen` như `ThoatHaiLan`.
- **M7** `_lamTuoiKhoa` chỉ chặn `dangKiem`; nếu một lượt kiểm đã kết thúc trong lúc nó đọc kho, nó phát `soLanSai` / `choDen` cũ đè bản mới (chỉ lệch hiển thị — service vẫn chặn). Sửa: bắt `lanKiem` lúc bắt đầu.
- **M8** `choDen` ở tương lai xa (giờ máy từng chạy trước rồi chỉnh lại) ⇒ chờ dài tuỳ ý (còn vân tay / Quên PIN). Sửa: kẹp phần chờ còn lại ở `thoiGianCho(∞)` = 15 phút.
- **M11** Mọi đăng nhập mật khẩu tắt khoá **im lặng** (mục 1b, bẫy 24) — tối thiểu báo một dòng sau đăng nhập, hoặc chỉ xoá khi đi đường Quên PIN. **Hỏi người dùng.**
- **M12** `BIOMETRIC_ERROR_TIMEOUT` → `LOI` (nên `HUY`), `SECURITY_UPDATE_REQUIRED` → nên `KHONG_HO_TRO` (người chờ ở màn khoá thấy câu chung *"Không mở được bằng vân tay — nhập mã PIN"*); `SinhTrac.kt` `xoaHet` một `try` chung quanh `forEach deleteEntry`.
  Đo câu hiện ra trên Realme trước khi đổi ánh xạ.
- **M13** Lớp phủ không nhận phím số của bàn phím vật lý (chỉ Tab + Enter từng phím) — để lại, đã ghi.
- **Sau soát lại đợt sửa (2026-10-25, để lại):** `DatMaPinPage._napCho` đọc kho kiểu khoan dung và nuốt lỗi → đọc hỏng thì chế độ `dat` vẫn ghi đè PIN mà không hỏi PIN cũ (M4 chỉ đóng
  khi đọc được; lối vào chỉ là route nội bộ). `TheoDoiRouteCongKhai`: `didPop` / `didRemove` có thể ghi một popup qua `previousRoute` (kẹt `false` tới lần push kế — chiều đóng, van an toàn gỡ),
  `didReplace` có popup ở một vế thì mất route trên cùng — cả hai chưa xảy ra được với mã hôm nay; hướng sửa: observer giữ danh sách route trang riêng. Ca nối router thật mới ghim `/login` —
  nên liệt kê đủ các route công khai.
- **Để lại có lý do (triage review):** ABA `nhanPhien` 10→null→10 mở hộp vân tay hai lần (Kotlin `hoi()` huỷ lời đầu — đo chạm hai lần nhanh); `batVanTay` đọc cấu hình trước hộp rồi ghi sau (hộp hệ thống là modal; không đường nào trong app đổi cấu hình lúc ấy);
  tấm Quên PIN mở mà bàn phím phía sau còn trong cây semantics (`BlockSemantics` — nghiệm thu TalkBack); ca 320 dp chưa thử nhãn dài nhất; `pbkdf2` không chặn `soVong < 1` (`tuJson` đã loại); đổi tên enum `TuKhoaSau` đã cất ⇒ đọc về mặc định 30 s;
  sai vân tay "không cộng" chưa ghim (bản sai chỉ làm chặt hơn); `_lamTuoiKhoa` giữ `coVanTay` RAM.
- **Ba chỗ chú thích / tên ca lệch mã sau đổi thiết kế — ĐÃ SỬA** (đợt sửa cuối, M1, 2026-10-25): `phien_dieu_phoi_that_test.dart` (tên + `reason`), `khoa_app_store.dart` (doc `xoaHet`), `phien_dieu_phoi.dart` (docstring `sauXacThucMatKhau` / `sauDangNhap` / `dongPhien`),
  thêm `khoa_app_service.dart` (docstring đầu tệp) và `main.dart` (chú thích). Đã đóng cùng đợt: C1, I1–I4, M1–M4, M6, M9, M10, T1, T5–T7.

## 9. Checklist nghiệm thu — PHIÊN SAU

Quay màn hình (60 fps nếu được) ở mọi bước có chữ **[quay]** — đó là phép đo duy nhất cho C1 và cho "không lọt khung".

**A. Chuẩn bị:** (1) chép CSDL Realme ra trước khi đụng (khuôn `D:\FlowMoney-saoluu\realme-tk10-truoc-khoa-app-<giờ>\`, `exec-out run-as … cat`
ba tệp `flowmoney.db` / `-wal` / `-shm`, so cỡ; Git Bash đặt `MSYS_NO_PATHCONV=1`); (2) bản debug cùng `--dart-define=API_BASE_URL=…` cũ.
⚠️ **Đừng đăng xuất ở đầu buổi** — đăng nhập lại cần backend `PersonFinance` + `DATA_ENCRYPTION_KEY` dev + mật khẩu postgres, và bật backend sai CSDL là đường mất dữ liệu (*Ghi chú vận hành* → *Danh tính CSDL*, `CLAUDE.md`).
Mọi bước có *Đăng xuất* (**10a**, **11**, **12** nhánh đăng xuất, D-1) chỉ chạy sau khi đã kiểm danh tính CSDL + đã chép CSDL (A1).

**B. Đo số vòng PBKDF2 trên bản RELEASE** (phải đi trước nghiệm thu): thêm TẠM `Stopwatch` quanh `_bam(...)` trong `KhoaAppService.datPin`
và `debugPrint('[KhoaApp] bam ${sw.elapsedMilliseconds} ms')` (chỉ thời gian, KHÔNG PIN — quét 38 **không** canh dòng này, bẫy 19) → `flutter build apk --release
--dart-define=API_BASE_URL=http://127.0.0.1:3000/api` (địa chỉ nội bộ được `http`; ký debug vì không có `key.properties`) → cài, bật khoá
ba lần, `adb logcat -d | grep KhoaApp`. Mục tiêu **200–300 ms**: đổi `kSoVongMacDinh` theo tỉ lệ (vd. đo 100 ms ở 30.000 → 75.000), dựng lại,
đo lại. **Gỡ** dòng đo, cài lại bản debug, **ghi số đo vào mục 10 tệp này**. Bản debug chậm hơn release nhiều lần — đừng chọn theo debug.
Đổi `kSoVongMacDinh` không làm hỏng PIN đã đặt (số vòng cất trong cấu hình).

**C. Bước nghiệm thu (chụp màn từng bước, ghi đạt / không):**
1. **Bật:** Cá nhân → *Khoá ứng dụng* → bật → đặt PIN hai lần → hộp *"Chạm vân tay để bật"* tự hiện → chạm → công tắc vân tay bật; lượt khác Huỷ → chỉ PIN. Bật vân tay **lần đầu** thành công (xác nhận `deleteEntry` trên alias chưa có không ném, bẫy T5).
2. **Mở lạnh [quay]:** `am force-stop` → mở → lớp đặc → màn khoá, không một khung nội dung; hộp vân tay tự hiện đúng một lần → vân tay mở.
3. **Ở nền:** mở → Home → ra màn chính 29 s / 31 s ở mức 30 s (20 s không khoá, 35 s khoá); mức *Ngay*; tắt màn hình bằng nút nguồn rồi mở lại.
4. **Quay lại sau ≥ mức [quay]:** không được thấy khung nội dung cũ trước màn khoá (Flutter có thể vẽ lại lớp cuối khi surface dựng lại, trước khi Dart nhận `resumed` — chỉ máy thật cho biết). Ảnh Đa nhiệm trống (Android 13).
5. **ColorOS + BiometricPrompt:** hộp vân tay (ở Cài đặt và ở màn khoá) chỉ gây `inactive` hay cả `paused`? Với mức *Ngay*, bật vân tay xong có bị khoá ngay không (logcat vòng đời).
6. **Chạm thông báo khi khoá** (app sống / app đã chết; đổi tạm giờ *Tổng kết tuần*, trả lại sau), tóm tắt D1, nút *Trả ngay*: màn khoá trước, mở khoá thấy trang đích.
7. **Sai PIN:** lần 5 → *"Thử lại sau 00:30"* đếm ngược, phím mờ, **phím vân tay vẫn bật**; force-stop giữa lúc chờ → mở lại vẫn chờ; lần 6 / 7 / 8. **Sai ở trang Đổi / Tắt PIN rồi rời app** → màn khoá lần sau thấy đúng `soLanSai` (P9).
8. **Vân tay:** mở được; quét sai nhiều lần → câu tạm khoá; để hộp tự hết giờ (`TIMEOUT`) → câu nào hiện (M12; hiện rơi `LOI` → *"Không mở được bằng vân tay — nhập mã PIN"*); chạm phím vân tay hai lần thật nhanh.
9. **Thêm vân tay mới trên máy** (nhờ người dùng) → `VO_HIEU` → tự tắt + câu *"Vân tay trên máy đã thay đổi…"*, PIN mở được; xoá hết vân tay; gỡ khoá màn hình máy.
10. **Mở app chưa đăng nhập (P2 — chỉ khi máy đang ở trạng thái đã đăng xuất, đừng tự đăng xuất):** màn Đăng nhập chạm được, không lớp phủ.
10a. **Quên mã PIN:** *Huỷ* (không đăng xuất) — luôn đo được. *(Chỉ khi đã qua điều kiện A)* **[quay]** có mạng **và chế độ máy bay**: *Đăng xuất* → không lộ trang dưới trong lúc chuyển sang Đăng nhập (C1 đường 1) → `am force-stop` → mở → màn Đăng nhập chạm được, không lớp phủ (P12, bẫy 4) → **đăng nhập lại bằng mật khẩu cùng tài khoản** → không màn khoá, hàng Khoá ứng dụng **không** viên *Đang bật*, dữ liệu còn.
11. *(Chỉ khi đã qua điều kiện A)* **Vuốt khỏi Đa nhiệm trong lúc chờ vòng đồng bộ đầu sau Quên PIN** → mở lại: dự kiến **KHÔNG** hỏi lại PIN cũ (I4 đã đóng cửa sổ này; Realme vuốt = force-stop).
12. **Cưỡng chế đăng xuất khi đang khoá [quay]** (admin khoá tài khoản thử / socket `account.force_logout`) và **phiên chết lúc mở lạnh [quay]** (C1 đường 2–3) — dự kiến không khung nào lộ trang dưới.
13. **Đồng hồ khởi động (I1) trên máy thật:** (a) mức 5 phút, ở nền, **tắt màn hình bằng nút nguồn** > 5 phút (đồng hồ khởi động phải tăng cả lúc máy ngủ — dùng `Stopwatch` / uptime thì không khoá) → mở lại → **khoá**; (b) ở nền, chỉnh giờ máy **lùi** về sau mốc rời, quay lại → dự kiến **KHOÁ** (trước I1: không khoá); (c) chỉnh giờ khi đang chờ sau sai PIN (`choDen`) vẫn rút được — giới hạn spec đã chấp nhận (bẫy 7). Bản release dựng thử `--release` có `dart:ffi` không bị R8 / tree-shake.
14. **G100:** Back hai lần ở Trang chủ → app xuống nền (không thoát) → mở lại theo luật tự khoá; **gỡ FlowMoney khỏi Đa nhiệm** — một lần khi đang giữ Gemma (đã hỏi Trợ lý AI; `MainActivity.onDestroy` giết tiến trình), một lần không giữ (dịch vụ D1 giữ tiến trình → engine dựng lại trong tiến trình sống) → mở lại = **màn khoá**. Kiểm `pidof com.flowmoney.flowmoney` trước / sau để biết đã đi đường nào.
15. **G106:** `adb shell dumpsys alarm | grep -c 'Alarm{.*flowmoney'` sau force-stop + mở app vẫn **3** (lớp khoá không làm hỏng).
16. **Bản release:** đo số vòng PBKDF2 (bước B), giao diện không giật khi kiểm (isolate), kênh `flowmoney/sinh_trac` sống sau R8.
17. **Bố cục:** 320 dp / cỡ chữ lớn — màn khoá, trang Khoá ứng dụng (nhãn *"Ngay khi rời app"*, câu *"Thêm vân tay…"*), hàng Cá nhân + viên *Đang bật*.
18. **TalkBack:** không đọc nội dung dưới lớp khoá; mỗi phím đọc **một lần** ("7", không "7 7"); tấm Quên PIN (phím phía sau còn bấm được?); nút vân tay. **Bàn phím vật lý (Tab / Enter):** không bấm được nội dung dưới lớp khoá.
19. **Thêm vân tay trong Cài đặt máy rồi quay lại trang Khoá ứng dụng** — dòng phụ còn *"Thêm vân tay…"* tới khi vào lại trang? Máy đủ điều kiện nhưng chưa đăng ký vân tay (`daDangKy:false`): bật khoá không hiện hộp, công tắc vân tay có câu hướng dẫn.
20. **Back khi đang khoá** — với một form dở bên dưới, ở trang con, ở Trang chủ (hai lần), khi tấm Quên PIN mở: không lộ gì, không thoát (M5, bẫy 14).
21. **Quét ảnh khi khoá bật** (mức Ngay hoặc 30 s): ColorOS giết app khi mở camera / trình chọn ảnh lúc đang giữ Gemma → quay về = mở lạnh = màn khoá. Mở khoá xong lượt quét vẫn phải hoàn tất và điền form. **PayOS khi khoá bật:** từ màn Chờ thanh toán sang app ngân hàng > 30 s → quay về bị khoá → mở khoá → màn Chờ vẫn hỏi `order-status` và chuyển đúng trạng thái. (Chấp nhận theo spec mục 8.)
22. **Chạm đôi** công tắc *Khoá FlowMoney* và hàng *Đổi mã PIN* → một trang Đặt PIN (I3); **Đổi mã PIN** và **Tắt khoá** đòi PIN hiện tại.
23. Tắt khoá ở cuối buổi **chỉ khi** người dùng muốn; hỏi trước.

**D. Thêm từ các lượt soát:**
- D-1. *(Chỉ khi đã qua điều kiện A)* Giết tiến trình (vuốt khỏi Đa nhiệm) **giữa lúc đăng xuất** (POST treo bằng chế độ máy bay) → mở lại vẫn khoá (bẫy 5). Trên Realme vuốt = force-stop (trừ khi D1 giữ tiến trình).
- Nhãn dài nhất ở 360 dp: *Tự khoá sau* = "Ngay khi rời app" — không tràn / cụt; phóng chữ.

**E. Không đo được bằng hai máy hiện có (API ≥ 30):** nhánh API 28–29 của `trangThai()` và P10 (`USE_FINGERPRINT` `maxSdkVersion=29`) / P11 (lint `NewApi`) — soát bằng mắt mã `SinhTrac.kt`; API 24–27 chỉ PIN.
**Ngoài phạm vi (spec mục 8):** ẩn số tiền · 2FA / MFA tài khoản · danh sách thiết bị / đăng xuất từ xa · mã hoá SQLite · khoá khi tắt màn hình · miễn khoá khi rời app do chính app mở (camera, chọn ảnh, PayOS) · iOS (Face ID).

## 10. Kết quả nghiệm thu

*(Chưa có — điền ở phiên nghiệm thu: số đo PBKDF2 release, bảng đạt / không từng bước mục 9.)*
