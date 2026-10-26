# Soát sau gộp `main` @ `d72ccd45`: hai tệp migration trùng số và script áp migration đồng bộ bị viết đè; webhook xử lý lại đơn đã đối soát; tra mã nhận diện bắt nhầm tiền tố PayOS; hợp đồng thanh toán mới chưa vào tài liệu sự kiện (mục 44)

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`.**
> - **B1 — đạt phần nguy hiểm:** `payment.service.js:137-140` chỉ xử lý webhook khi đơn `PENDING` / `EXPIRED`. Còn dư: webhook bị chặn
>   không ghi hàng `payment_transaction` để đối soát; `amount_received` không cộng dồn qua nhiều lần chuyển; không có test.
> - **B2 — một phần:** `recordTransaction` (`payment.repository.js:329-337`) `findFirst` theo `payos_transaction_id` rồi `create` — đọc-rồi-ghi,
>   hai webhook đồng thời vẫn lọt; CSDL `payment_transaction` **không** unique (khoá chính + `idx_payment_transaction_order` +
>   `idx_payment_transaction_account`); nhánh khớp tiền đi `activatePremiumSubscription`, hàm này `create` thẳng (`:373-386`), không qua khử
>   trùng. Xin: unique index trên `payos_transaction_id` và mọi đường ghi bắt 23505.
> - **C vế phụ — chưa:** `findOrderByRecognitionCode` (`:284-301`) không lọc `PENDING`, `findFirst` không `orderBy`.
> - **A — đạt:** tệp thành `27b_…` (`uniq -d` rỗng); dòng 2 của tệp `27b` vẫn ghi "Migration 27".
> - **F — vẫn tái phát:** `Event-Notification-to-ClientApp.md` có 0 lần `confirm-upgrade` / `WAITING_CONFIRMATION` / `REFUND_PENDING` /
>   `REFUNDED` / `excessAmount` / `amountReceived`; §4.13 `:406` ghi `receivedAmount`; bảng `:91` dặn "mở hỗ trợ CSKH"; **sai mới** §4.12
>   `:386-392` ghi `orderCode` / `timestamp` (mã gửi `orderId` / `refundedAt` — `payment.service.js:503-509`).
> - D, E vẫn đạt.

> 🔎 **Client soát lại 2026-10-26** (mã `main` @ `5bb258ff`, backend mới nhất `36f1ea43`; truy vấn chỉ đọc trên CSDL
> Supabase của `.env`): **B chưa làm; A và F tái phát.**
> - **B1:** chốt ở `payment.service.js:136` vẫn chỉ chặn `PAID` / `REFUNDED` / `CANCELLED` — đơn `WAITING_CONFIRMATION` nhận lại
>   webhook có số tiền khớp rơi xuống nhánh `:313` và được nâng gói.
> - **B2:** `recordTransaction` vẫn `create` thẳng (`payment.repository.js:328-339`); CSDL: `payment_transaction` chỉ có khoá chính
>   + hai chỉ mục thường (`order_id`, `idaccount`), **không** unique theo mã giao dịch PayOS.
> - **C:** phần chính đạt; vế phụ chưa — `findOrderByRecognitionCode` (`payment.repository.js:286`) không lọc `PENDING`.
>   **D** đạt (CSDL: `payment_order.status` dài 25). **E** đạt.
> - **A tái phát:** `6cbd248e` (2026-10-23) thêm `27_create_aiops_metric_snapshot_table.sql`, trùng số với `27_add_qr_url…` —
>   theo dõi ở mục 49 vế C. `apply_migration_20.js:19` vẫn đúng.
> - **F tái phát:** từ `6cbd248e`, `confirm-upgrade`, ba trạng thái đơn mới và `excessAmount` bị xoá khỏi
>   `Event-Notification-to-ClientApp.md` (5 lần nhắc → 0); §4.13 `:404-409` ghi `receivedAmount`, mã gửi `amountReceived` +
>   `excessAmount` / `shortage` / `fee` (`payment.service.js:223-230`, `:266-274`).
>
> 🟡 **Client soát 2026-10-18 (sau gộp `main` @ `e7570e16`; backend ghi *"✅ Đã xong 100%"* ở `3a5d320c`): đạt năm
> mục, mục B còn hai vế.** Đo bằng đọc mã ở `e7570e16`, truy vấn chỉ đọc trên CSDL dev, và `grep` tài liệu hợp đồng sự
> kiện. Thân đơn bên dưới giữ nguyên: mục *Xin làm* và *Kiểm lại bằng* của vế B vẫn áp dụng.
>
> **Đạt:**
> - **A** — `ls database | cut -d_ -f1 | sort | uniq -d` không in gì. Hai tệp thanh toán thành `28_…` và `29_…`, thêm
>   `27_add_qr_url_to_payment_order.sql`. `apply_migration_20.js` trỏ lại `20_add_server_update_at_sync_tables.sql`.
> - **C** — `payment.service.js:121` tra mã nhận diện theo token cuối của `description` (`/^[A-Z0-9]{6}$/`).
> - **D** — `28_…sql:17` có `ALTER COLUMN "status" TYPE VARCHAR(25)`. CSDL dev đo 2026-10-18: `payment_order.status` dài
>   **25**, bảng có **22** cột (đủ cột của 27, 28, 29).
> - **E** — controller (`:207`) và service (`:378`) đều trả 400 khi `accept` không phải boolean.
> - **F** — `Event-Notification-to-ClientApp.md` §3.12–3.14 có ba sự kiện `payment.*` với đúng các khoá payload mà
>   `payment.service.js` phát; §3.12 tả `POST /api/payment/confirm-upgrade` với `accept` true / false; ba trạng thái mới và
>   hạn 10 phút đều có. Thêm §3.15 `payment.order_expired` (ngoài đơn).
>
> **Còn mở — mục B:**
> 1. Chốt idempotency (`payment.service.js:136`) chỉ chặn `PAID` · `REFUNDED` · `CANCELLED`. Ba nhánh sau nó (khớp ·
>    thừa · thiếu) không xét trạng thái nữa. Nên một webhook lặp lại cho đơn `WAITING_CONFIRMATION` hoặc `REFUND_PENDING`
>    sẽ ghi thêm một hàng `payment_transaction`, ghi đè `amount_received`, và phát lại `payment.overpaid_confirmation` /
>    `payment.underpaid_warning`. Nếu số tiền của lần sau khớp đúng giá gói, đơn đang chờ xác nhận nhảy thẳng sang `PAID`
>    và nâng gói mà người dùng chưa chọn. Đơn xin *"chỉ xử lý khi còn `PENDING` (và `EXPIRED`)"*.
>    *Kiểm lại:* ca test — đơn `WAITING_CONFIRMATION` nhận lại đúng webhook cũ → trạng thái và `amount_received` không đổi,
>    không phát sự kiện, có thêm tối đa một hàng `payment_transaction` để đối soát.
> 2. Chưa khử trùng theo `reference`: `recordTransaction` (`payment.repository.js:325`) `create` thẳng, không có unique
>    index trên `payos_transaction_id`.
>    *Kiểm lại:* hai webhook cùng `reference` → một hàng `payment_transaction` (câu ở mục *Kiểm lại bằng* vế B).
>
> **Câu hỏi có mặc định (không chặn client):** spec `docs/Payment/PAYMENT_WORKFLOW_SPEC.md` (sơ đồ trạng thái, dòng
> 132–136) cho `WAITING_CONFIRMATION` chỉ hai lối ra, đều do người dùng chọn. Bộ hết hạn tự động
> (`autoExpirePendingOrders`, `payment.repository.js:46`) chỉ xét `PENDING`. Vậy người dùng không bao giờ chọn thì tiền
> nằm ở đó mãi. **Mặc định client theo:** không có hạn chờ; client sẽ thêm lối xác nhận ở trang Lịch sử mua, vì
> `GET /payment/history` đã trả đủ mã đơn và trạng thái (G94 phía client). Backend chỉ cần ghi lựa chọn ấy vào spec. Nếu
> backend muốn có hạn chờ, xin ghi hạn và trạng thái đích vào spec để client hiện đúng câu.
>
> ✅ **Client đã làm phần của mình (mã xong 2026-10-18 tối, G94 lát 2; chưa nghiệm thu sandbox):** mọi dòng Lịch sử mua
> mở màn Chi tiết đơn `/premium/don/:orderCode` — nơi gọi `confirm-upgrade`; màn Nâng cấp có thẻ đơn chờ xác nhận và khoá
> *Thanh toán* tới khi người dùng chọn. Client tìm đơn trong `GET /payment/history` trang 1 (20 dòng) — đơn chờ xác nhận
> cũ hơn 20 đơn sẽ không có lối vào; với gói 30 ngày đây là ca hiếm, client không xin thêm API.

**Ngày:** 2026-10-16 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat` (commit gộp `e49100ed`)
**Loại:** đơn xin — **một lỗi mức cao** (A), **ba lỗi mức vừa** (B, C, D), **hai việc mức thấp** (E, F). Không đổi lược đồ
đồng bộ, không đổi payload `/sync/*`. Mọi khẳng định dưới đây đo bằng **đọc mã** ở `d72ccd45` và **truy vấn chỉ đọc**
trên CSDL dev ngày 2026-10-16. Client không chạy backend, không sửa `src/Backend`.

