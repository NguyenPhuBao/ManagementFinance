# 📋 KẾ HOẠCH CHI TIẾT SỬA CHỮA & TINH CHỈNH DASHBOARD (ADMIN-WEB)
> **Dự án:** Personal Finance Management — Module `src/Admin-web` & `src/Backend`  
> **Tài liệu nguồn sự thật kế hoạch:** `docs/Admin-web/DASHBOARD_REFINEMENT_PLAN.md`  
> **Người lập:** Lead BA + Lead FullStack + Lead Tester  
> **Phê duyệt bởi:** Product Owner (PO)  
> **Ngày lập:** 2026-10-21  
> **Quyết định cốt lõi đã chốt:** PO duyệt **Phương án 1 (Chuẩn SLA Công nghiệp)** cho Thẻ Uptime Hệ thống.

---

## 🎯 I. TỔNG QUAN YÊU CẦU & KẾT QUẢ KHẢO SÁT THỰC TẾ

Dựa trên khảo sát thực tế tại URL `https://management-finance-gamma.vercel.app/dashboard` và mã nguồn hiện tại, các vấn đề tồn đọng được phân tích và xác định nguyên nhân kỹ thuật chi tiết như sau:

| STT | Vị trí / Thành phần | Yêu cầu từ PO | Hiện trạng & Nguyên nhân kỹ thuật | Giải pháp kỹ thuật |
|---|---|---|---|---|
| **1** | **Header Dashboard** | - Bỏ dòng text phụ đề: *"Dữ liệu tài chính và hoạt động được cập nhật liên tục để cung cấp cái nhìn toàn diện về hiệu suất."*<br>- Bỏ nút *"Bảo trì khẩn cấp"* ở góc phải header. | Dòng subtitle nằm tại thẻ `<p>{t('dashboard.subtitle')}</p>` (dòng 873). Nút bảo trì khẩn cấp (dòng 878-905) bị lặp với Tab Sức khỏe máy chủ và trang Quản trị bảo trì (`/broadcast`), làm rối giao diện. | Xóa thẻ `<p>` subtitle và component `<button>` bảo trì khẩn cấp khỏi Header `DashboardPage.jsx`. |
| **2** | **Thẻ "Uptime Hệ thống"** | Xác định công thức tính: Thời gian hệ thống hoạt động chưa trừ đi thời gian bảo trì. *(Đã trình PO duyệt: Áp dụng Phương án 1 - Chuẩn SLA Công nghiệp).* | Hiện tại `process.uptime()` chỉ đo thời gian tiến trình Node.js chạy liên tục. Nếu hệ thống bật bảo trì 2 giờ thì runtime vẫn cộng dồn vào uptime, không trừ đi thời gian gián đoạn phục vụ. | Chuẩn hóa Backend `admin.service.js`: `Runtime = Tổng thời gian máy chủ - Thời gian bảo trì khẩn cấp`. Uptime SLA (%) trừ thời gian bảo trì khẩn cấp (Emergency Outage). Đồng nhất hiển thị giữa Card và Tab Sức khỏe. |
| **3** | **Bảng Hoạt động gần đây** | - Các cột cố định độ rộng trước, nếu dài quá thì ẩn bằng `...` và hiển thị tooltip khi rê chuột.<br>- Thu nhỏ lại một nửa cho cột *"Hành động"*.<br>- Nút nhỏ trạng thái real-time phải hiển thị đúng, nếu mất kết nối phải đổi trạng thái ngay. | Thẻ `<table>` chưa có CSS `table-fixed`, các cột co dãn tự do theo độ dài text. Cột Hành động đang chiếm `w-[24%] min-w-[150px]` quá rộng. Real-time badge chỉ lắng nghe sự kiện `connect`/`disconnect` cơ bản, chưa xử lý `connect_error`, `reconnect_attempt`, hoặc timeout khiến trạng thái bị treo xanh. | Áp dụng `table-fixed` cho bảng; giảm cột Hành động xuống `w-[12%] min-w-[95px]`; phân bổ lại độ rộng; dùng `TruncateCell` kèm `title` tooltip; nâng cấp bộ lắng nghe trạng thái kết nối socket toàn diện (Connected, Reconnecting, Disconnected). |
| **4** | **Tab Sức khỏe hệ thống** | - Cập nhật lại uptime cho khớp với thẻ Card Uptime ở trên.<br>- Áp dụng xác thực mã PIN cho công tắc bật Bảo trì khẩn cấp. | Thẻ Card Uptime đọc từ `getSystemHealth()` hiển thị định dạng *"57 phút"*, trong khi Widget Uptime trong `ServerHealthPanel` nhận stream thời gian thực từ `admin.metrics_stream` với định dạng *"0d 1h 6m 45s"*, gây lệch số liệu và định dạng. Toggle bảo trì khẩn cấp trong `ServerHealthPanel` bật/tắt trực tiếp qua `adminApi.setMaintenanceStatus` mà không bắt xác thực mã PIN. | Chuẩn hóa hàm format và nguồn dữ liệu uptime đồng nhất; tích hợp `SecurityConfirmModal` (yêu cầu nhập mã PIN bảo mật) trước khi cho phép kích hoạt công tắc bảo trì khẩn cấp trong `ServerHealthPanel`. |
| **5** | **Biểu đồ Đăng nhập & Lưu lượng Request** | - Biểu đồ Request: Bỏ nút nhỏ `Live Mode`.<br>- Cả 2 Biểu đồ: Thêm nút nhỏ hiển thị Real-time ở góc phải tương tự bảng Hoạt động gần đây. | Biểu đồ Request có nút tĩnh `Live Mode` xanh nhấp nháy (`animate-ping`) nhưng biểu đồ Đăng nhập lại không có. Cả 2 chưa có badge báo trạng thái kết nối socket thực sự. | Bỏ nút `Live Mode`; đưa component `RealtimeStatusBadge` dùng chung lên góc phải tiêu đề của cả Biểu đồ Đăng nhập và Biểu đồ Lưu lượng Request. |

