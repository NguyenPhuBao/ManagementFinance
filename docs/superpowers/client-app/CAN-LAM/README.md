# 📱 DANH SÁCH CÔNG VIỆC CẦN LÀM PHÍA CLIENT-APP (MOBILE FLUTTER)
### (Client-App Action Items & Implementation Checklist)

> **Mã tài liệu:** `DOC-CLIENT-APP-CAN-LAM-v1.1`  
> **Cơ quan ban hành:** Lead BA + Lead FullStack Cao Cấp + Lead QA Architect  
> **Trạng thái:** 🟢 PO ĐÃ PHÊ DUYỆT ĐỊNH HƯỚNG & YÊU CẦU THỰC THI (Official Source of Truth)  
> **Ngày cập nhật:** 26/10/2026  
> **Thư mục lưu trữ:** `docs/superpowers/client-app/CAN-LAM/README.md`  
> **Các tài liệu nguồn liên quan:**
> - [`docs/superpowers/sync/SYNC_DOCUMENTATION.md`](../../sync/SYNC_DOCUMENTATION.md) (Hợp đồng đồng bộ 6 bảng dữ liệu cốt lõi)
> - [`docs/Admin-web/IP-Device-ClientApp.md`](../../../Admin-web/IP-Device-ClientApp.md) (Đặc tả thu thập thông tin thiết bị & IP)
> - [`docs/Admin-web/Event-Notification-to-ClientApp.md`](../../../Admin-web/Event-Notification-to-ClientApp.md) (Hợp đồng sự kiện Socket.io & 9 mã chốt chặn HTTP)
> - [`Project.md`](../../../../Project.md) (Nguồn ngữ cảnh toàn diện mục 4.26)

---

