# Kế Hoạch Tái Thiết Kế & Nâng Cấp Hệ Thống AIOps Sentinel: Bóc Tách 4 Vector Rủi Ro Độc Lập & Mô Hình Co Giãn Lưu Lượng Theo Quy Mô 1.000 – 2.000 Người Dùng

> **Người đề xuất yêu cầu:** PO (Product Owner)  
> **Mục tiêu:** 
> 1. Xóa bỏ hoàn toàn cơ chế tính điểm gộp cứng nhắc (Monolithic Additive Scoring) đang gây báo động giả.
> 2. Phân tích định lượng số lượng request phát sinh trên từng tính năng, xây dựng mô hình công suất cho 1.000 – 2.000 người dùng.
> 3. Bóc tách 4 Vector Rủi ro chuyên biệt với công thức đo lường và hành động phòng vệ riêng biệt.
> 4. Trang bị bộ điều khiển quy mô người dùng (Target Concurrency Scaler) trên giao diện Admin-web cho phép Quản trị viên cập nhật trực tiếp.

---

## 🔬 PHẦN 1: BÓC TÁCH LƯU LƯỢNG REQUEST THEO TÍNH NĂNG (REQUEST PROFILING)

Dựa trên cấu trúc kiến trúc của dự án, mỗi thao tác người dùng sinh ra số lượng request cụ thể:

| STT | Luồng Nghiệp Vụ / Chức Năng | Các Endpoint Backend Được Gọi | Số req / lần thao tác | Tần suất ước tính của 1 User đang hoạt động |
|:---:|---|---|:---:|:---:|
| **1** | **Khởi động ứng dụng & Đăng nhập** | `POST /api/auth/login`<br/>`GET /api/wallets`<br/>`GET /api/categories` | **3 req** | 1 lần / phiên làm việc |
| **2** | **Làm mới phiên ngầm (Session Refresh)** | `POST /api/auth/refresh` | **1 req** | 1 lần / 2 giờ |
| **3** | **Tải Màn hình Chính (Dashboard)** | `GET /api/wallets`<br/>`GET /api/budgets/summary`<br/>`GET /api/transactions?limit=10`<br/>`GET /api/notifications/unread-count` | **4 req** | 1 lần / 2 - 3 phút |
| **4** | **Thêm / Sửa Giao dịch Thu Chi** | `POST /api/transactions`<br/>`GET /api/wallets` (cập nhật số dư) | **2 req** | 2 - 5 lần / ngày |
| **5** | **Xem Báo cáo Thống kê & Phân tích** | `GET /api/reports/monthly`<br/>`GET /api/reports/categories`<br/>`GET /api/reports/cashflow` | **3 req** | 1 - 2 lần / phiên |
| **6** | **Hội thoại Trợ lý AI (Chatbot)** | `POST /api/ai/chatbot/stream` (SSE)<br/>`GET /api/ai/chatbot/history` | **2 req** | Khi cần tư vấn tài chính |
| **7** | **Đồng bộ ngầm & Heartbeat Socket** | WebSocket ping / fallback sync | **~2 req/phút** | Liên tục trong phiên |
| **8** | **Thao tác Admin trên Admin-web** | `GET /api/admin/aiops/status`<br/>`GET /api/admin/system/health`<br/>`GET /api/admin/users` | **2 - 4 req** | 1 - 3 lần / phút (Admin) |

---

## 🧮 PHẦN 2: MÔ HÌNH ƯỚC TÍNH CÔNG SUẤT CHO 1.000 – 2.000 NGƯỜI DÙNG

### 2.1. Hệ số hoạt động đồng thời (Concurrency Activity Multiplier):
- Trong thực tế, một người dùng đang mở ứng dụng (Active Concurrent User) không bấm liên tục từng giây, mà trung bình gửi **1 thao tác mỗi 6 – 10 giây**, tương đương:
  $$\mu = 0.15\text{ req/giây/user} \approx 9 - 10\text{ req/phút/user}$$

### 2.2. Bảng tham số công suất tương ứng các mốc quy mô:

