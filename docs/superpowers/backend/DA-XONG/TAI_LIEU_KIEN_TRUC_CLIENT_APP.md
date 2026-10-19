# Thông báo + xin sửa chữ: kiến trúc Client-app trong `Project.md` §3.3 tả sai mã đang chạy

> ✅ **ĐÓNG 2026-10-18 — client soát sau gộp `main` @ `e7570e16`, chuyển sang `DA-XONG/`.** Backend sửa `Project.md` §3.3 ở
> `3a5d320c` theo mặc định của mục 3. Câu trỏ sang `docs/KIEN_TRUC_CLIENT_APP.md` nằm ở `Project.md:381`. Cả sáu dòng của
> bảng mục 2 đã vào (`:386`–`:393`). Hai chỗ nhỏ còn lại, không mở đơn mới. (1) Liên kết ở `:381` là đường dẫn tuyệt đối
> `file:///d:/Tai_Lieu_IUH/…` của máy người viết, nên mở trên máy khác là hỏng. (2) Dòng *Repository* chép đúng câu đơn
> đề nghị ngày 2026-10-10, *"hoặc hàng Drift (hoá đơn, danh mục)"*. Câu ấy **lạc hậu theo mã** từ đợt Entity Hoá đơn
> (2026-10-14) và Entity Danh mục (2026-10-15): repository nay không còn lối nào trả hàng Drift. Lần sau client xin sửa
> `Project.md` thì gộp hai chỗ ấy vào.

**Ngày:** 2026-10-10 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` · **Mục:** 42
**Loại:** **thông báo**, kèm **xin sửa chữ** và một câu hỏi có mặc định. **Không xin đổi mã backend, không migration,
không trường đồng bộ mới, không đổi hợp đồng API.** Backend không trả lời thì client làm theo mặc định ở mục 3.

---

## Tệp cần đọc

| Tệp | Vì sao |
|---|---|
| `Project.md` (gốc repo) §3.3 *"Kiến Trúc Client-app (Offline-first, Flutter)"*, dòng 377–389 | chỗ xin sửa — tệp do backend viết (48/50 commit theo `git log --format=%an -- Project.md`), client không sửa thẳng |
| `docs/KIEN_TRUC_CLIENT_APP.md` | tài liệu kiến trúc client mới, client sở hữu; mọi số đo ở đó đếm ngày 2026-10-10 |
| `docs/superpowers/specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md` | đợt sửa kiến trúc client cùng ngày, người dùng duyệt từng phần |

---

## 1. Bối cảnh

Ngày 2026-10-10 client làm một bản đánh giá kiến trúc toàn diện rồi một đợt **bịt điểm rò** (giữ kiến trúc, không đổi
hành vi người dùng): trang thôi gọi thẳng CSDL (`sl<AppDatabase>` ở `presentation/` 29 chỗ → 0), hai trang lớn tách
thành widget theo khối (`analytics_page` 4.208 → 339 dòng, `add_transaction_page` 3.107 → 2.007), `AuthBloc` chỉ còn
trạng thái còn vòng đời phiên chuyển sang `PhienDieuPhoi`, và có CI GitHub Actions chạy `flutter analyze` + toàn bộ
`flutter test` sau mỗi lần đẩy.

Lượt đánh giá đối chiếu `Project.md` §3.3 với mã và thấy bảng ấy tả một kiến trúc **không có**: dòng *State Management*
ghi *"Mỗi màn hình có BLoC riêng (loading/loaded/error)"*, trong khi app có **3 Bloc + 7 Cubit** (`grep -rhoE 'class \w+
extends (Bloc|Cubit)<' src/Client-app/lib`) cho các màn có luồng ghi, còn **289** chỗ `setState` và các màn đọc dùng
thẳng stream Drift. Dòng *Repository* ghi *"Abstract nguồn dữ liệu (local/remote)"* trong khi repository client chỉ đọc
SQLite (mạng là việc của `SyncEngine`), và trả hai loại kiểu khác nhau tuỳ mảng. Người đọc báo cáo đồ án sẽ đọc §3.3 trước.

## 2. Xin sửa — dòng hiện tại → câu thay thế

| Dòng hiện tại (`Project.md` §3.3) | Câu thay thế đề nghị |
|---|---|
| **State Management** · BLoC · *"Mỗi màn hình có BLoC riêng (loading/loaded/error)"* | BLoC + Cubit · *"BLoC + Cubit cho 10 màn có luồng ghi (3 Bloc, 7 Cubit); màn đọc dùng stream Drift; trạng thái màn trong widget"* |
| **Repository** · Repository Pattern · *"Abstract nguồn dữ liệu (local/remote), ưu tiên đọc local"* | Repository Pattern · *"Interface ở tầng data, trả Entity (ví, giao dịch, mục tiêu, ngân sách) hoặc hàng Drift (hoá đơn, danh mục); chỉ đọc/ghi SQLite — mạng là việc của Sync Engine"* |
| **Real-time** · Socket.IO · *"Backend push sự kiện → client cập nhật local DB + UI"* | Socket.IO · *"Sự kiện là tín hiệu: client chỉ đọc tên sự kiện rồi kéo dữ liệu qua `/sync/pull` (trừ `account.force_logout` mang lý do)"* — *đề nghị thêm, backend tự quyết* |
| *(thêm dòng)* **Test quét kiến trúc** | Test đọc mã nguồn `lib/` · *"29 test quét (26 tệp mang số 1–25, cộng 3 không số — đếm lại 2026-10-11 sau khi thêm test quét 25) canh các luật một-định-nghĩa: tầng giao diện không cầm CSDL, chỉ một tệp import mỗi gói native, không fallback tài khoản admin…"* |
| *(thêm dòng)* **Cổng nền tảng** | Interface + bản giả · *"OsNotifier (thông báo), DocChuAnh (OCR ML Kit), SlmRuntime (Gemma trên máy), kênh Kotlin `flowmoney/*` — mọi ranh giới nền tảng thay được bằng bản giả trong test"* |
| *(thêm dòng)* **Chạy nền** | WorkManager (Android) · *"Tự trả hoá đơn / tự trích mục tiêu chạy cả khi app đóng: WorkManager đánh thức engine Flutter không giao diện, đồng bộ trong lượt nền (2026-10-10)"* |

