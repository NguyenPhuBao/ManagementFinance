# ⚡ Chức Năng 11: Kiến Trúc Real-Time Toàn Diện (Full Real-Time Architecture & Event Bus)

> **Mã chức năng:** `ADMIN-FEAT-11`  
> **Phiên bản:** `v2.6 (23/10/2026)`  
> **Trạng thái:** `Production Ready`  
> **Module phụ trách:**  
> - Frontend: `src/Admin-web/src/hooks/useSocket.js`, Toàn bộ các trang trong `src/Admin-web/src/pages/`  
> - Backend: `src/Backend/core/socket.js`, `src/Backend/index.js`, Các hook service nghiệp vụ (`auth.service.js`, `admin.service.js`, `maintenance.manager.js`, `aiops.service.js`)  

---

## 📌 1. TỔNG QUAN & MỤC ĐÍCH NGHIỆP VỤ

**Kiến Trúc Real-Time Toàn Diện (Full Real-Time Architecture)** là xương sống truyền thông dữ liệu của toàn bộ ứng dụng quản trị Admin-web. Trước đây, nhiều trang quản trị đòi hỏi người dùng phải bấm F5 tải lại trang hoặc phụ thuộc vào các cơ chế Polling định kỳ (gửi request liên tục gây tốn CPU và băng thông).

Với việc xây dựng **Trục Sự Kiện Tập Trung (Centralized Event Bus)** qua thư viện Socket.io v4 và phòng điều phối bảo mật `admin_room`:
- **100% các thông số, thẻ đếm, bảng danh sách, biểu đồ xu hướng và cảnh báo an ninh** trên toàn bộ Admin-web đều tự động cập nhật tức thì (độ trễ $< 50\text{ms}$).
- Không còn bất kỳ tình trạng stale state (dữ liệu cũ bị đọng) hay thao tác thủ công nào.

---

## ⚙️ 2. KIẾN TRÚC ĐIỀU PHỐI SỰ KIỆN TẬP TRUNG (CENTRALIZED REAL-TIME BUS)

```mermaid
graph TD
    subgraph "Nguồn Biến Động (Trigger Sources)"
        T1[Client-app: Đăng ký / Đăng nhập / Xóa tài khoản]
        T2[Client-app: Gửi Request API / Giao dịch]
        T3[Backend Engine: Nhịp tim phần cứng 3s / AIOps Sentinel]
        T4[Admin Action: Bật-Tắt bảo trì / Sửa danh mục]
    end

    subgraph "Backend Realtime Hub (src/Backend/core/socket.js)"
        GW[Socket.io Gateway - JWT Handshake Authentication]
        AR[Phòng Quản Trị Bảo Mật: admin_room]
        BC[Kênh Phát Sóng Toàn Mạng: broadcast]
    end

    subgraph "Các Thành Phần Nhận Dữ Liệu Tức Thời (Admin-web Consumers)"
        P1[Header: Chuông cảnh báo an ninh & Đếm chưa đọc]
        P2[AppLayout: Banner Báo Động Đỏ Threat >= 85]
        P3[Dashboard: Bảng Hoạt Động recentActivities & Nhịp Tim Server Health]
        P4[Server Health Panel: Nhịp tim CPU, RAM, Event Loop Lag mỗi 3s]
        P5[User Management: Tự nạp User mới, Nhảy Badge trạng thái]
        P6[Category Management: Nút 'Khôi phục' & 'Xóa' đồng bộ REST API]
        P7[Audit Log: Stream nhật ký request mới nhất lên đầu bảng]
        P8[Broadcast & Bảo Trì: Đồng bộ công tắc & Lịch hẹn bảo trì]
        P9[AIOps Sentinel: Đồng hồ Threat Score, 4 Vectơ, Bảng RCA & Phong tỏa]
    end

    T1 & T2 & T3 & T4 --> GW
    GW -->|idrole === 1| AR
    GW -->|Toàn bộ người dùng| BC

    AR -->|admin.metrics_stream| P3 & P4 & P9
    AR -->|admin.user_registered| P5
    AR -->|admin.user_status_changed| P5
    AR -->|audit_activity| P3 & P7
    AR -->|admin.maintenance_changed| P4 & P8
    AR -->|admin.security_alert| P1 & P2 & P9
    AR -->|admin.security_blocked| P2 & P9
    AR -->|admin.quarantine_updated| P9
    AR -->|admin.anomaly_detected| P9
    AR -->|admin.vector_config_changed| P9
    BC -->|system.maintenance_changed| P8
```

