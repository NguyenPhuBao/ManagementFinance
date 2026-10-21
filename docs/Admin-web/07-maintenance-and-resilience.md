# ⚙️ Chức Năng 07: Quản Trị Chế Độ Bảo Trì & Cứu Hộ Khẩn Cấp (Maintenance & Resilience Management)

> **Mã chức năng:** `ADMIN-FEAT-07`  
> **Module phụ trách:**  
> - Frontend: `src/Admin-web/src/pages/system/BroadcastPage.jsx` (Tab 1), `src/Admin-web/src/components/common/ServerHealthPanel.jsx`  
> - Backend: `src/Backend/core/resilience/maintenance.manager.js`, `src/Backend/middleware/maintenance.middleware.js`, `src/Backend/api/admin.routes.js`  

---

## 📌 1. TỔNG QUAN & MỤC ĐÍCH NGHIỆP VỤ

Chức năng **Quản Trị Chế Độ Bảo Trì & Cứu Hộ Khẩn Cấp** là công tắc ngắt mạch trung tâm (Circuit Breaker) của toàn bộ nền tảng. Khi hệ thống cần nâng cấp phiên bản, thực hiện migrate cơ sở dữ liệu lớn hoặc đối mặt với sự cố an ninh nghiêm trọng, chức năng này cho phép quản trị viên cách ly an toàn máy chủ khỏi lưu lượng người dùng di động.

Hệ thống được xây dựng trên nền tảng **Kiến trúc Zero-Coupling & Cứu hộ Bất biến**:
1. **Kiến trúc Độc Lập Hoàn Toàn Khỏi CSDL (Zero-Coupling Out-of-Band Gatekeeper):** Trạng thái bảo trì được quản lý trực tiếp bằng biến In-Memory và Redis với độ trễ $O(1) < 0.05\text{ms}$. Ngay cả khi CSDL PostgreSQL gặp sự cố sập hoàn toàn, Admin vẫn có thể bật/tắt bảo trì bình thường.
2. **Bộ Đệm Ngoại Tuyến (Outbox Buffer `_pendingDbSyncQueue`):** Mọi lệnh thay đổi trạng thái khi CSDL offline được xếp vào hàng đợi bộ đệm để ghi bù ngay khi kết nối CSDL phục hồi.
3. **Cơ Chế Triệt Tiêu Bản Ghi Ma (Ghost Maintenance Killer - `reconcileWithDatabase`):** Khi CSDL khôi phục, hệ thống tự động đối soát chéo giữa RAM/Redis và CSDL. Nếu phiên bảo trì đã kết thúc trong thời gian CSDL mất kết nối, hệ thống tự động cập nhật dứt điểm các bản ghi `ONGOING` thành `COMPLETED`, xóa bỏ hoàn toàn rủi ro xuất hiện "phiên bảo trì ma" kéo dài sai thực tế.
4. **Đặc quyền Cứu hộ Khẩn cấp (Emergency Override):** Duy nhất **Bảo trì khẩn cấp** có quyền kích hoạt đè khi hệ thống đang trong phiên bảo trì thông thường nhằm xử lý ngay lập tức các tình huống rủi ro bảo mật hoặc thảm họa máy chủ.
5. **CẤM TUYỆT ĐỐI bảo trì theo lịch đè nhau (No Overlapping Schedules):** Nếu hệ thống đang trong phiên bảo trì hoặc đã có một lịch bảo trì tương lai đang chờ kích hoạt (`SCHEDULED`), hệ thống từ chối mọi yêu cầu lên lịch mới để loại trừ xung đột thời gian.
6. **Bảo toàn lịch hẹn tương lai:** Khi kích hoạt bảo trì khẩn cấp, hệ thống chỉ hủy những lịch bị giao thoa (`scheduled.start_time <= emergency.end_time`), bảo toàn nguyên vẹn các lịch xa hơn trong tương lai.
7. **Trải nghiệm Quản trị Chuyên Nghiệp:** Popup Modal xác nhận hai chiều (cả khi bật và khi tắt bảo trì), loại bỏ hoàn toàn các icon `⚠️`/`🚨` thô sơ trong payload thông báo, thay thế bằng định dạng chuyên nghiệp chuẩn Enterprise.

