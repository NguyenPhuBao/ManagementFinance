# Danh sách việc UX/UI — lượt đánh giá 2026-09-19

Nguồn: soát mã `src/Client-app/lib`, đối chiếu design system Stitch "Kinetic Finance",
và chạy app thật trên máy ảo 411dp với dữ liệu thật (khoảng 30 ảnh chụp). Mọi con số
đếm bằng máy ngày 2026-09-19. Thứ tự các nhóm theo nếp của dự án: **lỗi trước, tính
năng sau**. Cỡ việc: S ≈ dưới 1 giờ, M ≈ nửa ngày, L ≈ từ 1 ngày. ⚑ = đổi bố cục màn,
phải đưa lên Stitch trước rồi mới sửa Flutter. ❓ = cần người dùng chốt.

## A. Nút chết, stub, chữ sai (lỗi đang chạy)

> **Tiến độ:** A1, A2, A3, A7, A12 ✅ xong 2026-09-19 (cùng lượt gỡ nút "hỗ trợ" rỗng ở
> Cài đặt và nối nút "Gửi lại mã OTP" — A10, không có trong danh sách gốc, do
> test quét lộ ra). Test quét `lib/` thứ mười `khong_co_nut_chet_test.dart`
> canh; các handler rỗng còn lại nằm trong danh sách chờ chốt của chính test ấy.

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| A1 ✅ | Hamburger ở tab Cá nhân không làm gì — đã gỡ | `profile_page.dart:28` `onPressed: () {}` | S |
| A2 ✅ | Hamburger ở tab Phân tích là `Icon` trần, không bấm được — đã gỡ | `analytics_page.dart:271` | S |
| A10 ✅ | "Gửi lại mã OTP" (màn OTP quên mật khẩu) là handler rỗng — nay gọi lại `forgotPassword`, xoá sáu ô, báo đã gửi | `otp_page.dart:234`; 3 ca `otp_gui_lai_ma_test.dart` | S |
| A11 ❓ (½) | Còn handler rỗng chờ chốt: `ai_chat_page` 5, `login_page` Google/Apple 2, `forgot_password_page` "Liên hệ hỗ trợ" 1, `add_transaction_page` menu ⋮ 1. ✅ Phím `+` `−` của bàn phím — **nút chết mà test quét không thấy** — đã làm phép tính thật 2026-09-19 | danh sách trong `khong_co_nut_chet_test.dart`; 26 ca ở `bieu_thuc_so_tien_test.dart` + `phep_tinh_ban_phim_test.dart` | S mỗi cái |
| A12 ✅ | Phím `.` sinh thập phân mà `_saveTransaction` strip dấu chấm → **12.5 thành 125**, im lặng. Người dùng chốt **bỏ phím** (2026-09-19); ô ấy nay là `00`. ⚠️ Lỗi có **hai cửa** — chế độ sửa nạp chuỗi có dấu chấm từ `editing.amount.toString()`, nên chốt thật ở `_saveTransaction`; số lẻ cũng thôi in chuỗi thô, đi qua `formatCoLe` | 4 ca `so_tien_thap_phan_test.dart` (tệp mới) + 4 ca `ban_phim_so_tien_test.dart` | S |
| A3 ✅ | Công tắc "Giao diện" sáng/tối chỉ là hình vẽ, app không có `darkTheme` — người dùng chốt **gỡ** (2026-09-19). Rút khỏi danh sách chờ chốt của `khong_co_nut_chet_test.dart`; `_ProfileItem.trailing` gỡ theo vì hết chỗ gọi (analyze lên 26, mức nền 25) | 2 ca `profile_page_menu_test.dart` | S |
| A4 ✅ | Drawer "Xuất báo cáo" báo "đang phát triển" dù trang đã có từ 2026-09-09 — nay trỏ `/export-report`; drawer tách thành `DrawerTrangChu`, test đối chiếu mọi đường với router thật | `home_page.dart:344` | S |
| A5 | Nút "Quét" ở Trang chủ là stub SnackBar | `home_page.dart:471-475` | ❓ giữ (làm OCR/QR) hoặc gỡ |
| A6 | Thẻ "Insight AI · Mới" là chữ tĩnh, lỗi chính tả "Thêm thêm" | `home_page.dart:750-791` | ❓ gỡ hoặc nối vào Trợ lý AI |
| A7 ✅ | Hai mục "Bảo mật 2 yếu tố (MFA)" và "Đồng bộ dữ liệu Cloud" `onTap` rỗng — đã gỡ, cùng nút "hỗ trợ" rỗng trên cùng trang | `settings_page.dart:210`, `:217` | S (gỡ) |
| A8 ✅ | Widget `AppBottomNavBar` chết — đã xoá (0 chỗ gọi), mang nhãn khác bản chạy | `shared/widgets/bottom_nav_bar.dart` | S (xoá) |
| A9 ✅ | Drawer thiếu "Đăng xuất" ở đáy và avatar là vòng đen trống (chữ `primary` trên nền `primaryContainer`, hai màu là một) — đã sửa, hộp thoại xác nhận dùng chung `xacNhanDangXuat` | ảnh Stitch `6c692ef1…` vs `home_page.dart:246-334` | S |

