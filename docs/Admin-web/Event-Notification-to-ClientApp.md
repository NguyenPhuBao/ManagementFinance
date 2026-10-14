# 📡 HỢP ĐỒNG GIAO TIẾP SỰ KIỆN & THÔNG BÁO TỪ ADMIN-WEB VÀ BACKEND TỚI CLIENT-APP
### (Event & Notification Communication Contract: Admin-Web & Backend ➔ Client-App)

> **Tài liệu nguồn sự thật (Source of Truth)** đặc tả toàn bộ các sự kiện, thông báo và tín hiệu điều hướng phát sinh từ **Admin-web** và **Backend** có tác động hoặc yêu cầu xử lý từ phía **Client-app (Mobile App Flutter)**.  
> 
> * **Ngày lập & phê duyệt:** 14/10/2026  
> * **Trạng thái:** PO ĐÃ PHÊ DUYỆT (Official Approved Specification)  
> * **Phạm vi đối chiếu mã nguồn thực tế:**
>   * `src/Backend/core/socket.js` (Hạ tầng WebSocket Socket.IO)
>   * `src/Backend/modules/notification/notification.service.js` (Hệ thống thông báo đa kênh)
>   * `src/Backend/modules/admin/admin.service.js` (Nghiệp vụ quản trị Admin)
>   * `src/Backend/core/resilience/maintenance.manager.js` (Điều hành bảo trì khẩn cấp & theo lịch)
>   * `src/Backend/middleware/` (`auth.js`, `maintenance.middleware.js`, `load-shedding.middleware.js`, `retry-guard.middleware.js`, `feature-permission.middleware.js`)
>   * `src/Backend/modules/aiops/aiops.quarantine.js` (Tường lửa Sentinel & Ma trận phong tỏa)
>   * `src/Client-app/lib/core/realtime/` (`realtime_event.dart`, `realtime_channel.dart`, `realtime_socket.dart`)
>   * `src/Client-app/lib/core/api/interceptors/` (`auth_interceptor.dart`, `buoc_dang_xuat.dart`)

---

