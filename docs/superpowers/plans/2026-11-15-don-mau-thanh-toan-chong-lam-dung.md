# Kế hoạch: Đơn mẫu chống lạm dụng + sổ giao dịch thanh toán bất biến

Lập 2026-11-15 · Vai lập: Lead PO + Lead BA · Trạng thái: **ĐÃ DUYỆT, ĐÃ THI CÔNG (bước 1–8)**; migration 53 đã áp Supabase 2026-11-15 theo xác nhận đích danh của Chủ dự án.

Điểm lệch khi thi công: (1) thiếu `reference` sau cả hai nguồn ⇒ **giữ nguyên trạng thái đơn** (không chuyển `WAITING_CONFIRMATION` như bản 2 ghi), vì `WAITING_CONFIRMATION` là trạng thái chờ người dùng đồng ý nâng cấp — dùng nó sẽ cho người dùng tự kích hoạt gói khi sổ chưa có mã ngân hàng; thay vào đó ghi `payment_webhook_log` `MISSING_REFERENCE` + sự kiện `payment.reconciliation_needed` tới admin. (2) Tính duy nhất của mã ngân hàng dùng chỉ mục sẵn có `uq_payment_transaction_payos_id` (cột nay NOT NULL nên áp mọi dòng), không tạo chỉ mục mới. (3) Hoàn tiền: số tiền vẫn kiểm ≤ `amount_received` và minh chứng bắt buộc. (4) Chi tiết đơn cho admin lọc sổ: bỏ payload gốc và tên người chuyển, số tài khoản che còn 4 số cuối.
Phạm vi: `src/Backend`, `src/Admin-web`, `src/Backend/database/`. Không đụng Client-app (API người dùng đã lọc `is_template = false`; sự kiện `payment.*` giữ tên). Không commit / push khi chưa có lệnh.

## 0. Quyết định đã chốt (Chủ dự án)

| # | Quyết định |
|---|---|
| D1 | Đơn mẫu chỉ nhận **2.000 đ cố định**; tối đa **10 đơn mẫu / ngày (giờ VN) cho toàn hệ thống**, không phân biệt admin. Chặn ở Backend (lộ API cũng không vượt được) và giao diện. |
| D2 | **Không xoá vĩnh viễn đơn** (mọi trạng thái). "Xóa đơn mẫu" → **ẩn** khỏi danh sách; đơn vẫn trong CSDL. Ẩn không cần PIN. |
| D3 | Thẻ: **Doanh thu** (tổng; thực nhận từ user · thử nghiệm), **Tổng đơn hàng** (tổng; user · thử nghiệm), **Đã thanh toán** (tổng; user · thử nghiệm), **Tỷ lệ thành công** chỉ tính đơn user. |
| D4 | Bỏ khả năng tạo đơn "đã thanh toán" giả khỏi API. |
| D5 | Đơn mẫu gắn với admin tạo (JWT), không nhận `idaccount` từ body. |
| D6 | Tạo đơn mẫu bắt buộc PIN; nhật ký ghi số tiền, mã đơn, người tạo. |
| D7 | Lưu mã giao dịch ngân hàng song song với ngân hàng, lưu cứng, cấm xoá theo quy định. |
| D8 | **Không bao giờ** lưu mã đơn vào chỗ mã giao dịch ngân hàng (sai lệch kế toán). |
| D9 | Lưu **tài khoản nhận, người chuyển, payload gốc có chữ ký PayOS** cho **mọi** giao dịch (user và mẫu). |
| D11 | (duyệt bản 2) Gỡ hẳn API giả lập webhook. Hoàn tiền Backend bắt buộc PIN. Hoàn tiền là thao tác thủ công của admin: **số tiền, mã giao dịch, ngày hoàn, nội dung, minh chứng đều do admin tự nhập và xác nhận** (trách nhiệm của người thực hiện); hoàn xong ⇒ `REFUNDED`, khoá, không hoàn lần 2. Hai mặc định (thiếu `reference` ⇒ chờ đối soát; hoàn được đơn `REFUND_PENDING` và `PAID`) được chấp nhận. |
| D10 | Giao dịch cũ đã xoá: bỏ qua. **Xoá đơn mẫu + giao dịch mẫu hiện có trước**, rồi mới bật trigger. Sau đó hai bảng: **giao dịch cố định tuyệt đối** (cấm xoá, cấm sửa). Lưu ý luồng **hoàn tiền của admin**. |

## 1. Kết quả xác minh (đối chiếu mã + dữ liệu thật, chỉ đọc)

