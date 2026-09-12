# 🚀 HƯỚNG DẪN TRIỂN KHAI CLOUD & ĐẶC TẢ MÔI TRƯỜNG (DEVELOPMENT VS PRODUCTION)

Tài liệu này là **Nguồn sự thật (Source of Truth)** hướng dẫn chi tiết quy trình triển khai hệ thống **ManagementFinance** lên môi trường điện toán đám mây (Cloud - Render, Supabase), đồng thời phân định ranh giới kỹ thuật, cấu hình và cơ chế bảo mật giữa 2 môi trường **Development** và **Production**.

---

## 📌 1. SO SÁNH CHI TIẾT GIỮA DEVELOPMENT VÀ PRODUCTION

| Tiêu Chí / Cơ Chế | Môi Trường Development (Cục bộ / Dev Server) | Môi Trường Production (Render / Cloud) | Mục Đích Kỹ Thuật & Tác Động |
|---|---|---|---|
| **Biến `NODE_ENV`** | `development` | `production` | Kích hoạt toàn bộ các chốt chặn an toàn và tối ưu hóa runtime của Node.js & Express. |
| **Lệnh Khởi Động (Start Command)** | `npm run dev`<br>*(gọi `nodemon index.js`)* | **`npm start`**<br>*(gọi `node index.js`)* | • **Dev:** Tự động reload khi code thay đổi.<br>• **Prod:** V8 Engine tối ưu bytecode, chạy ổn định, không tốn tài nguyên scan file. |
| **Gói Phụ Thuộc (`npm install`)** | Cài đặt toàn bộ (`dependencies` + `devDependencies`). | **Chỉ cài `dependencies`** (bỏ qua `devDependencies` như `nodemon`, `@optave/codegraph`). | Tối ưu thời gian build, giảm dung lượng bộ nhớ và triệt tiêu diện tích tấn công từ công cụ dev. |
| **Chốt Khóa Mã Hóa ([`crypto.util.js`](../../src/Backend/utils/crypto.util.js))** | Nếu thiếu `DATA_ENCRYPTION_KEY` hoặc `BLIND_INDEX_SECRET`, chỉ log warning và dùng key mặc định để dev nhanh. | **Bắt buộc 100%:** Thiếu hoặc key không đủ 64-hex (32 bytes) $\rightarrow$ **Server ném Exception và dừng khởi động ngay lập tức**. | Ngăn chặn việc dữ liệu tài chính thật của người dùng bị mã hóa bằng key yếu hoặc secret mặc định. |
| **Che Giấu Thông Tin Lỗi ([`error-handler.js`](../../src/Backend/middleware/error-handler.js))** | Trả về stack trace, thông tin chi tiết lỗi CSDL, mã lỗi Prisma để lập trình viên gỡ lỗi. | **Error Obfuscation:** Giấu toàn bộ lỗi nội bộ 500, chỉ trả về chuỗi chuẩn: *"Loi he thong, vui long thu lai sau"*. | Ngăn chặn hacker thu thập thông tin cấu trúc CSDL hoặc công nghệ nội bộ qua phản hồi lỗi. |
| **Log Truy Vấn CSDL ([`db.js`](../../src/Backend/config/db.js))** | In ra console toàn bộ câu lệnh SQL (`['query', 'error', 'warn']`). | **Chỉ log lỗi (`['error']`).** | Tiết kiệm CPU/RAM I/O, không làm tràn log và không lộ dữ liệu cá nhân nhạy cảm trong câu lệnh SQL. |
| **Khóa Cửa Hậu Mock Input ([`ocr.controller.js`](../../src/Backend/modules/ai/features/ocr/ocr.controller.js))** | Cho phép nhận dữ liệu giả lập `_mock*` nếu bật cờ `ALLOW_MOCK_INPUT=true` để chạy test. | **Khóa hoàn toàn 100%:** Bỏ qua mọi tham số mock, bắt buộc 100% request phải qua AI xử lý thật. | Đảm bảo tính toàn vẹn dữ liệu, chống gian lận dữ liệu tài chính. |
| **Bộ Nhớ Đệm Framework (Express Cache)** | Tắt bộ nhớ đệm view/middleware để phản ánh code mới tức thì. | **Bật bộ nhớ đệm tối đa.** | Tăng thông lượng chịu tải (throughput) và giảm thời gian xử lý request HTTP. |

