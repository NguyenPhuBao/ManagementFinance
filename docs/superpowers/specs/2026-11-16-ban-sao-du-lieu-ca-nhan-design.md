# Bản sao dữ liệu cá nhân — trang "Dữ liệu của tôi" (đơn client-app mục 52)

> Ngày: 2026-11-16 (phiên 48). Nhánh: `TranQuangDat-backend` (worktree `.superpowers/backend-worktree`).
> Đơn gốc: `docs/superpowers/client-app/CAN-LAM/BAN_SAO_DU_LIEU.md` (backend NPBao, 2026-11-14 — chủ dự án chốt **bắt buộc**).
> Người dùng duyệt ba phần thiết kế trong phiên 48. Chốt mã mở lại đích danh cho việc này (người dùng: *"cứ B C D đi"*).

## 0. Mục đích

Thực hiện quyền **xem và nhận bản sao dữ liệu** của chủ thể dữ liệu (Luật Bảo vệ dữ liệu cá nhân 2025; đáp ứng trong 10 ngày).
Người dùng bấm một nút trong app → backend tạo hai tệp ở nền (JSON toàn bộ dữ liệu máy chủ giữ, CSV giao dịch) → email báo sẵn sàng
(không có đường dẫn) → người dùng tải trong app trong 24 giờ.

**Không** phải sao lưu / khôi phục (người dùng chốt 2026-11-16 — không làm chức năng nhập ngược): dữ liệu đã tự đồng bộ với máy
chủ, cài lại app chỉ cần đăng nhập; nhập JSON ngược vướng trùng id, khoá ngoại, số dư suy từ sổ, dữ liệu nhà, mốc `update_at`, và
backend không có API nhập. Trang nói rõ điều này để người dùng không hiểu nhầm.

## 1. Lối vào

Trang Cài đặt (`profile/presentation/widgets/noi_dung_cai_dat.dart`), thẻ **BẢO MẬT & TÙY CHỌN**, dòng **thứ tư** ngay dưới
"Khoá ứng dụng": "Dữ liệu của tôi", cùng kiểu `_mucHanhDong` (biểu tượng + chữ + mũi tên) → `context.push('/settings/du-lieu-cua-toi')`.
Route con khai cùng chỗ các route con khác của `/settings` trong `app_router.dart`.

## 2. Trang và trạng thái

**Đầu trang** — đoạn giải thích: bản sao gồm toàn bộ dữ liệu máy chủ đang giữ, dạng JSON và CSV giao dịch (mở bằng Excel); tệp tải
được trong 24 giờ; mỗi 24 giờ một yêu cầu; *"Tệp này để bạn giữ hoặc xem, không dùng để khôi phục. Dữ liệu của bạn đã tự đồng bộ
với máy chủ."*

**Thẻ trạng thái** — đọc `GET /api/account/data-export/latest` mỗi khi trang hiện:

| Trạng thái | Nguồn | Hiện |
|---|---|---|
| Chưa yêu cầu | `data: null` | nút **"Nhận bản sao dữ liệu của tôi"** |
| Đang tạo | `PROCESSING` | vòng xoay + "Đang tạo, bạn sẽ nhận email khi xong"; nút khoá |
| Sẵn sàng | `READY` | "Tải được tới HH:mm dd/MM" (`expiresAt`, giờ máy) + **"Tải dữ liệu (JSON)"** / **"Tải giao dịch (CSV)"** (theo `files`) |
| Hết hạn | `EXPIRED` | "Tệp đã bị xoá" + nút yêu cầu lại |
| Lỗi | `FAILED` | "Tạo bản sao không thành công" + nút yêu cầu lại |
| (đọc không được) | mất mạng / 5xx | "Cần kết nối mạng để xem bản sao dữ liệu" + **Thử lại**; không treo |

Chuỗi `status` lạ đọc là **Lỗi** (cho yêu cầu lại; server tự chặn bằng 429 nếu chưa đủ 24 giờ).

**Bấm yêu cầu** (`POST /api/account/data-export`):
- `202` → `baoNhanh("Đã gửi tới email {email}, tệp sẵn sàng sau ít phút")`, chuyển *Đang tạo* (dùng `data` trả về).
- `429 DATA_EXPORT_RATE_LIMITED` → `baoNhanh("Bạn có thể yêu cầu lại sau {X giờ Y phút}")` từ header `Retry-After` (giây); thiếu
  header → câu không số "Bạn đã yêu cầu trong 24 giờ qua". Đọc lại trạng thái.
- Bấm hai lần liền chỉ gửi một lần (cờ đang gửi trong cubit).

