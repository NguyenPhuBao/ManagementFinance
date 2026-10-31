# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này **chỉ có việc còn phải làm**, đo trên backend `8e3b4e48`. Việc xong thì client xoá khỏi tệp; lịch sử xem bằng git.
> Bước 1 và 2 chạy lệnh có sẵn, xong phần lớn danh sách. Bước 3 là **4 việc tay** vì chúng cần Render, khoá thật hoặc trí nhớ của người làm, cộng một việc tuỳ chọn.
> Đơn mới thêm vào tệp này, số kế tiếp **61**.

## Tổng quan

| Mã | Việc | Mức | Cách xong |
|---|---|---|---|
| 52.4 | Chưa so khoá mã hoá trên Render. Khác khoá thì kéo toàn bộ trả 500 | **CAO** | Tay |
| 60.4 | `recordTransaction` ném `ReferenceError` khi hai webhook đua nhau: thiếu `require` logger | VỪA | Bản vá |
| T1 | `Event-Notification-to-ClientApp.md` sai 11 / 20 hàng; socket `ocr.completed` phát số tài khoản đầy đủ | VỪA | Bản vá |
| T3 | `4_TRU_COT.md` sai 13 / 15 hàng; xoá nhầm `/export-report` | VỪA | Bản vá |
| 55.A3 | Chưa có ca test Premium không có hạn | VỪA | Bản vá |
| 52.3 | Chưa chạy kiểm mã hoá trên `PersonFinance` | VỪA | Tay |
| 52.5 | Chưa ghi đã di trú trên CSDL nào, khoá nào, lúc nào | VỪA | Tay |
| T6 | Mã thật mang nhánh chỉ để hợp bản giả; nhãn `[Tier 2]` trên ca giả | THẤP | Bản vá |
| 60.1 | Hai script `Test/` không chặn URL `*.supabase.co` | THẤP | Bản vá |
| 60.2 | `verify:household` ghi tệp kết quả vào cây mã, không bị ignore | THẤP | Bản vá |
| 60.3 | Bốn ca test mock trúng hàm cần chứng minh | THẤP | Tay (tuỳ chọn) |
| 48.1 | Chưa ghi ai / công cụ nào đã xoá ví test của tài khoản 18 | THẤP | Tay |

---

## Bước 1. Tạo CSDL riêng, đo mốc

⚠️ Đặt `DATABASE_URL` **trước** mọi lệnh `prisma`. Thiếu biến là rơi về `.env` = Supabase dùng chung. Không dùng `--force-reset`. Dòng `Datasource "db"` Prisma in ra phải ghi đúng tên CSDL thử, sai thì DỪNG.

Git Bash, từ gốc repo:

```bash
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma

# Phải ra "TỔNG: 10 đạt / 24 ca" (bản đối chiếu: KIEM-THU/ket_qua_pr174_ma_hien_tai_8e3b4e48.txt)
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq_truoc.txt
```

Kịch bản chỉ chạy trên CSDL tên `flowmoney_kiem_thu` ở máy này; không gửi thư, không phát socket, không gọi Gemini.

## Bước 2. Áp bản vá, đo lại

Bản vá 12 tệp, client đã thử trên một bản sao + CSDL tạm. Nó phủ **60.4, T1, T3, 55.A3, T6, 60.1, 60.2** và nhãn hai ca của 60.3. Không cần `npm install`, `prisma generate` hay migration mới.

```bash
cd ../.. && git apply --ignore-whitespace docs/superpowers/backend/CAN-LAM/KIEM-THU/ban_sua_pr174.patch && cd src/Backend

# Phải ra "TỔNG: 24 đạt / 24 ca"
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq_sau.txt

# Phải vẫn "TỔNG: 50 đạt / 50 ca"
npm run verify:household -- . kq_nha.txt

# Test đơn vị, trên một CSDL riêng MỚI
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu_unit"
export DIRECT_URL="$DATABASE_URL"
npx prisma db push --skip-generate --schema prisma/schema.prisma
NODE_ENV=test node --test --test-force-exit tests/unit/*.test.js
```

Số đo của client: **24 / 24**, **50 / 50**, test đơn vị **489 / 491**. Hai dòng hỏng là một ca: `data_encryption_group4_audit` ca 5 và bộ test cha của nó, cần khoá `.env` (client đo không có `.env`, máy bạn có thể xanh). Không xoá ca nào cho xanh. Mã đã đổi so với `8e3b4e48` mà không áp được thì sửa tay theo *Nội dung bản vá* dưới đây.

## Bước 3. Bốn việc tay

### 52.4 (CAO) — So khoá mã hoá trên Render

Vân tay máy dev đã có: `98e9e026`. Chưa có số nào của Render. 25 + 3 hàng trên Supabase mang khoá `.env`; Render khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng còn sống trả 500 (`sync.controller.js:67-73`).

So vân tay, không in khoá. Thêm tạm vào `index.js` sau khi nạp `.env`, deploy, đọc log Render, rồi gỡ:

