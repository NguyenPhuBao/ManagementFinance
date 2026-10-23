# 📋 KẾ HOẠCH TRIỂN KHAI: ĐỒNG BỘ SQLITE, HỢP ĐỒNG SỰ KIỆN CLIENT-APP & THEO DÕI THIẾT BỊ / IP

> **Mã kế hoạch:** `PLAN-SYNC-DEVICE-EVENT-20261023`  
> **Người lập:** Lead BA + Lead FullStack Cao Cấp + QA Architect  
> **Trạng thái:** 🟡 CHỜ PRODUCT OWNER (PO) PHÊ DUYỆT  
> **Tài liệu nguồn sự thật tác động:**  
> - `docs/superpowers/sync/SYNC_DOCUMENTATION.md`  
> - `docs/Admin-web/Event-Notification-to-ClientApp.md`  
> - `src/Backend/prisma/schema.prisma`  
> - `src/Backend/modules/auth/`  
> - `src/Client-app/`  

---

## 🏛️ I. TỔNG QUAN YÊU CẦU TỪ PO & PHÂN TÍCH 2 CHIỀU (DUAL-AXIS)

PO yêu cầu thực thi 3 hạng mục cốt lõi:
1. **Module SYNC & CSDL:** Cập nhật lại các trường cần phải đồng bộ lên SQLite tại Module SYNC và ghi nhận tại `docs/superpowers/sync/SYNC_DOCUMENTATION.md` để phía Client-app sửa đổi bổ sung.
2. **Sự kiện & Thông báo Backend/Admin:** Cập nhật toàn bộ các thông báo và sự kiện xuất phát từ Backend và Admin-web vào `docs/Admin-web/Event-Notification-to-ClientApp.md` để phía Client-app sửa đổi bổ sung phương thức tiếp nhận và giải quyết.
3. **Thu thập Thiết bị & IP phía Client-app:** Thu thập Tên thiết bị và IP người dùng, mỗi lần đăng nhập hay truy cập vào app đều phải ghi nhận lại IP và Tên thiết bị 1 lần. Nếu IP hoặc Tên thiết bị có thay đổi thì ghi dòng mới vào CSDL chứ không ghi đè, tránh làm mất dấu vết người dùng trước đó. Kiểm tra xung đột ràng buộc CSDL.

### 1. Phân Tích Chiều Ngang (Horizontal Impact Analysis)
- **Cơ sở dữ liệu (Database Schema):**
  + 6 Bảng đồng bộ cốt lõi (`category`, `wallet`, `budget`, `bill`, `goal`, `transaction`) đều đã có cột `Server_update_at` (Migration 20 + 21) để phục vụ Delta Pull. Cần rà soát từng trường thuộc tính của 6 bảng giữa PostgreSQL và SQLite Drift của Client-app.
  + Kiểm tra bảng `refreshtoken`: Đang có `device_name` (VARCHAR 100), `ip_address` (VARCHAR 256), `token_hash` (UNIQUE).
  + Khảo sát bảng lưu vết thiết bị: Nếu ghi nhận mỗi lần truy cập đổi IP/Device, bảng `refreshtoken` không phù hợp vì gắn với vòng đời JWT Token (bị thu hồi `status: true` hoặc dọn dẹp định kỳ). Cần một cấu trúc lưu trữ chuyên biệt `account_device_history` để bảo toàn vĩnh viễn lịch sử truy vết mà không xung đột ràng buộc.
- **Giao tiếp Hệ thống & APIs:**
  + Client-app gửi kèm Tên thiết bị qua Custom Header HTTP `x-device-name` (hoặc body lúc login/refresh).
  + Backend tự động trích xuất IP qua `req.ip || req.headers['x-forwarded-for']` và mặt nạ hóa theo Nghị định 13/2023/NĐ-CP (`maskIp`).
  + Endpoint đăng nhập `POST /api/auth/login` và middleware xác thực `authenticateToken` sẽ thực thi logic kiểm tra chênh lệch (Diff Check) và ghi nhận vào CSDL.
- **Tác động Phía Client-app (Flutter Mobile):**
  + Client-app sử dụng `device_info_plus` (hoặc `Platform.operatingSystem` + model) để lấy tên thiết bị.
  + Dio Interceptor tự động gắn header `x-device-name` cho mọi request.
  + Module SYNC Client-app đọc `SYNC_DOCUMENTATION.md` để khớp 100% các cột bảng SQLite Drift.
  + Module Realtime Client-app đọc `Event-Notification-to-ClientApp.md` để bắt 23+ sự kiện Socket & HTTP signals.

