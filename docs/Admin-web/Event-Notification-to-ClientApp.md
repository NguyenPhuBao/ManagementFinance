# 📡 HỢP ĐỒNG GIAO TIẾP SỰ KIỆN & THÔNG BÁO TỪ ADMIN-WEB VÀ BACKEND TỚI CLIENT-APP
### (Event & Notification Communication Contract: Admin-Web & Backend ➔ Client-App)

> **Tài liệu nguồn sự thật (Source of Truth)** đặc tả toàn bộ các sự kiện thời gian thực (Socket.IO), thông báo hệ thống, tín hiệu điều hướng và lỗi chốt chặn HTTP/API phát sinh từ **Admin-web** và **Backend** có tác động hoặc yêu cầu xử lý từ phía **Client-app (Mobile App Flutter)**.  
> 
> * **Ngày cập nhật:** 24/10/2026  
> * **Phiên bản:** `v4.0` (Đồng bộ toàn diện sau đợt chuẩn hóa CSDL, Bảo trì 2 loại hình & AIOps Sentinel chuẩn PO)  
> * **Trạng thái:** 🟢 PO ĐÃ PHÊ DUYỆT ĐỊNH HƯỚNG & YÊU CẦU THỰC THI (Official Approved Specification)  
> * **Phạm vi đối chiếu mã nguồn thực tế:**
>   * `src/Backend/core/socket.js` (Hạ tầng WebSocket Socket.IO v4)
>   * `src/Backend/core/event-bus.js` & `src/Backend/core/scheduler.service.js` (Hạ tầng Event Bus & Tác vụ định kỳ)
>   * `src/Backend/modules/notification/notification.service.js` (Hệ thống thông báo đa kênh & Broadcast persistence)
>   * `src/Backend/modules/payment/payment.service.js` (Luồng thanh toán PayOS, hoàn tiền, hủy đơn, lệch tiền)
>   * `src/Backend/modules/admin/admin.service.js` (Nghiệp vụ quản trị Admin)
>   * `src/Backend/core/resilience/maintenance.manager.js` (Điều hành bảo trì chỉ 2 loại: Khẩn cấp & Định kỳ đặt trước 3h, cách 12h)
>   * `src/Backend/middleware/` (`auth.js`, `maintenance.middleware.js`, `load-shedding.middleware.js`, `retry-guard.middleware.js`, `feature-permission.middleware.js`, `audit-log.middleware.js`)
>   * `src/Backend/modules/aiops/aiops.quarantine.js` (Tường lửa Sentinel & Ma trận phong tỏa)
>   * `src/Client-app/lib/core/realtime/` (`realtime_event.dart`, `realtime_channel.dart`, `realtime_socket.dart`)
>   * `src/Client-app/lib/core/api/interceptors/` (`auth_interceptor.dart`, `buoc_dang_xuat.dart`)

---

