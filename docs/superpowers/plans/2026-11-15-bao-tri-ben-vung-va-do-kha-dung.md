# Kế hoạch: Bảo trì bền vững qua khởi động lại + Độ khả dụng theo kỳ

Lập 2026-11-15 · Vai lập: Lead PO + Lead BA · Trạng thái: **CHỜ CHỦ DỰ ÁN DUYỆT**
Phạm vi: `src/Backend`, `src/Admin-web`, `src/Backend/database/`. Không đụng `src/Client-app`. Không commit / push khi chưa được lệnh.

## 0. Quyết định đã chốt (Chủ dự án, 2026-11-15)

| # | Quyết định |
|---|---|
| Q1 | CSDL (`maintenance_history`) là nguồn sự thật của bảo trì. Sau mỗi lần khởi động / deploy, máy chủ đọc phiên gần nhất; phiên còn hiệu lực thì khoá lại hệ thống, không tự làm mới bảo trì. Lịch hẹn cũng được khôi phục. |
| Q2 | Tách hai chỉ số: **Độ khả dụng (%) theo kỳ lịch** (bền vững, không mất khi khởi động lại) và **Chạy liên tục** (đếm lại từ 0 mỗi lần khởi động). |
| Q3 | `Chạy liên tục = Bây giờ − Lúc tiến trình khởi động`, không trừ bảo trì. |
| Q4 | Thẻ dashboard gọn (mặc định tháng hiện tại); bấm "Xem chi tiết" mở ngăn kéo có bộ chọn Tháng (1–12 + năm) / Quý (Q1–Q4 + năm) / Năm. Không gắn với bộ lọc "Hôm nay / 7 ngày / 1 tháng / 1 năm". |
| Q5 | Phương án B: khoảng máy chủ dừng **có chủ đích** (nhận SIGTERM/SIGINT: deploy, Render cho ngủ) hiện riêng, không trừ vào độ khả dụng; khoảng dừng **không ghi kịp** (sập) tính là gián đoạn ngoài dự kiến. Đã có dịch vụ ngoài đánh thức mỗi 12 phút; B là dự phòng. |
| Q6 | Thêm migration mới cho độ khả dụng. Áp lên Supabase chỉ khi Chủ dự án xác nhận đích danh. |
| Q7 | (duyệt kế hoạch, 2026-11-15) CSDL chậm / lỗi lúc khởi động ⇒ không biết trạng thái bảo trì ⇒ **khoá máy chủ cho tới khi đọc được CSDL** (fail-closed). |
| Q8 | Bảo trì **có trừ** vào độ khả dụng: bảo trì chặn khách hàng nên vẫn là thời gian không khả dụng. |
| Q9 | Giữ tạm khoá cũ (`uptimePercent`, `uptimeFormatted`, `downtimeSeconds`) với nghĩa mới; gỡ ở đợt sau khi đợt này xong. |

Trạng thái: **ĐÃ DUYỆT 2026-11-15**, thi công ngay ở phiên chính. **Đã thi công 2026-11-15** (bước 1–5 xong, kiểm thật trên CSDL thử); migration 52 đã áp Supabase 2026-11-15 theo xác nhận đích danh của Chủ dự án.

Điểm lệch so với kế hoạch khi thi công: (1) chi tiết độ khả dụng dùng hộp thoại `Modal` có sẵn thay cho ngăn kéo (kế hoạch cho phép cả hai); `StatCard` thêm prop `action`. (2) `server_session.start()` đóng ngay phiên còn mở của **cùng `instance_id`** (tiến trình cũ trên cùng máy chắc chắn đã chết), không đợi đủ 3 phút mất nhịp; phát hiện khi kiểm thật (khởi động lại nhanh làm khoảng gián đoạn bị tính thiếu trong 3 phút). (3) Chạy dưới 1 phút ghi "dưới 1 phút" thay "Vừa khởi động" để đọc liền với "Chạy liên tục …".

## 1. Hiện trạng (đã đối chiếu mã 2026-11-15)