**PayOS (D7):** SDK chính thức `@payos/node` 2.0.5, kiểu `WebhookData`: `reference` (bắt buộc), `accountNumber` (tài khoản nhận), `transactionDateTime`, `paymentLinkId`, `description`, `currency`, `counterAccountBankId/BankName/Name/Number`, `virtualAccountName/Number`. Tra lại được qua `paymentRequests.get(paymentLinkId).transactions[]`. Đơn thật trên Supabase lưu `FT26313015169909` — đúng mã giao dịch MB Bank ⇒ `reference` là mã đối chiếu sao kê.

**Supabase hiện tại:** 1 đơn `PAID` (49.000 đ, đơn user), 1 giao dịch `FT26313015169909`; 0 đơn mẫu; 0 giao dịch giả (`SIM-REF-%`, `SAMPLE-TXN-%`). Không có trigger trên hai bảng.

**Lỗ hổng phát hiện thêm khi soát (đưa vào đợt này):**

| # | Hiện trạng | Hậu quả |
|---|---|---|
| L1 | `POST /api/admin/payments/simulate-webhook` **đang mở ở production**: đánh dấu đơn THẬT của user là đã trả, kích hoạt Premium, ghi giao dịch mã giả `SIM-REF-…` cờ "đã xác thực chữ ký" | Tạo doanh thu và chứng từ giả, cấp Premium không thu tiền |
| L2 | Hàm trên **tạm thay hàm kiểm chữ ký PayOS cho toàn tiến trình** trong lúc chạy | Webhook thật tới đúng lúc đó được nhận không kiểm chữ ký |
| L3 | Hoàn tiền (`PUT /payments/orders/:id/refund`): Backend **không đòi PIN** (chỉ giao diện đòi trước bằng lời gọi riêng) | Lộ phiên admin là ghi hoàn tiền được |
| L4 | Hoàn tiền nhận `refundedAt` **từ body** | Ghi lùi ngày chứng từ |
| L5 | Hoàn tiền **không kiểm trạng thái / số tiền**: hoàn đơn nào cũng được, nhiều lần, ghi đè lần trước, số tiền tuỳ ý | Sai sổ, che lần hoàn trước |
| L6 | Tiền chi ra khi hoàn **không có mã giao dịch ngân hàng**, chỉ có ảnh minh chứng | Không đối chiếu được sao kê chiều chi |
| L7 | Webhook thiếu `reference` ⇒ lưu `orderCode` vào `payos_transaction_id` (D8) | Mã giả trong sổ |
| L8 | Đối soát tức thì với PayOS (`syncOrderWithPayOS`) cũng ghi giao dịch nhưng không lưu chi tiết giao dịch PayOS trả về | Thiếu chứng cứ |

## 2. Thiết kế

### 2.1. Sổ giao dịch (`payment_transaction`) — mỗi dòng là một lần tiền **vào hoặc ra** đã có mã ngân hàng
Migration thêm cột:
- `direction VARCHAR(3) NOT NULL DEFAULT 'IN'` — `IN` (tiền vào qua PayOS) | `OUT` (admin hoàn tiền).
- `source VARCHAR(12)` — `WEBHOOK` | `PAYOS_API` (đối soát tức thì) | `ADMIN_REFUND`.
- `receiving_account_number VARCHAR(50)`, `payment_link_id VARCHAR(64)`, `transfer_description VARCHAR(255)`, `currency VARCHAR(10)`.
- `counter_account_bank_id VARCHAR(20)`, `counter_account_bank_name VARCHAR(255)`, `counter_account_name VARCHAR(512)` (**mã hoá**), `counter_account_number VARCHAR(512)` (**mã hoá**).
- `raw_payload TEXT` (**mã hoá**): webhook gốc có chữ ký (`WEBHOOK`) hoặc phản hồi API PayOS (`PAYOS_API`) — kiểm lại chữ ký được khi điều tra.
- `created_by INT NULL` (admin ghi hoàn tiền), `proof TEXT NULL` (đường dẫn minh chứng hoàn tiền).
- Ràng buộc: `payos_transaction_id` (mã giao dịch ngân hàng) **NOT NULL** + **duy nhất** — sổ không bao giờ có dòng thiếu mã ngân hàng (D8). Dòng hiện có (`FT26313015169909`) thoả.

