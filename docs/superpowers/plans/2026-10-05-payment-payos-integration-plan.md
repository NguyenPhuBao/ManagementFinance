# Kế Hoạch Triển Khai: Tích Hợp Module Payment (PayOS) & Vòng Đời Gói Premium

> **Dành cho Agentic Workers:** REQUIRED SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` để triển khai kế hoạch này theo từng tác vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng hoàn chỉnh Module Payment tại Backend tích hợp cổng PayOS để người dùng thanh toán mua gói Premium 1 tháng (49,000 VNĐ), kích hoạt quyền tự động, chống sửa đổi CSDL trái phép và tự động hạ cấp về Basic kèm thông báo khi hết hạn.

**Kiến trúc:** Xây dựng micro-module `modules/payment` theo mô hình Controller - Service - Repository. Tích hợp thư viện chính thức `@payos/node` để tạo liên kết thanh toán VietQR và xác thực chữ ký Webhook HMAC-SHA256. Mở rộng Scheduler `runDailyHygieneRoutine` (0h00 UTC+7) để tự động kiểm tra cảnh báo trước 3 ngày và hạ cấp tài khoản khi hết hạn.

**Sơ đồ Kiến trúc & Luồng Dữ liệu:**

```mermaid
graph TD
    subgraph "Client Layer"
        User[Người dùng Client-app]
    end

    subgraph "Backend API Layer (Express)"
        Router[api/payment.routes.js]
        AuthMiddleware[middleware/auth.js]
        Controller[modules/payment/payment.controller.js]
    end

    subgraph "Payment Micro-Module"
        Service[modules/payment/payment.service.js]
        Repo[modules/payment/payment.repository.js]
        PayOSClient[modules/payment/payos.client.js]
    end

    subgraph "External Gateway"
        PayOSGateway[Cổng Thanh Toán PayOS API]
    end

    subgraph "Persistence Layer"
        DB[(PostgreSQL Supabase)]
    end

    subgraph "Background & Realtime"
        Scheduler[core/scheduler.service.js]
        EventBus[core/event-bus.js]
        SocketServer[core/socket.js]
    end

    User -->|1. POST /api/payment/create-order| Router
    Router --> AuthMiddleware
    AuthMiddleware --> Controller
    Controller --> Service
    Service --> Repo
    Repo -->|Lưu payment_order (PENDING)| DB
    Service --> PayOSClient
    PayOSClient -->|Tạo payment link| PayOSGateway
    PayOSGateway -->|Trả về checkoutUrl| User

    PayOSGateway -->|2. POST /api/payment/webhook| Router
    Router --> Controller
    Controller --> Service
    Service -->|Verify HMAC-SHA256| PayOSClient
    Service -->|Atomic Transaction: Đổi PAID, Account=Premium| DB
    Service --> EventBus
    EventBus --> SocketServer
    SocketServer -->|Phát Socket.IO realtime| User

    Scheduler -->|3. Daily 0h00: Quét hết hạn| DB
    Scheduler -->|Hạ cấp Basic & Gửi thông báo| EventBus
```

**Tech Stack:** Node.js, Express, Prisma ORM, PostgreSQL (Supabase), `@payos/node`, Crypto (HMAC-SHA256), Socket.IO, `node:test`.

---

## Các Ràng Buộc Toàn Cục (Global Constraints)

- **Rule 10 (DB Guard):** CẤM chạy `prisma migrate dev` hay `prisma db push` trên CSDL Supabase. Mọi thay đổi DDL bắt buộc viết vào `database/15_create_payment_subscription.sql`.
- **Rule 2 (RTK Enforcement):** Mọi lệnh terminal CLI bắt buộc có tiền tố `rtk`.
- **Data Security (`Data_Security.md`):** Tuyệt đối KHÔNG lưu thông tin thẻ ngân hàng/CVV. Chỉ lưu mã tham chiếu đối soát và SHA-256 digest của webhook.
- **Idempotency:** Webhook trùng lặp (Replay) từ PayOS phải trả về HTTP 200 ngay lập tức nếu đơn đã `PAID`, không cộng dồn thời hạn lần 2.
- **Stacking:** Nếu tài khoản còn hạn Premium $\rightarrow$ `premium_expires_at = current_expires_at + 30 days`. Nếu hết hạn/Basic $\rightarrow$ `premium_expires_at = now + 30 days`.

---

## Kế Hoạch Chi Tiết Các Tác Vụ (Bite-Sized Tasks)

### Tác vụ 1: Cài Đặt Thư Viện `@payos/node` & Thiết Lập Cấu Hình Môi Trường

**Files:**
- Modify: `src/Backend/package.json`
- Modify: `src/Backend/config/index.js`
- Test: `src/Backend/tests/unit/payment.config.test.js`

- [ ] **Bước 1: Viết test kiểm tra cấu hình PayOS nạp đúng biến môi trường**
  Tạo `src/Backend/tests/unit/payment.config.test.js` kiểm tra module config có đầy đủ các trường `payos.clientId`, `payos.apiKey`, `payos.checksumKey`, `payment.premiumPriceVnd`.
- [ ] **Bước 2: Chạy test để xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payment.config.test.js`
  Kết quả mong đợi: FAIL do config chưa có trường `payos`.
