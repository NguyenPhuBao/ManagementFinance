# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này **chỉ có việc còn phải làm**, đo trên backend `13fddd09` (PR #176) ngày 2026-11-01. Việc xong thì client xoá khỏi tệp; lịch sử xem bằng git.
> Đơn mới thêm vào tệp này, số kế tiếp **65**.

## Tổng quan

| Mã | Lỗi | Mức | Cách xong |
|---|---|---|---|
| 52.4 | Chưa so khoá mã hoá trên Render. Khác khoá thì kéo toàn bộ trả 500 | **CAO** | Tay, cần quyền Render |
| 61.2 | Gemini quá 60 giây: luồng chat treo, không có `done` | **CAO** | Bản vá |
| 63.1 | Áp `database/45_add_transaction_fund_pair.sql` lên Supabase trước khi gộp / triển khai nhánh gia đình 1A (thiếu cột thì mọi truy vấn `transaction` ném `P2022`) | **CAO** | Chạy SQL luỹ đẳng, có câu kiểm |
| 62.1 | Tạo đơn rơi về tài khoản MB cá nhân ghi cứng khi PayOS không trả thông tin nhận tiền | **CAO** | Bản vá + sửa tay Admin-web, tài liệu |
| 62.2 | Đường JIT bỏ qua số tiền và trạng thái `UNDERPAID`: webhook không tới thì chuyển thiếu thành hết hạn, chuyển thừa thành `PAID` | VỪA | Bản vá |
| 61.3 | Người dùng bấm Dừng bị đếm là lỗi LLM, có thể đóng chatbot của mọi tài khoản | VỪA | Bản vá |
| 62.3 | Webhook hợp lệ tới đơn `CANCELLED`: tiền vào nhưng đơn đứng yên, không ai được báo | VỪA | Bản vá |
| 62.6 | Xác nhận kênh PayOS của `.env` và URL webhook; client cần để đóng G94 | VỪA | Trả lời 4 câu |
| 63.2 | Khoản thuộc nhà trỏ danh mục riêng: server không kiểm phạm vi danh mục (suy từ mã, chưa đo) | VỪA | Quyết định + bản vá nhỏ |
| 64.1 | `formerMembers` chứa người đang ở hoặc một người nhiều lần: `addMember` luôn tạo hàng mới, không khoá duy nhất theo (nhà, tài khoản) (client đã khử trùng khi đọc) | THẤP | Quyết định + bản vá nhỏ |
| 61.4 | Cửa sổ thời gian của cầu dao không bao giờ reset | THẤP | Bản vá |
| 61.1 | Lời mời email nhận địa chỉ có dấu | THẤP | Bản vá |
| 61.5 | Hàng còn sống trong nhà giải tán trước bản sửa 57.6 | THẤP | Chạy SQL, có thể không cần |
| 62.4 | Đồng ý đơn chuyển thừa ghi hai dòng `payment_transaction` cho một lần chuyển | THẤP | Bản vá |
| 62.5 | `paid_at` đọc giờ PayOS theo múi giờ của máy chủ | THẤP | Bản vá |
| 60.3 | Ba ca test nói nhiều hơn điều chúng chứng minh | THẤP | Tay, tuỳ chọn |

**Thứ tự đề xuất:** áp 63.1 (cột `Idfund_pair`) **trước mọi lần gộp / triển khai nhánh gia đình**; rồi áp bản vá một lần cho 61.1–61.4, chạy kịch bản, rồi làm 52.4 và 61.5. Áp bản vá đơn 62 thành một lượt riêng (hai bản vá không đụng chung tệp), rồi làm phần tay của 62.1 và trả lời 62.6.

---

## Bản vá cho 61.1, 61.2, 61.3, 61.4

Bản vá 3 tệp, +13 / −6 dòng, không đổi hợp đồng API, không cần migration. Client đã thử trên bản sao của `13fddd09`: kịch bản đơn 61 **1 / 6 trước khi vá, 6 / 6 sau khi vá**; `circuit.breaker`, `audit.log`, `chatbot.rag`, `chatbot.tools`, `household.api` đều xanh sau khi vá.

```bash
# Từ gốc repo
git apply docs/superpowers/backend/CAN-LAM/KIEM-THU/ban_sua_61.patch

cd src/Backend
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_61.js . kq_61.txt   # dòng cuối: 6 đạt / 6 ca
node --test --test-force-exit tests/unit/circuit.breaker.test.js                   # 3 pass
```

Kịch bản không cần CSDL, không gọi Gemini, không gửi thư: `config/db`, SDK Gemini và `household.service` bị thay bằng bản giả trong tiến trình.

`git apply` báo lỗi thì sửa tay theo từng mục dưới đây. Sau đó chạy hai kịch bản ở mục *Giữ nguyên khi sửa backend*.

---

## 52.4 (CAO) — So khoá mã hoá trên Render

⚠️ **Bảng trả lời PR #176 chưa đóng việc này.** Phép so ở đó là khoá dev với dữ liệu Supabase, và phần ấy đúng: client đo lại 2026-11-01, khoá `.env` có vân tay `98e9e026`, Supabase có 28 trường mã hoá, 0 lỗi giải mã. Điều chưa ai biết là **máy chủ Render có chạy cùng khoá ấy không**. `db:verify-encryption` chạy trên máy dev không trả lời được câu này, vì nó đọc khoá của máy dev.

25 + 3 hàng trên Supabase mang khoá `.env`. Render khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng còn sống trả 500 (`sync.controller.js:67-73`).

So vân tay, không in khoá. Thêm tạm vào `index.js` sau khi nạp `.env`, deploy, đọc log Render, rồi gỡ:

```js
logger.info('DATA_KEY_FP', { fp: require('crypto').createHash('sha256').update(process.env.DATA_ENCRYPTION_KEY || '').digest('hex').slice(0, 8) });
```

**Xong khi có đủ hai điều:**

1. Log Render in `DATA_KEY_FP` bằng `98e9e026`.
2. `GET https://managementfinance.onrender.com/api/sync/pull?since=1970-01-01T00:00:00.000Z` của một tài khoản có hàng đã di trú trả 200.

Khác vân tay thì đừng đổi khoá trên Render khi chưa di trú dữ liệu: báo client và PO trước.

