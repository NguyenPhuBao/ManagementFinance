# Mục 52 — Bản sao dữ liệu cá nhân: người dùng nhận bản sao trong app

> Người nhận: thành viên Client-app. Người giao: Backend / Admin-web (NPBao). Ngày: 2026-11-14.
> Trạng thái: Backend và Admin-web **đã xong** (chưa deploy Render). Client-app **bắt buộc làm** (Chủ dự án chốt 2026-11-14). App cũ chưa làm vẫn chạy bình thường: chỉ là chưa có nút.
> Căn cứ: Luật Bảo vệ dữ liệu cá nhân 2025 — chủ thể dữ liệu có quyền xem và nhận bản sao dữ liệu, đáp ứng trong 10 ngày. Chi tiết: `docs/Rule_Project/Data_Security.md` mục 10.11.

## 1. Nghiệp vụ (Chủ dự án chốt 2026-11-14)

- Người dùng bấm **"Nhận bản sao dữ liệu của tôi"** trong app (Cài đặt → Dữ liệu của tôi).
- Backend tạo tệp ở chế độ nền, rồi **gửi email báo đã sẵn sàng**. Email **không có đường dẫn tải**: người dùng phải **đăng nhập app** mới tải được.
- Có 2 tệp: **JSON** (toàn bộ dữ liệu cá nhân máy chủ đang giữ) và **CSV giao dịch** (mở thẳng bằng Excel).
- Tệp tải được trong **24 giờ**, sau đó tự xóa. Mỗi tài khoản yêu cầu tối đa **1 lần / 24 giờ** (yêu cầu bị lỗi không tính).
- Nhật ký trong tệp chỉ gồm các lượt app gọi tới máy chủ (12 tháng gần nhất). App không gửi hoạt động cá nhân trong app lên máy chủ; giữ nguyên như vậy.

## 2. Hợp đồng API (đã có ở Backend)

Mọi request gửi `Authorization: Bearer <access token>`. Không gửi `idaccount` (Backend lấy từ JWT).

### `POST /api/account/data-export`
- `202`:
```json
{ "success": true, "message": "Đang tạo bản sao dữ liệu. Bạn sẽ nhận email khi tệp sẵn sàng.",
  "data": { "id": "uuid", "status": "PROCESSING", "requestedAt": "2026-11-14T03:00:00.000Z", "email": "an***@gmail.com" } }
```
- `429` `code: "DATA_EXPORT_RATE_LIMITED"` + header `Retry-After` (giây): đã yêu cầu trong 24 giờ qua → hiện "Bạn có thể yêu cầu lại sau …" (đổi giây thành giờ / phút).
- `401`: như các API khác (đăng nhập lại).

### `GET /api/account/data-export/latest`
- `200`, `data` là `null` (chưa từng yêu cầu) hoặc:
```json
{ "id": "uuid", "status": "READY", "requestedAt": "…", "readyAt": "…", "expiresAt": "…", "emailSentAt": "…", "files": ["json", "csv"] }
```
- `status`: `PROCESSING` (đang tạo) · `READY` (tải được tới `expiresAt`) · `EXPIRED` (đã xóa tệp) · `FAILED` (lỗi, cho yêu cầu lại ngay).
- `files` chỉ có phần tử khi `READY`.

### `GET /api/account/data-export/:id/download?format=json|csv`
- `200`: nội dung tệp, header `Content-Disposition: attachment; filename="flowmoney-du-lieu-ca-nhan-YYYYMMDD.json"` hoặc `flowmoney-giao-dich-YYYYMMDD.csv`, `Content-Type` `application/json; charset=utf-8` / `text/csv; charset=utf-8`. Tải dạng bytes (`ResponseType.bytes`), giữ nguyên, không giải mã lại.
- `404` `DATA_EXPORT_NOT_FOUND` (không phải của tài khoản này) · `409` `DATA_EXPORT_NOT_READY` · `410` `DATA_EXPORT_EXPIRED`.

### Sự kiện Socket.io `account.data_export_ready`
Phát vào phòng của tài khoản khi tệp sẵn sàng. Payload `{ "id": "uuid", "expiresAt": "…" }`. Nhận được thì gọi lại `GET /latest` để màn hình chuyển sang trạng thái tải được. App bỏ qua sự kiện lạ nên bản cũ không lỗi.

### Nội dung tệp JSON (tham khảo, app không cần đọc)
Các mục cấp 1: `meta` (thời điểm tạo, đoạn giải thích phạm vi), `account`, `profile`, `wallets`, `transactions`, `budgets`, `bills`, `goals`, `categories`, `households`, `payments`, `devices` (IP đã che), `policyAcceptances`, `serverActivity`. Không có mật khẩu, PIN, token, OTP, IP đầy đủ.

## 3. Việc Client-app cần làm

| # | Việc | Gợi ý vị trí | Nghiệm thu |
|---|---|---|---|
| 1 | Mục **"Dữ liệu của tôi"** trong Cài đặt: mở thì gọi `GET /latest`, hiện trạng thái (chưa yêu cầu / đang tạo / sẵn sàng tới … / đã hết hạn / lỗi) | `features/profile/` (hoặc màn Cài đặt hiện có) | Mỗi trạng thái hiện đúng câu; ngoại tuyến thì báo cần mạng, không treo |
| 2 | Nút **"Nhận bản sao dữ liệu của tôi"**: `POST /data-export`; `202` → "Đã gửi tới email {email}, tệp sẵn sàng sau ít phút"; `429` → thời gian còn phải chờ theo `Retry-After`. Khóa nút khi đang `PROCESSING` | như trên | Bấm 2 lần trong 24 giờ: lần 2 không tạo yêu cầu mới, hiện thời gian chờ |
| 3 | Khi `READY`: 2 nút **"Tải dữ liệu (JSON)"** và **"Tải giao dịch (CSV)"** → `GET /:id/download?format=…`, lưu / chia sẻ tệp bằng cơ chế đang dùng cho xuất báo cáo (`features/analytics/data/datasources/luu_tep_platform.dart`, `share_plus`), giữ nguyên tên tệp từ `Content-Disposition` | như trên | Tệp CSV mở bằng Excel đúng dấu tiếng Việt; JSON mở được; `410` → báo hết hạn, cho yêu cầu lại |
| 4 | Nghe `account.data_export_ready` (thêm vào `RealtimeEvent`, ví dụ `banSaoDuLieuSanSang`) → gọi lại `GET /latest` | `core/realtime/realtime_event.dart` | Đang mở màn hình thì tự chuyển sang "sẵn sàng" khi tệp xong |
| 5 | Chỉ tải khi đã đăng nhập (dùng `Dio` có `AuthInterceptor` sẵn); không lưu tệp tải về vào SQLite; không gửi tệp lên dịch vụ ngoài | — | Đăng xuất rồi mở lại: phải đăng nhập mới tải được |

**Đồng bộ CSDL:** không thêm bảng đồng bộ. Bảng `data_export_request` chỉ ở Backend, không đi qua `/sync/*`.

## 4. Ghi chú

- Email gửi tới địa chỉ email của tài khoản (Brevo). Nếu email không tới, người dùng vẫn thấy trạng thái trong app và tải được.
- Admin-web hiện trạng thái yêu cầu gần nhất trong hộp chi tiết người dùng (dòng "Bản sao dữ liệu").
