# KẾ HOẠCH TRIỂN KHAI: TỐI ƯU HÓA ĐIỀU HÀNH BẢO TRÌ & LỊCH SỬ PHÁT SÓNG THÔNG BÁO HỆ THỐNG
*(System Maintenance Architecture & Broadcast Notifications Refinement Plan)*

**Tài liệu chuẩn hóa:** `docs/Admin-web/MAINTENANCE_BROADCAST_REFINEMENT_PLAN.md`  
**Phiên bản:** 1.0.0 — Dành riêng cho xét duyệt từ Product Owner (PO)  
**Tác giả:** Lead BA & Lead FullStack Cao Cấp & QA Architect  
**Tuân thủ quy chuẩn:** Supreme Mandatory Rules (PO First, Dual-Axis, Ask PO), Data Security (`Data_Security.md`), DB Guard (Rule 10), 2-Tier Testing Architecture (Rule 11).

---

## I. KHẢO SÁT THỰC TRẠNG & GIẢI TRÌNH KIẾN TRÚC TỪ LEAD ARCHITECT

### 1. Giải trình câu hỏi kiến trúc của PO:
> *"Cần thiết kế lại cách tiếp nhận và xử lý phần bảo trì để khi cập nhật các tính năng khác sẽ không ảnh hưởng tới Bảo trì. Và nếu cần cập nhật phần bảo trì thì sao ?"*

#### A. Tại sao cập nhật tính năng khác có nguy cơ ảnh hưởng đến Bảo trì (nếu thiết kế lỏng lẻo)?
- Nếu cơ chế bảo trì bị phụ thuộc (tight coupling) vào các bảng CSDL nghiệp vụ (`account`, `transaction`, `categories`, `wallets`...) hoặc gọi qua service của các module khác:
  + Khi một module khác thay đổi cấu trúc dữ liệu, chạy migration bị lock bảng, hoặc crash runtime, middleware bảo trì có thể bị nghẽn (hang/timeout) theo, khiến hệ thống mất khả năng phòng vệ.
- Nếu middleware bảo trì truy vấn trực tiếp CSDL mỗi khi có request:
  + Khi CSDL quá tải (DB Connection Pool cạn kiệt), middleware bảo trì cũng không thể thực thi để trả về HTTP 503 cho client, dẫn đến sập toàn diện (Cascading Failure).

#### B. Thiết kế chuẩn hóa: Mô hình Tách Biệt Kênh Điều Hành & Kênh Phòng Vệ (Control Plane vs. Data Plane Isolation)
1. **Kênh phòng vệ ở tầng rìa ứng dụng (Data Plane Guard — Zero Business Dependency):**
   - Middleware `maintenance.middleware.js` được đặt ở cấp cao nhất trong HTTP pipeline (`src/Backend/server.js`), đứng trước tất cả các router nghiệp vụ.
   - Việc kiểm tra trạng thái bảo trì `isMaintenanceActive()` diễn ra hoàn toàn trên **RAM (In-Memory)** và đồng bộ tức thì qua Redis (nếu có). Độ phức tạp là **$O(1)$**, tiêu tốn $0\text{ms}$ và **hoàn toàn KHÔNG truy vấn CSDL nghiệp vụ hay Prisma**.
   - Ngoại lệ an toàn (Safe Bypass): Chỉ các API định danh Admin (`/api/admin/*`, `/api/auth/login-admin`) và Healthcheck (`/health`, `/metrics`) được thông luồng. Toàn bộ các request nghiệp vụ khác lập tức nhận về `HTTP 503 Service Unavailable`.
   - $\rightarrow$ **Kết quả:** Bất kể các tính năng khác (giao dịch, ví tiền, thanh toán, đồng bộ dữ liệu...) có được sửa đổi, nâng cấp hay thêm mới, chúng **hoàn toàn không thể tác động hay làm hỏng cơ chế bảo vệ của Bảo trì**.

