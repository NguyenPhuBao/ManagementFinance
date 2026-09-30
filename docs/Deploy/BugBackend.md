# BÁO CÁO PHÂN TÍCH: NGUY CƠ SINGLE POINT OF FAILURE (SPOF) & PHƯƠNG ÁN XỬ LÝ ĐÃ CHỐT

> **Trạng thái:** **PO ĐÃ DUYỆT CHỐT CÁC PHƯƠNG ÁN XỬ LÝ (2026-09-29)**  
> **Phạm vi áp dụng:** `src/Backend` (Node.js, Express, Supabase PostgreSQL, Redis, Workers)

---

## 1. MÔ TẢ VẤN ĐỀ (PROBLEM STATEMENT)

Hệ thống Backend cần giải quyết triệt để nguy cơ **Single Point of Failure (SPOF)** — tình huống khi **chỉ 1 request bị lỗi bất thường hoặc quá tải làm sập (crash) hoặc đóng băng (freeze) toàn bộ máy chủ**, gián đoạn dịch vụ của toàn bộ người dùng.

### 1.1. Những cơ chế hệ thống ĐÃ CÓ
- **Middleware Error Handler tập trung:** [`src/Backend/middleware/error-handler.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/error-handler.js) xử lý lỗi khi controller có `try/catch` hoặc gọi `next(err)`.
- **Cầu dao tự ngắt (Circuit Breaker) ở tầng AI:** Tự động ngắt mạch khi API bên ngoài (Google Gemini) lỗi/chậm, tránh treo dây chuyền.
- **Kết nối Redis Non-blocking:** Không làm chết ứng dụng nếu dịch vụ Redis ngừng hoạt động (chỉ tạm dừng worker và tính năng cache).

### 1.2. Các lỗ hổng chí mạng hiện tại
1. **Chưa bắt `process.on('uncaughtException')` & `process.on('unhandledRejection')`:** Node.js crash tiến trình ngay lập tức nếu có bất kỳ unhandled promise hoặc uncaught exception nào.
2. **Vận hành đơn tiến trình (Single Process):** Chạy `node index.js` đơn lẻ. Nếu 1 request bị vòng lặp vô tận (infinite loop), biểu thức chính quy nặng hoặc parse dữ liệu lớn $\rightarrow$ chiếm 100% CPU Event Loop, làm đơ toàn bộ người dùng khác.
3. **Cạn kiệt Connection Pool CSDL Supabase:** Dùng chung pool, không có trần giới hạn hay timeout truy vấn. Một vài request chậm chiếm hết slot connection của Supabase (vốn rất hạn chế trên Free Tier).
4. **Thiếu Request Timeout:** Request bị treo giữ socket và bộ nhớ máy chủ vô thời hạn.

---

## 2. PHƯƠNG ÁN XỬ LÝ CHÍNH THỨC ĐÃ ĐƯỢC PO PHÊ DUYỆT

PO đã chính thức phê duyệt toàn bộ 5 hạng mục xử lý với các yêu cầu kỹ thuật chi tiết sau:

### 2.1. Bổ sung Bẫy lỗi toàn cục (Global Process Exception Handlers) — [ĐÃ DUYỆT]
- **Triển khai:** Lắng nghe `uncaughtException` và `unhandledRejection` tại [`src/Backend/index.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/index.js).
- **Cơ chế:** Ghi log chi tiết (stack trace, path, timestamp) phục vụ điều tra lỗi. Thực hiện dọn dẹp tài nguyên và khởi động lại tiến trình một cách an toàn (Graceful Exit & Recovery), tuyệt đối không để tiến trình rơi vào trạng thái "zombie".

### 2.2. Kiến trúc Đa tiến trình tự phục hồi & Khống chế vòng lặp gọi lại — [ĐÃ DUYỆT]
- **Triển khai:**
  - Nâng cấp Backend hỗ trợ cơ chế Cluster (sử dụng Node.js native `cluster` module hoặc cấu hình Process Manager PM2).
  - Tự động fork worker mới nếu 1 worker bị sự cố (Zero-downtime).
