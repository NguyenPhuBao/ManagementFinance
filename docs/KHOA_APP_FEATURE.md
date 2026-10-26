# Khoá ứng dụng bằng PIN 6 số + vân tay — tài liệu bàn giao

> **Trạng thái (2026-10-25):** ✅ **mã xong, đã qua review toàn nhánh và đợt sửa cuối** — 12 task của kế hoạch
> `docs/superpowers/plans/2026-10-24-khoa-app-pin-sinh-trac.md` (gitignore) + đợt sửa sau review (C1, I1–I4, mục nhỏ). Dải commit
> `a0c6dacf..393e626f` (30 commit, đếm 2026-10-25 trước commit tài liệu này: 22 commit thi công `a0c6dacf..92b69200` · `f6699e64`
> tài liệu Task 13 · 7 commit đợt sửa `5fa1b69c` `29405da5` (C1) · `7cef81df` (I2) · `d5cfb994` (I3) · `62cad490` (I4) · `fb4f245b` (I1) ·
> `393e626f` (mục nhỏ)).
> ◐ **Nghiệm thu Realme buổi 1 (2026-10-25, bản release) — mục 10:** đạt các bước không cần đăng xuất (bật, mở lạnh, tự khoá, sai PIN,
> vân tay, thêm vân tay mới, I1 tách riêng bằng chỉnh giờ lùi, G100, G106, chạm đôi). Buổi đo bắt **F1** (quay lại app lộ ~1 khung nội
> dung) → **đã sửa và đo lại đạt** (`Mo(che)` ở `inactive`, bẫy 25); **M11** (dòng nhắc *"Khoá ứng dụng đã tắt"*) làm theo người dùng chốt
> (bẫy 24). `kSoVongMacDinh` = **50.000** theo số đo release. 🚧 **Còn mở:** ~~mọi bước có **đăng xuất**~~ (✅ Buổi 2b); TalkBack (nghe thật);
> quét ảnh / PayOS / chạm thông báo khi khoá; 320 dp (ColorOS chặn `wm density`).
> ✅ **2026-10-25 tối (phiên 7, bản debug trên Realme):** **M5 đã sửa và đo đạt** — Back trên màn khoá đưa app xuống nền, tấm Quên PIN mở thì
> Back = Huỷ (bẫy 14, `f1daea24`); **thanh trạng thái** màn khoá tự đặt kiểu trong suốt (bẫy 26, `f1daea24` + `c5010e1b`);
> **`flutter_secure_storage` 9.2.4 → 10.3.4** (`f5a90f4b`) — kho thật 16 mục chuyển sang RSA-OAEP + AES-GCM, PIN / gói / mốc đồng bộ
> còn nguyên (mục 10, *Buổi 2*); hệ quả với I2 ở bẫy 27. Cùng tối, **các bước đăng xuất** (mục 10, *Buổi 2b*, backend `PersonFinance`):
> D-1 · 10 · 10a (mạng treo + có mạng) · 11 (có điều kiện) · 12a · 12b · M11 — **đạt**; **C1 ba đường đạt theo video** (tách khung 1/60 s).
> Lộ **M14** (mục 8): đăng xuất bị cắt giữa chừng làm vân tay tự tắt với câu *"Vân tay trên máy đã thay đổi"* → ✅ sửa cùng tối (mã `MAT_KHOA`,
> câu *"Vân tay đã tắt…"*), đo lại trên Realme đạt.
> ✅ **2026-10-25 khuya (phiên 8):** **M7 · M8 · M12 · `_napCho`** đóng (`b49217ca`, bẫy 28); thanh trạng thái **một kiểu cho cả app** (`81c09b8a`, bẫy 26);
> `WebSocketConnectionClosed` khi server cắt socket — gốc ở `socket_io_client` 3.1.6, ngoài mảng này (`f8ae62ca`). **Buổi 3 trên Realme (mục 10)**: bước **6**
> (chạm thông báo khi khoá — app sống và app đã chết) · **17** (320 dp — người dùng đổi *cỡ hiển thị*) · **21** (Quét ảnh khi khoá) · **11** (proxy giữ `/sync/pull`)
> — **đạt**; lộ **M15** (bố cục 320 dp, mục 8). Người dùng chốt **giữ** `resetOnError` (bẫy 27) và **không** miễn khoá cho lối app tự mở máy ảnh / chọn ảnh
> (spec mục 8). 🚧 Còn: TalkBack nghe thật; PayOS khi khoá (người dùng chọn bỏ khỏi buổi 3).
> Spec: `docs/superpowers/specs/2026-10-24-khoa-app-pin-sinh-trac-design.md` (đã sửa theo thiết kế cuối 2026-10-25).
> Mảng mã: `src/Client-app/lib/features/khoa_app/` (21 tệp, 2.450 dòng, đếm 2026-10-25 khuya sau phiên 8; tối 2.410, chiều 2.310) +
> `android/…/SinhTrac.kt` + hàm dùng chung `duaAppXuongNen` (`lib/shared/widgets/thoat_hai_lan.dart`).

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
- **Mất tiêu điểm khi khoá bật** (F1, 2026-10-25): kéo thanh thông báo, mở menu nút nổi, hộp vân tay / hộp quyền, hoặc rời app → nội dung
  app được che bằng nền trơn (khung cuối trước khi rời màn không mang số liệu); quay lại trong mức tự khoá thì thoáng một khung trơn rồi nội dung.
- **Quên PIN:** tấm xác nhận → *Đăng xuất* → đăng nhập lại bằng **mật khẩu tài khoản** thì khoá đã tắt và app báo một dòng *"Khoá ứng dụng đã
  tắt — bật lại trong Cài đặt"* (M11; mọi lần đăng nhập mật khẩu khi tài khoản đang bật khoá), dữ liệu máy giữ nguyên. Cần mạng. ⚠️ Đăng nhập lại bằng **tài khoản khác** thì dữ liệu cục bộ của tài khoản cũ bị dọn (mục 1b).
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
- **Ảnh trong Đa nhiệm chỉ trống từ Android 13** (`setRecentsScreenshotEnabled(false)`); API 24–32 vẫn có ảnh trang cuối. Đo Realme (Android 13)
  2026-10-25: thẻ Đa nhiệm của FlowMoney **đen trơn**. Nhưng cờ ấy **không** chặn việc engine vẽ lại khung cuối lúc quay lại app — đó là F1 (bẫy 25),
  chặn bằng lớp che ở `inactive`.
- **Khuôn mặt Class 2 không dùng được** (không mở được khoá Keystore); **API 24–27 chỉ PIN**.
- **Giờ máy:** `choDen` (thời gian chờ sau sai PIN) tính theo giờ máy — chỉnh giờ rút được thời gian chờ (spec chấp nhận). Riêng **tự
  khoá** đã chặn bằng đồng hồ khởi động (bẫy 23): chỉnh giờ lùi không vượt được khoá.
- **Đọc kho hỏng:** mở lạnh = *chưa bật* (token cùng kho; kho hỏng thì phiên đã hỏng — spec chấp nhận); nhưng sau đó màn khoá /
  kiểm PIN đọc **nghiêm ngặt** và hỏng thì **vẫn khoá** (bẫy 6). ⚠️ Từ `flutter_secure_storage` 10 (2026-10-25 tối) gói tự **xoá** mục giải mã
  hỏng và trả `null` (`resetOnError` mặc định) — trên máy thật *"hỏng"* hầu như thành *"vắng"*, tức *"chưa bật"*; chỉ xảy ra khi một mục bị sửa
  riêng lẻ (root) — bẫy 27.
- **Hệ quả thiết kế (Ruling T12 + I4):** cấu hình PIN xoá ở **mọi lần đăng nhập bằng mật khẩu** (không chỉ sau Quên PIN) — kể cả
  sau hết phiên, cưỡng chế đăng xuất, đổi mật khẩu (`change_password_page` → `LogoutRequested`). Người dùng có thể tưởng app còn khoá —
  từ 2026-10-25 có dòng nhắc *"Khoá ứng dụng đã tắt — bật lại trong Cài đặt"* (M11, bẫy 24; trừ khi kho đã bị gói xoá trước đó — bẫy 27). Băm PIN (PBKDF2, trong kho `flutter_secure_storage`) nằm lại trên máy
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

