# 📋 KẾ HOẠCH TRIỂN KHAI: CHUẨN HÓA THỜI LƯỢNG BẢO TRÌ & TÁCH BIỆT NÂNG CẤP HỆ THỐNG
### (Maintenance Duration Accuracy & System Upgrade Isolation Implementation Plan)

> **Mã kế hoạch:** `PLAN-MAINTENANCE-DURATION-UPGRADE-20261023`  
> **Người lập:** Lead BA + Lead FullStack Cao Cấp + QA Architect  
> **Trạng thái:** 🟢 ĐÃ HOÀN TẤT TRIỂN KHAI VÀ XÁC MINH (Completed & Verified)  
> **Phạm vi tác động:** `src/Backend`, `src/Admin-web`, `docs/Admin-web/Event-Notification-to-ClientApp.md`

---

## 🏛️ I. TỔNG QUAN VẤN ĐỀ & PHÂN TÍCH 2 CHIỀU (DUAL-AXIS)

### 1. Phân Tích Thực Trạng Hiện Tại (Root Cause Analysis)
1. **Lỗi hiển thị "Đang diễn ra..." cho phiên ĐÃ HỦY:**
   * Trong giao diện `BroadcastPage.jsx`, hàm `formatDuration(startedAt, endedAt)` kiểm tra:
     ```javascript
     if (!endedAt) return t('broadcast.history.ongoingText', 'Đang diễn ra...');
     ```
   * Khi một lịch bảo trì (`SCHEDULED`) bị hủy trước khi chạy:
     - Cột `started_at` trong CSDL được lưu là thời điểm hẹn trong tương lai (ví dụ: `23/10/2026 18:59`).
     - Cột `ended_at` đang là `null` (hoặc là thời điểm bấm hủy nhỏ hơn `started_at`).
     - Do đó, giao diện hiển thị: Trạng thái = **`Đã hủy`**, nhưng Thời lượng = **`Đang diễn ra...`**, Kết thúc = **`—`** (Cực kỳ vô lý và gây hiểu lầm cho người dùng!).
2. **Thiếu thời lượng thực tế cho phiên ĐANG DIỄN RA (`ONGOING`):**
   * Hiện tại, phiên đang diễn ra chỉ hiển thị chuỗi tĩnh `"Đang diễn ra..."` mà không hiển thị **thời lượng đã trôi qua** (ví dụ: `15m 30s (Đang diễn ra)`).
3. **Chưa tách biệt giữa BẢO TRÌ HỆ THỐNG (Maintenance) và NÂNG CẤP HỆ THỐNG (System Upgrade):**
   * Hiện tại cột `type` chỉ có `EMERGENCY` (Khẩn cấp) và `SCHEDULED` (Theo lịch).
   * Khi đội ngũ triển khai phiên bản mới hoặc nâng cấp CSDL (Zero-downtime hoặc Blue-Green deployment), hệ thống chưa có phân loại `UPGRADE` (Nâng cấp hệ thống) để thông báo cho người dùng một cách chuyên nghiệp (tránh gây tâm lý hoang mang là hệ thống bị sự cố).

---

## 📐 II. GIẢI PHÁP THỰC THI TOÀN DIỆN (SOLUTION SPECIFICATION)

### 1. CSDL PostgreSQL (`maintenance_history`)
* Bổ sung cột `actual_duration_seconds` (`INTEGER NULL`): Lưu trữ chính xác thời lượng thực tế tính bằng giây khi phiên kết thúc hoặc bị hủy.
* Cột `type`: Mở rộng hỗ trợ 3 loại hình:
  - `'EMERGENCY'`: Bảo trì khẩn cấp (sự cố)
  - `'SCHEDULED'`: Bảo trì định kỳ (bảo dưỡng phần cứng/mạng)
  - `'UPGRADE'`: Nâng cấp hệ thống (Deploy phiên bản mới, cập nhật cơ sở dữ liệu)

```sql
-- Migration 36: Bổ sung actual_duration_seconds và hỗ trợ loại UPGRADE
ALTER TABLE "maintenance_history" 
ADD COLUMN IF NOT EXISTS "actual_duration_seconds" INTEGER NULL;

COMMENT ON COLUMN "maintenance_history"."actual_duration_seconds" IS 'Thời lượng thực tế của phiên bảo trì/nâng cấp tính bằng giây';
```

---

### 2. Quy Tắc Ghi Nhận Thời Lượng CSDL & Backend
1. **Khi bảo trì ĐÃ HOÀN THÀNH (`COMPLETED`):**
   * `ended_at = new Date()`
   * `actual_duration_seconds = Math.max(0, Math.floor((ended_at - started_at) / 1000))`
2. **Khi bảo trì ĐÃ BỊ HỦY (`CANCELLED`):**
   * **Trường hợp A (Lịch hẹn chưa chạy mà bị hủy):**
     - Thực tế phiên chưa từng diễn ra $\implies$ `actual_duration_seconds = 0`.
     - `ended_at = new Date()` (Ghi nhận thời điểm bấm hủy).
   * **Trường hợp B (Đang bảo trì mà bị hủy/ngắt ngang):**
     - `actual_duration_seconds = Math.max(0, Math.floor((ended_at - started_at) / 1000))` (Thời gian đã chạy thực tế trước khi bị hủy).
     - `ended_at = new Date()`.