### 2.2. Tiền vào: webhook / đối soát tức thì (D8, D9, L7, L8)
1. Webhook có `reference` ⇒ ghi dòng `IN` đủ trường 2.1 (cả đơn user và đơn mẫu, cả nhánh đơn đã huỷ → hàng hoàn tiền).
2. Webhook **thiếu** `reference` ⇒ gọi ngay `paymentRequests.get(paymentLinkId)` lấy `reference` của giao dịch khớp số tiền / thời điểm.
3. Vẫn không có ⇒ **không ghi dòng sổ, không kích hoạt gói**; đơn chuyển `WAITING_CONFIRMATION` (trạng thái đã có), payload gốc lưu vào `payment_webhook_log` (2.4), ghi cảnh báo + thông báo admin. Lần đối soát sau (admin mở chi tiết đơn, hoặc webhook phát lại) có `reference` thì ghi sổ và hoàn tất bình thường.
4. `syncOrderWithPayOS` ghi dòng `IN` `source = PAYOS_API` với chi tiết giao dịch PayOS trả về.
5. Trùng `reference` ⇒ nhánh idempotent sẵn có.

### 2.3. Tiền ra: hoàn tiền của admin (L3–L6)
- Một lời gọi duy nhất mang `pin` (Backend xác thực, action `REFUND_ORDER`), `refundedAmount`, `bankReference` (mã giao dịch chuyển khoản hoàn — **bắt buộc**), `refundReason`, minh chứng.
- Chỉ cho hoàn khi đơn `REFUND_PENDING` hoặc `PAID`; `refundedAmount` > 0 và ≤ `amount_received`; mỗi đơn hoàn **một lần** (đơn `REFUNDED` không hoàn lại được).
- `refunded_at` = **ngày giờ hoàn do admin nhập** (bắt buộc; không ở tương lai, không trước lúc tạo đơn). Thời điểm máy chủ ghi nhận lưu riêng ở `created_at` của dòng sổ để đối chiếu.
- Ghi dòng sổ `OUT`, `source = ADMIN_REFUND`, `payos_transaction_id = bankReference`, `created_by = admin`, `proof`; cập nhật đơn sang `REFUNDED` cùng `refunded_*`. Hai việc trong một giao tác.
- Nhật ký `[PAYMENT] Hoàn tiền <số tiền> đơn <mã> — mã GD <bankReference>`.
- Sự kiện `payment.refunded` tới user giữ nguyên tên, payload như cũ.

### 2.4. Nhật ký webhook thô (`payment_webhook_log`, bảng mới, append-only)
`id, received_at, order_code, reference, signature_valid, payload (mã hoá), handled_as` — ghi **mọi** webhook có chữ ký hợp lệ (kể cả đơn không tồn tại, thiếu `reference`), làm chứng cứ đối chiếu PayOS. Trigger cấm sửa / xoá.

### 2.5. Bất biến ở mức CSDL (D10)
Migration `53_payment_legal_retention.sql`, thứ tự trong một giao tác:
1. **Dọn đơn mẫu**: chỉ khi trigger bảo vệ CHƯA tồn tại — `DELETE payment_transaction` của đơn `is_template = true` và giao dịch mã giả (`SAMPLE-TXN-%`, `SIM-REF-%`), rồi `DELETE payment_order WHERE is_template = true`. (Supabase hiện 0 dòng; CSDL thử có thể có.) Chạy lại migration sau khi đã có trigger thì bỏ qua bước này.
2. Thêm cột / bảng ở 2.1, 2.4; `payment_order` thêm `hidden_at`, `hidden_by`.
3. Ràng buộc 2.1.
4. Trigger:
   - `payment_transaction`, `payment_webhook_log`: **cấm UPDATE và DELETE** (cố định tuyệt đối).
   - `payment_order`: **cấm DELETE**. **Cấm UPDATE** các trường gốc: `id, idaccount, order_code, package_type, amount, currency, is_template, created_at, recognition_code`. Đơn đã ở trạng thái cuối **`REFUNDED`**: cấm mọi UPDATE. Trường `paid_at, amount_received, refunded_*` chỉ được ghi một lần (NULL/0 → giá trị), không ghi đè. Vẫn cho đổi `status` theo luồng hợp lệ, xoá `checkout_url / qr_url`, đặt `hidden_at` (trạng thái đơn là dòng đời, tiền thì nằm ở sổ bất biến).
5. Thêm các trigger vào `db:verify-indexes`. Cập nhật `schema.prisma`, `prisma:generate`.
Áp Supabase **chỉ khi Chủ dự án xác nhận đích danh**.