## B. Bản địa hoá và định dạng số

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| B1 ✅ | Thêm `flutter_localizations`, `localizationsDelegates`, `supportedLocales: [vi]`, `locale: vi` — ba hằng ở `core/constants/app_localization.dart`, `intl` lên `^0.20.2` | date picker hiện "Select date · Sat, Sep 19 · Cancel/OK", tuần bắt đầu Chủ nhật; `pubspec.yaml` không có gói | S |
| B2 ✅ | Ba thẻ Thu nhập / Chi tiêu / Thu net trên Trang chủ cắt "14.635.0…" — tách `TheSoLieuThang`, `FittedBox` co chữ, số đi qua `CurrencyFormatter`; test đo `didExceedMaxLines` | `home_page.dart:569-570` `TextOverflow.ellipsis` | S (FittedBox hoặc `formatCompact`) |
| B3 ✅ | Thống nhất một dạng "13.590.000 đ": đếm lại bằng test quét là **20 chỗ / 7 tệp** (không phải 18 — `grep` bỏ sót `'$moneyđ'`), tất cả về `CurrencyFormatter`; 25 khẳng định test đổi theo | `grep "}đ'"` = 18, ví dụ `analytics_page.dart:241` `_dong` | M |
| B4 ✅ | Thêm test quét `lib/` cấm nối `đ` bằng tay — `core/utils/ky_hieu_tien_mot_noi_test.dart`, test quét thứ mười một; hai chuỗi mockup (`ai_chat_page`, `bill_delete_page`) ở danh sách chờ chốt | `currency_formatter_test.dart` | S |

## C. Luồng Thêm giao dịch (luồng quan trọng nhất)

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| C1 ✅ | Bàn phím số phải vừa màn 411dp — nay neo đáy (`mainAxisExtent: 50`), theo màn Stitch mới `acf6f17e…`; ✓ là nút lưu, bỏ nút "Lưu giao dịch" | ảnh `11_add.png` vs `19_add_scrolled.png` | ⚑ M |
| C2 ✅ | Ô số tiền luôn thấy — khối số tiền cố định, chỉ thẻ form cuộn | cùng ảnh | ⚑ M (chung với C1) |
| C3 ✅ | Chọn Thu / Chi ngay đầu màn — Stitch gốc đã vẽ "Chi tiêu · Thu nhập · Chuyển khoản", bản Flutter đi lệch từ 2026-09-05; `_huong` là lối vào, `type` vẫn suy từ danh mục | Money Lover, MISA đều có tab Chi/Thu/Vay ngay đầu | ⚑ M |
| C4 ✅ | Ba nút nhanh đặt sẵn loại — `push('/add', extra: 'thu')`… → `huongBanDau` | `home_page.dart:450-466` cả ba đều `push('/add')` trần | S (sau C3) |
| C5 ✅ | Màn Chọn danh mục: hàng lá trần theo Stitch `acab2a45…` — bỏ chevron và icon tag | ảnh `53_category_picker.png` vs `16_categories.png` | S |

## D. Cấu trúc menu và điều hướng

✅ **Chốt lối B** (giữ drawer làm menu đầy đủ) — 2026-09-19, và **đã thi công xong
cùng ngày**. Spec: `2026-09-19-nhom-d-cau-truc-menu-design.md`; kế hoạch:
`2026-09-19-nhom-d-cau-truc-menu.md`. Nguyên tắc: **thanh dưới = việc hằng ngày,
drawer = mọi thứ còn lại, không đích nào ở cả hai chỗ.**