3. **Khi bảo trì ĐANG DIỄN RA (`ONGOING`):**
   * `ended_at = null`
   * `actual_duration_seconds = null` (Được tính động theo thời gian thực trên giao diện).

---

### 3. Giao Diện Admin-Web (`BroadcastPage.jsx`)
1. **Cột THỜI LƯỢNG thông minh:**
   * Nếu `status === 'CANCELLED'`:
     - Nếu bị hủy trước khi chạy (`actual_duration_seconds === 0` hoặc chưa bắt đầu): Hiển thị **`— (Đã hủy trước khi chạy)`** hoặc **`—`**.
     - Nếu bị hủy giữa chừng (`actual_duration_seconds > 0`): Hiển thị thời gian đã chạy thực tế (ví dụ: `12m 45s (Bị hủy ngang)`).
   * Nếu `status === 'ONGOING'`:
     - Hiển thị thời lượng chạy trực tiếp theo nhịp đồng hồ thời gian thực: **`15m 20s (Đang diễn ra)`**.
   * Nếu `status === 'SCHEDULED'`:
     - Nếu có giờ dự kiến kết thúc: Hiển thị **`Dự kiến: 1h 00m`**; nếu không thì hiển thị **`—`**.
   * Nếu `status === 'COMPLETED'`:
     - Hiển thị thời lượng chuẩn: `${diffSec}s` / `${min}m ${sec}s` / `${h}h ${min}m`.
2. **Cột KẾT THÚC:**
   * Nếu `status === 'CANCELLED'`: Hiển thị `formatDateTime(row.ended_at) (Đã hủy)`.
   * Nếu `status === 'SCHEDULED'`: Hiển thị `formatDateTime(row.scheduled_end_at) (Dự kiến)`.
   * Nếu `status === 'COMPLETED'`: Hiển thị `formatDateTime(row.ended_at)`.
   * Nếu `status === 'ONGOING'`: Hiển thị `formatDateTime(row.scheduled_end_at) (Dự kiến)` hoặc `Đang diễn ra...`.
3. **Tách biệt NÂNG CẤP HỆ THỐNG (`UPGRADE`):**
   * Thêm tùy chọn Nâng cấp hệ thống vào bộ lọc "Tất cả loại".
   * Badge hiển thị loại:
     - 🔴 **Khẩn cấp** (`EMERGENCY`): Badge đỏ
     - 🔵 **Định kỳ** (`SCHEDULED`): Badge xanh dương
     - 🟣 **Nâng cấp** (`UPGRADE`): Badge tím với icon `system_update`

---

### 4. Socket.IO & Giao Tiếp Real-time
* Sự kiện `admin.maintenance_changed` và `system.maintenance_changed` gửi kèm:
  ```json
  {
    "active": true,
    "isEmergency": false,
    "isUpgrade": true,
    "type": "UPGRADE",
    "reason": "Hệ thống đang tiến hành nâng cấp phiên bản 3.2 để bổ sung tính năng mới.",
    "activatedAt": "2026-10-23T12:00:00.000Z"
  }
  ```
* Phía Client-app khi nhận `isUpgrade: true` sẽ hiển thị banner/thông điệp thân thiện: *"Hệ thống đang được nâng cấp tính năng mới..."* thay vì thông báo sự cố bảo trì đỏ.

---

## 📅 III. CÁC BƯỚC THỰC HIỆN TUẦN TỰ (4-PHASE WORKFLOW)

- [x] **Bước 1:** Trình kế hoạch chi tiết cho PO phê duyệt (Quy tắc Tối cao 1 & Rule 6) — *PO đã duyệt 100%*.
- [x] **Bước 2 (CSDL & Backend Repository):**
  - Tạo script Migration `36_enhance_maintenance_history_duration_and_upgrade.sql`.
  - Viết script thực thi `apply_migration_36.js` cập nhật Supabase Cloud an toàn (tuân thủ Rule 10 DB Guard).
  - Cập nhật `maintenance.repository.js` tính và lưu `actual_duration_seconds` khi hoàn tất hoặc hủy phiên.
- [x] **Bước 3 (Resilience Manager & Socket):**
  - Cập nhật `maintenance.manager.js` hỗ trợ `isUpgrade` và loại `UPGRADE`.
  - Phát đầy đủ payload qua Socket.io.
- [x] **Bước 4 (Admin-Web UI):**
  - Cập nhật hàm `formatDuration` và render cột "Kết thúc" trong `BroadcastPage.jsx`.
  - Bổ sung Badge tím và bộ lọc cho loại "Nâng cấp hệ thống" (`UPGRADE`).
  - Thêm Live Timer đếm thời gian cho các phiên `ONGOING`.
- [x] **Bước 5 (Kiểm thử 2 Tầng & Hoàn tất):**
  - Viết unit test 2 tầng kiểm tra độ chính xác thời lượng của cả 4 trạng thái (`COMPLETED`, `CANCELLED`, `ONGOING`, `SCHEDULED`).
  - Chạy `rtk npm test` (372/372 pass, 50 suites), build Admin-web thành công và cập nhật CodeGraph.