### 2.6. Đơn mẫu (D1, D4, D5, D6)
- `POST /api/admin/payments/sample` chỉ nhận `{ pin }`; bỏ qua mọi trường khác. Xoá nhánh tạo đơn `PAID` + `SAMPLE-TXN`.
- Một giao tác có `pg_advisory_xact_lock`: xác thực PIN (`CREATE_SAMPLE_ORDER`) → đếm đơn mẫu tạo trong ngày giờ VN (gồm đã ẩn) → ≥ 10 ⇒ 429 `SAMPLE_DAILY_LIMIT` → gọi PayOS 2.000 đ → ghi đơn `is_template = true`, `idaccount = req.user.idaccount`.
- Nhật ký `[PAYMENT] Tạo đơn thử nghiệm 2.000 đ, mã đơn <orderCode>` + người tạo.
- `GET /api/admin/payments/sample/quota` → `{ used, limit: 10, amount: 2000 }`.
- Đơn mẫu được trả tiền vẫn **không** kích hoạt gói (giữ luật cũ), nhưng **có** dòng sổ `IN` đủ chứng cứ.

### 2.7. Bỏ giả lập webhook (L1, L2)
- Gỡ route `POST /api/admin/payments/simulate-webhook`, hàm `simulateWebhook` (controller, service) và `paymentApi.simulateWebhook` ở Admin-web (không màn nào gọi). Không còn chỗ nào thay hàm kiểm chữ ký lúc chạy.

### 2.8. Ẩn đơn mẫu (D2)
- `DELETE /api/admin/payments/sample` (giữ đường dẫn) ⇒ đặt `hidden_at`, `hidden_by` cho đơn mẫu chưa ẩn; trả `{ hiddenCount }`. Không xoá dòng nào.
- Danh sách admin mặc định không hiện đơn mẫu đã ẩn; **thống kê và CSV vẫn tính**.

### 2.9. Thống kê (D3)
- `getPaymentSummaryStats` trả thêm `revenue {total,user,template}`, `orders {total,user,template}`, `paid {total,user,template}`; `successRate` chỉ đơn user. Giữ khoá cũ để Admin-web cũ không vỡ. Doanh thu = tổng `amount` đơn `PAID` (định nghĩa hiện tại).

### 2.10. Admin-web
- Ba thẻ: số tổng ở trên, dưới 2 cột "Từ user · Thử nghiệm"; thẻ tỷ lệ ghi "chỉ đơn user".
- `SampleOrderModal`: chỉ "2.000 đ", hiện "Còn x/10 đơn hôm nay", hết lượt khoá nút, tạo ⇒ hộp PIN gửi PIN cùng lời gọi.
- "Xóa đơn mẫu" → "Ẩn đơn mẫu" (hộp xác nhận: "đơn vẫn được lưu, chỉ ẩn khỏi danh sách").
- `RefundModal`: thêm ô **Mã giao dịch hoàn tiền** và **Ngày giờ hoàn** (bắt buộc, admin tự nhập); PIN gửi cùng lời gọi hoàn tiền (không gọi xác thực riêng).
- Chi tiết đơn: bảng giao dịch (vào / ra) với mã giao dịch ngân hàng, tài khoản nhận, người chuyển (che còn 4 số cuối), nguồn ghi nhận.

## 3. Ma trận test (viết trước, phải ĐỎ)