`src/Client-app/lib/features/khoa_app/` (đếm 2026-10-25 chiều sau F1 + M11: 21 tệp, 2.310 dòng):

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
   `inactive` — tính chúng thì mở khoá bằng vân tay xong là bị khoá lại ngay. (`inactive` vẫn **vẽ lớp che** F1 — bẫy 25 — nhưng không đặt mốc rời.)
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
7. **Thời gian chờ (`choDen`) theo giờ máy** (`DateTime`): chỉnh giờ máy rút được thời gian chờ — giới hạn chấp nhận (spec mục 6). Đồng hồ lùi lúc quay lại app thì `canKhoaKhiQuayLai` trả **khoá**. Chiều ngược (mốc chờ xa hơn 15 phút vì giờ máy từng chạy trước) kẹp về 15 phút — bẫy 28.
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
14. **Back khi đang khoá — `LopKhoaApp` giữ phím Back (M5, ✅ sửa 2026-10-25 tối, `f1daea24`).** Trước đó Back đi tới router và pop route dưới lớp phủ (khoá ở trang
    *Khoá ứng dụng*, Back, mở khoá → về tab Cá nhân — xác nhận trên Realme; `PopScope` của trang dưới mở hộp thoại **nằm dưới** lớp khoá, form dở bị bỏ, toast *"Nhấn lần nữa để
    thoát"* hiện **dưới** lớp khoá). Nay `_LopKhoaAppState` là `WidgetsBindingObserver`: **Khoá** → tấm Quên PIN mở thì Back = Huỷ (`ManKhoaState.xuLyBackTrenTam`; đã chạm
    *Đăng xuất* thì **giữ** tấm — đóng tấm là mở đường chạm "Quên mã PIN?" lần hai), còn lại đưa cả task xuống nền (`duaAppXuongNen`, hàm tách từ `ThoatHaiLan` — G100: không
    đóng activity); **DangXet / DangRoi** (lớp đặc) → nuốt Back; `Tat` / `Mo` → để router. ⚠️ **Thứ tự đăng ký là cả cơ chế:** Flutter 3.47.8 hỏi `didPopRoute` **theo thứ tự đăng
    ký** (`WidgetsBinding.handlePopRoute`, đọc mã trên GitHub), và `initState` của `LopKhoaApp` (cha) chạy trước `Router` con — nơi `RootBackButtonDispatcher` đăng ký. **Đừng**
    dời observer xuống `ManKhoa` (dựng sau Router → router thắng), **đừng** thay bằng `BackButtonListener` (cần `Router` phía trên — lớp khoá nằm TRÊN router), và đổi phiên bản
    Flutter thì chạy lại `lop_khoa_app_back_test.dart` (GoRouter thật; `MaterialApp(home:)` đi `_WidgetsAppState.didPopRoute` đăng ký trước lớp khoá — ca ở đó mù). Hộp vân tay
    chỉ tự hiện **một lần mỗi lần khoá**: mở lại app sau khi Back đưa nó xuống nền thì không có hộp — Back lúc ấy rơi thẳng vào màn khoá (đo trên máy).
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
20. **Kênh Dart ↔ Kotlin khớp tay**: tên lệnh `trangThai · bat · mo · xoaHet`, khoá `idaccount · biMat · banMa · iv · hoTro · daDangKy · loi`, mã `HUY · VO_HIEU · MAT_KHOA · TAM_KHOA · KHONG_HO_TRO · LOI` (`MAT_KHOA` từ 2026-10-25 tối — M14: alias không còn ≠ khoá vô hiệu). `kenh_sinh_trac_noi_day_test`
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
    đừng "sửa" bằng cách đặt hook vào `moPhienCucBo` (bẫy 5). ✅ **Dòng nhắc (người dùng chốt 2026-10-25):** `datLaiSauDangNhap` nhớ trong RAM *"tài khoản này vừa có
    khoá"* (`_vuaTatCua`, chỉ khi cấu hình của CHÍNH tài khoản ấy tồn tại — khoá của tài khoản khác bị xoá thì không nhắc); `KhoaAppCubit.nhanPhien` ở nhánh không cấu hình gọi
    `layVaXoaVuaTat(id)` (đọc là xoá — dùng một lần) rồi hàm tiêm `khiKhoaVuaTat`, `main.dart` nối với `baoNhanh(kCauKhoaVuaTat)` *"Khoá ứng dụng đã tắt — bật lại trong Cài đặt"*.
    ⚠️ Chỉ được MỘT `KhoaAppCubit` gọi `layVaXoaVuaTat` (test dựng hai cubit trên cùng service là cubit đầu tiêu cờ — vấp khi viết test).
25. **F1 — che khi mất tiêu điểm (`Mo(che)`, nghiệm thu Realme 2026-10-25, người dùng chọn lối Flutter).** Quay lại app sau ≥ mức tự khoá, engine vẽ lại **khung cuối** lên surface mới
    trước khi Dart nhận `resumed` → lộ ~1 khung nội dung (mục 10, *Phát hiện F1*). Sửa: `inactive` + khoá bật + `Mo` → `KhoaAppMo(daBat, che: true)` (lớp đặc), vì `hidden` / `paused`
    tới khi Flutter đã **tắt vẽ khung** — đặt che ở đó là không bao giờ được vẽ. `resumed`: tới mức → `Khoa`; chưa → gỡ che (`Mo(che:false)`). `che` nằm TRONG `KhoaAppMo` để mọi cổng
    `state is KhoaAppMo` của luật tự khoá giữ nguyên (đặt thành trạng thái riêng là "35 s không khoá" — ca *che rồi ở nền 29 s / 30 s* canh, bản sai đã thử). `napLai` **giữ** `che`.
    Lớp phủ: `Mo(che)` chỉ vẽ nền đặc + `AbsorbPointer`, **không** `ExcludeFocus` / `ExcludeSemantics` — cướp tiêu điểm là đóng bàn phím mỗi lần kéo thanh thông báo (ca *lớp che
    KHÔNG cướp tiêu điểm*). Cái giá người dùng chấp nhận: kéo thanh thông báo / mở menu nút nổi / hộp vân tay / hộp quyền khi khoá bật thì phía sau là nền trơn; quay lại trong mức thì
    thoáng một khung trơn. ⚠️ Test: cubit dựng ở `setUp` nghe `vongDoi` trong zone thật — state phát từ sự kiện vòng đời không tới `BlocBuilder` trong `pump` (ca xanh OAN); dựng cubit
    trong thân ca, và **đừng `await close()`** cubit cũ trong thân ca (treo cả tệp ~10 phút) — cất cho `tearDown` đóng (`cubitTrongCa`, `lop_khoa_app_test.dart`).
26. **Thanh trạng thái của màn khoá (2026-10-25 tối, `f1daea24` + `c5010e1b`).** Màn khoá không tự đặt `SystemUiOverlayStyle` thì ăn theo trang dưới: dải xám 25 % đen (màu
    mặc định của cửa sổ Android) ở trang không có AppBar (Trang chủ, Phân tích), trong suốt ở trang có AppBar (Material 3 đặt `statusBarColor` trong suốt). Nay `_KieuThanhTrangThaiKhoa`
    (`AnnotatedRegion`: trong suốt, biểu tượng tối) bọc màn khoá và lớp đặc của **ba** trạng thái che hẳn (DangXet · DangRoi · Khoa) — **không** bọc lớp che `Mo(che)`.
    ⚠️ Flutter **không tự trả kiểu cũ** khi vùng biến mất (`RenderView` chỉ gọi `setSystemUIOverlayStyle` khi TÌM THẤY vùng): trang không có `AnnotatedRegion` giữ kiểu
    trong suốt sau khi mở khoá. Đây **không** phải kiểu lệch mới — đo trên Realme: ghé tab Cá nhân (AppBar) rồi về Trang chủ là Trang chủ cũng mất dải xám tới lần mở lạnh kế.
    ✅ **Phiên 8 (2026-10-25 khuya, người dùng chọn): vùng gốc cho cả app** — `VungThanhTrangThaiGoc` (`shared/widgets/`) bọc ngoài router, TRONG `LopKhoaApp`
    (`main.dart`, ca đọc mã canh thứ tự), giá trị là hằng chung `kKieuThanhTrangThaiSang` (`shared/theme/kieu_thanh_trang_thai.dart`) — màn khoá cũng đọc hằng ấy; màn
    Quét (nền đen toàn màn, không AppBar) tự bọc `kKieuThanhTrangThaiToi` (biểu tượng sáng). Trang mới nền tối toàn màn mà không AppBar thì phải tự bọc kiểu tối, nếu không
    biểu tượng tối chìm. Hệ quả kéo theo: tấm Quên PIN phải nằm **ngoài** `SafeArea` của màn khoá (lớp mờ phủ cả
    vùng thanh trạng thái), mặt tấm tự tránh thanh điều hướng (`SafeArea(top: false)`) — trong `SafeArea` thì lớp mờ dừng ở mép dưới thanh trạng thái, để lại dải kem sáng.
27. **`flutter_secure_storage` 10 — hỏng thành vắng ở tầng native (hệ quả với I2, bẫy 4d).** Từ `f5a90f4b` gói ở **10.3.4** (ghim cứng) với `AndroidOptions` **mặc định** —
    `resetOnError = true`: đọc một mục giải mã hỏng thì gói **xoá mục ấy rồi trả `null`**; bước chuyển thuật toán hỏng thì xoá **cả kho** rồi chạy tiếp. Tức `docNghiemNgat` hầu như
    không còn thấy *"hỏng"* từ máy thật — `khoa_app_<id>` hỏng riêng lẻ thành *"chưa bật"* (mở app không PIN nếu token còn đọc được). Giữ mặc định là quyết định kỹ thuật của
    phiên 7; ✅ phiên 8 (2026-10-25) trình lại hai lựa chọn, người dùng **chốt giữ bật**: hỏng riêng một mục cần sửa tệp XML = root, ngoài mô hình đe doạ (mục 1b); còn `resetOnError = false` biến một lần chuyển
    hỏng thành **mọi** lời gọi kho ném mãi → `main.dart:76` đọc token không `try` → app chết trước `runApp`, lối thoát duy nhất là *Xoá dữ liệu ứng dụng* (mất SQLite — đúng điều
    G36 / G89 từ chối). Sàn xấu nhất của lối đã chọn: đăng xuất + khoá app tắt **không có dòng nhắc M11** (cấu hình đã mất trước lần đăng nhập mật khẩu) + tuỳ chọn về mặc định +
    kéo về toàn bộ; SQLite và alias Keystore vân tay (`SinhTrac.kt`, kho riêng) không bị đụng. ⚠️ Cấu hình gói đi theo **lời gọi đầu tiên** tới kho (native `initialize` chỉ chạy
    một lần, khoá theo tên tệp prefs) — mọi `FlutterSecureStorage()` của app dùng cùng mặc định; thêm `AndroidOptions` khác mặc định ở MỘT chỗ là cấu hình chạy hay không tuỳ chỗ
    nào gọi trước (cần một định nghĩa + test quét — số 39 còn trống). **Đừng nhảy lên 11** khi chưa chắc mọi máy đã qua 10 ít nhất một lần mở (11.0.0 bỏ đường đọc dữ liệu v9).
