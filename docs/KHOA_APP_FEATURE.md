# Khoá ứng dụng bằng PIN 6 số + vân tay — tài liệu bàn giao

> **Trạng thái (2026-10-25):** ✅ **mã xong** — 12 task của kế hoạch `docs/superpowers/plans/2026-10-24-khoa-app-pin-sinh-trac.md`
> (gitignore), dải commit `a0c6dacf..92b69200` (22 commit, đếm 2026-10-25; Task 1 = `e86431f2`, Task 12 sửa lần cuối = `92b69200`).
> 🚧 **CHƯA nghiệm thu trên máy thật** — người dùng chốt *"nghiệm thu thì để phiên sau"*. Mọi thứ dưới đây là **mã + test**; chưa
> ai nhìn lớp khoá trên Realme. Checklist ở mục **9** (phải làm đúng thứ tự: chép CSDL Realme → đo số vòng PBKDF2 trên release →
> nghiệm thu). ⚠️ **`kSoVongMacDinh` = 30.000 là số TẠM của kế hoạch, chưa đo trên bản release** (mục 9, bước B).
> Spec: `docs/superpowers/specs/2026-10-24-khoa-app-pin-sinh-trac-design.md` (đã sửa theo thiết kế cuối 2026-10-25).
> Mảng mã: `src/Client-app/lib/features/khoa_app/` (16 tệp, 2.009 dòng) + `android/…/SinhTrac.kt`.

## 1. Người dùng thấy gì

- **Bật:** Cá nhân → thẻ *Bảo mật & Tuỳ chọn* → hàng **Khoá ứng dụng** (viên xanh *Đang bật* khi đã bật) → trang Khoá ứng dụng →
  công tắc *Khoá FlowMoney* → đặt PIN 6 số (nhập hai lần) → nếu máy đủ điều kiện, hộp vân tay hệ thống *"Chạm vân tay để bật"*
  **tự hiện** (chạm = bật vân tay; huỷ = chỉ dùng PIN, không có hộp hỏi riêng). Trang còn: *Đổi mã PIN*, công tắc *Vân tay*, ô
  *Tự khoá sau* (Ngay khi rời app · 30 giây **mặc định** · 1 phút · 5 phút). Tắt khoá / đổi PIN đòi PIN hiện tại.
- **Bị khoá:** màn khoá phủ toàn app kể cả toast: logo, *"Nhập mã PIN"*, 6 chấm, bàn phím số, nút vân tay, *"Quên mã PIN?"*. Bật
  vân tay thì hộp vân tay tự hiện **một lần** mỗi lần khoá.
- **Khi nào khoá:** mở app từ đầu (kể cả engine Flutter dựng lại khi tiến trình còn sống — G100) · quay lại sau khi ở nền ≥ mức đã
  chọn. Hộp vân tay / hộp cấp quyền (`inactive`) không tính là rời app.
- **Chạm thông báo / tóm tắt D1 / nút Trả ngay khi đang khoá:** router vẫn điều hướng tới trang đích **bên dưới** lớp phủ; mở khoá
  là thấy trang đó.
- **Sai PIN:** lần 5 → chờ 30 giây; 6 → 1 phút; 7 → 5 phút; từ 8 → 15 phút mỗi lần. Đang chờ: phím số mờ + *"Thử lại sau mm:ss"*;
  **vân tay vẫn mở được**.
- **Quên PIN:** tấm xác nhận → *Đăng xuất* → đăng nhập lại bằng **mật khẩu tài khoản** thì khoá đã tắt (đặt lại nếu muốn), dữ liệu
  máy giữ nguyên. Cần mạng.
- **Giới hạn đã nói với người dùng:** khuôn mặt phần lớn máy Android là sinh trắc *yếu* (Class 2) → không mở được khoá Keystore →
  chỉ **vân tay**; Android 7–8.1 (API 24–27, `minSdk` 24) chỉ PIN; thêm vân tay mới trên máy thì vân tay của app tự tắt, phải nhập
  PIN rồi bật lại.