```js
logger.info('DATA_KEY_FP', { fp: require('crypto').createHash('sha256').update(process.env.DATA_ENCRYPTION_KEY || '').digest('hex').slice(0, 8) });
```

**Xong khi:** vân tay Render = `98e9e026`, và `GET https://managementfinance.onrender.com/api/sync/pull` không `since` của một tài khoản có hàng đã di trú trả 200. Khác vân tay thì đừng đổi khoá trên Render khi chưa di trú dữ liệu: báo client và PO trước.

### 52.3 (VỪA) — Kiểm mã hoá trên `PersonFinance`

```bash
DATABASE_URL=<PersonFinance> DIRECT_URL=<PersonFinance> DATA_ENCRYPTION_KEY=<khoá dev mặc định của crypto.util.js> npm run db:verify-encryption
```

**Xong khi:** dán nguyên dòng tổng kết vào mục Trả lời. Câu chốt khoá đã có ở `docs/progress/Backend.md` và `.env.example`, không phải viết lại.

### 52.5 (VỪA) — Ghi lần di trú

Script và mã thoát đã đúng. **Xong khi:** mục Trả lời ghi `migrate_reencrypt_legacy_dev_data.js` đã chạy trên CSDL nào, khoá nào (vân tay, không ghi khoá), lúc nào.

### 48.1 (THẤP) — Ai đã xoá ví test của tài khoản 18

13 ví test đã xoá mềm, lần cuối `2026-10-26 03:58:21Z`. **Xong khi:** mục Trả lời ghi tên người + công cụ (`UPDATE` tay? Admin-web? script nào?). Không nhớ thì ghi *"không truy được"*: câu ấy cũng đóng việc.

### 60.3 (THẤP, tuỳ chọn) — Bốn ca test nói nhiều hơn điều chúng chứng minh

Bằng chứng đường thật của gia đình là `verify:household`, không phải các ca này. Chỉ cần làm khi có thời gian.

| Ca trong `tests/unit/household_and_aiops_v2.test.js` | Vì sao chưa canh được | Cách sửa |
|---|---|---|
| Ca 2 (57.2) | Gọi thật `findActiveMemberByAccount` với id cứng 104, có truy vấn CSDL theo `.env` | Giả hàm ấy |
| Ca 3 (58.1) | `operation: 'create'`, khoá `to_idwallet`: app không gửi | Chép payload từ `src/Client-app/test/core/sync/sync_payload_contract_test.dart` |
| Ca 4 (57.4 + 59.1) | Giả `enforceHouseholdPermission`, không kiểm *không ghi* | Giả ở tầng Prisma, kiểm số lần ghi |
| Ca 5 (58.5) | Đi qua `isAccountQuarantined`, 0 chỗ gọi ngoài test | Gọi `sweepExpiredQuarantines`, `_reconcileAutoLocks` |

## Bước 4. Commit và ghi Trả lời

Commit, push, rồi điền bảng cuối tệp. Chỉ ghi điều có trong diff; việc chưa làm thì ghi *"chưa"*.

---

## Nội dung bản vá (đối chiếu khi không áp được)

**60.4** — `modules/payment/payment.repository.js`: `logger` chỉ khai cục bộ ở `:576`, nên `:345, :354, :374, :380` ném `ReferenceError` khi webhook trùng hoặc đơn không có. Đã chạy xác nhận trên CSDL thật. Đường đơn đã xử lý (`payment.service.js:163-165`) nuốt lỗi bằng `catch (_) {}` nên không ai thấy; ba chỗ gọi không có `catch` (`:175, :218, :260`) thì webhook đua nhau sẽ lỗi thay vì trả 200.

```js
// đầu tệp, sau payosClient
const logger = require('../../core/logger');
// và xoá dòng `const logger = require('../../core/logger');` ở :576
```

Ca mới `2b` trong `tests/unit/payment.repository.test.js` đi đúng nhánh P2002.

**T1, mã** — `ocr.completed` phát `transfer_details`, `transaction_info` chứa số tài khoản đầy đủ (`ocr.service.js:146-147`), trong khi tài liệu dòng 67 ghi đã che. Client không đọc payload này nên không phải đổi app. DTO trả về chủ tài khoản giữ nguyên.

```js
// utils/masking.util.js, thêm và export
function maskAccountFields(obj, khoa) {
  if (!obj) return obj ?? null;
  const ra = { ...obj };
  for (const k of khoa) {
    if (ra[k]) ra[k] = maskAccountNumber(String(ra[k]));
  }
  return ra;
}

// modules/ai/features/ocr/ocr.service.js
transfer_details: maskAccountFields(classifiedResult.transfer_details, ['source_account', 'destination_account']),
transaction_info: maskAccountFields(classifiedResult.transaction_info, ['source_account', 'counterpart_account']),
```

**T1, tài liệu** — `docs/Admin-web/Event-Notification-to-ClientApp.md` (số dòng ở `8e3b4e48`):

