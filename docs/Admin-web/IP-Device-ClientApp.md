# 📱 ĐẶC TẢ THU THẬP THÔNG TIN THIẾT BỊ & ĐỊA CHỈ IP NGƯỜI DÙNG PHÍA CLIENT-APP
### (Client-App Device & IP Tracking Specification for Admin-Web Management)

> **Mã tài liệu:** `DOC-DEVICE-IP-TRACKING-v3.0`  
> **Cơ quan ban hành:** Lead BA + Lead FullStack Cao Cấp + Lead QA Architect  
> **Trạng thái:** 🟢 PO ĐÃ PHÊ DUYỆT ĐỊNH HƯỚNG & QUY TẮC NGHIỆP VỤ (Official Source of Truth)  
> **Ngày hiệu lực:** 23/10/2026  
> **Phạm vi áp dụng:** Toàn bộ hệ thống FinanceManagement:
> - **Client-app (Mobile Flutter):** Thu thập và truyền tải `x-device-name`, `User-Agent`.
> - **Backend (Node.js/Express/Prisma):** Trích xuất IP, mặt nạ hóa (Masked IP), kiểm tra biến động (Diff Check) và ghi nhận vào PostgreSQL.
> - **Admin-web (React/Vite):** Hiển thị màn hình Quản lý người dùng, Lịch sử thiết bị, Truy vết kiểm toán và Cảnh báo an ninh AIOps.


> 📌 **Ghi chú đối chiếu thực tế với Client-app theo đo đạc 2026-10-30 (Task T2):**
> - Fallback thiết bị: Client-app không gửi chuỗi `Unknown Device`, Backend tự điền fallback khi vắng header `x-device-name`.
> - Quản lý CSDL: Luôn tuân thủ cơ chế xóa mềm (Soft-delete), không xóa cứng cascade trên bảng `account`.
> - Throttle bypass: Cả Login, Register và OTP đều được cấu hình linh hoạt theo hạ tầng rate-limiter.

---