2. **Kênh điều hành độc lập (Control Plane Isolation):**
   - Bộ quản trị `maintenance.manager.js` và bảng CSDL `maintenance_history` là **module tự chủ (Stand-alone)**:
     + Bảng `maintenance_history` không có bất kỳ Foreign Key nào trỏ tới các bảng nghiệp vụ.
     + Có cơ chế **Graceful Fallback**: Nếu CSDL Supabase bị lag hoặc gián đoạn, `MaintenanceManager` vẫn bật/tắt bảo trì thành công trên RAM/Redis để bảo vệ hệ thống ngay lập tức, không để lỗi ghi log CSDL làm sập tiến trình bật/tắt bảo trì.

3. **Và nếu cần cập nhật chính phần bảo trì thì sao?**
   - **Về Backend:** Module bảo trì được bao bọc độc lập, có bộ kiểm thử riêng (`admin.priority.maintenance.test.js`, `admin.maintenance.history.test.js`). Khi cần bổ sung logic bảo trì (như mở rộng trường lịch trình, logic hẹn giờ), chỉ cần cập nhật trong `maintenance.manager.js` và chạy bộ test riêng biệt mà không ảnh hưởng tới bất kỳ controller hay service nghiệp vụ nào khác.
   - **Về Frontend:** Tách biệt rõ 2 cấp độ:
     + *Dashboard (`ServerHealthPanel.jsx`)*: Chỉ đóng vai trò Widget quan sát trạng thái và là "Cửa thoát hiểm khẩn cấp ban đầu". Khi hệ thống đã vào bảo trì, toggle trên Dashboard **MẶC ĐỊNH BỊ KHÓA** để chống thao tác nhầm làm gãy luồng.
     + *Trang Điều hành chuyên biệt (`BroadcastPage.jsx`)*: Nơi tập trung toàn bộ quyền điều hành, lịch sử CSDL, lên lịch và bắt buộc có **Popup xác nhận kết thúc bảo trì** trước khi hành động.

---

### 2. Thảo luận & Đề xuất phương án CSDL lưu trữ thông báo Broadcast:
> PO đặt vấn đề: *"Cần có CSDL lưu lại các thông báo - Thảo luận để xác định xem nên lưu all hay những phần thông báo quan trọng"*

- **Hiện trạng:** Thông báo phát sóng (System Broadcast) hiện chỉ đẩy qua Socket.IO và lưu tạm vào Redis list (tối đa 50 item, tự mất khi khởi động lại). PostgreSQL chưa có bảng lưu lịch sử phát sóng.
- **Phân tích 2 phương án:**
  - *Phương án 1: Chỉ lưu thông báo quan trọng (CRITICAL / WARNING):*
    + Nhược điểm: Các thông báo thường (INFO) như "Chào mừng phiên bản mới", "Tính năng ví mới", "Thông báo lịch bảo dưỡng định kỳ" sẽ biến mất không dấu vết. Admin không có căn cứ tra cứu lịch sử ai đã gửi thông báo gì cho người dùng.
  - *Phương án 2 (ĐỀ XUẤT TỐI ƯU CỦA LEAD BA & ARCHITECT): Lưu TẤT CẢ thông báo do Admin chủ động phát sóng (System Broadcast):*
    + **Lý do 1:** Tần suất Admin chủ động phát thanh toàn hệ thống rất ít (vài lần/tuần hoặc tháng). Dữ liệu này cực kỳ nhẹ (chỉ tốn vài KB/năm), không gây áp lực tài nguyên CSDL.
    + **Lý do 2:** Tuân thủ pháp lý & quy định kiểm toán (`docs/Rule_Project/Data_Security.md` §5): Bất kỳ thông điệp nào gửi đến toàn bộ người dùng đều cần lưu vết audit (Ai gửi? Lúc nào? Mức độ nào? Nội dung gì?).
    + **Lý do 3:** Phục vụ bảng lịch sử phân trang 5 dòng/trang theo đúng yêu cầu PO, giúp Admin xem lại lịch sử gửi thông báo bất kỳ lúc nào.
