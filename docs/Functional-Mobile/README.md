# 📱 TỔNG QUAN HỆ THỐNG CHỨC NĂNG CLIENT-APP (FLOWMONEY MOBILE)

> **Dự án:** Personal Finance Management — FlowMoney Client Mobile App  
> **Nền tảng công nghệ:** Flutter 3.47.6 • Dart 3.13.5 • SQLite (Offline-First) • BLoC/Cubit • GoRouter • Clean Architecture  
> **Thư mục nguồn:** [`src/Client-app`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app)  
> **Mục tiêu tài liệu:** Ghi nhận khảo sát toàn diện 100% tất cả các chức năng, màn hình, luồng nghiệp vụ và quy tắc kỹ thuật hiện có tại ứng dụng Mobile, tuyệt đối không bỏ sót bất kỳ chi tiết nào.

---

## 🧭 1. BẢN ĐỒ MA TRẬN PHÂN HỆ CHỨC NĂNG (FUNCTIONAL MATRIX)

Ứng dụng Client-app được cấu trúc thành **13 Phân hệ Chức năng Cốt lõi** với tổng cộng **48 Màn hình & Luồng nghiệp vụ chuyên sâu**:

| STT | Mã phân hệ | Tên phân hệ chức năng | Quy mô màn hình / View | Trạng thái | Tài liệu đặc tả chuyên sâu |
|:---:|:---|:---|:---:|:---:|:---|
| 01 | **AUTH** | Xác thực & Bảo mật tài khoản | 7 màn hình | Hoàn chỉnh | [`01_XAC_THUC_VA_BAO_MAT.md`](./01_XAC_THUC_VA_BAO_MAT.md) |
| 02 | **HOME** | Trang chủ & Navigation Shell | 2 view chính + 6 widgets | Hoàn chỉnh | [`02_TRANG_CHU_VA_DIEU_HUONG.md`](./02_TRANG_CHU_VA_DIEU_HUONG.md) |
| 03 | **WALLET** | Quản lý Ví tiền & Tài sản ròng | 3 màn hình | Hoàn chỉnh | [`03_QUAN_LY_VI_TIEN_TE.md`](./03_QUAN_LY_VI_TIEN_TE.md) |
| 04 | **TX** | Sổ giao dịch Thu / Chi / Vay nợ | 5 phương thức & màn hình | Hoàn chỉnh | [`04_SO_GIAO_DICH_THU_CHI.md`](./04_SO_GIAO_DICH_THU_CHI.md) |
| 05 | **CAT** | Hệ thống Danh mục Thu Chi Đa cấp | 4 màn hình | Hoàn chỉnh | [`05_HE_THONG_DANH_MUC.md`](./05_HE_THONG_DANH_MUC.md) |
| 06 | **BUDGET** | Ngân sách Chi tiêu & Cảnh báo hạn mức | 3 màn hình | Hoàn chỉnh | [`06_NGAN_SACH_CHI_TIEU.md`](./06_NGAN_SACH_CHI_TIEU.md) |
| 07 | **BILL** | Quản lý Hóa đơn định kỳ & Nhắc hạn | 5 màn hình | Hoàn chỉnh | [`07_HOA_DON_DINH_KY.md`](./07_HOA_DON_DINH_KY.md) |
| 08 | **GOAL** | Mục tiêu Tiết kiệm & Tích lũy tài chính | 4 màn hình | Hoàn chỉnh | [`08_MUC_TIEU_TIET_KIEM.md`](./08_MUC_TIEU_TIET_KIEM.md) |
| 09 | **ANALYTICS** | Báo cáo Phân tích & Xuất dữ liệu | 2 màn hình + Biểu đồ | Hoàn chỉnh | [`09_BAO_CAO_PHAN_TICH.md`](./09_BAO_CAO_PHAN_TICH.md) |
| 10 | **AI** | Trợ lý Chatbot AI Gemini & Edge AI On-Device | 3 màn hình + Edge AI | Hoàn chỉnh | [`10_TRO_LY_AI_VA_AI_EDGE.md`](./10_TRO_LY_AI_VA_AI_EDGE.md) |
| 11 | **NOTIF** | Trung tâm Thông báo & Giám sát Ngân hàng | 3 màn hình + Listener | Hoàn chỉnh | [`11_TRUNG_TAM_THONG_BAO_VA_NHAC_NHO.md`](./11_TRUNG_TAM_THONG_BAO_VA_NHAC_NHO.md) |
| 12 | **PREMIUM** | Gói cước Tài khoản & Thanh toán PayOS VietQR | 3 màn hình | Hoàn chỉnh | [`12_GOI_CUOC_PREMIUM_VA_PAYOS.md`](./12_GOI_CUOC_PREMIUM_VA_PAYOS.md) |
| 13 | **SYNC** | Động cơ Đồng bộ Offline-First & CSDL SQLite | Core Engine (6 entities) | Hoàn chỉnh | [`13_KIEN_TRUC_DONG_BO_OFFLINE_FIRST.md`](./13_KIEN_TRUC_DONG_BO_OFFLINE_FIRST.md) |