### 2. Phân Tích Chiều Sâu (Vertical / Deep-Impact Analysis)
- **Tính toàn vẹn dữ liệu lịch sử:** Không sửa/xóa các bản ghi thiết bị cũ; mỗi khi IP hoặc Device thay đổi, tạo bản ghi mới (`INSERT`), đảm bảo lịch sử kiểm toán an ninh số (Digital Forensics) nguyên vẹn 100%.
- **Chống bão ghi CSDL (Write Storm Prevention):** Khi người dùng lướt app liên tục (hàng trăm request trong vài phút), nếu cùng 1 IP và cùng 1 Device $\rightarrow$ **chỉ cập nhật timestamp hoạt động gần nhất (`last_active_at`) hoặc bỏ qua**, tuyệt đối không INSERT hàng trăm dòng trùng lặp vào CSDL.
- **Bảo vệ CSDL (DB Guard Rule 10):** Tuyệt đối không chạy `prisma migrate dev` hoặc `prisma db push` trên Supabase Cloud. Viết file SQL migration DDL chuẩn vào `src/Backend/database/` và cập nhật Prisma schema qua `prisma generate`.
- **Bảo mật dữ liệu (Data Security Rule 9):** IP lưu trữ được mask chuẩn (`113.161.xx.xx`) theo Nghị định 13/2023/NĐ-CP, bảo vệ quyền riêng tư người dùng.

---

## 📐 II. CHI TIẾT CÁC HẠNG MỤC THỰC THI

### HẠNG MỤC 1: CẬP NHẬT `SYNC_DOCUMENTATION.md`
Cập nhật toàn diện file `docs/superpowers/sync/SYNC_DOCUMENTATION.md` theo hợp đồng mới nhất:
1. **Ví tài chính (`wallets` - 13 trường):**
   - `id` (UUID v4), `name`, `type`, `balance` (⚠️ hợp đồng 1 chiều: push gửi, pull bỏ qua để tránh ghi đè cache tổng sổ), `currency`, `icon`, `color`, `is_default`, `is_deleted`, `include_in_total`, `status` (`Active` / `Inactive`), `update_at`, `idaccount`.
2. **Giao dịch Thu/Chi (`transactions` - 13 trường):**
   - `id`, `walletId`, `categoryId`, `idwallet_transfer` (ví đích chuyển khoản), `amount` (dấu âm là chi, dương là thu), `type` (`Transaction` / `Transfer`), `note` (được mã hóa at-rest an toàn), `dateTransaction`, `is_deleted`, `update_at`, `idaccount`, `idgoal` (khoá ngoại `fk_transaction_goal`), `idbill` (khoá ngoại `fk_transaction_bill`).
   - ⚠️ Quy tắc thứ tự đẩy: `goal` và `bill` phải đẩy TRƯỚC `transaction`.
3. **Danh mục Chi tiêu (`categories` - 12 trường + `keyword`):**
   - `id`, `name`, `namecategory`, `classify` (`Thu` / `Chi` / `Vay/no`), `icon`, `color`, `is_default` (bảo vệ danh mục hệ thống), `is_deleted`, `isGroup` (`is_group`), `parentId` (`idgroup` - bảo toàn cấu trúc cây nhóm), `update_at`, `idaccount`, `keyword` (chuỗi từ khóa AI NLP phục vụ nhận diện giao dịch).
4. **Ngân sách Chi tiêu (`budgets` - 17 trường):**
   - `id`, `idcategory`, `total_amount`, `spent`, `threshold_warning_amount`, `threshold_warning_percent` (ngưỡng % cảnh báo), `over_spending`, `over_amount`, `start`, `end`, `recurrence`, `time_recurrence` (`Day`, `Week`, `Month`, `Quarter`, `Year`), `nexttime_recurrence`, `note`, `is_deleted`, `update_at`, `idaccount`.
5. **Hóa đơn & Dịch vụ (`bills` - 21 trường):**
   - `id`, `idwallet`, `idcategory`, `name`, `amount`, `start_date`, `due_date`, `pay_status` (`Pending`, `Payed`, `Skipped`, `Overdue`), `recurrence`, `time_recurrence`, `time_notification`, `icon`, `color`, `note`, `is_deleted`, `update_at`, `idaccount`, `previous_bill_id`, `anchor_day`, `period_end` (ân hạn hóa đơn tách hạn trả), `auto_pay` (công tắc tự động trả hóa đơn).
6. **Mục tiêu Tiết kiệm (`goals` - 22 trường):**
   - `id`, `name`, `target_amount`, `current_amount`, `start_date`, `target_date`, `idwallet`, `cycle_take_money`, `time_cycle_take_money`, `status_complete`, `recurrence`, `time_recurrence`, `icon`, `color`, `note`, `is_deleted`, `update_at`, `idaccount`, `auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`, `priority` (thứ tự ưu tiên kéo thả).