## 📌 MỤC LỤC
1. [Nguyên Tắc Thiết Kế & Kiến Trúc Giao Tiếp](#1-nguyên-tắc-thiết-kế--kiến-trúc-giao-tiếp)
2. [Bảng Tổng Hợp 19 Sự Kiện & Tín Hiệu](#2-bảng-tổng-hợp-19-sự-kiện--tín-hiệu)
3. [Phần I: Đặc Tả 11 Sự Kiện Kênh Thời Gian Thực (Socket.IO Events)](#3-phần-i-đặc-tả-11-sự-kiện-kênh-thời-gian-thực-socketio-events)
4. [Phần II: Đặc Tả 8 Tín Hiệu Chốt Chặn HTTP/API (Middleware & Error Signals)](#4-phần-ii-đặc-tả-8-tín-hiệu-chốt-chặn-httpapi-middleware--error-signals)
5. [Phần III: Ma Trận Đối Chiếu Hiện Trạng Phía Client-App](#5-phần-iii-ma-trận-đối-chiếu-hiện-trạng-phía-client-app)
6. [Phần IV: Checklist & Hướng Dẫn Thực Thi Cho Dev Client-App](#6-phần-iv-checklist--hướng-dẫn-thực-thi-cho-dev-client-app)

---

## 1. NGUYÊN TẮC THIẾT KẾ & KIẾN TRÚC GIAO TIẾP

### 1.1. Mô Hình 2 Kênh Phản Ứng (Dual-Channel Reactive Architecture)
Client-app tương tác với máy chủ thông qua 2 kênh độc lập nhưng bổ trợ chặt chẽ:
1. **Kênh Thời Gian Thực (Push via WebSocket / Socket.IO):**
   - Hoạt động khi thiết bị di động có kết nối Internet và đã xác thực JWT lúc bắt tay (Handshake).
   - Máy chủ chủ động đẩy tín hiệu xuống thiết bị tức thời ($< 100\text{ms}$).
   - Client-app lắng nghe các sự kiện để: cập nhật State, kích hoạt kéo Delta Pull, hiển thị Toast/Banner, hoặc điều hướng cưỡng chế đăng xuất.
2. **Kênh Chốt Chặn Yêu Cầu (Pull/Request via REST API / Dio):**
   - Hoạt động khi Client-app chủ động gọi API (đồng bộ dữ liệu, xác thực, lấy thông tin gói, bóc tách OCR, AI chat...).
   - Các Middleware bảo vệ tại Backend (Maintenance, Load Shedding, Retry Guard, AIOps Firewall, Feature Gate, Auth) đóng vai trò là "chốt chặn bảo vệ cuối cùng", trả về mã HTTP kèm JSON DTO chuẩn hóa.
   - Client-app bắt các mã này qua Dio Interceptor để có phản ứng phù hợp (hiển thị Màn hình Bảo trì, Mời nâng cấp gói, Backoff đếm ngược...).

### 1.2. Các Nguyên Tắc Bắt Buộc (Invariant Rules)
* **Contract-First & Zero-Guesswork:** Tuyệt đối không suy đoán tên sự kiện hay payload. Mọi trường dữ liệu đều được ánh xạ đúng theo mã nguồn Backend đã kiểm thử.
* **Bảo Vệ Dữ Liệu Riêng Tư (Data Security & PDP 2025):** 
  - Socket events gửi tới người dùng **tuyệt đối không truyền số tài khoản ngân hàng đầy đủ, mật khẩu, mã OTP, số dư thô** (theo [Data_Security.md](../Rule_Project/Data_Security.md)).
  - Sự kiện cưỡng chế xóa tài khoản (`ACCOUNT_DELETED`) bắt buộc Client-app phải dọn dẹp sạch dữ liệu cá nhân cục bộ trong SQLite.
* **Phân Biệt "Đánh Thức Đồng Bộ" và "Sự Kiện Thông Điệp":**
  - Không phải sự kiện nào cũng kích hoạt `syncNow()`. Các sự kiện như nâng cấp gói, cảnh báo bảo trì, thông báo broadcast chỉ cập nhật UI / Local Storage, không ép chạy full-sync tránh nghẽn mạng và tốn pin thiết bị.

---

## 2. BẢNG TỔNG HỢP 19 SỰ KIỆN & TÍN HIỆU

| STT | Tên Sự Kiện / Tín Hiệu | Giao Thức | Nguồn Kích Hoạt | Phạm Vi | Mức Độ Ưu Tiên |
|:---:|---|:---:|---|---|:---:|
| **1** | `account.force_logout` | Socket.IO | Admin Khóa / Xóa tài khoản | Riêng tư (`account_<id>`) | 🚨 Khẩn cấp |
| **2** | `system.maintenance_changed` | Socket.IO | Admin Bật/Tắt bảo trì | Toàn hệ thống (`io.emit`) | 🚨 Khẩn cấp |
| **3** | `system.broadcast` | Socket.IO | Admin Phát thông báo hệ thống | Toàn hệ thống (`io.emit`) | ⚠️ Cao |
| **4** | `account.permissions_updated` | Socket.IO | Admin Lưu ma trận phân quyền | Toàn hệ thống (`io.emit`) | ℹ️ Tiêu chuẩn |
| **5** | `account.upgraded` | Socket.IO | Webhook PayOS / Admin duyệt | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **6** | `account.downgraded` | Socket.IO | Cron 00:00 hạ cấp hết hạn | Riêng tư (`account_<id>`) | ⚠️ Cao |
| **7** | `account.countdown` | Socket.IO | Cron 00:00 đếm ngược chờ xóa | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **8** | `sync.completed` | Socket.IO | Backend xử lý xong đợt Push | Riêng tư (`account_<id>`) | 🔇 Im lặng |
| **9** | `ocr.completed` | Socket.IO | Worker hoàn tất bóc tách OCR | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **10** | `ocr.duplicate` | Socket.IO | AI phát hiện hóa đơn trùng lặp | Riêng tư (`account_<id>`) | ⚠️ Cảnh báo |
| **11** | `user.notification` | Socket.IO | Hệ thống gửi tin nhắn riêng | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **12** | HTTP 503 `MAINTENANCE_MODE` | REST API | Chế độ bảo trì hệ thống | Mọi Client gọi API | 🚨 Khẩn cấp |
| **13** | HTTP 503 `SERVER_OVERLOADED` | REST API | Load Shedding (Lag > 100ms) | Mọi Client gọi API | ⚠️ Tạm thời |
| **14** | HTTP 429 `RETRY_LIMIT_EXCEEDED` | REST API | Bão request lặp (> 3 retries) | IP / Client vi phạm | ⚠️ Tạm thời |
| **15** | HTTP 403 `AIOPS_QUARANTINED` | REST API | Tường lửa Sentinel chặn IP | IP vi phạm | 🚫 Chặn truy cập |
| **16** | HTTP 403 `FEATURE_DISABLED` | REST API | Chặn tính năng ngoài gói | Tài khoản gói Basic | 🔒 Giới hạn |
| **17** | HTTP 401 `ACCOUNT_INACTIVE` | REST API | Admin khóa tài khoản | Tài khoản bị khóa | 🚨 Đăng xuất |
| **18** | HTTP 401 `ACCOUNT_DELETED` | REST API | Admin xóa mềm tài khoản | Tài khoản bị xóa | 🚨 Đăng xuất & Xóa |
| **19** | Socket Handshake Error | WebSocket | Bắt tay kết nối thất bại | Client kết nối Socket | 🚨 Ngắt kết nối |

---

## 3. PHẦN I: ĐẶC TẢ 11 SỰ KIỆN KÊNH THỜI GIAN THỰC (SOCKET.IO EVENTS)

### 3.1. `account.force_logout` — Cưỡng Chế Đăng Xuất Tức Thì
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:** 
  - Admin bấm **Khóa tài khoản** (`status: 'Inactive'`, kèm lý do bắt buộc) trên `UserListPage.jsx` $\rightarrow$ gọi API `PATCH /api/admin/users/:id/status`.
  - Admin bấm **Xóa người dùng** (Soft-delete) trên `UserListPage.jsx` $\rightarrow$ gọi API `DELETE /api/admin/users/:id`.
  - Hàm phát: [core/socket.js:184](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/socket.js#L184) `emitForceLogout(idaccount, reason, message)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "idaccount": 50,
  "reason": "ACCOUNT_INACTIVE",
  "message": "Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Gian lận giao dịch và hoàn tiền bất thường."
}
```
*(Trường hợp bị xóa: `"reason": "ACCOUNT_DELETED"`, `"message": "Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên."`)*
* **Xử lý bắt buộc trên Client-app:**
  1. Đọc payload an toàn tại luồng `_buocDangXuatController` trong `realtime_channel.dart`.
  2. Xóa sạch `accessToken` và `refreshToken` khỏi `FlutterSecureStorage`.
  3. Nếu `reason == 'ACCOUNT_DELETED'`: Xóa trắng dữ liệu nhạy cảm của tài khoản trong SQLite (`purgeAccountData`).
  4. Nếu `reason == 'ACCOUNT_INACTIVE'`: Giữ nguyên CSDL SQLite (để khi Admin mở lại không bị mất dữ liệu).
  5. Mở Popup Dialog thông báo lỗi ghi rõ câu `message` từ server. Khi người dùng bấm "Đồng ý", chuyển hướng về màn hình `LoginPage`.

---

### 3.2. `system.maintenance_changed` — Thay Đổi Trạng Thái Bảo Trì Hệ Thống
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`)
* **Nguồn kích hoạt:**
  - Admin kích hoạt **Bảo trì khẩn cấp** hoặc **Lên lịch bảo trì** trên `BroadcastPage.jsx`.
  - Khi lịch hẹn bảo trì tự động bắt đầu hoặc kết thúc theo thời gian hẹn ([maintenance.manager.js:277](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/resilience/maintenance.manager.js#L277)).
  - Hàm phát: [core/socket.js:328](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/socket.js#L328) `io.emit('system.maintenance_changed', maintenanceStatus)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "active": true,
  "reason": "Hệ thống đang tiến hành nâng cấp cụm máy chủ cơ sở dữ liệu định kỳ.",
  "isEmergency": true,
  "activatedAt": "2026-10-14T08:00:00.000Z",
  "activatedBy": "admin_system"
}
```
*(Khi kết thúc bảo trì: `"active": false`, `"isEmergency": false`, `"reason": null`)*
* **Xử lý bắt buộc trên Client-app:**
  1. Khi `active == true`:
     - Cập nhật biến trạng thái toàn cục `isMaintenanceActive = true`.
     - Tạm dừng ngay bộ định thời tự động đồng bộ ngầm (`SyncTimer.pause()`), triệt tiêu nguy cơ spam request gây nghẽn.
     - Hiển thị Màn hình Bảo Trì Toàn Cục (`MaintenanceScreen`) hoặc Modal khóa thao tác ghi rõ lý do.
  2. Khi `active == false`:
     - Cập nhật `isMaintenanceActive = false`.
     - Đóng Màn hình Bảo trì, hiển thị Toast xanh thông báo *"Hệ thống đã hoạt động bình thường trở lại"*.
     - Kích hoạt tiến trình đồng bộ bù (`syncNow()`).

---

### 3.3. `system.broadcast` — Thông Báo Toàn Hệ Thống
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`)
* **Nguồn kích hoạt:**
  - Admin soạn và phát tin nhắn từ Tab "Phát thông báo" tại `BroadcastPage.jsx` $\rightarrow$ gọi API `POST /api/admin/system/broadcast`.
  - Hệ thống tự động phát khi Bắt đầu bảo trì khẩn cấp (`⚠️ BẢO TRÌ HỆ THỐNG KHẨN CẤP`) hoặc Kết thúc bảo trì (`✅ HỆ THỐNG ĐÃ KẾT THÚC BẢO TRÌ`).
  - Hàm phát: [core/socket.js:257](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/socket.js#L257) `emitSystemBroadcast(broadcastData)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "id": "e4b52c08-72fa-45cf-81b4-f6b92a40dc78",
  "title": "Thông báo nâng cấp ứng dụng phiên bản 2.5",
  "message": "Hệ thống bổ sung tính năng AI Copilot và tối ưu hóa hiệu năng đồng bộ offline.",
  "level": "INFO",
  "category": "BROADCAST",
  "createdAt": "2026-10-14T08:15:00.000Z",
  "metadata": {}
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Bật Global Toast / Top In-App Banner với màu sắc trực quan theo cấp độ `level`:
     - `CRITICAL`: Nền đỏ, icon cảnh báo nguy cấp.
     - `WARNING`: Nền vàng cam, icon chú ý.
     - `INFO`: Nền xanh dương hoặc đen trung tính.
  2. Lưu bản ghi thông báo vào Bảng Thông Báo Cục Bộ SQLite để người dùng có thể xem lại trong Tab Thông Báo.

---

### 3.4. `account.permissions_updated` — Cập Nhật Ma Trận Phân Quyền Tính Năng
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`)
* **Nguồn kích hoạt:**
  - Admin thay đổi hạn mức (`LIMIT`) hoặc bật/tắt tính năng (`TOGGLE`) trên trang `PermissionManagementPage.jsx` $\rightarrow$ gọi API `PUT /api/admin/permissions/matrix`.
  - Hàm phát: [core/socket.js:378](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/socket.js#L378) `emitPermissionsUpdated(updates)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "updates": [
    {
      "idaccount_type": 1,
      "idfeature": "ai_assistant",
      "is_enabled": true,
      "limit_value": null
    },
    {
      "idaccount_type": 1,
      "idfeature": "wallets",
      "is_enabled": true,
      "limit_value": 3
    }
  ],
  "timestamp": "2026-10-14T08:20:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. **Không kích hoạt Full Sync:** Đây là thay đổi quyền, không phải dữ liệu tài chính.
  2. Gọi nhẹ API `GET /api/payment/subscription-info` (~300 bytes) để tải lại thông tin quyền của tài khoản hiện tại.
  3. Cập nhật `GoiCubit` và lưu cấu hình quyền mới vào `FlutterSecureStorage`.
  4. Giao diện tức thì ẩn/hiện hoặc giới hạn các nút chức năng (OCR, Chatbot, Thêm ví...) theo đúng cấu hình mới của server.

---

### 3.5. `account.upgraded` — Nâng Cấp Gói Premium Thành Công
* **Kênh phát:** `account_<idaccount>` (hoặc broadcast khi Admin cập nhật ma trận)
* **Nguồn kích hoạt:**
  - Người dùng quét mã VietQR và thanh toán PayOS thành công $\rightarrow$ Webhook PayOS xác thực chữ ký $\rightarrow$ [payment.service.js:169](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/payment/payment.service.js#L169) `emitToAccount(idaccount, 'account.upgraded', ...)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "type": "Premium",
  "premiumExpiresAt": "2026-11-14T15:00:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. `GoiCubit` chuyển trạng thái sang `GoiState.premium(expiresAt)`.
  2. Lưu hạn Premium vào `FlutterSecureStorage`.
  3. Nếu người dùng đang mở trang Nâng cấp gói: Tự động chuyển sang màn hình **Chúc Mừng Kích Hoạt Thành Công** kèm hiệu ứng Confetti.
  4. Mở khóa toàn bộ hạn mức UI: cho phép tạo không giới hạn ví, ngân sách, hóa đơn, mục tiêu và kích hoạt AI Chatbot.

---

### 3.6. `account.downgraded` — Hạ Cấp Gói Cước Về Basic
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - Tiến trình Scheduler chạy tự động lúc 00:00:00 (Asia/Ho_Chi_Minh) phát hiện tài khoản đã hết hạn Premium $\rightarrow$ [scheduler.service.js:319](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/scheduler.service.js#L319) `emitToAccount(idaccount, 'account.downgraded', ...)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "type": "Basic",
  "message": "Gói Premium đã hết hạn, tài khoản chuyển về gói Basic"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. `GoiCubit` chuyển trạng thái về `GoiState.basic()`.
  2. Xóa mốc `premium_expires_at` khỏi bộ nhớ bảo mật.
  3. Hiển thị Dialog thông báo: *"Gói Premium của bạn đã hết hạn sử dụng. Tài khoản đã được chuyển về gói Tiêu chuẩn (Basic)."* kèm nút "Gia hạn ngay".
  4. **Quy tắc bảo vệ dữ liệu cũ:** Tuyệt đối không xóa các ví/ngân sách/mục tiêu người dùng đã tạo vượt hạn mức trước đây. Chỉ chặn không cho tạo mới thêm khi đã $\ge 3$.

---

### 3.7. `account.countdown` — Đếm Ngược Thời Gian Chờ Xóa Tài Khoản
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - Người dùng gửi yêu cầu xóa tài khoản (trạng thái `PendingDelete`, thời gian ân hạn 30 ngày).
  - Tiến trình Scheduler chạy tự động lúc 00:00:00 (Asia/Ho_Chi_Minh) giảm countdown mỗi ngày $\rightarrow$ [scheduler.service.js:184](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/scheduler.service.js#L184).
* **Cấu trúc Payload chuẩn:**
```json
{
  "idaccount": 50,
  "username": "nguyenvan_a",
  "daysRemaining": 25,
  "title": "Cảnh báo ngừng hoạt động tài khoản",
  "message": "Tài khoản của bạn đang trong thời gian chờ xóa. Còn 25 ngày trước khi tài khoản bị xóa vĩnh viễn."
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Cập nhật số ngày `daysRemaining` hiển thị trên Thẻ Cảnh Báo Trang Chủ và mục "Vùng nguy hiểm" trong Cài Đặt.
  2. Giữ nút "Hủy yêu cầu xóa tài khoản" để người dùng có thể khôi phục lại bất kỳ lúc nào khi `daysRemaining > 0`.

---

### 3.8. `sync.completed` — Hoàn Tất Xử Lý Đồng Bộ Hai Chiều
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - Backend nhận và ghi xong một lô `POST /api/sync/push` từ một thiết bị bất kỳ $\rightarrow$ [sync.service.js:242](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/sync/sync.service.js#L242).
* **Cấu trúc Payload chuẩn:**
```json
{
  "summary": {
    "created": 1,
    "updated": 2,
    "deleted": 0
  },
  "timestamp": "2026-10-14T08:30:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. **Tuyệt đối im lặng (Silent Event):** KHÔNG hiện Toast thông báo vì thiết bị vừa đẩy dữ liệu cũng nhận lại sự kiện này.
  2. Đánh thức `syncEngine.syncNow()` trên các thiết bị khác cùng tài khoản để kích hoạt Delta Pull (`GET /api/sync/pull?since=...`), kéo bản ghi mới về SQLite cục bộ ngay tức khắc.

---

### 3.9. `ocr.completed` — Xử Lý Bóc Tách Hóa Đơn Hoàn Tất
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - AI OCR Worker xử lý xong hình ảnh hóa đơn từ hàng đợi ngầm $\rightarrow$ [ocr.service.js:133](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/ai/features/ocr/ocr.service.js#L133).
* **Cấu trúc Payload chuẩn:**
```json
{
  "title": "Hóa đơn đã được bóc tách thành công",
  "message": "Hóa đơn Circle K (45.000đ) đã được bóc tách và phân loại.",
  "type": "OcrCompleted",
  "createdAt": "2026-10-14T08:35:00.000Z",
  "data": {
    "merchant_name": "Circle K",
    "total_amount": 45000,
    "detected_type": "Receipt",
    "predicted_category_id": "uuid-category",
    "confidence": 0.96
  }
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Hiển thị Toast thông báo: *"Đã bóc tách xong hóa đơn Circle K (45.000đ)"*.
  2. Kích hoạt kéo giao dịch / dữ liệu hóa đơn về màn hình Sổ Giao Dịch hoặc màn hình Xác Nhận Giao Dịch Chờ.

---

### 3.10. `ocr.duplicate` — Hóa Đơn Bị Trùng Lặp
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - AI Deduplication Engine phát hiện ảnh hóa đơn vừa gửi đã tồn tại trong CSDL $\rightarrow$ [ocr.service.js:95](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/ai/features/ocr/ocr.service.js#L95).
* **Cấu trúc Payload chuẩn:**
```json
{
  "title": "Giao dịch đã tồn tại",
  "message": "Hình ảnh này trùng khớp với giao dịch đã được ghi nhận trên hệ thống trước đó.",
  "type": "OcrDuplicate",
  "createdAt": "2026-10-14T08:36:00.000Z",
  "data": {
    "reason": "DUPLICATE_RECEIPT_HASH"
  }
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Hiển thị Toast cảnh báo: *"Hóa đơn này đã được ghi nhận trước đó"*.
  2. **Không kích hoạt đồng bộ kéo:** Vì không có dữ liệu mới nào được tạo trên server.

---

### 3.11. `user.notification` — Tin Nhắn Thông Báo Trực Tiếp
* **Kênh phát:** `account_<idaccount>`
* **Nguồn kích hoạt:**
  - Backend phát thông báo cá nhân hóa qua `notificationService.sendDirectNotification(idaccount, ...)`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "id": "uuid-notif",
  "title": "Nhắc nhở hóa đơn tiền điện",
  "message": "Hóa đơn tiền điện kỳ tháng 10 của bạn sắp đến hạn thanh toán vào ngày mai.",
  "type": "BillReminder",
  "createdAt": "2026-10-14T08:40:00.000Z",
  "metadata": {
    "idbill": "uuid-bill",
    "amount": 350000
  }
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Hiển thị thông báo In-app Notification.
  2. Tăng số đếm Badge chuông thông báo trên Header giao diện di động.
  3. Lưu vào danh sách thông báo để người dùng xem lại.

---

## 4. PHẦN II: ĐẶC TẢ 8 TÍN HIỆU CHỐT CHẶN HTTP/API (MIDDLEWARE & ERROR SIGNALS)

Khi Client-app gửi request qua Dio HTTP Client, Backend có thể trả về các mã phản hồi đặc biệt. Client-app **bắt buộc phải bóc tách tại Interceptor**:

### 4.1. HTTP 503 `MAINTENANCE_MODE` — Hệ Thống Đang Bảo Trì Khẩn Cấp
* **Middleware kích hoạt:** [maintenance.middleware.js:39-47](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/maintenance.middleware.js#L39-L47)
* **Response Header:** `Retry-After: 60`
* **Response Body (JSON):**
```json
{
  "success": false,
  "statusCode": 503,
  "code": "MAINTENANCE_MODE",
  "message": "Hệ thống đang bảo trì để nâng cấp định kỳ. Quý khách vui lòng quay lại sau ít phút!",
  "isEmergency": true,
  "activatedAt": "2026-10-14T08:00:00.000Z",
  "timestamp": "2026-10-14T08:05:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - **Chặn đứng mọi retry tự động:** Không được tự ý retry liên tục.
  - Hiển thị Màn hình Bảo Trì Toàn Cục (`MaintenanceScreen`) kèm lý do `message`.
  - Có đồng hồ đếm ngược tối thiểu 60 giây (theo header `Retry-After`) trước khi cho phép người dùng bấm nút "Thử lại".

---

### 4.2. HTTP 503 `SERVER_OVERLOADED` — Cơ Chế Cắt Tải Tự Động (Load Shedding)
* **Middleware kích hoạt:** [load-shedding.middleware.js:75-82](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/load-shedding.middleware.js#L75-L82)
* **Điều kiện:** Event Loop Lag của Backend vượt ngưỡng $100\text{ms}$.
* **Response Header:** `Retry-After: 5`
* **Response Body (JSON):**
```json
{
  "success": false,
  "statusCode": 503,
  "code": "SERVER_OVERLOADED",
  "message": "Hệ thống đang xử lý lượng truy cập lớn. Vui lòng thử lại sau ít giây!",
  "retryAfter": 5,
  "timestamp": "2026-10-14T08:05:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Đọc trường `retryAfter` (hoặc header `Retry-After`, mặc định 5s).
  - Tạm dừng gửi request lên server trong ít nhất 5 giây (Exponential Backoff).
  - Không đăng xuất người dùng; hiển thị snackbar/toast: *"Máy chủ đang bận xử lý, vui lòng chờ trong giây lát..."*.

---

### 4.3. HTTP 429 `RETRY_LIMIT_EXCEEDED` — Ngăn Chặn Bão Request (Retry Storm Guard)
* **Middleware kích hoạt:** [retry-guard.middleware.js:54-61](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/retry-guard.middleware.js#L54-L61)
* **Điều kiện:** Client gửi cùng 1 request thử lại $> 3$ lần trong cửa sổ 10 giây.
* **Response Body (JSON):**
```json
{
  "success": false,
  "statusCode": 429,
  "code": "RETRY_LIMIT_EXCEEDED",
  "message": "Phát hiện vòng lặp yêu cầu thử lại liên tục. Vui lòng dừng lại và thử lại sau ít phút!",
  "backoffSeconds": 10,
  "timestamp": "2026-10-14T08:05:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Đóng băng hàng đợi thử lại (`SyncQueue.freeze(10)`) trong `backoffSeconds` giây.
  - Reset lại bộ đếm retry `x-retry-count` về 0.

---

### 4.4. HTTP 403 `AIOPS_QUARANTINED` — Tường Lửa Sentinel Phong Tỏa IP Thiết Bị
* **Middleware kích hoạt:** [aiops.quarantine.js:1097-1105](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/aiops/aiops.quarantine.js#L1097-L1105)
* **Điều kiện:** IP thiết bị có hành vi tấn công, quét lỗ hổng hoặc brute-force bị AIOps Sentinel tự động cách ly hoặc Admin cách ly thủ công.
* **Response Body (JSON):**
```json
{
  "success": false,
  "code": "AIOPS_QUARANTINED",
  "error": "AIOPS_QUARANTINED",
  "message": "Kết nối từ thiết bị của bạn tạm thời bị phong tỏa do hệ thống phát hiện hành vi bất thường hoặc dấu hiệu tấn công an ninh.",
  "reason": "Phát hiện dấu hiệu dò quét tài nguyên bất thường",
  "quarantineExpiresAt": "2026-10-14T09:00:00.000Z",
  "timestamp": "2026-10-14T08:05:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Hiển thị Dialog Cảnh Báo An Ninh: Thông báo kết nối từ mạng/thiết bị bị phong tỏa tạm thời kèm thời gian dự kiến mở khóa (`quarantineExpiresAt`).
  - Hướng dẫn người dùng chuyển đổi mạng (ví dụ từ Wi-Fi sang 4G/5G) hoặc chờ bộ quét tự động mở khóa sau khi hết hạn.

---

### 4.5. HTTP 403 `FEATURE_DISABLED` — Chặn Tính Năng Gói Basic
* **Middleware kích hoạt:** [feature-permission.middleware.js:47-55](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/feature-permission.middleware.js#L47-L55)
* **Điều kiện:** Tài khoản gói `Basic` cố gắng gọi các API tính năng nâng cao (Chatbot AI `/chat`, Quét hóa đơn `/ocr/parse`, Sức khỏe tài chính `/financial-health`...).
* **Response Body (JSON):**
```json
{
  "success": false,
  "statusCode": 403,
  "message": "Tính năng này chưa được kích hoạt cho loại tài khoản Basic. Vui lòng nâng cấp gói để tiếp tục sử dụng!",
  "data": {
    "code": "FEATURE_DISABLED",
    "featureId": "ai_assistant",
    "accountType": "Basic"
  }
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Không báo lỗi crash app hay lỗi mạng chung chung.
  - Bật BottomSheet / Modal **"Nâng Cấp Gói Premium"** giới thiệu giá trị của tính năng bị khóa kèm nút "Xem Bảng Giá & Nâng Cấp".

---

### 4.6. HTTP 401 `ACCOUNT_INACTIVE` — Tài Khoản Bị Vô Hiệu Hóa Bởi Admin
* **Vị trí kích hoạt:** [middleware/auth.js:64-76](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/auth.js#L64-L76)
* **Response Body (JSON):**
```json
{
  "success": false,
  "message": "Tài khoản đã bị vô hiệu hóa. Lý do: Sử dụng nhiều tài khoản trục lợi khuyến mãi",
  "code": "ACCOUNT_INACTIVE",
  "idaccount": 50,
  "reason_inactive": "Sử dụng nhiều tài khoản trục lợi khuyến mãi"
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Bắt tại `AuthInterceptor.onError`.
  - **Không gọi `/auth/refresh`:** Vì Refresh Token đã bị hủy trên server, gọi lại sẽ vấp Token Reuse Detection.
  - Xóa token đăng nhập, giữ nguyên CSDL SQLite.
  - Hiển thị Dialog thông báo lý do cụ thể và đưa về màn hình Đăng nhập.

---

### 4.7. HTTP 401 `ACCOUNT_DELETED` — Tài Khoản Đã Bị Xóa Mềm
* **Vị trí kích hoạt:** [middleware/auth.js:70-76](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/auth.js#L70-L76)
* **Response Body (JSON):**
```json
{
  "success": false,
  "message": "Account no longer exists or has been deleted",
  "code": "ACCOUNT_DELETED",
  "idaccount": 50
}
```
* **Xử lý bắt buộc trên Client-app (Dio Interceptor):**
  - Xóa sạch token đăng nhập.
  - Xóa trắng toàn bộ dữ liệu SQLite của tài khoản trên máy (`purgeAccountData`) để tuân thủ quyền được lãng quên (Right to be Forgotten).
  - Hiển thị Dialog thông báo tài khoản đã xóa và đưa về màn hình Đăng nhập.

---

### 4.8. Socket Handshake Error — Kết Nối Socket Thất Bại Lúc Khởi Động
* **Vị trí kích hoạt:** [core/socket.js:45-50](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/socket.js#L45-L50)
* **Cơ chế:** Khi mở app, Client-app kết nối Socket.IO kèm token. Nếu tài khoản đã bị khóa hoặc xóa trước đó:
* **Error Object trả về qua `connect_error`:**
```javascript
err.message = "Authentication error: Tài khoản đã bị vô hiệu hóa. Lý do: ..."
err.data = {
  "code": "ACCOUNT_INACTIVE", // hoặc "ACCOUNT_DELETED"
  "idaccount": 50,
  "reason_inactive": "..."
}
```
* **Xử lý bắt buộc trên Client-app:**
  - Bắt trong hàm `onConnectError` tại [realtime_channel.dart](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/realtime/realtime_channel.dart#L178-L182).
  - Ngừng ngay bộ định thời tự động nối lại `_henNoiLai?.cancel()`.
  - Kích hoạt sự kiện cưỡng chế đăng xuất tức thì ngay lúc khởi động app.

---

## 5. PHẦN III: MA TRẬN ĐỐI CHIẾU HIỆN TRẠNG PHÍA CLIENT-APP

| Hạng mục | Tên Sự Kiện / Tín Hiệu | Trạng Thái Client-App | Vị Trí Code Hiện Tại | Đánh Giá & Hành Động Cần Làm |
|---|---|:---:|---|---|
| **Socket** | `ocr.completed` | ✅ Đã xử lý | `realtime_event.dart:54` | Đã ánh xạ `RealtimeEvent.ocrXong`, hiện Toast. |
| **Socket** | `ocr.duplicate` | ✅ Đã xử lý | `realtime_event.dart:56` | Đã ánh xạ `RealtimeEvent.ocrTrung`, hiện cảnh báo. |
| **Socket** | `sync.completed` | ✅ Đã xử lý | `realtime_event.dart:58` | Đã ánh xạ `RealtimeEvent.dongBoXong`, kéo Delta Pull im lặng. |
| **Socket** | `account.upgraded` | ✅ Đã xử lý | `realtime_event.dart:60` | Đã ánh xạ `RealtimeEvent.taiKhoanNangCap`, gọi subscription-info. |
| **Socket** | `account.permissions_updated` | ✅ Đã xử lý | `realtime_event.dart:61` | Đã ánh xạ `RealtimeEvent.taiKhoanNangCap`, làm mới quyền hạn. |
| **Socket** | `account.force_logout` | ✅ Đã xử lý | `realtime_channel.dart:213` | Đã bắt luồng riêng `buocDangXuat`, hiện Dialog và xóa token. |
| **Socket** | `system.maintenance_changed` | ❌ **BỎ SÓT** | `realtime_channel.dart:235` | **Bị vứt bỏ là "sự kiện lạ"**. Cần bổ sung xử lý mở Màn hình Bảo trì. |
| **Socket** | `system.broadcast` | ❌ **BỎ SÓT** | `realtime_channel.dart:235` | **Bị vứt bỏ là "sự kiện lạ"**. Cần bổ sung In-App Banner toàn cục. |
| **Socket** | `account.downgraded` | ❌ **BỎ SÓT** | `realtime_channel.dart:235` | **Bị vứt bỏ là "sự kiện lạ"**. Cần chuyển `GoiCubit` về Basic. |
| **Socket** | `account.countdown` | ❌ **BỎ SÓT** | `realtime_channel.dart:235` | **Bị vứt bỏ là "sự kiện lạ"**. Cần cập nhật số ngày đếm ngược. |
| **Socket** | `user.notification` | ❌ **BỎ SÓT** | `realtime_channel.dart:235` | **Bị vứt bỏ là "sự kiện lạ"**. Cần lưu vào danh sách thông báo. |
| **HTTP** | 401 `ACCOUNT_INACTIVE` | ✅ Đã xử lý | `auth_interceptor.dart:103` | Bắt tại `tuBody401`, phát `taiKhoanBiTuChoi`. |
| **HTTP** | 401 `ACCOUNT_DELETED` | ✅ Đã xử lý | `auth_interceptor.dart:103` | Bắt tại `tuBody401`, phát `taiKhoanBiTuChoi`. |
| **HTTP** | 503 `MAINTENANCE_MODE` | ❌ **BỎ SÓT** | `auth_interceptor.dart:91` | Đang bỏ qua (`!= 401`), ném `DioException` gây lỗi mạng chung chung. |
| **HTTP** | 503 `SERVER_OVERLOADED` | ❌ **BỎ SÓT** | `auth_interceptor.dart:91` | Chưa đọc `Retry-After: 5`, có nguy cơ spam retry làm lag server. |
| **HTTP** | 429 `RETRY_LIMIT_EXCEEDED` | ❌ **BỎ SÓT** | `auth_interceptor.dart:91` | Chưa đọc `backoffSeconds: 10`, chưa đóng băng SyncQueue. |
| **HTTP** | 403 `AIOPS_QUARANTINED` | ❌ **BỎ SÓT** | `auth_interceptor.dart:91` | Chưa hiển thị Popup cảnh báo an ninh và đếm ngược mở khóa. |
| **HTTP** | 403 `FEATURE_DISABLED` | ❌ **BỎ SÓT** | `auth_interceptor.dart:91` | Chưa hiển thị BottomSheet mời nâng cấp gói Premium. |
| **Handshake**| Socket Connect Error | ❌ **BỎ SÓT** | `realtime_channel.dart:178` | Chỉ in log `debugPrint`, không kiểm tra `err.data` để đăng xuất sớm. |

---

## 6. PHẦN IV: CHECKLIST & HƯỚNG DẪN THỰC THI CHO DEV CLIENT-APP

Để hoàn thiện 100% việc tiếp nhận thông báo và xử lý sự kiện, thành viên phụ trách Client-app cần thực hiện 4 bước sau:

### Bước 1: Mở Rộng `realtime_event.dart`
Bổ sung các enum mới và ánh xạ trong `realtimeEventFromName`:
```dart
enum RealtimeEvent {
  ocrXong,
  ocrTrung,
  dongBoXong,
  taiKhoanNangCap,
  baoTriThayDoi,     // system.maintenance_changed (MỚI)
  thongBaoHeThong,    // system.broadcast (MỚI)
  taiKhoanHaCap,     // account.downgraded (MỚI)
  demNguocXoa,       // account.countdown (MỚI)
  thongBaoCaNhan,    // user.notification (MỚI)
}
```

### Bước 2: Nâng Cấp `realtime_channel.dart`
Trong hàm `_khiCoSuKien(String ten, dynamic payload)`:
* Với các sự kiện mang payload thông điệp quan trọng như `system.maintenance_changed` và `system.broadcast`, bổ sung một Stream riêng `Stream<ThongBaoHeThong> get thongBaoHeThongStream` để truyền tải dữ liệu `reason`, `isEmergency`, `title`, `message` lên tầng UI.
* Trong `onConnectError`: Kiểm tra nếu lỗi có `code == 'ACCOUNT_INACTIVE'` hoặc `'ACCOUNT_DELETED'` thì gọi `_buocDangXuatController.add(...)` ngay lúc khởi động.

### Bước 3: Nâng Cấp `auth_interceptor.dart` (Bắt Mã 503, 429, 403)
Tại hàm `onError(DioException err, ErrorInterceptorHandler handler)`:
```dart
// 1. Bắt chế độ bảo trì khẩn cấp HTTP 503 MAINTENANCE_MODE
if (err.response?.statusCode == 503 && err.response?.data?['code'] == 'MAINTENANCE_MODE') {
  _phatTinHieuBaoTri(err.response?.data);
  return handler.next(err);
}

// 2. Bắt cắt tải thông minh HTTP 503 SERVER_OVERLOADED
if (err.response?.statusCode == 503 && err.response?.data?['code'] == 'SERVER_OVERLOADED') {
  final waitSec = int.tryParse(err.response?.headers.value('retry-after') ?? '5') ?? 5;
  _apDungBackoff(waitSec);
  return handler.next(err);
}

// 3. Bắt tường lửa phong tỏa HTTP 403 AIOPS_QUARANTINED
if (err.response?.statusCode == 403 && err.response?.data?['code'] == 'AIOPS_QUARANTINED') {
  _phatTinHieuPhongToa(err.response?.data);
  return handler.next(err);
}

// 4. Bắt giới hạn tính năng HTTP 403 FEATURE_DISABLED
if (err.response?.statusCode == 403 && err.response?.data?['data']?['code'] == 'FEATURE_DISABLED') {
  _moModalNangCapPremium(err.response?.data?['data']);
  return handler.next(err);
}
```

### Bước 4: Xây Dựng Màn Hình Bảo Trì Toàn Cục & Dialog Cảnh Báo An Ninh
* **Màn hình Bảo Trì (`MaintenanceScreen`):** Lắng nghe từ `thongBaoHeThongStream` và tín hiệu 503. Tự động hiển thị đè lên toàn bộ app khi `isMaintenanceActive = true`.
* **Dialog Mời Nâng Cấp Premium:** Mở tự động khi nhận mã `FEATURE_DISABLED` giúp người dùng hiểu rõ lý do và kích hoạt mua gói ngay.

---

> 🎯 **KẾT LUẬN & BÀN GIAO:**  
> Tài liệu này là cơ sở kỹ thuật chính thức đã được đối soát 100% với mã nguồn Backend và Admin-web đang chạy thực tế. Thành viên phát triển Client-app có thể bám sát tài liệu này để triển khai hoàn thiện việc đồng bộ và phản ứng sự kiện cho ứng dụng di động.