## 61.2 (CAO) — Gemini quá 60 giây thì luồng chat treo

**Đo được** (2026-11-01, `POST /api/ai/chatbot/chat/stream`, câu hỏi dài, Gemini đang quá tải):

| Giờ | Sự việc |
|---|---|
| 13:16:58 | Hai request vào |
| 13:17:58 | Đúng 60 giây sau: `Request aborted when fetching…`, log ghi *"Client đã ngắt kết nối"*. **Client chưa hề ngắt** |
| 13:18:57, 13:19:27 | Client tự bỏ sau 120 giây và 150 giây. Giữa chừng không có `done`, không có `fallback`, chỉ có `: ping` |

**Gốc lỗi.** `chatbot.service.js:171` đặt `timeout: 60000` cho SDK. Hết giờ, SDK ném lỗi có chữ `aborted`. Khối `catch` (`:233`) thấy chữ ấy thì coi là người dùng dừng và `return`:

- Không gọi `onDone`, nên `res.end()` không chạy và luồng SSE treo.
- `pingInterval` không được dọn, cứ 15 giây lại ghi `: ping`, nên `receiveTimeout` của client không nổ.
- Không có `fallback`, nên app chờ hết trần 120 giây (`kTranTongOnline`) mới rơi về mô hình trên máy.

**Sửa.** `modules/ai/features/chatbot/chatbot.service.js`, chỉ tin `signal` của client:

```js
// Trước
if (signal?.aborted || error.name === 'AbortError' || error.message?.includes('aborted')) {

// Sau
// Chỉ signal của client mới nghĩa là người dùng dừng. Hết giờ `timeout: 60000` của SDK cũng báo chữ "aborted"
// nhưng client vẫn đang chờ: phải đi nhánh fallback để có `done`, không thì luồng treo tới khi client tự bỏ.
if (signal?.aborted) {
```

**Xong khi:** hai ca `61.2` của kịch bản đạt. Hết giờ phải đi nhánh `_streamFallbackResponse` (có `done.fallback = true`) và vẫn được cầu dao đếm là một lỗi.

## 61.3 (VỪA) — Bấm Dừng bị đếm là lỗi LLM

**Đo được** (2026-11-01): client ngắt sau `meta`, Dừng đã tới server đúng, nhưng log có:

```text
13:16:03 [SSE Controller] Client idaccount: 10 đã ngắt kết nối stream.
13:16:03 WARN [CircuitBreaker] Ghi nhận lỗi LLM (2/5): … Request aborted … This operation was aborted
```

**Hậu quả.** `geminiCircuitBreaker` dùng chung cả tiến trình. Kịch bản: 6 lần Dừng liên tiếp đưa cầu dao sang `OPEN`, mọi tài khoản nhận thông báo fallback trong 30 giây. Dừng lúc đang thăm dò `HALF-OPEN` cũng đẩy về `OPEN`.

**Sửa.** Hai tệp:

```js
// modules/ai/features/chatbot/resilience/circuit-breaker.js
async execute(fn, { boQuaLoi } = {}) {
  // … giữ nguyên …
  } catch (error) {
    if (!boQuaLoi?.(error)) {
      this.handleFailure(error, now);
    }
    throw error;
  }
}

// modules/ai/features/chatbot/chatbot.service.js, dấu đóng của lời gọi geminiCircuitBreaker.execute(async () => { … })
}, { boQuaLoi: () => signal?.aborted === true });
```

**Xong khi:** hai ca `61.3` của kịch bản đạt: 6 lần Dừng thì cầu dao vẫn `CLOSED`, bộ đếm 0; Dừng lúc `HALF-OPEN` không về `OPEN`.

## 61.4 (THẤP) — Cửa sổ của cầu dao không bao giờ reset

**Gốc lỗi.** `circuit-breaker.js:84` gán `lastFailureTime = now` rồi dòng `:95` mới so `now - lastFailureTime > windowMs`. Hiệu số luôn bằng 0, nên nhánh reset về 1 là mã chết. Ba lỗi cách nhau nhiều giờ vẫn mở cầu dao nếu giữa chúng không có lượt thành công nào chạy sau cửa sổ.

**Sửa.** So trước khi gán:

```js
handleFailure(error, now) {
  // Phải so TRƯỚC khi gán: gán trước thì hiệu số luôn 0, cửa sổ không bao giờ reset.
  const quaCuaSo = now - this.lastFailureTime > this.windowMs;
  this.lastFailureTime = now;
  // … nhánh HALF-OPEN giữ nguyên …
  if (this.state === 'CLOSED') {
    if (quaCuaSo) {
      this.failureCount = 1;
    } else {
      this.failureCount++;
    }
    // … phần còn lại giữ nguyên …
```

**Xong khi:** ca `61.4` của kịch bản đạt: lỗi rời rạc không cộng dồn, ba lỗi liền nhau trong cửa sổ vẫn mở cầu dao.

## 61.1 (THẤP) — Lời mời email nhận địa chỉ có dấu

**Đo được** (2026-11-01, Realme): bộ gõ Telex đổi `.test` thành `.tét`, `POST /api/households/invites/email` trả 202 với `giadinhthu1@flowmoney.tét`. Resend từ chối (*The email address contains non-ASCII characters*), SMTP dự phòng vẫn gửi, lời mời nằm *Đang chờ* và chiếm một chỗ trong nhà tới khi huỷ. Client nay đã chặn trước, nhưng bản app cũ và lối gọi API trực tiếp vẫn lọt.

**Sửa.** `modules/household/household.controller.js:299`, thêm vế từ chối ký tự ngoài ASCII in được, dùng lại 400 `INVALID_EMAIL` đang có:

```js
if (!email || typeof email !== 'string' || !email.includes('@') || email.trim().length > 100 || /[^ -~]/.test(email)) {
```

**Xong khi:** ca `61.1` của kịch bản đạt: `an@flowmoney.tét` trả 400 và không tạo lời mời, `an@flowmoney.test` vẫn 202.

## 61.5 (THẤP) — Hàng còn sống trong nhà giải tán trước bản sửa 57.6

