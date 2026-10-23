# 📡 HỢP ĐỒNG GIAO TIẾP SỰ KIỆN & THÔNG BÁO TỪ ADMIN-WEB VÀ BACKEND TỚI CLIENT-APP
### (Event & Notification Communication Contract: Admin-Web & Backend ➔ Client-App)

> **Tài liệu nguồn sự thật (Source of Truth)** đặc tả toàn bộ các sự kiện, thông báo, tín hiệu điều hướng và quy chuẩn thu thập thông tin thiết bị/IP phát sinh từ **Admin-web** và **Backend** có tác động hoặc yêu cầu xử lý từ phía **Client-app (Mobile App Flutter)**.  
> 
> * **Ngày cập nhật:** 23/10/2026  
> * **Phiên bản:** `v3.0` (Đồng bộ toàn diện kiến trúc AIOps Sentinel, Quản trị Bảo trì, Phân quyền 4 Trụ cột & Theo dõi Thiết bị/IP)  
> * **Trạng thái:** PO ĐÃ DUYỆT ĐỊNH HƯỚNG & YÊU CẦU THỰC THI (Official Approved Specification)  
> * **Phạm vi đối chiếu mã nguồn thực tế:**
>   * `src/Backend/core/socket.js` (Hạ tầng WebSocket Socket.IO v4)
>   * `src/Backend/modules/notification/notification.service.js` (Hệ thống thông báo đa kênh & Broadcast persistence)
>   * `src/Backend/modules/admin/admin.service.js` (Nghiệp vụ quản trị Admin)
>   * `src/Backend/core/resilience/maintenance.manager.js` (Điều hành bảo trì khẩn cấp & theo lịch)
>   * `src/Backend/middleware/` (`auth.js`, `maintenance.middleware.js`, `load-shedding.middleware.js`, `retry-guard.middleware.js`, `feature-permission.middleware.js`, `audit-log.middleware.js`)
>   * `src/Backend/modules/aiops/aiops.quarantine.js` (Tường lửa Sentinel & Ma trận phong tỏa)
>   * `src/Client-app/lib/core/realtime/` (`realtime_event.dart`, `realtime_channel.dart`, `realtime_socket.dart`)
>   * `src/Client-app/lib/core/api/interceptors/` (`auth_interceptor.dart`, `buoc_dang_xuat.dart`)

---