⚠️ Ba lỗi hồi quy do chính lượt này sinh ra, **cả ba chỉ máy ảo thấy**: hai nút `+`
chồng nhau ở trang Sổ giao dịch, trang Ngân sách thành ngõ cụt (`automaticallyImplyLeading:
false` đúng hồi nó là tab), và "Vùng nguy hiểm" rơi vào giữa trang Cá nhân. Chi tiết ở
mục 14 `PROJECT_CONTEXT.md`.

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| D1 ✅ | Tab **Giao dịch** ở thanh dưới; `/transactions` thành nhánh shell, `/budget` rời shell về drawer. ⚠️ Nhãn 9 ký tự vì ô rộng **cố định 72dp** | tệp mới `main_shell_tab_so_giao_dich_test.dart`, 8 ca ba lớp | ⚑ M |
| D2 ✅ | Thanh dưới: Trang chủ · Phân tích · [+] · Giao dịch · Cá nhân | `main_shell.dart` | ⚑ M |
| D3 ✅ | Drawer còn **sáu** mục — rút Thống kê, Cá nhân, Cài đặt; Ngân sách đi ngược chiều về đây | `drawer_trang_chu_test.dart`, 4 ca mới | S–M |
| D4 ✅ | **Tự tan** khi drawer thôi có mục ấy; tiêu đề trang đổi thành "Phân tích" (`analytics_page.dart:282`) | 1 ca mới | S |
| D5 ✅ | Gộp: thân trang tách thành `NoiDungCaiDat` dùng chung (**chuyển**, không chép — bài học G41/G47). Route `/settings` giữ vì bốn route con khai bên trong nó | 3 ca mới | ⚑ M |
| D6 ✅ | Nhóm ấy **bỏ hẳn** khỏi tab Cá nhân — bốn mục sống ở drawer | 1 ca mới | S |
| D7 ✅ | "Thông báo" → **"Cài đặt thông báo"** | 1 ca mới | S |
| D8 ✅ | **Tự tan** cùng nhóm module: glyph heo đất thôi mang hai nghĩa | — | S |
| D9 ✅ | **Tự tan**: drawer *là* menu dưới lối B, nên "chỉ vào từ drawer" đúng là thiết kế mong muốn | — | — |
| D10 ✅ | Bỏ nút hero và "Xem báo cáo"; còn **bốn** lối vào (ba nút tròn đặt sẵn chiều + FAB). `HomeActionButtons` xoá hẳn | tệp mới `trang_chu_gon_test.dart`, 4 ca | ⚑ S |
| D11 ✅ | Bỏ slogan hai dòng (~120dp); số dư nay nằm ngay đầu màn | cùng tệp trên | ⚑ |

## E. Trạng thái tải, phản hồi, thoát app

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| E1 ⏸ | Skeleton cho tab Phân tích — **chưa làm**: trạng thái tải là một khối giao diện mới, theo nếp phải vẽ vào Stitch (màn `c8567243…`) trước | ảnh `05_analytics.png`; trang 3874 dòng, 7 nguồn stream | M |
| E2 | Mục lục / tab con hoặc thu gọn khối cho trang Phân tích (13 khối, cuộn rất dài) | `analytics_page.dart` | ⚑ ❓ L |
| E3 ✅ | Chặn Back ở Trang chủ thoát app ngay: "Nhấn lần nữa để thoát" — `ThoatHaiLan` bọc `MainShell`, tab khác về Trang chủ; toast qua kênh mới `ThongBaoNhanh` (nguồn thứ tư của `AppToast`, nền cho E4). ⚠️ Máy ảo lật thêm: predictive back (targetSdk 36) làm Back ở tab Phân tích đóng activity — tắt bằng `enableOnBackInvokedCallback="false"`, test GoRouter thật `main_shell_back_test.dart` | `grep PopScope` = 0 | S |
| E4 ⏸ | Thay 176 `SnackBar` bằng toast — **kênh đã có** (`ThongBaoNhanh` → `AppToast`, từ E3); phần thay dần chưa làm vì đụng hàng trăm khẳng định `find.byType(SnackBar)`/`find.text` trong test (goal 54, bill 36, transaction 22…) | `grep SnackBar` = 176 | M (một widget chung + thay dần) |
| E5 ✅ | Thẻ tổng tab Ngân sách tô thanh **xanh** ở 90% trong khi thẻ danh mục ngay dưới tô **đỏ** cùng con số — nay cùng thang qua `budgetHealthOfRatio` | ảnh `08_budget.png`; `budget_tabs_view.dart` | S |
| E6 ❓ | Trung tâm thông báo lặp "Số dư ví đang âm" cho cùng ví mỗi ngày (4 bản) — khoá `walletNeg:<ví>:<ngày>` là **quyết định có chủ ý** ("ví ở trạng thái âm cho tới khi nạp tiền"), và khoá chống trùng sống 90 ngày nên bỏ ngày là im 90 ngày kể cả khi ví âm lại. Cần chốt: giữ nhắc hằng ngày, đổi sang hằng tuần, hay chỉ báo khi *chuyển* sang âm | ảnh `17_notifications.png`; luật `walletNegative` | S (khoá theo ví, không theo ngày) |
| E7 ✅ (½) | Trang Danh mục: tiêu đề lặp đã bỏ theo Stitch `583f8232…`; FAB đè hàng cuối **để nguyên** (Stitch cũng FAB nổi; padding đáy chỉ có tác dụng khi cuộn tới cuối) | ảnh `16_categories.png` | S |
| E8 ✅ | Hoá đơn hiện "Danh mục đã xoá" cho 2/3 hoá đơn — **lỗi thật, G47** (mở và đóng cùng ngày): `categoryDao.getAll` thay vì `getBangTraTen` ở BillPage, BillDetailPage và bảng tra của ngân sách | ảnh `13_bills.png` | S (kiểm) |