`dissolveHousehold` hiện tại đã xoá mềm đủ năm bảng; đo năm nhà giải tán sau bản sửa (nhà 3–7) đều sạch. Nhưng nhà giải tán **trước** bản sửa còn hàng `Delete_at` trống. Trên `PersonFinance` có 2 ví, 2 giao dịch, 26 danh mục (nhà 1, 2). Các hàng này không về app, vì `/sync/pull` lọc theo thành viên, nhưng vẫn được đếm khi truy vấn thẳng bảng.

Client không đọc được Supabase và production nên chưa biết ở đó có hay không. **Bạn chạy trên từng CSDL dùng thật:**

**Bước 1, đếm (chỉ đọc):**

```sql
SELECT 'wallet' AS bang, count(*)::int AS n FROM "wallet" x JOIN "household" h ON h."Idhousehold" = x."Idhousehold" WHERE h."Status" = 'Dissolved' AND x."Delete_at" IS NULL
UNION ALL SELECT 'transaction', count(*)::int FROM "transaction" x JOIN "household" h ON h."Idhousehold" = x."Idhousehold" WHERE h."Status" = 'Dissolved' AND x."Deleted_at" IS NULL
UNION ALL SELECT 'budget', count(*)::int FROM "budget" x JOIN "household" h ON h."Idhousehold" = x."Idhousehold" WHERE h."Status" = 'Dissolved' AND x."Delete_at" IS NULL
UNION ALL SELECT 'goal', count(*)::int FROM "goal" x JOIN "household" h ON h."Idhousehold" = x."Idhousehold" WHERE h."Status" = 'Dissolved' AND x."Delete_at" IS NULL
UNION ALL SELECT 'category', count(*)::int FROM "category" x JOIN "household" h ON h."Idhousehold" = x."Idhousehold" WHERE h."Status" = 'Dissolved' AND x."Delete_at" IS NULL;
```

Cả năm dòng bằng 0 thì ghi *"0 hàng"* vào bảng trả lời và dừng.

**Bước 2, có hàng thì dọn.** Chỉ xoá mềm, đúng quy tắc của dự án. Client đã chạy thử trên `PersonFinance` trong giao tác rồi `ROLLBACK`: cập nhật đúng 2 / 2 / 0 / 0 / 26 hàng, bước 1 về 0.

```sql
BEGIN;
UPDATE "wallet" x SET "Delete_at" = h."Delete_at", "Update_at" = NOW(), "Server_update_at" = NOW()
  FROM "household" h WHERE h."Idhousehold" = x."Idhousehold" AND h."Status" = 'Dissolved' AND x."Delete_at" IS NULL;
UPDATE "transaction" x SET "Deleted_at" = h."Delete_at", "Update_at" = NOW(), "Server_update_at" = NOW()
  FROM "household" h WHERE h."Idhousehold" = x."Idhousehold" AND h."Status" = 'Dissolved' AND x."Deleted_at" IS NULL;
UPDATE "budget" x SET "Delete_at" = h."Delete_at", "Update_at" = NOW(), "Server_update_at" = NOW()
  FROM "household" h WHERE h."Idhousehold" = x."Idhousehold" AND h."Status" = 'Dissolved' AND x."Delete_at" IS NULL;
UPDATE "goal" x SET "Delete_at" = h."Delete_at", "Update_at" = NOW(), "Server_update_at" = NOW()
  FROM "household" h WHERE h."Idhousehold" = x."Idhousehold" AND h."Status" = 'Dissolved' AND x."Delete_at" IS NULL;
UPDATE "category" x SET "Delete_at" = h."Delete_at", "Update_at" = NOW(), "Server_update_at" = NOW()
  FROM "household" h WHERE h."Idhousehold" = x."Idhousehold" AND h."Status" = 'Dissolved' AND x."Delete_at" IS NULL;
COMMIT;
```

**Xong khi:** bước 1 trả 0 ở cả năm dòng trên mọi CSDL dùng thật.

## 60.3 (THẤP, tuỳ chọn) — Ba ca test nói nhiều hơn điều chúng chứng minh

Ca 2 đã sửa ở PR #176. Bằng chứng đường thật của gia đình là `verify:household`, không phải các ca này. Chỉ cần làm khi có thời gian.

| Ca trong `tests/unit/household_and_aiops_v2.test.js` | Vì sao chưa canh được | Cách sửa |
|---|---|---|
| Ca 3 (58.1) | `operation: 'create'`, khoá `to_idwallet`: app không gửi | Chép payload từ `src/Client-app/test/core/sync/sync_payload_contract_test.dart` |
| Ca 4 (57.4 + 59.1) | Giả `enforceHouseholdPermission`, không kiểm *không ghi* | Giả ở tầng Prisma, kiểm số lần ghi |
| Ca 5 (58.5) | Đi qua `isAccountQuarantined`, 0 chỗ gọi ngoài test | Gọi `sweepExpiredQuarantines`, `_reconcileAutoLocks` |

---

## 62 — Thanh toán PayOS (đo 2026-11-01 phiên 30)

**Cách đo.** Client chạy backend `13fddd09` trên `PersonFinance` với khoá PayOS trong `.env`, tạo đơn thật qua PayOS rồi gửi webhook tự ký bằng `createSignatureFromObj` của SDK. **Không có giao dịch ngân hàng nào.** Đủ tiền, thừa, thiếu, trả muộn, phát lại, sai chữ ký và *Đồng ý* / *Từ chối* / hoàn tiền của admin đều chạy đúng; các mục dưới là phần còn lại.

### Bản vá cho 62.1–62.5

Bản vá 6 tệp, +231 / −142 dòng (3 tệp mã trong `modules/payment/`, 3 tệp test). Không cần migration, không đổi hợp đồng API, client không phải sửa gì. Client đã thử trên bản sao của `13fddd09`, không đụng `src/Backend`: kịch bản **4 / 14 trước khi vá, 14 / 14 sau khi vá**; 78 ca unit thanh toán đều pass (không `.env`, trên CSDL cục bộ); ca 62.3 còn chạy thật trên `PersonFinance`.

```bash
# Từ gốc repo
git apply docs/superpowers/backend/CAN-LAM/KIEM-THU/ban_sua_62.patch

cd src/Backend
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_62.js . kq_62.txt   # dòng cuối: 14 đạt / 14 ca
# Đặt DATABASE_URL + DIRECT_URL trỏ CSDL dev của bạn trước lệnh dưới, đừng để nó đọc `.env` trỏ CSDL dùng chung
node --test --test-force-exit tests/unit/payment.*.test.js tests/unit/admin.payment.test.js tests/unit/payos*.test.js
```