### 2.1. Xác Thực Bắt Tay Socket (JWT Handshake Authentication)
Để ngăn chặn người dùng bình thường hoặc kẻ xấu nghe lén thông tin nội bộ của máy chủ:
1. Khi Admin-web khởi tạo kết nối Socket.io, client đính kèm JWT Access Token trong `auth.token`.
2. Middleware xác thực trên server giải mã token:
   ```javascript
   const decoded = verifyAccessToken(token);
   socket.user = decoded;
   
   // Chỉ Quản trị viên (idrole === 1) mới được phép gia nhập admin_room
   if (decoded.idrole === 1) {
     socket.join('admin_room');
     logger.info(`[Socket] Admin ${decoded.username} đã gia nhập admin_room`);
   }
   ```
3. Các sự kiện quản trị nhạy cảm (`admin.*`) **chỉ được phát tới `admin_room`**, tuyệt đối không phát ra ngoài phòng công cộng.

---

## 📑 3. BẢNG TRA CỨU TOÀN BỘ 13 SỰ KIỆN REAL-TIME CỦA HỆ THỐNG

| Tên sự kiện Socket.io | Kênh truyền | Dữ liệu phát tải (Payload) | Thành phần tiếp nhận | Hành vi phản ứng trên giao diện |
|---|:---:|---|---|---|
| **`admin.metrics_stream`** | `admin_room` | `{ uptimeSeconds, eventLoopLagMs, cpuPercent, ramPercent, ramRssMb, threatScore, dbPool, environment }` | `ServerHealthPanel`, `DashboardPage`, `AIOpsPage` | Cập nhật kim đo phần cứng thật, chỉ số CPU/RAM, Uptime và Threat Score sau mỗi **3 giây/lần**. |
| **`admin.user_registered`** | `admin_room` | `{ iduser, idaccount, username, fullname, email, created_at }` | `UserListPage`, `DashboardPage` | Tự động chèn tài khoản mới vào đầu bảng có highlight viền xanh lá, cập nhật thẻ Bento KPI tổng số người dùng. |
| **`admin.user_status_changed`** | `admin_room` | `{ iduser, idaccount, status, reason_inactive, countdown }` | `UserListPage` | Cập nhật trực tiếp Badge trạng thái (`Active`, `Inactive`, `PendingDelete`, `Deleted`) mà không cần reload trang. |
| **`audit_activity`** | `admin_room` | `{ id, idaccount, user, action, status, reason, time_req, time_res, ip }` | `DashboardPage`, `AuditLogPage` | Chèn request mới nhất lên đầu bảng hoạt động khi ở Trang 1 và không lọc; hiện badge đếm log mới nếu đang lọc. |
| **`admin.maintenance_changed`** | `admin_room` | `{ active, isEmergency, reason, activatedBy, activatedAt, scheduled }` | `BroadcastPage`, `ServerHealthPanel` | Đồng bộ trạng thái công tắc bảo trì (Thường/Khẩn cấp), khóa công tắc tại Dashboard, cập nhật thẻ lịch hẹn bảo trì. |
| **`system.maintenance_changed`** | `broadcast` | `{ active, isEmergency, reason, activatedAt }` | Toàn bộ Client-app & Admin-web | Hiển thị màn hình khóa bảo trì toàn phần trên mobile hoặc Global Banner trên Admin-web. |
| **`system_broadcast`** | `broadcast` | `{ title, message, level, timestamp }` | Toàn bộ Client-app | Kích hoạt SnackBar (Info), Top Banner (Warning) hoặc Pop-up chặn (Critical) trên ứng dụng Flutter. |
| **`force_logout`** | P2P Socket ID | `{ code, reason, timestamp }` | Client-app cụ thể | Cưỡng chế xóa token và đẩy thiết bị người dùng bị khóa/xóa về màn hình Đăng nhập. |
| **`admin.security_alert`** | `admin_room` | `{ threatScore, status, anomalies, timestamp }` | `Header`, `AppLayout`, `AIOpsPage` | Rung chuông Header (+1 badge), hiện Banner đỏ nếu Threat Score $\ge 85$, nhảy kim đồng hồ AIOps. |
| **`admin.security_blocked`** | `admin_room` | `{ hash, maskedIp, reason, bannedAt, expiresAt }` | `AppLayout`, `AIOpsPage` | Hiện thông báo Toast góc màn hình và nạp ngay IP vi phạm vào Bảng Nguồn theo dõi đặc biệt. |
| **`admin.quarantine_updated`** | `admin_room` | `{ type, ip, username, status, expiresAt }` | `AIOpsPage` | Tự động cập nhật bảng phong tỏa khi có IP hoặc Tài khoản được mở khóa hoặc hết hạn tự động (Auto-expire). |
| **`admin.anomaly_detected`** | `admin_room` | `{ incidentId, code, vector, severity, message, timestamp }` | `AIOpsPage` | Tự động chèn sự cố mới vào đầu Bảng Bóc Tách Nguyên Nhân Gốc Rễ (RCA) trong CSDL PostgreSQL. |
| **`admin.vector_config_changed`** | `admin_room` | `{ thresholds, updatedBy, updatedAt }` | `AIOpsPage` | Đồng bộ các vạch ngưỡng cảnh báo & khẩn cấp của 4 vectơ trên biểu đồ SVG khi có Quản trị viên thay đổi cấu hình. |