- Cờ bảo trì chỉ nằm trong RAM (`core/resilience/maintenance.manager.js`); đoạn ghi Redis không chạy vì `redis` không được truyền vào.
- Khởi động: `index.js:84-89` gọi `reconcileStateWithDatabase()` → RAM `active=false` → `reconcileWithDatabase` đóng mọi phiên `ONGOING` thành `COMPLETED` ("ghost killer"). ⇒ deploy giữa bảo trì làm **mất bảo trì**.
- Lịch `SCHEDULED` còn trong CSDL nhưng không ai gọi `getActiveScheduledRecords()` lúc khởi động ⇒ **lịch hẹn mất sau khởi động lại** (lỗi).
- `calcUptimePercent` (`modules/admin/admin.service.js:82`): `Tổng = process.uptime()`, trừ bảo trì kể từ `SERVER_START_TIME` ⇒ mất số liệu mỗi lần khởi động; không đo được thời gian sập. Hàm này còn bị gọi mỗi 3 giây trong luồng metrics (`index.js:111`), mỗi lần một truy vấn CSDL.
- `maintenance_history` không có trong `schema.prisma` (repository dùng `pg` thô + `initTable()`).
- Client-app không đọc trường uptime (đã `Grep src/Client-app/lib`). Client chỉ nhận `system.maintenance_changed` và phản hồi của middleware bảo trì ⇒ hợp đồng không đổi.

## 2. Thiết kế

### 2.1. Khôi phục bảo trì khi khởi động (không cần migration)

Thêm `MaintenanceManager.restoreFromDatabase()` thay cho lời gọi `reconcileStateWithDatabase()` lúc khởi động:

1. Đọc các bản ghi `ONGOING`, mới nhất trước.
   - Nhiều hơn 1 bản ghi (dữ liệu lỗi): giữ bản mới nhất; các bản cũ đóng `COMPLETED`, `ended_at = started_at của bản mới nhất`.
   - Bản giữ lại có `scheduled_end_at < now` ⇒ đóng `COMPLETED`, `ended_at = scheduled_end_at`, `actual_duration_seconds` tính theo đó; không bật bảo trì.
   - Ngược lại ⇒ khôi phục RAM: `active=true`, `isEmergency = type==='EMERGENCY'`, `isUpgrade = type==='UPGRADE'`, `reason`, `activatedBy`, `activatedAt = started_at`. **Không** tạo bản ghi mới, **không** broadcast thông báo đẩy (tránh báo trùng), **có** phát `emitMaintenanceChanged(getStatus())`. Có `scheduled_end_at` ở tương lai ⇒ đặt hẹn giờ tự kết thúc cho phần còn lại (dùng chung cách đặt `_autoEndTimer` của `activateScheduledItem`).
2. Đọc các bản ghi `SCHEDULED` (`getActiveScheduledRecords()`):
   - `scheduled_end_at` (nếu có) đã qua ⇒ `CANCELLED`, lý do "Lỡ lịch do máy chủ không chạy trong khung giờ hẹn".
   - `started_at ≤ now` (đang trong khung) ⇒ `activateScheduledItem` (giữ luật cũ: đang có bảo trì khác thì lịch bị huỷ).
   - Tương lai ⇒ nạp lại vào `scheduledList` kèm hẹn giờ, theo đúng dạng đối tượng `scheduleMaintenance` đang tạo (FullStack đọc `scheduleMaintenance` để tái dùng phần tạo đối tượng + hẹn giờ, không viết bản thứ hai; tách hàm nội bộ nếu cần, không đổi hành vi `scheduleMaintenance`).
3. **Thứ tự khởi động (Q7, fail-closed):** `MaintenanceManager` bắt đầu ở trạng thái `restorePending = true`. Trong lúc đó middleware bảo trì chặn yêu cầu của người dùng thường (503, cùng dạng phản hồi bảo trì hiện có, lý do "Hệ thống đang khởi động"); vẫn cho qua health check (để Render không khởi động lại liên tục), admin và đăng nhập như ngoại lệ hiện có. Trạng thái chờ chỉ ở RAM: không ghi `maintenance_history`, không broadcast, không tính vào độ khả dụng. `restoreFromDatabase()` thử lại mỗi 5 giây tới khi đọc được CSDL; xong thì `restorePending = false` và phát `emitMaintenanceChanged(getStatus())` một lần để client đang thấy 503 cập nhật lại.
4. Bỏ "ghost killer" khỏi đường khởi động. Giữ `reconcileStateWithDatabase` cho nhánh "đang bảo trì nhưng CSDL thiếu bản ghi ONGOING" nếu còn nơi gọi khác; nếu chỉ dùng lúc khởi động thì gỡ lời gọi, giữ hàm (soát bằng `Grep` trước).