**Tải tệp** (`GET …/:id/download?format=json|csv`, `ResponseType.bytes`):
- Lưu nguyên bytes (không giải mã, giữ BOM của CSV) vào **Tải về** qua `LuuTepPlatform.luuVaoTaiVe` (`MediaStore`, không xin quyền);
  trả `null` → ghi tệp tạm + `SharePlus` (đúng khuôn `XuatTepServiceImpl`). Báo `baoNhanh("Đã lưu {đường dẫn}")` khi lưu được.
- Tên tệp từ `Content-Disposition` (`filename="…"`); thiếu / rác → `flowmoney-du-lieu-ca-nhan-YYYYMMDD.json` /
  `flowmoney-giao-dich-YYYYMMDD.csv`. Tên chỉ nhận ký tự an toàn (`[A-Za-z0-9._-]`) — tên đi vào `MediaStore` / đường dẫn tạm.
- `410 DATA_EXPORT_EXPIRED` → báo hết hạn + đọc lại; `409 DATA_EXPORT_NOT_READY` / `404 DATA_EXPORT_NOT_FOUND` → đọc lại.
- Mime: `application/json` / `text/csv`.

**Tự cập nhật:** đang mở trang mà nhận `account.data_export_ready` → đọc lại. Không hỏi định kỳ; quay lại trang (`TickerMode` /
vòng đời) cũng đọc lại.

## 3. Cấu trúc mã — mảng mới `features/ban_sao_du_lieu/`

| Tầng | Tệp | Việc |
|---|---|---|
| `domain/` | `trang_thai_ban_sao.dart` | enum `TrangThaiBanSao { chuaYeuCau, dangTao, sanSang, hetHan, loi }`; `trangThaiTuChuoi(String?)`; `chuChoYeuCauLai(Duration)` → "5 giờ 12 phút" / "12 phút" / "dưới 1 phút" |
| `data/models/` | `yeu_cau_ban_sao.dart` | `YeuCauBanSao { id, trangThai, requestedAt, readyAt?, expiresAt?, files, email? }` + `yeuCauBanSaoTuJson` |
| `data/datasources/` | `ban_sao_du_lieu_api.dart` | `layMoiNhat()`, `yeuCau()`, `taiTep(id, dinhDang)` qua `sl<DioClient>().dio`; `TepTaiVe { ten, bytes, mime }`; lỗi → `LoiBanSao` (`daGioiHan(Duration?)` · `hetHan` · `chuaXong` · `khongCo` · `matMang` · `khac`) |
| `data/repositories/` | `ban_sao_du_lieu_repository.dart` + `ban_sao_du_lieu_repository_impl.dart` | cổng duy nhất trang gọi (quét 31) |
| `data/` | `luu_tep_ban_sao.dart` | lưu Tải về / sheet chia sẻ, dùng lại `analytics/data/datasources/luu_tep_platform.dart` (không chép; `core/` khoá 15 chủ đề — quét 25) |
| `presentation/bloc/` | `du_lieu_cua_toi_cubit.dart` + state | nạp / mất mạng / có dữ liệu; cờ đang gửi, đang tải (theo định dạng) |
| `presentation/pages/` | `du_lieu_cua_toi_page.dart` | giao diện theo Stitch; nghe `RealtimeEvent.banSaoDuLieuSanSang` (khuôn `lich_su_mua_page.dart`) |

Chạm mã sẵn có: `core/realtime/realtime_event.dart` thêm `banSaoDuLieuSanSang` ← `account.data_export_ready` (im lặng, `loiNhan
null`, không kéo đồng bộ, không đọc payload); `noi_dung_cai_dat.dart` (dòng thứ tư); `app_router.dart` (route); DI đăng ký API +
repository + bộ lưu.

**Không** đổi: không bảng SQLite, không đường đồng bộ, không gửi tệp đi đâu. Mọi lời gọi đi Dio có `AuthInterceptor` → chỉ khi
đăng nhập. Gói Basic / Premium đều dùng được (quyền pháp lý, không qua `MaQuyen`).

## 4. Kiểm thử (`flutter test`, ca đỏ trước)

- Domain: năm trạng thái + chuỗi lạ; `chuChoYeuCauLai` 18.720 s → "5 giờ 12 phút", < 60 s, đúng 24 giờ.
- Model: `null`, `READY` có `files`, thiếu trường ngày.
- Datasource (Dio giả): tên từ `Content-Disposition` (có nháy, không nháy, thiếu, ký tự lạ); bytes giữ BOM; 429 có / không
  `Retry-After`; 410 / 409 / 404 / mất mạng → đúng loại.