---

## 🛡️ 4. CƠ CHẾ TRIỆT TIÊU TOAST LẶP LẠI 3 TẦNG (3-TIER TOAST DE-DUPLICATION)

Khi quản trị viên thao tác trực tiếp trên giao diện (ví dụ: Bật/Tắt bảo trì khẩn cấp), nếu không có cơ chế lọc, trình duyệt sẽ nhận cả phản hồi từ API REST lẫn sự kiện Socket.io dội về, gây ra hiện tượng hiển thị 2 Toast thông báo giống hệt nhau liên tiếp. Hệ thống xử lý triệt để qua 3 tầng:

```mermaid
graph TD
    A[Admin thực hiện thao tác] --> B[Gọi API REST thành công]
    B --> C[Tầng 1: Hiển thị Toast thao tác trực tiếp]
    B --> D[Đánh dấu cờ isActionInitiatorRef = true]
    
    A -.-> E[Backend phát sự kiện Socket admin.maintenance_changed]
    E --> F[Socket Listener nhận sự kiện]
    F --> G{Tầng 2: isActionInitiatorRef == true?}
    G -- "Có (Là người phát lệnh)" --> H[Hủy Toast Socket & Reset cờ sau 500ms]
    G -- "Không (Nhận từ phiên khác)" --> I{Tầng 3: Deduplication Debounce Cache 1500ms?}
    I -- "Trùng lặp trong 1.5s" --> J[Bỏ qua Toast trùng]
    I -- "Thông báo mới hợp lệ" --> K[Hiển thị Toast cho Admin khác]
```

1. **Tầng 1 — Direct Action Feedback:** Phản hồi Toast thành công ngay tại callback của lệnh gọi API REST.
2. **Tầng 2 — Originator Flag Suppression (`isActionInitiatorRef`):** Sử dụng React Ref ghi nhận cờ "Người khởi tạo". Khi Socket dội sự kiện về chính tab đó, listener kiểm tra cờ và bỏ qua việc phát thêm Toast thứ hai.
3. **Tầng 3 — Global Alert Deduplication Debounce (1500ms):** Trong `alert.context.jsx`, hệ thống lưu băm nội dung thông báo gần nhất kèm timestamp. Bất kỳ thông báo nào có nội dung tương tự xuất hiện trong vòng $1,500\text{ms}$ đều bị loại bỏ tự động.

---

## ⏱️ 5. GIÁM SÁT ĐỘ TRỄ KẾT NỐI REAL-TIME (PING LATENCY MONITORING)

Để quản trị viên luôn kiểm chứng được tính liên tục và độ tin cậy của luồng dữ liệu thời gian thực:
- **Cơ chế Heartbeat Ping-Pong:** Định kỳ mỗi 10 giây, client gửi gói tin `ping` tới server và đo thời gian nhận lại `pong` tương ứng:
  $$\text{Latency (ms)} = \text{Time}_{\text{pong}} - \text{Time}_{\text{ping}}$$