Rủi ro đã chấp nhận: admin tắt bảo trì lúc CSDL sập, lệnh đóng phiên nằm ở hàng đợi RAM (`flushPendingQueue`), rồi máy chủ khởi động lại trước khi bù ⇒ bảo trì bật lại. Admin thấy trên Admin-web và tắt lại. Ghi vào tài liệu vận hành.

### 2.2. Ghi phiên chạy của máy chủ (migration 52)

`src/Backend/database/52_server_session.sql` (luỹ đẳng; số 52 là kế tiếp sau `51_data_incident.sql`, kiểm lại trước khi tạo):

```sql
CREATE TABLE IF NOT EXISTS "server_session" (
  "id"           BIGSERIAL PRIMARY KEY,
  "instance_id"  VARCHAR(100) NOT NULL,          -- RENDER_INSTANCE_ID, không có thì os.hostname()
  "version"      VARCHAR(64)  NULL,              -- RENDER_GIT_COMMIT (rút gọn 12 ký tự) nếu có
  "started_at"   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  "last_seen_at" TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  "ended_at"     TIMESTAMPTZ  NULL,
  "end_reason"   VARCHAR(20)  NULL CHECK ("end_reason" IN ('GRACEFUL','UNKNOWN'))
);
CREATE INDEX IF NOT EXISTS "idx_server_session_started_at" ON "server_session" ("started_at");
CREATE INDEX IF NOT EXISTS "idx_server_session_open" ON "server_session" ("last_seen_at") WHERE "ended_at" IS NULL;
```

Không chứa dữ liệu người dùng; không trigger bất biến. Sau migration: cập nhật `schema.prisma` (model `server_session`), `npm run prisma:generate`, `npm run db:verify-indexes`.

Hành vi (`core/resilience/server-session.js`, mới):
- **Khởi động:** đóng phiên treo `ended_at IS NULL AND last_seen_at < now − 3 phút` ⇒ `ended_at = last_seen_at`, `end_reason='UNKNOWN'` (không đóng phiên của máy chủ khác còn sống). Rồi chèn phiên mới.
- **Nhịp sống:** mỗi 60 giây `UPDATE last_seen_at = NOW()` cho phiên hiện tại (`unref()`; lỗi thì bỏ qua, lần sau ghi tiếp).
- **SIGTERM / SIGINT:** trong hai handler sẵn có ở `index.js:176-197`, trước `prisma.$disconnect()`: `ended_at = NOW(), end_reason='GRACEFUL'`, chặn tối đa 2 giây.
- Sai số chấp nhận: sập giữa hai nhịp mất tối đa 60 giây số liệu; SIGKILL không kịp ghi ⇒ tính nhầm thành gián đoạn (nghiêng về thận trọng).

### 2.3. Tính độ khả dụng theo kỳ

Hàm thuần `calcAvailability({ periodStart, periodEnd, now, sessions, maintenances })` (`modules/admin/availability.js`, mới) để test không cần CSDL:

```
Cửa_sổ_đo = [ max(periodStart, started_at phiên đầu tiên), min(periodEnd, now) ]
Độ_khả_dụng = (Đo_được − Bảo_trì − Gián_đoạn) ÷ Đo_được × 100
```

- `Đo_được`: độ dài cửa sổ đo (giây). Bằng 0 (kỳ trước khi bắt đầu đo, hoặc kỳ tương lai) ⇒ trả `percent = null`, giao diện ghi "Chưa có dữ liệu".
- `Bảo_trì`: phần giao của các phiên `COMPLETED`/`ONGOING` trong `maintenance_history` với cửa sổ; chia `emergency` (`type='EMERGENCY'`) và `planned` (còn lại: SCHEDULED, ROUTINE, UPGRADE). `CANCELLED` không tính.
- `Gián_đoạn` (ngoài dự kiến): các khoảng trống giữa phiên có `end_reason='UNKNOWN'` (tính từ `ended_at` tới `started_at` phiên kế tiếp), **trừ phần trùng bảo trì** (không đếm hai lần).
- `Dừng_có_chủ_đích`: khoảng trống sau phiên `GRACEFUL`; báo riêng, **không** trừ (Q5). Cũng trừ phần trùng bảo trì.
- Phiên đang chạy: kết thúc tạm = `now`.
- Làm tròn 2 chữ số; kẹp 0–100.
- Kỳ lịch tính theo giờ Việt Nam (Asia/Ho_Chi_Minh): FullStack dùng lại tiện ích múi giờ đang có cho thống kê admin (xem `tests/unit/admin.stats.timezone.test.js`), không tự viết mới.
- Cột chia nhỏ (`buckets`): kỳ tháng → theo ngày; quý, năm → theo tháng; mỗi cột cùng công thức.