28. **M8 — mốc chờ xa hơn `kChoToiDa` thì kẹp VÀ GHI LẠI** (2026-10-25 phiên 8). Sai PIN lúc giờ máy chạy trước (vd. một ngày) rồi giờ được chỉnh lại → `choDen` cách hiện tại hơn
    một ngày, màn khoá bắt chờ tương ứng (vân tay / Quên PIN vẫn còn). `kepChoDen` (`domain/luat_khoa_app.dart`) kẹp mốc về `nay + kChoToiDa` (15 phút — cùng hằng với mức chờ dài nhất
    của `thoiGianCho`); `KhoaAppService.doc` / `docNghiemNgat` / `kiemPin` áp nó **và ghi mốc đã kẹp xuống kho** (ghi hỏng thì vẫn trả bản kẹp, lần đọc sau kẹp lại). ⚠️ Kẹp mà **không
    ghi** là sai im lặng: mỗi lần đọc lại (P9 lúc quay lại app, mở trang Đặt PIN) mốc dời thêm 15 phút — đồng hồ đếm ngược đứng ở `15:00` hoặc nhảy về `15:00`, không bao giờ về 0 (ca
    service *"lần đọc sau giữ đúng mốc ấy"* canh). ⚠️ Đừng đổi thành *"xa quá thì bỏ chờ"* (`conCho` trả `null`): chỉnh giờ lùi một giờ trong lúc chờ 30 s là xoá được chờ — kẹp chỉ rút
    về 15 phút, không mở thêm lối vượt nào ngoài lối chỉnh giờ tới đã chấp nhận (bẫy 7). Đang ở màn khoá mà giờ máy đổi: `resumed` khi đang `Khoa` đọc lại kho (`_lamTuoiKhoa`) — ra
    Cài đặt giờ rồi quay lại là mốc được kẹp; giờ tự đồng bộ (NTP) trong lúc nhìn màn khoá thì chỉ được kẹp ở lần rời / quay lại app kế (để lại). Lượt làm tươi ấy bỏ kết quả khi một
    lượt kiểm PIN đã bắt đầu / kết thúc trong lúc nó đọc kho (**M7** — so `lanKiem` lúc bắt đầu, ca *"lượt làm tươi về SAU một lượt kiểm"*).

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

- **166 ca** khai báo trong 18 tệp dưới `test/features/khoa_app/` (đếm bằng Python cùng mẫu 2026-10-26 sau phiên 9: +3 M15, +5 M13); trước đó **158 ca** (2026-10-25 khuya sau phiên 8: +8 M7 · M8 · M12 · `_napCho`; `flutter test` chạy ra 160 vì vòng lặp khổ màn); trước đó **150 ca** (2026-10-25 tối, sau M5 + thanh trạng thái + M14: +5 `lop_khoa_app_back_test.dart`
  (GoRouter thật), +2 `lop_khoa_app_thanh_trang_thai_test.dart`, +1 lớp mờ tấm Quên PIN ở `lop_khoa_app_test.dart`, +2 `MAT_KHOA` (service, cubit); chiều 140, trước đó 128), cộng `test/core/router/theo_doi_route_cong_khai_test.dart` (observer), ca ở `phien_dieu_phoi_that_test.dart`
  (hook `sauXacThucMatKhau` / `xoaKhoaApp` / `datLaiKhoaApp`), `auth_bloc_buoc_dang_xuat_test.dart` (thứ tự mở phiên với `PhienDieuPhoiThat` thật) và `noi_dung_cai_dat_khoa_app_test.dart` (viên *Đang bật*, kể cả `Mo(daBat:false)` và `Tat`).
- Mốc toàn bộ: **8.117 pass / 10 skip**, `flutter analyze` **20** (đo 2026-10-26 sau phiên 10 — lượt sửa 2 + 3 cỡ chữ 1,6 + `BoCucTheoFont` + quét 39, ngoài mảng khoá app trừ hàng *Tự khoá sau*; 8.090 sau phiên 9 — M15 + nút Google + M13 + lô bố cục cỡ chữ 1,6 + M16; 8.061 sau M13 — +8 khoá app, +2 `login_page_nut_google_test.dart`; 8.051 đo 2026-10-25 khuya sau phiên 8 — +8 khoá app, +2 socket `realtime_socket_dong_test.dart`, +4 thanh trạng thái; 8.037 sau M14; 8.035 sau M5 + thanh trạng thái `c5010e1b`, trên `flutter_secure_storage` 10.3.4; chiều 8.027 sau F1 + M11 `4c7945ed`; trước đó 8.017 sau `be3bdf26`; xem *Lệnh hay dùng* `CLAUDE.md`). Bản vá `be3bdf26` thêm 4 ca: hai ở
  `lop_khoa_app_roi_phien_test.dart` (`/login` tự `showDialog` → gỡ trước van; popup trên trang được bảo vệ không làm tín hiệu `true`) và hai ở `test/core/router/route_cong_khai_ten_route_test.dart`.
- Mảng mới phải qua các quét sẵn có: 22 (`presentation/` không chạm CSDL), 25 (vị trí tệp — `core/router` là chủ đề sẵn có), 27 (không `<dynamic>` trần ở `data/` +
  `application/`), 38 (không log PII — **không** canh PIN / bí mật, bẫy 19). Không thêm test quét mới.
- **Ca test còn MÙ** (chỉ máy thật / chưa có ca): dây nối `main.dart` → `phienDauChoKhoaApp` (hàm thuần đã có ca); **I1 bản ffi** (host Windows trả `null`; ca `dong_ho_khoi_dong_test` chỉ canh "null hoặc số không âm đơn điệu"); C1 trên máy thật
  (ca GoRouter thật phủ ba đường nhưng animation nền tảng khác — cần quay 60 fps); BiometricPrompt thật, ColorOS `inactive` vs `paused`; TalkBack; bàn phím vật lý trên máy (ca M13 dùng `sendKeyEvent`); bản release R8;
  bước chuyển dữ liệu của `flutter_secure_storage` 10 (mã Android gốc — chỉ logcat trên máy, bẫy 27). Back khi khoá (bẫy 14) nay có ca GoRouter thật, kênh `xuong_nen` vẫn chỉ giả.

## 8. Việc còn mở (chưa sửa — từ review toàn nhánh 2026-10-25, đáng xem trước khi sửa mã)

- ~~**M5** Back khi đang khoá pop route bên dưới~~ — ✅ **đóng 2026-10-25 tối** (`f1daea24`, người dùng chọn *"Back đưa app xuống nền"*): `didPopRoute` ở lớp khoá, tấm Quên PIN mở thì Back = Huỷ (bẫy 14); đo Realme đạt (mục 10, *Buổi 2*).
- ~~**M7** `_lamTuoiKhoa` chỉ chặn `dangKiem`~~ — ✅ **đóng 2026-10-25 (phiên 8)**: nó chụp `lanKiem` lúc bắt đầu và bỏ bản đọc khi `lanKiem` đã đổi (bẫy 28). Mô tả gốc: nếu một lượt kiểm đã kết thúc trong lúc nó đọc kho, nó phát `soLanSai` / `choDen` cũ đè bản mới (chỉ lệch hiển thị — service vẫn chặn).
- ~~**M8** `choDen` ở tương lai xa~~ — ✅ **đóng 2026-10-25 (phiên 8)**: `kepChoDen` kẹp về `nay + kChoToiDa` (15 phút) và service **ghi lại** mốc đã kẹp; `resumed` khi đang khoá đọc lại kho (bẫy 28). Mô tả gốc: giờ máy từng chạy trước rồi chỉnh lại ⇒ chờ dài tuỳ ý (còn vân tay / Quên PIN).
- ~~**M11** Mọi đăng nhập mật khẩu tắt khoá **im lặng**~~ — ✅ **đóng 2026-10-25**: người dùng chọn dòng nhắc *"Khoá ứng dụng đã tắt — bật lại trong Cài đặt"* (bẫy 24). Nghiệm thu trên máy cần đăng nhập lại bằng mật khẩu → đi cùng bước 10a (cần backend `PersonFinance`).
- ~~**M12**~~ — ✅ **đóng 2026-10-25 (phiên 8)**: `TIMEOUT` → `HUY` (hộp tự hết giờ: không câu lỗi), `SECURITY_UPDATE_REQUIRED` (hằng API 31, số nguyên — an toàn ở API 28–30) → `KHONG_HO_TRO`; `xoaHet` bọc `try` quanh **từng** `deleteEntry`. Nghiệm thu = ca đọc mã `kenh_sinh_trac_noi_day_test` + `flutter build apk --debug` biên dịch đạt — **không đo được trên máy**: hộp vân tay Realme đứng **78 s không tự hết giờ** (đo 2026-10-25), chưa máy nào cần bản vá bảo mật. Ở màn khoá `KHONG_HO_TRO` và `LOI` cùng một câu `kCauVanTayHong` — đổi mã chỉ khác ở đường bật vân tay.
  Mô tả gốc: `TIMEOUT` → `LOI`, `SECURITY_UPDATE_REQUIRED` → `LOI` (người chờ ở màn khoá thấy câu chung *"Không mở được bằng vân tay — nhập mã PIN"*); một `try` chung quanh `forEach deleteEntry`.
- ~~**M13**~~ — ✅ **mã xong + đo Realme đạt 2026-10-26 (phiên 9, buổi 4 — `adb keyevent` hàng số + bàn số + Backspace, bản release)**, người dùng chọn làm: `ManKhoa` bọc `Focus` (nút tiêu điểm riêng, **xin tường minh** sau khung đầu —
  `autofocus` không chạy khi phạm vi gốc còn nhớ tiêu điểm của route bên dưới) nghe hàng số + bàn số (`digit0–9`, `numpad0–9`) và Backspace; phím khác đi tiếp
  (Tab / Enter / Space giữ nguyên). Luật tắt số **một** định nghĩa `_tatSo` (đang chờ ∨ đang kiểm) cho cả phím trên màn lẫn bàn phím; tấm Quên PIN mở thì bỏ qua
  phím. Test: 5 ca ở `lop_khoa_app_test.dart` (gõ + Backspace + bàn số → mở khoá, chấm theo phím, đang chờ không lọt số, tấm Quên PIN, ô đang gõ bên dưới không
  nhận phím) — năm bản sai đều đỏ. Mô tả gốc: lớp phủ không nhận phím số của bàn phím vật lý (chỉ Tab + Enter từng phím).