- **Không đổi:** chia sẻ biên lai (`NhanBienLaiActivity`, không giao diện), nút *Hoãn 1 ngày* (chạy nền), engine nền tự trả / tự
  trích, dịch vụ D1. Khoá ứng dụng **miễn phí mọi gói** (không có trong bảng quyền theo gói).

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
- **Đăng xuất chỉ xoá alias Keystore; cấu hình PIN xoá ở `PhienDieuPhoiThat.sauDangNhap`** (Ruling T12, đổi thân spec 2026-10-25, hành vi người dùng thấy không đổi) · xem bẫy 5.
- **`khiQuenPin` chỉ `add(LogoutRequested())`** · đường lùi `tatKhoa` sau `AuthUnauthenticated` bị gỡ cùng `application/xoa_khoa_sau_dang_xuat.dart` khi Ruling T12 đổi.
- **`xoaHet` của kho: mỗi `delete` một `try` riêng**, `readAll` hỏng thì nuốt · đăng xuất không được ném; đường lùi cho `readAll` hỏng là `datLaiSauDangNhap` xoá thẳng theo khoá.
- **`kiemPin` không có cấu hình → đúng** (`dung: true`) · đọc kho hỏng = chưa bật (spec mục 6, khớp `AuthBloc`: kho hỏng thì phiên đã hỏng).
- **Một định nghĩa "đang chờ"** `conCho(choDen, nay)` + `chuDemNguoc(Duration)` ở `domain/luat_khoa_app.dart` · trang PIN, màn khoá và service từng chép riêng và đã lệch (T10 review).
- **Câu "Thử lại sau" hiện khi `choDen` còn ở tương lai**, không chỉ khi `dangCho` · lần sai thứ 5 trả `dangCho=false` kèm `choDen` (T10).
- **Kho hỏng khi kiểm / đặt PIN có câu riêng**: *"Không kiểm được mã PIN — thử lại"* (không nói "không đúng", không tính sai), *"Không lưu được mã PIN — thử lại"*, *"Không lưu được cài đặt khoá — thử lại"* · nói sai với người dùng là lỗi.
- **`resumed` khoá ngay bằng bản RAM rồi làm tươi từ kho** (P9, chỉ emit khi còn cùng `lanKhoa`) · không để lọt khung nội dung, nhưng `soLanSai` / `choDen` ở kho có thể mới hơn.
- **`_daBietPhien` + `id == _id` → bỏ qua** · `verifySession` phát lại `AuthSuccess` (bẫy 3).
- **`ExcludeFocus` + `ExcludeSemantics` bật theo cờ** (P5/T9 review) · bẫy 1.
- **Cờ `_dangLam` ở `CaiDatKhoaAppCubit`** (chống chạm đôi) · bẫy 11.
- **`USE_FINGERPRINT` `maxSdkVersion=29`** (P10); **build `--release` bắt buộc trước commit Task 5** (P11).
- **Phím số: `ExcludeSemantics` trong `_Phim`**, không `excludeSemantics: true` ở `Semantics` ngoài (cắt tap) · TalkBack từng đọc "7\n7".
- **Màn khoá căn giữa theo Stitch** (Padding ngang 24 cho dòng phụ / câu lỗi) · bản đầu lệch trái (dx 133 thay 180 ở 360 × 800).
- **Bỏ mọi `runAsync` ở bốn widget test** (P14) · bẫy 13.

## 3. Luồng