### 2.4. API

- `GET /api/admin/system/availability?period=month&year=2026&month=11` · `period=quarter&year=2026&quarter=4` · `period=year&year=2026`
  - Kiểm tham số: sai ⇒ 400. Cùng lớp bảo vệ admin với các route `/system/*` khác.
  - Trả: `{ period, label, periodStart, periodEnd, coverageFrom, measuredSeconds, percent, plannedMaintenanceSeconds, emergencyMaintenanceSeconds, unplannedSeconds, plannedStopSeconds, buckets:[{ label, start, end, percent }], incidents:[{ kind:'EMERGENCY'|'PLANNED'|'UNPLANNED'|'PLANNED_STOP', start, end, durationSeconds, reason? }], availableYears:[...] }`
- `GET /system/health` và luồng socket metrics 3 giây: trường `uptime` đổi nghĩa:
  - `runningSeconds`, `runningFormatted` = `process.uptime()` (Q3); `startedAt`; `version`.
  - Giữ tạm các khoá cũ (`uptimeFormatted`, `uptimePercent`, `downtimeSeconds`) với nghĩa mới (`uptimeFormatted = runningFormatted`; `uptimePercent` = độ khả dụng tháng hiện tại) để Admin-web cũ không vỡ trong lúc deploy lệch nhau; gỡ ở đợt sau.
  - Luồng 3 giây **không** truy vấn CSDL nữa; độ khả dụng tháng hiện tại lưu đệm, tính lại tối đa 60 giây/lần và ngay khi bảo trì đổi trạng thái.

### 2.5. Admin-web

- `pages/dashboard/DashboardPage.jsx`: thẻ "Thời gian hoạt động" → **"Độ khả dụng · Tháng MM/YYYY"**: số %, dòng "Chạy liên tục …", liên kết "Xem chi tiết ›". Màu giữ ngưỡng cũ (≥ 99,5 xanh, ≥ 95 vàng, còn lại đỏ). `percent=null` ⇒ "Chưa có dữ liệu".
- Mới: `components/dashboard/AvailabilityDrawer.jsx`: nút chọn Tháng | Quý | Năm; ô chọn phụ theo loại (tháng 1–12 + năm; Q1–Q4 + năm; năm). Danh sách năm lấy từ `availableYears`. Hiện %, "Dữ liệu từ dd/mm/yyyy", bốn dòng chia nhỏ, biểu đồ cột theo `buckets` (dùng thư viện biểu đồ dashboard đang dùng), bảng sự cố.
- `components/common/ServerHealthPanel.jsx`: hàng "Thời gian hoạt động %" → "Độ khả dụng (tháng)"; "Đã chạy" → "Chạy liên tục"; thêm "Phiên bản" khi có.
- `locales/vi.js`, `locales/en.js`: khoá mới.
- `adminApi`: thêm `getAvailability(params)`.

## 3. Ma trận test (viết trước, phải ĐỎ trước khi code)

**Backend (`node:test`, `tests/unit/`; tầng 2 dùng CSDL thử `flowmoney_adminweb`, không dùng Supabase chung):**