- **Cấu trúc bảng PostgreSQL `broadcast_notification`:**
  - `id`: `SERIAL PRIMARY KEY`
  - `title`: `VARCHAR(255) NOT NULL`
  - `message`: `TEXT NOT NULL`
  - `level`: `VARCHAR(20) NOT NULL DEFAULT 'INFO'` (`INFO`, `WARNING`, `CRITICAL`)
  - `sender_username`: `VARCHAR(100) NOT NULL DEFAULT 'admin'`
  - `created_at`: `TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()`
  - Index: `created_at DESC`
  - *Khởi tạo an toàn (DB Guard Rule 10):* Tạo qua script init / pool query độc lập, tuyệt đối không chạy `prisma migrate dev` hay `prisma db push` trên Supabase Cloud.

---

### 3. Khảo sát chi tiết các Issue Log trên giao diện:

| STT | Vị trí | Hiện trạng | Yêu cầu chuẩn hóa |
|---|---|---|---|
| 1 | **Tab Phát thông báo** (`BroadcastPage.jsx`) | Dưới form phát thanh có khối ghi chú quy tắc vận hành (info Quy tắc vận hành phát thanh...) | **BỎ** hoàn toàn khối ghi chú này. |
| 2 | **Tab Phát thông báo** (`BroadcastPage.jsx`) | Chưa có bảng lịch sử các thông báo phát sóng | **THÊM** bảng danh sách thông báo đã phát sóng: Cột `#`, `Mức độ`, `Tiêu đề`, `Nội dung`, `Người gửi`, `Thời gian gửi`. Phân trang mặc định **5 dòng/trang** (tùy chọn 5, 10, 20). Tự động nạp lại sau khi phát thông báo thành công. |
| 3 | **Tab Điều hành bảo trì** (`BroadcastPage.jsx`) | Bảng "Lịch Sử Các Phiên Bảo Trì Hệ Thống" có icon cong quay lại (nút Làm mới) ở header bảng | **BỎ** nút làm mới này vì bảng đã tự động đồng bộ realtime qua socket và khi đổi trang/bộ lọc. |
| 4 | **Header cam bảo trì** (`AppLayout.jsx`) | Có icon `⚠️` trước chữ "HỆ THỐNG ĐANG BẢO TRÌ" | **BỎ** icon `⚠️`. Đảm bảo nút "Quản trị bảo trì" điều hướng mượt mà đến trang `/broadcast`. |
| 5 | **Dashboard > Sức khỏe máy chủ** (`ServerHealthPanel.jsx`) | Thẻ bảo trì hiển thị giống nhau giữa thường và khẩn cấp; khi đang bảo trì toggle vẫn bấm được | **Phân biệt giao diện rõ rệt:**<br>• *Khẩn cấp*: Theme đỏ hồng (`bg-rose-50 border-rose-300`), icon đỏ, badge "BẢO TRÌ KHẨN CẤP".<br>• *Thông thường*: Theme vàng cam (`bg-amber-50 border-amber-300`), icon cam, badge "BẢO TRÌ THÔNG THƯỜNG".<br>• **Khóa toggle:** Khi hệ thống đang bảo trì (thường hay khẩn cấp), toggle **mặc định bị khóa (`disabled={true}`)**, không cho gạt tắt từ Dashboard mà phải vào trang `/broadcast`. |
| 6 | **Trang Bảo trì & Thông báo** (`BroadcastPage.jsx`) | Banner bảo trì đang hiển thị icon `🚨` và hiển thị nhầm "KHẨN CẤP" dù là phiên bảo trì theo lịch | • **BỎ** icon `🚨`.<br>• Phân biệt giao diện đồng nhất với Dashboard (Đỏ hồng cho Khẩn cấp, Vàng cam cho Thông thường theo lịch).<br>• Hiển thị banner này nổi bật gần đầu trang khi bảo trì kích hoạt. |
| 7 | **Tắt bảo trì** (`BroadcastPage.jsx`) | Nhấn "Tắt Bảo Trì" lập tức gọi API tắt ngay không qua bước xác nhận | **Hiển thị Popup Modal xác nhận:** "Bạn có chắc chắn muốn kết thúc phiên bảo trì và khôi phục hoạt động bình thường cho toàn bộ người dùng?". Xác nhận thì mới thực thi gọi API. |