```
Bật      Trang Khoá ứng dụng → công tắc → /settings/khoa-app/dat-pin?che=dat → KhoaAppService.datPin (salt 16 B, PBKDF2, ghi kho)
         → CaiDatKhoaAppCubit.sauDatPin (nạp lại trang) rồi batVanTay (nếu máy hỗ trợ + đã đăng ký): Kotlin bat → hộp "Chạm vân tay để bật"
         → cất {banMa, iv, bamBiMat}; KhoaAppCubit.napLai() (đọc lại cấu hình, KHÔNG khoá)
Khoá     (a) nhanPhien(id) lần đầu của phiên: có cấu hình → KhoaAppKhoa; không → KhoaAppMo(daBat:false)
         (b) vòng đời: hidden/paused đầu tiên ghi _roiLuc; resumed + canKhoaKhiQuayLai(roiLuc, nay, muc) → KhoaAppKhoa
Mở PIN   ManKhoa gõ đủ 6 số → cubit.nhapPin → service.kiemPin: chờ? → dangCho (không băm) ; đúng → soLanSai=0 → KhoaAppMo ;
         sai → soLanSai+1, choDen=thoiGianCho(n), GHI KHO RỒI MỚI trả
Mở vân tay  ManKhoa tự gọi moBangVanTay mỗi lanKhoa → Kotlin mo → SHA-256(biMat) so hằng thời gian với bamBiMat → mở
         (VO_HIEU → tatVanTay + xoaHet + câu "Vân tay trên máy đã thay đổi…"; HUY → ở lại; sai vân tay KHÔNG cộng soLanSai)
Quên PIN Tấm xác nhận trong ManKhoa → LogoutRequested → AuthBloc → dongPhien (xoaVanTayHet: CHỈ alias Keystore) → AuthUnauthenticated
         → cubit nhanPhien(null) → KhoaAppTat (lớp phủ gỡ, màn Đăng nhập)
Đăng nhập lại bằng MẬT KHẨU → AuthBloc → PhienDieuPhoiThat.sauDangNhap → datLaiSauDangNhap(id) xoá cấu hình (id + mọi tài khoản) + alias
         → AuthSuccess → cubit nhanPhien(id) → không cấu hình → KhoaAppMo(daBat:false)
Đổi tài khoản  AuthSuccess của id khác → nhanPhien(id mới) → KhoaAppDangXet (lớp đặc) → đọc cấu hình của id đó
Mở app chưa đăng nhập  main.dart: initialRoute == '/login' → nhanPhien(null) → KhoaAppTat ngay (bẫy 4)
```

## 4. Bản đồ tệp → việc

`src/Client-app/lib/features/khoa_app/` (đếm 2026-10-25):

| Tệp | Việc |
|---|---|
| `domain/luat_khoa_app.dart` | `TuKhoaSau` (+ `macDinh`, `tuTen`), `maPinHopLe`, `canKhoaKhiQuayLai`, `thoiGianCho`, **`conCho`**, **`chuDemNguoc`**, `kDoDaiPin`, `kSaiBatDauCho` |
| `domain/bam_ma_pin.dart` | `pbkdf2HmacSha256`, `bamMaPin`, `soSanhHangThoiGian`, `kSoVongMacDinh` (**30000, chưa đo**) |
| `data/models/cau_hinh_khoa_app.dart` | `CauHinhKhoaApp` (salt, bam, soVong, tuKhoaSau, vanTay, soLanSai, choDen) + `VanTayDaBat` |
| `data/khoa_app_store.dart` | `KhoaAppStore` + bản `flutter_secure_storage`, khoá `khoa_app_<idaccount>`; `doc` không ném, `ghi` ném |
| `data/datasources/kenh_sinh_trac.dart` | cổng kênh `flowmoney/sinh_trac` (`trangThai · bat · mo · xoaHet`), `LoiSinhTrac`, bản `Noop` |
| `application/khoa_app_service.dart` | `datPin · kiemPin · tatKhoa · datTuKhoaSau · batVanTay · tatVanTay · moBangVanTay · xoaVanTayHet · datLaiSauDangNhap` |
| `presentation/bloc/khoa_app_cubit.dart` + `khoa_app_state.dart` | trạng thái cả app: `KhoaAppDangXet · Tat · Mo(daBat) · Khoa(coVanTay, soLanSai, choDen, loiNhan, dangKiem, lanKhoa, lanKiem)` |
| `presentation/bloc/cai_dat_khoa_app_cubit.dart` | trạng thái trang Khoá ứng dụng, cờ `_dangLam` |
| `presentation/widgets/man_khoa/` | `lop_khoa_app.dart` (lớp phủ), `man_khoa.dart`, `tam_xac_nhan_quen_pin.dart` |
| `presentation/widgets/` | `cham_pin.dart`, `ban_phim_pin.dart` (dùng chung màn khoá + trang đặt PIN) |
| `presentation/pages/` | `khoa_app_page.dart`, `dat_ma_pin_page.dart` |