---

## 🏛️ II. PHÂN TÍCH TÁC ĐỘNG THEO 2 CHIỀU (DUAL-AXIS REASONING)

### 1. Suy luận theo chiều ngang (Horizontal Reasoning)
- **src/Backend (`modules/admin/admin.service.js` & `index.js`):**
  - Hàm `calcUptimePercent` và `formatUptimeDuration`:
    + Tính toán thời gian hoạt động thực tế phục vụ người dùng (`activeRuntimeSec = Math.max(0, processUptimeSec - emergencyDowntimeSec)`).
    + Chuẩn hóa định dạng hiển thị thời gian uptime đồng nhất giữa REST API (`/admin/system/health`) và Socket Event (`admin.metrics_stream`).
- **src/Admin-web (`pages/dashboard/` & `components/`):**
  - Tạo mới component `RealtimeStatusBadge.jsx`: Quản lý 3 trạng thái kết nối Socket.IO:
    1. 🟢 `Real-time`: Khi socket đang `connected = true`.
    2. 🟡 `Đang kết nối lại...`: Khi socket đang `reconnecting` hoặc `connect_error`.
    3. 🔴 `Mất kết nối`: Khi socket bị `disconnect` hoặc mất mạng hoàn toàn.
  - Tích hợp `RealtimeStatusBadge` tại 3 vị trí: Bảng Hoạt động gần đây, Biểu đồ Đăng nhập, Biểu đồ Request.
  - Nâng cấp `ServerHealthPanel.jsx`:
    + Nhúng `SecurityConfirmModal` với action type `EMERGENCY_MAINTENANCE` để xác thực mã PIN trước khi bật bảo trì.
    + Nhận và hiển thị uptime đồng bộ với Card Uptime trên Dashboard.

### 2. Suy luận theo chiều sâu (Vertical / Deep-Impact Reasoning)
- **Zero Regressions & Không làm hỏng dữ liệu:**
  - Không thay đổi cấu trúc bảng CSDL, không vi phạm DB Guard (Rule 10).
  - Hành động bảo trì khẩn cấp được bảo vệ bằng mã PIN chuẩn 6 số qua endpoint `/api/admin/verify-security-action`, tự động ghi Audit Log bất biến chuẩn OWASP & ISO 27001.
  - Khi người dùng mất kết nối Internet, giao diện tự động cảnh báo `Mất kết nối` trên toàn bộ các khối giám sát thời gian thực, không tạo cảm giác giả mạo thông số.

