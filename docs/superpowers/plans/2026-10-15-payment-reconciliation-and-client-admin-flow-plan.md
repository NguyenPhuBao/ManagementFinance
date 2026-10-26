# Kế Hoạch Triển Khai: Quy Trình Thanh Toán Tự Động, Đối Soát Lệch Tiền & Xử Lý Hoàn Trả (Backend, Client-App & Admin-Web)

> **Mục tiêu:** Hiện thực hóa 100% quy trình thanh toán PayOS 6 bước theo đặc tả tại `docs/Payment/PAYMENT_WORKFLOW_SPEC.md`:
> 1. CSDL thực tế với đầy đủ ràng buộc (mã đơn không trùng, mã nhận diện 6 ký tự, số tiền thực nhận, thông tin hoàn tiền minh bạch).
> 2. Triển khai trọng tâm tại **Client-app (Flutter)**: Luồng chờ thanh toán, xác nhận khi chuyển thừa tiền, thông báo khi chuyển thiếu tiền, cập nhật hạn 30 ngày thời gian thực.
> 3. Dựng quy trình giả định **Admin Roleplay / Sandbox** tại **Admin-web**: Cho phép Admin đóng vai người dùng, tự động tạo đơn kèm bộ công cụ kiểm thử tức thì mọi kịch bản và form xử lý hoàn tiền minh bạch kèm minh chứng.

---

## 1. THIẾT KẾ CSDL THỰC TẾ & MIGRATION (TUÂN THỦ DB_GUARD - RULE 10)

### 1.1. Bổ sung các cột vào bảng `payment_order`
Viết file script migration SQL: `src/Backend/database/20_add_payment_reconciliation_and_refund_fields.sql`.

```sql
-- 1. Bổ sung các cột đối soát và mã nhận diện 6 ký tự
ALTER TABLE "payment_order"
ADD COLUMN IF NOT EXISTS "recognition_code" VARCHAR(10),
ADD COLUMN IF NOT EXISTS "amount_received" DECIMAL(15,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS "fee" DECIMAL(15,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS "transfer_content" VARCHAR(100),
ADD COLUMN IF NOT EXISTS "refunded_at" TIMESTAMP(6),
ADD COLUMN IF NOT EXISTS "refunded_amount" DECIMAL(15,2),
ADD COLUMN IF NOT EXISTS "refund_reason" TEXT,
ADD COLUMN IF NOT EXISTS "refund_proof" TEXT;

-- 2. Đảm bảo ràng buộc UNIQUE và INDEX
CREATE INDEX IF NOT EXISTS "idx_payment_order_recognition_code" ON "payment_order"("recognition_code");
CREATE INDEX IF NOT EXISTS "idx_payment_order_status" ON "payment_order"("status");
```

### 1.2. Cập nhật Prisma Schema (`src/Backend/prisma/schema.prisma`)
Cập nhật model `payment_order` với đầy đủ các trường mới:
- `recognition_code`: String? @db.VarChar(10) @map("recognition_code")
- `amount_received`: Decimal @default(0.00) @db.Decimal(15, 2) @map("amount_received")
- `fee`: Decimal @default(0.00) @db.Decimal(15, 2) @map("fee")
- `transfer_content`: String? @db.VarChar(100) @map("transfer_content")
- `refunded_at`: DateTime? @db.Timestamp(6) @map("refunded_at")
- `refunded_amount`: Decimal? @db.Decimal(15, 2) @map("refunded_amount")
- `refund_reason`: String? @db.Text @map("refund_reason")
- `refund_proof`: String? @db.Text @map("refund_proof")

*Chạy lệnh chuẩn:* `rtk npm run prisma:generate` (Cấm chạy migrate dev / db push trên Supabase).

---

## 2. TRIỂN KHAI BACKEND SERVICE & API (`src/Backend`)

### 2.1. Sinh mã nhận diện 6 ký tự ngẫu nhiên & Mã đơn không trùng
Tại `src/Backend/modules/payment/payos.client.js` & `payment.service.js`:
- Hàm `generateRecognitionCode()`: Sinh ngẫu nhiên 6 ký tự `[A-Z0-9]` (ví dụ `A8K9M2`), không dùng các ký tự dễ nhầm lẫn như `0/O`, `1/I`.
- Hàm `generateOrderCode()`: Sử dụng thuật toán Timestamp (mili-giây) + 2 số ngẫu nhiên = 15 chữ số an toàn, bảo đảm không trùng lặp và tương thích định dạng `Int` của PayOS.