| Mã | Ca | Kỳ vọng |
|---|---|---|
| P1 | Đơn mẫu gửi `amount: 500000000` | Đơn đúng 2.000 đ |
| P2 | Đơn mẫu gửi `status: 'PAID'` / `simulateWebhook: true` | Đơn `PENDING`, không có dòng sổ |
| P3 | Đơn mẫu gửi `idaccount` người khác | Gắn `req.user.idaccount` |
| P4 | Đơn mẫu thiếu / sai PIN | 400, không gọi PayOS, không ghi đơn |
| P5 | Đã có 10 đơn mẫu hôm nay (nhiều admin, gồm đã ẩn) | 429, không gọi PayOS |
| P6 | 10 đơn hôm qua | Hôm nay tạo được (00:00 giờ VN) |
| P7 | Hai yêu cầu đồng thời ở lượt thứ 10 | Chỉ một thành công (CSDL thử) |
| P8 | Ẩn đơn mẫu (có đơn `PAID`) | Không xoá dòng nào; danh sách ẩn; thống kê vẫn tính |
| P9 | Migration trên CSDL thử có đơn mẫu + giao dịch giả | Bị dọn trước; trigger bật sau; chạy lại migration không lỗi |
| P10 | `DELETE` / `UPDATE` `payment_transaction`, `payment_webhook_log`; `DELETE payment_order`; sửa `amount` đơn; sửa đơn `REFUNDED` | CSDL từ chối (CSDL thử) |
| P11 | Webhook đủ trường (đơn user, đơn mẫu) | Dòng `IN` có mã ngân hàng, tài khoản nhận, người chuyển (mã hoá, giải mã khớp), payload gốc mã hoá; có dòng `payment_webhook_log` |
| P12 | Webhook thiếu `reference`, PayOS API trả được | Ghi sổ với `reference` từ API |
| P13 | Webhook thiếu `reference`, API cũng không có | Không có dòng sổ, không kích hoạt gói, đơn `WAITING_CONFIRMATION`, có log; **không** lưu `orderCode` làm mã |
| P14 | Ghi dòng sổ không có mã ngân hàng (gọi thẳng CSDL) | CSDL từ chối (NOT NULL) |
| P15 | Hoàn tiền thiếu PIN / sai PIN | 400, đơn không đổi |
| P16 | Hoàn tiền thiếu `bankReference`; số tiền > đã nhận; đơn `PENDING`; hoàn lần hai | Từ chối |
| P17 | Hoàn tiền hợp lệ (admin nhập ngày hoàn hôm qua) | `refunded_at` = ngày admin nhập; dòng sổ `OUT` (`transaction_time` = ngày admin nhập, `created_at` = giờ máy chủ, mã GD, người hoàn, minh chứng); đơn `REFUNDED`; nhật ký có mã GD. Ngày hoàn ở tương lai hoặc trước lúc tạo đơn ⇒ từ chối |
| P18 | Route `simulate-webhook` | 404 (đã gỡ) |
| P19 | Thống kê có đơn user + đơn mẫu | Tách đúng 3 nhóm; tỷ lệ chỉ user |
| P20 | Nhật ký tạo đơn mẫu | Có số tiền, mã đơn, người tạo |
| A1–A5 | Admin-web: 3 thẻ tách; modal mẫu 2.000 đ + hạn mức + PIN; hết lượt khoá nút; "Ẩn đơn mẫu"; RefundModal bắt buộc mã GD, gửi PIN cùng lời gọi, không gửi `refunded_at` | Tầng 1 + tầng 2 (payload API) |

Sửa test cũ theo đặc tả mới: `tests/unit/admin.payment.test.js` (nhóm `test:shared-db`), test webhook / hoàn tiền hiện có, `Admin-web/src/tests/payments.test.jsx`.

## 4. Thứ tự thi công
1. Migration 53 trên CSDL thử (dọn đơn mẫu → cột / bảng / ràng buộc → trigger) + P9, P10, P14 → **dừng xin xác nhận áp Supabase**.
2. Gỡ giả lập webhook (P18).
3. Tiền vào: webhook + đối soát lưu đủ chứng cứ, xử lý thiếu `reference` (P11–P13).
4. Tiền ra: hoàn tiền (P15–P17).
5. Đơn mẫu: PIN, 2.000 đ, hạn mức, gắn admin, nhật ký, ẩn thay xoá (P1–P8, P20).
6. Thống kê tách (P19).
7. Admin-web (A1–A5) + kiểm trên trình duyệt.
8. Tài liệu: `docs/Payment/*`, `docs/Admin-web` (lịch sử thanh toán), `docs/Rule_Project/Data_Security.md` (sổ thanh toán bất biến, dữ liệu người chuyển mã hoá).

## 5. Rủi ro / lưu ý
- Thiếu `reference` sau cả hai bước (2.2.3): người dùng đã chuyển tiền nhưng chưa có gói tới khi đối soát xong. Theo kiểu dữ liệu SDK, `reference` là trường bắt buộc nên ca này hiếm; đổi lại sổ không bao giờ có mã giả.
- Trigger chặn sửa đơn `REFUNDED`: mọi luồng đọc sau hoàn tiền vẫn chạy; luồng nào cố ghi vào đơn `REFUNDED` sẽ lỗi — soát bằng test hiện có.
- FK `onDelete: Cascade` từ `account` còn nguyên; trigger chặn mọi xoá dây chuyền. Không có luồng xoá vật lý tài khoản (đã `Grep`).
- Dữ liệu người chuyển là dữ liệu cá nhân: lưu mã hoá, hiển thị che 4 số cuối, chỉ admin xem, không gửi qua socket.
- Chưa xác minh: `reference` luôn trùng mã sao kê ở mọi ngân hàng — đối chiếu 1–2 giao dịch thật sau khi chạy.