- **Phản xạ màu sắc trên thanh trạng thái:**
  - $\text{Latency} < 50\text{ms}$: Xanh ngọc lục bảo (`text-emerald-500`) — Kết nối cực nhanh và ổn định.
  - $50\text{ms} \le \text{Latency} < 150\text{ms}$: Vàng hổ phách (`text-amber-500`) — Kết nối trung bình.
  - $\text{Latency} \ge 150\text{ms}$ hoặc Mất kết nối: Đỏ hồng (`text-rose-500`) — Cảnh báo trễ mạng hoặc tự động chuyển sang REST Polling Fallback.

---

## 📐 6. CÁC THÔNG SỐ HIỆU NĂNG & TỐI ƯU HÓA (PERFORMANCE METRICS)

1. **Kích thước gói tin cực nhỏ (Micro-Payload):**
   - Payload sự kiện `admin.metrics_stream` được tối ưu hóa chỉ nặng **$< 450$ bytes**.
   - Băng thông tiêu thụ trên mỗi kết nối Admin mở cả ngày: $\approx 12.9\text{MB}$ / 24 giờ.
2. **Cơ chế Timer Unref (`timer.unref()`):**
   - Bộ đếm thời gian 3s trong `index.js` sử dụng `.unref()` để không giữ tiến trình Node.js sống vô tận khi quản trị viên gửi tín hiệu dừng máy chủ (`SIGINT` / `SIGTERM`), đảm bảo server tắt (Graceful Shutdown) sạch sẽ trong $< 1$ giây.
3. **Giải phóng lắng nghe React Hook (`useSocket.js`):**
   - Mọi component khi `unmount` đều bắt buộc phải gọi hàm dọn dẹp `socket.off(eventName, handler)`.
   - Ngăn chặn hoàn toàn hiện tượng rò rỉ bộ nhớ (Memory Leak) hoặc nhân đôi sự kiện (Duplicate Event Callbacks) trên trình duyệt.

---

## ⛔ 7. NGUYÊN TẮC BẢO MẬT & PHÁP LÝ (DATA SECURITY)

1. **Zero Raw PII trên luồng Socket:**
   - Mọi địa chỉ IP phát qua Socket.io đều được che 2 octet cuối: `113.161.xx.xx`.
   - Tuyệt đối không phát tán mật khẩu, Access Token hoặc dữ liệu số dư tài khoản chi tiết qua kênh Socket.io.
2. **Cách ly phòng quản trị:**
   - Người dùng di động (Client-app) hoàn toàn không thể lắng nghe các sự kiện tiền tố `admin.*`. Nếu Client cố tình gửi lệnh join `admin_room`, server sẽ kiểm tra token và từ chối.

---

## 💼 8. CÔNG DỤNG & GIÁ TRỊ NGHIỆP VỤ

- **Trải nghiệm điều hành chuẩn phòng chỉ huy (Command Center Experience):** Quản trị viên chỉ cần mở màn hình và quan sát, các con số và biểu đồ tự nhảy số nhịp nhàng như trên bảng điện tử chứng khoán.
- **Phản ứng sự cố tức thì:** Khi có đợt tấn công an ninh, thông báo xuất hiện trên màn hình ngay thời khắc mili-giây đầu tiên, giúp Admin can thiệp trước khi server bị sập.
- **Tiết kiệm tài nguyên:** Giảm hơn **$90\%$ số lượng request HTTP thăm dò** lên máy chủ so với cơ chế Polling truyền thống.

---

## 📱 9. ẢNH HƯỞNG ĐẾN HỆ THỐNG & MOBILE APP (CLIENT-APP)

- **Đến Backend:**
  - Socket.io tích hợp chạy chung cổng HTTP với Express Server, chia sẻ chung kết nối TCP, giảm thiểu việc phải mở nhiều cổng mạng.
- **Đến Mobile App (Client-app):**
  - Khi quản trị viên thực hiện bất kỳ hành động điều phối nào (Bật bảo trì, phát thông báo, khóa tài khoản), thiết bị di động của người dùng sẽ nhận được tín hiệu qua Socket chỉ sau $< 100\text{ms}$, mang lại sự đồng bộ tuyệt đối trên toàn bộ hệ sinh thái.