Chỗ nối ngoài mảng: `lib/main.dart` (dựng `KhoaAppCubit`, bọc `LopKhoaApp` ngoài `AppToast`, rẽ P2) · `lib/core/auth/phien_dieu_phoi_that.dart`
(hook `xoaKhoaApp` ở `dongPhien`, `datLaiKhoaApp` ở `sauDangNhap`) · `lib/core/di/injection_container.dart` (store, kênh, service) ·
`lib/core/router/app_router.dart` (hai route) · `lib/features/profile/presentation/widgets/noi_dung_cai_dat.dart` (hàng + viên
`_NhanKhoaApp`) · Kotlin `SinhTrac.kt` + một dòng đăng ký kênh ở `MainActivity.kt` + `USE_BIOMETRIC` / `USE_FINGERPRINT` ở manifest.
Cấu hình khoá là **cục bộ** — không vào `SyncEntityType`, không lên server.

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
   không phát gì → cubit kẹt `KhoaAppDangXet` = lớp **đặc** che màn Đăng nhập, không chạm được gì. `main.dart` rẽ
   `widget.initialRoute == '/login'` → `nhanPhien(null)`. **`main.dart` không có test** — chỗ này chỉ nghiệm thu máy được (bước 0, mục 9).
5. **Đăng xuất chỉ xoá alias Keystore; cấu hình PIN xoá ở `sauDangNhap`** (Ruling T12, đổi 2026-10-25 sau soát Task 12). Lý do:
   `AuthBloc._onLogoutRequested` = emit loading → `dongPhien` → `authRepository.logout()` (POST `/auth/logout` trước, xoá token
   **sau**, trần 30 + 30 s) → `AuthUnauthenticated`. Bản đầu xoá cấu hình ở `dongPhien` → **kịch bản vượt khoá đã chặn**: Quên PIN →
   Đăng xuất → vuốt app khỏi Đa nhiệm lúc POST treo → token còn, cấu hình mất → mở lại: `AuthSuccess` từ bộ nhớ đệm, không cấu hình
   = vào thẳng app không PIN. Nay `sauDangNhap` (**chỉ chạy sau đăng nhập bằng MẬT KHẨU thành công**, trước emit `AuthSuccess`,
   `auth_bloc.dart:271`) gọi `datLaiSauDangNhap` — mật khẩu tài khoản = đặt lại khoá, đúng nghĩa *Quên mã PIN?*. Hệ quả: băm PIN
   (PBKDF2, trong kho Keystore-encrypted của `flutter_secure_storage`) nằm lại trên máy từ lúc đăng xuất tới lần đăng nhập mật khẩu
   kế — chỉ đọc được khi root máy. Giết tiến trình giữa đăng xuất → mở lại **vẫn khoá** (an toàn). Vân tay chết ngay lúc đăng xuất
   (alias mất → `moBangVanTay` trả `VO_HIEU`, tự tắt). ⚠️ Còn mở: giết tiến trình **giữa `login()` và `sauDangNhap`** → cấu hình còn,
   token mới → đòi PIN đã quên (chiều đóng, hỏng ở phía an toàn; gỡ bằng Quên PIN → đăng xuất → đăng nhập lại).
6. **`kiemPin` khi không có cấu hình = đúng** (`dung: true`) và `store.doc` nuốt lỗi → `null`: kho hỏng **lúc màn khoá đang hiện**
   thì gõ 6 số bất kỳ cũng mở. Chấp nhận có chủ ý (spec: *"đọc hỏng = chưa bật"*; kho hỏng thì token cũng hỏng, phiên đã hỏng).
   Ngược lại `ghi` **ném** khi hỏng, để `kiemPin` không báo "sai" khi chưa ghi được lần sai.