---

## II. KẾ HOẠCH TRIỂN KHAI CHI TIẾT (IMPLEMENTATION PHASES)

### Phase 1: Backend Persistence & REST API cho Broadcast History
1. **Tạo Repository `src/Backend/modules/notification/broadcast.repository.js`:**
   - Hàm `initTable()`: Khởi tạo bảng `broadcast_notification` nếu chưa tồn tại (kèm chỉ mục `created_at DESC`).
   - Hàm `createRecord({ title, message, level, sender_username })`: Ghi nhận thông báo phát sóng vào PostgreSQL. Có fallback bộ nhớ an toàn.
   - Hàm `getHistory({ page = 1, limit = 5, level })`: Đọc danh sách kèm phân trang và tổng số bản ghi.
2. **Cập nhật `notification.service.js` & `notification.controller.js`:**
   - Khi Admin gọi `POST /api/notifications/broadcast`, trích xuất `sender_username` từ JWT Admin (`req.user.username || 'admin'`), gọi `broadcastRepository.createRecord(...)`.
   - Bổ sung endpoint `GET /api/notifications/broadcast/history` (yêu cầu quyền Admin) trả về danh sách lịch sử phát sóng phân trang.
3. **Cập nhật route `src/Backend/api/notification.routes.js`:**
   - Đăng ký `router.get('/broadcast/history', authorize('admin'), notificationController.getBroadcastHistory)`.

### Phase 2: Frontend Client API & Điều Chỉnh Header Banner (`AppLayout.jsx`)
1. **Bổ sung API trong `src/Admin-web/src/api/notification.api.js`:**
   - `getBroadcastHistory: (params = { page: 1, limit: 5 }) => axiosClient.get('/notifications/broadcast/history', { params })`.
2. **Hiệu chỉnh Banner Header cam trong `src/Admin-web/src/components/layout/AppLayout.jsx`:**
   - Xóa icon `⚠️` khỏi chuỗi dịch `appLayout.maintenanceBannerTitle` trong `vi.js`, `en.js` và trực tiếp trong JSX fallback.
   - Kiểm tra nút "Quản trị bảo trì": đảm bảo gọi `navigate('/broadcast')` chuyển trang chính xác.

### Phase 3: Chuẩn Hóa Dashboard Server Health Panel (`ServerHealthPanel.jsx`)
1. **Phân biệt kiểu hiển thị Bảo trì Thông thường vs. Bảo trì Khẩn cấp:**
   - Kiểm tra cờ `maintenance.isEmergency`:
     + Nếu `true`: Banner đỏ hồng nhạt, tiêu đề "Bảo trì khẩn cấp", mô tả "Cắt toàn bộ Client, giữ Admin thông luồng".
     + Nếu `false`: Banner vàng/cam dịu, tiêu đề "Bảo trì thông thường (Theo lịch / Kỹ thuật)", mô tả "Bảo trì kỹ thuật định kỳ hệ thống".
2. **Khóa công tắc toggle:**
   - Khi `maintenance.active === true`, gán `disabled={true}` cho nút toggle `#btn-maintenance-toggle`, style con trỏ `cursor-not-allowed opacity-60`, thêm chú thích rõ ràng yêu cầu truy cập `/broadcast` để điều hành an toàn.