⚠️ **Bộ test này không hoàn toàn cô lập.** `admin.payment.test.js` ca 4, 11, 12 chạm CSDL mà `DATABASE_URL` trỏ tới: `autoExpirePendingOrders` là một `UPDATE` thật, chuyển đơn `PENDING` quá hạn sang `EXPIRED`. Trước bản vá, ca 7 và 9 còn gọi PayOS thật khi có khoá (mỗi lượt là một liên kết trên kênh); bản vá đã giả hai ca ấy. Prisma client còn tự nạp `.env` theo đường dẫn lúc `generate`, nên `node_modules` nối junction cũng kéo theo `.env` của thư mục gốc.

Kịch bản không cần CSDL, không gọi PayOS: `core/socket`, repository và PayOS bị thay bằng bản giả trong tiến trình. Làm xong bản vá vẫn còn ba việc tay: **Admin-web + tài liệu** (cuối 62.1) và **62.6**.

`git apply` báo lỗi (mã đã đổi) thì sửa tay theo từng mục dưới đây.

**Kiểm tay trên CSDL dev (tuỳ chọn, không mất tiền).** Chỉ dùng đơn của tài khoản thử, tạo đơn bằng app hoặc `POST /api/payment/create-order`. Không quét QR để chuyển: đó là tài khoản thật.

```bash
cd src/Backend
K=../../docs/superpowers/backend/CAN-LAM/KIEM-THU/webhook_tu_ky.js
node $K <orderCode> 49000 sai    # 400, đơn không đổi
node $K <orderCode> 70000        # đơn mới: WAITING_CONFIRMATION
node $K <orderCode> 20000        # đơn mới: REFUND_PENDING
node $K <orderCode> 49000        # đơn mới: PAID; kiểm cả account.Type lẫn premium_expires_at
```

### 62.1 (CAO) — Tài khoản cá nhân ghi cứng làm dự phòng

`modules/payment/payment.service.js:29-32`:

```js
const transferContent = payosResponse.description || `CS... ${recognitionCode}`;
const bin = payosResponse.bin || '970422';
const accountNumber = payosResponse.accountNumber || '2512070399999';
const accountName = payosResponse.accountName || 'NGUYEN PHU BAO';
```

Đơn đo hôm nay có `bin` do PayOS trả nên nhánh này chưa chạy. Khi PayOS không trả các trường ấy (đổi kênh, đổi phiên bản API), người dùng vẫn nhận QR vào một tài khoản MB cố định, đơn không gắn với kênh PayOS nào và webhook không bao giờ tới: tiền đã đi mà gói không mở. `getOrCreatePayosQr` còn nặng hơn: PayOS lỗi là `catch` rồi vẫn trả QR tài khoản ấy, kèm `checkoutUrl` tự dựng không mở được.

**Sửa, ba chỗ:**

1. `payos.client.js`, thêm hai hàm rồi `exports`:

   ```js
   function thongTinNhanTien(payosResponse) {
     const { bin, accountNumber, accountName, description } = payosResponse || {};
     if (!bin || !accountNumber) {
       const error = new Error('Cổng thanh toán không trả về tài khoản nhận tiền, vui lòng thử lại sau');
       error.statusCode = 502;
       throw error;
     }
     return { bin, accountNumber, accountName: accountName || '', description };
   }

   function thongTinTuQrUrl(qrUrl) {
     const khop = /\/image\/(\d+)-(\d+)-[^/?]+(?:\?(.*))?$/.exec(qrUrl || '');
     if (!khop) return null;
     return {
       bin: khop[1],
       accountNumber: khop[2],
       accountName: new URLSearchParams(khop[3] || '').get('accountName') || '',
     };
   }
   ```

2. `payment.service.js`, `createPremiumOrder`: thay bốn dòng trên bằng

   ```js
   const { bin, accountNumber, accountName, description } = payosClient.thongTinNhanTien(payosResponse);
   const transferContent = description || recognitionCode;
   ```

   Khối `return` dùng thẳng `bin`, `accountNumber`, `accountName || null`. `simulateWebhook` (dòng 572) đổi số tài khoản giả thành `'0000000000'`.

3. `payment.repository.js`:
   - `getOrderDetailForAdmin` (dòng 803–814): bỏ hằng và bỏ phép dựng lại `qr_url`; `bank_info` đọc từ QR đã lưu qua `thongTinTuQrUrl`, không đọc được thì `null`.
   - `getOrCreatePayosQr` (dòng 832–860): bỏ mọi giá trị khởi tạo, PayOS lỗi thì ném 502, phản hồi đi qua `thongTinNhanTien`.
   - `bankName` không ghi cứng: thêm `tenNganHang(bin)` trả `'MB Bank (Quân Đội)'` cho `970422`, còn lại `null`.

⚠️ **Đổi hành vi có chủ ý:** PayOS hỏng thì admin tạo đơn mẫu hoặc lấy QR nhận lỗi 502 thay vì QR đoán. Ca 9 `admin.payment.test.js` đang ghim hành vi cũ, bản vá viết lại ca ấy; mock `paymentRequests.create` ở `payment.service.test.js` và `payment.reconciliation.test.js` thêm `bin`, `accountNumber`.

**Ngoài bản vá, sửa tay:**

| Tệp | Sửa |
|---|---|
| `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx:381-383` | Bỏ giá trị `|| 'MB Bank…'`, `|| '2512070399999'`, `|| 'NGUYEN PHU BAO'`; thiếu thì để trống |
| `src/Admin-web/src/locales/vi.js:1575`, `en.js:1575` | `warningDesc` bỏ số tài khoản và tên |
| `docs/Payment/PAYMENT_WORKFLOW_SPEC.md:29` | Sơ đồ ghi tài khoản nhận là tài khoản của kênh PayOS |
| `docs/Payment/CLIENT_INTEGRATION_GUIDE.md:126-128, 240, 245` | Thay ví dụ bằng số giả |
| `docs/Payment/PAYOS_SETUP_GUIDE.md:62, 213` | Sửa theo kết quả 62.6: chưa ai đo được chế độ *Sandbox* mà tệp mô tả |