- [ ] **Bước 3: Cài đặt `@payos/node` và cập nhật `src/Backend/config/index.js`**
  Chạy lệnh: `cd src/Backend && rtk npm install @payos/node`
  Cập nhật `src/Backend/config/index.js` bổ sung object cấu hình PayOS.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payment.config.test.js`
  Kết quả mong đợi: PASS 100%.

---

### Tác vụ 2: Thiết Kế Script Migration CSDL DDL & Cập Nhật Prisma Schema

**Files:**
- Create: `database/15_create_payment_subscription.sql`
- Modify: `src/Backend/prisma/schema.prisma`

- [ ] **Bước 1: Viết file SQL DDL `database/15_create_payment_subscription.sql`**
  Bổ sung cột `premium_expires_at` tại bảng `account`. Tạo bảng `payment_order` và `payment_transaction` kèm các khóa ngoại và chỉ mục.
- [ ] **Bước 2: Cập nhật model `payment_order`, `payment_transaction` và cập nhật model `account` trong `src/Backend/prisma/schema.prisma`**
  Thêm các quan hệ tương ứng trong `schema.prisma`.
- [ ] **Bước 3: Chạy sinh Prisma Client**
  Chạy: `cd src/Backend && rtk npm run prisma:generate`
  Kết quả: Prisma Client được cập nhật các models mới mà không chạm vào CSDL Supabase.

---

### Tác vụ 3: Xây Dựng PayOS Client Wrapper & Cơ Chế Verify HMAC-SHA256

**Files:**
- Create: `src/Backend/modules/payment/payos.client.js`
- Test: `src/Backend/tests/unit/payos.client.test.js`

- [ ] **Bước 1: Viết test cho PayOS Client**
  Viết unit test cho hàm tạo link thanh toán `createPaymentLink` và hàm kiểm tra chữ ký webhook `verifyWebhookData`.
- [ ] **Bước 2: Chạy test xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payos.client.test.js`
  Kết quả mong đợi: FAIL do file chưa tồn tại.
- [ ] **Bước 3: Triển khai `src/Backend/modules/payment/payos.client.js`**
  Bọc thư viện `@payos/node`, xử lý ngoại lệ an toàn, hỗ trợ test mock.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payos.client.test.js`
  Kết quả mong đợi: PASS 100%.

---

### Tác vụ 4: Xây Dựng Payment Repository (Truy Xuất CSDL)

**Files:**
- Create: `src/Backend/modules/payment/payment.repository.js`
- Test: `src/Backend/tests/unit/payment.repository.test.js`

- [ ] **Bước 1: Viết test cho Payment Repository**
  Mock Prisma Client để test các hàm: `createOrder`, `findOrderByCode`, `updateOrderStatus`, `recordTransaction`, `activatePremiumSubscription`.
- [ ] **Bước 2: Chạy test xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payment.repository.test.js`
  Kết quả mong đợi: FAIL do repository chưa viết.