$$\text{Expected Baseline RPM}(N) = N \times 10\text{ (req/phút)}$$
$$\text{Max Organic Peak RPM}(N) = \text{Baseline RPM} \times 2.5$$
$$\text{DDoS Threat RPM Ceiling}(N) = \text{Baseline RPM} \times 3.5$$
$$\text{Per-IP Burst Quarantine Threshold}(N) = \max\left(150, 20 + 50 \times \log_{10}(N)\right)\text{ req/10 giây}$$

| Quy mô ($N$ người dùng) | Expected Baseline RPM | Ngưỡng Đỉnh Tự Nhiên (Organic Peak) | Ngưỡng Nghi Vấn DDoS Flood | Ngưỡng Phong Tỏa 1 IP (Burst/10s) | Ngưỡng Đăng nhập Sai Toàn Hệ Thống/10s |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **500 Users** | $5,000\text{ RPM}$ ($\sim 83\text{ req/s}$) | $12,500\text{ RPM}$ | $> 17,500\text{ RPM}$ | $> 155\text{ req}/10\text{s}$ | $> 15\text{ lần}/10\text{s}$ |
| **1.000 Users** | $10,000\text{ RPM}$ ($\sim 167\text{ req/s}$) | $25,000\text{ RPM}$ | $> 35,000\text{ RPM}$ | $> 170\text{ req}/10\text{s}$ | $> 25\text{ lần}/10\text{s}$ |
| **2.000 Users** | $20,000\text{ RPM}$ ($\sim 333\text{ req/s}$) | $50,000\text{ RPM}$ | $> 70,000\text{ RPM}$ | $> 185\text{ req}/10\text{s}$ | $> 45\text{ lần}/10\text{s}$ |
| **5.000 Users** | $50,000\text{ RPM}$ ($\sim 833\text{ req/s}$) | $125,000\text{ RPM}$ | $> 175,000\text{ RPM}$ | $> 205\text{ req}/10\text{s}$ | $> 100\text{ lần}/10\text{s}$ |

---

## 🎯 PHẦN 3: BỐC TÁCH 4 VECTOR RỦI RO ĐỘC LẬP (MULTI-VECTOR RISK ARCHITECTURE)

Không còn dùng 1 công thức cộng dồn chung chung. Hệ thống chia thành **4 Vector Chuyên Biệt**, mỗi vector có điểm số $0 - 100$ và hành vi phản ứng riêng:

### 1. Vector 1: Rủi ro Xác thực & Danh tính (Auth & Identity Risk - $S_{\text{auth}}$)
- **Đặc thù:** Chỉ đo lường các hành vi bẻ khóa, chiếm đoạt danh tính.
- **Công thức:**
  $$S_{\text{auth}} = \max\left( \text{BruteForceScore}, \text{TokenHijackScore} \right)$$
  - $\text{BruteForceScore}$: Tính theo tỷ lệ số lần đăng nhập sai so với quy mô người dùng ($N$). Nếu 1 IP sai liên tiếp $\ge 8$ lần $\implies 70$ điểm.
  - $\text{TokenHijackScore}$: Phát hiện sử dụng token đã thu hồi (`req.tokenReuseDetected`) $\implies 75$ điểm.
- **Hành động phản ứng độc lập:** Chỉ phong tỏa IP của kẻ dò mật khẩu hoặc thu hồi phiên của tài khoản bị chiếm đoạt. **TUYỆT ĐỐI KHÔNG ảnh hưởng người dùng khác, KHÔNG bật bảo trì hệ thống.**

### 2. Vector 2: Rủi ro Lưu lượng & Từ chối Dịch vụ (Traffic & DoS/DDoS Risk - $S_{\text{traffic}}$)
- **Đặc thù:** Phân biệt rạch ròi giữa **Người dùng thật ùa vào (Organic Traffic)** và **Tấn công DoS/DDoS**.
- **Công thức:**
  $$R = \frac{\text{Current RPM}}{\text{Baseline RPM}(N)},\quad \text{Entropy} = \frac{\text{Distinct IPs}}{\max(1, \text{Sample Requests})}$$
  - Nếu $R > 2.5$ nhưng $\text{Entropy} \ge 0.2$ (Hàng trăm IP khác nhau của người dùng thật) $\implies S_{\text{traffic}} = 10 - 20$ (Xanh an toàn, Organic Peak!).
  - Nếu $R > 2.5$ nhưng $\text{Entropy} < 0.05$ (Lưu lượng khổng lồ đổ dồn từ 1 đến vài IP) $\implies S_{\text{traffic}} = \min(100, 50 + (R - 2.5) \times 20)$ (DDoS Flood).
