# 🚀 HƯỚNG DẪN TRIỂN KHAI CLOUD TỰ ĐỘNG (GITHUB + RENDER + VERCEL + SUPABASE + UPSTASH)

Tài liệu này là **Nguồn sự thật (Source of Truth)** hướng dẫn kiến trúc và quy trình thiết lập tự động hóa triển khai (CI/CD Automated Deployment) cho toàn bộ hệ thống **ManagementFinance** trên nền tảng điện toán đám mây đa dịch vụ: **GitHub**, **Render**, **Vercel**, **Supabase** và **Upstash Redis**.

---

> [!IMPORTANT]
> **QUY ĐỊNH CHIẾN LƯỢC CỦA PRODUCT OWNER (PO) — GIAI ĐOẠN HIỆN TẠI:**  
> **Hiện tại MỌI MÔI TRƯỜNG (kể cả triển khai trên Render / Cloud) ĐỀU THỐNG NHẤT CHẠY THEO CHẾ ĐỘ `DEVELOPMENT` (`NODE_ENV=development`).**  
> - **Mục đích:** Hỗ trợ việc phát triển, kiểm thử liên thông giữa Backend, Admin-web và Client-app diễn ra thuận lợi, theo dõi log chi tiết và chẩn đoán lỗi nhanh chóng.  
> - **Nguyên tắc chuyển đổi:** Chỉ sau khi hoàn thiện toàn bộ dự án và **CÓ YÊU CẦU/PHÊ DUYỆT TỪ PO**, hệ thống mới được kích hoạt chuyển đổi sang môi trường **`PRODUCTION`** (`NODE_ENV=production`). Mọi hành vi tự ý chuyển đổi khi chưa có lệnh từ PO đều bị nghiêm cấm.

---

## 🏗️ 1. SƠ ĐỒ KIẾN TRÚC TRIỂN KHAI CLOUD TỔNG THỂ

Hệ thống kết hợp các dịch vụ Cloud chuyên biệt tốt nhất hiện nay nhằm đảm bảo tốc độ cao, độ trễ thấp và tự động hóa 100% mỗi khi cập nhật mã nguồn qua Git:

```mermaid
flowchart TD
    subgraph SCM["Source Code Management"]
        GH["GitHub Repository<br>(NguyenPhuBao/Personal_Finance_Management)"]
    end

    subgraph CI_CD["Automated CI/CD Pipeline"]
        GH -- "Webhook (Auto Deploy on Push)" --> RENDER["Render Web Service<br>(src/Backend)"]
        GH -- "Webhook (Auto Deploy on Push)" --> VERCEL["Vercel Platform<br>(src/Admin-web)"]
    end

    subgraph CLOUD_INFRA["Cloud Infrastructure"]
        RENDER -- "1. API & WebSocket" --> VERCEL
        RENDER -- "2. PostgreSQL Connection Pooling (Port 6543)" --> SUPABASE[("Supabase Cloud<br>(PostgreSQL Database)")]
        RENDER -- "3. TLS Redis URL (rediss://)" --> UPSTASH[("Upstash Serverless Redis<br>(Queue & Event Bus)")]
        CLIENT["Client-app (Mobile Flutter)<br>(Android / iOS)"] -- "4. REST API & Socket.io" --> RENDER
    end
```

### Phân Định Trách Nhiệm Từng Nền Tảng

| Nền Tảng Cloud | Thành Phần Đảm Nhiệm | Vai Trò Kỹ Thuật Trong Hệ Thống |
|---|---|---|
| **GitHub** | Git Version Control | Trung tâm lưu trữ mã nguồn, kích hoạt Webhooks tự động kích hoạt Render và Vercel khi có commit mới vào branch. |
| **Render** | `src/Backend` (NodeJS + Express + Socket.IO) | Máy chủ API tập trung, xử lý đồng bộ 2 chiều (Sync Engine), phân tích AI (OCR/Classify), Webhook ngân hàng (Casso/SePay). |
| **Vercel** | `src/Admin-web` (React + Vite + Tailwind) | Nền tảng CDN Serverless toàn cầu phân phối giao diện Quản trị viên, tốc độ tải trang cực nhanh, tự động xử lý Single Page Application (SPA). |
| **Supabase** | PostgreSQL Database | Cơ sở dữ liệu quan hệ lưu trữ 13 bảng thực thể, cung cấp cổng PgBouncer Connection Pooler (6543) và cổng Direct (5432). |
| **Upstash** | Serverless Redis (TLS `rediss://`) | Message Broker & In-memory Cache: Phục vụ hàng đợi BullMQ (xử lý nền OCR, AI), Redis Pub/Sub (EventBus), Socket.IO Adapter và Rate-limiting. |