## 📌 MỤC LỤC
1. [Nguyên Tắc Thiết Kế & Kiến Trúc Giao Tiếp](#1-nguyên-tắc-thiết-kế--kiến-trúc-giao-tiếp)
2. [Đặc Tả Thu Thập Thông Tin Thiết Bị & IP Người Dùng](#2-đặc-tả-thu-thập-thông-tin-thiết-bị--ip-người-dùng)
3. [Bảng Tổng Hợp Toàn Bộ Các Sự Kiện & Tín Hiệu](#3-bảng-tổng-hợp-toàn-bộ-các-sự-kiện--tín-hiệu)
4. [Phần I: Đặc Tả Chi Tiết Toàn Bộ Sự Kiện Kênh Thời Gian Thực Cho Client-App](#4-phần-i-đặc-tả-chi-tiết-toàn-bộ-sự-kiện-kênh-thời-gian-thực-cho-client-app)
5. [Phần II: Đặc Tả Chi Tiết 9 Tín Hiệu Chốt Chặn HTTP/API & Socket Handshake](#5-phần-ii-đặc-tả-chi-tiết-9-tín-hiệu-chốt-chặn-httpapi--socket-handshake)
6. [Phần III: Phân Định Các Sự Kiện Dành Riêng Cho Quản Trị Viên (Admin-Web Only)](#6-phần-iii-phân-định-các-sự-kiện-dành-riêng-cho-quản-trị-viên-admin-web-only)
7. [Phần IV: Ma Trận Đối Chiếu Hiện Trạng Phía Client-App](#7-phần-iv-ma-trận-đối-chiếu-hiện-trạng-phía-client-app)
8. [Phần V: Checklist & Hướng Dẫn Thực Thi Cho Dev Client-App (Flutter)](#8-phần-v-checklist--hướng-dẫn-thực-thi-cho-dev-client-app-flutter)

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
* **Bảo Vệ Dữ Liệu Riêng Tư (Data Security & Nghị định 13/2023/NĐ-CP):** 
  - Socket events gửi tới người dùng **tuyệt đối không truyền số tài khoản ngân hàng đầy đủ, mật khẩu, mã OTP, số dư thô** (theo `Data_Security.md`).
  - Sự kiện cưỡng chế xóa tài khoản (`ACCOUNT_DELETED`): Client-app đăng xuất và hiển thị hộp thoại thông báo lý do, bảo lưu SQLite trên máy (tránh mất dữ liệu chưa đồng bộ; dọn dẹp khi tài khoản khác đăng nhập).
* **Phân Biệt "Đánh Thức Đồng Bộ" và "Sự Kiện Thông Điệp":**
  - Không phải sự kiện nào cũng kích hoạt `syncNow()`. Các sự kiện như nâng cấp gói, cảnh báo bảo trì, thông báo broadcast chỉ cập nhật UI / Local Storage, không ép chạy full-sync tránh nghẽn mạng và tốn pin thiết bị.

---

## 2. ĐẶC TẢ THU THẬP THÔNG TIN THIẾT BỊ & IP NGƯỜI DÙNG

Đã được lập thành văn bản nguồn sự thật riêng biệt tại:  
👉 **`docs/Admin-web/IP-Device-ClientApp.md`**

### Tóm Lược Quy Tắc Bắt Buộc:
1. **Header HTTP bắt buộc:** `x-device-name` (ví dụ: `"Samsung Galaxy S24 Ultra (Android 14)"`, tối đa 150 ký tự). Gửi trong mọi request qua Dio Interceptor.
2. **Không tự gọi API bên thứ ba để lấy IP:** Backend tự động trích xuất IP mạng qua TCP socket và mặt nạ hóa (`maskIp`: `113.161.xx.xx`) theo Nghị định 13/2023/NĐ-CP.
3. **Cơ chế Diff Check CSDL:** Cùng IP và Device $\longrightarrow$ UPDATE `last_active_at`; Đổi IP hoặc Device $\longrightarrow$ INSERT dòng mới vào `account_device_history`, bảo toàn 100% lịch sử truy vết.

---

## 3. BẢNG TỔNG HỢP TOÀN BỘ CÁC SỰ KIỆN & TÍN HIỆU

### 3.1. Nhóm 1: Sự Kiện Thời Gian Thực Gửi Tới Client-App (Socket.IO — 18 Sự Kiện)

| STT | Tên Sự Kiện | Kênh / Room | Nguồn Kích Hoạt | Mục Đích Nghiệp Vụ | Mức Độ Ưu Tiên |
|:---:|---|:---:|---|---|:---:|
| **1** | `account.force_logout` / `force_logout` | `account_<id>` | Admin Khóa / Xóa tài khoản | Cưỡng chế đăng xuất tức thì, xóa session | 🚨 Khẩn cấp |
| **2** | `system.maintenance_changed` | Toàn hệ thống (`io.emit`) | Admin Bật/Tắt bảo trì (Khẩn cấp / Định kỳ) | Mở/đóng Màn hình Bảo trì toàn cục | 🚨 Khẩn cấp |
| **3** | `system.broadcast` | Toàn hệ thống (`io.emit`) | Admin Phát thông báo hệ thống | In-App Banner, lưu SQLite notification | ⚠️ Cao |
| **4** | `account.permissions_updated` | Toàn hệ thống (`io.emit`) | Admin Lưu ma trận phân quyền | Cập nhật 4 Trụ cột quyền hạn (`GoiCubit`) | ℹ️ Tiêu chuẩn |
| **5** | `account.upgraded` | `account_<id>` & `io.emit` | PayOS Webhook / Admin duyệt gói | Nâng cấp tài khoản lên Premium | ℹ️ Tiêu chuẩn |
| **6** | `account.downgraded` | `account_<id>` | Cron 00:00 hạ cấp hết hạn Premium | Chuyển tài khoản về gói Basic | ⚠️ Cao |
| **7** | `account.countdown` | `account_<id>` | Cron 00:00 đếm ngược xóa 30 ngày | Thông báo số ngày còn lại trước khi xóa | ℹ️ Tiêu chuẩn |
| **8** | `sync.completed` | `account_<id>` | Push thành công từ thiết bị khác | Đánh thức thiết bị kéo Delta Pull về | 🔇 Im lặng |
| **9** | `ocr.completed` | `account_<id>` | Worker hoàn tất bóc tách OCR | Thông báo bóc tách xong, kích hoạt sync | ℹ️ Tiêu chuẩn |
| **10** | `ocr.duplicate` | `account_<id>` | AI phát hiện hóa đơn trùng lặp | Cảnh báo hóa đơn đã tồn tại | ⚠️ Cảnh báo |
| **11** | `user.notification` | `account_<id>` | Hệ thống gửi tin nhắn riêng | Lưu hộp thư cá nhân trên điện thoại | ℹ️ Tiêu chuẩn |
| **12** | `payment.success` | `account_<id>` | Webhook PayOS xác nhận thanh toán | Cập nhật màn hình Chờ/Chi tiết đơn hàng | ℹ️ Tiêu chuẩn |
| **13** | `payment.order_cancelled` | `account_<id>` | Người dùng / Hệ thống hủy đơn | Cập nhật trạng thái đơn thành CANCELLED | ℹ️ Tiêu chuẩn |
| **14** | `payment.order_expired` | `account_<id>` | Worker 30s quét hủy đơn quá 10 phút | Đóng popup VietQR, báo hết hạn mã | ℹ️ Tiêu chuẩn |
| **15** | `payment.refunded` | `account_<id>` | Admin duyệt hoàn tiền kèm minh chứng | Thông báo hoàn tiền + link xem ảnh biên lai | ℹ️ Tiêu chuẩn |
| **16** | `payment.overpaid_confirmation` | `account_<id>` | Webhook PayOS thừa tiền đơn hàng | Cảnh báo chuyển thừa, mở hỗ trợ CSKH | ⚠️ Cao |
| **17** | `payment.underpaid_warning` | `account_<id>` | Webhook PayOS thiếu tiền đơn hàng | Cảnh báo chuyển thiếu, hướng dẫn nộp bù | ⚠️ Cảnh báo |
| **18** | `bank_transaction.incoming` | `account_<id>` | Webhook biến động ngân hàng (Legacy) | Thông báo giao dịch (đã dừng module Bank) | 🔇 Legacy |

---

### 3.2. Nhóm 2: Tín Hiệu Chốt Chặn HTTP/API & Socket Handshake (9 Tín Hiệu)

| STT | Mã HTTP / Tín Hiệu | Cơ Chế Kích Hoạt | Ý Nghĩa Nghiệp Vụ | Phản Ứng Bắt Buộc Của Client-App |
|:---:|---|---|---|---|
| **1** | HTTP 503 `MAINTENANCE_MODE` | Middleware `maintenance.middleware.js` | Hệ thống đang bật bảo trì | Mở Màn hình Bảo Trì (`MaintenanceScreen`) |
| **2** | HTTP 503 `SERVER_OVERLOADED` | Middleware `load-shedding.middleware.js` | Cắt tải CPU khi Event Loop lag > 100ms | Đọc header `Retry-After`, đếm ngược thử lại |
| **3** | HTTP 429 `RETRY_LIMIT_EXCEEDED` | Middleware `retry-guard.middleware.js` | Chống bão request lặp (> 3 retries) | Dừng retry ngay lập tức, exponential backoff |
| **4** | HTTP 403 `AIOPS_QUARANTINED` | Tường lửa Sentinel `aiops.quarantine.js` | IP bị phong tỏa an ninh | Hiển thị Dialog phong tỏa + đếm ngược mở khóa |
| **5** | HTTP 403 `FEATURE_DISABLED` | Middleware `feature-permission.middleware.js` | Tính năng vượt quá gói cước Basic | Hiển thị BottomSheet mời nâng cấp Premium |
| **6** | HTTP 401 `ACCOUNT_INACTIVE` | Middleware `auth.js` | Admin khóa tài khoản kèm lý do | Hiển thị Dialog lý do, điều hướng về Login |
| **7** | HTTP 401 `ACCOUNT_DELETED` | Middleware `auth.js` | Tài khoản đã bị xóa mềm | Đăng xuất + hiển thị Dialog lý do, bảo lưu SQLite |
| **8** | WebSocket Handshake Error | `io.use` trong `core/socket.js` | Bắt tay thất bại (Token lỗi/hết hạn/khóa) | Ngắt kết nối socket, làm mới JWT token |

---

## 4. PHẦN I: ĐẶC TẢ CHI TIẾT TOÀN BỘ SỰ KIỆN KÊNH THỜI GIAN THỰC CHO CLIENT-APP

### 4.1. `account.force_logout` / `force_logout` — Cưỡng Chế Đăng Xuất Tức Thì
* **Kênh phát:** `account_<idaccount>` và Direct Socket ID.
* **Nguồn kích hoạt:**
  - Admin bấm **Khóa tài khoản** (`status: 'Inactive'`, kèm lý do) trên `UserListPage.jsx`.
  - Admin bấm **Xóa mềm người dùng** 5 bước ACID trên `UserListPage.jsx`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "idaccount": 50,
  "reason": "ACCOUNT_INACTIVE",
  "message": "Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Phát hiện đăng nhập bất thường từ thiết bị lạ."
}
```
*(Nếu bị xóa: `"reason": "ACCOUNT_DELETED"`, `"message": "Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên."`)*
* **Xử lý bắt buộc trên Client-app:**
  1. Xóa sạch `accessToken` và `refreshToken` khỏi `FlutterSecureStorage`.
  2. Nếu `reason == 'ACCOUNT_DELETED'`: Đăng xuất và hiển thị Popup Dialog lý do, bảo lưu SQLite trên máy.
  3. Nếu `reason == 'ACCOUNT_INACTIVE'`: Giữ nguyên dữ liệu SQLite.
  4. Mở Popup Dialog hiển thị đúng nội dung `message`. Bấm "Đồng ý" chuyển về màn hình `LoginPage`.

---

### 4.2. `system.maintenance_changed` — Thay Đổi Trạng Thái Bảo Trì Hệ Thống (Chỉ 2 Loại Hình)
> ⚠️ **QUY TẮC BẢO TRÌ ĐÃ ĐƯỢC PO DUYỆT CHỐT:**
> 1. **Chỉ có đúng 2 loại hình bảo trì:**
>    - **Bảo trì Khẩn cấp (`EMERGENCY`):** Kích hoạt tức thì khi có sự cố nghiêm trọng.
>    - **Bảo trì Định kỳ (`SCHEDULED`):** Phải đặt lịch **trước ít nhất 3 tiếng** so với thời điểm bắt đầu. Các lịch bảo trì phải **cách nhau ít nhất 12 tiếng**. Hủy lịch phải thực hiện **trước ít nhất 3 tiếng**.
> 2. **Tuyệt đối không có loại `UPGRADE` / `isUpgrade`:** Đã loại bỏ hoàn toàn.
> 3. **Bỏ ghi chú campaign giả.**

* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`).
* **Nguồn kích hoạt:** Admin kích hoạt/tắt bảo trì khẩn cấp hoặc lịch bảo trì định kỳ tự động kích hoạt.
* **Cấu trúc Payload chuẩn:**
```json
// Bảo trì Khẩn cấp:
{
  "active": true,
  "isEmergency": true,
  "type": "EMERGENCY",
  "reason": "Hệ thống đang tiến hành khắc phục sự cố kỹ thuật khẩn cấp. Quý khách vui lòng quay lại sau ít phút!",
  "activatedAt": "2026-10-24T08:00:00.000Z",
  "activatedBy": "admin_system"
}

// Bảo trì Định kỳ:
{
  "active": true,
  "isEmergency": false,
  "type": "SCHEDULED",
  "reason": "Bảo trì định kỳ máy chủ theo lịch trình kỹ thuật.",
  "activatedAt": "2026-10-24T12:00:00.000Z",
  "activatedBy": "admin_system"
}

// Khi kết thúc bảo trì:
{
  "active": false,
  "isEmergency": false,
  "reason": null
}
```

* **Xử lý bắt buộc trên Client-app:**
  1. Khi `active == true`:
     - **Nếu `isEmergency: true` (`EMERGENCY`):** Hiển thị Màn hình Cảnh báo Bảo Trì Khẩn Cấp toàn cục tông màu đỏ, tạm hoãn các thao tác ghi dữ liệu nhạy cảm, tạm dừng toàn bộ luồng background sync. Cho phép người dùng duyệt dữ liệu SQLite cục bộ ở chế độ Read-only.
     - **Nếu `isEmergency: false` (`SCHEDULED`):** Hiển thị Banner màu cam thông báo bảo trì theo lịch, cho phép người dùng xem dữ liệu offline.
  2. Khi `active == false`:
     - Đóng màn hình bảo trì, hiển thị Toast xanh thông báo hệ thống đã sẵn sàng hoạt động bình thường trở lại.
     - Tự động kích hoạt đồng bộ bù `syncNow()`.

---

### 4.3. `system.broadcast` — Thông Báo Toàn Hệ Thống
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`).
* **Nguồn kích hoạt:** Admin phát sóng từ Tab "Phát thông báo" tại `BroadcastPage.jsx`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "id": "e4b52c08-72fa-45cf-81b4-f6b92a40dc78",
  "title": "Thông báo nâng cấp ứng dụng",
  "message": "Hệ thống bổ sung tính năng theo dõi thiết bị an ninh và tối ưu hóa hiệu năng đồng bộ offline.",
  "level": "INFO",
  "isEmergency": false,
  "category": "BROADCAST",
  "createdAt": "2026-10-24T08:15:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Hiển thị In-App Banner hoặc Top SnackBar theo cấp độ `level`:
     - `CRITICAL` hoặc `isEmergency: true`: Banner đỏ cảnh báo khẩn cấp.
     - `WARNING`: Banner vàng cam.
     - `INFO`: SnackBar xanh dương nhẹ, tự đóng sau 4 giây.
  2. Lưu thông báo vào bảng SQLite cục bộ `notification` trên điện thoại.

---

### 4.4. `account.permissions_updated` — Cập Nhật Ma Trận Phân Quyền Tính Năng
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`).
* **Nguồn kích hoạt:** Admin lưu ma trận phân quyền 4 Trụ cột trên `PermissionManagementPage.jsx`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "updates": [
    { "idaccount_type": 1, "idfeature": "ai_assistant", "is_enabled": true, "limit_value": null },
    { "idaccount_type": 1, "idfeature": "wallets", "is_enabled": true, "limit_value": 3 }
  ],
  "timestamp": "2026-10-24T08:20:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Không chạy full sync. Gọi nhẹ API `GET /api/payment/subscription-info` (~300 bytes).
  2. Cập nhật `GoiCubit` và lưu cấu hình quyền mới vào `FlutterSecureStorage`.
  3. Cập nhật giao diện ẩn/hiện hoặc khóa các tính năng theo hạn mức mới.

---

### 4.5. `account.upgraded` & `account.downgraded` — Nâng Cấp & Hạ Cấp Gói Cước
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:**
  - `account.upgraded`: Webhook PayOS xác nhận đã thanh toán đơn Premium thành công, hoặc Admin duyệt gia hạn thủ công.
  - `account.downgraded`: Tác vụ bảo trì 00:00:00 UTC+7 quét phát hiện gói Premium đã hết hạn.
* **Cấu trúc Payload:**
```json
// Nâng cấp:
{
  "type": "Premium",
  "message": "Nâng cấp tài khoản lên gói Premium thành công",
  "expiresAt": "2027-10-24T00:00:00.000Z"
}

// Hạ cấp:
{
  "type": "Basic",
  "message": "Gói Premium đã hết hạn, tài khoản chuyển về gói Basic"
}
```
* **Xử lý trên Client-app:**
  - Gọi lại `GET /api/payment/subscription-info` để nạp hạn mức mới vào `GoiCubit`.
  - Hiển thị Toast thông báo chúc mừng nâng cấp hoặc thông báo hết hạn gói. Không kích hoạt sync dữ liệu tài chính vì bảng nghiệp vụ không thay đổi.

---

### 4.6. `account.countdown` — Đếm Ngược Chờ Xóa Tài Khoản 30 Ngày
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Tác vụ 00:00:00 UTC+7 quét các tài khoản `PendingDelete` và trừ lùi ngày.
* **Cấu trúc Payload:**
```json
{
  "idaccount": 50,
  "username": "nguyenvanan",
  "daysRemaining": 28,
  "title": "Cảnh báo ngừng hoạt động tài khoản",
  "message": "Tài khoản của bạn đang trong thời gian chờ xóa. Còn 28 ngày trước khi tài khoản bị xóa vĩnh viễn."
}
```
* **Xử lý trên Client-app:**
  - Hiển thị Banner cam cảnh báo đếm ngược ở đầu màn hình Trang chủ (`HomeScreen`).
  - Đính kèm nút "Hủy yêu cầu xóa tài khoản" gọi API `POST /api/auth/cancel-delete`.

---

### 4.7. `sync.completed` — Hoàn Tất Đợt Đồng Bộ Từ Thiết Bị Khác
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Backend xử lý xong một batch `/api/sync/push` từ một thiết bị khác (Web hoặc điện thoại khác của cùng tài khoản).
* **Cấu trúc Payload:**
```json
{
  "summary": { "created": 2, "updated": 1, "deleted": 0 },
  "timestamp": "2026-10-24T08:30:00.000Z"
}
```
* **Xử lý trên Client-app:**
  - **Sự kiện im lặng (Silent Event):** KHÔNG hiện Toast làm phiền người dùng.
  - Tự động kích hoạt luồng kéo ngầm `syncEngine.processPull()` để cập nhật dữ liệu mới nhất vào SQLite Drift.

---

### 4.8. `ocr.completed` & `ocr.duplicate` — Kết Quả Bóc Tách Hóa Đơn OCR
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Worker hoàn tất phân tích ảnh hóa đơn hoặc AI phát hiện hóa đơn trùng lặp.
* **Cấu trúc Payload:**
```json
// ocr.completed:
{
  "idaccount": 50,
  "title": "Bóc tách hóa đơn hoàn tất",
  "message": "Hóa đơn siêu thị Co.opmart đã được phân loại vào danh mục Ăn uống.",
  "type": "OcrCompleted",
  "metadata": { "transactionId": "b8a1c9e2-..." }
}

// ocr.duplicate:
{
  "idaccount": 50,
  "title": "Phát hiện hóa đơn trùng lặp",
  "message": "Hóa đơn này có số tiền và thời gian trùng với một giao dịch đã ghi nhận.",
  "type": "OcrDuplicate"
}
```
* **Xử lý trên Client-app:**
  - Với `ocr.completed`: Hiện Toast "Đã bóc tách xong hóa đơn", kích hoạt `syncNow()` để kéo giao dịch mới về.
  - Với `ocr.duplicate`: Hiện Dialog cảnh báo vàng, KHÔNG kích hoạt sync vì không có dữ liệu mới sinh ra.

---

### 4.9. `user.notification` — Thông Báo Riêng Tư Trong Hộp Thư Cá Nhân
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Backend phát thông báo cá nhân (nhắc nhở chi tiêu quá hạn, cảnh báo vượt ngưỡng ngân sách).
* **Cấu trúc Payload:**
```json
{
  "id": "notif-uuid-1234",
  "idaccount": 50,
  "title": "Ngân sách Ăn uống vượt 80%",
  "message": "Bạn đã chi tiêu 4.200.000đ / 5.000.000đ của hạn mức tháng 10.",
  "type": "BudgetWarning",
  "createdAt": "2026-10-24T08:35:00.000Z"
}
```
* **Xử lý trên Client-app:**
  - Lưu vào bảng SQLite `notification` trên thiết bị.
  - Tăng số đếm Badge chưa đọc tại biểu tượng Chuông thông báo (`NotificationBell`).

---

### 4.10. `payment.success` & `payment.order_cancelled` — Thanh Toán Thành Công & Hủy Đơn
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:**
  - `payment.success`: Webhook PayOS xác nhận chuyển khoản khớp chính xác số tiền đơn hàng.
  - `payment.order_cancelled`: Người dùng hủy đơn trên giao diện hoặc đơn bị hủy thủ công.
* **Cấu trúc Payload:**
```json
// payment.success:
{
  "orderCode": 1729671234567,
  "amount": 49000,
  "status": "PAID",
  "message": "Thanh toán đơn hàng thành công"
}

// payment.order_cancelled:
{
  "orderCode": 1729671234567,
  "status": "CANCELLED",
  "message": "Đơn hàng đã bị hủy"
}
```
* **Xử lý trên Client-app:**
  - Đóng popup chờ thanh toán QR Code.
  - Chuyển hướng sang màn hình "Thanh toán thành công" (nếu là `payment.success`) hoặc cập nhật trạng thái đơn trong Lịch sử mua hàng.

---

### 4.11. `payment.order_expired` — Đơn Hàng Thanh Toán Quá Hạn (10 Phút)
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Worker 30s quét và hủy các đơn hàng VietQR chưa thanh toán sau 10 phút.
* **Cấu trúc Payload:**
```json
{
  "orderCode": 1729671234567,
  "message": "Đơn hàng đã hết hạn thanh toán (quá 10 phút). Vui lòng tạo đơn mới."
}
```
* **Xử lý trên Client-app:** Tự động đóng popup mã QR và báo mã đã hết hạn.

---

### 4.12. `payment.refunded` — Thông Báo Hoàn Tiền Thành Công Kèm Minh Chứng
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Admin xử lý duyệt hoàn tiền giao dịch PayOS đính kèm minh chứng.
* **Cấu trúc Payload:**
```json
{
  "orderCode": 1729671234567,
  "refundedAmount": 49000,
  "refundReason": "Giao dịch chuyển khoản trùng lặp theo yêu cầu của khách hàng",
  "refundProof": "https://supabase-storage.../refund_proof_123.jpg",
  "timestamp": "2026-10-24T08:25:00.000Z"
}
```
* **Xử lý trên Client-app:** Hiển thị Dialog thông báo hoàn tiền kèm nút "Xem biên lai chuyển khoản".

---

### 4.13. `payment.overpaid_confirmation` & `payment.underpaid_warning` — Lệch Số Tiền
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Webhook PayOS phát hiện số tiền chuyển khoản không khớp với giá trị đơn.
* **Cấu trúc Payload:**
```json
{
  "orderCode": 1729671234567,
  "expectedAmount": 49000,
  "receivedAmount": 20000,
  "message": "Số tiền nhận được (20.000đ) thấp hơn giá trị đơn hàng (49.000đ). Vui lòng liên hệ hỗ trợ."
}
```
* **Xử lý trên Client-app:** Hiển thị Dialog cảnh báo để người dùng liên hệ Hotline hỗ trợ đối soát.

---

### 4.14. `bank_transaction.incoming` — Biến Động Số Dư Ngân Hàng (Legacy Notice)
* **Kênh phát:** `account_<idaccount>`.
* **Tình trạng:** ⚠️ **LEGACY / SUSPENDED:** Module Bank liên kết SePay đã dừng hoạt động ngày 18/09/2026. Backend vẫn giữ event handler để không vỡ kiến trúc EventBus, nhưng **Client-app bỏ qua sự kiện này** (`realtimeEventFromName` trả về `null`).

---

## 5. PHẦN II: ĐẶC TẢ CHI TIẾT 9 TÍN HIỆU CHỐT CHẶN HTTP/API & SOCKET HANDSHAKE

### 5.1. HTTP 503 `MAINTENANCE_MODE` — Hệ Thống Đang Bảo Trì
* **Phát sinh từ:** `src/Backend/middleware/maintenance.middleware.js`
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 503,
  "code": "MAINTENANCE_MODE",
  "isEmergency": true,
  "message": "Hệ thống đang tiến hành bảo trì máy chủ. Quý khách vui lòng quay lại sau ít phút!"
}
```
* **Xử lý trên Client-app:** Bắt tại Dio Interceptor, kích hoạt Màn hình Bảo Trì toàn phần (`MaintenanceScreen`), không ném ngoại lệ crash ứng dụng.

---

### 5.2. HTTP 503 `SERVER_OVERLOADED` — Cắt Tải CPU Thông Minh (Load Shedding)
* **Phát sinh từ:** `src/Backend/middleware/load-shedding.middleware.js` (Khi Event Loop lag > 100ms).
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 503,
  "code": "SERVER_OVERLOADED",
  "message": "Hệ thống đang chịu tải cao. Vui lòng thử lại sau 5 giây.",
  "retryAfter": 5
}
```
* **Xử lý trên Client-app:** Đọc header `Retry-After: 5`, hiển thị Top Toast cam "Máy chủ đang bận, tự động thử lại sau 5s...", thực hiện exponential backoff.

---

### 5.3. HTTP 429 `RETRY_LIMIT_EXCEEDED` — Chặn Bão Request Lặp (Retry Storm Guard)
* **Phát sinh từ:** `src/Backend/middleware/retry-guard.middleware.js` (Khi Client gửi cùng 1 signature quá 3 lần liên tục).
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 429,
  "code": "RETRY_LIMIT_EXCEEDED",
  "message": "Phát hiện tần suất gửi lại yêu cầu quá dày đặc. Vui lòng dừng thao tác và đợi ít phút."
}
```
* **Xử lý trên Client-app:** Chặn ngay lập tức mọi vòng lặp retry tự động trong Dio Interceptor, thông báo người dùng kiểm tra kết nối mạng.

---

### 5.4. HTTP 403 `AIOPS_QUARANTINED` — Tường Lửa Sentinel Phong Tỏa IP
> ⚠️ **ĐẶC TẢ AIOPS SENTINEL CHUẨN PO:**
> - **Lưu lượng (`traffic`):** Là vector đo tấn công/truy cập từ phía user/client gửi vào hệ thống (gắn liền với `TK:` tài khoản và `IP:` thiết bị).
> - **Xác thực (`auth`) & Khai thác (`exploit`):** Đều phát xuất từ phía user/client.
> - **Chỉ duy nhất Tài nguyên (`resource`):** Mới là vector thuộc riêng về hệ thống máy chủ.

* **Phát sinh từ:** `src/Backend/modules/aiops/aiops.quarantine.js`
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 403,
  "code": "AIOPS_QUARANTINED",
  "message": "Kết nối từ thiết bị của bạn tạm thời bị phong tỏa do phát hiện dấu hiệu bất thường.",
  "reason": "Tấn công DoS quá ngưỡng request lưu lượng",
  "quarantineExpiresAt": "2026-10-24T09:00:00.000Z"
}
```
* **Xử lý trên Client-app:** Hiển thị Dialog cảnh báo an ninh toàn màn hình kèm đồng hồ đếm ngược mở khóa (`quarantineExpiresAt`).

---

### 5.5. HTTP 403 `FEATURE_DISABLED` — Chặn Tính Năng Vượt Gói Cước Basic
* **Phát sinh từ:** `src/Backend/middleware/feature-permission.middleware.js`
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 403,
  "data": {
    "code": "FEATURE_DISABLED",
    "featureId": "ai_assistant",
    "accountType": "Basic"
  },
  "message": "Tính năng này chưa được kích hoạt cho gói Basic. Vui lòng nâng cấp Premium!"
}
```
* **Xử lý trên Client-app:** Mở BottomSheet giới thiệu tính năng kèm nút "Nâng cấp Premium ngay".

---

### 5.6. HTTP 401 `ACCOUNT_INACTIVE` — Tài Khoản Bị Vô Hiệu Hóa Kèm Lý Do
* **Phát sinh từ:** `src/Backend/middleware/auth.js`
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 401,
  "data": {
    "code": "ACCOUNT_INACTIVE",
    "idaccount": 50,
    "reason_inactive": "Phát hiện đăng nhập bất thường từ thiết bị lạ."
  },
  "message": "Tài khoản đã bị vô hiệu hóa. Lý do: Phát hiện đăng nhập bất thường từ thiết bị lạ."
}
```
* **Xử lý trên Client-app:** Giữ nguyên dữ liệu SQLite offline, xóa JWT token và chuyển về màn hình Đăng nhập kèm Dialog lý do.

---

### 5.7. HTTP 401 `ACCOUNT_DELETED` — Tài Khoản Đã Bị Xóa Mềm Khỏi Hệ Thống
* **Phát sinh từ:** `src/Backend/middleware/auth.js`
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 401,
  "data": {
    "code": "ACCOUNT_DELETED",
    "idaccount": 50
  },
  "message": "Account no longer exists or has been deleted"
}
```
* **Xử lý trên Client-app:** Hiển thị Dialog thông báo lý do, bảo lưu SQLite trên máy, xóa JWT token và điều hướng về Login.

---

### 5.8. WebSocket Handshake Rejection — Lỗi Bắt Tay Xác Thực Socket
* **Phát sinh từ:** `io.use` trong `src/Backend/core/socket.js`
* **Cơ chế phản hồi:** Khi Client kết nối socket với token sai, hết hạn hoặc tài khoản bị khóa:
  ```javascript
  next(Object.assign(new Error("Authentication error: Tài khoản đã bị vô hiệu hóa"), {
    data: { code: 'ACCOUNT_INACTIVE', idaccount: 50, reason_inactive: '...' }
  }));
  ```
* **Xử lý trên Client-app:** Lắng nghe sự kiện `socket.on('connect_error')`, đọc `err.data.code` để thực hiện làm mới token hoặc đăng xuất theo đúng nghiệp vụ.

---

## 6. PHẦN III: PHÂN ĐỊNH CÁC SỰ KIỆN DÀNH RIÊNG CHO QUẢN TRỊ VIÊN (ADMIN-WEB ONLY)

> ⚠️ **LƯU Ý DÀNH CHO DEV CLIENT-APP:**  
> Toàn bộ các sự kiện dưới đây được máy chủ phát vào kênh riêng biệt `admin_room`. **Client-app tuyệt đối KHÔNG lắng nghe các sự kiện này** để tránh lãng phí tài nguyên và rò rỉ dữ liệu vận hành nội bộ:

1. `admin.user_registered`: Phát khi có tài khoản người dùng mới tạo thành công.
2. `admin.user_logged_in`: Phát khi có người dùng đăng nhập thành công (phục vụ biểu đồ Active Users).
3. `admin.user_status_changed`: Phát khi trạng thái tài khoản chuyển đổi (`Active`, `Inactive`, `PendingDelete`).
4. `admin.category_updated`: Phát khi Admin tạo/sửa/xóa danh mục mặc định của hệ thống.
5. `admin.maintenance_changed`: Phát riêng cho Admin Dashboard cập nhật giao diện điều hành bảo trì.
6. `admin.metrics_stream`: Luồng nhịp tim thông số phần cứng CPU, RAM, Event Loop lag phát 3 giây/lần.
7. `admin.notification`: Cảnh báo quản trị khẩn cấp (Overload, Security Alert).
8. `admin.security_blocked`: Thông báo tường lửa Sentinel vừa phong tỏa một IP vi phạm.
9. `admin.quarantine_updated`: Báo hiệu danh sách phong tỏa có sự thay đổi.
10. `admin.anomaly_detected`: AI phát hiện dị thường truy cập của người dùng.
11. `payment.order_created`, `payment.status_changed`, `payment.order_paid`, `payment.refund_pending`, `payment.amount_mismatch`: Các biến động đơn hàng phục vụ quản lý doanh thu Admin.
12. `audit_activity`: Nhật ký thao tác quản trị ghi nhận vào Audit Log.

---

## 7. PHẦN IV: MA TRẬN ĐỐI CHIẾU HIỆN TRẠNG PHÍA CLIENT-APP

| Tên Sự Kiện / Tín Hiệu | Hiện Trạng Client-App | Ánh Xạ Trong `realtime_event.dart` | Hành Động Cần Bổ Sung Phía Client-App |
|---|:---:|:---:|---|
| `x-device-name` (Header) | ❌ **CHƯA CÓ** | N/A (Header HTTP) | Thêm `device_info_plus`, tự động chèn tên thiết bị vào Dio Interceptor. |
| `system.maintenance_changed` | ❌ **BỎ SÓT** | Chưa khai báo enum | Bổ sung enum `baoTriThayDoi`, mở `MaintenanceScreen` khi `active = true` (2 loại: Khẩn cấp / Định kỳ). |
| `system.broadcast` | ❌ **BỎ SÓT** | Chưa khai báo enum | Bổ sung enum `thongBaoHeThong`, hiển thị In-App Banner và lưu SQLite. |
| `account.upgraded` | ✅ ĐÃ CÓ | `RealtimeEvent.taiKhoanNangCap` | Đã đón nhận, gọi `/subscription-info` cập nhật `GoiCubit`. |
| `account.downgraded` | ❌ **BỎ SÓT** | Chưa khai báo enum | Bổ sung enum `taiKhoanHaCap`, cập nhật `GoiCubit` về Basic. |
| `account.countdown` | ❌ **BỎ SÓT** | Chưa khai báo enum | Bổ sung enum `demNguocXoa`, hiển thị Banner cam đếm ngược 30 ngày. |
| `sync.completed` | ✅ ĐÃ CÓ | `RealtimeEvent.dongBoXong` | Đã đón nhận, kích hoạt kéo Delta Pull ngầm (im lặng). |
| `ocr.completed` | ✅ ĐÃ CÓ | `RealtimeEvent.ocrXong` | Đã đón nhận, hiện Toast và kích hoạt sync kéo giao dịch mới. |
| `ocr.duplicate` | ✅ ĐÃ CÓ | `RealtimeEvent.ocrTrung` | Đã đón nhận, hiện Dialog cảnh báo vàng. |
| `payment.success` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán, đóng popup QR. |
| `payment.order_cancelled` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán. |
| `payment.order_expired` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán. |
| `payment.refunded` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán. Cần thêm nút xem biên lai. |
| `payment.overpaid_confirmation` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán. |
| `payment.underpaid_warning` | ✅ ĐÃ CÓ | `RealtimeEvent.donThanhToanDoi` | Đã gộp trong enum đơn thanh toán. |
| `bank_transaction.incoming` | 🔇 BỎ QUA | `null` (Bỏ qua chuẩn) | Giữ nguyên hành vi bỏ qua (Module Bank đã dừng). |
| HTTP 503 `MAINTENANCE_MODE` | ❌ **BỎ SÓT** | Dio Interceptor | Bắt mã 503 tại `AuthInterceptor`, mở `MaintenanceScreen`. |
| HTTP 503 `SERVER_OVERLOADED` | ❌ **BỎ SÓT** | Dio Interceptor | Đọc `Retry-After`, đếm ngược tự động thử lại. |
| HTTP 429 `RETRY_LIMIT_EXCEEDED`| ❌ **BỎ SÓT** | Dio Interceptor | Dừng lặp request, thông báo người dùng tạm nghỉ. |
| HTTP 403 `AIOPS_QUARANTINED` | ❌ **BỎ SÓT** | Dio Interceptor | Hiển thị Dialog phong tỏa và thời gian mở khóa. |
| HTTP 403 `FEATURE_DISABLED` | ❌ **BỎ SÓT** | Dio Interceptor | Hiển thị BottomSheet mời nâng cấp gói Premium. |
| HTTP 401 `ACCOUNT_INACTIVE` | ⚠️ BÁN PHẦN | `buoc_dang_xuat.dart` | Cần hiển thị đúng chuỗi `reason_inactive` của Admin từ payload. |
| HTTP 401 `ACCOUNT_DELETED` | ✅ ĐÃ ĐẠT (G89) | `buoc_dang_xuat.dart` | Đăng xuất + hiện Dialog lý do, bảo lưu SQLite trên máy. |

---

## 8. PHẦN V: CHECKLIST & HƯỚNG DẪN THỰC THI CHO DEV CLIENT-APP (FLUTTER)

- [ ] **1. Tích hợp Thu Thập Thiết Bị (Device Tracking):**
  - Khai báo `device_info_plus: ^10.1.0` trong `pubspec.yaml`.
  - Viết `DeviceInfoService.getDeviceName()` chuẩn hóa chuỗi $\le 150$ ký tự.
  - Thêm `DeviceHeaderInterceptor` gắn `x-device-name` cho mọi request Dio.
- [ ] **2. Mở rộng `realtime_event.dart`:**
  - Bổ sung các case vào `realtimeEventFromName()`:
    + `system.maintenance_changed` $\longrightarrow$ `RealtimeEvent.baoTriThayDoi` (Xử lý 2 loại: Khẩn cấp & Định kỳ)
    + `system.broadcast` $\longrightarrow$ `RealtimeEvent.thongBaoHeThong`
    + `account.downgraded` $\longrightarrow$ `RealtimeEvent.taiKhoanHaCap`
    + `account.countdown` $\longrightarrow$ `RealtimeEvent.demNguocXoa`
- [ ] **3. Cập nhật `AuthInterceptor` (Dio Chốt Chặn):**
  - Bắt HTTP 503 với `code == 'MAINTENANCE_MODE'` $\longrightarrow$ điều hướng tới `MaintenanceScreen`.
  - Bắt HTTP 503 với `code == 'SERVER_OVERLOADED'` $\longrightarrow$ kích hoạt Backoff đếm ngược theo header `Retry-After`.
  - Bắt HTTP 403 với `code == 'AIOPS_QUARANTINED'` $\longrightarrow$ hiển thị Dialog cảnh báo an ninh Sentinel.
  - Bắt HTTP 403 với `code == 'FEATURE_DISABLED'` $\longrightarrow$ mở BottomSheet nâng cấp gói.
- [ ] **4. Tuân thủ Bảo Vệ Dữ Liệu Cá Nhân (Rule 9 & Nghị định 13/2023/NĐ-CP):**
  - Khi nhận `account.force_logout` với `reason == 'ACCOUNT_DELETED'` hoặc HTTP 401 `ACCOUNT_DELETED`: Đăng xuất và hiển thị Dialog lý do, bảo lưu SQLite trên máy.