- ~~**M15**~~ — ✅ **mã xong + đo Realme đạt 2026-10-26 (phiên 9, buổi 4 mục 10 — cả cỡ chữ 1,6)**, người dùng chọn *"giá trị xuống dòng khi chật"*: `_hang(giaTri:)` của `khoa_app_page.dart` đo bề rộng tiêu đề
  và giá trị bằng `TextPainter` (họ chữ của `DefaultTextStyle` + `MediaQuery.textScalerOf` — đỡ cả cỡ chữ lớn); tiêu đề không vừa một dòng bên cạnh giá trị thì giá
  trị + mũi tên xuống dưới dòng phụ, còn lại giữ bố cục Stitch `129c2d77` (lệch Stitch có chủ ý, chỉ ở khổ hẹp). Test: 3 ca ở `khoa_app_page_test.dart` (320 dp +
  *Ngay*, khổ 600 giữ một hàng, cỡ chữ 1,5 ở **480 dp** — ở 411 dp font test chật cả ở cỡ 1 nên ca mù với bản quên `textScaler`, đã thử), ba bản sai đều đỏ. Mô tả gốc
  (Buổi 3, 320 dp): khi giá trị là *"Ngay khi rời app"*, cột phải chiếm chỗ → tiêu đề *"Tự khoá sau"* gãy 2 dòng, dòng phụ gãy 4 dòng (không tràn, 0 điểm vàng —
  chỉ chật). Cùng buổi, ngoài mảng này: nút **Google** màn Đăng nhập gãy *"Goo / gle"* ở 320 dp — sửa cùng phiên (đệm ngang 12 + nhãn một dòng tự co,
  `login_page_nut_google_test.dart`).
- **M16** (Buổi 4, 2026-10-26) Có phím bàn phím vật lý là Android vẽ **khung tiêu điểm mặc định** (xanh-vàng (167, 209, 39), vài px) quanh cả `FlutterView` — mọi màn, chạm màn là mất; có cả trước M13 (Tab). Người dùng chọn **tắt viền** — ✅ **mã xong phiên 9**: `android:defaultFocusHighlightEnabled=false`
  ở `LaunchTheme` + `NormalTheme` của cả bốn `styles.xml` (`values`, `-night`, `-v31`, `-night-v31` — Realme Android 13 đọc `-v31`); `View` đọc giá trị mặc
  định từ theme. Ca đọc tệp `test/core/khung_tieu_diem_android_test.dart` (vùng mù). ✅ Đo Realme đạt (buổi 4, bản `626c6060`: Tab + gõ PIN bằng phím, mép
  màn vẫn nền).
- ~~**M14**~~ — ✅ **đóng 2026-10-25 tối** (người dùng chọn *sửa câu báo*): Kotlin `mo` trả mã mới **`MAT_KHOA`** khi `getKey` ra `null` (alias không còn) —
  `KeyPermanentlyInvalidatedException` vẫn là `VO_HIEU`; Dart `LoiSinhTrac.matKhoa` → service tự tắt vân tay như `voHieu`, cubit báo **`kCauVanTayDaTat`**
  *"Vân tay đã tắt — nhập mã PIN rồi bật lại trong Cài đặt"*. Thứ tự đăng xuất (`dongPhien` trước POST) **giữ nguyên** (bẫy 4). Test: 4 ca (dịch mã, nối dây Kotlin
  đòi `if (khoa == null)` → `"MAT_KHOA"`, service, cubit) — đỏ trước khi sửa. Đo Realme: lặp D-1 → màn khoá báo đúng câu mới, vẫn khoá. Mô tả gốc:
  (nghiệm thu Realme 2026-10-25 tối, bước D-1) Đăng xuất bị cắt giữa chừng → vân tay **tự tắt** với câu báo **sai lý do**. `AuthBloc._onLogoutRequested`
  chạy `dongPhien()` (xoá alias Keystore vân tay, bẫy 4) **trước** `authRepository.logout()` (POST rồi mới xoá token); giết tiến trình giữa lúc POST treo thì token +
  cấu hình PIN còn (đúng bẫy 5 — vẫn khoá) nhưng alias đã mất → lần mở sau kênh trả `VO_HIEU` → `tatVanTay` + *"Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại
  trong Cài đặt"* dù người dùng không đổi vân tay nào. An toàn không đổi (vẫn khoá, PIN mở). Hướng sửa (chưa chọn — hỏi người dùng): Kotlin `mo` phân biệt *alias không còn*
  (`containsAlias` sai) với *khoá bị vô hiệu* (`KeyPermanentlyInvalidatedException`) → câu riêng *"Vân tay đã tắt — …"*; hoặc dời xoá alias về sau `logout()`.
- **Sau soát lại đợt sửa (2026-10-25, để lại):** ~~`DatMaPinPage._napCho` đọc kho kiểu khoan dung và nuốt lỗi~~ — ✅ **đóng 2026-10-25 (phiên 8)**: đọc `docNghiemNgat`; đọc hỏng = *không biết* có cấu hình → chế độ `dat` cũng đổi sang hỏi PIN hiện tại (`kiemPin` gặp kho hỏng báo *"Không kiểm được mã PIN"*, không ghi đè; ca *"kho ĐỌC HỎNG"* `dat_ma_pin_page_test`). Từ `flutter_secure_storage` 10 mục giải mã hỏng tự thành *vắng* (bẫy 27) nên đường này chỉ còn với lỗi kênh / JSON hình lạ. `TheoDoiRouteCongKhai`: `didPop` / `didRemove` có thể ghi một popup qua `previousRoute` (kẹt `false` tới lần push kế — chiều đóng, van an toàn gỡ),
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