7. **Thời gian chờ theo giờ máy** (`choDen` là `DateTime`): chỉnh giờ máy rút được thời gian chờ — giới hạn chấp nhận (spec mục 6).
   Đồng hồ lùi lúc quay lại app thì `canKhoaKhiQuayLai` trả **khoá** (không biết đã ở nền bao lâu).
8. **Một định nghĩa `conCho` / `chuDemNguoc`** (`luat_khoa_app.dart`) cho service, màn khoá và trang PIN. Đang chờ → `kiemPin` **không
   băm** (không lộ oracle đúng / sai lúc chờ). ⚠️ Chưa có ca test ghim "PIN sai lúc chờ không băm / không đổi `soLanSai`" — minor còn mở.
9. **Bật vân tay: Kotlin `bat` xoá alias cũ TRƯỚC khi hiện hộp.** Huỷ giữa chừng khi vân tay đã bật ⇒ khoá cũ mất, `mo` trả `LOI`
   (không `VO_HIEU`) — vân tay hỏng vĩnh viễn tới khi tắt / bật lại. Hai lớp chặn: `CaiDatKhoaAppCubit` chỉ gọi `batVanTay` khi
   `coVanTay` false, và cờ `_dangLam` chặn chạm đôi (hai `SinhTrac.bat` song song, lượt sau xoá alias của lượt trước).
   `KhoaAppService.batVanTay` **chưa** tự kiểm vân tay đang bật (minor còn mở).
10. **`lanKiem` thay khung `dangKiem` trung gian (P13).** Màn khoá xoá 6 chấm khi `lanKiem` đổi. Nhìn khung `dangKiem: true`
    trung gian thì sai: `nhapPin` phát `dangKiem` rồi `await kiemPin`; băm hoàn tất trong microtask thì cả hai state phát xong
    **trước** khi khung nào được dựng — `didUpdateWidget` chỉ thấy `false → false`, 6 chấm kẹt. Trên máy thật PBKDF2 ~200 ms nên
    khung ấy "tình cờ" tồn tại — logic phụ thuộc thời gian.
11. **Chấm PIN theo chỉ số** (`cham-day-$i` / `cham-rong-$i`, P1): hai loại chấm cùng khoá thì test đếm sai. Ca chấm đòi kết quả
    (`chamPin()` ở helper), không chỉ vắng mặt.
12. **Khuôn mặt Class 2 không mở được khoá Keystore**; `trangThai()` trả `hoTro` chỉ khi có sinh trắc **mạnh** (`BIOMETRIC_STRONG`),
    API ≥ 28 (API 29 chỉ có mặt mạnh → `hoTro=false`, plan-mandated). **API 24–27: chỉ PIN.** Khoá AES-GCM:
    `setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`; API ≥ 30 `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)`.
13. **Thêm vân tay mới trên máy → Keystore vô hiệu khoá** → `mo` trả `VO_HIEU` **không hiện hộp** → service `tatVanTay` + `xoaHet` →
    câu *"Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại trong Cài đặt"*; ở màn khoá nút vân tay biến mất (`coVanTay:false`).
14. **Back khi đang khoá gỡ route bên dưới** (kế hoạch chấp nhận): Back ở màn khoá không đóng app mà pop route dưới lớp phủ — không lộ
    gì, nhưng deeplink mở lúc khoá có thể mất trang đích. Back khi tấm Quên PIN mở cũng gỡ route dưới thay vì đóng tấm.