---

## 📋 III. KẾ HOẠCH TRIỂN KHAI CHI TIẾT TỪNG BƯỚC

### 🔹 Giai đoạn 1: Chuẩn hóa Backend Uptime Service & Đồng bộ Metrics Stream
- [x] **Bước 1.1:** Cập nhật `src/Backend/modules/admin/admin.service.js`:
  - Lấy tổng thời gian bảo trì khẩn cấp từ `defaultMaintenanceManager.getHistory()`.
  - Tính toán `activeUptimeSec = Math.max(0, Math.floor(process.uptime()) - emergencyDowntimeSec)`.
  - Chuẩn hóa hàm `formatUptimeDuration` hiển thị định dạng thân thiện, khoa học (ví dụ: `1 ngày 2 giờ 15 phút` hoặc `57 phút`).
- [x] **Bước 1.2:** Cập nhật `src/Backend/index.js`:
  - Trong luồng phát `admin.metrics_stream`, sử dụng cùng công thức và hàm format chuẩn từ `admin.service.js`, bảo đảm stream Socket và REST API trả về số liệu khớp 100%.

### 🔹 Giai đoạn 2: Tinh chỉnh Header Dashboard
- [x] **Bước 2.1:** Chỉnh sửa `src/Admin-web/src/pages/dashboard/DashboardPage.jsx`:
  - Xóa dòng phụ đề `{t('dashboard.subtitle')}`.
  - Xóa nút "Bảo trì khẩn cấp" ở hàng công cụ Header.
  - Giữ lại bộ lọc thời gian nhanh (Hôm nay, 7 Ngày, 1 Tháng, 1 Năm) và Bộ chọn ngày tùy biến.

### 🔹 Giai đoạn 3: Tối ưu Bảng Hoạt động gần đây
- [x] **Bước 3.1:** Thêm thuộc tính `table-fixed` cho thẻ `<table>`.
- [x] **Bước 3.2:** Phân bổ lại tỷ lệ độ rộng các cột:
  - Cột `Người dùng`: `w-[18%] min-w-[120px]`.
  - Cột `Hành động`: Thu nhỏ 50% $\rightarrow$ `w-[12%] min-w-[90px]`.
  - Cột `Yêu cầu`: Tăng không gian $\rightarrow$ `w-[30%] min-w-[160px]`.
  - Cột `Lý do`: `w-[18%] min-w-[120px]`.
  - Cột `Trạng thái`: `w-[11%] min-w-[80px]`.
  - Cột `Thời gian`: `w-[11%] min-w-[80px]` (căn phải).
- [x] **Bước 3.3:** Bọc nội dung các ô bằng `TruncateCell` có thuộc tính `title` để hiển thị tooltip native khi hover chuột vào nội dung bị cắt ngắn `...`.

### 🔹 Giai đoạn 4: Nâng cấp Tab Sức khỏe hệ thống (`ServerHealthPanel`)
- [x] **Bước 4.1:** Tích hợp `SecurityConfirmModal` vào `ServerHealthPanel.jsx`:
  - Khi người dùng gạt công tắc bật Bảo trì khẩn cấp:
    + Bắt buộc nhập lý do (nếu chưa nhập thì báo lỗi).
    + Mở modal yêu cầu nhập mã PIN bảo mật 6 số.
    + Chỉ khi xác thực mã PIN thành công mới gọi API kích hoạt chế độ bảo trì.
  - Khi tắt bảo trì: Cho phép xác nhận trực tiếp hoặc qua modal để khôi phục hoạt động cho người dùng.
- [x] **Bước 4.2:** Đồng bộ hiển thị Uptime:
  - Đồng bộ format chuỗi Uptime với Card Uptime trên Dashboard, hiển thị thống nhất cả SLA % và thời gian chạy thực tế đã trừ bảo trì.