| Dòng | Sửa thành |
|---|---|
| 42, 113, 453 | *8 tín hiệu* (bảng 3.2 có 8 hàng) |
| 60 | Bỏ *"Backoff đếm ngược"*: dòng nhắc bảo trì / phong toả + hẹn thử lại, làm mới gói khi bị tắt quyền |
| 67 | Che số tài khoản ở `transfer_details`, `transaction_info`: chỉ còn 4 số cuối |
| 94 | Trung tâm thông báo + khay hệ điều hành (luồng `tinHeThong`), không banner |
| 98, 283-284 | App không nghe `account.countdown`; số ngày từ `countdown` của `/auth/profile` |
| 99, 288 | `sync.completed` phát cho mọi máy của tài khoản, cả máy vừa đẩy |
| 102, 347-349 | `user.notification`: chưa dùng, server chưa phát, app không nghe |
| 103, 354 | `payment.success`: webhook tới `admin_room`, JIT sync tới tài khoản |
| 105, 383 | `payment.order_expired`: worker tới `admin_room`, JIT sync tới tài khoản; không popup |
| 117, 623, 640 | Bảo trì: dòng nhắc Trang chủ + toast + câu Đăng nhập, hẹn theo `Retry-After`, không đếm ngược trên màn |
| 118, 624, 641 | Quá tải: chỉ `/sync/push` hẹn lại, sàn 30 s, không hiện gì |
| 119, 498, 625 | 429: app không có nhánh riêng |
| 120 | Phong toả: dòng nhắc Trang chủ + toast + câu Đăng nhập + hẹn thử lại |
| 193-199 | `system.maintenance_changed`: app cố ý bỏ qua, biết bảo trì qua HTTP 503 |
| 265 | Nâng / hạ gói: không Toast, chỉ làm mới gói |
| 320-325 | Mẫu `ocr.duplicate` theo `notification.service.js:116-117, 129-135`: `title`, `message`, `type`, `data`, `createdAt` |
| Bảng 3.1 + ma trận | Thêm `household.changed`, `household.invited` |

**T3** — `docs/Functional-Mobile/4_TRU_COT.md`: app không đọc `scopes` / `scope_config` lẫn `downgrade_policy`, nên dưới mỗi `scope_config` chưa có hiệu lực thêm một dòng *"App thi hành: …"*:

| Dòng | App thi hành |
|---|---|
| 11 | Bỏ *"lộ trình tương lai"*: các loại ví ấy không có trong app |
| 74-76, 428 | `READ_ONLY` chưa có hiệu lực: thẻ khoá thay cả khối, dự báo tính tại chỗ, không lưu |
| 110-112, 556 | Không có `cache_token_days`; `offline_login` app không có |
| 203-204, 563 | Không đính ảnh vào giao dịch; Sổ xem mọi kỳ |
| 225-229, 565 | ML Kit trên máy, không đếm lượt |
| 236-237, 566 | Không trần số giao dịch mỗi lần gắn |
| 274-275, 569 | Không trần số từ khoá |
| 491, 586 | Seed thật VCB / MB / TCB / ACB, server lưu, không dùng. App: MB Bank, MoMo, ZaloPay, không theo gói |
| 518-519 | `countdown_minutes` server lưu, không dùng; đơn hết hạn sau 10 phút |
| 529-530, 589 | Không có tải hoá đơn; chỉ *Lưu mã QR* |
| 545-549, 590 | Giãn đồng bộ 2 s mọi gói, không sao lưu ảnh |
| 580 | FHS: app không có màn |
| 599 | Trả lại `/export-report`, kèm `/analytics/export`; `/ai-chat` khoá trong trang |

**55.A3** — tệp mới `tests/unit/premium_effective.test.js`: `isPremiumEffective` các biên, job hạ cấp quét cả hàng không có hạn.

**T6** — `payment.repository.js:415-444`: bỏ nhánh `typeof … === 'function'`, chỉ giữ `createMany({ skipDuplicates: true })`; bản giả ở `payment.repository.test.js` đổi sang `createMany`. `payos_group3_comprehensive_audit.test.js`: 7 nhãn `[Tier 2]` thành `[Unit: giả paymentRepository]`.

**60.1** — `Test/test_sync_new_schema.js`, `Test/test_can_lam_fixes.js`: `/supabase\.(com|co)/i`.

**60.2** — `scripts/verify_household_contract.js`: mặc định ghi `path.join(require('os').tmpdir(), 'kq_household_contract.txt')`.

**60.3, phần nhãn** — `household_group1_completion.test.js` ca 1, 2: bỏ `[Tier 2]`, ghi rõ *chỉ ghim tham số* / *giả `emitHouseholdChanged`*.

---

## Trả lời (backend ghi vào đây)

**`chay_kiem_pr174.js`:** … **`verify:household`:** … **Test đơn vị:** …

| Mã | Đã làm (tệp, commit) | Kiểm lại ra gì |
|---|---|---|
| 52.4 | | *(vân tay Render, `/sync/pull` 200)* |
| 52.3 | | *(dòng tổng kết)* |
| 52.5 | | *(CSDL, vân tay khoá, thời điểm)* |
| 48.1 | | |
| 60.3 | | *(hoặc "chưa")* |