15. **Test: `google_fonts` + `tester.runAsync` làm ca ĐẦU tệp đỏ (P14).** `AppTheme.lightTheme` → `GoogleFonts.interTextTheme()` tải
    font qua HTTP; `HttpClient` của `flutter_test` trả 400 → `Exception: Failed to load font…` ném vào zone của ca đang chạy khi
    phản hồi về — phản hồi chỉ về khi có lượt event-loop **thật** (`runAsync`). `GoogleFonts.config.allowRuntimeFetching = false`
    **không cứu** (đổi sang ném *"font was not found in the application assets"*). Cách đúng: **không `runAsync`** khi kho giả +
    `bamNhanh` chỉ dùng microtask; riêng `lop_khoa_app_test` còn dựng `phien`/`vongDoi`/`cubit` trong `setUp` (ngoài FakeAsync) nên
    gọi thẳng `await cubit.nhanPhien(…); await t.pump();` thay vì đẩy vào stream.
16. **Ca canh bằng `Completer` không được `await` mù.** Ca chống chạm đôi của trang Khoá ứng dụng từng **treo ~10 phút** (timeout
    mặc định `testWidgets`) khi hồi quy, thay vì đỏ — `await b` chờ Completer không bao giờ hoàn tất. Đã dời sang `test()` ở cubit
    (`3d6a9d78`) để **đỏ ngay**. Ca mới cùng khuôn: thử bản sai và thấy nó **đỏ**, không treo.
17. **`ExcludeSemantics` trong `_Phim` (phím số)**, không `excludeSemantics: true` ở `Semantics` ngoài: cái sau cắt tap. TalkBack từng
    đọc "7\n7" (label + `Text` bên trong gộp).
18. **Bàn phím số chỉ co khi cha cho chiều cao giới hạn** (T8 ⚠️) — màn khoá và trang PIN đều có ca ở 360 × 640 / 800.
19. **Không log PIN / bí mật / bản mã** (quét 38). Cất **bản mã + IV + SHA-256(bí mật)**, không bao giờ cất bí mật 32 byte
    (`Random.secure()`); so SHA-256 bằng `soSanhHangThoiGian` (hằng thời gian).
20. **Kênh Dart ↔ Kotlin khớp tay**: tên lệnh `trangThai · bat · mo · xoaHet`, khoá `idaccount · biMat · banMa · iv · hoTro · daDangKy ·
    loi`, mã `HUY · VO_HIEU · TAM_KHOA · KHONG_HO_TRO · LOI`. `kenh_sinh_trac_noi_day_test` đọc `SinhTrac.kt`, `MainActivity.kt`,
    manifest — và canh `MainActivity` vẫn `: FlutterActivity()` (đổi sang `FlutterFragmentActivity` là đụng G100).
21. **`lintVitalRelease` có thể không chạy `NewApi` / `MissingPermission`** (mức error nhưng không fatal) — build release xanh chưa
    chứng minh P10 / P11; chỉ máy thật mới chứng minh.

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
theme) — màn này theo Stitch; (4) màu chữ phụ `#454743` (`_xamChu`), **không** `AppColors.onSurfaceVariant` (`#767872`).

## 7. Test và quét

- **98 ca** khai báo trong 13 tệp dưới `test/features/khoa_app/` (đếm 2026-10-25), cộng ca ở `phien_dieu_phoi_that_test.dart` (hook
  `xoaKhoaApp` / `datLaiKhoaApp`) và `noi_dung_cai_dat_khoa_app_test.dart` (viên *Đang bật*, kể cả `Mo(daBat:false)` và `Tat`).
- Mốc toàn bộ: xem *Lệnh hay dùng* `CLAUDE.md` (số đã sửa 2026-10-25).
- Mảng mới phải qua các quét sẵn có: 22 (`presentation/` không chạm CSDL), 25 (vị trí tệp), 27 (không `<dynamic>` trần ở `data/` +
  `application/`), 38 (không log PII). Không thêm test quét mới.

## 8. Minor còn mở (chưa sửa — từ ledger, đáng xem trước khi sửa mã)

- **Nên sửa:** ca `soSanhHangThoiGian` lọt bản sai `khac = a^b` (thiếu ca khác byte đầu / giữa — hàm so băm PIN); `pbkdf2` không chặn
  `soVong < 1` / `doDai < 1`; "đang chờ → không băm" chưa ghim (không ca PIN **sai** lúc chờ, không đếm lời gọi `bam`);
  `batVanTay` chưa kiểm vân tay đã bật (Huỷ giữa chừng làm hỏng vân tay).