---

## 📋 2. BẢNG TỔNG KẾT TOÀN DIỆN 48 MÀN HÌNH & CHỨC NĂNG NGHIỆP VỤ

| Phân hệ | Tuyến Route | Tên file Dart / Giao diện | Tóm tắt Chức năng & Hành vi Nghiệp vụ |
|:---:|:---|:---|:---|
| **AUTH** | `/login` | `login_page.dart` | Đăng nhập tài khoản; Hỗ trợ Đăng nhập Offline qua cache hash; Đăng nhập sinh trắc học vân tay / Face ID. |
| **AUTH** | `/register` | `register_page.dart` | Đăng ký tài khoản người dùng mới, kiểm tra độ mạnh mật khẩu và gửi mã OTP qua email. |
| **AUTH** | `/register/verify-otp` | `register_otp_page.dart` | Xác thực 6 số OTP đăng ký qua cổng Brevo HTTPS REST API siêu tốc (2.5s), đếm ngược 60 giây gửi lại mã. |
| **AUTH** | `/forgot-password` | `forgot_password_page.dart` | Yêu cầu gửi OTP khôi phục mật khẩu qua địa chỉ email đã đăng ký. |
| **AUTH** | `/otp` | `otp_page.dart` | Xác thực OTP quên mật khẩu, nhận Reset Token bảo mật. |
| **AUTH** | `/reset-password` | `reset_password_page.dart` | Thiết lập mật khẩu mới kèm mã Token xác thực gửi từ server. |
| **AUTH** | `/settings/change-password` | `change_password_page.dart` | Đổi mật khẩu tài khoản trực tiếp trong ứng dụng. |
| **AUTH** | `/settings/delete-account` | `delete_account_page.dart` | Vòng đời xóa tài khoản ân hạn 30 ngày (PendingDelete); Cho phép hủy xóa phục hồi tài khoản bất kỳ lúc nào. |
| **HOME** | `/` (Shell) | `main_shell.dart` | Thanh điều hướng đáy 4 Tabs (Trang chủ, Phân tích, Sổ giao dịch, Cá nhân); Giữ trạng thái qua IndexedStack. |
| **HOME** | `/home` | `home_page.dart` | Dashboard trung tâm: Thẻ tổng số dư tài sản ròng, 5 phím tác vụ nhanh, Thẻ cảnh báo xóa 30 ngày, Widget ngân sách & hóa đơn, Lịch sử gần đây. |
| **HOME** | Drawer | `app_drawer.dart` | Menu bên hông: Thông tin người dùng, trạng thái gói cước, phím tắt nhanh và phiên bản ứng dụng. |
| **WALLET** | `/wallets` | `wallets_page.dart` | Danh sách 5 loại ví (Tiền mặt, Ngân hàng, Ví điện tử, Tiết kiệm, Đầu tư); Công tắc tính/loại trừ ví khỏi tổng tài sản. |
| **WALLET** | `/wallets/add` | `add_wallet_page.dart` | Tạo ví mới (Tên ví, loại ví, số dư ban đầu, icon, màu sắc); Kiểm soát trần gói Basic tối đa 3 ví (`LoaiTran.vi`). |
| **WALLET** | `/wallets/:id/edit` | `edit_wallet_page.dart` | Chỉnh sửa ví, điều chỉnh số dư ví (tự động sinh giao dịch bù trừ số dư), xóa mềm ví (soft-delete). |
| **TX** | `/transactions` | `transactions_page.dart` | Sổ giao dịch thu chi đa chiều: Lọc theo ví, theo khoảng thời gian (ngày/tuần/tháng/năm), tìm kiếm theo từ khóa. |
| **TX** | `/add` | `add_transaction_page.dart` | Thêm giao dịch thủ công: Thu, Chi, Chuyển tiền giữa 2 ví, máy tính bỏ túi mini tích hợp, đính kèm ảnh hóa đơn. |
| **TX** | `/add?noi=1` | Voice Input Whisper | Nhập giao dịch bằng giọng nói tiếng Việt tự nhiên On-Device (tự động bóc tách số tiền, danh mục, ví, ghi chú). |
| **TX** | `/quet` | `scan_receipt_page.dart` | Quét hóa đơn OCR bằng camera hoặc ảnh thư viện thông qua Google MLKit On-Device, tự động lọc tổng tiền và ngày in. |
| **TX** | `/transactions/gan-danh-muc` | `gan_danh_muc_page.dart` | Màn hình gán danh mục nhanh (C1) hàng loạt cho các giao dịch chưa phân loại hoặc biến động số dư. |
| **CAT** | `/categories` | `categories_page.dart` | Quản lý cây danh mục 2 cấp Thu và Chi (Nhóm cha - Danh mục con); Tùy biến icon và bảng màu. |
| **CAT** | `/categories/group/new` | `add_category_group_page.dart`| Tạo nhóm danh mục cha mới. |
| **CAT** | `/categories/child/new` | `add_category_child_page.dart`| Tạo danh mục con mới trực thuộc nhóm cha; Kiểm soát trần danh mục riêng Basic. |
| **CAT** | `/categories/:id/keywords` | `category_keywords_page.dart` | Thiết lập danh sách từ khóa tự động gán cho danh mục (dùng cho nhận diện giọng nói, OCR và biến động ngân hàng). |
| **BUDGET**| `/budget` | `budget_page.dart` | Danh sách ngân sách chi tiêu tháng, thanh tiến độ %, mã màu cảnh báo (Xanh <80%, Vàng 80-99%, Đỏ >=100% bội chi). |
| **BUDGET**| `/budget/rules` | `budget_rules_page.dart` | Thiết lập ngân sách mới (chọn danh mục, hạn mức chi, khoảng thời gian; kiểm tra trần Basic 3 ngân sách). |
| **BUDGET**| `/budget/detail/:id` | `budget_detail_page.dart` | Chi tiết ngân sách: Danh sách giao dịch phát sinh, định mức chi an toàn mỗi ngày còn lại, dự báo ngày vỡ hạn mức chi. |
| **BILL**  | `/bills` | `bills_page.dart` | Danh sách hóa đơn định kỳ phân loại (Chưa thanh toán, Đã thanh toán, Quá hạn); Nhắc hẹn đa tầng. |
| **BILL**  | `/bills/add` | `add_bill_page.dart` | Tạo hóa đơn định kỳ: Chọn 4 loại chu kỳ lặp lại (Tuần, Tháng, Quý, Năm), ngày đến hạn, nhắc trước N ngày; Trần Basic 5 hóa đơn. |
| **BILL**  | `/bills/:id` | `bill_detail_page.dart` | Chi tiết hóa đơn định kỳ, tiến độ chu kỳ và lịch sử thanh toán các kỳ trước. |
| **BILL**  | `/bills/:id/edit` | `edit_bill_page.dart` | Chỉnh sửa số tiền, chu kỳ, bật/tắt nhắc nhở hoặc tạm dừng theo dõi hóa đơn. |
| **BILL**  | Bill Pay Action | `bill_pay_action.dart` | Thao tác "Thanh toán ngay": Tự động sinh giao dịch trừ tiền ví và tịnh tiến chu kỳ sang kỳ tiếp theo. |
| **GOAL**  | `/goals` | `goals_page.dart` | Danh sách mục tiêu tiết kiệm, thanh tiến độ tích lũy %, số tiền còn thiếu, ngày kỳ vọng hoàn thành. |
| **GOAL**  | `/goals/add` | `add_goal_page.dart` | Tạo mục tiêu tích lũy mới (Tên mục tiêu, số tiền kỳ vọng, ngày hạn chót, icon, mức ưu tiên; Trần Basic 3 mục tiêu). |
| **GOAL**  | `/goals/:id` | `goal_detail_page.dart` | Chi tiết mục tiêu tài chính, biểu đồ tăng trưởng và lịch sử nạp/rút tiền. |
| **GOAL**  | `/goals/:id/edit` | `edit_goal_page.dart` | Chỉnh sửa mục tiêu hoặc gia hạn ngày hạn chót; Nạp thêm tiền từ ví hoặc rút tiền mục tiêu về lại ví. |
| **ANALYTICS**| `/analytics` | `analytics_page.dart` | Báo cáo tài chính trực quan: Biểu đồ cơ cấu chi tiêu hình tròn (Pie Chart), biểu đồ cột dòng tiền Thu vs Chi, tỷ lệ tiết kiệm ròng. |
| **ANALYTICS**| `/analytics/export` | `export_page.dart` | Xuất báo cáo tài chính ra file PDF in ấn chuẩn màu hoặc file Excel chi tiết từng giao dịch (Độc quyền Premium). |
| **AI**    | `/ai-chat` | `ai_chat_page.dart` | Trợ lý tài chính AI Gemini thông minh: Streaming phản hồi từng chữ, Financial Snapshot ngữ cảnh ví/ngân sách, Deep link C3 chuyển màn hình. |
| **AI**    | Voice Whisper | On-Device Inference | Mô hình nhận diện giọng nói tiếng Việt chạy trực tiếp trên chip điện thoại (~45MB), bảo mật tuyệt đối không gửi audio lên server. |
| **AI**    | OCR MLKit | On-Device Inference | Mô hình nhận diện ký tự quang học xử lý ảnh biên lai cục bộ trên điện thoại, trích xuất chính xác tổng tiền và thời gian. |
| **AI**    | `/ai-settings` | `ai_settings_page.dart` | Quản lý mô hình AI: Tải về, xóa giải phóng bộ nhớ máy, công tắc ưu tiên xử lý On-Device. |
| **NOTIF** | `/notifications` | `notifications_page.dart` | Trung tâm thông báo tập trung với 5 nhóm (Hóa đơn, Ngân sách, Nhắc ghi chép, AI Insights, Hệ thống). |
| **NOTIF** | `/settings/notifications`| `notification_settings_page.dart`| Cài đặt giờ nhắc nhở ghi chép hàng ngày, bật/tắt từng loại chuông cảnh báo, cấp quyền Android 13+. |
| **NOTIF** | Bank Scanner | `bank_notification_listener.dart`| Dịch vụ giám sát thông báo ngân hàng chạy ngầm (Vietcombank, MB, Techcombank...), phát thông báo nhắc ghi chép ngay (D1). |
| **PREMIUM**| `/premium` | `nang_cap_page.dart` | Màn hình giới thiệu gói Premium, bảng so sánh quyền lợi, thông điệp cá nhân hóa theo trần/quyền, nút "Nâng cấp ngay". |
| **PREMIUM**| `/premium/cho-thanh-toan` | `cho_thanh_toan_page.dart`| Màn hình thanh toán VietQR Napas 247 động, mã nhận diện 6 ký tự, đếm ngược 10-30 phút, JIT Sync, xử lý chuyển thừa/thiếu tiền. |
| **PREMIUM**| `/premium/lich-su` | `lich_su_mua_page.dart` | Xem lịch sử đơn mua gói Premium; Đã lọc sạch 100% các đơn mẫu (`is_template: false`). |
| **SYNC**   | Core Engine | `sync_engine.dart` | Động cơ đồng bộ 2 chiều Offline-First: Ghi cục bộ SQLite 0ms độ trễ, gom batch 2 giây, lùi số mũ backoff, Last-Write-Wins, chuẩn G67 mốc kéo server. |