- Cubit: yêu cầu khi `dangTao` không gọi `POST`; bấm hai lần → một `POST`; 202 → *Đang tạo*; sự kiện socket → đọc lại; 410 khi tải
  → đọc lại; đọc hỏng → trạng thái mất mạng, Thử lại nạp lại.
- Widget: mỗi trạng thái đúng câu / nút; khổ 320 dp với mốc ngày dài nhất (không tràn); trang Cài đặt có dòng thứ tư, bấm tới đúng
  route (router thật).
- `RealtimeEvent`: `account.data_export_ready` → `banSaoDuLieuSanSang`, im lặng.
- Test quét sẵn có tự canh: 12 (tooltip), 19 (không `SnackBar`), 22 / 31 (trang không chạm CSDL / datasource), 25 (vị trí tệp).

## 5. Giao diện

Màn Stitch **"Cài đặt - Dữ liệu của tôi"** (dự án FlowMoney `5106367939423432838`), trạng thái *Sẵn sàng*, theo bảng màu / font màn
Cài đặt — tạo **trước** khi viết trang. Timeout thì không gọi lại, nhờ người dùng nhìn. Chỗ app khác Stitch ghi vào mục 8 spec này.

## 6. Đo máy thật

Đơn ghi API **chưa triển khai Render**. ❓ **Còn mở:** đo bằng backend cục bộ (worktree không `.env`; CSDL dev phải có bảng
`data_export_request` — migration backend; mỗi bước bật backend / áp migration / chọn CSDL xin phép đích danh; kiểm *danh tính CSDL*
trước khi đăng nhập) **hay** chờ Render (đợt này dừng ở test + analyze + máy ảo, ghi rõ chưa đo đường thật). Mặc định: chờ Render,
hỏi lại trước bước đo.

Kịch bản: (a) yêu cầu lần đầu → *Đang tạo*; (b) email + socket → tự sang *Sẵn sàng*; (c) tải JSON + CSV, mở CSV bằng Excel đúng dấu;
(d) yêu cầu lần hai → thời gian chờ; (e) mất mạng → báo cần mạng; (f) 320 dp không tràn.

## 7. Tài liệu khi xong

Khối mục 14 `PROJECT_CONTEXT.md`; hàng *Đụng vào bản sao dữ liệu* trong `CLAUDE.md`; trạng thái mục 52 — sửa phần client trong
`client-app/CAN-LAM/README.md` thì hỏi người dùng trước (tệp do backend viết).

## 8. Chỗ mã khác spec

Thi công 2026-11-16 (phiên 49, inline, commit `2a7a2afd..8cdfe74c`):

1. **Lỗi tách hai nơi:** `LoaiLoiBanSao` / `LoiBanSao` ở `domain/loi_ban_sao.dart` (Dart thuần), không ở datasource như bảng mục 3 —
   cubit đặt trong datasource thì đỏ quét 31 (trang không import datasource API). Phép đổi `DioException` → lỗi (`loiBanSaoTu`) vẫn ở
   `data/datasources/ban_sao_du_lieu_api.dart`, tệp ấy `export` lại `loi_ban_sao.dart`. Khuôn `premium/domain/cau_loi_thanh_toan.dart`.
2. **Model chỉ giữ trường app dùng:** `YeuCauBanSao { id, trangThai, expiresAt?, files, email? }` — bỏ `requestedAt` / `readyAt`
   (không chỗ nào hiện). `files` chỉ nhận `json` / `csv`; `status` không phải chuỗi → *Lỗi*.
3. **Đang tạo:** không có nút (spec ghi "nút khoá") — vòng xoay + câu là đủ; cubit vẫn chặn `POST` khi `dangTao`.
4. **Sẵn sàng:** dòng đầu luôn là "Bản sao đã sẵn sàng" (tick xanh `AppColors.income`); "Tải được tới HH:mm dd/MM" chỉ hiện khi có
   `expiresAt`.
5. **409 / 404 khi tải:** ngoài đọc lại còn báo "Tệp chưa sẵn sàng" (lỗi); mất mạng khi tải / gửi có câu riêng.
6. **Đọc lại khi quay về app:** `AppLifecycleListener.onResume`, không `TickerMode`.
7. **Stitch:** `generate_screen_from_text` trả `timeout` (2026-11-16, không gọi lại); `list_screens` sau đó vẫn 170 màn, chưa thấy màn
   mới. Trang dựng theo khung của kế hoạch + bảng màu màn Cài đặt (nền `#EDEDE9`, thẻ trắng bo 12, chữ phụ `#767872`). Màn Stitch
   xuất hiện muộn thì đối chiếu lại.