### Phase 4: Nâng Cấp Trang Bảo Trì & Phát Sóng Thông Báo (`BroadcastPage.jsx`)
1. **Header & Thẻ trạng thái đang bảo trì:**
   - Bỏ icon `🚨` trong `emergencyTitle` (cập nhật `vi.js`, `en.js`).
   - Thiết kế banner trạng thái đang bảo trì phân biệt rõ giữa Bảo trì Khẩn Cấp (đỏ hồng) và Bảo trì Thông Thường (vàng cam dịu), đồng nhất hoàn hảo với Dashboard.
2. **Popup Modal Xác Nhận Kết Thúc Bảo Trì:**
   - Khi click nút "Tắt Bảo Trì", mở popup xác nhận với thông điệp rõ ràng, ngăn chặn click nhầm làm mở cổng người dùng khi chưa chuẩn bị xong.
3. **Tab Điều hành bảo trì:**
   - Xóa bỏ nút làm mới (icon cong `refresh`) ở header bảng "Lịch Sử Các Phiên Bảo Trì Hệ Thống".
4. **Tab Phát thông báo:**
   - Xóa bỏ khối ghi chú quy tắc vận hành phát thanh ở cuối tab.
   - Thêm bảng hiển thị "Lịch Sử Các Thông Báo Đã Phát Sóng":
     + Đầy đủ các cột: `#`, `Mức độ` (Badge màu INFO/WARNING/CRITICAL), `Tiêu đề`, `Nội dung thông báo`, `Người phát sóng`, `Thời điểm phát sóng`.
     + Tích hợp component `Pagination` với mặc định là **5 dòng/trang** (tùy chọn 5, 10, 20).
     + Tự động tải lại bảng lịch sử ngay sau khi form gửi thông báo thành công.

### Phase 5: Kiểm Thử 2 Tầng (2-Tier Testing) & Nghiệm Thu
1. **Tầng 1 (UI Rendering & Interaction):**
   - Render đầy đủ bảng lịch sử phát sóng, các trường dữ liệu và phân trang 5 mục/trang.
   - Không còn hiển thị khối ghi chú quy tắc, không còn nút làm mới ở bảng lịch sử bảo trì, không còn icon `⚠️` và `🚨`.
   - Nút "Tắt Bảo Trì" khi click phải bật Popup Modal xác nhận.
   - Toggle tại Dashboard bị khóa `disabled` khi bảo trì đang bật.
2. **Tầng 2 (System Impact & Behavioral Verification):**
   - API `POST /api/notifications/broadcast` thực sự lưu bản ghi vào CSDL PostgreSQL và trả về phân trang qua `GET /api/notifications/broadcast/history`.
   - Xác nhận kết thúc bảo trì trên Popup Modal thực sự gửi request `active: false` đến backend và đưa hệ thống trở lại bình thường.
   - Chạy toàn bộ test suites (`rtk npm test` Backend & Admin-web).
   - Cập nhật tài liệu nguồn sự thật `Project.md` và tái tạo CodeGraph (`rtk npx codegraph build`).

---

## III. CAM KẾT CHẤT LƯỢNG & BẢO VỆ DỰ ÁN
- ✅ **DB Guard (Rule 10):** Tuyệt đối không chạy `prisma migrate dev` hoặc `prisma db push` trên CSDL Supabase Cloud. Khởi tạo bảng qua script native an toàn.
- ✅ **Data Security (Rule 9):** Thông báo chỉ lưu thông điệp quản trị và username, không chứa dữ liệu nhạy cảm. Phân quyền chặt chẽ qua middleware `authorize('admin')`.
- ✅ **Zero Regressions:** Bảo trì được cách ly hoàn toàn, không ảnh hưởng đến bất kỳ luồng thanh toán, người dùng, ví hay danh mục nào.
- 🛑 **CHỜ PHÊ DUYỆT TỪ PRODUCT OWNER (PO):** AI sẽ KHÔNG chỉnh sửa mã nguồn cho đến khi nhận được lệnh đồng ý phê duyệt chính thức từ PO.