## 📌 MỤC LỤC
1. [Tổng Quan Các Nhóm Nhiệm Vụ](#1-tổng-quan-các-nhóm-nhiệm-vụ)
2. [Phần I: Đồng Bộ CSDL & Chuẩn Hóa Hợp Đồng Sync Engine (SQLite Drift ➔ Backend REST API)](#2-phần-i-đồng-bộ-csdl--chuẩn-hóa-hợp-đồng-sync-engine)
3. [Phần II: Thu Thập Thông Tin Thiết Bị & Địa Chỉ IP (Device & IP Tracking)](#3-phần-ii-thu-thập-thông-tin-thiết-bị--địa-chỉ-ip)
4. [Phần III: Tiếp Nhận Sự Kiện Thời Gian Thực & Tín Hiệu Chốt Chặn HTTP (Socket.io & Dio Interceptors)](#4-phần-iii-tiếp-nhận-sự-kiện-thời-gian-thực--tín-hiệu-chốt-chặn-http)
5. [Phần IV: Điều Khoản Loại Trừ & Giới Hạn Phạm Vi (Scope Boundary)](#5-phần-iv-điều-khoản-loại-trừ--giới-hạn-phạm-vi)
6. [Bảng Ma Trận & Checklist Nghiệm Thu Từng Hạng Mục (2-Tier Testing Checklist)](#6-bảng-ma-trận--checklist-nghiệm-thu-từng-hạng-mục)

---

## 1. TỔNG QUAN CÁC NHÓM NHIỆM VỤ

Để ứng dụng di động **Client-app (Flutter Mobile)** đồng bộ hoàn hảo với CSDL PostgreSQL Supabase và hệ sinh thái Backend/Admin-web sau các đợt chuẩn hóa mới nhất, đội ngũ phát triển Client-app cần hoàn thiện **3 nhóm nhiệm vụ cốt lõi**:

```
┌────────────────────────────────────────────────────────────────────────┐
│               3 NHÓM NHIỆM VỤ CỐT LÕI CLIENT-APP CẦN LÀM               │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. ĐỒNG BỘ CSDL (SYNC ENGINE)  │ Chuẩn hóa payload 6 bảng: is_deleted, │
│                                │ time_notification: null, pay_status,  │
│                                │ status ví, đọc trực tiếp note decrypt │
├────────────────────────────────┼───────────────────────────────────────┤
│ 2. THU THẬP THIẾT BỊ & IP      │ Gửi Header x-device-name & x-platform │
│                                │ Không tự gọi API lấy IP bên thứ ba    │
├────────────────────────────────┼───────────────────────────────────────┤
│ 3. SỰ KIỆN & CHỐT CHẶN HTTP    │ Thêm 3 enum Socket.io; Bắt mã HTTP    │
│                                │ 503, 429, 403, 401; Bảo lưu SQLite    │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

## 2. PHẦN I: ĐỒNG BỘ CSDL & CHUẨN HÓA HỢP ĐỒNG SYNC ENGINE

Nguồn sự thật chi tiết: [`docs/superpowers/sync/SYNC_DOCUMENTATION.md`](../../sync/SYNC_DOCUMENTATION.md)

### 2.1. Đồng bộ thuộc tính Xóa Mềm (`is_deleted`)
* **Hiện trạng Backend:** Backend Module SYNC (`src/Backend/modules/sync/sync.repository.js`) đã được bổ sung kiểm tra bí danh `is_deleted` (snake_case) bên cạnh `isDeleted` (camelCase) và `delete_at`/`deletedAt` cho cả 6 thực thể (`wallet`, `category`, `goal`, `bill`, `budget`, `transaction`).
* **Việc Client-app cần làm:**
  - Trong `src/Client-app/lib/core/sync/sync_payload_normalizer.dart`: Đảm bảo khi gửi thao tác xóa mềm lên server, payload xuất đúng thuộc tính `is_deleted: true`.
  - Trong `src/Client-app/lib/core/sync/ap_du_lieu_keo_ve.dart`: Khi kéo dữ liệu về (`GET /api/sync/pull`), nếu phát hiện `delete_at != null` hoặc `deleted_at != null`, cập nhật trường trạng thái xóa mềm tương ứng trong SQLite Drift (`isDeleted = true`).

### 2.2. Tắt nhắc nhở Hóa đơn (`time_notification: null`)
* **Hiện trạng Backend:** CSDL PostgreSQL Backend đã chuẩn hóa cột `time_notification` của bảng `bill` cho phép nhận giá trị `null` (đại diện cho việc người dùng chủ động tắt chuông/tắt nhắc nhở kỳ thanh toán).
* **Việc Client-app cần làm:**
  - Khi người dùng tắt nhắc nhở trên giao diện Hóa đơn: Gửi `time_notification: null` (hoặc `Value(null)` trong Drift SQLite) thay vì gửi chuỗi rỗng `""` hay gán cứng `"3"`.
  - Nhánh kéo về: Nếu nhận `time_notification: null`, lưu an toàn giá trị `null` vào SQLite Drift mà không bị crash ép kiểu sang chuỗi.

### 2.3. Hỗ trợ trạng thái Hóa đơn Bỏ qua kỳ (`pay_status: 'Skipped'`)
* **Hiện trạng Backend:** CSDL hỗ trợ 4 trạng thái hóa đơn chuẩn: `'Pending'`, `'Payed'`, `'Overdue'`, `'Skipped'`.
* **Việc Client-app cần làm:**
  - Kiểm tra `BillDao` và UI Hóa đơn hỗ trợ enum/giá trị `'Skipped'`.
  - Khi người dùng chọn "Bỏ qua kỳ này": Đẩy `pay_status: 'Skipped'` lên Backend.
  - Khi kéo về: Xử lý `'Skipped'` là kỳ chưa trả tiền (`isPaid = false`) nhưng không hiển thị cảnh báo nợ quá hạn khẩn cấp.

### 2.4. Duy trì trạng thái Lưu trữ Ví (`status: 'Active'` / `'Inactive'`)
* **Hiện trạng Backend:** Bảng ví `wallets` gồm đúng **13 trường** (đã qua kiểm thử `sync_payload_contract_test.dart`), trong đó có trường `status` gồm hai giá trị: `'Active'` và `'Inactive'`.
* **Việc Client-app cần làm:**
  - Đảm bảo SQLite `WalletsCompanion` duy trì trường `status`.
  - Khi người dùng thực hiện tính năng "Lưu trữ ví" (Archive Wallet), gửi `status: 'Inactive'`.
  - Khi ví hoạt động bình thường, gửi `status: 'Active'`.

### 2.5. Cơ chế Đọc trực tiếp trường Ghi chú (`note`)
* **Hiện trạng Backend:** Backend tự động mã hóa AES-256 At-Rest cho trường `note` của Giao dịch, Ngân sách, Hóa đơn và Mục tiêu. Khi Client gọi `GET /api/sync/pull`, Backend **đã tự động giải mã plaintext** trường `note` qua kết nối bảo mật HTTPS TLS 1.3.
* **Việc Client-app cần làm:**
  - Phía Client-app **KHÔNG** cần tự giải mã AES thủ công. Đọc trực tiếp trường `note` nhận được từ phản hồi `/sync/pull` và lưu vào SQLite Drift.

### 2.6. Bảng đối soát số trường của 6 thực thể Sync cốt lõi

| Thực thể | Số trường hợp đồng | Các trường bắt buộc có mặt trong SQLite & Payload | Ghi chú kỹ thuật quan trọng |
|---|:---:|---|---|
| **Wallets** | **13 trường** | `id`, `idaccount`, `name`, `type`, `balance` (hợp đồng 1 chiều Push), `currency`, `icon`, `color`, `is_default`, `is_deleted`, `include_in_total`, `status` (`'Active'`/`'Inactive'`), `update_at`. | `balance` chỉ đẩy 1 chiều (G37), kéo về thôi đọc (`Value.absent()`). |
| **Transactions** | **13 trường** | `id`, `idaccount`, `walletId`/`idwallet`, `categoryId`/`idcategory`, `idwallet_transfer`, `amount` (âm là Chi, dương là Thu), `type` (`'Transaction'`/`'Transfer'`), `note` (đã giải mã), `dateTransaction`/`date_transaction`, `idgoal`, `idbill`, `is_deleted`, `update_at`. | `type` client có 3 loại: `thu`, `chi`, `transfer`. Normalizer đổi `chi` thành `Transaction` + số âm; `transfer` đổi thành `Transfer`. |
| **Categories** | **12 trường** | `id`, `create_by`/`idaccount`, `name_category`/`name`, `classify` (`'Thu'`/`'Chi'`/`'Vay/no'`), `is_default`, `is_group`/`isGroup`, `idgroup`/`parentId`, `icon`, `color`, `keyword`, `is_deleted`, `update_at`. | Nhóm công nợ chuẩn hóa lưu trữ là `'Vay/no'`. `is_group` và `idgroup` bảo toàn cấu trúc cây nhóm. |
| **Budgets** | **17 trường** | `id`, `idaccount`, `idcategory`, `total_amount`, `spent`, `threshold_warning_amount`, `threshold_warning_percent`, `over_spending` (`'Stop'`/`'Over'`), `over_amount`, `start`, `end`, `recurrence`, `time_recurrence`, `nexttime_recurrence`, `note`, `is_deleted`, `update_at`. | Không dùng `period` (đã thay bằng `time_recurrence`). Số tiền là `total_amount`. |
| **Bills** | **21 trường** | `id`, `idaccount`, `idwallet`, `idcategory`, `name`, `amount`, `start_date`, `due_date`, `pay_status` (`'Pending'`/`'Payed'`/`'Overdue'`/`'Skipped'`), `recurrence`, `time_recurrence`, `time_notification`, `icon`, `color`, `note`, `previous_bill_id`, `period_end`, `auto_pay`, `anchor_day`, `is_deleted`, `update_at`. | `time_notification` nhận `null` để tắt chuông. `pay_status` hỗ trợ `'Skipped'`. `period_end` gửi 00:00 UTC của ngày cục bộ. |
| **Goals** | **22 trường** | `id`, `idaccount`, `idwallet`, `name`, `target_amount`, `current_amount`, `start_date`, `target_date`, `cycle_take_money`, `time_cycle_take_money`, `status_complete` (`'True'`/`'False'`), `recurrence`, `time_recurrence`, `icon`, `color`, `note`, `auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`, `priority`, `is_deleted`, `update_at`. | Ba cột `auto_deposit_*` đi cùng nhau. `priority` nếu chưa sắp thì đẩy `null` (không gửi 0). |

---

## 3. PHẦN II: THU THẬP THÔNG TIN THIẾT BỊ & ĐỊA CHỈ IP

Nguồn sự thật chi tiết: [`docs/Admin-web/IP-Device-ClientApp.md`](../../../Admin-web/IP-Device-ClientApp.md)

### 3.1. Header HTTP Bắt Buộc: `x-device-name` và `x-platform`
* **Mục đích:** Giúp Admin-web theo dõi danh sách thiết bị truy cập trong tab "Lịch sử Thiết bị & IP" (`account_device_history`), phát hiện đăng nhập lạ hoặc hành vi gian lận. CORS Backend (`src/Backend/app.js`) đã cho phép hai headers này.
* **Việc Client-app cần làm:**
  1. Thêm dependency trong `pubspec.yaml`:
     ```yaml
     dependencies:
       device_info_plus: ^10.1.0
     ```
  2. Xây dựng service lấy thông tin thiết bị `DeviceInfoService`:
     ```dart
     import 'dart:io';
     import 'package:device_info_plus/device_info_plus.dart';

     class DeviceInfoService {
       static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

       static Future<String> getDeviceName() async {
         try {
           if (Platform.isAndroid) {
             final android = await _plugin.androidInfo;
             return 'Android ${android.manufacturer} ${android.model}'.trim();
           } else if (Platform.isIOS) {
             final ios = await _plugin.iosInfo;
             return 'iOS ${ios.name} (${ios.utsname.machine})'.trim();
           }
           return Platform.operatingSystem;
         } catch (_) {
           return 'Unknown Device';
         }
       }

       static String getPlatformName() {
         return Platform.operatingSystem.toLowerCase(); // 'android' | 'ios'
       }
     }
     ```
  3. Cấu hình Dio Interceptor gắn Header vào **tất cả request API**:
     ```dart
     class DeviceHeaderInterceptor extends Interceptor {
       final String deviceName;
       final String platform;
       DeviceHeaderInterceptor({required this.deviceName, required this.platform});

       @override
       void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
         // Cắt ngắn tối đa 150 ký tự để chống tràn bộ đệm CSDL
         final safeName = deviceName.length > 150 ? deviceName.substring(0, 150) : deviceName;
         options.headers['x-device-name'] = safeName;
         options.headers['x-platform'] = platform;
         super.onRequest(options, handler);
       }
     }
     ```

### 3.2. Tuyệt Đối KHÔNG Tự Gọi API Bên Thứ Ba Lấy IP
* ⚠️ **Nguyên tắc sống còn:** Client-app **tuyệt đối KHÔNG** tự gọi các dịch vụ lấy IP công cộng bên ngoài (như `api.ipify.org`, `ipinfo.io`).
* **Lý do:** Làm chậm ứng dụng, tốn pin, gây lỗi crash khi dịch vụ ngoài timeout, và vi phạm quyền riêng tư.
* **Cơ chế Backend:** Backend tự động trích xuất địa chỉ IP trực tiếp từ kết nối TCP socket và mặt nạ hóa an toàn (`113.161.xx.xx`) theo đúng Nghị định 13/2023/NĐ-CP trước khi ghi nhận vào CSDL `account_device_history`.

---

## 4. PHẦN III: TIẾP NHẬN SỰ KIỆN THỜI GIAN THỰC & TÍN HIỆU CHỐT CHẶN HTTP

Nguồn sự thật chi tiết: [`docs/Admin-web/Event-Notification-to-ClientApp.md`](../../../Admin-web/Event-Notification-to-ClientApp.md)

### 4.1. Đối chiếu Hiện trạng Enum Sự Kiện Socket.io trong `realtime_event.dart`
Rà soát mã nguồn thực tế `src/Client-app/lib/core/realtime/realtime_event.dart`:

| Sự Kiện Backend | Enum Hiện Tại Trên Client | Hiện Trạng Mã Nguồn Client-app | Hành Động Cần Thực Hiện |
|---|:---:|:---:|---|
| `sync.completed` | `RealtimeEvent.dongBoXong` | ✅ **ĐÃ CÓ** | Giữ nguyên (kích hoạt kéo Delta Pull ngầm). |
| `ocr.completed` | `RealtimeEvent.ocrXong` | ✅ **ĐÃ CÓ** | Giữ nguyên (hiện Toast bóc tách xong). |
| `ocr.duplicate` | `RealtimeEvent.ocrTrung` | ✅ **ĐÃ CÓ** | Giữ nguyên (hiện Toast cảnh báo trùng). |
| `account.upgraded` / `permissions_updated` | `RealtimeEvent.taiKhoanNangCap` | ✅ **ĐÃ CÓ** | Giữ nguyên (gọi làm mới thông tin gói). |
| `account.downgraded` | `RealtimeEvent.taiKhoanHaCap` | ✅ **ĐÃ CÓ** | Giữ nguyên (gọi làm mới gói về Basic). |
| `payment.*` (6 sự kiện đơn hàng) | `RealtimeEvent.donThanhToanDoi` | ✅ **ĐÃ CÓ** | Giữ nguyên (màn hình đơn hỏi lại server). |
| **`system.maintenance_changed`** | — | ❌ **CHƯA CÓ** | **CẦN BỔ SUNG:** `RealtimeEvent.baoTriThayDoi` |
| **`system.broadcast`** | — | ❌ **CHƯA CÓ** | **CẦN BỔ SUNG:** `RealtimeEvent.thongBaoHeThong` |
| **`account.countdown`** | — | ❌ **CHƯA CÓ** | **CẦN BỔ SUNG:** `RealtimeEvent.demNguocXoa` |

* **Bổ sung 3 enum mới vào `RealtimeEvent`:**
  ```dart
  enum RealtimeEvent {
    ocrXong,
    ocrTrung,
    dongBoXong,
    taiKhoanNangCap,
    taiKhoanHaCap,
    donThanhToanDoi,
    
    // ── 3 SỰ KIỆN BỔ SUNG MỚI ──────────────────────────────────────────────
    baoTriThayDoi,         // system.maintenance_changed (Khẩn cấp / Định kỳ)
    thongBaoHeThong,       // system.broadcast (Thông báo toàn mạng)
    demNguocXoa,           // account.countdown (Đếm ngược 30 ngày xóa tài khoản)
  }
  ```
* **Bổ sung vào `realtimeEventFromName(String name)`:**
  ```dart
  case 'system.maintenance_changed':
    return RealtimeEvent.baoTriThayDoi;
  case 'system.broadcast':
    return RealtimeEvent.thongBaoHeThong;
  case 'account.countdown':
    return RealtimeEvent.demNguocXoa;
  ```
* **Hành vi xử lý tương ứng trên Client-app:**
  - `baoTriThayDoi`: Nhận tín hiệu bảo trì khẩn cấp $\longrightarrow$ hiển thị `MaintenanceScreen` toàn màn hình. Khi bảo trì kết thúc $\longrightarrow$ đóng màn hình bảo trì.
  - `thongBaoHeThong`: Hiển thị SnackBar/Banner theo cấp độ (`INFO`, `WARNING`, `CRITICAL`) và lưu vào SQLite notification.
  - `demNguocXoa`: Hiển thị Banner cam cảnh báo số ngày đếm ngược còn lại tại Trang chủ.

### 4.2. Tiếp nhận 5 Mã Chốt Chặn HTTP trong Dio Interceptor (`MayChuInterceptor` / `AuthInterceptor`)
Trong `src/Client-app/lib/core/api/interceptors/`:
* Client-app hiện đã có `MayChuInterceptor` (bắt 503 `MAINTENANCE_MODE` và 403 `AIOPS_QUARANTINED` qua `TrangThaiMayChu`, cùng 403 `FEATURE_DISABLED` qua `_xetTatQuyen`).
* **Cần hoàn thiện bổ sung 2 mã chốt chặn bảo vệ hạ tầng còn lại:**
  1. **HTTP 503 `SERVER_OVERLOADED` (Load Shedding):**
     - Khi Event Loop lag $> 100\text{ms}$, server cắt tải và gửi kèm header `Retry-After: 5`.
     - Phản ứng: Đọc `Retry-After`, hiển thị thông báo nhẹ và tự động xếp lịch thử lại sau thời gian chỉ định.
  2. **HTTP 429 `RETRY_LIMIT_EXCEEDED` (Retry Storm Guard):**
     - Khi client lặp lại request quá 3 lần thất bại liên tiếp, server trả về 429.
     - Phản ứng: Lập tức ngắt chu kỳ lặp tự động, thông báo người dùng tạm nghỉ.
  3. **HTTP 401 `ACCOUNT_INACTIVE` & `ACCOUNT_DELETED` (Cưỡng chế đăng xuất an toàn):**
     - ⚠️ **QUY TẮC BẢO TOÀN DỮ LIỆU SQLITE (Rule G89):** Tuyệt đối **KHÔNG** xóa trắng cơ sở dữ liệu SQLite Drift trên thiết bị khi nhận mã này.
     - Chỉ xóa token phiên làm việc JWT trong `FlutterSecureStorage` và điều hướng về màn hình Đăng nhập kèm Dialog thông báo lý do (`reason_inactive`). Dữ liệu SQLite được bảo lưu an toàn trên máy phòng trường hợp có giao dịch ngoại tuyến chưa kịp đồng bộ.

---

## 5. PHẦN IV: ĐIỀU KHOẢN LOẠI TRỪ & GIỚI HẠN PHẠM VI

> ⚠️ **LƯU Ý DÀNH RIÊNG CHO ĐỘI NGŨ CLIENT-APP:**  
> 1. **Mục 50 ([`GIA_DINH_NEN_MONG.md`](../../backend/CAN-LAM/GIA_DINH_NEN_MONG.md) - Tính năng Gia đình nền móng):** Theo quyết định chính thức từ Product Owner (PO), tính năng Gia đình đã được **hoãn lại để triển khai ở giai đoạn tiếp theo**. Đội ngũ Client-app **CHƯA triển khai** các bảng `household`, `household_member` và các giao diện gia đình trong đợt này.
> 2. **Module Ngân hàng đối tác (`bank_transaction`):** Đã dừng hoàn toàn theo quyết định ngày 2026-09-18, bỏ qua mọi sự kiện socket liên quan đến bank.

---

## 6. BẢNG MA TRẬN & CHECKLIST NGHIỆM THU TỪNG HẠNG MỤC

Áp dụng quy tắc kiểm thử 2 tầng **(Rule 11 — 2-Tier Testing Architecture)**:

| STT | Hạng mục công việc | File mã nguồn Client-app phụ trách | Tầng 1: Hiển thị & Thao tác UI | Tầng 2: Tác động Hệ thống thực tế | Trạng thái |
|:---:|---|---|---|---|:---:|
| **1** | Gửi Header `x-device-name` & `x-platform` | `core/network/device_header_interceptor.dart` | Khởi tạo thành công service không văng lỗi | Backend ghi nhận chính xác 1 dòng vào `account_device_history` | ⏳ Chờ làm |
| **2** | Đồng bộ Xóa mềm `is_deleted` | `core/sync/sync_payload_normalizer.dart` | Thao tác Xóa trên UI hiển thị dialog thành công | DB PostgreSQL cập nhật `delete_at != null`, không xóa cứng | ⏳ Chờ làm |
| **3** | Tắt nhắc hóa đơn `null` | `features/bills/bill_form_screen.dart` | Switch "Nhắc nhở" tắt mượt mà | Payload sync gửi `time_notification: null`, server lưu `null` | ⏳ Chờ làm |
| **4** | Hóa đơn bỏ qua kỳ `Skipped` | `features/bills/bill_detail_screen.dart` | Nút "Bỏ qua kỳ" đổi badge sang Xám/Vàng | `pay_status` lưu `'Skipped'`, không tính vào nợ quá hạn | ⏳ Chờ làm |
| **5** | Lưu trữ ví `Inactive` | `features/wallets/wallet_detail_screen.dart` | Nút "Lưu trữ ví" ẩn ví khỏi danh sách chính | `status` gửi `'Inactive'`, tổng số dư loại trừ ví này | ⏳ Chờ làm |
| **6** | Đọc `note` đã giải mã | `core/sync/ap_du_lieu_keo_ve.dart` | Giao diện hiển thị rõ chữ tiếng Việt có dấu | SQLite Drift lưu trữ plaintext, không vướng tiền tố `enc:` | ⏳ Chờ làm |
| **7** | Bổ sung 3 enum `RealtimeEvent` mới | `core/realtime/realtime_event.dart` | Nhận Socket không throw `ArgumentError` | Kích hoạt đúng Cubit/State cập nhật UI thời gian thực | ⏳ Chờ làm |
| **8** | Chốt chặn 503 Bảo trì | `core/api/interceptors/may_chu_interceptor.dart` | Mở `MaintenanceScreen` khóa tương tác | Chặn gọi thêm API ghi, bảo vệ CSDL | ⏳ Chờ làm |
| **9** | Chốt chặn 503 Quá tải & 429 Retry | `core/api/interceptors/may_chu_interceptor.dart` | Hiển thị Toast thông báo đếm ngược thử lại | Dừng bão request lặp, bảo vệ hạ tầng | ⏳ Chờ làm |
| **10**| Chốt chặn 403 AIOps | `core/api/interceptors/may_chu_interceptor.dart` | Hiển thị Dialog cảnh báo an ninh Sentinel | Ngăn spam request khi IP bị đưa vào cách ly | ⏳ Chờ làm |
| **11**| Bảo lưu SQLite khi 401 | `core/api/interceptors/buoc_dang_xuat.dart` | Đăng xuất về Login kèm Dialog lý do | SQLite local Drift được bảo lưu 100%, không bị DROP table | ⏳ Chờ làm |

---

> 🎯 **Cam kết chất lượng:** Mọi thắc mắc trong quá trình thực hiện, đội ngũ Client-app có thể đối chiếu trực tiếp với các test suite mẫu tại Backend (`src/Backend/tests/unit/sync.engine.v2.test.js` và `Test/test_data_security_encryption_and_masking.js`) để đảm bảo hệ thống đạt độ ổn định tuyệt đối (Zero Regressions).