## F. Nhận diện app và hoàn thiện

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| F1 ✅ | Icon app: đang là logo Flutter mặc định (`ic_launcher.png` 544 byte) — nay ô đen bo góc + glyph ví trắng, sinh bằng `flutter_launcher_icons` từ `assets/icon/` (ảnh do `test/tool/tao_icon_app_test.dart` vẽ) | `android/app/src/main/res/mipmap-*/` | S (`flutter_launcher_icons`) |
| F2 ✅ | Splash: nền trắng + logo Flutter — nay nền #EDEDE9 + ô icon, `flutter_native_splash` | `launch_background.xml` mặc định | S (`flutter_native_splash`) |
| F3 ✅ | Nhãn app "flowmoney" chữ thường → "FlowMoney" (Android + iOS) | `AndroidManifest.xml:19` | S |
| F4 | Avatar: drawer vòng đen trống, Cá nhân chữ "Đ" nền xanh — một kiểu | `home_page.dart`, `profile_page.dart` | S |

## G. Khả năng tiếp cận

| # | Việc | Bằng chứng | Cỡ |
|---|---|---|---|
| G1 ✅ (phần `IconButton`) | 45 `IconButton` thiếu `tooltip` — đã chèn theo icon, test quét `lib/` thứ mười hai canh; nút dựng qua `GestureDetector`/`NotificationBell` chưa có `Semantics` | `grep Semantics\|tooltip:` = 0 | M |
| G2 | Kiểm bố cục với cỡ chữ hệ thống lớn (`textScaler` 1.3): ba thẻ Trang chủ, header Phân tích, sheet chọn phạm vi | `grep textScaler` = 0 | M |

## Cần người dùng chốt trước khi làm

1. ~~A3 dark mode~~ — ✅ chốt **gỡ** 2026-09-19.
2. A5 Quét, A6 Insight AI, D9 Trợ lý AI: giữ (và làm thật) hay gỡ khỏi giao diện.
   (A11 Google/Apple ở màn Đăng nhập cũng còn chờ.)
3. ~~D: lối A hay lối B~~ — ✅ chốt **lối B**, và **D1–D11 đã thi công xong**
   2026-09-19. Ba màn Stitch: `250229e6…` (drawer), `580ee88c…` (Cá nhân),
   `93501c85…` (Trang chủ).
4. D11, E2: có đụng bố cục Trang chủ và Phân tích không.
5. ~~Phím `+` và `-` là nút chết~~ — ✅ chốt **làm phép cộng/trừ thật**, xong
   2026-09-19. ⚠️ Bài học giữ lại: **một nút có thể chết ở tầng dưới nút**;
   `khong_co_nut_chet_test.dart` không thấy chúng vì `onTap` trỏ tới một hàm
   thật, chỉ đọc hàm thuần mới lộ ra.

## Thứ tự đề nghị

1. Nhóm A (trừ A3) + B1 + B2 + E3 + F1–F3 — toàn việc S, gỡ hết thứ lộ ngay khi demo.
2. B3 + B4 — thống nhất số tiền.
3. Nhóm C — luồng nhập liệu, cần Stitch trước.
4. Nhóm D theo lối đã chốt — cần Stitch trước.
5. E1, E4, E5, E6, E7, E8.
6. Nhóm G, rồi A3/E2 nếu chốt làm.