**Xong khi:**

```bash
grep -rn "2512070399999\|NGUYEN PHU BAO" src/Backend/modules src/Backend/api src/Admin-web/src   # 0 dòng
```

và ba ca `62.1` của kịch bản đạt: PayOS trả thiếu `bin` thì lỗi 502 và không lưu đơn.

### 62.2 (VỪA) — Đường JIT bỏ qua số tiền

`syncOrderWithPayOS` (dòng 595–782) chỉ xử lý `CANCELLED`, `EXPIRED`, `PAID`, trong khi SDK còn khai `UNDERPAID`, `PROCESSING`, `FAILED` (`@payos/node/lib/resources/v2/payment-requests/payment-requests.d.ts:51`). Nhánh `PAID` gọi thẳng `activatePremiumSubscription`, không so `amountPaid` với `order.amount`, và không gọi `invalidateAccountCache`.

Khi webhook không tới (kịch bản chạy trên mã gốc xác nhận cả bốn):

| PayOS trả | Hôm nay | Phải là |
|---|---|---|
| `UNDERPAID`, đã trả 20.000 | Giữ `PENDING`, tới hạn thì `EXPIRED`: mất tiền, app báo *"Đơn đã hết hạn"* | `REFUND_PENDING` |
| `PAID`, đã trả 70.000 | `PAID` ngay, bỏ bước xác nhận | `WAITING_CONFIRMATION` |
| `EXPIRED`, đã trả 20.000 | `EXPIRED` | `REFUND_PENDING` |
| `PROCESSING`, đã quá hạn cục bộ | `EXPIRED` | Giữ `PENDING` |

⚠️ Chưa có giao dịch thật nên PayOS chưa từng trả các giá trị này cho client: bảng trên chạy bằng PayOS giả theo kiểu của SDK. Client mới đo được nhánh `CANCELLED` và `EXPIRED` không có tiền trên PayOS thật (đạt).

**Sửa, cùng một đường cho webhook và JIT:**

1. Cắt `handlePayOSWebhook` ngay trước dòng `// PHÂN LUỒNG 6.1 VS 6.2`, phần thân giữ nguyên chỗ:

   ```js
     return xuLyTienVaoDon(order, { orderCode, receivedAmount, txData, txTime, description });
   }

   async function xuLyTienVaoDon(order, { orderCode, receivedAmount, txData, txTime, description }) {
     const now = new Date();
     const expectedAmount = Number(order.amount);
     // phần PHÂN LUỒNG 6.1 VS 6.2 như cũ
   ```

   Ở nhánh khớp tiền, đọc tài khoản bằng `order.account || await paymentRepository.findAccountSubscription(order.idaccount)`, vì `syncOrderWithPayOS` có thể được gọi với đơn không kèm `account`.

2. Trong `syncOrderWithPayOS`, đặt khối này **đầu tiên** trong `if (payosInfo)`, rồi xoá khối `if (payosInfo.status === 'PAID')` cũ:

   ```js
   const daTra = Number(payosInfo.amountPaid || 0);
   if (payosInfo.status === 'PAID' || daTra > 0) {
     const receivedAmount = daTra > 0 ? daTra : Number(order.amount);
     const latestTx = Array.isArray(payosInfo.transactions) && payosInfo.transactions.length > 0
       ? payosInfo.transactions[payosInfo.transactions.length - 1]
       : null;
     const txTime = docGioPayOS(latestTx?.transactionDateTime, new Date());
     const ketQua = await xuLyTienVaoDon(order, {
       orderCode,
       receivedAmount,
       txTime,
       description: latestTx?.description,
       txData: {
         id: crypto.randomUUID(),
         orderId: order.id,
         idaccount: order.idaccount,
         amount: receivedAmount,
         payosTransactionId: latestTx?.reference || latestTx?.transactionId || `JIT_${order.id}_${Date.now()}`,
         bankCode: latestTx?.counterAccountBankName || 'PAYOS_JIT',
         transactionTime: txTime,
         signatureVerified: true,
         rawWebhookHash: 'JIT_SYNC_DIRECT_API',
       },
     });
     order.status = ketQua.action;
     order.amount_received = receivedAmount;
     order.qr_url = null;
     order.checkout_url = null;
     order.bank_info = null;
     if (ketQua.action === 'PAID') order.paid_at = txTime;
     return order;
   }

   if (payosInfo.status === 'PROCESSING') {
     return order;
   }
   ```

Đi chung đường nên JIT cũng được `invalidateAccountCache`, `payment.success` của event bus và các socket như webhook. Sự kiện admin khi JIT kích hoạt đổi từ `payment.order_paid` sang `payment.success`: nếu Admin-web chỉ nghe tên cũ thì cần sửa theo.

**Giới hạn, không sửa ở đây:** `autoExpirePendingOrders` chuyển đơn quá hạn sang `EXPIRED` mà không hỏi PayOS, và JIT chỉ chạy với đơn `PENDING`. Webhook không tới, app lại không hỏi trong lúc đơn còn hạn thì đơn có tiền vẫn thành `EXPIRED`, tới khi webhook tới lại. Vì vậy URL webhook đúng (62.6) vẫn là đường chính.

**Xong khi:** sáu ca `62.2` của kịch bản đạt.

### 62.3 (VỪA) — Webhook hợp lệ tới đơn đã huỷ

Đo trên đơn `5166888392633` (`CANCELLED` trên cả PayOS thật lẫn CSDL), webhook đúng chữ ký 49.000 đ: trả 200 *"Đơn hàng đã được xử lý…"*, thêm một dòng `payment_transaction`, đơn vẫn `CANCELLED`, không socket, không báo admin. Dòng 161 gộp `CANCELLED` với các trạng thái đã xử lý, nên nếu tiền vào thật thì không ai biết. Chưa biết PayOS có còn gửi webhook sau khi huỷ không (62.6).

**Sửa:** thêm khối này ngay trước comment `// 3. Xử lý Idempotency`:

```js
if (order.status === 'CANCELLED' && !order.is_template) {
  await paymentRepository.recordTransaction(txData);
  await paymentRepository.updateOrderPaymentStatus({
    orderId: order.id,
    status: 'REFUND_PENDING',
    amountReceived: receivedAmount,
    refundReason: 'Nhận tiền sau khi đơn đã huỷ',
    transferContent: description || order.transfer_content,
  });
  try {
    const { emitToAccount, getIO } = require('../../core/socket');
    emitToAccount(order.idaccount, 'payment.order_cancelled', {
      orderId: order.id,
      orderCode: Number(order.order_code || orderCode),
      status: 'REFUND_PENDING',
      amountReceived: receivedAmount,
    });
    const io = getIO();
    if (io) {
      io.to('admin_room').emit('payment.refund_pending', {
        orderId: order.id,
        orderCode: Number(order.order_code || orderCode),
        amount: receivedAmount,
        reason: 'Nhận tiền sau khi đơn đã huỷ',
      });
    }
  } catch (_) {}
  return { success: true, action: 'REFUND_PENDING', message: 'Đơn đã huỷ nhận được tiền, đã chuyển trạng thái chờ hoàn trả' };
}
```

Chọn hoàn tiền chứ không kích hoạt vì người dùng đã huỷ đơn; PO muốn khác thì đổi ở khối này. `payment.order_cancelled` là tên client đã nghe, nên màn đang mở tự nạp lại; đơn bằng giá gói hiện *"Đang chờ hoàn tiền"*, client không phải sửa.

**Xong khi:** hai ca `62.3` của kịch bản đạt; đơn thử thành `REFUND_PENDING`, nằm trong hàng hoàn tiền của Admin-web, phát lại không đổi thêm gì.

### 62.4 (THẤP) — Hai dòng giao dịch cho một lần chuyển thừa

Đo trên đơn `5163211699944` (chuyển 70.000 đ rồi *Đồng ý*): `payment_transaction` có một dòng 70.000 từ webhook và `OVERPAID-CONFIRMED-5163211699944` 70.000 từ `confirmUpgrade` (dòng 429–437). Cộng cột `amount` để đối soát ra 140.000 đ. `/admin/payments/stats` không dính vì cộng theo giá đơn.

**Sửa:** bỏ hẳn tham số `transactionData` ở lời gọi `activatePremiumSubscription` trong `confirmUpgrade`. Hàm ấy đã chịu được thiếu tham số (`amount_received: transactionData ? … : undefined`), nên `amount_received` giữ nguyên 70.000.

**Dữ liệu cũ:** đếm dòng `OVERPAID-CONFIRMED-*` trên CSDL thật, ghi số vào bảng trả lời, đừng xoá cứng.

**Xong khi:** ca `62.4` của kịch bản đạt; đơn thừa có đúng một dòng `payment_transaction`.

### 62.5 (THẤP) — `paid_at` phụ thuộc múi giờ máy chủ

`new Date(transactionDateTime)` ở dòng 137 đọc chuỗi không múi giờ theo giờ của tiến trình Node. Kịch bản đo với `TZ=UTC`: `2026-11-01 13:57:17` ra `13:57:17Z`, muộn 7 giờ so với `06:57:17Z`. Chuỗi không hợp lệ thì `Invalid Date` đi thẳng vào CSDL. Chưa đo múi giờ của Render.

**Sửa:** thêm hàm này, dùng ở dòng 137 (`docGioPayOS(transactionDateTime, new Date())`) và ở JIT:

```js
function docGioPayOS(giaTri, macDinh) {
  if (!giaTri) return macDinh;
  const chuoi = String(giaTri).trim();
  const khongMuiGio = /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d+)?$/.test(chuoi);
  const gio = new Date(khongMuiGio ? `${chuoi.replace(' ', 'T')}+07:00` : chuoi);
  return Number.isNaN(gio.getTime()) ? macDinh : gio;
}
```

**Xong khi:** hai ca `62.5` của kịch bản đạt (kịch bản tự đổi `TZ`).

### 62.6 (VỪA) — Xác nhận kênh PayOS và webhook

Không phải sửa mã. `.env` dev hiện gọi được PayOS và PayOS trả tài khoản nhận MB `2512070399999`, tên NGUYEN PHU BAO, không có dấu hiệu là kênh thử. Client đang chặn ở đây để đóng G94 bằng một giao dịch thật. Trả lời trong bảng cuối tệp:

1. Tài khoản `2512070399999` có phải của bạn và được dùng để thử không? Mỗi lần chuyển thử là tiền thật vào đó; client đã tạo 14 liên kết thử ngày 2026-11-01, không ai chuyển tiền, sẽ thấy trong trang quản trị kênh.
2. Kênh của khoá trong `.env` là kênh thử hay kênh thật? `PAYOS_SETUP_GUIDE.md:62, 213` nói có chế độ *Sandbox* với nút giả lập; nếu có thật thì tạo kênh thử và gửi khoá cho môi trường dev.
3. Kênh đang đăng ký webhook URL nào? Ghi URL (`scripts/confirm_payos_webhook.js` đăng ký, không đọc được), và cho biết Render có dùng cùng kênh không. Đừng đổi URL khi Render đang nhận đơn thật.
4. PayOS có còn gửi webhook cho liên kết đã huỷ không? Hỏi PayOS hoặc đo trên kênh thử (62.3).

**Xong khi:** bốn câu có trả lời.

## 63 — Cột `Idfund_pair` và phạm vi danh mục của khoản nhà (gia đình đợt 1A, 2026-11-01)

Nhánh `TranQuangDat-backend` có đợt mã gia đình 1A (dải `2c18bf77..9cfca7bd`). Phần backend của đợt ấy nhỏ: cột `transaction."Idfund_pair"`, ánh xạ trong `sync.repository.js`, ba chốt trong `sync.service.js` (mã cặp trên `Transfer`, người sửa khoản có mã cặp, `laXoa = operation === 'delete'`), kịch bản `KIEM-THU/chay_kiem_gia_dinh_2.js` (21 / 21; hồi quy `chay_kiem.js` 50 / 50, trên CSDL `flowmoney_kiem_thu`). Hợp đồng đồng bộ: `docs/superpowers/sync/SYNC_DOCUMENTATION.md` bảng 4.2, `docs/Family/04_HOP_DONG_PHAN_1_NHU_MA.md` mục 3.

### 63.1 (CAO) — Áp `database/45_add_transaction_fund_pair.sql` lên Supabase TRƯỚC khi gộp / triển khai nhánh