---

## 💎 3. BẢNG PHÂN QUYỀN GÓI CƯỚC (BASIC VS PREMIUM FEATURE GATING)

Hệ thống Client-app áp dụng cơ chế khóa trần tự động (**Feature Gating & Limit Thresholds**) thông qua các guard route (`redirectTaoTheoGoi` và `redirectTheoQuyen` tại `app_router.dart`):

| Tính năng / Tài nguyên | Gói Basic (Mặc định Miễn phí) | Gói Premium (Nâng cao) | Cơ chế xử lý khi chạm trần |
|:---|:---:|:---:|:---|
| **Số lượng Ví hoạt động (`wallet`)** | Tối đa **3 ví** | **Không giới hạn** | Chuyển hướng sang `/premium?tran=vi` kèm thông báo |
| **Số lượng Ngân sách tháng (`budget`)** | Tối đa **3 ngân sách** | **Không giới hạn** | Chuyển hướng sang `/premium?tran=ngan_sach` |
| **Số lượng Mục tiêu tiết kiệm (`goal`)** | Tối đa **3 mục tiêu** | **Không giới hạn** | Chuyển hướng sang `/premium?tran=muc_tieu` |
| **Số lượng Hóa đơn định kỳ (`bill`)** | Tối đa **5 hóa đơn** | **Không giới hạn** | Chuyển hướng sang `/premium?tran=hoa_don` |
| **Tạo Danh mục riêng (`category`)** | Danh mục mặc định hệ thống | **Tự do tạo không giới hạn** | Chuyển hướng sang `/premium?tran=danh_muc_rieng` |
| **Xuất Báo cáo Chi tiêu (`export_reports`)** | Không khả dụng | **Xuất PDF & Excel chuyên sâu** | Chuyển hướng sang `/premium?quyen=export_reports` |
| **Trợ lý AI Gemini Chatbot** | Giới hạn câu hỏi cơ bản | **Không giới hạn, Snapshot tài chính sâu** | Hiển thị Banner nâng cấp trong màn Chatbot |
| **Mô hình AI On-Device (OCR & Voice)** | Khả dụng | **Khả dụng tốc độ cao** | Tùy chọn tải mô hình ngoại tuyến |
| **Đồng bộ 2 chiều Offline-First** | Có | Có | Tự động đồng bộ ngầm khi có mạng |