**Buổi 1 — 2026-10-25 chiều, Realme RMX2205 (Dimensity 1100, Android 13, 360 dp), bản RELEASE** (ký debug, `API_BASE_URL=http://127.0.0.1:3000/api`,
backend TẮT — app giữ phiên nhờ G86). Nghiệm thu làm trên bản release chứ không debug như mục 9 dặn: tốc độ băm và hiệu ứng là của bản người dùng
nhận, và `debugPrint` vẫn ra logcat ở release. Hai dòng log TẠM (thời gian băm, vòng đời + đồng hồ khởi động) có trong bản đo, gỡ trước commit.
A1: CSDL chép ra `D:\FlowMoney-saoluu\realme-tk10-truoc-khoa-app-2026-10-25-1430\` (335.872 byte, máy không có `-wal` / `-shm`; `integrity_check` ok,
v31, tài khoản 10 — 134 giao dịch) kèm `FlutterSecureStorage.xml` (mã hoá bằng Keystore — chỉ dùng lại được trên chính máy này).

**B. Số vòng PBKDF2** — đo trên release, `Stopwatch` quanh `compute` (gồm dựng isolate — đúng thời gian người dùng chờ):

| Số vòng | Thời gian |
|---|---|
| 30.000 | 193 ms (lần đặt PIN) · 160 ms · **245 ms** (kiểm PIN lần đầu sau mở lạnh) |
| 60.000 | 324 ms |
| 100.000 | 535 ms |
| 150.000 | 796 ms |

≈ 5,3 ms / 1.000 vòng → **`kSoVongMacDinh` = 50.000** (dự kiến ~265 ms, lần đầu sau mở lạnh ~350 ms). PIN đặt ở 30.000 vẫn mở được (số vòng cất cùng băm).
Đo lại ở 50.000 (release): **297 ms** đặt PIN · **330–357 ms** kiểm lần đầu sau mở lạnh · 330 ms khi app còn sống. Bản **debug**: phím cuối → Trang chủ
**0,45–0,8 s** (chụp màn liên tục trên máy, lần kiểm thứ hai trong tiến trình).

**C. Từng bước:**

| Bước | Kết quả |
|---|---|
| 1 Bật | ✅ Công tắc → Đặt PIN hai lần → hộp vân tay **tự hiện** → Huỷ = chỉ PIN (trang hiện *Đổi mã PIN*, *Mở bằng vân tay* tắt, *Tự khoá sau 30 giây*). Chạm giữa hàng không bật công tắc — cùng quy ước với Cài đặt thông báo (chỉ công tắc nhận chạm), không phải lỗi |
| 1b Bật vân tay | ✅ Công tắc *Mở bằng vân tay* → hộp hệ thống → chạm → bật (lần đầu, alias chưa có — `deleteEntry` không ném, T5). Kéo thanh thông báo khi hộp đang mở = hộp huỷ, công tắc giữ tắt |
| 2 Mở lạnh **[quay]** | ✅ PIN: màn khoá → PIN → Trang chủ. Vân tay: hộp tự hiện **đúng một lần** → chạm → Trang chủ. Video (trình ghi ColorOS, khung cách 16,5–18 ms khi màn đổi; tách khung bằng WinRT `MediaComposition.GetThumbnailAsync` — `scratchpad/tachkhung.ps1` của phiên): màn chờ (logo) mờ dần → lớp đặc trơn (`DangXet`) → màn khoá hiện dần → đen (hộp sinh trắc là cửa sổ bảo mật — trình ghi bôi đen **cả màn**). **Không khung nào lộ nội dung** |
| 3 Ở nền (30 s) | ✅ 20 s → quay lại không khoá; 35 s → khoá. *(Mức Ngay, tắt màn hình bằng nút nguồn: chưa)* |
| 4 Quay lại sau ≥ mức **[quay]** | ❌ bản đầu **LỘ MỘT KHUNG** (*Phát hiện F1* dưới bảng) → ✅ **sau sửa F1** (bản release `17db9f65…`, mức *Ngay*, vân tay tắt để hộp sinh trắc không bôi đen video): **(A)** Home → mở lại bằng `am start`: khung đầu của hiệu ứng mở là khối sáng trơn, rồi màn khoá hiện dần — không khung Trang chủ nào; **(B)** mở từ **Đa nhiệm**: thẻ FlowMoney đen → thẻ đen phóng to → màn khoá; **(C)** kéo thanh thông báo: thanh của ColorOS đục, che kín — lớp che phía sau không thấy được; thu thanh lên thì app đã `resumed`, nội dung hiện lại (cái giá người dùng chấp nhận không lộ ra mắt trên Realme) |
| 9 bis Thêm vân tay mới (làm lại) | ✅ Vân tay bật → thêm một vân tay trên máy (máy 1 → 2 vân tay) → quay lại: **không** có hộp sinh trắc (không `handleAuthenticate`, không `inactive` sau `resumed`), màn khoá báo *"Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại trong Cài đặt"*, phím vân tay biến mất, công tắc tự tắt; PIN mở được |
| 5 ColorOS + BiometricPrompt | ✅ Hộp vân tay (ở trang Cài đặt và ở màn khoá) chỉ gây **`inactive`**, không `paused` → không tính rời app; mức *Ngay* + bật vân tay không bị khoá ngay |
| 7 Sai PIN | ✅ Lần 5 → *"Sai mã PIN quá nhiều lần · Thử lại sau 00:30"* đếm ngược, phím số mờ, **phím vân tay vẫn bấm được**; `force-stop` giữa lúc chờ → mở lại vẫn chờ; lần 6 → 01:00; **mở bằng vân tay giữa lúc chờ** → vào app, đếm về 0. **P9** ✓: sai 5 lần ở trang *Đổi mã PIN* → rời app (mức *Ngay*) → màn khoá hiện ngay *"Thử lại sau 00:16"*. Lần 7 / 8 không chờ (đã có test luật) |
| 8 Vân tay | ✅ Mở được (hai ngón đăng ký khác nhau). Ngón chưa đăng ký 5 lần → *"Vân tay tạm bị khoá — thử lại sau hoặc nhập mã PIN"*, `soLanSai` không tăng. **Hộp không tự hết giờ** — đứng 78 s chưa có `TIMEOUT` (M12 gần như không xảy ra trên máy này). Câu báo hai dòng đẩy chấm + bàn phím xuống ~53 px (không tràn). Chạm phím vân tay hai lần nhanh: xem hàng 22 |
| 9 Thêm vân tay mới | 🚧 **Chưa đo được** — lượt 1 người dùng tự tắt *Mở bằng vân tay* trong app trước khi thêm vân tay, nên lúc quay lại không có hộp là vì vân tay đã tắt, không phải nhánh `VO_HIEU` (lúc đầu ghi nhầm là đạt — người dùng đính chính). Đo được một vế: **xoá** bớt vân tay trên máy thì khoá Keystore vẫn hợp lệ (đúng chuẩn Android) — hộp vẫn hiện, ngón đã xoá không khớp, ngón còn lại mở được |
| D Nhãn dài nhất 360 dp | ✅ *"Ngay khi rời app"* vừa ở bảng chọn và ở hàng *Tự khoá sau* (dòng phụ của hàng xuống 3 dòng, không tràn) |
| 13 I1 bản ffi | ✅ `CLOCK_BOOTTIME` đọc được trên Android **release** (qua R8): `kd` = 621.834.902 ms, tăng 14.335 ms đúng bằng giờ tường trong cùng quãng |
| 13a Tắt màn hình (+ bước 3) | ✅ Mức 5 phút, nút nguồn tắt màn hình ~7 phút → mở máy → vào app: **khoá**; đồng hồ khởi động tăng 6,93 phút qua lúc tắt màn hình (máy đang sạc — không chứng minh được máy đã vào ngủ sâu). Lượt này người dùng đặt nhầm giờ +1 giờ nên giờ tường cũng vượt mức — xem 13b cho phép thử tách riêng |
| 13b Chỉnh giờ lùi (I1 tách riêng) | ✅ Mức 1 phút. **Đối chứng:** ở nền 50 s, không chỉnh giờ → không khoá (hai đồng hồ cùng +49,9 s). **Phép thử:** ở nền 70 s → lùi giờ máy về *rời app + 20 s* (`adb shell cmd alarm set-time <ms>` — shell **được** quyền này trên ColorOS; `settings put global auto_time` thì bị chặn) → mở app: giờ tường +19,7 s (< mức), đồng hồ khởi động +90,2 s → **khoá**. Trước I1 lượt này vào thẳng app. Trả giờ về đúng bằng cùng lệnh |
| 14 G100 | ✅ Back hai lần ở Trang chủ → app xuống nền, tiến trình giữ nguyên (pid 16505) → mở lại: màn khoá. Gỡ khỏi Đa nhiệm (không giữ Gemma) → `onStackRemoved`, tiến trình **sống** (dịch vụ D1) → mở lại: activity mới + màn chờ, engine dựng lại trong tiến trình cũ → **màn khoá**. *(Đường đang giữ Gemma — `onDestroy` giết tiến trình: chưa đo, phải nạp mô hình)* |
| 15 G106 | ✅ Báo thức FlowMoney 4 → `force-stop` 0 → mở + mở khoá: **4** (số tuyệt đối đổi theo dữ liệu — mục 9 ghi 3 là số của ngày khác; điều cần là về đúng số trước) |
| 16 Release | ✅ kênh `flowmoney/sinh_trac` sống sau R8 (`trangThai` · `bat` · `mo` chạy); `dart:ffi` sống sau R8; băm trong isolate không giật giao diện (kiểm ~300 ms, chấm xoá ngay khi xong) |
| 17 Bố cục 320 dp | ⛔ **Không đo được** — ColorOS chặn `wm density` (`WRITE_SECURE_SETTINGS`); dựa vào widget test 360 × 640 / 800 |
| 18 TalkBack | ◐ **Qua cây trợ năng, chưa nghe bằng TalkBack** (người dùng bỏ qua lượt nghe): `uiautomator dump` lúc khoá chỉ có nút của màn khoá (*"Nhập mã PIN · Mở khoá FlowMoney · Đã nhập 0 trên 6 số"*, phím `0`–`9` mỗi phím **một** nhãn, *Xoá*, *Quên mã PIN?*) — không nút nào của trang dưới. Tấm Quên PIN + TalkBack chưa thử |
| 20 Back khi khoá | ⚠️ **M5 xác nhận** buổi 1: Back trên màn khoá không lộ gì, không thoát, nhưng **gỡ route bên dưới** — khoá ở trang *Khoá ứng dụng*, Back, mở khoá → về tab Cá nhân. → ✅ **sửa + đo đạt ở Buổi 2** (dưới) |
| 22 Chạm đôi | ✅ Chạm đôi hàng *Đổi mã PIN* → **một** trang PIN (Back một lần là về); trang đòi *PIN hiện tại*. Chạm đôi phím vân tay trên màn khoá → hệ thống nhận 2 yêu cầu cách 27 ms, yêu cầu sau huỷ yêu cầu trước — **một** hộp |

**Phát hiện F1 (bước 4, 2026-10-25) — quay lại app sau ≥ mức tự khoá lộ ~1 khung Trang chủ.** Video lượt *Home → 35 s → mở lại*: khung
69,683–69,717 s là launcher + cửa sổ chờ tối mờ dần vào; **khung 69,767 s (~33 ms) là Trang chủ của app, thu nhỏ trong hiệu ứng mở, hơi tối,
đọc được số dư *-3.256.000 đ* và giao dịch *100.000 đ***; 69,800 s cửa sổ đen; từ 69,850 s đen cả màn (hộp vân tay). Logcat cùng lượt:
`SnapshotStartingWindow` vẽ lúc 14:50:04,702 · cửa sổ `MainActivity` `finishDrawing` lúc **04,777** · Dart nhận `resumed` lúc **04,806** (khoá
phát sau đó). Tức có một khung được vẽ lên surface mới **trước** khi Dart biết đã quay lại — giả thuyết mạnh nhất: engine vẽ lại *lớp cuối*
(Trang chủ) khi surface dựng lại (đúng cảnh báo của bước 4). Giả thuyết phụ: ảnh `TaskSnapshot` (chụp lúc 14:49:29,564 — chỉ **58 ms** sau
`inactive` ở 29,506; `hidden`/`paused` tới 30,001) — nhưng thẻ Đa nhiệm của FlowMoney **đen trơn** (`setRecentsScreenshotEnabled(false)` có tác
dụng ở Đa nhiệm), nên ảnh chụp nhiều khả năng không mang nội dung. Mở lạnh (bước 2) không dính vì engine mới không có lớp cuối.

**Cách đo trên Realme (cho buổi sau):** ColorOS **cấm** `adb shell screenrecord` (*Permission denied*) — quay bằng trình *Ghi màn hình* của máy
(người dùng bật / tắt; video ở `/sdcard/Pictures/Screenshots/Record_*.mp4`, khung cách 16,5–18 ms khi màn đổi, bỏ khung khi màn đứng yên). Máy tính không
có ffmpeg / OpenCV / PIL — tách khung bằng WinRT `Windows.Media.Editing.MediaComposition.GetThumbnailAsync(…, NearestFrame)` qua **Windows PowerShell 5.1**
(pwsh 7 không có WinRT; `Clips.Add` phải gọi qua `ICollection<MediaClip>.Add` bằng reflection), gộp khung trùng bằng MD5 rồi xem từng khung khác nhau. Hộp
sinh trắc là cửa sổ bảo mật → trình ghi bôi đen **cả màn** khi nó mở: lượt cần nhìn liền mạch khung khoá thì **tắt vân tay**. Neo giờ video theo logcat,
không theo đồng hồ shell (`am start` tới ATM chậm ~0,7 s). Giờ máy: `adb shell cmd alarm set-time <epoch ms>` chạy được; `wm density` và `settings put
global auto_time` bị chặn. `uiautomator dump` có lúc trả *null root node* (dịch vụ trợ năng của người dùng) — rơi về toạ độ đã đo + ảnh chụp.

**Ghi nhận phụ:** thanh trạng thái ở màn khoá có dải xám (≈ 25 % đen) — Trang chủ vốn có dải ấy (không AppBar), màn khoá
không tự đặt `SystemUiOverlayStyle` nên ăn theo trang nằm dưới (→ ✅ sửa ở Buổi 2, bẫy 26). Khuôn mặt (Sensor 4, modality 8) — logcat hệ thống: *"cannot participate in Keystore
operations"*, đúng giới hạn Class 2 (mục 1b). Hộp sinh trắc chặn `screencap` (ảnh 0 byte) — chụp bước có hộp vân tay phải nhờ người dùng nhìn.

**Buổi 2 — 2026-10-25 tối (17:40–18:35), Realme, bản DEBUG** (`API_BASE_URL=http://127.0.0.1:3000/api`, backend TẮT). Người dùng vắng — Claude thao tác
bằng adb (PIN gõ qua toạ độ phím đọc từ `uiautomator`); **chạm vân tay chưa thử** (cần người dùng). Sao lưu trước buổi (force-stop rồi chép, so cỡ từng byte):
`D:\FlowMoney-saoluu\realme-tk10-truoc-nang-secure-storage-10-2026-10-25-1740\` (ba tệp CSDL + cả thư mục `shared_prefs/`, 10 tệp).

| Việc | Kết quả |
|---|---|
| `flutter_secure_storage` 9.2.4 → 10.3.4 (`f5a90f4b`), cài đè bản debug | ✅ Kho trước khi cài: **16 mục** mang tiền tố (token, `khoa_app_10`, `goi_tai_khoan_*`, `sync_last_pull_v2_*`, `notification_prefs_10`, công tắc AI…), không dấu thuật toán. Lần mở đầu, logcat `FlutterSecureStorage`: một dòng `E` *"EncryptedSharedPreferences initialization failed. Falling back to custom ciphers"* (gói dò kho kiểu cũ app không dùng — vô hại) → *"Algorithm changed detected"* → `FROM=RSA_ECB_PKCS1Padding, TO=RSA_ECB_OAEPwithSHA_256andMGF1Padding` → *"Successfully decrypted 16 items"* → *"committed 16 items"* → *"Migrated 16 items"*, **~160 ms**, không có *"Deleting all data"*. Sau đó: 16 mục còn đủ; thêm tệp dấu `FlutterSecureStorageConfiguration:FlutterSecureStorage.xml`, khoá AES bọc mới trong `FlutterSecureKeyStorage.xml` (bên cạnh khoá cũ), hai mục `__androidx_security_crypto_encrypted_prefs_*_keyset__` do lượt dò để lại (không tiền tố → `readAll` bỏ qua). Hộp vân tay **tự hiện** (đọc được `khoa_app_10`); PIN 135790 mở → Trang chủ, vẫn đăng nhập |
| Lần mở thứ hai (force-stop) | ✅ **Không** còn dòng nào của gói (không dò, không chuyển lại); hộp vân tay tự hiện; PIN mở; kéo về từ mốc `2026-10-24T12:33:48Z` (mốc `sync_last_pull_v2_10` còn, không kéo toàn bộ); Premium *"Còn 11 ngày"* (đọc kho gói khi `lamMoi` hỏng); trang *Khoá ứng dụng*: vân tay bật, *Tự khoá sau 30 giây* |
| Bản `--release` | ✅ dựng đạt qua R8 (226,9 MB) — không cài (dữ liệu đo nằm ở bản debug) |
| 20 Back khi khoá — M5 (`f1daea24`) | ✅ Trang *Khoá ứng dụng* → Home 32 s → mở: khoá, hộp vân tay → Back huỷ hộp → **Back trên màn khoá → launcher**, tiến trình giữ nguyên (pid 21563) → mở lại (không có hộp — một lần mỗi lần khoá) → Back → launcher lần nữa → mở → PIN → **đúng trang *Khoá ứng dụng*** (buổi 1: về tab Cá nhân). Tấm Quên PIN mở → Back → **tấm đóng, app vẫn ở màn khoá**. Lớp đặc lúc mở lạnh (lần đầu sau cài bản debug ~10 s mới hết `DangXet`) → Back → app ở lại |
| Thanh trạng thái (`f1daea24` + `c5010e1b`) | ✅ Lớp đặc lúc mở lạnh và màn khoá: thanh trạng thái **trong suốt** (màu kem), biểu tượng tối — hết dải xám dù Trang chủ nằm dưới. Tấm Quên PIN bản đầu: lớp mờ dừng dưới thanh trạng thái, để lại dải kem sáng → `c5010e1b` → đo lại: lớp mờ phủ liền cả thanh trạng thái |
| Vân tay sau khi nâng kho | ✅ 18:50 người dùng chạm phím vân tay trên màn khoá → hộp hệ thống 2 s → Trang chủ (người dùng xác nhận đã chạm vân tay, không nhập PIN) |

Bẫy của buổi: Back trên màn khoá nay **đưa app xuống nền**, mà hộp vân tay chỉ tự hiện một lần mỗi lần khoá — một phím Back "để huỷ hộp" ở lần mở thứ
hai rơi vào màn khoá, và sáu cú chạm PIN kế đó rơi vào **launcher** của người dùng (vùng trống, không mở app nào). Kiểm `mCurrentFocus` trước **mỗi**
chuỗi chạm, kể cả giữa hai lệnh của cùng một lượt.

**Buổi 2b — 2026-10-25 tối (18:53–19:16), Realme, bản debug, các bước ĐĂNG XUẤT.** Điều kiện A: kiểm danh tính CSDL trước (script chỉ đọc:
`current_database()` = `PersonFinance`, tài khoản 10 `Active`), sao lưu `D:\FlowMoney-saoluu\realme-tk10-truoc-dang-xuat-2026-10-25-1853\` (CSDL + `shared_prefs/`;
⚠️ tên tệp `FlutterSecureStorageConfiguration:FlutterSecureStorage.xml` có dấu `:` — trên NTFS cần chú ý khi khôi phục), backend nền trỏ `PersonFinance` +
`DATA_ENCRYPTION_KEY` dev + `adb reverse tcp:3000`. Lượt đầu nối backend: `/auth/profile`, `/subscription-info`, `/sync/pull` đều 200, không lỗi giải mã.
⚠️ App đi qua `adb reverse` (USB) nên **chế độ máy bay không làm POST treo** — "mạng treo" giả bằng một máy chủ TCP nhận kết nối mà không trả lời
(`node may_chu_treo.js 3001` + `adb reverse tcp:3000 tcp:3001`; ba script đo của buổi — `may_chu_treo.js`, `tach_khung.ps1`, `kiem_tk10.js` (kiểm danh tính CSDL, chỉ đọc) — lưu ở `D:\FlowMoney-saoluu\cong-cu-do\`); `receiveTimeout` 30 s. Người dùng quay video (trình *Ghi màn hình*), Claude điều khiển
bằng adb; khoá tài khoản thử bằng API admin `PATCH /api/admin/updatestatus/10` (`iduser` = 10), mở lại ngay sau mỗi lượt (đọc CSDL xác nhận `Active`).

| Bước | Kết quả |
|---|---|
| D-1 Giết tiến trình giữa lúc đăng xuất | ✅ Máy chủ treo → *Quên mã PIN?* → *Đăng xuất* (POST `/api/auth/logout` tới máy chủ treo lúc 18:58:31,5; tấm giữ hai nút khoá — M9) → force-stop sau 2,4 s → trả backend thật → mở lại: **vẫn khoá**, PIN mở được, vẫn đăng nhập. ⚠️ Lộ **M14**: màn khoá báo *"Vân tay trên máy đã thay đổi…"*, nút vân tay biến mất — `dongPhien` đã xoá alias trước POST (mục 8). → Sửa (`MAT_KHOA`), lặp lại D-1 lúc 19:37: màn khoá báo *"Vân tay đã tắt — nhập mã PIN rồi bật lại trong Cài đặt"*, vẫn khoá ✅ |
| 10a mạng treo **[quay]** | ✅ Tấm khoá nút suốt 30 s POST treo → hết giờ → màn Đăng nhập. **Video** (`Record_2026-10-25-19-00-42.mp4` trên máy, t = 98,600 → 98,717 s): màn khoá + tấm chuyển **thẳng** sang Đăng nhập, mọi khung khác biệt sau đó là màn Đăng nhập — **C1 đường 1 đạt** |
| 10 / P12 | ✅ Force-stop → mở lại: màn Đăng nhập, chạm ô *Tên đăng nhập* → nhận tiêu điểm, bàn phím hiện, không lớp phủ |
| M11 trên máy | ✅ Đăng nhập lại bằng mật khẩu → **không** màn khoá, dòng nhắc *"Khoá ứng dụng đã tắt — bật lại trong Cài đặt"*, hàng *Khoá ứng dụng* ở Cá nhân không còn viên *Đang bật*, dữ liệu còn (kéo về cùng mốc cũ — không bị dọn). Nhắc cả sau đăng nhập ở đường cưỡng chế (12b) |
| 10a có mạng **[quay]** | ✅ POST logout 200 trong 46 ms; video (`Record_2026-10-25-19-06-08.mp4`, t ≈ 61,1 → 61,2 s): tấm → Đăng nhập, không khung lạ |
| 11 Vuốt khỏi Đa nhiệm sau Quên PIN | ◐ **Đạt có điều kiện**: force-stop 2,8 s sau khi chạm *Đăng nhập* → mở lại vào thẳng Trang chủ, **không** hỏi PIN cũ. Nhưng lượt đồng bộ đầu (backend cục bộ) xong trong < 1 s, tức lần giết rơi **sau** lượt ấy — không chen được vào *giữa* lượt. Thứ tự xoá cấu hình ngay sau `login()` (I4) do test đơn vị canh. Muốn đo đúng "giữa lượt" cần proxy giữ riêng `/sync/pull` |
| 12b Phiên chết lúc mở lạnh **[quay]** | ✅ App tắt → admin khoá TK10 → mở lạnh: `/auth/profile` 401 → đăng xuất + hộp thoại *"Tài khoản đã bị vô hiệu hoá. Lý do: …"*. **Video** (t ≈ 313,8–322 s, 552 khung, 51 khác nhau): launcher → hiệu ứng mở → splash → lớp đặc → màn khoá → lớp đặc (`DangRoi`) → Đăng nhập → hộp thoại — **không khung nội dung**; C1 đường 3 đạt |
| 12a Cưỡng chế khi đang khoá **[quay]** | ✅ App mở, đang khoá → admin khoá TK10 → socket `account.force_logout` (logcat *"Bị buộc đăng xuất: biKhoa"*) → **video** (t ≈ 459–460 s): màn khoá → lớp đặc (459,283 s) → Đăng nhập + hộp thoại (459,617 s) — C1 đường 2 đạt |

Cách đọc video: `tach_khung.ps1` (WinRT `GetThumbnailAsync`, `NearestFrame`, Windows PowerShell 5.1) quét thô 1 s / khung để định vị bằng **cỡ tệp
JPEG** (432 × 960: màn khoá ≈ 26 KB · lớp đặc ≈ 11,7 KB · splash ≈ 14,5 KB · Đăng nhập ≈ 45 KB, có hộp thoại ≈ 50 KB · tấm Quên PIN ≈ 41 KB · launcher
≈ 110 KB), rồi tách 1/60 s quanh chỗ chuyển, gộp khung trùng bằng MD5 và **mở xem mọi khung có cỡ lạ** (đều là hiệu ứng mở app / splash mờ dần).
Mốc giờ: tên tệp video = giờ máy lúc bắt đầu; giờ máy chậm hơn giờ PC ~1 s (logcat 19:13:47,9 so với PC 19:13:48,9).
Quan sát ngoài khoá app: lúc server cắt socket (12a), logcat có `Unhandled Exception: WebSocketConnectionClosed` từ `socket_io_client`
(`IOWebSocket.close`) — app vẫn chạy đúng. ✅ Phiên 8: gốc ở `WebSocketTransport.doClose` (gọi `close()` không `await`) — sửa bằng lớp bọc
`WebSocketDongEm` (`f8ae62ca`), đo lại Buổi 3 không còn dòng ấy.
Cuối buổi: khoá app BẬT lại (PIN 135790, vân tay — người dùng chạm, *Tự khoá sau* 30 giây); backend + máy chủ treo đã tắt; token admin tạm đã xoá.
Dấu vết để lại trong CSDL dev `PersonFinance` (cố ý, không dọn): `auditlog` có hai cặp *"Khóa tài khoản"* / *"Mở khóa tài khoản"* cho tài khoản 10 (admin,
lý do *"Kiem thu khoa ung dung - tam thoi"*, 19:11 và 19:13), bốn `refreshtoken` mới của tài khoản 10 + một của admin, `account.Update_at` của tài khoản 10 đổi.

**Buổi 3 — 2026-10-25 khuya (20:47–21:42, phiên 8), Realme, bản DEBUG** (`f8ae62ca` + `81c09b8a`, `API_BASE_URL=http://127.0.0.1:3000/api`; cài 20:47:54,
SHA-1 `237e0d13…`). Người dùng cầm máy (vân tay, Cài đặt máy, đăng nhập); Claude chạm PIN / điều hướng bằng adb, chụp màn, đọc logcat. Sao lưu trước buổi
(force-stop rồi chép, cỡ khớp): `D:\FlowMoney-saoluu\realme-tk10-truoc-phien8-2026-10-25-2046\` (3 tệp CSDL + 11 tệp `shared_prefs/`). *Tự khoá sau*
tạm đặt **Ngay** cho bước 21 / 6.

| Bước | Kết quả |
|---|---|
| Thanh trạng thái (`81c09b8a`) | ✅ màn khoá, Trang chủ **lúc mở lạnh**, Cá nhân, Phân tích, rồi Trang chủ lại: điểm ảnh thanh trạng thái = nền kem (237, 237, 233) cả năm ảnh — dải xám cũ (~178) đã hết; màn Quét nền đen: biểu tượng **trắng** (người dùng nhìn). |
| 17 — 320 dp | ✅ ColorOS chặn `wm density` và `settings put system font_scale` (`WRITE_SETTINGS`) → người dùng đổi **cỡ hiển thị** trong Cài đặt máy = density 540 = **320 dp**. Màn khoá, Cá nhân, trang Khoá ứng dụng, bảng chọn *Tự khoá sau*: **0 điểm vàng thuần**, không cụt chữ; lộ **M15** (hàng *Tự khoá sau* gãy dòng khi chọn *Ngay khi rời app*). Cỡ **chữ** (font scale) chưa đo. |
| 21 — Quét ảnh khi khoá (Ngay) | ✅ Quét → Chọn ảnh (DocumentsUI 21:11:14) → quay về: **màn khoá trước** (người dùng xác nhận) → vân tay → lượt quét chạy tiếp: OCR (STARBUCKS, 262.000) 21:11:33, Gemma đọc ảnh 39 s, danh mục *Ăn uống* 21:12:21 → **form tự điền**; cùng tiến trình suốt lượt (không bị ColorOS giết — lúc mở trình chọn chưa giữ Gemma). Không Lưu. Đường **máy ảnh khi đang giữ Gemma** (ColorOS giết app) chưa đo. PayOS: người dùng chọn bỏ. |
| 6a — chạm thông báo, app sống + khoá | ✅ *Tổng kết tuần* đặt Chủ nhật, giờ hiện tại + 3 phút → Home → chạm thông báo: **màn khoá trước, không lộ khung nào** (người dùng nhìn) → vân tay → *Xuất Báo cáo* kỳ **12/10 – 18/10** (= `tuanTruoc(now)`, `notification_rules.dart:338` — đúng thiết kế). |
| 6b — chạm thông báo, app đã chết | ✅ đặt lại giờ → `am crash` (không force-stop — force-stop xoá lịch) → pid 27013 chết, hệ điều hành dựng 5055 cho dịch vụ D1 (không giao diện), lịch còn 3 → chạm thông báo 21:30:15: engine mới, màn khoá → vân tay → đúng *Xuất Báo cáo 12/10 – 18/10*. |
| `WebSocketConnectionClosed` (`f8ae62ca`) | ✅ backend nền trỏ `PersonFinance` (kiểm danh tính trước: script chỉ đọc), app nối socket → `PATCH /api/admin/updatestatus/10` `Inactive` 21:33:30, mở lại `Active` 21:33:36 (đọc CSDL: `Active`). Logcat: `Bị buộc đăng xuất: biKhoa` → `Đứt kết nối: io server disconnect` (đúng đường gói `41` + đóng) — **0** dòng `WebSocketConnectionClosed` / `Unhandled Exception` cả buổi; hộp thoại *"Tài khoản đã bị vô hiệu hoá"* đúng lý do. |
| 11 — vuốt app giữa vòng đồng bộ đầu sau đăng nhập lại | ✅ proxy `D:\FlowMoney-saoluu\cong-cu-do\proxy_giu_pull.js` (cổng 3002 → backend 3000, `adb reverse tcp:3000 tcp:3002`; giữ mọi `/sync/pull` khi có tệp `giu.flag`, mọi yêu cầu khác + socket.io đi thẳng). Đăng nhập mật khẩu (sau lần bị buộc đăng xuất — cùng đường với *Quên PIN → Đăng xuất*: cấu hình PIN còn) → `/sync/pull` bị giữ 21:36:12 → **hết giờ 30 s, không bao giờ xong** → người dùng vuốt app khỏi Đa nhiệm → mở lại: **không hỏi PIN / vân tay**, vào Trang chủ, hàng *Khoá ứng dụng* không còn viên *Đang bật*. ⚠️ Trên Realme vuốt **không giết tiến trình** (pid 5055 suốt — dịch vụ D1 giữ), chỉ dựng lại engine (21:36:46); kết luận đứng được vì lượt đồng bộ đầu chưa từng xong mà PIN cũ đã mất — đúng I4 (xoá ở `sauXacThucMatKhau`, không đợi `sauDangNhap`). |

Người dùng hỏi giữa buổi vì sao chọn ảnh để quét cũng bị hỏi PIN → giải thích (trình chọn ảnh là app khác, app xuống nền; mức *Ngay* do buổi đo đặt tạm;
mặc định 30 giây thì chọn nhanh không bị hỏi) → người dùng chốt **giữ như spec** (không miễn khoá cho lối app tự mở máy ảnh / chọn ảnh / PayOS — spec mục 8).
Cuối buổi: người dùng bật lại khoá app (PIN 135790, vân tay, *Tự khoá sau* 30 giây), trả *Tổng kết tuần* và cỡ hiển thị (density về 480); backend + proxy +
logcat của buổi đã dừng, `adb reverse` trả về `tcp:3000 tcp:3000`, token admin tạm đã xoá. Lượt đồng bộ sau khi thả cờ chưa tự chạy lại trước khi tắt
backend (đang giãn sau lần hỏng) — lần mở kế tự kéo. Dấu vết trong CSDL dev `PersonFinance` (cố ý): `auditlog` một cặp khoá / mở tài khoản 10 (admin, lý do
*"Kiem thu phien 8 - kenh socket, tam thoi"*, 21:33), `refreshtoken` mới của tài khoản 10 và admin. Một `adb logcat` của phiên trước (pid 11868, chạy từ
17:55) còn sống — không do buổi này mở, để nguyên.

**Buổi 4 — 2026-10-26 sáng (09:27–09:53, phiên 9), Realme, bản RELEASE** (`d7af5559` = M15 + nút Google + M13, `--dart-define=API_BASE_URL=http://127.0.0.1:3000/api`,
ký khoá debug vì không có `android/key.properties`; 227,0 MB, SHA-1 `a62c0da7…`, cài đè bản debug bằng `adb install -r` — dữ liệu giữ nguyên, cờ gói hết
`DEBUGGABLE`). Sao lưu trước khi cài (bản release không `run-as` được): `D:\FlowMoney-saoluu\realme-tk10-truoc-phien9-2026-10-26-0927\` (`flowmoney.db` — WAL
đã gộp — + 11 tệp `shared_prefs/`, cỡ khớp từng tệp). Backend **tắt** cả buổi (khoá app không cần mạng). Người dùng chọn đo bước 1–4; TalkBack và máy ảnh khi
đang giữ Gemma **chưa đo**; nút Google đo trên máy ảo (Realme phải đăng xuất mới thấy màn Đăng nhập).

| Bước | Kết quả |
|---|---|
| 1 — R8 + vân tay (`SinhTrac.kt` đổi ở phiên 8) | ✅ mở lạnh → màn khoá → hộp `OplusBiometricPrompt` tự hiện → người dùng chạm: logcat hệ thống `Authenticated! … IsCrypto: true` (lần đầu sai ngón, lần hai đúng) → Trang chủ. Bản release qua R8 chạy đường Keystore đúng. |
| 2 — M13 bàn phím vật lý | ✅ xuống nền 33 s (tự khoá 30 giây) → mở lại → Back đóng hộp vân tay (`HUY`, không câu lỗi) → `adb shell input keyevent` 8 · 10 · 12 (*1 3 5*) → **3 chấm** → 16 (*9*) → 4 chấm → 67 (Backspace) → 3 chấm → 151 (**bàn số** *7*) · 16 · 7 → mở khoá. Lặp lại sau khi mở rồi Huỷ tấm *Quên mã PIN?*: gõ phím vẫn mở được. ⚠️ Lộ **M16**: có phím là Android vẽ **khung tiêu điểm mặc định** (xanh-vàng (167, 209, 39), dày vài px) quanh cả `FlutterView` — chạm màn là mất; có cả trước M13 (Tab). |
| 3 — M15 ở 320 dp | ✅ người dùng đổi cỡ hiển thị (density 540). *30 giây*: giá trị bên phải, tiêu đề một dòng. *Ngay khi rời app*: tiêu đề + dòng phụ mỗi thứ một dòng, giá trị + mũi tên xuống dưới (ảnh). Trả mức về *30 giây*. |
| 4 — cỡ chữ lớn (1,6) + 320 dp | ✅ khoá app: màn khoá, tấm Quên PIN (nút Huỷ trọn trên màn), trang Khoá ứng dụng (*30 giây* cũng tự xuống dưới — đúng phép đo có `textScaler`; hàng công tắc xuống 2 dòng nhưng đọc được). ❌ ngoài mảng: **Trang chủ** (số tổng gãy giữa chữ số, chip *Số dư thực tế* tràn, chuông bị đẩy ra mép, nhãn nút nhanh dính nhau — có cả ở cỡ 1), **Sổ giao dịch** (thẻ tổng tràn), **Thêm giao dịch** (chip *Giọng nói & Gõ* tràn), **Phân tích** (nhãn *SỐ DƯ ĐẦ…* cắt), **Ngân sách** (hai tab lệch cỡ) — người dùng chọn sửa cả, phiên 9. |

**Đo lại sau sửa (10:41–10:51, bản release `626c6060`, SHA-1 `d62ae17e…`, cài đè — vẫn cỡ chữ 1,6 + 320 dp):** ✅ Trang chủ (chuông trọn trong lề, chip
xuống dưới tiêu đề, số tổng một dòng, năm nhãn nút nhanh cùng cỡ + có khe) · Sổ giao dịch (ba cột vừa thẻ) · Thêm giao dịch (chip dưới *NHẬP NHANH*) · Phân
tích (nhãn số dư xuống dòng đủ chữ) · Ngân sách (hai tab cùng cỡ) · **M16** (Tab + gõ PIN bằng `keyevent`: mép màn vẫn nền (237, 237, 233), không khung) ·
máy ảo bản debug 320 dp × 1,0 và × 1,6: nút *Google* / *Apple* một dòng. Lộ thêm (người dùng chọn sửa, phiên 9 lượt 2): *Xem tất cả* ở Trang chủ bị cắt; số
*"Còn 490.000 đ"* ở thẻ ngân sách gãy giữa chữ số; màn Đăng nhập tràn ở *MẬT KHẨU · Quên mật khẩu?* (19 px) và *Chưa có tài khoản? Đăng ký ngay* (87 px);
lệch cỡ ở thẻ tổng Sổ giao dịch và hai nút Google / Apple.

**Lượt sửa 2 (phiên 10, 2026-10-26 trưa — `b7d30bd6`, `0251284e`, `711c3cf0`; ngoài mảng khoá app trừ hàng *Tự khoá sau*):** thẻ từng ngân sách đo
bằng `doRongChu` (khuôn thẻ hoá đơn G74) — không vừa một hàng thì hai số tiền xuống dưới căn phải, dòng phụ `formatLienKhoi`; tiêu đề *Giao dịch gần đây*
(`TieuDeGiaoDichGanDay`, tách từ `home_page.dart`) `Flexible`; màn Đăng nhập: *Quên mật khẩu?* `Flexible` căn phải, chân trang `Wrap` căn giữa; thẻ tổng Sổ
giao dịch và hai nút Google / Apple dùng `NhanCoDeu` (ô biểu tượng Apple 24 dp như Google). **Đo Realme bản release `b7d30bd6`** (SHA-1 `9ca6af32…`, cài
11:34, vẫn cỡ chữ 1,6 + 320 dp, mở khoá bằng `keyevent` PIN): ✅ *Xem tất cả* trọn trong lề (tiêu đề 2 dòng) · thẻ *Giáo dục* / *Ăn uống* / *Di chuyển*:
*"Còn 490.000 đ"* một dòng, *"10.000 đ / 500.000 đ"* dưới căn phải · thẻ tổng Sổ: *"0 đ"* · *"-310.000 đ"* · *"-310.000 đ"* cùng cỡ. **Máy ảo bản debug
320 dp × 1,6** (màn Đăng nhập — Realme không đăng xuất): ✅ hai hàng hết tràn, 0 điểm sọc dải (250, 250, 58); ❌ lộ lỗi mới — nút **"Googl"** cụt chữ
khi mở lạnh: `NhanCoDeu` đo trong `builder` của `LayoutBuilder` lúc font Inter (`google_fonts`, không đóng gói) **chưa nạp**, `Text` tự đo lại còn
`builder` thì không (ràng buộc không đổi). Ép dựng lại (đổi cỡ chữ 1,55 → 1,6) thì trọn chữ — xác nhận gốc. Sửa: `BoCucTheoFont` (`core/ui/do_chu.dart`,
`LayoutBuilder` dựng lại khi `PaintingBinding.systemFonts` báo đổi) cho `NhanCoDeu`, thẻ ngân sách và — người dùng chọn sửa luôn — chín chỗ đo chữ khác
(câu hỏi ghi nhầm *"4 chỗ"*, quét đủ `lib/` ra 9; có hai chỗ ở Trang chủ); test quét 39. Mở lạnh máy ảo sau sửa: *"Google"* trọn chữ, cùng cỡ *"Apple"*;
cỡ thường (420 dpi × 1,0) nhìn như cũ. Thấy thêm, **không** sửa (chưa ai chọn): thẻ *Chưa đặt ngân sách* ở 1,6 cắt dòng phụ *"khoảng 2.010.000 đ …"*
(trần hai dòng của G78); thẻ D1 *"Tin ngân hàng, biên lai và lần …"* cắt. ⚠️ Máy ảo **mất token** sau lượt đo — mẹo đăng xuất bằng xoá
`FlutterSecureStorage.xml` rồi chép bản sao về **không còn dùng được** với kho 10.3.4 (`resetOnError` xoá token, *Chạy máy ảo* ở `CLAUDE.md`); SQLite
còn nguyên, và phiên của máy ảo vốn đã bị backend từ chối từ 2026-10-17 (401, 29 thao tác chờ đẩy).

**Lượt sửa 3 (phiên 10, 2026-10-26 chiều — `544d29bb` + sửa tiêu đề thẻ; người dùng chọn *"dọn nốt cỡ chữ 1,6"*):** thanh điều hướng dưới
bốn nhãn `NhanCoDeu` — tham số mới `kieuDo` để mọi ô đo theo chữ đậm của nhãn đang chọn (test 320 dp × 1,76 từng lệch 17,0 / 17,9 /
17,9 / 20,6 dp); thẻ *Chưa đặt ngân sách* bỏ trần dòng của dòng phụ *"khoảng … mỗi tháng"* (G78 chỉ cho hai dòng) và của tiêu đề
*"CHƯA ĐẶT NGÂN SÁCH"* (lượt đo lộ thêm: cụt *"CHƯA ĐẶT N…"* cạnh chip *"2 nhóm"*); khung `TheViecChoDuyet` (thẻ D1 *"Có N mục
chờ ghi"*, C1 *"Có N giao dịch chưa có danh mục"*) đo bằng `vuaSoDong` (helper mới ở `core/ui/do_chu.dart`) — tiêu đề và dòng phụ
không vừa hai dòng cạnh nút thì nút xuống dưới căn phải. ⚠️ Đo font thật: cột chữ của hai thẻ này cụt **ngay ở cỡ chữ thường** trên
320 / 360 dp (cột 63 / 103 dp; tiêu đề C1, dòng phụ D1 *"…"*), nên ở 360 dp cỡ thường nút *Xem* / *Gắn nhanh* nay cũng xuống dưới;
411 dp giữ bố cục Stitch. **Đo Realme bản release** (`c61ac418…` 13:55, rồi `2e63c2d6…` 14:01 có bản sửa tiêu đề; người dùng đặt lại
cỡ chữ 1,6 + 320 dp): ✅ bốn nhãn thanh dưới cùng cỡ (*Trang chủ* đậm cũng vậy) · *"khoảng 2.010.000 đ mỗi tháng"* trọn ba dòng ·
*"CHƯA ĐẶT / NGÂN SÁCH"* hai dòng · thẻ D1 tiêu đề một dòng, dòng phụ trọn bốn dòng, nút *Xem* dưới căn phải.

⚠️ Bẫy đo: (1) **bản release không vẽ sọc vàng** báo tràn (chỉ debug) — đếm điểm vàng trên ảnh release luôn ra 0, phải chấm bằng mắt; (2) ColorOS lưu cỡ chữ
ở `settings system font_scale` nhưng chỉ khi kéo **thanh "Cỡ phông chữ"** (lần đầu người dùng đổi chỗ khác, `mGlobalConfiguration` vẫn `{1.0 …}`) — đọc
`dumpsys activity | grep mGlobalConfiguration` để chắc; (3) `screencap` lúc hộp vân tay hệ thống đang mở ra tệp **0 byte** (cửa sổ bảo mật).