---

## ⚙️ 2. HƯỚNG DẪN CẤU HÌNH DỊCH VỤ TRÊN RENDER (RENDER WEB SERVICE)

Khi tạo hoặc cấu hình dịch vụ **Web Service** trên nền tảng Render cho module Backend:

### 2.1. Cấu Hình Cơ Bản (Build & Deploy)

| Mục Cấu Hình | Giá Trị Cần Điền | Ghi Chú Quan Trọng |
|---|---|---|
| **Name** | `ManagementFinance` *(hoặc tên tùy chọn)* | Tên định danh dịch vụ trên Render Dashboard. |
| **Region** | `Singapore (Southeast Asia)` | Chọn vùng gần Việt Nam để giảm độ trễ mạng (latency). |
| **Branch** | `main` *(hoặc nhánh triển khai chính thức)* | Nhánh git mà Render sẽ tự động kéo code khi có commit mới. |
| **Root Directory** | `src/Backend` | **Bắt buộc:** Trỏ thẳng vào thư mục chứa `package.json` của Backend. |
| **Runtime** | `Node` | Môi trường thực thi Node.js. |
| **Build Command** | `npm install` | Đã có hook `"postinstall": "prisma generate"` trong `package.json`, Prisma Client sẽ tự sinh sau khi cài gói. |
| **Start Command** | **`npm start`** | **Tuyệt đối KHÔNG dùng `npm run dev`** (vì production không cài `nodemon`, sẽ gây lỗi `status 127`). |

---

### 2.2. Danh Mục Biến Môi Trường (Environment Variables) Trên Render

Vào mục **Environment** trên Render Web Service và cấu hình đầy đủ các biến sau:

```env
# ==============================================================================
# 1. CẤU HÌNH CHẾ ĐỘ CHẠY (BẮT BUỘC)
# ==============================================================================
NODE_ENV=production
PORT=10000

# ==============================================================================
# 2. CƠ SỞ DỮ LIỆU POSTGRESQL (SUPABASE POOLING & DIRECT)
# ==============================================================================
# Dùng kết nối Pooled (Port 6543 qua PgBouncer) cho ứng dụng thông thường
DATABASE_URL=postgresql://postgres.[YOUR-PROJECT]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1

# Dùng kết nối Trực tiếp (Port 5432 - Session mode) cho Prisma Migration
DIRECT_URL=postgresql://postgres.[YOUR-PROJECT]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres

# ==============================================================================
# 3. BẢO MẬT & MÃ HÓA DỮ LIỆU TÀI CHÍNH (CRITICAL - PRODUCTION GUARDS)
# ==============================================================================
# Khóa đối xứng AES-256-GCM (bắt buộc ĐÚNG 64 ký tự hex = 32 bytes)
# Sinh bằng lệnh: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
DATA_ENCRYPTION_KEY=[CHUỖI_HEX_64_KÝ_TỰ_NGẪU_NHIÊN]

# Khóa băm Blind Index cho tra soát số tài khoản ngân hàng SePay
BLIND_INDEX_SECRET=[CHUỖI_BẢO_MẬT_NGẪU_NHIÊN_KHÔNG_ĐOÁN_ĐƯỢC]

# ==============================================================================
# 4. XÁC THỰC NGƯỜI DÙNG (JWT TOKENS)
# ==============================================================================
JWT_SECRET=[CHUỖI_SECRET_CHO_ACCESS_TOKEN]
JWT_REFRESH_SECRET=[CHUỖI_SECRET_CHO_REFRESH_TOKEN]
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# ==============================================================================
# 5. DỊCH VỤ EMAIL & THÔNG BÁO (SMTP GMAIL / SENDGRID)
# ==============================================================================
EMAIL_USER=[EMAIL_CỦA_HỆ_THỐNG@GMAIL.COM]
EMAIL_PASS=[MẬT_KHẨU_ỨNG_DỤNG_APP_PASSWORD_16_KÝ_TỰ]

# ==============================================================================
# 6. TÍCH HỢP TRÍ TUỆ NHÂN TẠO (AI SERVICES)
# ==============================================================================
GEMINI_API_KEY=[API_KEY_GOOGLE_GEMINI]

# ==============================================================================
# 7. CHẶN DỮ LIỆU GIẢ LẬP (MOCK GUARD)
# ==============================================================================
ALLOW_MOCK_INPUT=false
```