---

## 🏗️ 4. KIẾN TRÚC ĐIỀU HƯỚNG TỔNG THỂ (GO-ROUTER ARCHITECTURE)

Toàn bộ ứng dụng được định tuyến tập trung tại [`src/Client-app/lib/core/router/app_router.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/router/app_router.dart):
1. **Public Routes (Không yêu cầu đăng nhập):**
   - `/login`, `/register`, `/register/verify-otp`, `/forgot-password`, `/otp`, `/reset-password`.
2. **Main Navigation Shell (`StatefulShellRoute.indexedStack` - 4 Tabs Đáy):**
   - Nhánh 1: `/home` — Trang chủ Dashboard.
   - Nhánh 2: `/analytics` — Phân tích chi tiêu (sub-route: `export`).
   - Nhánh 3: `/transactions` — Sổ giao dịch (sub-route: `gan-danh-muc` C1).
   - Nhánh 4: `/profile` — Trang cá nhân và cài đặt.
3. **Stand-alone Fullscreen Routes (Màn hình chức năng ngoài Shell):**
   - Nghiệp vụ giao dịch: `/add`, `/add/category`, `/quet`.
   - Nghiệp vụ tài chính: `/wallets`, `/wallets/add`, `/wallets/:id/edit`, `/budget`, `/budget/rules`, `/budget/detail/:id`, `/bills`, `/bills/add`, `/bills/:id/edit`, `/bills/:id`, `/goals`, `/goals/add`, `/goals/:id/edit`, `/goals/:id`, `/categories`, `/categories/child/new`, `/categories/group/new`, `/categories/:id/keywords`.
   - Trợ lý & Cài đặt: `/ai-chat`, `/ai-settings`, `/notifications`, `/settings/notifications`, `/settings`, `/settings/change-password`, `/settings/delete-account`, `/settings/edit-profile`.
   - Cổng thanh toán Premium: `/premium`, `/premium/cho-thanh-toan`, `/premium/lich-su`.

---

## 📑 5. DANH MỤC CÁC TÀI LIỆU CHỨC NĂNG CHI TIẾT

Nhấp vào từng liên kết bên dưới để xem đặc tả chi tiết của từng phân hệ chức năng:
- [x] [01. Xác thực & Bảo mật tài khoản (Auth & Security)](./01_XAC_THUC_VA_BAO_MAT.md)
- [x] [02. Trang chủ & Điều hướng Navigation Shell (Home & Navigation)](./02_TRANG_CHU_VA_DIEU_HUONG.md)
- [x] [03. Quản lý Ví tiền & Tài sản ròng (Wallet & Net Worth)](./03_QUAN_LY_VI_TIEN_TE.md)
- [x] [04. Sổ giao dịch Thu / Chi / Vay nợ (Transactions & Voice/OCR)](./04_SO_GIAO_DICH_THU_CHI.md)
- [x] [05. Hệ thống Danh mục Thu Chi Đa cấp (Category System)](./05_HE_THONG_DANH_MUC.md)
- [x] [06. Ngân sách Chi tiêu & Cảnh báo hạn mức (Budgeting)](./06_NGAN_SACH_CHI_TIEU.md)
- [x] [07. Quản lý Hóa đơn định kỳ & Nhắc hạn (Recurring Bills)](./07_HOA_DON_DINH_KY.md)
- [x] [08. Mục tiêu Tiết kiệm & Tích lũy (Savings Goals)](./08_MUC_TIEU_TIET_KIEM.md)
- [x] [09. Báo cáo Phân tích Tài chính & Xuất File (Analytics & Export)](./09_BAO_CAO_PHAN_TICH.md)
- [x] [10. Trợ lý AI Gemini & Edge AI On-Device (AI Chatbot & Edge)](./10_TRO_LY_AI_VA_AI_EDGE.md)
- [x] [11. Trung tâm Thông báo & Giám sát Ngân hàng (Notifications & Bank Reminders)](./11_TRUNG_TAM_THONG_BAO_VA_NHAC_NHO.md)
- [x] [12. Gói cước Tài khoản & Thanh toán PayOS VietQR (Premium & PayOS)](./12_GOI_CUOC_PREMIUM_VA_PAYOS.md)
- [x] [13. Kiến trúc Đồng bộ Offline-First & CSDL SQLite (Sync Engine)](./13_KIEN_TRUC_DONG_BO_OFFLINE_FIRST.md)
- [x] [⭐ ĐẶC TẢ 4 TRỤ CỘT PHÂN QUYỀN HỆ THỐNG — 36 TÍNH NĂNG (4_TRU_COT.md)](./4_TRU_COT.md)