Hai dòng bullet dưới bảng (*Trigger sync*, *Business logic*) vẫn đúng, không xin sửa.

## 3. Câu hỏi cho backend

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Backend có muốn tài liệu kiến trúc client nằm **trong** `Project.md` hay chỉ **trỏ** sang `docs/KIEN_TRUC_CLIENT_APP.md`? | **Trỏ**: §3.3 giữ bảng ngắn (đã sửa theo mục 2) và thêm một dòng *"Chi tiết: `docs/KIEN_TRUC_CLIENT_APP.md`"*; client giữ tệp ấy khớp mã |

## 4. Phụ lục — sáu chỗ chữ lệch tên, thấy trong lượt soát (không bắt buộc)

| Tệp · dòng | Chữ hiện tại | Mã thật |
|---|---|---|
| `docs/Admin-web/10-ai-copilot-and-financial-health.md` §7 (*Ảnh hưởng đến Mobile App*, về sau gộp `main` @ `79e46225`) | *"Giao diện và thuật toán tính điểm FHS tại Admin-web hoàn toàn đồng nhất với màn hình Chatbot AI trên Mobile App Flutter"* | màn Trợ lý AI của client chạy **Gemma 4 E2B trên máy** (`flutter_gemma`, không gửi gì lên server — `docs/AI_EDGE_FEATURE.md`); chatbot trực tuyến + FHS của backend (`modules/ai/features/chatbot/`, `ChatbotAI_Moblie.md`) **chưa được client nhận** từ 2026-09-26 (chờ người dùng quyết). Hai bộ chỉ số không chung nguồn, không chung công thức. Câu đề nghị: *"FHS tại Admin-web tính trên PostgreSQL; Mobile App hiện dùng Edge AI trên máy, chưa tích hợp FHS/Chatbot của backend"* |
| `docs/Admin-web/01-authentication-and-authorization.md` §7 | *"Khi Admin thực hiện đổi mật khẩu hoặc khóa tài khoản của người dùng từ Admin-web, Backend phát lệnh Socket cưỡng chế đăng xuất"* | `api/admin.routes.js` **không có** route đổi mật khẩu người dùng (chỉ `PATCH /updatestatus/:id`, `DELETE /users/:id`); `account.force_logout` chỉ phát từ `core/socket.js:175-191` khi khoá / xoá. Đề nghị bỏ vế *"đổi mật khẩu"* |
| `docs/Rule_Project/testing-guidelines.md:124–127` (§4.3, về sau gộp `main` @ `79e46225` 2026-10-11) | *"Nhận sự kiện Socket → Icon huy hiệu Premium trên AppBar đổi màu vàng"* | client **không có** huy hiệu Premium nào trên AppBar; sự kiện `account.upgraded` / `account.permissions_updated` là **tín hiệu** (client không đọc payload) gọi `GoiRepository.lamMoi()` → `/payment/subscription-info`; thứ đổi là **thẻ Gói** ở tab Cá nhân / Cài đặt và các cửa quyền (`GoiCubit.coQuyen`), lưu secure storage `goi_tai_khoan_<id>`. Câu đề nghị: *"Tầng 1: nhận socket → thẻ Gói ở tab Cá nhân đổi Basic → Premium, cửa khoá Trợ lý AI mở. Tầng 2: `GoiCubit` nhận trạng thái mới từ `/subscription-info`, lưu `goi_tai_khoan_<id>` trong `FlutterSecureStorage`."* |
| `Project.md:1961` (gốc repo) | *"`core/constants/app_router.dart`"* | `core/router/app_router.dart` — tệp dời ngày 2026-10-10 (đợt dọn vị trí tệp theo luật mục 8 `docs/KIEN_TRUC_CLIENT_APP.md`); `Project.md:3635` chỉ ghi `app_router.dart` không kèm đường dẫn nên không lệch |
| `docs/Rule_Project/Rule_project.md:590` | *"điều hướng về màn hình Đăng nhập (`LoginScreen`) qua `AuthBloc`"* | không có lớp `LoginScreen`; `AuthBloc` phát `AuthUnauthenticated(thongBao:)`, router đưa về `/login`, màn Đăng nhập hiện hộp thoại lý do |
| `docs/progress/Client-app.md:367` | *"`context.read<AuthBloc>().add(AuthLoggedOut())`"* | không có sự kiện `AuthLoggedOut`; cưỡng chế đăng xuất đi sự kiện `TaiKhoanBiBuocDangXuat` (từ socket / HTTP qua `PhienDieuPhoi.buocDangXuat`), người dùng tự đăng xuất là `LogoutRequested` |

## 5. Kiểm lại phía client

- `grep -rE "sl<AppDatabase>" src/Client-app/lib/features/*/presentation src/Client-app/lib/shared` — 0 dòng (test quét 22).
- `grep -c "sl<" src/Client-app/lib/features/auth/presentation/bloc/auth_bloc.dart` — 0 (test quét 24).
- `grep -rhoE "class \w+ extends (Bloc|Cubit)<" src/Client-app/lib | wc -l` — 10.
- `.github/workflows/client-app.yml` — một workflow, lượt chạy xanh trên GitHub ngày 2026-10-10.