- [ ] **Bước 3: Triển khai `src/Backend/modules/payment/payment.repository.js`**
  Viết các truy vấn Prisma an toàn, xử lý atomic transaction `$transaction` khi kích hoạt Premium.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payment.repository.test.js`
  Kết quả mong đợi: PASS 100%.

---

### Tác vụ 5: Xây Dựng Payment Service (Xử Lý Logic Đơn Hàng & Webhook)

**Files:**
- Create: `src/Backend/modules/payment/payment.service.js`
- Test: `src/Backend/tests/unit/payment.service.test.js`

- [ ] **Bước 1: Viết test cho Payment Service**
  Kiểm tra 6 kịch bản chính:
  1. Tạo đơn hàng với `orderCode` duy nhất.
  2. Webhook chữ ký hợp lệ $\rightarrow$ Nâng cấp Premium thành công.
  3. Webhook chữ ký sai $\rightarrow$ Ném lỗi 400 Bad Request.
  4. Webhook gửi lặp lại (Idempotency) $\rightarrow$ Trả 200 OK, không cộng dồn.
  5. Tài khoản còn hạn Premium $\rightarrow$ Tự động cộng dồn 30 ngày vào hạn cũ.
  6. Tra cứu subscription info trả về đúng số ngày còn lại.
- [ ] **Bước 2: Chạy test xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payment.service.test.js`
  Kết quả: FAIL.
- [ ] **Bước 3: Triển khai `src/Backend/modules/payment/payment.service.js`**
  Thực thi đầy đủ logic nghiệp vụ theo đặc tả `PAYMENT_PAYOS_SPEC.md`. Xóa cache auth `invalidateAccountCache` khi kích hoạt.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payment.service.test.js`
  Kết quả: PASS 100%.

---

### Tác vụ 6: Xây Dựng Payment Controller, API Routes & Mount Router

**Files:**
- Create: `src/Backend/modules/payment/payment.controller.js`
- Create: `src/Backend/api/payment.routes.js`
- Modify: `src/Backend/api/index.js`
- Test: `src/Backend/tests/unit/payment.api.test.js`

- [ ] **Bước 1: Viết test cho Payment API Routes**
  Test các endpoint:
  - `POST /api/payment/create-order` (Có/không có JWT).
  - `GET /api/payment/order-status/:orderCode`.
  - `GET /api/payment/subscription-info`.
  - `POST /api/payment/webhook` (PayOS webhook).
  - `GET /api/payment/history`.
- [ ] **Bước 2: Chạy test xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payment.api.test.js`
- [ ] **Bước 3: Triển khai Controller, Routes và mount vào `src/Backend/api/index.js`**
  Mount router tại `/api/payment`. Áp dụng `authenticate` cho các route private, mở public cho `/webhook`.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payment.api.test.js`
  Kết quả: PASS 100%.

---

### Tác vụ 7: Tích Hợp Cơ Chế Lập Lịch Tự Động Vào Daily Routine (0h00 UTC+7)

**Files:**
- Modify: `src/Backend/core/scheduler.service.js`
- Test: `src/Backend/tests/unit/payment.scheduler.test.js`

- [ ] **Bước 1: Viết test cho Daily Premium Expiration Routine**
  Test kiểm tra:
  - Cảnh báo trước 3 ngày qua EventBus.
  - Hạ cấp tài khoản khi `premium_expires_at <= now` về `Basic` và xóa `premium_expires_at`.
  - Xóa cache bộ nhớ `invalidateAccountCache`.
- [ ] **Bước 2: Chạy test xác nhận FAIL**
  Chạy: `rtk npm test -- tests/unit/payment.scheduler.test.js`
- [ ] **Bước 3: Triển khai hàm `runDailyPremiumExpirationTask()` trong `src/Backend/core/scheduler.service.js`**
  Gọi hàm này trong `initScheduler` cùng lúc với `runDailyCountdownTask`.
- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `rtk npm test -- tests/unit/payment.scheduler.test.js`
  Kết quả: PASS 100%.

---

### Tác vụ 8: Kiểm Thử Toàn Diện & Cập Nhật Nguồn Sự Thật (Verification & Docs)

**Files:**
- Test: Toàn bộ Backend test suite (`rtk npm test`)
- Modify: `Project.md`
- Run: `rtk npx codegraph build`

- [ ] **Bước 1: Chạy toàn bộ test suite Backend**
  Chạy: `cd src/Backend && rtk npm test`
  Kết quả mong đợi: Toàn bộ unit tests PASS 100%, 0 failed.
- [ ] **Bước 2: Cập nhật Nguồn sự thật `Project.md`**
  Ghi nhận mục mới trong `Project.md` về Module Payment & PayOS integration.
- [ ] **Bước 3: Cập nhật CodeGraph**
  Chạy: `rtk npx codegraph build` từ thư mục gốc.