## 📌 MỤC LỤC
1. [Nguyên Tắc Thiết Kế & Kiến Trúc Giao Tiếp](#1-nguyên-tắc-thiết-kế--kiến-trúc-giao-tiếp)
2. [Đặc Tả Thu Thập Thông Tin Thiết Bị & IP Người Dùng (Device & IP Tracking)](#2-đặc-tả-thu-thập-thông-tin-thiết-bị--ip-người-dùng-device--ip-tracking)
3. [Bảng Tổng Hợp Toàn Bộ 24 Sự Kiện & Tín Hiệu](#3-bảng-tổng-hợp-toàn-bộ-24-sự-kiện--tín-hiệu)
4. [Phần I: Đặc Tả 15 Sự Kiện Kênh Thời Gian Thực (Socket.IO Events)](#4-phần-i-đặc-tả-15-sự-kiện-kênh-thời-gian-thực-socketio-events)
5. [Phần II: Đặc Tả 9 Tín Hiệu Chốt Chặn HTTP/API (Middleware & Error Signals)](#5-phần-ii-đặc-tả-9-tín-hiệu-chốt-chặn-httpapi-middleware--error-signals)
6. [Phần III: Ma Trận Đối Chiếu Hiện Trạng Phía Client-App](#6-phần-iii-ma-trận-đối-chiếu-hiện-trạng-phía-client-app)
7. [Phần IV: Checklist & Hướng Dẫn Thực Thi Cho Dev Client-App](#7-phần-iv-checklist--hướng-dẫn-thực-thi-cho-dev-client-app)

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
  - Socket events gửi tới người dùng **tuyệt đối không truyền số tài khoản ngân hàng đầy đủ, mật khẩu, mã OTP, số dư thô** (theo [`Data_Security.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Rule_Project/Data_Security.md)).
  - Sự kiện cưỡng chế xóa tài khoản (`ACCOUNT_DELETED`) bắt buộc Client-app phải dọn dẹp sạch dữ liệu cá nhân cục bộ trong SQLite (`purgeAccountData`).
* **Phân Biệt "Đánh Thức Đồng Bộ" và "Sự Kiện Thông Điệp":**
  - Không phải sự kiện nào cũng kích hoạt `syncNow()`. Các sự kiện như nâng cấp gói, cảnh báo bảo trì, thông báo broadcast chỉ cập nhật UI / Local Storage, không ép chạy full-sync tránh nghẽn mạng và tốn pin thiết bị.

---

## 2. ĐẶC TẢ THU THẬP THÔNG TIN THIẾT BỊ & IP NGƯỜI DÙNG (DEVICE & IP TRACKING)

> ⚠️ **YÊU CẦU BẮT BUỘC TỪ PO:**  
> "Client-app cần thu thập thông tin người dùng: Tên thiết bị và IP người dùng, mỗi lần đăng nhập hay truy cập vào app đều phải ghi nhận lại IP và tên thiết bị 1 lần. Nếu IP hoặc Tên thiết bị có thay đổi thì ghi dòng mới vào CSDL chứ không ghi đè, tránh làm mất dấu vết người dùng trước đó (Kiểm tra CSDL xem có bị xung đột với các ràng buộc đã có sẵn trong CSDL hay không)."

### 2.1. Phân Tích Ràng Buộc CSDL & Giải Pháp Lưu Trữ Không Ghi Đè
1. **Kiểm tra Ràng buộc CSDL (Constraint Conflict Analysis):**
   - **Bảng `account`:** Khóa chính `Idaccount`, Unique `Email`. Mỗi tài khoản chỉ có 1 dòng duy nhất. Nếu lưu trực tiếp vào bảng này sẽ gây **ghi đè** mất lịch sử người dùng trước đó $\implies$ **Tuyệt đối không lưu vào `account`**.
   - **Bảng `refreshtoken`:** Có cột `Device_name` và `IP_address`, nhưng bảng này phụ thuộc vào vòng đời của JWT token. Khi token hết hạn hoặc người dùng truy cập app bằng Access Token thông thường (chưa refresh), bảng này không được gọi. Hơn nữa, việc thu hồi hoặc dọn dẹp token định kỳ sẽ làm mất dấu vết kiểm toán $\implies$ **Không dùng làm nơi lưu vết chính**.
   - **Bảng chuyên biệt `account_device_history` (Đề xuất tối ưu):**
     - Khóa chính tự tăng `id BIGSERIAL PRIMARY KEY`.
     - Khóa ngoại `idaccount INT NOT NULL REFERENCES "account"("Idaccount") ON DELETE CASCADE`.
     - **HOÀN TOÀN KHÔNG có ràng buộc UNIQUE trên `(idaccount, device_name)` hay `(idaccount, ip_address)`**.
     - $\implies$ **Hoàn toàn KHÔNG XUNG ĐỘT** với bất kỳ ràng buộc nào đã có trong CSDL!

2. **Cấu Trúc Bảng CSDL PostgreSQL `account_device_history`:**
```sql
CREATE TABLE IF NOT EXISTS "account_device_history" (
  "id" BIGSERIAL PRIMARY KEY,
  "idaccount" INT NOT NULL,
  "device_name" VARCHAR(150) NOT NULL,
  "ip_address" VARCHAR(256) NOT NULL,
  "user_agent" TEXT,
  "first_seen_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "last_active_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  CONSTRAINT "fk_device_history_account" FOREIGN KEY ("idaccount") 
    REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE INDEX IF NOT EXISTS "idx_device_history_account" ON "account_device_history" ("idaccount", "last_active_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_history_ip" ON "account_device_history" ("ip_address");
```

3. **Cơ Chế Thu Thập & Quy Tắc Ghi Nhận (Diff Check Logic):**
   - **Phía Client-app (Flutter):**
     - Thu thập Tên thiết bị chi tiết (ví dụ: `"Samsung Galaxy S24 (Android 14)"` hoặc `"iPhone 15 Pro (iOS 17.5)"`) thông qua package `device_info_plus`.
     - Tự động gắn header HTTP chuẩn vào mọi request qua Dio Interceptor:
       ```http
       x-device-name: Samsung Galaxy S24 (Android 14)
       ```
   - **Phía Backend:**
     - Tự động trích xuất Tên thiết bị từ `req.headers['x-device-name']` (fallback về User-Agent nếu thiếu).
     - Tự động trích xuất IP kết nối qua `req.ip || req.headers['x-forwarded-for']` và mặt nạ hóa theo Nghị định 13/2023/NĐ-CP (`113.161.xx.xx`).
     - **Quy tắc so khớp biến động:**
       ```javascript
       const latest = await prisma.account_device_history.findFirst({
         where: { idaccount: targetIdaccount },
         orderBy: { last_active_at: 'desc' }
       });

       if (!latest || latest.device_name !== currentDevice || latest.ip_address !== currentMaskedIp) {
         // CÓ THAY ĐỔI Thiết bị hoặc IP -> GHI DÒNG MỚI (INSERT)
         await prisma.account_device_history.create({
           data: {
             idaccount: targetIdaccount,
             device_name: currentDevice,
             ip_address: currentMaskedIp,
             user_agent: req.headers['user-agent'] || null,
             first_seen_at: new Date(),
             last_active_at: new Date(),
           }
         });
       } else {
         // CÙNG Thiết bị và CÙNG IP -> Cập nhật timestamp hoạt động gần nhất (chống spam dòng trùng lặp)
         await prisma.account_device_history.update({
           where: { id: latest.id },
           data: { last_active_at: new Date() }
         });
       }
       ```

---

## 3. BẢNG TỔNG HỢP TOÀN BỘ 24 SỰ KIỆN & TÍN HIỆU

| STT | Tên Sự Kiện / Tín Hiệu | Giao Thức | Nguồn Kích Hoạt | Phạm Vi | Mức Độ Ưu Tiên |
|:---:|---|:---:|---|---|:---:|
| **1** | `account.force_logout` / `force_logout` | Socket.IO | Admin Khóa / Xóa tài khoản | Riêng tư (`account_<id>`) | 🚨 Khẩn cấp |
| **2** | `system.maintenance_changed` | Socket.IO | Admin Bật/Tắt bảo trì (Khẩn cấp / Lịch) | Toàn hệ thống (`io.emit`) | 🚨 Khẩn cấp |
| **3** | `system.broadcast` | Socket.IO | Admin Phát thông báo hệ thống | Toàn hệ thống (`io.emit`) | ⚠️ Cao |
| **4** | `account.permissions_updated` | Socket.IO | Admin Lưu ma trận phân quyền 4 Trụ cột | Toàn hệ thống (`io.emit`) | ℹ️ Tiêu chuẩn |
| **5** | `account.upgraded` | Socket.IO | Webhook PayOS / Admin duyệt gói | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **6** | `account.downgraded` | Socket.IO | Cron 00:00 hạ cấp hết hạn Premium | Riêng tư (`account_<id>`) | ⚠️ Cao |
| **7** | `account.countdown` | Socket.IO | Cron 00:00 đếm ngược chờ xóa 30 ngày | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **8** | `sync.completed` | Socket.IO | Backend xử lý xong đợt Push từ thiết bị khác | Riêng tư (`account_<id>`) | 🔇 Im lặng |
| **9** | `ocr.completed` | Socket.IO | Worker hoàn tất bóc tách OCR hóa đơn | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **10** | `ocr.duplicate` | Socket.IO | AI phát hiện hóa đơn trùng lặp | Riêng tư (`account_<id>`) | ⚠️ Cảnh báo |
| **11** | `user.notification` | Socket.IO | Hệ thống gửi tin nhắn riêng vào hộp thư | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **12** | `payment.refunded` | Socket.IO | Admin duyệt hoàn tất đơn hoàn tiền | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **13** | `payment.order_expired` | Socket.IO | Worker 30s hủy đơn VietQR quá 10 phút | Riêng tư (`account_<id>`) | ℹ️ Tiêu chuẩn |
| **14** | `payment.overpaid_confirmation` | Socket.IO | Webhook PayOS chuyển thừa tiền đơn hàng | Riêng tư (`account_<id>`) | ⚠️ Cao |
| **15** | `payment.underpaid_warning` | Socket.IO | Webhook PayOS chuyển thiếu tiền đơn hàng | Riêng tư (`account_<id>`) | ⚠️ Cảnh báo |
| **16** | HTTP 503 `MAINTENANCE_MODE` | REST API | Chế độ bảo trì hệ thống đang kích hoạt | Mọi Client gọi API | 🚨 Khẩn cấp |
| **17** | HTTP 503 `SERVER_OVERLOADED` | REST API | Load Shedding thông minh (Lag > 100ms) | Mọi Client gọi API | ⚠️ Tạm thời |
| **18** | HTTP 429 `RETRY_LIMIT_EXCEEDED` | REST API | Bão request lặp (> 3 retries) | IP / Client vi phạm | ⚠️ Tạm thời |
| **19** | HTTP 403 `AIOPS_QUARANTINED` | REST API | Tường lửa Sentinel phong tỏa IP | IP vi phạm | 🚫 Chặn truy cập |
| **20** | HTTP 403 `FEATURE_DISABLED` | REST API | Chặn tính năng vượt gói cước Basic | Tài khoản gói Basic | 🔒 Giới hạn |
| **21** | HTTP 401 `ACCOUNT_INACTIVE` | REST API | Admin khóa tài khoản (kèm lý do) | Tài khoản bị khóa | 🚨 Đăng xuất |
| **22** | HTTP 401 `ACCOUNT_DELETED` | REST API | Admin xóa mềm tài khoản 5 bước | Tài khoản bị xóa | 🚨 Đăng xuất & Xóa |
| **23** | HTTP 400 `PENDING_DELETE_PROTECTED`| REST API | Bảo vệ tài khoản chờ thanh lý 30 ngày | Thao tác sửa/xóa | 🚫 Từ chối |
| **24** | Socket Handshake Error | WebSocket | Bắt tay kết nối thất bại (Token/Khóa) | Client kết nối Socket | 🚨 Ngắt kết nối |

---

## 4. PHẦN I: ĐẶC TẢ 15 SỰ KIỆN KÊNH THỜI GIAN THỰC (SOCKET.IO EVENTS)

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
  2. Nếu `reason == 'ACCOUNT_DELETED'`: Xóa trắng CSDL SQLite (`purgeAccountData`) để tuân thủ quyền riêng tư.
  3. Nếu `reason == 'ACCOUNT_INACTIVE'`: Giữ nguyên dữ liệu SQLite.
  4. Mở Popup Dialog hiển thị đúng nội dung `message`. Bấm "Đồng ý" chuyển về màn hình `LoginPage`.

---

### 4.2. `system.maintenance_changed` — Thay Đổi Trạng Thái Bảo Trì Hệ Thống
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`).
* **Nguồn kích hoạt:** Admin bật/tắt bảo trì khẩn cấp hoặc lịch bảo trì tự động kích hoạt.
* **Cấu trúc Payload chuẩn:**
```json
{
  "active": true,
  "isEmergency": true,
  "reason": "Hệ thống đang tiến hành nâng cấp cụm máy chủ cơ sở dữ liệu định kỳ.",
  "activatedAt": "2026-10-23T08:00:00.000Z",
  "activatedBy": "admin_system"
}
```
*(Khi kết thúc: `"active": false`, `"isEmergency": false`, `"reason": null`)*
* **Xử lý bắt buộc trên Client-app:**
  1. Khi `active == true`:
     - Nếu `isEmergency: true`: Hiển thị Màn hình Bảo Trì Toàn Cục màu đỏ khẩn cấp, khóa các nút tạo/sửa giao dịch, tạm dừng sync ngầm.
     - Nếu `isEmergency: false`: Hiển thị Banner màu cam thông báo bảo trì theo lịch, cho phép người dùng xem dữ liệu offline.
  2. Khi `active == false`:
     - Đóng màn hình bảo trì, hiển thị Toast xanh thông báo hệ thống hoạt động trở lại.
     - Tự động kích hoạt đồng bộ bù `syncNow()`.

---

### 4.3. `system.broadcast` — Thông Báo Toàn Hệ Thống
* **Kênh phát:** Toàn bộ Client kết nối (`io.emit`).
* **Nguồn kích hoạt:** Admin phát sóng từ Tab "Phát thông báo" tại `BroadcastPage.jsx`.
* **Cấu trúc Payload chuẩn:**
```json
{
  "id": "e4b52c08-72fa-45cf-81b4-f6b92a40dc78",
  "title": "Thông báo nâng cấp ứng dụng phiên bản 3.0",
  "message": "Hệ thống bổ sung tính năng theo dõi thiết bị an ninh và tối ưu hóa hiệu năng đồng bộ offline.",
  "level": "INFO",
  "isEmergency": false,
  "category": "BROADCAST",
  "createdAt": "2026-10-23T08:15:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Hiển thị In-App Banner hoặc Top SnackBar theo cấp độ `level`:
     - `CRITICAL` hoặc `isEmergency: true`: Banner đỏ cảnh báo khẩn cấp toàn màn hình.
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
  "timestamp": "2026-10-23T08:20:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  1. Không chạy full sync. Gọi nhẹ API `GET /api/payment/subscription-info` (~300 bytes).
  2. Cập nhật `GoiCubit` và lưu cấu hình quyền mới vào `FlutterSecureStorage`.
  3. Cập nhật giao diện ẩn/hiện hoặc khóa các tính năng theo hạn mức mới.

---

### 4.5. `payment.refunded` — Thông Báo Hoàn Tiền Thành Công
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Admin xử lý duyệt hoàn tiền giao dịch PayOS đính kèm minh chứng.
* **Cấu trúc Payload chuẩn:**
```json
{
  "orderCode": 1729671234567,
  "refundedAmount": 49000,
  "refundReason": "Giao dịch chuyển khoản trùng lặp theo yêu cầu của khách hàng",
  "refundProof": "https://supabase-storage.../refund_proof_123.jpg",
  "timestamp": "2026-10-23T08:25:00.000Z"
}
```
* **Xử lý bắt buộc trên Client-app:**
  - Hiển thị Dialog thông báo đã hoàn tiền thành công kèm nút bấm "Xem biên lai chuyển khoản".

---

### 4.6. `payment.order_expired` — Đơn Hàng Thanh Toán Quá Hạn
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Worker 30s quét và hủy các đơn hàng VietQR chưa thanh toán sau 10 phút.
* **Cấu trúc Payload chuẩn:**
```json
{
  "orderCode": 1729671234567,
  "message": "Đơn hàng đã hết hạn thanh toán (quá 10 phút). Vui lòng tạo đơn mới."
}
```
* **Xử lý bắt buộc trên Client-app:**
  - Nếu người dùng đang mở popup mã VietQR thanh toán: Tự động đóng popup và thông báo mã QR đã hết hạn.

---

### 4.7. `payment.overpaid_confirmation` & `payment.underpaid_warning` — Lệch Số Tiền Thanh Toán
* **Kênh phát:** `account_<idaccount>`.
* **Nguồn kích hoạt:** Webhook PayOS phát hiện số tiền chuyển khoản không khớp với đơn hàng.
* **Cấu trúc Payload chuẩn:**
```json
{
  "orderCode": 1729671234567,
  "expectedAmount": 49000,
  "receivedAmount": 20000,
  "message": "Số tiền nhận được (20.000đ) thấp hơn giá trị đơn hàng (49.000đ). Vui lòng liên hệ hỗ trợ."
}
```
* **Xử lý bắt buộc trên Client-app:**
  - Hiển thị Dialog cảnh báo để người dùng liên hệ Hotline hỗ trợ kỹ thuật xử lý đối soát.

---

## 5. PHẦN II: ĐẶC TẢ 9 TÍN HIỆU CHỐT CHẶN HTTP/API (MIDDLEWARE & ERROR SIGNALS)

### 5.1. HTTP 503 `MAINTENANCE_MODE` — Hệ Thống Đang Bảo Trì
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 503,
  "code": "MAINTENANCE_MODE",
  "isEmergency": true,
  "message": "Hệ thống đang tiến hành nâng cấp máy chủ định kỳ. Quý khách vui lòng quay lại sau ít phút!"
}
```
* **Xử lý trên Client-app:** Bắt tại Dio Interceptor, kích hoạt Màn hình Bảo Trì toàn phần, không ném lỗi crash mạng.

### 5.2. HTTP 403 `AIOPS_QUARANTINED` — Tường Lửa Phong Tỏa IP
* **Response Body:**
```json
{
  "success": false,
  "code": "AIOPS_QUARANTINED",
  "message": "Kết nối từ thiết bị của bạn tạm thời bị phong tỏa do phát hiện dấu hiệu bất thường.",
  "reason": "Tấn công DoS quá ngưỡng request",
  "quarantineExpiresAt": "2026-10-23T09:00:00.000Z"
}
```
* **Xử lý trên Client-app:** Hiển thị Dialog thông báo thiết bị bị phong tỏa tạm thời kèm đồng hồ đếm ngược mở khóa (`quarantineExpiresAt`).

### 5.3. HTTP 403 `FEATURE_DISABLED` — Chặn Tính Năng Gói Basic
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
* **Xử lý trên Client-app:** Mở Modal / BottomSheet giới thiệu tính năng kèm nút "Nâng cấp Premium ngay".

### 5.4. HTTP 400 `PENDING_DELETE_PROTECTED` — Bảo Vệ Tài Khoản Chờ Xóa 30 Ngày
* **Response Body:**
```json
{
  "success": false,
  "statusCode": 400,
  "code": "PENDING_DELETE_PROTECTED",
  "message": "Tài khoản đang trong thời gian ân hạn 30 ngày chờ thanh lý. Không thể thay đổi trạng thái."
}
```

---

## 6. PHẦN III: MA TRẬN ĐỐI CHIẾU HIỆN TRẠNG PHÍA CLIENT-APP

| Hạng mục | Tên Sự Kiện / Tín Hiệu | Trạng Thái Client-App | Hành Động Cần Bổ Sung Cho Client-App |
|---|---|:---:|---|
| **Header** | `x-device-name` | ❌ **CHƯA CÓ** | Thêm package `device_info_plus`, tự động gắn tên thiết bị vào Dio Interceptor cho mọi request. |
| **Socket** | `system.maintenance_changed` | ❌ **BỎ SÓT** | Mở Màn hình Bảo Trì toàn phần (`MaintenanceScreen`) khi `active = true`. |
| **Socket** | `system.broadcast` | ❌ **BỎ SÓT** | Bổ sung In-App Banner toàn cục và lưu thông báo vào SQLite. |
| **Socket** | `payment.refunded` | ❌ **BỎ SÓT** | Hiển thị Dialog thông báo hoàn tiền thành công kèm link xem ảnh biên lai. |
| **Socket** | `payment.order_expired` | ❌ **BỎ SÓT** | Tự động đóng popup mã QR và báo mã đã hết hạn. |
| **HTTP** | 503 `MAINTENANCE_MODE` | ❌ **BỎ SÓT** | Bắt mã 503 tại `AuthInterceptor`, mở Màn hình Bảo Trì thay vì ném lỗi mạng. |
| **HTTP** | 403 `AIOPS_QUARANTINED` | ❌ **BỎ SÓT** | Hiển thị Popup cảnh báo an ninh và thời gian đếm ngược mở khóa. |
| **HTTP** | 403 `FEATURE_DISABLED` | ❌ **BỎ SÓT** | Hiển thị BottomSheet mời nâng cấp gói Premium. |

---

## 7. PHẦN IV: CHECKLIST & HƯỚNG DẪN THỰC THI CHO DEV CLIENT-APP

- [ ] **1. Tích hợp Device Tracking:**
  - Thêm `device_info_plus: ^10.1.0` vào `pubspec.yaml`.
  - Tạo `DeviceInfoService` lấy chuỗi: `"${brand} ${model} (${osVersion})"`.
  - Trong `DioClient`: Luôn gắn header `options.headers['x-device-name'] = await DeviceInfoService.getDeviceName();`.
- [ ] **2. Mở rộng `realtime_event.dart`:**
  - Bổ sung các sự kiện: `baoTriThayDoi`, `thongBaoHeThong`, `hoanTienThanhCong`, `donHangHetHan`.
- [ ] **3. Cập nhật `auth_interceptor.dart`:**
  - Bắt các mã HTTP 503 (`MAINTENANCE_MODE`), 403 (`AIOPS_QUARANTINED`), 403 (`FEATURE_DISABLED`) để phản hồi trực quan trên UI.
- [ ] **4. Tạo màn hình Bảo trì toàn cầu (`MaintenanceScreen`):**
  - Khóa thao tác ghi, bảo vệ dữ liệu tài chính của người dùng khi server bảo trì khẩn cấp.