### 🔹 Giai đoạn 5: Xây dựng `RealtimeStatusBadge` & Tích hợp vào Bảng & 2 Biểu đồ
- [x] **Bước 5.1:** Tạo component `src/Admin-web/src/components/common/RealtimeStatusBadge.jsx`:
  - Kết nối với `useSocketContext()` và lắng nghe các sự kiện socket: `connect`, `disconnect`, `connect_error`, `reconnect_attempt`.
  - Render trạng thái tương ứng:
    + Đang kết nối: Xanh lá `● Real-time` (chấm xanh nhấp nháy pulse).
    + Đang kết nối lại: Vàng cam `● Đang kết nối...` (spinner quay hoặc chấm vàng).
    + Mất kết nối: Đỏ `● Mất kết nối` (chấm đỏ kèm tooltip giải thích).
- [x] **Bước 5.2:** Tích hợp vào Bảng Hoạt động gần đây (thay thế badge cũ).
- [x] **Bước 5.3:** Cập nhật 2 Biểu đồ trong `DashboardPage.jsx`:
  - Biểu đồ Request: Xóa bỏ badge cũ `Live Mode`.
  - Đặt `RealtimeStatusBadge` vào góc phải header của cả Biểu đồ Đăng nhập và Biểu đồ Request.

### 🔹 Giai đoạn 6: Kiểm thử 2 tầng & Thẩm tra hoàn tất
- [x] **Bước 6.1:** Viết bài kiểm thử tự động 2 tầng Vitest (`dashboard.refinement.2tier.test.jsx`).
- [x] **Bước 6.2:** Kiểm tra lint, build và thẩm tra TypeScript/JSX (`rtk npm run build` - 0 lỗi).
- [x] **Bước 6.3:** Cập nhật tài liệu nguồn sự thật và xây dựng lại CodeGraph (`rtk npx codegraph build`).

---

## 🧪 IV. TIÊU CHÍ NGHIỆM THU 2 TẦNG (2-TIER ACCEPTANCE CRITERIA)

### 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
1. **Header:** Không còn dòng subtitle và không còn nút Bảo trì khẩn cấp trên Header.
2. **Bảng Hoạt động:** Cột Hành động có độ rộng thu nhỏ còn 12%; các nội dung dài tự động có dấu `...` và hiển thị tooltip khi rê chuột vào.
3. **Biểu đồ:** Biểu đồ Request không còn chữ `Live Mode`. Cả Biểu đồ Đăng nhập và Request đều có badge Real-time ở góc trên bên phải.
4. **Công tắc Bảo trì Sức khỏe:** Khi click bật công tắc Bảo trì khẩn cấp trong `ServerHealthPanel`, Modal xác thực mã PIN hiển thị trang trọng, có input 6 ô mã PIN và bàn phím số/phím ảo.

### ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (Real System Impact & Verification)
1. **Xác thực mã PIN thực tế:**
   - Khi chưa nhập đúng mã PIN: Hệ thống KHÔNG gọi API đổi trạng thái bảo trì, công tắc vẫn ở trạng thái TẮT.
   - Khi nhập đúng mã PIN: API `/api/admin/verify-security-action` trả về `200 OK`, sau đó gọi `/api/admin/system/maintenance` bật bảo trì thành công, phát thông báo Socket tới toàn bộ client.
2. **Đồng bộ số liệu Uptime:**
   - Card Uptime ở trên và Widget Uptime trong ServerHealthPanel hiển thị cùng một giá trị % SLA và thời gian chạy thực tế (đã trừ thời gian bảo trì khẩn cấp).
3. **Cơ chế phản ứng Real-time Badge:**
   - Giả lập ngắt kết nối socket (`disconnect` hoặc `connect_error`): Cả 3 badge (Bảng hoạt động, Biểu đồ đăng nhập, Biểu đồ request) lập tức chuyển sang màu vàng/đỏ (`Mất kết nối`), không bị treo vĩnh viễn ở trạng thái xanh.
   - Khi socket kết nối lại thành công (`connect`): Cả 3 badge tự động chuyển lại sang màu xanh `Real-time`.