- **Xử lý Vòng lặp vô tận / Request Retry Storm:**
  - Thiết lập bộ đếm kiểm soát số lần gọi lại của cùng 1 request (`x-retry-count` / Idempotency Key / client signature).
  - Giới hạn số lần thử lại tối đa (ví dụ tối đa 3 lần trong cửa sổ thời gian). Nếu vượt quá, phản hồi `429 Too Many Requests / Retry Limit Exceeded` kèm gợi ý giãn cách thời gian (Exponential Backoff), không cho phép gọi lặp vô hạn.
  - **Lưu ý Cloud Free Tier:** Điều chỉnh ngưỡng thời gian linh hoạt (tránh nhầm lẫn giữa request bị lặp và request xử lý chậm do máy chủ Cloud Free thức dậy sau giấc ngủ / cold start).

### 2.3. Bổ sung Request Timeout Middleware — [ĐÃ DUYỆT]
- **Triển khai:**
  - Tích hợp middleware kiểm soát thời gian tối đa của mỗi request.
  - Thiết lập ngưỡng thời gian phù hợp: **30 giây** cho các API thông thường (tính đến độ trễ mạng và đặc thù gói Cloud Free), ngoại trừ các luồng SSE Streaming (AI Copilot) hoặc Upload file chứng từ có cấu hình timeout riêng biệt.
  - Khi hết hạn, tự động hủy socket và trả về mã `504 Gateway Timeout`.

### 2.4. Giám sát Event Loop & Cơ chế Cắt tải bảo vệ (Load Shedding) — [ĐÃ DUYỆT]
- **Triển khai:**
  - Tự động đo đạc độ trễ Event Loop thời gian thực.
  - Khi phát hiện hệ thống quá tải (độ trễ Event Loop lag > 100ms hoặc CPU tăng vọt): Kích hoạt chế độ Load Shedding.
- **Yêu cầu quan trọng từ PO:** **KHÔNG ĐƯỢC ÂM THẦM CHẶN REQUEST.**
  - Khi từ chối nhận request, máy chủ phải trả về mã `503 Service Unavailable` với payload JSON thân thiện và minh bạch:
    ```json
    {
      "success": false,
      "statusCode": 503,
      "code": "SERVER_OVERLOADED",
      "message": "Hệ thống đang xử lý lượng truy cập lớn. Vui lòng thử lại sau ít giây!",
      "retryAfter": 5,
      "timestamp": "..."
    }
    ```
  - Thiết lập header HTTP `Retry-After: 5` để Client-app và Admin-web hiển thị thông báo rõ ràng cho người dùng, không để ứng dụng bị đứng hình.

### 2.5. Tách biệt & Giới hạn Connection Pool kết nối Supabase — [ĐÃ DUYỆT]
- **Đặc thù Supabase Free Tier:** Số lượng kết nối trực tiếp tối đa bị giới hạn nghiêm ngặt (thường ~15 - 20 connections).
- **Triển khai:**
  - Giới hạn lại `max` connections của pg `Pool` và Prisma `connection_limit` hợp lý (ví dụ: pg Pool `max: 5`, Prisma `connection_limit=5`), tránh tình trạng nhân bản pool giữa các worker làm cạn kiệt slot kết nối của Supabase.
  - Bổ sung cấu hình `statement_timeout: 10000` (10 giây) cho PostgreSQL để tự động hủy các câu lệnh SQL bị treo, giải phóng kết nối ngay về pool.
  - Thiết lập khoang cách ly (Bulkhead): Client-app chỉ được chiếm dụng tối đa 80% pool kết nối, luôn giữ lại 20% dung lượng kết nối cho Admin.

---

## 3. TRẠNG THÁI & KẾ HOẠCH BẮT ĐẦU TRIỂN KHAI

- [x] Đã được PO phê duyệt toàn bộ 5 nội dung kỹ thuật.
- [ ] Lập Implementation Plan chi tiết theo quy trình chuẩn (TDD: Red $\rightarrow$ Green $\rightarrow$ Refactor).
- [ ] Trình Implementation Plan cho PO/Người dùng kiểm duyệt trước khi viết code.