7. **Cơ chế Server_update_at & Delta Pull (Migration 20 + 21):**
   - Khóa kéo theo giờ server `Server_update_at` UTC, kẹp thời gian nóng `pulledAt - 2 phút`, đảm bảo không mất giao dịch giữa 2 thiết bị.

---

### HẠNG MỤC 2: CẬP NHẬT `Event-Notification-to-ClientApp.md`
Cập nhật toàn bộ các sự kiện và thông báo từ Backend/Admin tới Client-app:
1. **Nhóm Sự kiện Real-Time Socket.IO (15 sự kiện):**
   - `account.force_logout` (Lý do `ACCOUNT_INACTIVE` kèm câu thông báo của Admin, hoặc `ACCOUNT_DELETED` dọn sạch SQLite).
   - `system.maintenance_changed` (`active`, `isEmergency`, `reason`, `activatedAt`, `activatedBy`).
   - `system.broadcast` (`id`, `title`, `message`, `level` INFO/WARN/CRITICAL, `timestamp`).
   - `account.permissions_updated` (Đồng bộ ma trận 4 Trụ cột quyền hạn).
   - `account.upgraded` & `account.downgraded` (Nâng cấp/hạ cấp gói Basic/Premium).
   - `account.countdown` (Đếm ngược 30 ngày xóa tài khoản).
   - `sync.completed` (Kích hoạt delta sync ngay khi máy khác push xong).
   - `ocr.completed` & `ocr.duplicate` (Thông báo kết quả quét hóa đơn OCR).
   - `user.notification` (Tin nhắn hộp thư cá nhân).
   - `payment.overpaid_confirmation` & `payment.underpaid_warning` (Biến động đơn PayOS).
   - `payment.refunded` (Thông báo hoàn tiền đính kèm minh chứng).
   - `payment.order_expired` (Hủy đơn hàng quá 10 phút).
2. **Nhóm Tín Hiệu Chốt Chặn HTTP/API (8 tín hiệu):**
   - `503 MAINTENANCE_MODE`: Chế độ bảo trì hệ thống.
   - `503 SERVER_OVERLOADED`: Load shedding khi lag Event Loop > 100ms.
   - `429 RETRY_LIMIT_EXCEEDED`: Retry storm guard.
   - `403 AIOPS_QUARANTINED`: Tường lửa Sentinel phong tỏa IP (kèm `reason` và `quarantineExpiresAt`).
   - `403 FEATURE_DISABLED`: Chặn tính năng vượt giới hạn gói cước Basic.
   - `401 ACCOUNT_INACTIVE`: Cưỡng chế đăng xuất do tài khoản bị Admin khóa.
   - `401 ACCOUNT_DELETED`: Cưỡng chế đăng xuất do tài khoản bị xóa mềm.
   - `400 PENDING_DELETE_PROTECTED`: Chặn mọi thao tác sửa/xóa trên tài khoản đang chờ thanh lý 30 ngày.

---

### HẠNG MỤC 3: KIỂM TRA RÀNG BUỘC CSDL & GIẢI PHÁP LƯU VẾT THIẾT BỊ / IP

#### 1. Kiểm tra Xung đột Ràng buộc CSDL (Database Constraint Conflict Check)
| Bảng CSDL | Ràng buộc hiện có | Đánh giá rủi ro xung đột | Kết luận |
|---|---|---|---|
| `account` | `Idaccount` (PK), `Email` (UNIQUE) | Chỉ có 1 dòng cho mỗi tài khoản. Nếu ghi trực tiếp vào `account` sẽ bị **ghi đè** mất dấu vết lịch sử. | ❌ Không lưu vào `account` |
| `refreshtoken` | `Idtoken` (PK), `Token_hash` (UNIQUE) | Ràng buộc `token_hash UNIQUE`. Khi user gọi API bình thường bằng access token (không refresh), bảng này không được gọi. Khi token bị thu hồi hoặc xóa định kỳ, dữ liệu lịch sử sẽ bị mất. | ⚠️ Chỉ lưu được phiên token, không lưu được lịch sử truy cập app liên tục |
| **`account_device_history`** *(Đề xuất mới)* | `id (BIGSERIAL PK)`, `idaccount (FK account)` | **KHÔNG có ràng buộc UNIQUE trên Device hoặc IP**. Khóa ngoại `idaccount` cascade xóa khi tài khoản bị xóa vật lý. | ✅ **HOÀN TOÀN KHÔNG XUNG ĐỘT**, bảo toàn lịch sử 100% |