- **Hành động phản ứng độc lập:** Kích hoạt tường lửa phong tỏa IP nguồn flood hoặc bật Adaptive Rate Limiter.

### 3. Vector 3: Rủi ro Thăm dò Lỗ hổng & Xâm nhập (Exploits & Malicious Probes - $S_{\text{exploit}}$)
- **Đặc thù:** Rà quét SQL Injection, Path Traversal (`../`), XSS injection, Endpoint probing.
- **Công thức:**
  $$S_{\text{exploit}} = \min\left(100, \text{malformedRequests} \times 15\right)$$
- **Hành động phản ứng độc lập:** Tự động đưa IP scanner vào danh sách đen 30 phút.

### 4. Vector 4: Sức khỏe Hạ tầng & Cạn kiệt Tài nguyên (System Resources & Health - $S_{\text{resource}}$)
- **Đặc thù:** Đo lường quá tải phần cứng thực tế (CPU, RAM, Event Loop Lag, Lỗi 5xx của máy chủ).
- **Công thức:**
  $$S_{\text{resource}} = \max\left( \frac{\text{EventLoopLag}}{300}\times 60,\; \frac{\max(0, \text{RAM}\% - 75)}{20}\times 60,\; \frac{\text{Error5xx}\%}{0.15}\times 50 \right)$$
- **Hành động phản ứng độc lập:** Kích hoạt Load Shedding (loại bỏ bớt request không quan trọng của client để cứu CPU), phát cảnh báo phần cứng. **KHÔNG quy chụp người dùng là kẻ tấn công.**

### 5. Công thức Tổng hợp Điểm Rủi Ro Toàn Cục (Composite Threat Score):
$$\text{CompositeThreatScore} = 0.7 \times \max(S_{\text{auth}}, S_{\text{traffic}}, S_{\text{exploit}}, S_{\text{resource}}) + 0.3 \times \text{Average}(S_{\text{auth}}, S_{\text{traffic}}, S_{\text{exploit}}, S_{\text{resource}})$$
- **Ngưỡng phân cấp chuẩn mực:**
  - `0 – 59`: **NORMAL** (Bình thường, hệ thống vận hành êm ái).
  - `60 – 79`: **ELEVATED** (Chú ý theo dõi vector tương ứng).
  - `80 – 89`: **WARNING** (Cảnh báo cục bộ, hệ thống tự động cách ly mối nguy).
  - `90 – 100`: **CRITICAL** (Nguy cấp thảm họa đa vector, sẵn sàng cứu hộ).

---

## 🖥️ PHẦN 4: KẾ HOẠCH NÂNG CẤP GIAO DIỆN ADMIN_WEB (`AIOpsPage.jsx`)

1. **Bộ Điều Khiển Quy Mô Người Dùng Mục Tiêu (Concurrency Scaler Card):**
   - Vị trí: Đầu trang `AIOpsPage.jsx`.
   - Cung cấp cụm nút chọn nhanh: `500`, `1,000`, `2,000`, `5,000` người dùng cùng thanh trượt Slider.
   - Thẻ thông số tức thời: Lưu lượng kỳ vọng, Trần tải an toàn, Ngưỡng phong tỏa 1 IP.
   - Nút **"Áp Dụng Quy Mô"** gọi API `POST /api/admin/aiops/scale` cập nhật động vào Backend ngay tức thì.
2. **Cụm 4 Thẻ Mini-Gauges Hiển Thị 4 Vector Rủi Ro:**
   - 🛡️ Auth & Identity ($S_{\text{auth}}$)
   - 🌊 Traffic & DoS ($S_{\text{traffic}}$)
   - 🔍 Exploits & Probes ($S_{\text{exploit}}$)
   - 🖥️ System Resources ($S_{\text{resource}}$)
3. **Bảng Bóc Tách Nguyên Nhân Gốc Rễ (Root Cause Analysis):**
   - Phân loại rõ ràng cảnh báo thuộc Vector nào kèm giải thích công thức toán học và hành động tự động đã thực hiện.