---

## ⚙️ 2. CƠ CHẾ HOẠT ĐỘNG CHI TIẾT (END-TO-END FLOW)

```mermaid
graph TD
    subgraph "Admin-web Điều Hành (BroadcastPage.jsx & ServerHealthPanel)"
        A1[Bật Bảo Trì Khẩn Cấp]
        A2[Popup Modal Xác Nhận Bật - Nhập PIN]
        A3[Tắt Bảo Trì Khẩn Cấp]
        A4[Popup Modal Xác Nhận Tắt]
        A5[Lên Lịch Thời Điểm Bảo Trì]
        A6[Khóa Công Tắc tại Dashboard - SafeMaintenanceLink]
    end

    subgraph "Động Cơ Bảo Trì Zero-Coupling (maintenance.manager.js)"
        B1[Cập nhật tức thì In-Memory RAM & Redis]
        B2{CSDL PostgreSQL Sẵn Sàng?}
        B3[Ghi trực tiếp vào bảng maintenance_history]
        B4[Xếp lệnh vào Outbox Buffer: _pendingDbSyncQueue]
        B5[DB Reconnect Listener: Kích hoạt reconcileWithDatabase]
        B6[Ghost Maintenance Killer: Chốt COMPLETED các bản ghi ONGOING mồ côi]
        B7[Flush Outbox: Đẩy toàn bộ hàng đợi vào CSDL]
    end

    subgraph "Kênh Thông Báo & Phân Phối (Realtime Hub)"
        S1[Phát system.maintenance_changed tới Toàn Bộ Client App]
        S2[Phát admin.maintenance_changed tới admin_room]
        S3[NotificationService: Gửi thông báo hệ thống đã chuẩn hóa format]
    end

    A1 --> A2 --> B1
    A3 --> A4 --> B1
    A5 --> B1
    A6 -.-> A1

    B1 --> B2
    B2 -- "Online" --> B3
    B2 -- "Offline / Lỗi kết nối" --> B4

    B5 --> B6 --> B7

    B1 --> S1 & S2 & S3
```

### 2.1. Kiến Trúc Failover & Ghost Maintenance Killer Chi Tiết
Khi cơ sở dữ liệu bị mất kết nối hoặc quá tải:
1. **Giai đoạn CSDL Ngoại Tuyến (Offline Phase):**
   - Quản trị viên thực hiện bật hoặc tắt bảo trì trên Admin-web.
   - `MaintenanceManager` lập tức cập nhật biến In-Memory và Redis, phát tán Socket.io tới Client-app và Admin-web.
   - Request API trả về thành công ngay lập tức ($< 5\text{ms}$), không bị treo chờ CSDL.
   - Thao tác cập nhật lịch sử được đẩy vào hàng đợi bộ nhớ `_pendingDbSyncQueue = [{ action: 'TOGGLE', active, reason, time }]`.
2. **Giai đoạn CSDL Hồi Phục (Self-Healing & Reconciliation Phase):**
   - Cơ chế giám sát CSDL phát hiện kết nối PostgreSQL đã hoạt động trở lại và gọi `reconcileWithDatabase()`.
   - **Thực thi Ghost Maintenance Killer:**
     ```javascript
     if (!this.state.active) {
       // Nếu bộ nhớ xác nhận đã tắt bảo trì, đóng ngay mọi bản ghi còn mở trong CSDL
       await prisma.maintenance_history.updateMany({
         where: { status: 'ONGOING' },
         data: { status: 'COMPLETED', end_time: new Date() }
       });
     }
     ```
   - **Xả hàng đợi Outbox (`flushPendingDbSyncQueue`):** Duyệt tuần tự các lệnh trong hàng đợi `_pendingDbSyncQueue` và đồng bộ an toàn vào bảng `maintenance_history`.

