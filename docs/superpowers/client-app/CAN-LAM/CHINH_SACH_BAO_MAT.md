# Mục 51 — Chính sách bảo mật: người dùng đồng ý trước khi dùng app

> Người nhận: thành viên Client-app. Người giao: Backend / Admin-web (NPBao). Ngày: 2026-11-13.
> Trạng thái: Backend và Admin-web **đã xong** (chưa deploy Render). Client-app **bắt buộc làm** (Chủ dự án chốt 2026-11-14). Backend hiện **chưa chặn** người dùng chưa đồng ý; sẽ bật `403 POLICY_NOT_ACCEPTED` sau khi app làm xong (báo trước), nên app cũ vẫn chạy trong thời gian chờ.
> Căn cứ: Luật Bảo vệ dữ liệu cá nhân 2025, Nghị định 356/2025/NĐ-CP (lưu bằng chứng đồng ý). Chi tiết: `docs/Rule_Project/Data_Security.md` mục 7.1, `docs/Rule_Project/Khao_sat_phap_ly_2026-11.md`.

## 1. Nghiệp vụ (Chủ dự án chốt 2026-11-13)

- **Cập nhật 2026-11-15:** có thể có **nhiều chính sách song song** (ví dụ "Chính sách bảo mật", "Điều khoản sử dụng"). Mỗi chính sách có nhiều phiên bản, tối đa **một phiên bản đang sử dụng**. Admin thêm, ngừng, kích hoạt ở Admin-web (Bảo trì & Thông báo → Chính sách); nội dung đã đăng không sửa được.
- Người dùng **phải đồng ý mọi chính sách đang sử dụng** mới dùng được app. Đồng ý từng chính sách một lần cho phiên bản đang dùng, **không có rút đồng ý**.
- Khi admin kích hoạt một phiên bản mới (hoặc một chính sách mới), người dùng phải đồng ý bản đó mới được dùng tiếp. Chính sách bị ngừng thì không còn phải đồng ý.
- Không đồng ý: đăng xuất (không xóa dữ liệu SQLite, theo quy tắc bảo lưu dữ liệu khi đăng xuất).

## 2. Hợp đồng API (đã có ở Backend)

Mọi request gửi `Authorization: Bearer <access token>` như các API khác. Không gửi `idaccount` trong body (Backend lấy từ JWT).

### `GET /api/policy/current`
```json
{
  "success": true,
  "data": {
    "policies": [
      { "version": 3, "policyId": 1, "docVersion": 2, "title": "Chính sách bảo mật", "content": "…(văn bản thuần, xuống dòng bằng \\n)…", "status": "ACTIVE", "publishedAt": "2026-11-15T03:28:08.632Z", "accepted": true, "acceptedAt": "2026-11-15T04:00:00.000Z" },
      { "version": 2, "policyId": 2, "docVersion": 1, "title": "Điều khoản sử dụng", "content": "…", "status": "ACTIVE", "publishedAt": "2026-11-14T03:28:08.632Z", "accepted": false, "acceptedAt": null }
    ],
    "policy": { "version": 2, "policyId": 2, "docVersion": 1, "title": "Điều khoản sử dụng", "content": "…", "status": "ACTIVE", "publishedAt": "…" },
    "acceptedVersion": 3,
    "acceptedAt": "2026-11-15T04:00:00.000Z",
    "mustAccept": true
  }
}
```
- **`policies`** (thêm 2026-11-15): mọi chính sách đang sử dụng. `version` là **mã để gửi khi đồng ý** (không phải số hiển thị); hiển thị dùng `title` + `v{docVersion}`. `accepted` cho biết người dùng đã đồng ý bản này chưa.
- `mustAccept: true` khi còn ít nhất một mục trong `policies` có `accepted: false`. App hiện **từng** chính sách chưa đồng ý (lần lượt hoặc gộp một màn có nhiều mục) và gửi đồng ý cho từng `version`.
- `policy` giữ cho tương thích: chính sách đang dùng đầu tiên mà người dùng chưa đồng ý (đã đồng ý hết thì là bản đang dùng mới nhất). App mới nên dùng `policies`.
- `policies: []`, `policy: null`, `mustAccept: false` khi không có chính sách nào đang sử dụng: cho dùng app bình thường.