- **Chú thích lệch mã** (Task 12 review, phần lớn là việc Task 13 — chỉ spec đã sửa 2026-10-25): tên + `reason` ca
  `phien_dieu_phoi_that_test.dart:176-179` ("đăng xuất là xoá PIN") tả hành vi cũ; `khoa_app_store.dart:17` doc `xoaHet` ghi "(đăng xuất)";
  `phien_dieu_phoi.dart:28-32` interface chưa ghi hợp đồng `sauDangNhap` / `dongPhien` của khoá app.
- **Khác:** BIOMETRIC_ERROR_TIMEOUT → `LOI` (nên `HUY`), SECURITY_UPDATE_REQUIRED → nên `KHONG_HO_TRO` (người chờ ở màn khoá thấy
  câu chung); `SinhTrac.kt` `xoaHet` một `try` chung quanh `forEach deleteEntry` (chưa try từng alias); `_mo` luôn emit `Mo(daBat:true)`
  kể cả `doc == null`; ABA `nhanPhien` 10→null→10 mở hộp vân tay hai lần; `batVanTay` đọc cấu hình trước hộp rồi ghi sau (đổi PIN chồng
  bật vân tay → ghi đè băm PIN cũ); chạm đôi hàng *Đổi mã PIN* mở hai trang PIN; sau *Đăng xuất* tấm xác nhận vẫn bấm được;
  tấm Quên PIN mở mà bàn phím phía sau còn trong cây semantics; `dat` khi kho đã có cấu hình ghi đè PIN không hỏi PIN hiện tại (chỉ lối
  nội bộ); ca 320 dp chưa thử nhãn dài nhất.

## 9. Checklist nghiệm thu — PHIÊN SAU (Task 13 Step 1–3, P12, các lượt soát)

