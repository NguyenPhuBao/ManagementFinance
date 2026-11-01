# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này **chỉ có việc còn phải làm**, đo trên backend `13fddd09` (PR #176) ngày 2026-11-01. Việc xong thì client xoá khỏi tệp; lịch sử xem bằng git.
> Đơn mới thêm vào tệp này, số kế tiếp **62**.

## Tổng quan

| Mã | Lỗi | Mức | Cách xong |
|---|---|---|---|
| 52.4 | Chưa so khoá mã hoá trên Render. Khác khoá thì kéo toàn bộ trả 500 | **CAO** | Tay, cần quyền Render |
| 61.2 | Gemini quá 60 giây: luồng chat treo, không có `done` | **CAO** | Bản vá |
| 61.3 | Người dùng bấm Dừng bị đếm là lỗi LLM, có thể đóng chatbot của mọi tài khoản | VỪA | Bản vá |
| 61.4 | Cửa sổ thời gian của cầu dao không bao giờ reset | THẤP | Bản vá |
| 61.1 | Lời mời email nhận địa chỉ có dấu | THẤP | Bản vá |
| 61.5 | Hàng còn sống trong nhà giải tán trước bản sửa 57.6 | THẤP | Chạy SQL, có thể không cần |
| 60.3 | Ba ca test nói nhiều hơn điều chúng chứng minh | THẤP | Tay, tuỳ chọn |

**Thứ tự đề xuất:** áp bản vá một lần cho 61.1–61.4, chạy kịch bản, rồi làm 52.4 và 61.5.

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
```

---

## Trả lời (backend ghi vào đây)

| Mã | Đã làm | Kiểm lại ra gì |
|---|---|---|
| 52.4 | | *(vân tay trong log Render, mã trả về của `/sync/pull` trên Render)* |
| 61.1, 61.2, 61.3, 61.4 | | *(dòng cuối `kq_61.txt`; sửa khác bản vá thì nói khác ở đâu)* |
| 61.5 | | *(kết quả bước 1 trên từng CSDL, trước và sau khi dọn)* |
| 60.3 | | *(hoặc "chưa")* |