### `POST /api/policy/accept`
Body: `{ "version": 2 }` (đúng `version` của chính sách vừa hiện cho người dùng). Nhiều chính sách thì gọi một lần cho mỗi chính sách.
- `201`: ghi nhận lần đầu; `200`: đã đồng ý phiên bản này trước đó. `data` trả lại cùng dạng `GET /current` (`mustAccept: false` khi đã đồng ý hết).
- `409` `code: "POLICY_VERSION_OUTDATED"`: bản này vừa bị admin ngừng sử dụng trong lúc người dùng đang đọc → gọi lại `GET /current`, hiện danh sách mới.
- `404` `code: "POLICY_NOT_FOUND"`: không có chính sách nào đang sử dụng → cho dùng app.
- `400` `code: "POLICY_VERSION_REQUIRED"`: thiếu / sai `version`.
- Backend lưu kèm: thời điểm, chỉ mục mù IP (không lưu IP), header `x-device-name`, `user-agent`. App nên tiếp tục gửi `x-device-name` (mục 3.1 của `README.md`).

### Sự kiện Socket.io `system.policy_updated`
Phát tới mọi client khi admin **kích hoạt hoặc ngừng** một phiên bản (từ 2026-11-15; thêm phiên bản mới không phát vì bản mới ở trạng thái ngừng). Payload: `{ "version": 2, "title": "…", "status": "ACTIVE" }`. Client chỉ cần dựa vào tên sự kiện: nhận được thì gọi `GET /api/policy/current`.

## 3. Việc Client-app cần làm

| # | Việc | Gợi ý vị trí | Nghiệm thu |
|---|---|---|---|
| 1 | Sau đăng nhập và mỗi lần mở app khi có mạng: gọi `GET /api/policy/current`; `mustAccept` thì mở màn hình chính sách toàn màn hình, chặn các màn khác | luồng sau đăng nhập / khởi động | Tài khoản chưa đồng ý không vào được Trang chủ |
| 2 | Màn hình chính sách: với **mỗi** mục `policies` có `accepted: false`, hiện `title` + `v{docVersion}`, `content` (cuộn được), nút "Đồng ý" và "Không đồng ý". Đồng ý → `POST /api/policy/accept` với `version` của mục đó; đồng ý hết mới vào app. Không đồng ý → đăng xuất, giữ SQLite | `features/` mới (ví dụ `features/policy/`) | Đồng ý xong vào app; Backend có 1 dòng `policy_acceptance` đúng `idaccount`, `policy_version` |
| 3 | Xử lý `409 POLICY_VERSION_OUTDATED`: tải lại và hiện phiên bản mới | interceptor hoặc màn chính sách | Không kẹt vòng lặp, không hiện lỗi thô |
| 4 | Thêm sự kiện `system.policy_updated` vào `RealtimeEvent` (ví dụ `chinhSachMoi`), nhận được thì gọi lại bước 1 | `core/realtime/realtime_event.dart` | Admin đăng phiên bản mới → app đang mở hiện màn chính sách |
| 5 | Ngoại tuyến (offline-first): không gọi được Backend thì **không chặn** người dùng; kiểm lại khi có mạng. Có thể lưu `acceptedVersion` cục bộ để tránh nháy màn hình | lưu cục bộ (SecureStorage / SQLite) | Mất mạng vẫn dùng app được |

**Đồng bộ CSDL:** không thêm bảng đồng bộ. Dữ liệu đồng ý chỉ nằm ở Backend; bảng `privacy_policy`, `policy_acceptance` không đi qua `/sync/*`.

## 4. Dự kiến về sau (chưa làm, sẽ báo trước)

- Backend có thể trả `403` `code: "POLICY_NOT_ACCEPTED"` cho người dùng chưa đồng ý phiên bản hiện hành, khi Client-app đã làm xong mục 3. Thời điểm bật do Chủ dự án quyết; sẽ ghi vào bảng trả lời và `Event-Notification-to-ClientApp.md` trước khi bật.

## 5. Ghi chú liên quan: IP và thiết bị (đổi từ 2026-11-13)

- Backend nay lưu IP đầy đủ ở dạng **mã hóa** (chỉ admin xem được, phải nhập PIN, mỗi lần xem ghi nhật ký) cùng bản che `113.161.xx.xx`; IP lấy từ kết nối, app **không** cần gửi IP và **không** gọi dịch vụ ngoài để lấy IP (giữ như mục 3.2 của `README.md`). IP đầy đủ tự xóa sau 365 ngày.
- **Bắt buộc** (Chủ dự án chốt 2026-11-14): chú thích trong `lib/core/api/ten_thiet_bi.dart` ghi Backend lưu "IP che mờ" đã lỗi thời. Sửa thành: Backend lưu IP đã che (`113.161.xx.xx`) và IP đầy đủ dạng mã hóa (chỉ admin xem, phải nhập PIN, mỗi lần xem ghi nhật ký, tự xóa sau 365 ngày); app chỉ gửi `x-device-name`, không gửi IP.