| Mã | Ca | Kỳ vọng |
|---|---|---|
| B1 | Khởi động khi CSDL có 1 phiên ONGOING không hạn kết thúc | `active=true`, `activatedAt = started_at`, không `createRecord`, không broadcast, có emit socket |
| B2 | ONGOING có `scheduled_end_at` đã qua | bản ghi `COMPLETED`, `ended_at = scheduled_end_at`; `active=false` |
| B3 | ONGOING có `scheduled_end_at` tương lai | `active=true`; hết giờ (giả lập đồng hồ) thì tự tắt |
| B4 | 2 bản ghi ONGOING | giữ bản mới nhất; bản cũ `COMPLETED` |
| B5 | SCHEDULED tương lai / đang trong khung / đã lỡ | lần lượt: nằm trong `scheduledList` có hẹn giờ; được kích hoạt; `CANCELLED` |
| B6 | Không có ONGOING | `active=false` (hồi quy) |
| B7 | Middleware lúc khởi động khi CSDL có ONGOING | yêu cầu người dùng thường bị chặn ngay từ yêu cầu đầu tiên sau khi nhận kết nối |
| B8 | `server-session`: khởi động / nhịp sống / SIGTERM | chèn phiên; `last_seen_at` tăng; `GRACEFUL` |
| B9 | Phiên treo cũ > 3 phút và phiên máy khác còn sống | phiên cũ `UNKNOWN`, `ended_at = last_seen_at`; phiên còn sống giữ nguyên |
| B10 | `calcAvailability`: không sự kiện | 100% |
| B11 | Bảo trì 1 giờ trong tháng 30 ngày đo đủ | `(2.592.000 − 3.600) ÷ 2.592.000 × 100 = 99,86%` |
| B12 | Khoảng sập sau phiên UNKNOWN | tính vào `unplannedSeconds`, trừ vào % |
| B13 | Khoảng sau phiên GRACEFUL | vào `plannedStopSeconds`, % không đổi |
| B14 | Sập trùng một phần bảo trì | phần trùng chỉ tính một lần, ở bảo trì |
| B15 | Bắt đầu đo giữa kỳ; kỳ tương lai | `coverageFrom` đúng, mẫu số chỉ phần đo được; kỳ tương lai `percent=null` |
| B16 | `buckets` tháng / quý / năm, ranh giới theo giờ Việt Nam | số cột 30–31 / 3 / 12; mốc 00:00 +07:00 |
| B17 | API tham số sai / không phải admin | 400 / bị chặn như route `/system/*` khác |
| B18 | `uptime.runningSeconds` khi đang bảo trì | bằng `process.uptime()`, không trừ bảo trì |
| B19 | Migration 52 chạy hai lần trên CSDL thử | không lỗi, cấu trúc như thiết kế |

Sửa test cũ theo đặc tả mới (trước khi sửa mã): `maintenance.reconciliation.2tier.test.js` (bỏ kỳ vọng "khởi động thì đóng ONGOING"), các test của `calcUptimePercent` / `admin.health.test.js` nếu kiểm nghĩa cũ.

**Admin-web (`vitest` + Testing Library, `src/tests/`):**

| Mã | Tầng | Ca |
|---|---|---|
| A1 | 1 | Thẻ hiện "Độ khả dụng · Tháng MM/YYYY", %, "Chạy liên tục"; `percent=null` hiện "Chưa có dữ liệu" |
| A2 | 1 | Bấm "Xem chi tiết" mở ngăn kéo; chuyển Tháng → Quý → Năm đổi đúng ô chọn |
| A3 | 2 | Chọn Q4/2026 gọi `getAvailability({ period:'quarter', year:2026, quarter:4 })`; dữ liệu trả về hiện đúng % và "Dữ liệu từ" |
| A4 | 2 | Sự kiện socket metrics cập nhật "Chạy liên tục" trên thẻ và trên panel |

Kiểm trên trình duyệt (`agent-browser`) ở môi trường thử Admin-web (cổng 3010/5180) trước khi báo xong.

## 4. Thứ tự thi công (mỗi bước test xanh, commit khi Chủ dự án ra lệnh)

1. Khôi phục bảo trì + lịch hẹn (2.1) — B1–B7 + sửa test cũ.
2. Migration 52 trên CSDL thử + `server-session` (2.2) — B8, B9, B19. **Dừng, xin xác nhận trước khi áp lên Supabase.**
3. `calcAvailability` + API + đổi trường `uptime` (2.3, 2.4) — B10–B18.
4. Admin-web (2.5) — A1–A4 + kiểm trên trình duyệt.
5. Tài liệu: `docs/Admin-web/*` (mục dashboard / bảo trì), `docs/Deploy/CloudDeploy.md` (rủi ro 2.1, ý nghĩa chỉ số), `docs/progress/Backend.md`, `Project.md` mục 3.2/3.4. Client-app không phải làm gì (không ghi đơn `CAN-LAM` client).

## 5. Định nghĩa xong

- B1–B19, A1–A4 xanh; toàn bộ `npm test` của Backend và Admin-web xanh; lint sạch.
- Khởi động lại máy chủ thử giữa phiên bảo trì: bảo trì còn nguyên, lịch hẹn còn nguyên (chứng minh bằng log + Admin-web).
- Số liệu độ khả dụng không đổi sau khởi động lại.
- Migration 52 áp lên Supabase chỉ sau xác nhận đích danh.