#### 2. Thiết Kế Bảng `account_device_history` (PostgreSQL)
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

#### 3. Cơ Chế Thu Thập & Ghi Nhận Không Ghi Đè (Diff Check Logic)
Mỗi khi người dùng **Đăng nhập** hoặc **Gửi request truy cập vào app**:
```javascript
// 1. Trích xuất Tên thiết bị và IP hiện tại
const currentDevice = req.headers['x-device-name'] || req.body?.deviceName || 'Thiết bị không xác định';
const currentRawIp = req.ip || req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || '127.0.0.1';
const currentMaskedIp = maskIp(currentRawIp);

// 2. Tìm bản ghi thiết bị gần nhất của tài khoản này
const latestRecord = await prisma.account_device_history.findFirst({
  where: { idaccount: targetIdaccount },
  orderBy: { last_active_at: 'desc' }
});

// 3. Kiểm tra biến động (Diff Check)
if (!latestRecord || latestRecord.device_name !== currentDevice || latestRecord.ip_address !== currentMaskedIp) {
  // IP hoặc Tên thiết bị CÓ THAY ĐỔI -> GHI DÒNG MỚI (INSERT)
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
  logger.info('[DeviceTracker] Ghi nhận thiết bị/IP mới cho tài khoản', { idaccount: targetIdaccount, device: currentDevice, ip: currentMaskedIp });
} else {
  // Cùng thiết bị và cùng IP -> Cập nhật thời gian hoạt động gần nhất (không tạo dòng rác trùng lặp)
  await prisma.account_device_history.update({
    where: { id: latestRecord.id },
    data: { last_active_at: new Date() }
  });
}
```

#### 4. Phía Client-app (Flutter)
1. Thêm package `device_info_plus: ^10.1.0` vào `pubspec.yaml` (hoặc module đọc thông tin OS).
2. Tạo Service `DeviceInfoService`: Lấy tên thiết bị (ví dụ: `"Samsung Galaxy S24 (Android 14)"` hoặc `"iPhone 15 Pro (iOS 17.5)"`).
3. Gắn `x-device-name` vào Interceptor của `DioClient` để gửi kèm trong mọi request đăng nhập và truy cập app.

---

## 🧪 III. KẾ HOẠCH KIỂM THỬ 2 TẦNG (2-TIER TESTING ARCHITECTURE)

- **Tầng 1 (Kiểm thử Giao diện & Định dạng Payload):**
  + Kiểm tra Client-app gửi đúng header `x-device-name`.
  + Kiểm tra hợp đồng `sync_payload_contract_test.dart` và các test case đồng bộ.
- **Tầng 2 (Kiểm thử Tác động Hệ thống & CSDL):**
  + Case 1: Lần đầu đăng nhập $\rightarrow$ CSDL có 1 dòng mới trong `account_device_history`.
  + Case 2: Đăng nhập lại trên CÙNG thiết bị và CÙNG IP $\rightarrow$ KHÔNG sinh dòng mới, chỉ cập nhật `last_active_at`.
  + Case 3: Người dùng đổi sang mạng Wifi khác (IP thay đổi) $\rightarrow$ CSDL sinh thêm 1 DÒNG MỚI, dòng cũ vẫn giữ nguyên.
  + Case 4: Người dùng đăng nhập trên thiết bị thứ 2 (Device khác) $\rightarrow$ CSDL sinh thêm 1 DÒNG MỚI, dòng của thiết bị cũ vẫn nguyên vẹn.
  + Case 5: Thẩm tra không có lỗi xung đột Unique constraint hay Foreign key.

---

## 📅 IV. CÁC BƯỚC THỰC HIỆN TUẦN TỰ (4-PHASE WORKFLOW)

1. **Bước 1:** Trình bản kế hoạch cho PO phê duyệt (Quy tắc Tối cao 1).
2. **Bước 2:** Cập nhật 2 tài liệu nguồn sự thật:
   - `docs/superpowers/sync/SYNC_DOCUMENTATION.md`
   - `docs/Admin-web/Event-Notification-to-ClientApp.md`
3. **Bước 3:** Tạo file SQL migration DDL `35_create_account_device_history_table.sql`, cập nhật Prisma Schema và chạy `rtk npm run prisma:generate`.
4. **Bước 4:** Cập nhật Backend tracking logic (trong `auth.service.js` và middleware).
5. **Bước 5:** Hướng dẫn cấu hình phía Client-app (`device_info_plus` và Dio interceptor).
6. **Bước 6:** Viết bộ test 2 tầng kiểm thử toàn diện, chạy `rtk npx codegraph build` và báo cáo hoàn tất cho PO.