---

## 📐 3. CÁC THÔNG SỐ KỸ THUẬT & HEADERS

| Thuộc tính / Header | Giá trị | Mục đích & Ý nghĩa |
|---|---|---|
| **HTTP Status Code** | `503 Service Unavailable` | Báo cho Client và Web Crawler biết server tạm thời bảo trì, không bị đánh tụt SEO. |
| **Header `Retry-After`** | `3600` (giây) | Hướng dẫn client thời gian quay lại thử lại. |
| **Error Code Payload** | `MAINTENANCE_MODE` | Mã chuẩn hóa cho Client-app bắt exception. |
| **Redis Cache Key** | `system:maintenance:status` | Lưu trữ bền bỉ phân tán trên Redis cluster. |
| **Outbox Buffer** | `_pendingDbSyncQueue` | Mảng In-Memory đệm các thao tác CSDL khi Postgres bị ngắt kết nối. |
| **Scheduled Timer** | `setTimeout().unref()` | Non-blocking timer, không gây treo tiến trình Node.js khi shutdown. |
| **Database Table** | `maintenance_history` | Bảng lưu trữ nhật ký vĩnh viễn trên PostgreSQL Supabase. |

---

## ⛔ 4. CÁC GIỚI HẠN & NGUYÊN TẮC AN TOÀN

1. **Chặn thời gian trong quá khứ:** Form lên lịch bảo trì tự động kiểm tra thời điểm hẹn. Nếu thời gian chọn nhỏ hơn thời điểm hiện tại (`targetDate <= Date.now()`), hệ thống từ chối với lỗi HTTP 400.
2. **Miễn trừ Route kiểm tra sức khỏe:** Route `/health`, `/health/admin` luôn mở 100% để bộ cân bằng tải (Load Balancer / Kubernetes / Render) không hiểu nhầm container đã chết mà restart liên tục.
3. **Đồng bộ đa tiến trình (Cross-Process Hydration):** Khi khởi động, Backend tự động gọi `hydrateFromRedis()` để nạp lại trạng thái bảo trì nếu trước đó server bị restart bất ngờ.
4. **Bảo vệ công tắc tại Dashboard:** Khóa công tắc tại `ServerHealthPanel` khi đang active để ngăn ngừa click tắt nhầm ngoài ý muốn, chỉ cho phép điều khiển tắt tại trang Broadcast có Modal xác nhận.

---

## 💼 5. CÔNG DỤNG & GIÁ TRỊ NGHIỆP VỤ

- **Bảo toàn dữ liệu tài chính tuyệt đối:** Ngắt toàn bộ lưu lượng ghi từ ứng dụng di động khi thực hiện migration database, bảo vệ số dư và giao dịch không bao giờ bị corrupt.
- **Khả năng tự phục hồi (Self-Healing Resiliency):** Không phụ thuộc vào trạng thái của database, tự động đối soát và triệt tiêu bản ghi ma khi hạ tầng phục hồi.
- **Minh bạch và chuẩn mực:** Toàn bộ lịch sử bảo trì lưu vết chi tiết người thực hiện, thời gian bắt đầu, thời gian kết thúc, thời lượng và lý do.

---

## 🧩 6. TÍNH NĂNG ĐI KÈM TRÊN GIAO DIỆN (`BroadcastPage.jsx`)

1. **Global Maintenance Banner & Modal Xác Nhận 2 Chiều:**
   - Khi kích hoạt bảo trì khẩn cấp: Modal xác nhận yêu cầu nhập mã PIN bảo mật cấp 2.
   - Khi tắt bảo trì khẩn cấp: Modal xác nhận cảnh báo hệ thống sắp mở lại kết nối cho toàn bộ người dùng Client-app.
   - Loại bỏ hoàn toàn các icon `⚠️`/`🚨` thô sơ trong thông báo phát sóng.