**Vì sao.** `src/Backend/prisma/schema.prisma` đã khai `idfund_pair ... @map("Idfund_pair")` ở model `transaction`. `npm install` tự chạy `prisma generate` (`postinstall`), nên client sinh ra chọn cột `Idfund_pair` trong **mọi** truy vấn bảng `transaction`. CSDL chưa có cột thì mọi truy vấn ấy ném `P2022` (kiểu lỗi đã gặp với `account.premium_expires_at`, migration 19, 2026-10-06 — đăng nhập hỏng); client chưa chạy lại ca này với `Idfund_pair`. Client đã áp tệp lên `PersonFinance` cục bộ ngày 2026-11-01 theo phép đích danh của người dùng, sau khi sao lưu (`PersonFinance-truoc-45-2026-11-01.dump`); **chưa áp Supabase**, và client chưa biết Render dùng CSDL nào.

**Làm.** Áp tệp theo quy ước `database/N_*.sql` của repo (tệp luỹ đẳng: `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, không xoá gì). Thứ tự: **áp 45 → rồi mới gộp `main` / triển khai**.

**Kiểm lại (chỉ đọc), phải ra đúng một dòng mỗi câu:**

```sql
SELECT column_name, data_type, character_maximum_length, is_nullable
  FROM information_schema.columns WHERE table_name = 'transaction' AND column_name = 'Idfund_pair';
-- mong đợi: Idfund_pair | character varying | 36 | YES
SELECT indexname FROM pg_indexes WHERE tablename = 'transaction' AND indexname = 'idx_transaction_fund_pair';
-- mong đợi: idx_transaction_fund_pair
```

**Xong khi:** hai câu trên ra đúng trên mọi CSDL dùng thật, rồi một lượt `/sync/pull` của tài khoản thử trả 200.

### 63.2 (VỪA, cần quyết định) — Phạm vi danh mục của khoản thuộc nhà

**Điều client đọc được từ mã (suy từ mã, **chưa đo** trên server chạy).** `validateEntityScope` (`sync.service.js`, hàm gần dòng 210) kiểm ví, ví đích của khoản chuyển và mục tiêu cùng phạm vi với khoản (`HOUSEHOLD_SCOPE_MISMATCH`), nhưng **không kiểm danh mục**. Khoản mang `idhousehold` của nhà mà trỏ danh mục **riêng** của một người (hoặc danh mục của nhà khác) hiện được server nhận. Bảng `docs/Family/01_NEN_MONG.md` mục 3 cho thành viên thêm / sửa danh mục của nhà, nhưng chưa nói khoản của nhà bắt buộc dùng danh mục của nhà hay được dùng danh mục riêng.

**Vì sao cần chốt.** Client 1A: danh mục của nhà tách khỏi danh mục cá nhân (`getCuaNha`), khoản của nhà sẽ chọn danh mục qua một màn riêng ở 1B (chưa làm). Nếu server cho khoản nhà trỏ danh mục riêng, máy thành viên khác kéo khoản đó về mà **không có danh mục** (danh mục riêng không về máy họ) — khoản hiện không tên danh mục, thống kê nhà gom vào "chưa phân loại".

**Đề nghị (backend chọn một, báo lại):** (a) thêm vào `validateEntityScope` một nhánh cho `payload.idcategory` / `categoryId`: danh mục phải là hàng của đúng nhà đó hoặc danh mục mặc định, lệch thì `HOUSEHOLD_SCOPE_MISMATCH` (mã đã có trong `_permanentCodes` của client, không cần thêm mã); hoặc (b) giữ như hiện tại và ghi rõ vào `01` mục 3 rằng khoản nhà được dùng danh mục riêng (client sẽ thôi cấm ở 1B). Client nghiêng về (a). **Trước khi sửa** hãy chạy một ca thật (Thành viên đẩy khoản có `idhousehold` mà `idcategory` là danh mục riêng) để biết server trả gì — client chưa chạy ca ấy.

**Cập nhật 2026-11-02 (client làm (a) trên nhánh dự phòng `TranQuangDat-backend`, commit `6684cc6c`; phần gộp sang backend chính vẫn là việc của bạn).** Nhánh này thêm vào `validateEntityScope` đúng nhánh `payload.idcategory` / `categoryId` / `idCategory`: danh mục tìm thấy mà `Idhousehold` khác phạm vi đích (`Number(catHh || 0) !== Number(targetHhId || 0)`) ⇒ `HOUSEHOLD_SCOPE_MISMATCH`. ⚠️ Khác (a) ở một chỗ: **không có ngoại lệ "danh mục mặc định"** — khuôn mặc định có `Idhousehold` trống nên khoản của nhà trỏ thẳng khuôn bị từ chối, và đúng như vậy với client 1B (bản sao của nhà do server tạo, client chọn từ cây của nhà). Khối này chạy cho mọi thao tác đi qua `validateEntityScope` (giao dịch, và theo mã cả ngân sách, hoá đơn); câu lỗi nói *"giao dịch và danh mục"*. Kịch bản `KIEM-THU/chay_kiem_gia_dinh_2.js` có thêm ca (24 / 24 trên `flowmoney_kiem_thu`, hồi quy `chay_kiem.js` 50 / 50, đo trong đợt 1B). **Còn thiếu / hỏng, ghi ra để bạn quyết:** (1) hàng nhà **cũ** trỏ danh mục riêng cũng không **xoá** được vì `validateEntityScope` chạy trước nhánh xoá — chưa có hàng thật nào, client đọc log `HOUSEHOLD_SCOPE_MISMATCH` ở buổi đo; có thì xét cho xoá bỏ qua kiểm; (2) kịch bản chưa có ca ngân sách nhà trỏ danh mục riêng và khoản nhà trỏ khuôn mặc định. **Xong khi:** nhánh này (hoặc bản tương đương) đã vào backend chính, hai ca (1) (2) có kết luận.

---

## 64 — `formerMembers` có thể chứa người đang ở nhà hoặc một người nhiều lần (gia đình đợt 1B, 2026-11-02)

### 64.1 (THẤP, client đã chịu được) — `addMember` luôn tạo hàng mới, không khoá duy nhất theo (nhà, tài khoản)

**Đo gì (CSDL `PersonFinance`, 2026-11-02, phiên chính đo khi soát đợt 1B).** Nhà 3 có **3 hàng** `household_member` của tài khoản 30 (vào, rời, vào lại khi thử). Theo mã dưới đây, `GET /api/households/me` trả mọi hàng đã rời của tài khoản ấy trong `formerMembers`, kể cả khi họ đang ở lại (có hàng sống trong `members`) — client chưa chụp thân phản hồi, nên số hàng sống và số lần xuất hiện cụ thể hãy lấy từ câu kiểm. Câu kiểm:

```sql
SELECT "Idhousehold", "Idaccount", count(*) AS so_hang,
       count(*) FILTER (WHERE "Left_at" IS NULL) AS dang_o
  FROM "household_member" GROUP BY 1, 2 HAVING count(*) > 1 ORDER BY so_hang DESC;
-- hôm nay: có dòng (3, 30, 3, <0 hoặc 1>) — 3 hàng của tài khoản 30 ở nhà 3
```

**Chỗ mã.**
- `src/Backend/modules/household/household.repository.js:17` — `addMember` là `tx.household_member.create(...)`, luôn tạo hàng mới. Hai nơi gọi: tạo nhà (`household.service.js:90`) và nhận lời mời (`household.service.js:410`).
- Chỉ có chỉ mục duy nhất `uq_household_member_active_account` (`database/40_create_household_foundation.sql:36`): **một hàng sống mỗi tài khoản** (`WHERE "Left_at" IS NULL`). Không có ràng buộc theo (nhà, tài khoản) cho hàng đã rời; mỗi lần rời đặt `Left_at` trên hàng cũ rồi lần vào kế tạo hàng mới.
- `findFormerMembersByHousehold` (`household.repository.js:114`) trả **mọi** hàng `Left_at IS NOT NULL`, nên một người vào lại vẫn nằm ở `formerMembers`, và rời hai lần nằm hai lần (`household.service.js:182-187` ánh xạ từng hàng).

**Vì sao quan trọng.** Tên người đã rời (kèm *"(đã rời)"*) ở bảng góp và dòng hoạt động đọc từ `formerMembers`; đúng ý `01` mục 4 là danh sách **người đã rời**. Người đang ở mà vẫn có trong danh sách ấy, hoặc xuất hiện hai lần, làm bộ lọc theo người ở Hoạt động trùng khoá (client đã gặp `Duplicate keys found: Key("chon-25")`) và gắn nhầm *"(đã rời)"* cho người đang ở.

**Client đã làm (không cần backend để chạy đúng).** `nhaCuaToiTuJson` bỏ id đang ở và khử trùng theo id khi đọc `/me` (commit `658edf45`; ca `nha_cua_toi_test`). Phần backend là để trả đúng ngay từ nguồn.

**Đề nghị.** Chọn một, báo lại: (a) `findFormerMembersByHousehold` loại tài khoản đang có hàng sống ở nhà ấy và lấy một hàng mỗi tài khoản (hàng có `Left_at` mới nhất) — sửa ở đọc, không đụng dữ liệu; hoặc (b) `addMember` tái dùng hàng cũ khi cùng (nhà, tài khoản) (đặt lại `Left_at = NULL`, `Joined_at` mới) — sửa ở ghi, đổi nghĩa `Joined_at`, cần thêm chỉ mục duy nhất theo (nhà, tài khoản) và dọn hàng trùng sẵn có. Client nghiêng về (a) (nhỏ, không migration). Nếu chọn (b) thì **xin phép đích danh** trước khi áp migration.

**Kiểm lại.** Sau khi sửa, `GET /me` của nhà 3 không còn tài khoản 30 trong `formerMembers` khi đang ở, và mỗi tài khoản đã rời xuất hiện đúng một lần; `npm run verify:household` vẫn 50 / 50; thêm một ca vào `KIEM-THU/chay_kiem_gia_dinh_2.js` (rời, vào lại, rời lần hai, kiểm `formerMembers`).

**Xong khi:** câu SQL trên và `GET /me` cho kết quả như mô tả, ca kịch bản đạt.

---

## Giữ nguyên khi sửa backend

Các kịch bản ở `KIEM-THU/` đang đạt trọn và client chạy lại sau mỗi lần gộp. Chạy trước khi báo xong, hai kịch bản đầu trên CSDL riêng tên `flowmoney_kiem_thu`:

```bash
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma   # dòng Datasource phải ghi đúng tên CSDL thử, sai thì DỪNG

node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq_pr174.txt   # 24 đạt / 24 ca
npm run verify:household -- . kq_nha.txt                                                 # 50 đạt / 50 ca
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_61.js . kq_61.txt         # 6 đạt / 6 ca, sau khi áp bản vá
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_62.js . kq_62.txt         # 14 đạt / 14 ca, sau khi áp bản vá
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_gia_dinh_2.js . kq_gd2.txt  # 21 đạt / 21 ca (mã cặp góp / rút, nhánh gia đình 1A; cần cột `Idfund_pair`)
```

---

## Trả lời (backend ghi vào đây)

| Mã | Đã làm | Kiểm lại ra gì |
|---|---|---|
| 52.4 | | *(vân tay trong log Render, mã trả về của `/sync/pull` trên Render)* |
| 61.1, 61.2, 61.3, 61.4 | | *(dòng cuối `kq_61.txt`; sửa khác bản vá thì nói khác ở đâu)* |
| 61.5 | | *(kết quả bước 1 trên từng CSDL, trước và sau khi dọn)* |
| 62.1, 62.2, 62.3, 62.4, 62.5 | | *(dòng cuối `kq_62.txt`, kết quả `grep` của 62.1; sửa khác bản vá thì nói khác ở đâu)* |
| 62.1 phần tay | | *(Admin-web, ba tài liệu)* |
| 62.6 | | *(bốn câu trả lời)* |
| 63.1 | | *(hai câu kiểm: cột và chỉ mục, trên từng CSDL dùng thật)* |
| 63.2 | | *(chọn (a) hay (b); kết quả ca thật; kịch bản nếu thêm)* |
| 64.1 | | *(chọn (a) hay (b); câu SQL và `GET /me` sau khi sửa; ca kịch bản)* |
| 60.3 | | *(hoặc "chưa")* |
