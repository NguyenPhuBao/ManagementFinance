# Triển khai dự án lên Cloud

Mục tiêu hiện tại: Đưa hệ thống lên môi trường thực tế (Cloud) để có URL public phục vụ cho việc tích hợp webhook của Casso (Module Bank). 

Với tư cách là một người mới, quá trình triển khai (Deploy) có thể khá rối. Hệ thống của bạn là một **Monorepo** (nhiều dự án con chung một kho git), và kiến trúc backend của bạn khá đặc thù. Dưới đây là phân tích và kế hoạch triển khai chi tiết.

## ⚠️ Cảnh báo kiến trúc: Tại sao không nên dùng Vercel cho Backend?

> [!CAUTION]
> Bạn yêu cầu deploy Backend lên Vercel. Tuy nhiên, Vercel là nền tảng **Serverless** (chạy hàm không trạng thái và tự động tắt sau vài giây). 
> Trong khi đó, Backend của bạn có chứa **Background Workers (BullMQ)** chạy liên tục 24/7 để xử lý hàng đợi, và sau này có thể có **Socket.io**. Vercel **KHÔNG HỖ TRỢ** background worker và websocket. Nếu cố gắng ép Backend chạy trên Vercel, toàn bộ worker xử lý AI và xử lý giao dịch ngân hàng sẽ "chết" hoàn toàn.

**Giải pháp thay thế cho Backend:** Sử dụng **Render** hoặc **Railway**. Đây là các nền tảng Cloud cho phép chạy Node.js liên tục 24/7 giống y hệt như khi bạn chạy `npm run dev` trên máy cá nhân. Cả 2 đều có gói miễn phí cho người mới bắt đầu.

## Chiến lược triển khai đề xuất

Hệ thống của bạn có 3 thành phần chính. Chúng ta sẽ phân bổ như sau:

| Thành phần | Nền tảng Cloud | Lý do |
|---|---|---|
| **Cơ sở dữ liệu (DB)** | **Supabase** | Hoàn hảo cho PostgreSQL, mạnh mẽ, dễ quản lý. |
| **Backend (Node.js)** | **Render.com** | Hỗ trợ chạy liên tục 24/7, giữ cho BullMQ Workers và Express server hoạt động ổn định. |
| **Admin-web (React)** | **Vercel** | Vercel sinh ra là để tối ưu hóa tuyệt đối cho các framework Frontend. Hỗ trợ hosting tĩnh tuyệt vời. |

---

## Các bước thực hiện chi tiết (Dành cho người mới)

Dưới đây là luồng làm việc mà tôi sẽ hỗ trợ bạn làm từng bước một:

### Bước 1: Khởi tạo Database trên Supabase
1. Bạn đăng nhập vào [Supabase.com](https://supabase.com) và tạo 1 Project mới.
2. Lấy chuỗi kết nối **Connection String** (URI) trong phần Settings > Database.
3. Cung cấp chuỗi đó cho tôi. Tôi sẽ giúp bạn trỏ Prisma tại máy local lên Supabase và chạy lệnh đẩy toàn bộ bảng (table) và dữ liệu mồi (roles, admin) lên Cloud.

### Bước 2: Khởi tạo Redis (Dành cho Queue/Worker)
Vì Backend dùng Redis cho BullMQ, bạn cũng cần 1 cloud Redis.
1. Bạn đăng ký tài khoản tại [Upstash.com](https://upstash.com) (cung cấp Redis miễn phí).
2. Tạo 1 database Redis và lấy `REDIS_URL` cung cấp cho tôi.

### Bước 3: Đưa Backend lên Render
Tôi sẽ cấu hình các file trong mã nguồn (nếu cần) để Render hiểu cấu trúc dự án của bạn:
1. Bạn tạo tài khoản [Render.com](https://render.com).
2. Tạo mới một **Web Service**, kết nối với kho GitHub của bạn.
3. Thiết lập:
   - **Root Directory**: `src/Backend`
   - **Build Command**: `npm install && npx prisma generate`
   - **Start Command**: `npm start`
4. Copy toàn bộ các biến môi trường trong file `.env` (với `DATABASE_URL` từ Supabase và `REDIS_URL` từ Upstash) đưa vào phần cấu hình của Render.
5. Render sẽ build và cung cấp cho bạn 1 URL thật (ví dụ: `https://wealthcommand-api.onrender.com`). Đây sẽ là URL ta dùng cho Casso Webhook!

### Bước 4: Đưa Admin-web lên Vercel
Do mã nguồn 3 phần gộp chung, Vercel mặc định sẽ báo lỗi vì nó không biết chạy phần nào. Ta giải quyết cực dễ như sau:
1. Bạn vào Vercel, Import project từ GitHub.
2. Tại màn hình "Configure Project", mở phần **Root Directory** và chọn `src/Admin-web`. Vercel sẽ tự động hiểu đây là dự án Vite/React.
3. Thêm biến môi trường `VITE_API_URL` trỏ về cái URL của Render ở Bước 3.
4. Bấm Deploy.

## Open Questions (Chờ bạn xác nhận)

> [!IMPORTANT]
> 1. Bạn có đồng ý với việc dùng **Render** (hoặc nền tảng tương đương) cho Backend thay vì Vercel để đảm bảo Worker/AI hoạt động không?
> 2. Nếu đồng ý, nhiệm vụ đầu tiên của bạn là tạo tài khoản Supabase và cung cấp cho tôi **DATABASE_URL**. Bạn đã sẵn sàng làm việc này chưa?