2. **Cột Trái — Kích Hoạt Bảo Trì Khẩn Cấp:**
   - Ô nhập lý do gửi tới người dùng.
   - Nút bấm **LUÔN ĐỎ** (`bg-red-600`) mang tên **"Bật Bảo Trì Khẩn Cấp"**.
3. **Cột Phải — Lên Lịch Thời Điểm Bảo Trì:**
   - Input `datetime-local` chọn ngày giờ bắt đầu và kết thúc dự kiến chuẩn xác.
   - Tự động khóa và hiển thị cảnh báo nếu hệ thống đang có lịch hẹn hoặc đang trong phiên bảo trì trực tiếp.
4. **Bảng Lịch Sử Các Phiên Bảo Trì Hệ Thống (PostgreSQL Persistence):**
   - Lưu trữ vĩnh viễn trong bảng `maintenance_history`.
   - Các cột hiển thị: `#`, `Loại bảo trì` (Khẩn cấp / Theo lịch), `Người kích hoạt`, `Lý do / Thông điệp`, `Thời điểm bắt đầu`, `Thời điểm kết thúc`, `Thời lượng`, `Trạng thái` (Đang diễn ra, Đã hoàn thành, Đã hủy).
   - Bộ phân trang chuẩn mực (`Pagination.jsx`) mặc định 5 bản ghi/trang (hỗ trợ chọn 5, 10, 20, 50 phiên/trang).

---

## 📱 7. ẢNH HƯỞNG ĐẾN HỆ THỐNG & MOBILE APP (CLIENT-APP)

- **Đến Backend:**
  - Middleware kiểm tra cờ `active` bằng biến In-Memory tốc độ $O(1)$ ($< 0.05\text{ms}$), không tốn tài nguyên DB.
- **Đến Mobile App (Client-app):**
  - **Khi bật bảo trì:** Ứng dụng nhận sự kiện Socket, hiển thị ngay màn hình khóa bảo trì toàn phần, ngăn người dùng thực hiện giao dịch ghi. Người dùng vẫn xem được dữ liệu offline trong máy (Offline-first Drift SQLite).
  - **Khi tắt bảo trì:** Ứng dụng tự động kết nối lại, mở khóa các tính năng và đồng bộ hóa các giao dịch đang chờ trong SQLite lên máy chủ.

---

## 📡 8. DANH MỤC API & SOCKET.IO PHỤ TRÁCH

### REST API Endpoints
| Phương thức | Endpoint | Chức năng | Phân quyền |
|---|---|---|---|
| `GET` | `/api/admin/system/maintenance` | Lấy chi tiết trạng thái bảo trì & lịch hẹn hiện tại | Admin |
| `POST` | `/api/admin/system/maintenance` | Bật hoặc Tắt bảo trì khẩn cấp tức thì (yêu cầu mã PIN khi bật) | Admin |
| `POST` | `/api/admin/system/maintenance/schedule` | Lên lịch hẹn bảo trì tự động | Admin |
| `DELETE` | `/api/admin/system/maintenance/schedule` | Hủy bỏ lịch bảo trì đã hẹn | Admin |
| `GET` | `/api/admin/system/maintenance/history` | Lấy danh sách lịch sử các phiên bảo trì (có phân trang, bộ lọc) | Admin |

### Socket.io Events
- **Phát tán tới Toàn Hệ Thống (`broadcast`):**
  - `system.maintenance_changed`: Bắn tới toàn bộ người dùng di động khi trạng thái bảo trì bật/tắt.
- **Phát tán tới Phòng Quản Trị (`admin_room`):**
  - `admin.maintenance_changed`: Cập nhật trạng thái công tắc và card lịch hẹn trên mọi tab Admin-web đang mở.