### 2.2. Xử lý Webhook PayOS (Phân luồng 6.1 vs 6.2)
Tại `src/Backend/modules/payment/payment.service.js` -> `handlePayOSWebhook(payload)`:
1. Xác thực chữ ký HMAC-SHA256 (`verifyWebhookData`).
2. Trích xuất `orderCode`, `amount` (số tiền thực nhận), `reference`.
3. Tìm kiếm đơn hàng theo `orderCode` hoặc theo `recognition_code`.
4. So sánh số tiền thực nhận (`amountReceived`) với số tiền đơn hàng (`order.amount`):
   - **Luồng 6.1 (Khớp tiền: `amountReceived == order.amount`):**
     - Đổi status -> `PAID`, gán `amount_received = amountReceived`, ghi `payment_transaction`.
     - Kích hoạt cộng 30 ngày Premium nguyên tử.
     - Xóa cache phân quyền (`invalidateAccountCache`).
     - Bắn Socket.IO: `account.upgraded` tới Client-app và `payment.success` tới Admin-web.
   - **Luồng 6.2a (Chuyển THỪA tiền: `amountReceived > order.amount`):**
     - Đổi status -> `WAITING_CONFIRMATION`, gán `amount_received = amountReceived`.
     - Ghi nhận `payment_transaction`.
     - Bắn Socket.IO: `payment.overpaid_confirmation` tới Client-app (kèm số tiền thừa, hỏi người dùng có đồng ý nâng cấp không).
     - Bắn Socket.IO: `payment.amount_mismatch` tới Admin-web (báo đơn lệch thừa tiền).
   - **Luồng 6.2b (Chuyển THIẾU tiền: `amountReceived < order.amount`):**
     - Đổi status -> `REFUND_PENDING`, gán `amount_received = amountReceived`.
     - Gán `refund_reason = 'Số tiền thanh toán không hợp lệ'`.
     - Bắn Socket.IO: `payment.underpaid_warning` tới Client-app (từ chối kích hoạt, thông báo hoàn tiền sau trừ phí `n` VNĐ).
     - Bắn Socket.IO: `payment.amount_mismatch` tới Admin-web (báo đơn lệch thiếu tiền, yêu cầu hoàn trả).

### 2.3. Các Endpoint Mới Cho Client-app & Admin-web
1. **API Client-app Xác nhận kích hoạt khi chuyển thừa tiền:**
   - `POST /api/payment/confirm-upgrade`
   - Body: `{ orderCode: 748449796518, accept: true/false }`
   - Nếu `accept: true` -> Chuyển đơn sang `PAID`, cộng 30 ngày Premium.
   - Nếu `accept: false` -> Chuyển đơn sang `REFUND_PENDING`, ghi lý do *"Do người dùng từ chối nâng cấp gói"*.
2. **API Admin Thực hiện Hoàn tiền:**
   - `PUT /api/admin/payments/orders/:id/refund`
   - Body: `{ refundedAmount: 20000, refundProof: 'https://...', refundReason: '...' }`
   - Ghi nhận `refunded_at = now()`, status -> `REFUNDED`.
   - Bắn Socket.IO `payment.refunded` tới Client-app để người dùng nhận thông báo hoàn tiền.
3. **API Admin Giả lập Webhook (Dành riêng cho Sandbox Roleplay):**
   - `POST /api/admin/payments/simulate-webhook`
   - Body: `{ orderCode, simulateType: 'EXACT' | 'OVERPAID' | 'UNDERPAID' }`
   - Cho phép Admin trực tiếp kích hoạt luồng 6.1, 6.2a, 6.2b mà không cần chuyển tiền thật.

---

## 3. TRIỂN KHAI PHÂN HỆ CLIENT-APP (FLUTTER - TRỌNG TÂM CHÍNH)

### 3.1. Cập nhật Model & API Client
Tại `src/Client-app/lib/features/premium/`:
- `domain/don_thanh_toan.dart`: Bổ sung các trường `recognitionCode`, `amountReceived`, `fee`, `transferContent`, `status`.
- `data/payment_api.dart`:
  - Thêm phương thức `confirmUpgrade({ required int orderCode, required bool accept })`.