**A. Chuẩn bị:** (1) chép CSDL Realme ra trước khi đụng (khuôn `D:\FlowMoney-saoluu\realme-tk10-truoc-khoa-app-<giờ>\`, `exec-out run-as … cat`
ba tệp `flowmoney.db` / `-wal` / `-shm`, so cỡ; Git Bash đặt `MSYS_NO_PATHCONV=1`); (2) bản debug cùng `--dart-define=API_BASE_URL=…` cũ.

**B. Đo số vòng PBKDF2 trên bản RELEASE** (phải đi trước nghiệm thu): thêm TẠM `Stopwatch` quanh `_bam(...)` trong `KhoaAppService.datPin`
và `debugPrint('[KhoaApp] bam ${sw.elapsedMilliseconds} ms')` (chỉ thời gian, KHÔNG PIN) → `flutter build apk --release
--dart-define=API_BASE_URL=http://127.0.0.1:3000/api` (địa chỉ nội bộ được `http`; ký debug vì không có `key.properties`) → cài, bật khoá
ba lần, `adb logcat -d | grep KhoaApp`. Mục tiêu **200–300 ms**: đổi `kSoVongMacDinh` theo tỉ lệ (vd. đo 100 ms ở 30.000 → 75.000), dựng lại,
đo lại. **Gỡ** dòng đo, cài lại bản debug, **ghi số đo vào mục 10 tệp này**. Bản debug chậm hơn release nhiều lần — đừng chọn theo debug.
Đổi `kSoVongMacDinh` không làm hỏng PIN đã đặt (số vòng cất trong cấu hình).

**C. Bước nghiệm thu (chụp màn từng bước, ghi đạt / không):**
0. *(P12, chưa đăng nhập)* đăng xuất → `am force-stop` → mở → màn **Đăng nhập chạm được, không lớp phủ**.
1. Cá nhân → *Khoá ứng dụng* → bật → đặt PIN → hộp *"Chạm vân tay để bật"* tự hiện → chạm → công tắc vân tay bật.
2. `am force-stop` → mở → màn khoá + hộp vân tay tự hiện → vân tay mở.
3. Mở → Home → ra màn chính 20 s → vào lại: không khoá; 35 s: khoá.
4. Đang khoá: chạm một thông báo FlowMoney (đổi tạm giờ *Tổng kết tuần*, trả lại sau) → mở khoá → thấy trang đích.
5. Sai 5 lần → *"Thử lại sau 00:30"* đếm ngược, phím số mờ, **vân tay vẫn mở được**.
6. Nhờ người dùng **thêm một vân tay mới** trong Cài đặt máy → mở app → câu *"Vân tay trên máy đã thay đổi…"*, vân tay tắt, PIN mở được.
7. *Quên mã PIN?* → tấm xác nhận → *Huỷ* (không đăng xuất). Nhánh *Đăng xuất* chỉ đo khi người dùng đồng ý bật backend `PersonFinance`
   + `DATA_ENCRYPTION_KEY` dev + mật khẩu postgres (*Lệnh hay dùng*).
7b. *(P12)* sau Quên PIN → Đăng xuất → **đăng nhập lại bằng mật khẩu** → không màn khoá, hàng Khoá ứng dụng **không** viên *Đang bật*.
8. G100: Back hai lần ở Trang chủ → app xuống nền (không thoát); mở lại theo luật tự khoá.
9. `adb shell dumpsys alarm | grep -c 'Alarm{.*flowmoney'` sau force-stop + mở app vẫn **3** (G106 không bị lớp khoá làm hỏng).
9b. **Quét ảnh khi khoá bật** (mức Ngay hoặc 30 s): ColorOS giết app khi mở camera / trình chọn ảnh lúc đang giữ Gemma → quay về = mở lạnh
    = màn khoá. Mở khoá xong lượt quét vẫn phải hoàn tất và điền form (ảnh chờ bên dưới).
9c. **PayOS khi khoá bật**: từ màn Chờ thanh toán sang app ngân hàng > 30 s → quay về bị khoá → mở khoá → màn Chờ vẫn hỏi `order-status`
    và chuyển đúng trạng thái.
10. Tắt khoá ở cuối buổi **chỉ khi** người dùng muốn; hỏi trước.

**D. Thêm từ các lượt soát (chưa có ca nào đo máy):**
- Giết tiến trình (vuốt khỏi Đa nhiệm) **giữa lúc đăng xuất** → mở lại vẫn khoá (bẫy 5). Trên Realme vuốt = force-stop (trừ khi D1 giữ tiến trình).
- TalkBack: phím số đọc **một lần** ("7", không "7 7"); tấm Quên PIN; nút vân tay.
- Bàn phím vật lý (Tab / Enter): không bấm được nội dung dưới lớp khoá.
- 360 dp (Realme): nhãn dài nhất — *Tự khoá sau* = "Ngay khi rời app", câu "Thêm vân tay…" — không tràn / cụt; phóng chữ.
- Hộp vân tay hết giờ (`BIOMETRIC_ERROR_TIMEOUT`) hiện câu gì (hiện đang rơi `LOI` → *"Không mở được bằng vân tay — nhập mã PIN"*).
- Hai lần chạm công tắc vân tay thật nhanh (cờ `_dangLam`).
- Máy đủ điều kiện nhưng chưa đăng ký vân tay (`daDangKy:false`): bật khoá không hiện hộp, công tắc vân tay có câu hướng dẫn.

**E. Ngoài phạm vi (spec mục 8):** ẩn số tiền · 2FA / MFA tài khoản · danh sách thiết bị / đăng xuất từ xa · mã hoá SQLite · khoá khi tắt màn
hình · miễn khoá khi rời app do chính app mở (camera, chọn ảnh, PayOS) · iOS (Face ID).

## 10. Kết quả nghiệm thu

*(Chưa có — điền ở phiên nghiệm thu: số đo PBKDF2 release, bảng đạt / không từng bước mục 9.)*