---

## 🔄 2. QUY TRÌNH TỰ ĐỘNG HÓA TRIỂN KHAI MỖI KHI CẬP NHẬT GITHUB (AUTO-DEPLOY)

Mọi thành viên phát triển chỉ cần làm việc trên Git cục bộ và đẩy lên GitHub. Toàn bộ hạ tầng Cloud sẽ tự động cập nhật đồng bộ:

```
Lập trình viên commit & push code lên nhánh chính (GitHub)
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
[Render phát hiện thay đổi]   [Vercel phát hiện thay đổi]
   - Kiểm tra `src/Backend`      - Kiểm tra `src/Admin-web`
   - Chạy `npm install`          - Chạy `npm run build`
   - Tự sinh `prisma generate`   - Phân phối static lên Edge CDN
   - Khởi động `npm start`       - Cập nhật domain tức thì (< 1 phút)
   - Hoàn tất trong 2-3 phút     
```

---

## 🛠️ 3. HƯỚNG DẪN CẤU HÌNH CHI TIẾT TỪNG DỊCH VỤ

### 3.1. Cấu Hình Supabase (PostgreSQL Database)
1. **Tạo Project:**
   - Đăng nhập [supabase.com](https://supabase.com), tạo project mới.
   - Vùng chọn: **Singapore (ap-southeast-1)** để tối ưu tốc độ kết nối về Render và Việt Nam.
2. **Lấy Chuỗi Kết Nối (Connection Strings):**
   - Vào **Project Settings** $\rightarrow$ **Database** $\rightarrow$ **Connection string**.
   - **Chế độ Transaction Pooler (Cổng 6543):**
     ```env
     DATABASE_URL=postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1
     ```
     *(Dùng cho biến `DATABASE_URL` trên Render để phục vụ API và chống quá tải connection).*
   - **Chế độ Direct Session (Cổng 5432):**
     ```env
     DIRECT_URL=postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres
     ```
     *(Dùng cho `DIRECT_URL` để Prisma chạy Migration hoặc chạy script SQL).*
3. **Áp dụng Lược đồ CSDL:**
   - Chạy các script từ `database/1_schema.sql` đến `database/13_drop_budget_threshold_default.sql` qua Supabase SQL Editor.
   - ⚠️ **Cảnh báo:** Tuyệt đối không chạy `prisma migrate dev` trên Supabase để tránh mất mệnh đề `WHERE` của 5 Partial Unique Indexes.

---

### 3.2. Cấu Hình Upstash (Serverless Redis)
1. **Tạo Redis Database:**
   - Đăng nhập [upstash.com](https://upstash.com), chọn **Create Database**.
   - Tên: `managementfinance-redis`.
   - Vùng: **ap-southeast-1 (Singapore)** (cùng vùng với Supabase và Render).
   - Loại: **Regional** (tối ưu độ trễ).
2. **Lấy Chuỗi Kết Nối Node.js (ioredis):**
   - Tại trang tổng quan database, cuộn xuống mục **Connect your database** $\rightarrow$ Chọn tab **Node / ioredis**.
   - Copy chuỗi kết nối an toàn TLS:
     ```env
     REDIS_URL=rediss://default:[UPSTASH_PASSWORD]@[YOUR-ENDPOINT].upstash.io:6379
     ```
   - *Lưu ý:* Giao thức bắt đầu bằng `rediss://` (2 chữ `s` đại diện cho kết nối SSL/TLS an toàn). Thư viện `ioredis` của Backend đã hỗ trợ sẵn chuỗi này.

---

### 3.3. Cấu Hình Render (Backend API & WebSocket Web Service)
1. **Tạo Web Service:**
   - Đăng nhập [render.com](https://render.com), chọn **New +** $\rightarrow$ **Web Service**.
   - Kết nối với kho mã nguồn GitHub: `NguyenPhuBao/Personal_Finance_Management`.
2. **Thiết Lập Cơ Bản (Build & Deploy Settings):**
   - **Name:** `managementfinance` (sẽ sinh domain dạng `managementfinance.onrender.com`).
   - **Region:** `Singapore (Southeast Asia)`.
   - **Branch:** `main` (hoặc nhánh làm việc của bạn).
   - **Root Directory:** `src/Backend` (Bắt buộc phải điền để Render build đúng thư mục Backend).
   - **Runtime:** `Node`.
   - **Build Command:** `npm install`
   - **Start Command:** `npm start` *(hoặc `node index.js` — **không dùng** `npm run dev`)*.
   - **Auto-Deploy:** `Yes` (Kích hoạt tự động triển khai mỗi khi push code lên GitHub).
3. **Khai Báo Biến Môi Trường (Environment):**
   Vào tab **Environment** của Web Service trên Render, thêm các biến sau:

   ```env
   # --- 1. Chế độ chạy (Giai đoạn hiện tại) ---
   NODE_ENV=development
   PORT=10000

   # --- 2. Kết nối CSDL Supabase ---
   DATABASE_URL=postgresql://postgres.[PROJECT-REF]:[PASS]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1
   DIRECT_URL=postgresql://postgres.[PROJECT-REF]:[PASS]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres

   # --- 3. Kết nối Upstash Redis ---
   REDIS_URL=rediss://default:[UPSTASH_PASSWORD]@[YOUR-ENDPOINT].upstash.io:6379

   # --- 4. Bảo mật & Mã hóa ---
   DATA_ENCRYPTION_KEY=[CHUỖI_HEX_64_KÝ_TỰ]
   BLIND_INDEX_SECRET=[CHUỖI_BẢO_MẬT_NGẪU_NHIÊN]

   # --- 5. Xác thực JWT ---
   JWT_SECRET=[SECRET_KEY_ACCESS_TOKEN]
   JWT_REFRESH_SECRET=[SECRET_KEY_REFRESH_TOKEN]
   JWT_EXPIRES_IN=15m
   JWT_REFRESH_EXPIRES_IN=7d

   # --- 6. Email & AI Gemini ---
   EMAIL_USER=[EMAIL_HỆ_THỐNG@GMAIL.COM]
   EMAIL_PASS=[APP_PASSWORD_16_KÝ_TỰ]
   GEMINI_API_KEY=[API_KEY_GOOGLE_GEMINI]

   # --- 7. Khóa dữ liệu mock ---
   ALLOW_MOCK_INPUT=false
   ```

---

### 3.4. Cấu Hình Vercel (Admin-web Frontend SPA)
1. **Tạo Project Trên Vercel:**
   - Đăng nhập [vercel.com](https://vercel.com) bằng tài khoản GitHub.
   - Chọn **Add New...** $\rightarrow$ **Project** $\rightarrow$ Import repository `NguyenPhuBao/Personal_Finance_Management`.
2. **Cấu Hình Thư Mục & Build Settings:**
   - **Project Name:** `managementfinance-admin`.
   - **Root Directory:** Bấm **Edit**, chọn thư mục `src/Admin-web`.
   - **Framework Preset:** `Vite` (Vercel sẽ tự động nhận diện).
   - **Build Command:** `npm run build` (mặc định).
   - **Output Directory:** `dist` (mặc định).
   - **Install Command:** `npm install` (mặc định).
3. **Khai Báo Biến Môi Trường (Environment Variables):**
   - `VITE_API_BASE_URL`: `https://managementfinance.onrender.com/api` (URL API của Backend trên Render).
4. **Cơ Chế Routing SPA & Reverse Proxy API (`vercel.json`):**
   Trong thư mục [`src/Admin-web/vercel.json`](../../src/Admin-web/vercel.json) đã được thiết lập sẵn cấu hình chuẩn:
   ```json
   {
     "rewrites": [
       {
         "source": "/api/(.*)",
         "destination": "https://managementfinance.onrender.com/api/$1"
       },
       {
         "source": "/(.*)",
         "destination": "/index.html"
       }
     ]
   }
   ```
   *Tác dụng:* 
   - Điều hướng toàn bộ request `/api/...` về Render mà không bị lỗi CORS.
   - Hỗ trợ React Router điều hướng trang mượt mà, khi người dùng F5 tải lại trang không bị lỗi 404.

---

### 3.5. Kết Nối Client-App (Mobile Flutter App)
Ứng dụng di động (Flutter) kết nối trực tiếp với Backend trên Cloud:
1. **Cấu hình Base URL:**
   - Đặt URL máy chủ API: `https://managementfinance.onrender.com/api`
   - Đặt URL WebSocket Realtime: `https://managementfinance.onrender.com`
2. **Cơ Chế Offline-First:**
   - Dù máy chủ Render ở gói miễn phí có thể ngủ (Spin down) sau 15 phút không có request, Client-app vẫn ghi nhận giao dịch vào SQLite cục bộ bình thường. Khi kết nối lại, Sync Engine sẽ tự động đẩy dữ liệu lên qua `/api/sync/push`.

---

## 📌 4. SO SÁNH CHI TIẾT GIỮA DEVELOPMENT VÀ PRODUCTION

| Tiêu Chí / Cơ Chế | Môi Trường Development (Hiện Tại) | Môi Trường Production (Tương Lai) | Mục Đích Kỹ Thuật & Tác Động |
|---|---|---|---|
| **Biến `NODE_ENV`** | `development` | `production` | Kích hoạt toàn bộ các chốt chặn an toàn và tối ưu hóa runtime của Node.js & Express. |
| **Lệnh Khởi Động (Start Command)** | `npm start` *(hoặc `node index.js`)* | `npm start` *(gọi `node index.js`)* | V8 Engine tối ưu bytecode, chạy ổn định, không tốn tài nguyên scan file của nodemon. |
| **Gói Phụ Thuộc (`npm install`)** | Cài đặt toàn bộ (`dependencies` + `devDependencies`). | **Chỉ cài `dependencies`** (bỏ qua `devDependencies` như `nodemon`, `@optave/codegraph`). | Tối ưu thời gian build, giảm dung lượng bộ nhớ và triệt tiêu diện tích tấn công từ công cụ dev. |
| **Chốt Khóa Mã Hóa ([`crypto.util.js`](../../src/Backend/utils/crypto.util.js))** | Nếu thiếu `DATA_ENCRYPTION_KEY` hoặc `BLIND_INDEX_SECRET`, chỉ log warning và dùng key mặc định để dev nhanh. | **Bắt buộc 100%:** Thiếu hoặc key không đủ 64-hex (32 bytes) $\rightarrow$ **Server ném Exception và dừng khởi động ngay lập tức**. | Ngăn chặn việc dữ liệu tài chính thật của người dùng bị mã hóa bằng key yếu hoặc secret mặc định. |
| **Che Giấu Thông Tin Lỗi ([`error-handler.js`](../../src/Backend/middleware/error-handler.js))** | Trả về stack trace, thông tin chi tiết lỗi CSDL, mã lỗi Prisma để lập trình viên gỡ lỗi. | **Error Obfuscation:** Giấu toàn bộ lỗi nội bộ 500, chỉ trả về chuỗi chuẩn: *"Loi he thong, vui long thu lai sau"*. | Ngăn chặn hacker thu thập thông tin cấu trúc CSDL hoặc công nghệ nội bộ qua phản hồi lỗi. |
| **Log Truy Vấn CSDL ([`db.js`](../../src/Backend/config/db.js))** | In ra console toàn bộ câu lệnh SQL (`['query', 'error', 'warn']`). | **Chỉ log lỗi (`['error']`).** | Tiết kiệm CPU/RAM I/O, không làm tràn log và không lộ dữ liệu cá nhân nhạy cảm trong câu lệnh SQL. |
| **Khóa Cửa Hậu Mock Input ([`ocr.controller.js`](../../src/Backend/modules/ai/features/ocr/ocr.controller.js))** | Cho phép nhận dữ liệu giả lập `_mock*` nếu bật cờ `ALLOW_MOCK_INPUT=true` để chạy test. | **Khóa hoàn toàn 100%:** Bỏ qua mọi tham số mock, bắt buộc 100% request phải qua AI xử lý thật. | Đảm bảo tính toàn vẹn dữ liệu, chống gian lận dữ liệu tài chính. |
| **Bộ Nhớ Đệm Framework (Express Cache)** | Tắt bộ nhớ đệm view/middleware để phản ánh code mới tức thì. | **Bật bộ nhớ đệm tối đa.** | Tăng thông lượng chịu tải (throughput) và giảm thời gian xử lý request HTTP. |

---

## 🛠️ 5. CẨM NANG XỬ LÝ SỰ CỐ CLOUD (TROUBLESHOOTING)

### Lỗi 1: `sh: 1: nodemon: not found` (Exit status 127) trên Render
- **Triệu chứng:** Deploy log báo `==> Running 'npm run dev' -> sh: 1: nodemon: not found -> Exited with status 127`.
- **Nguyên nhân:** Render đặt **Start Command** là `npm run dev`. Khi chạy production hoặc môi trường không nạp global nodemon, lệnh sẽ báo lỗi.
- **Khắc phục:** Vào Render $\rightarrow$ **Settings** $\rightarrow$ **Start Command** $\rightarrow$ Đổi thành `npm start`.

---

### Lỗi 2: Server Crash ngay khi khởi động: `[FATAL SECURITY ERROR] DATA_ENCRYPTION_KEY must be a 64-character hex string`
- **Triệu chứng:** Server dừng ngay lập tức tại bước khởi động `crypto.util.js`.
- **Nguyên nhân:** Biến `DATA_ENCRYPTION_KEY` bị thiếu hoặc không đúng định dạng 64 ký tự hex (32 bytes).
- **Khắc phục:**
  1. Mở terminal cục bộ chạy lệnh sinh khóa:
     ```bash
     node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
     ```
  2. Copy chuỗi 64 ký tự in ra, dán vào biến `DATA_ENCRYPTION_KEY` trong mục **Environment** trên Render $\rightarrow$ Save Changes.

---

### Lỗi 3: Upstash Redis Lỗi Kết Nối: `ECONNREFUSED` hoặc Timeout
- **Triệu chứng:** Log hiển thị `Redis unavailable — continuing without cache/queue`.
- **Nguyên nhân:** Chuỗi `REDIS_URL` sai cú pháp hoặc thiếu tiền tố SSL `rediss://`.
- **Khắc phục:** Copy chính xác chuỗi kết nối từ tab **Node / ioredis** trên Upstash Dashboard, đảm bảo có dạng `rediss://default:...@[endpoint].upstash.io:6379`.

---

### Lỗi 4: `PrismaClientInitializationError: Can't reach database server at ...`
- **Triệu chứng:** Backend không kết nối được PostgreSQL Supabase khi có nhiều traffic đồng thời.
- **Nguyên nhân:** Vượt quá số lượng connection cho phép của gói Supabase Free do sử dụng kết nối Direct port 5432 thay vì Connection Pooler.
- **Khắc phục:** Đảm bảo `DATABASE_URL` dùng connection string của Supabase **Connection Pooler** (Port `6543`, kèm tham số `?pgbouncer=true&connection_limit=1`).

---

### Lỗi 5: Vercel Admin-web Bị Lỗi 404 Khi F5 / Refresh Trang
- **Triệu chứng:** Truy cập trang chủ bình thường, nhưng bấm vào `/categories` rồi F5 lại thì Vercel báo `404 NOT_FOUND`.
- **Nguyên nhân:** Thiếu file cấu hình SPA rewrite cho React Router.
- **Khắc phục:** Đảm bảo file `src/Admin-web/vercel.json` có đoạn rewrite `/(.*) -> /index.html`.