### 3.2. Nâng cấp Giao diện Chờ Thanh Toán (`cho_thanh_toan_page.dart`)
1. **Hiển thị thông tin chuyển khoản chuẩn xác:**
   - Ảnh mã QR VietQR động (chứa sẵn số tiền và mã nội dung).
   - Hiển thị rõ **Mã nhận diện 6 ký tự** nổi bật với nút Copy nhanh.
   - Cảnh báo: *"Vui lòng giữ nguyên nội dung chuyển khoản để hệ thống tự động nhận diện trong 1-3 giây"*.
   - Đồng hồ đếm ngược 10 phút. Khi về 00:00 -> Tự động chuyển sang trạng thái "Đã hết hạn" (`EXPIRED`).
2. **Lắng nghe sự kiện Socket.IO Real-time:**
   - **Khi nhận `account.upgraded`:** Chuyển ngay sang màn hình Thành công, hiển thị pháo hoa/huy hiệu Premium và ngày hết hạn mới.
   - **Khi nhận `payment.overpaid_confirmation` (Chuyển thừa tiền):**
     - Mở Modal Dialog:
       > *"Phát hiện chuyển khoản thừa: Bạn đã chuyển [amountReceived] ₫ (thừa +[diff] ₫ so với giá gói [amount] ₫). Bạn có đồng ý dùng khoản thanh toán này để kích hoạt gói Premium 30 ngày không?"*
       - Nút [Đồng ý kích hoạt]: Gọi `confirmUpgrade(accept: true)` -> Nhảy sang màn Thành công.
       - Nút [Yêu cầu hoàn tiền]: Gọi `confirmUpgrade(accept: false)` -> Chuyển sang màn Chờ hoàn trả.
   - **Khi nhận `payment.underpaid_warning` (Chuyển thiếu tiền):**
     - Mở Dialog thông báo:
       > *"Thanh toán không hợp lệ: Bạn đã chuyển [amountReceived] ₫ (thiếu -[diff] ₫). Đơn hàng không đủ điều kiện kích hoạt. Số tiền sẽ được hoàn trả lại sau khi khấu trừ phí giao dịch [fee] ₫."*
       - Đơn hàng chuyển sang trạng thái `REFUND_PENDING`.

---

## 4. TRIỂN KHAI PHÂN HỆ ADMIN-WEB (REACT / VITE)

### 4.1. Dựng Modal "Mô phỏng Giao dịch Client-app" (Admin Roleplay / Sandbox Mode)
Tại `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx`:
- Khi Admin click nút **"Mã QR mẫu thử nghiệm"**:
  - Tự động gọi API `POST /api/payment/create-order` tạo đơn hàng thật trên Backend & PayOS với mã nhận diện 6 ký tự.
  - Giao diện Modal mô phỏng chính xác trải nghiệm của Client-app:
    - Ảnh VietQR thật của PayOS.
    - Đồng hồ 10 phút đếm ngược.
    - Mã nhận diện 6 ký tự và nội dung chuyển khoản đầy đủ.
    - Nút mở liên kết PayOS Checkout.
  - **Khu vực Sandbox Giả lập (Dành cho Admin test nhanh):**
    - 🟢 Nút *"Giả lập Chuyển đúng tiền (49.000 ₫)"* $\rightarrow$ Kích hoạt luồng 6.1 (thành công ngay).
    - 🟡 Nút *"Giả lập Chuyển thừa tiền (70.000 ₫)"* $\rightarrow$ Kích hoạt luồng 6.2a (hiện popup hỏi xác nhận nâng cấp ngay trên modal).
    - 🔴 Nút *"Giả lập Chuyển thiếu tiền (20.000 ₫)"* $\rightarrow$ Kích hoạt luồng 6.2b (hiện thông báo từ chối và chuyển sang hàng đợi hoàn tiền).

### 4.2. Quản lý Đơn Hàng & Thao Tác Hoàn Tiền (Refund Processing)
1. **Bộ lọc trạng thái & Thẻ KPI:**
   - Bổ sung các trạng thái mới: `WAITING_CONFIRMATION` (Chờ xác nhận), `REFUND_PENDING` (Cần hoàn trả), `REFUNDED` (Đã hoàn trả).
   - Thêm tab lọc nhanh: `Cần hoàn trả` giúp Admin không bỏ sót các đơn chuyển thiếu/khách từ chối.
2. **Modal Thực hiện Hoàn tiền (`RefundModal.jsx`):**
   - Với đơn `REFUND_PENDING`, hiển thị nút hành động "Hoàn tiền".
   - Form nhập:
     - Số tiền hoàn trả (mặc định gợi ý: `amount_received - fee`).
     - Lý do hoàn tiền.
     - Thời gian hoàn tiền (`refunded_at`).
     - Upload ảnh chụp biên lai ngân hàng / ủy nhiệm chi (`refund_proof`).
   - Nút "Xác nhận đã hoàn tiền" -> Gọi API `PUT /api/admin/payments/orders/:id/refund`.
   - Cập nhật tức thì bảng dữ liệu qua Socket.IO.