**Vì sao client gửi đơn này:** bốn commit *"Payment premium Backend + admin-web"* (PR #138) thêm luồng đối soát chuyển
thừa / thiếu (`docs/Payment/PAYMENT_WORKFLOW_SPEC.md` v2.0.0), trong đó mục 5.1 tả việc client phải làm. Client soát
mã mới trước khi làm phần của mình và gặp A–F. **Đơn 43 mục B vẫn mở:** `findOrCreateOrderByCode`
(`payment.repository.js:88`) giống hệt từng dòng so với `cd2ee572`. Đơn tự tạo lấy `amount` từ chính webhook, nên số
tiền luôn "khớp" và luôn đi nhánh 6.1 (PAID). Hậu quả vẫn như đơn 43 mô tả, không nặng thêm. Hàm này còn đặt
`expired_at = now + 30 phút` trong khi đơn thường nay là 10 phút.

---

## A. (CAO) Hai tệp migration trùng số; `apply_migration_20.js` bị viết đè nên migration đồng bộ số 20 mất script áp

### Hiện tượng

| Số | Tệp đã có từ trước (đã áp) | Tệp mới ở `d72ccd45` |
|---|---|---|
| 20 | `database/20_add_server_update_at_sync_tables.sql` — cột `Server_update_at` + trigger cho 6 bảng đồng bộ (đơn 37) | `database/20_add_payment_reconciliation_and_refund_fields.sql` |
| 24 | `database/24_add_actor_role_to_aiops_incident.sql` | `database/24_add_is_template_to_payment_order.sql` |

`scripts/apply_migration_20.js` **bị viết lại**: trước trỏ `20_add_server_update_at_sync_tables.sql` và kiểm cột
`Server_update_at` trên 6 bảng, nay trỏ tệp thanh toán và chỉ kiểm 8 cột `payment_order`. Đo bằng `git grep` ở
`d72ccd45`: **không còn chỗ nào** trong `src/Backend` nhắc `20_add_server_update_at` hay `24_add_actor_role`.

**Hậu quả:** dựng một CSDL mới (máy mới, Supabase mới, khôi phục thảm hoạ) theo `database/N` + `apply_migration_N.js`
sẽ **bỏ sót** `Server_update_at`. `/sync/pull` và `maxSince` đọc cột ấy (đơn 37). Thiếu nó, đường kéo về của **mọi**
client hỏng. Mốc kéo về của client (G67, `mocTuMaxSince`) dựa trên `maxSince` này. Sổ *"tệp nào đã áp"* cũng không còn
phân biệt được hai tệp cùng số.

CSDL dev hôm nay **không** hỏng: đo 2026-10-16, `Server_update_at` có trên đủ 6 bảng (`bill`, `budget`, `category`,
`goal`, `transaction`, `wallet`). Hai tệp thanh toán mới **chưa áp**: `payment_order` có 12 cột, chưa có cột nào trong
9 cột mới (`recognition_code`, `amount_received`, `fee`, `transfer_content`, `refunded_at`, `refunded_amount`,
`refund_reason`, `refund_proof`, `is_template`).

### Xin làm

1. Đánh số lại hai tệp thanh toán sang số **còn trống** (số 26 đã dùng cho ba bảng `aiops_*quarantine*`, nên ví dụ 27,
   28 — backend tự chọn). Đổi tên cả `apply_migration_24.js` cho khớp.
2. Trả `apply_migration_20.js` về bản trỏ `20_add_server_update_at_sync_tables.sql` (bản ở `cd2ee572`). Script cho tệp
   thanh toán mang số mới.
3. Ghi hai tệp mới vào sổ *"tệp đã áp"* theo quy ước `docs/Rule_Project/Rule_project.md` §3.2.

### Kiểm lại bằng

```bash
ls src/Backend/database | cut -d_ -f1 | sort | uniq -d     # không in gì (không số nào trùng)
git grep -n "20_add_server_update_at_sync_tables" -- src/Backend/scripts   # có ít nhất một dòng
```

---

## B. (VỪA) Webhook chỉ chặn xử lý lại khi đơn `PAID` → đơn đã đối soát bị xử lý lại

### Hiện tượng

`payment.service.js:131`: bước *Idempotency* chỉ là `if (order.status === 'PAID') return`. Đơn ở
`WAITING_CONFIRMATION`, `REFUND_PENDING`, `REFUNDED` hoặc `EXPIRED` mà nhận một webhook nữa (PayOS gửi lại khi không
nhận 2xx, hoặc người dùng chuyển lần hai cho cùng nội dung) sẽ chạy lại nhánh 6.2a / 6.2b:

- `updateOrderPaymentStatus` **ghi đè** `amount_received` bằng số của lần sau, không cộng dồn. Ví dụ: chuyển thiếu
  40.000, chuyển bù 9.000 → đơn ghi `amount_received = 9000`. Ai hoàn tiền theo cột này hoàn **thiếu 40.000**.
- Đơn đã `REFUNDED` mà nhận lại webhook thiếu tiền sẽ **lùi về `REFUND_PENDING`**: nút *Hoàn tiền* ở Admin-web sáng lại,
  nên có thể hoàn **hai lần**.
- `recordTransaction` ghi thêm một hàng `payment_transaction`. Bảng không có ràng buộc duy nhất trên
  `payos_transaction_id` (`schema.prisma` `model payment_transaction`: chỉ hai index thường).
- Client nhận lại `payment.overpaid_confirmation` / `payment.underpaid_warning` cho một đơn đã xong.

### Xin làm

- Chỉ xử lý webhook khi đơn còn `PENDING` (và `EXPIRED`, nếu muốn nhận tiền đến muộn). Các trạng thái khác: ghi log, ghi
  hàng `payment_transaction` để đối soát, trả **2xx**, **không** đổi trạng thái đơn.
- Khử trùng theo `reference` (`payos_transaction_id`): cùng mã đã có thì bỏ qua. Nên thêm unique index (tệp `database/N`).
- Chuyển nhiều lần cho cùng đơn: `amount_received` nên là **tổng** các giao dịch của đơn (hoặc ghi rõ trong spec là chỉ
  lần đầu được tính).

### Kiểm lại bằng

Ca test: một đơn `REFUNDED` nhận lại cùng webhook thiếu tiền → trạng thái vẫn `REFUNDED`, không phát sự kiện nào tới
client. Hai webhook cùng `reference` → một hàng `payment_transaction`.

---

## C. (VỪA) Tra đơn theo mã nhận diện bắt nhầm tiền tố PayOS

`payment.service.js:116`: `description.match(/([A-Z0-9]{6})/)` lấy **6 ký tự đầu tiên** khớp mẫu. Với nội dung đúng
dạng spec mục 2 (`'CSCYDEZ2N10 A8B9K2'`), kết quả là **`CSCYDE`**, tức phần đầu tiền tố động của PayOS, không phải mã
`A8B9K2` (chạy thử bằng `node -e`, 2026-10-16). Nhánh tra theo mã nhận diện gần như không bao giờ tìm đúng đơn. Hôm nay
đơn vẫn được tìm thấy nhờ `orderCode` (tra trước), nên chỉ nhánh dự phòng chết. Nhưng nếu `findOrderByCode` trượt,
luồng rơi thẳng xuống `findOrCreateOrderByCode` (đơn 43 mục B).

**Xin làm:** lấy **token cuối** của nội dung (`description.trim().split(/\s+/).pop()`, so đúng 6 ký tự
`^[A-Z0-9]{6}$`), hoặc so với `transfer_content` đã lưu lúc tạo đơn. Tra theo mã nhận diện chỉ trong các đơn còn
`PENDING`.

**Kiểm lại bằng:** ca test webhook có `orderCode` không khớp đơn nào và `description: 'CSCYDEZ2N10 <mã của một đơn
PENDING>'` → tìm đúng đơn ấy.

---

## D. (VỪA) `schema.prisma` ghi `status VarChar(25)` nhưng không tệp SQL nào nới cột

`schema.prisma` `model payment_order`: `status … @db.VarChar(25)` (trước là 20). Cả hai tệp migration mới **không** có
`ALTER COLUMN "status"`. CSDL dev đo 2026-10-16: `payment_order.status` là `character varying(20)`, không có CHECK.
`'WAITING_CONFIRMATION'` dài **đúng 20** ký tự, nên hôm nay vừa khít. Trạng thái nào dài hơn thêm về sau sẽ vỡ `P2000`
ngay trong webhook. Webhook trả 5xx, PayOS gửi lại mãi, và người trả tiền không được nâng gói. Client từng vấp đúng
khuôn này với `wallet.Status varchar(7)` (`DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`).

**Xin làm:** thêm `ALTER TABLE "payment_order" ALTER COLUMN "status" TYPE VARCHAR(25);` vào tệp migration thanh toán
(sau khi đánh số lại, mục A). Hoặc đưa `schema.prisma` về `VarChar(20)`. Hai nơi phải nói cùng một con số.

**Kiểm lại bằng:**

```sql
SELECT character_maximum_length FROM information_schema.columns
WHERE table_name = 'payment_order' AND column_name = 'status';   -- 25 (khớp schema.prisma)
```

---

## E. (THẤP) `POST /api/payment/confirm-upgrade` ngã về phía kích hoạt khi `accept` thiếu hoặc sai kiểu

`payment.controller.js:203` đọc `{ orderCode, accept } = req.body`. `payment.service.js:329` `confirmUpgrade(idaccount,
{ orderCode, accept = true })`: body **thiếu** `accept` thì mặc định **đồng ý kích hoạt**. Chuỗi `"false"` là truthy,
nên cũng thành đồng ý. Client sẽ gửi boolean thật, nhưng một lỗi ở bất kỳ phía gọi nào sẽ biến *"từ chối"* thành *"thu
tiền"*.

**Xin làm:** `typeof accept !== 'boolean'` → 400. Không đặt giá trị mặc định cho `accept`.

---

## F. (THẤP) Hợp đồng thanh toán mới chưa vào `docs/Admin-web/Event-Notification-to-ClientApp.md`

Tài liệu hợp đồng sự kiện tới client (*"PO đã phê duyệt"*, đơn 43 mục D) chưa có:

- ba sự kiện mới tới phòng tài khoản: `payment.overpaid_confirmation` `{ orderId, orderCode, expectedAmount,
  amountReceived, excessAmount, message }`, `payment.underpaid_warning` `{ …, shortage, fee, message }`,
  `payment.refunded` `{ orderId, refundedAmount, refundedAt, refundReason, refundProof }`;
- endpoint `POST /api/payment/confirm-upgrade` `{ orderCode, accept }`;
- ba trạng thái đơn mới `WAITING_CONFIRMATION`, `REFUND_PENDING`, `REFUNDED` của `GET /payment/order-status/:orderCode`
  và `GET /payment/history`;
- hạn đơn đổi từ 30 phút sang **10 phút**.

**Xin làm:** thêm các mục trên vào tài liệu hợp đồng, cùng lượt sửa mục D của đơn 43.

**Thông tin cho backend (không phải lỗi):** client coi payload socket là **hộp đen** (chỉ đọc tên sự kiện, quyết định
2026-09-09; ngoại lệ duy nhất là `account.force_logout`). Khi làm phần của mình, client nhiều khả năng sẽ dùng sự kiện
như **tín hiệu** rồi đọc lại `GET /payment/order-status/:orderCode`. Hôm nay endpoint này trả `amount`,
`amountReceived`, `recognitionCode`, `transferContent`, nhưng **chưa** trả `fee`, `refundReason`, `refundedAmount`,
`refundedAt`. Client chưa chốt thiết kế. Khi chốt, client sẽ đặt đơn riêng nếu cần các trường ấy. Client cũng không
hiện `message` của server (chuỗi dùng `₫` và số không ngăn nghìn, khác quy ước hiển thị tiền của app).

---

## Client sẽ làm gì

Phía client có một khoảng trống mới, **G94** (`docs/CLIENT_APP_KNOWN_GAPS.md`). Client chưa biết ba trạng thái mới
nên coi là `pending`: người chuyển thừa ngồi ở màn *Chờ thanh toán* tới hết hạn mà không thấy hộp xác nhận. Câu *"chỉ
có hiệu lực 30 phút"* nay sai. A–F không chặn client. Người dùng chốt làm G94 **cùng lượt** với phần client của đơn 43,
sau khi đơn 43 đóng. Nếu thiết kế lúc ấy cần thêm trường ở `order-status` (mục F), client sẽ đặt đơn riêng.

> **Cập nhật 2026-10-18 tối (client):** màn Chờ thanh toán thôi tự báo hết hạn khi đồng hồ trên máy về 0 — nay chỉ báo
> khi `GET /payment/order-status` trả `EXPIRED`. Client vì thế **dựa vào** hành vi hiện có của backend: đơn `PENDING` quá
> `expired_at` được trả `EXPIRED` ngay lúc đọc — ba chỗ cùng làm việc ấy: `findOrderByCode` gọi
> `autoExpirePendingOrders` trước khi đọc (`payment.repository.js:106`), phép chuẩn hoá ở `payment.repository.js:30`, và
> `payment.service.js:713`. Xin giữ hành vi ấy; nếu bỏ cả ba, màn chờ sẽ đứng ở *"Còn 00:00"* tới lượt quét định kỳ
> (`setInterval`, `payment.service.js:895`). Không phải việc mới cho backend.