## 📌 MỤC LỤC
1. [Mục Đích & Phạm Vi Nghiệp Vụ Tại Admin-Web](#1-mục-đích--phạm-vi-nghiệp-vụ-tại-admin-web)
2. [Quy Tắc Thu Thập & Ghi Nhận Dữ Liệu (Business Rules)](#2-quy-tắc-thu-thập--ghi-nhận-dữ-liệu-business-rules)
3. [Phân Tích Ràng Buộc CSDL & Cấu Trúc Bảng PostgreSQL](#3-phân-tích-ràng-buộc-csdl--cấu-trúc-bảng-postgresql)
4. [Đặc Tả Giao Thức Kết Nối & Header HTTP Giữa Client và Server](#4-đặc-tả-giao-thức-kết-nối--header-http-giữa-client-và-server)
5. [Hướng Dẫn Triển Khai Chi Tiết Cho Đội Ngũ Client-App (Flutter)](#5-hướng-dẫn-triển-khai-chi-tiết-cho-đội-ngũ-client-app-flutter)
6. [Đặc Tả Các API Endpoints Backend Phục Vụ Admin-Web](#6-đặc-tả-các-api-endpoints-backend-phục-vụ-admin-web)
7. [Kiểm Thử 2 Tầng Bắt Buộc (2-Tier Testing Architecture)](#7-kiểm-thử-2-tầng-bắt-buộc-2-tier-testing-architecture)
8. [Checklist Sống Còn Cho Đội Ngũ Phát Triển (Golden Rules)](#8-checklist-sống-còn-cho-đội-ngũ-phát-triển-golden-rules)

---

## 1. MỤC ĐÍCH & PHẠM VI NGHIỆP VỤ TẠI ADMIN-WEB

### 1.1. Tại Sao Admin-Web Cần Dữ Liệu Thiết Bị & IP?
Ứng dụng Quản lý Tài chính Cá nhân xử lý các giao dịch tiền tệ, số dư tài khoản và ngân sách nhạy cảm. Quản trị viên (Admin) tại `Admin-web` bắt buộc phải nắm bắt thông tin thiết bị và địa chỉ IP của người dùng để:
1. **Giám sát an ninh truy cập & Phòng chống gian lận:**
   - Phát hiện các hành vi đăng nhập bất thường (ví dụ: cùng một tài khoản đăng nhập từ 2 địa chỉ IP cách xa nhau hàng trăm km trong thời gian ngắn).
   - Phát hiện việc một thiết bị dùng chung cho hàng loạt tài khoản ảo hoặc có dấu hiệu tấn công tự động (Credential Stuffing).
2. **Hỗ trợ truy vết sự cố & Giải quyết khiếu nại (Digital Forensics):**
   - Khi người dùng khiếu nại "Tôi không thực hiện giao dịch này" hoặc "Tài khoản của tôi bị ai đó đăng nhập trái phép", Admin có bằng chứng lịch sử rõ ràng về thời gian, tên thiết bị, và địa chỉ IP đã gửi request.
3. **Thống kê & Tối ưu hóa hạ tầng (Device Telemetry):**
   - Thống kê tỷ lệ thiết bị người dùng (Android, iOS, các dòng máy phổ biến, phiên bản OS) để đội ngũ kỹ thuật có căn cứ ưu tiên tối ưu giao diện và kiểm thử tương thích.
4. **Phối hợp với Hệ thống Tường lửa AIOps Sentinel:**
   - Cung cấp dữ liệu nhận diện thiết bị cho cơ chế phát hiện mối đe dọa (Threat Detection) và tự động phong tỏa IP vi phạm mà không làm ảnh hưởng nhầm đến người dùng hợp pháp khác.

### 1.2. Các Tính Năng / Màn Hình Tại Admin-Web Sử Dụng Dữ Liệu Này (Kế Hoạch)
> ⚠️ **Lưu ý hiện trạng:** Các giao diện hiển thị và API truy vấn lịch sử thiết bị trên Admin-web hiện đang ở trạng thái **kế hoạch phát triển** (Planned Roadmap). Ở giai đoạn hiện tại, CSDL Backend đang thực thi việc thu thập và ghi nhận (Write-only) vào bảng `account_device_history` qua mỗi request từ Client-app.

* **Màn hình Chi tiết Người dùng (`/admin/users/:idaccount`) *(Kế hoạch)*:** Tab **"Lịch sử Thiết bị & Phiên truy cập"** hiển thị danh sách toàn bộ các thiết bị người dùng từng sử dụng kèm: Tên thiết bị, Địa chỉ IP (đã che bớt), Lần đầu truy cập (`first_seen_at`), Hoạt động gần nhất (`last_active_at`), và Trạng thái đang hoạt động.
* **Màn hình Giám sát An ninh Tổng thể (`/admin/security/device-history`) *(Kế hoạch)*:** Danh sách luồng truy cập thiết bị theo thời gian thực (Real-time Device Access Stream).
* **Bảng Cảnh báo Đăng nhập Lạ (Unusual Login Alert) *(Kế hoạch)*:** Khi phát hiện IP mới khác subnet thông thường hoặc Device mới lần đầu xuất hiện, hiển thị cờ cảnh báo màu vàng để Admin lưu ý.

---

## 2. QUY TẮC THU THẬP & GHI NHẬN DỮ LIỆU (BUSINESS RULES)

> ⚠️ **ĐÂY LÀ QUY TẮC CỐT LÕI ĐÃ ĐƯỢC PRODUCT OWNER (PO) PHÊ DUYỆT CHÍNH THỨC:**
> 1. Mỗi lần người dùng **Đăng nhập** hoặc **Mở app / Gửi request truy cập sử dụng**, hệ thống đều phải ghi nhận lại IP và Tên thiết bị 1 lần.
> 2. **Cơ chế Diff Check (Không ghi đè, bảo toàn dấu vết):**
>    - Nếu IP hoặc Tên thiết bị **CÓ THAY ĐỔI** (hoặc tài khoản chưa có lịch sử) $\longrightarrow$ **GHI THÊM DÒNG MỚI (INSERT)** vào CSDL. Tuyệt đối **KHÔNG ghi đè** dòng cũ để tránh làm mất dấu vết người dùng trước đó.
>    - Nếu IP và Tên thiết bị **KHÔNG THAY ĐỔI** $\longrightarrow$ **CẬP NHẬT (UPDATE)** thời gian hoạt động gần nhất (`last_active_at`), **KHÔNG tạo thêm dòng mới** để tránh làm rác CSDL.

### 2.1. Lưu Đồ Xử Lý (Flowchart Quyết Định)

```mermaid
flowchart TD
    A[Client-app gửi Request] --> B[Middleware / Login Service trích xuất Info]
    B --> C[Lấy Tên Thiết Bị x-device-name & IP thực tế]
    C --> D[Mặt nạ hóa IP theo Nghị định 13: maskIp]
    D --> E{Kiểm tra Throttle Cache 60s?}
    E -- Trùng khớp trong 60s & Không phải Login -- --> F[Bỏ qua - Giữ hiệu năng CSDL]
    E -- Vượt 60s hoặc Luồng Login -- --> G[Truy vấn bản ghi gần nhất của Account trong CSDL]
    G --> H{Có bản ghi gần nhất chưa?}
    H -- Chưa có -- --> I[INSERT dòng mới vào account_device_history]
    H -- Đã có -- --> J{Device Name hoặc IP có khác nhau?}
    J -- CÓ THAY ĐỔI: Khác Device hoặc Khác IP -- --> I
    J -- KHÔNG THAY ĐỔI: Trùng cả Device và IP -- --> K[UPDATE last_active_at = NOW của dòng đó]
    I --> L[Lưu vào Cache 60s & Trả kết quả]
    K --> L
```

### 2.2. Cơ Chế Chống Bão Ghi CSDL (Throttle Cache 60 Giây)
- Khi người dùng sử dụng ứng dụng, họ có thể gửi hàng chục request trong vòng 1 phút (đồng bộ, kéo danh sách giao dịch, xem báo cáo, chuyển tab...).
- Nếu mỗi request đều truy vấn và cập nhật CSDL liên tục sẽ gây nghẽn kết nối (Connection Exhaustion).
- **Giải pháp triển khai tại Backend:**
  + Duy trì bộ đệm trong bộ nhớ (`accessCache`) với khóa: `${idaccount}:${deviceName}:${maskedIp}`.
  + Chu kỳ tiết lưu (`THROTTLE_MS`): **60 giây**.
  + Nếu trong vòng 60 giây, người dùng dùng cùng một thiết bị và cùng một IP tiếp tục gửi các request API bình thường, hệ thống **bỏ qua ghi nhận CSDL** để tối ưu tài nguyên.
  + **Ngoại lệ bắt buộc:** Khi người dùng thực hiện **Đăng nhập (`POST /api/auth/login`)**, **Đăng ký** hoặc **Xác thực OTP**, cờ `skipThrottle = true` luôn được kích hoạt để đảm bảo ghi nhận ngay lập tức mà không bị bỏ sót.

### 2.3. Tuân Thủ Pháp Luật & Bảo Vệ Quyền Riêng Tư (Nghị Định 13/2023/NĐ-CP & Rule 9)
Theo tài liệu [`Data_Security.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Rule_Project/Data_Security.md) và Điều 17 Nghị định 13/2023/NĐ-CP:
1. **Mặt nạ hóa địa chỉ IP (IP Masking):**
   - Địa chỉ IP là dữ liệu có khả năng định danh thiết bị mạng của người dùng. Backend **bắt buộc chạy qua hàm `maskIp()`** (`utils/masking.util.js`) trước khi lưu vào CSDL hoặc hiển thị lên Admin-web:
     + IPv4: Che 2 byte cuối $\longrightarrow$ Ví dụ: `113.161.45.12` thành `113.161.xx.xx`.
     + IPv6: Giữ 2 nhóm đầu, che các nhóm sau $\longrightarrow$ Ví dụ: `2402:800:6390:e388:...` thành `2402:800:xxxx:xxxx:...`.
2. **Nguyên tắc Tối thiểu hóa Dữ liệu (Data Minimization):**
   - **ĐƯỢC PHÉP thu thập:** Tên dòng máy (Model), Hãng sản xuất (Manufacturer), Phiên bản Hệ điều hành (OS Version), Địa chỉ IP mạng công cộng (đã che bớt).
   - **TUYỆT ĐỐI CẤM THU THẬP:** Danh bạ điện thoại, vị trí GPS thời gian thực liên tục (chỉ cho phép gắn vị trí giao dịch khi người dùng chủ động cho phép từng lần), nội dung SMS cá nhân ngoài biến động số dư ngân hàng, số IMEI/Serial phần cứng không được cấp phép.

---

## 3. PHÂN TÍCH RÀNG BUỘC CSDL & CẤU TRÚC BẢNG POSTGRESQL

### 3.1. Phân Tích Xung Đột Ràng Buộc CSDL Hiện Có
Trước khi triển khai, kiến trúc hệ thống đã được thẩm định toàn diện trên các bảng hiện hữu:

| Bảng CSDL | Ràng buộc hiện hữu | Đánh giá rủi ro xung đột | Kết luận |
| :--- | :--- | :--- | :--- |
| **`account`** | `Idaccount` (PK), `Email` (UNIQUE) | Mỗi tài khoản chỉ là 1 dòng duy nhất. Nếu thêm cột `device_name`, `ip_address` vào bảng `account`, mỗi lần người dùng đổi mạng hoặc đổi máy sẽ **bị ghi đè**, làm mất hoàn toàn lịch sử truy vết trước đó. | ❌ **KHÔNG LƯU VÀO `account`** |
| **`refreshtoken`** | `Idtoken` (PK), `Token_hash` (UNIQUE) | Bảng này chỉ phục vụ chu kỳ sống của JWT Refresh Token (bị thu hồi khi logout hoặc bị cron job dọn dẹp định kỳ sau 30 ngày). Khi người dùng gọi API bằng Access Token mà không refresh token, bảng này không được cập nhật. | ⚠️ **KHÔNG ĐỦ ĐÁP ỨNG** |
| **`account_device_history`** *(Bảng chuyên biệt)* | `id` (BIGSERIAL PK), `idaccount` (FK `account.Idaccount`) | **TUYỆT ĐỐI KHÔNG ĐẶT UNIQUE** trên `device_name` hoặc `ip_address`. Khóa ngoại liên kết tới `account` với chính sách `ON DELETE CASCADE`. Cho phép lưu không giới hạn lịch sử theo thời gian. | ✅ **GIẢI PHÁP TỐI ƯU 100% (KHÔNG XUNG ĐỘT)** |

### 3.2. Cấu Trúc Bảng PostgreSQL: `account_device_history`

Bảng đã được khởi tạo trong CSDL thông qua Migration `35_create_account_device_history_table.sql`:

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

-- Index tối ưu hóa truy vấn hiển thị Admin và kiểm tra biến động nhanh chóng
CREATE INDEX IF NOT EXISTS "idx_device_history_account" ON "account_device_history" ("idaccount", "last_active_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_history_ip" ON "account_device_history" ("ip_address");
```

#### Chi Tiết Ý Nghĩa Các Cột:
* `id` (`BIGSERIAL`): Khóa chính tự tăng, hỗ trợ mở rộng hàng chục triệu bản ghi lịch sử.
* `idaccount` (`INT`): Mã định danh tài khoản người dùng, tham chiếu tới `account.Idaccount`.
* `device_name` (`VARCHAR(150)`): Tên thiết bị được chuẩn hóa từ Client-app (Ví dụ: `"Samsung Galaxy S24 (Android 14)"`).
* `ip_address` (`VARCHAR(256)`): Địa chỉ IP đã che bớt 2 byte cuối (Ví dụ: `"113.161.xx.xx"`).
* `user_agent` (`TEXT`): Chuỗi định danh User-Agent của phiên bản ứng dụng và Webview.
* `first_seen_at` (`TIMESTAMP(6)`): Thời điểm đầu tiên phát hiện thiết bị và IP này kết nối tới hệ thống (giờ chuẩn quốc tế UTC).
* `last_active_at` (`TIMESTAMP(6)`): Thời điểm gần nhất thiết bị và IP này gửi request thao tác trên hệ thống. Dùng để sắp xếp hiển thị thiết bị đang hoạt động trên Admin-web.

---

## 4. ĐẶC TẢ GIAO THỨC KẾT NỐI & HEADER HTTP GIỮA CLIENT VÀ SERVER

### 4.1. Header Bắt Buộc: `x-device-name`
* **Tên Header:** `x-device-name`
* **Kiểu dữ liệu:** Chuỗi ký tự ASCII / UTF-8, độ dài tối đa 150 ký tự.
* **Quy tắc định dạng khuyến nghị:**
  $$\text{[Hãng sản xuất]} + \text{ } + \text{[Tên dòng máy]} + \text{ (} + \text{[Tên OS]} + \text{ } + \text{[Phiên bản OS]} + \text{)}$$
* **Ví dụ mẫu hợp lệ:**
  - `Samsung Galaxy S24 Ultra (Android 14)`
  - `iPhone 15 Pro Max (iOS 17.5.1)`
  - `Xiaomi Redmi Note 13 (Android 13)`
  - `iPad Air 5 (iPadOS 17.4)`
* **Nếu không lấy được thông tin phần cứng:** Client-app gửi fallback là `"Unknown Device"`.

### 4.2. Header Tiêu Chuẩn: `User-Agent`
* **Tên Header:** `User-Agent`
* **Ví dụ:** `FinanceApp/1.2.0 (Dart 3.5; Flutter 3.24; Android 14)`

### 4.3. Cơ Chế Thu Thập Địa Chỉ IP Người Dùng
> 💡 **LƯU Ý CỰC KỲ QUAN TRỌNG VỀ IP:**
> - **Client-app KHÔNG CẦN gọi các API bên thứ ba** (như `api.ipify.org`, `ipinfo.io`) để lấy IP trước khi gửi request. Việc này làm chậm tốc độ mở app, tốn băng thông và có nguy cơ lỗi timeout khi dịch vụ thứ ba bị chặn.
> - **Nguyên lý thu thập chuẩn:** Khi Client-app gửi bất kỳ request HTTP nào tới máy chủ Backend (qua mạng 4G/5G hoặc Wi-Fi), Backend Server tự động phân tích gói tin TCP/IP và trích xuất IP thực tế thông qua:
>   ```javascript
>   const rawIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || 
>                 req.ip || 
>                 req.socket?.remoteAddress;
>   ```
> - Sau đó, Backend sẽ tự động chạy hàm `maskIp(rawIp)` để bảo vệ dữ liệu cá nhân theo quy định pháp luật trước khi lưu vào CSDL.

### 4.4. Payload Bổ Sung Khi Đăng Nhập (`POST /api/auth/login`)
Ngoài header HTTP, trong body của API đăng nhập, Client-app nên gửi kèm trường `deviceName` để đảm bảo lưu vết tức thời:
```json
{
  "username": "nguyenvanan",
  "password": "Password123@!",
  "deviceName": "Samsung Galaxy S24 Ultra (Android 14)"
}
```

---

## 5. HIỆN TRẠNG TRIỂN KHAI PHÍA CLIENT-APP (FLUTTER)

### 5.1. Triển Khai Thực Tế Trên Android (Native Kotlin MethodChannel)
- **Phương thức thực tế:** Phía Client-app (Flutter) hiện tại thu thập tên thiết bị **chỉ trên nền tảng Android** thông qua MethodChannel Kotlin `flowmoney/thiet_bi` (không sử dụng package `device_info_plus`).
- **Định dạng gửi lên:** Chuỗi chuẩn hóa `"[Hãng sản xuất] [Model] (Android [Phiên bản])"` (ví dụ: `Samsung SM-S928B (Android 14)`).
- **Gắn tự động:** Được tự động đính kèm vào header `x-device-name` ở tất cả các luồng:
  + Dio instance chung của app (mọi request API thông thường).
  + Dio xử lý làm mới phiên (`POST /api/auth/refresh`).
  + Luồng đồng bộ chạy nền (background sync engine).
- **Nền tảng khác (iOS / Web):** Hiện tại chưa triển khai MethodChannel tương ứng; khi gửi request sẽ nhận fallback `"Unknown Device"` từ server nếu header vắng mặt.
- **Tuân thủ quyền riêng tư:** Tuyệt đối không sử dụng `iosInfo.name` hay `computerName` (vốn là tên do người dùng tự đặt trên thiết bị, vi phạm nguyên tắc bảo vệ dữ liệu cá nhân theo §2.3).

### 5.2. Bảng Lưu Vết Cục Bộ SQLite (`device_tracking`) Tại Client-App (Tham Chiếu)
Để Client-app có thể nắm bắt trạng thái thiết bị của chính mình khi ngoại tuyến (Offline-First), định nghĩa bảng Drift SQLite:

```dart
// lib/core/database/tables/device_tracking_table.dart
import 'package:drift/drift.dart';

@DataClassName('DeviceTrackingEntry')
class DeviceTracking extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceName => text().withLength(max: 150)();
  TextColumn get lastKnownIp => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isCurrentDevice => boolean().withDefault(const Constant(true))();
}
```

---

## 6. ĐẶC TẢ CÁC API ENDPOINTS BACKEND PHỤC VỤ ADMIN-WEB (KẾ HOẠCH)

> ⚠️ **Lưu ý hiện trạng:** Hai route `GET /api/admin/accounts/:idaccount/devices` và `GET /api/admin/devices/recent-access` hiện ở trạng thái **kế hoạch triển khai**. Phía Backend hiện tập trung hoàn tất tầng ghi nhận dữ liệu (Write layer) vào `account_device_history` và bảo vệ dữ liệu theo chuẩn Nghị định 13.

### 6.1. Lấy Lịch Sử Thiết Bị Của Một Tài Khoản (Kế hoạch)
* **Endpoint:** `GET /api/admin/accounts/:idaccount/devices`
* **Quyền hạn truy cập:** Admin Token (`idrole: 1` hoặc `rolename: 'admin'`).
* **Query Parameters:**
  + `limit`: Số bản ghi tối đa (mặc định: `20`, tối đa: `100`).
* **Ví dụ Response thành công (`HTTP 200 OK`):**
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy lịch sử thiết bị thành công",
  "data": {
    "idaccount": 50,
    "totalDevices": 3,
    "history": [
      {
        "id": 1042,
        "deviceName": "Samsung Galaxy S24 Ultra (Android 14)",
        "maskedIp": "113.161.xx.xx",
        "userAgent": "FinanceApp/1.2.0 (Android 14)",
        "firstSeenAt": "2026-10-20T08:30:00.000Z",
        "lastActiveAt": "2026-10-23T04:15:22.000Z",
        "isCurrentActive": true
      },
      {
        "id": 980,
        "deviceName": "Samsung Galaxy S24 Ultra (Android 14)",
        "maskedIp": "14.232.xx.xx",
        "userAgent": "FinanceApp/1.2.0 (Android 14)",
        "firstSeenAt": "2026-10-18T14:10:00.000Z",
        "lastActiveAt": "2026-10-19T22:05:10.000Z",
        "isCurrentActive": false
      },
      {
        "id": 812,
        "deviceName": "iPhone 13 (iOS 16.5)",
        "maskedIp": "42.118.xx.xx",
        "userAgent": "FinanceApp/1.0.5 (iOS 16.5)",
        "firstSeenAt": "2026-08-10T09:00:00.000Z",
        "lastActiveAt": "2026-08-15T11:20:00.000Z",
        "isCurrentActive": false
      }
    ]
  }
}
```

### 6.2. Luồng Theo Dõi Truy Cập Thiết Bị Toàn Hệ Thống (Real-time Stream) (Kế hoạch)
* **Endpoint:** `GET /api/admin/devices/recent-access`
* **Query Parameters:** `page=1&limit=50&search=Samsung`
* **Dữ liệu trả về:** Danh sách bản ghi truy cập gần nhất của tất cả người dùng, phục vụ màn hình Giám sát An ninh Tổng thể của Admin.

---

## 7. KIỂM THỬ 2 TẦNG BẮT BUỘC (2-TIER TESTING ARCHITECTURE)

Áp dụng nghiêm ngặt theo **Rule 11 (2-Tier Testing Architecture)** của dự án FinanceManagement:

### 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & GIAO DIỆN (UI Rendering & Payload Contract)
- [ ] **Test 1.1 (Kế hoạch):** Màn hình Admin-web hiển thị đầy đủ bảng danh sách thiết bị: Cột Tên thiết bị, Địa chỉ IP Masked, Thời điểm phát hiện lần đầu, Lần hoạt động cuối.
- [ ] **Test 1.2 (Kế hoạch):** Thẻ Badge trạng thái hiển thị chuẩn: Màu xanh `"Đang hoạt động"` cho thiết bị truy cập trong vòng 15 phút qua; màu xám cho các thiết bị cũ.
- [x] **Test 1.3:** Client-app gửi request có đính kèm chính xác Header `x-device-name` với độ dài $\le 150$ ký tự trên nền tảng Android.

### ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (Real System Impact & DB Persistence)
- [x] **Test 2.1 (Lần đầu truy cập):** Người dùng đăng nhập lần đầu $\longrightarrow$ CSDL PostgreSQL có **chính xác 1 dòng mới** trong `account_device_history` với đúng `idaccount`, `device_name`, và `ip_address` (đã mask).
- [x] **Test 2.2 (Cùng Device & Cùng IP):** Người dùng tiếp tục lướt app / gửi request $\longrightarrow$ **KHÔNG sinh thêm dòng mới**, bản ghi hiện tại được cập nhật timestamp `last_active_at` mới hơn.
- [x] **Test 2.3 (Thay đổi IP - Chuyển mạng Wi-Fi sang 4G):** Người dùng chuyển từ mạng Wi-Fi (IP `113.161.xx.xx`) sang 4G (IP `14.232.xx.xx`) $\longrightarrow$ CSDL **INSERT thêm 1 dòng mới**, bảo toàn 100% dòng cũ của Wi-Fi trước đó.
- [x] **Test 2.4 (Thay đổi Thiết bị - Đăng nhập máy mới):** Người dùng đăng nhập trên điện thoại thứ 2 $\longrightarrow$ CSDL **INSERT thêm 1 dòng mới** mang tên thiết bị mới, dữ liệu thiết bị cũ vẫn nguyên vẹn.
- [x] **Test 2.5 (Bảo vệ Xung đột Khóa ngoại):** Khi tài khoản bị Admin xóa cứng (`DELETE FROM account`) $\longrightarrow$ Toàn bộ lịch sử thiết bị trong `account_device_history` tự động bị xóa theo nhờ cơ chế `CASCADE DELETE`, không bị treo Orphan Records.

---

## 8. CHECKLIST SỐNG CÒN CHO ĐỘI NGŨ PHÁT TRIỂN (GOLDEN RULES)

| STT | Nguyên Tắc Vàng | Trách Nhiệm Phía | Hậu Quả Nếu Vi Phạm |
| :---: | :--- | :---: | :--- |
| **1** | **Bắt buộc gửi Header `x-device-name`** | Client-app | Backend sẽ phải fallback về User-Agent chung chung, Admin không phân biệt được model máy cụ thể. |
| **2** | **Không tự gọi API lấy IP bên thứ ba** | Client-app | Ứng dụng bị chậm, tốn pin, nguy cơ bị crash khi dịch vụ lấy IP bên ngoài gặp sự cố hoặc timeout. |
| **3** | **Tuyệt đối không ghi đè khi đổi IP/Device** | Backend | Vi phạm yêu cầu nghiệp vụ của PO, làm mất lịch sử truy vết an ninh số khi có khiếu nại. |
| **4** | **Phải chạy hàm `maskIp()` trước khi lưu/hiển thị** | Backend | Vi phạm Nghị định 13/2023/NĐ-CP và Rule 9 (Data Security), bị cơ quan quản lý phạt pháp lý. |
| **5** | **Áp dụng Throttle Cache 60s cho request thường** | Backend | CSDL bị dồn ép hàng nghìn truy vấn ghi liên tục khi người dùng lướt app, gây sập pool kết nối. |
| **6** | **Luôn bypass throttle khi đăng nhập Login** | Backend | Đăng nhập từ IP mới nhưng không được ghi nhận ngay lập tức, làm sai lệch cảnh báo an ninh. |
| **7** | **Không đặt ràng buộc `UNIQUE` trên Device/IP** | CSDL / DBA | Gây lỗi văng ngoại lệ `UniqueConstraintViolation` ngay khi người dùng đăng nhập lại lần thứ hai. |
| **8** | **Cắt chuỗi `deviceName` tối đa 150 ký tự** | Cả hai phía | Tránh lỗi tràn bộ đệm `StringDataRightTruncation` (`value too long for type character varying(150)`). |