---

## 5. KẾ HOẠCH KIỂM THỬ 2 TẦNG (2-TIER TESTING ARCHITECTURE - RULE 11)

### 5.1. Backend Tests (`tests/unit` & `tests/integration`)
- **Tầng 1 (Contract & Interface):**
  - Đảm bảo các API tạo đơn, xác nhận nâng cấp, hoàn tiền trả về đúng format JSON và mã HTTP (200, 201, 400, 404).
- **Tầng 2 (System Impact & Financial Logic):**
  - Test luồng 6.1: Đúng tiền $\rightarrow$ Cập nhật `PAID`, ghi `payment_transaction`, cộng đúng 30 ngày `premium_expires_at`, phát đúng Socket.IO.
  - Test luồng 6.2a: Thừa tiền $\rightarrow$ Cập nhật `WAITING_CONFIRMATION`, không tự ý nâng cấp khi người dùng chưa đồng ý; nâng cấp thành công khi người dùng xác nhận.
  - Test luồng 6.2b: Thiếu tiền $\rightarrow$ Cập nhật `REFUND_PENDING`, tài khoản không bị nâng cấp sai trái.
  - Test hoàn tiền: Cập nhật `REFUNDED`, lưu vết `refund_proof` và `refunded_amount`.

### 5.2. Client-App Tests (Flutter Widget & Bloc Tests)
- **Tầng 1 (UI Rendering & Interaction):**
  - `ChoThanhToanPage` render đầy đủ mã VietQR, mã nhận diện 6 ký tự, đồng hồ đếm ngược.
  - Nhấn nút copy mã nhận diện hoạt động tốt.
- **Tầng 2 (Real System Impact & Event Handling):**
  - Socket `account.upgraded` tới $\rightarrow$ UI chuyển ngay sang màn hình Thành công.
  - Socket `payment.overpaid_confirmation` tới $\rightarrow$ Hiển thị popup xác nhận; nhấn Đồng ý gọi API kích hoạt thành công.
  - Socket `payment.underpaid_warning` tới $\rightarrow$ Hiển thị thông báo từ chối nâng cấp và số tiền hoàn trả.

### 5.3. Admin-Web Tests (`payment.page.test.jsx`)
- **Tầng 1 (UI Rendering):**
  - Hiển thị đầy đủ các badge trạng thái mới (`WAITING_CONFIRMATION`, `REFUND_PENDING`, `REFUNDED`).
  - Modal Sandbox Roleplay mở ra đầy đủ mã QR và các nút test giả lập.
- **Tầng 2 (System Impact):**
  - Nhấn nút giả lập chuyển tiền kích hoạt API mô phỏng và cập nhật bảng real-time.
  - Thực hiện form hoàn tiền gửi đúng payload `refund_proof`, `refunded_amount` và cập nhật hàng đợi.

---

## 6. LỘ TRÌNH THỰC HIỆN TUẦN TỰ (4 PHASES)

- **Phase 1: Database Migration & Schema Sync**
  - Tạo file SQL migration `20_add_payment_reconciliation_and_refund_fields.sql`.
  - Thực thi an toàn trên Supabase Cloud theo DB Guard.
  - Chạy `prisma:generate` cập nhật Prisma Client Backend.
- **Phase 2: Backend Implementation & TDD (2-Tier)**
  - Viết test suite `payment.reconciliation.test.js` kiểm thử toàn bộ luồng 6.1, 6.2a, 6.2b.
  - Cập nhật `payment.service.js`, `payment.repository.js`, `payment.controller.js` và Socket.IO events.
- **Phase 3: Admin-Web Sandbox Roleplay & Refund UI**
  - Nâng cấp Modal Sandbox Roleplay giả lập Client-app cho Admin.
  - Thêm form xử lý hoàn tiền kèm upload minh chứng `RefundModal.jsx`.
  - Viết test Vitest cho Admin-web.
- **Phase 4: Client-App (Flutter) Implementation & Verification**
  - Cập nhật model và `ChoThanhToanPage`.
  - Xử lý các dialog xác nhận thừa tiền/thiếu tiền.
  - Chạy toàn bộ test suite và đối soát E2E.