---

## 🛠️ 3. CÁC LỖI TRIỂN KHAI PHỔ BIẾN & CÁCH XỬ LÝ (TROUBLESHOOTING)

### Lỗi 1: `sh: 1: nodemon: not found` (Exit status 127)
- **Triệu chứng:** Deploy log báo `==> Running 'npm run dev' -> sh: 1: nodemon: not found -> Exited with status 127`.
- **Nguyên nhân:** Render đang đặt **Start Command** là `npm run dev`. Khi `NODE_ENV=production`, `nodemon` thuộc `devDependencies` nên không được cài đặt.
- **Khắc phục:** Vào **Settings** $\rightarrow$ **Start Command** $\rightarrow$ Đổi thành `npm start`.

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

### Lỗi 3: Server Crash: `[FATAL SECURITY ERROR] BLIND_INDEX_SECRET must be set in production`
- **Triệu chứng:** Log hiển thị lỗi dừng server vì thiếu bí mật blind index.
- **Nguyên nhân:** Trên production, hệ thống không chấp nhận secret mặc định để bảo vệ dữ liệu tra soát giao dịch ngân hàng SePay.
- **Khắc phục:** Thêm biến `BLIND_INDEX_SECRET` trên Render với một chuỗi ngẫu nhiên có độ dài $\ge 32$ ký tự.

---

### Lỗi 4: `PrismaClientInitializationError: Can't reach database server at ...`
- **Triệu chứng:** Backend không kết nối được PostgreSQL Supabase khi có traffic đẩy lên.
- **Nguyên nhân:** Vượt quá số lượng connection cho phép của gói Supabase Free/Pro do sử dụng kết nối Direct port 5432 thay vì Connection Pooler.
- **Khắc phục:**
  1. Đảm bảo `DATABASE_URL` dùng connection string của Supabase **Connection Pooler** (Port `6543`, kèm tham số `?pgbouncer=true&connection_limit=1`).
  2. Chỉ dùng cổng `5432` cho `DIRECT_URL`.

---

### Lỗi 5: Lệch Partial Unique Index khi dùng `prisma migrate dev`
- **Triệu chứng:** Người dùng bị lỗi xung đột khi tạo lại danh mục đã xóa mềm hoặc tài khoản đã xóa mềm đăng ký lại email cũ.
- **Nguyên nhân:** Prisma ORM không hỗ trợ mệnh đề `WHERE` trong schema file, nếu chạy `prisma migrate dev` hoặc `prisma db push` trên CSDL thì Prisma sẽ tự động xóa các Partial Index có `WHERE "Delete_at" IS NULL` và biến thành index thường.
- **Khắc phục:**
  - **Tuyệt đối KHÔNG chạy `prisma migrate dev` hoặc `prisma db push` trên CSDL production.**
  - Chỉ chạy các script SQL thủ công trong thư mục `database/` (`12_*.sql`, `13_*.sql`), sau đó chỉ chạy `npx prisma generate` để sinh mã Client.
