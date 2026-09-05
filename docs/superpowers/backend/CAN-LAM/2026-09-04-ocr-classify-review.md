# Rà soát mô-đun OCR & Classify vừa gộp vào `main`

**Ngày:** 2026-09-04 · **Sửa lại cùng ngày** sau một vòng thẩm định phản biện
**Phạm vi:** Backend (`core/socket.js`, `modules/ai/features/{ocr,classify,dedup}/`,
`prisma/schema.prisma`, `middleware/audit-log.middleware.js`) và `docs/progress/Client-app.md`
**Từ:** Frontend Team
**Cơ sở:** đọc mã tại `fcf7659` (gộp `origin/main` `dfda862`), cộng một vòng phản biện
độc lập từng phát hiện, cộng phép đo trực tiếp trên CSDL `PersonFinance`.
Chỉ **đọc**, không sửa dòng mã backend nào.

> ## ⚠️ Bản đầu tiên của tài liệu này đã sai ở một chỗ — đọc phần này trước
>
> Bản viết lúc 2026-09-04 sáng xếp **"va chạm `uq_transaction_external` liên tài
> khoản"** là việc ưu tiên cao nhất, mô tả nó như một vòng lặp đẩy vô hạn đang
> chờ nổ. **Điều đó không xảy ra được ở trạng thái mã hiện tại**, vì client
> không gửi `provider` lẫn `bank_tran_id` trong payload đẩy — backend luôn ghi
> `('Manual', NULL)`, mà PostgreSQL coi mỗi NULL là khác biệt.
>
> Đo trực tiếp trên CSDL `PersonFinance` ngày 2026-09-04 xác nhận:
>
> ```
> SELECT "Provider","Status",count(*) FROM "transaction" GROUP BY 1,2;
>   → Manual | Confirmed | 5        (chỉ đúng một tổ hợp)
> SELECT count(*) FROM "bank_account";                      → 0
> SELECT count(*) FROM "transaction" WHERE "Bank_tran_id" IS NOT NULL; → 0
> ```
>
> Việc đó **vẫn cần làm**, nhưng là **nợ thiết kế phải trả trước khi client nối
> luồng OCR**, không phải lỗi đang chảy máu. Nó đã bị hạ từ 🔴 xuống 🟡 và
> chuyển xuống mục 6.
>
> Đổi lại, vòng thẩm định tìm ra **một lỗ hổng đang gây hại ngay hôm nay** mà
> bản đầu bỏ sót hoàn toàn: **Socket.io không có xác thực và phát mọi thứ ra
> toàn bộ client** (mục 2). Nó thay chỗ ở đầu bảng.
>
> Bài học ghi lại cho lần sau: bản đầu đúng ở tầng **bằng chứng** nhưng thổi
> phồng ở tầng **hậu quả** — phần lớn kịch bản hỏng được viết bằng thì hiện tại
> đều cần một tiền đề chưa tồn tại, đó là **client chưa có một dòng mã OCR nào**.

---

| # | Việc | Ưu tiên | Trạng thái |
|---|---|---|---|
| **1** (mục 2) | **Socket.io không xác thực, và mọi sự kiện đều phát kèm một bản `io.emit` toàn cục** | 🔴 **Cao — đang rò dữ liệu HÔM NAY** | ⛔ Chưa |
| **2** (mục 3) | `classifyExtractedReceipt` truyền **sai kiểu tham số** cho `classifyBatch` → phân loại từng mặt hàng **không bao giờ chạy** | 🔴 Cao — một dòng sửa, đang làm hỏng âm thầm tính năng chính của F013 | ⛔ Chưa |
| **3** (mục 4) | **Thiếu `GEMINI_API_KEY`** — mọi request mang ảnh thật đều chết, và mã lỗi bị nuốt trên đường về | 🔴 Cao — chặn hẳn cả tính năng | ⛔ Chưa |
| **4** (mục 5) | **Dedup Quy tắc 3 bỏ quên ba điều kiện** → chặn nhầm 409 mọi giao dịch cùng số tiền trong ngày | 🟠 Trung bình cao | ⛔ Chưa |
| **5** (mục 6) | Bốn tham số `_mock*` nhận thẳng từ `req.body` trên endpoint thật | 🟠 Trung bình cao | ⛔ Chưa |
| **6** (mục 7) | `@@unique([provider, bank_tran_id])` **thiếu `Idaccount`** | 🟡 Trung bình — **chưa nổ được**, xem khung trên | ⛔ Chưa |
| **7** (mục 8) | Bốn chỗ nhỏ hơn: DTO ba hình dạng · chuẩn hoá `bank_tran_id` lệch · tên `'ORC'` vs `'OCR'` · `'Interrupted'` là mã chết | 🟡 Trung bình | ⛔ Chưa |
| **8** (mục 9) | Ba chỗ sai trong `docs/progress/Client-app.md` và `docs/AI/ORC.md` | 🟡 Trung bình — client sẽ làm theo | ⛔ Chưa |

Tám việc **độc lập**, làm riêng được. Chỉ việc 6 cần migration.

---

## 1. Tóm tắt một câu mỗi việc

**1.** Máy chủ Socket.io không kiểm token ở bất kỳ đâu, `join_account` cho vào
phòng theo con số client tự khai, và bốn hàm phát sự kiện đều bồi thêm một
`io.emit` gửi cho **mọi** socket đang kết nối.

**2.** `classifyBatch` khai báo nhận một **object** nhưng chỗ gọi truyền vào một
**mảng**, nên nó thoát ở dòng đầu và luôn trả mảng rỗng.

**3.** `GEMINI_API_KEY` không có trong `src/Backend/.env`, và khi
`vision.extractor` ném `CONFIG_MISSING` thì error handler làm rơi mất mã lỗi.

**4.** `findFuzzyTransfer` nhận `counterpartAccount` và `note` nhưng không dùng,
cũng không lọc `provider` — nên nó chặn nhầm.

**5.** `_mockExtraction`, `_mockUser`, `_mockWallets`, `_mockBankAccounts` đi
thẳng từ thân request vào logic nghiệp vụ, không có cờ môi trường nào chặn.

**6.** Mã chống trùng được ràng buộc duy nhất trên **toàn bảng** thay vì theo
từng tài khoản — chưa nổ được vì client chưa gửi hai cột đó.

**7.** Bốn chỗ lệch nhỏ hơn, mỗi chỗ vài dòng.

**8.** Tài liệu bàn giao hướng dẫn client làm những việc mà mã hiện tại không
hỗ trợ, và mô tả sai một hành vi của chính backend.

---

## 2. Việc 1 — Socket.io không xác thực, mọi sự kiện phát ra toàn cục

### 2.1. Hiện trạng

`core/socket.js:11-19` dựng server **không** có `io.use()`, không có
`allowRequest`, không kiểm token ở bất kỳ đâu:

```js
io = new Server(httpServer, {
  cors: { origin: config.cors.origin || true, credentials: true, methods: ['GET','POST'] },
  transports: ['websocket', 'polling'],
});
```

`core/socket.js:25-31` cho socket vào phòng theo con số nó **tự khai**:

```js
socket.on('join_account', (idaccount) => {
  if (idaccount) {
    socket.join(`account_${idaccount}`);
  }
});
```

Nhưng phòng còn không phải vấn đề chính. **Cả bốn hàm phát đều làm hai lần** —
một lần vào phòng riêng, rồi một lần ra toàn bộ:

| Hàm | Phát riêng | Phát **toàn cục** |
|---|---|---|
| `emitBankTransaction` | `:82` `io.to(room)` | `:84` `io.emit(\`bank_transaction:${idaccount}\`, txData)` |
| `emitOcrCompleted` | `:103` `io.to(room)` | `:104` `io.emit(\`ocr_completed:${idaccount}\`, ocrData)` |
| `emitOcrDuplicate` | `:123` `io.to(room)` | `:124` `io.emit(\`ocr_duplicate:${idaccount}\`, duplicateData)` |
| `emitAuditActivity` | — | `:60` `io.emit('audit_activity', activityData)` |

Tên sự kiện có gắn `idaccount`, nhưng `io.emit` **gửi cho mọi socket**. Một
client ẩn danh chỉ cần lắng nghe `ocr_completed:10` là nhận trọn DTO hoá đơn của
tài khoản 10, **không cần đăng nhập, không cần vào phòng**.

Chú thích ở `:83` nói rõ đây là chủ ý: *"Đồng thời phát chung để client đang ở
chế độ broadcast cũng nhận được"*. Nghĩa là cơ chế phòng bị vô hiệu bằng tay.

### 2.2. Cái gì rò, và rò từ bao giờ

Nội dung DTO không phải siêu dữ liệu — nó gồm tên cửa hàng, danh sách mặt hàng,
số tiền, và với biên lai ngân hàng thì có cả `counterpart_account`
(`classify.service.js:396-404`, `:431-441`).

**Quan trọng: `emitAuditActivity` đang rò ngay hôm nay, không cần chờ OCR.**
Nó được gọi từ `auth.service.js` trong đường ghi nhật ký kiểm toán, mà
`auditLogMiddleware` gắn toàn cục ở `app.js:41` nên chạy trên **mọi** request đã
xác thực. Tên người dùng và hành động của họ được phát cho mọi socket ẩn danh
đang kết nối, kể từ lúc mô-đun này lên `main`.

Ba hàm còn lại hiện chưa rò được vì hai điều kiện cấu hình chưa có (thiếu
`GEMINI_API_KEY`, và chưa client nào gọi `/api/ai/`). Nhưng cả hai điều kiện đó
đều sắp được gỡ.

### 2.3. Đề nghị sửa

**Bước 1 — xác thực lúc bắt tay.** Đọc token từ `socket.handshake.auth.token`,
xác minh bằng đúng hàm mà `middleware/auth.js` dùng, gắn `socket.data.idaccount`:

```js
io.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('unauthorized'));
    const payload = verifyAccessToken(token);      // dùng lại hàm của middleware/auth
    socket.data.idaccount = payload.idaccount;
    next();
  } catch {
    next(new Error('unauthorized'));
  }
});
```

**Bước 2 — bỏ hẳn `join_account` do client tự khai.** Cho socket vào phòng của
chính nó ngay sau khi xác thực:

```js
socket.join(`account_${socket.data.idaccount}`);
```

**Bước 3 — xoá bốn dòng `io.emit`.** Giữ đúng nhánh `io.to(room)`. Nếu Admin
Dashboard thật sự cần nghe `audit_activity` thì cho nó một phòng riêng
(`socket.join('admin')` khi `payload.rolename === 'admin'`) và phát vào phòng
đó, không phát toàn cục.

> ⚠️ **Bước 3 sẽ làm hỏng consumer hiện tại.** `Admin-web/src/hooks/useSocket.js`
> kết nối **không kèm token**, nên bước 1 sẽ chặn nó. Phải sửa hai bên cùng lúc.
> Phía Client-app chưa bị ảnh hưởng: `pubspec.yaml` **không có** `socket_io_client`,
> nên hiện chưa có client Flutter nào nghe socket.

---

## 3. Việc 2 — phân loại từng mặt hàng chưa bao giờ chạy

### 3.1. Bằng chứng

`classify.service.js:117`, khai báo nhận **object**:

```js
async classifyBatch(idaccount, { items = [], merchant = '', source = 'OCR' }) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }
```

`classify.service.js:372`, chỗ gọi truyền vào **mảng**:

```js
const batchResults = await this.classifyBatch(idaccount, batchItems);
```

Destructuring `{ items = [] }` trên một mảng cho `items === undefined` → nhận
mặc định `[]` → thoát ở `:118-120`.

**Mẫu gọi đúng nằm ngay trong repo** để đối chiếu — `classify.controller.js:52-56`:

```js
const results = await classifyService.classifyBatch(idaccount, { items, merchant, source });
```

Cùng một hàm, hai kiểu truyền.

### 3.2. Hậu quả

`classify.service.js:377` `batchResults[idx]` luôn `undefined`, nên `:378` cho
`catId` rơi về `txClassification.category_id` — một hằng số suốt vòng lặp:

- Mỗi mặt hàng nhận **danh mục của cả hoá đơn**, không phải danh mục riêng.
- `groupMap` chỉ bao giờ có **một khoá**, nên `option_grouped` luôn một nhóm.
- Tính năng "Lưu theo nhóm danh mục" ở `docs/progress/Client-app.md` mục 6.4
  **không hoạt động**.

Không exception, không log — `[]` là giá trị trả về hợp lệ.

Hai triệu chứng phụ đi kèm, nên sửa cùng lúc:

- `note` của nhóm gán **một lần** lúc tạo nhóm (`:388`, trong `if (!groupMap.has(catId))`),
  nên hoá đơn siêu thị 20 món hiện `"BigC: Sữa tươi"`.
- `group_total` cộng dồn từng dòng (`:394-395`) trong khi `option_grouped.total_amount`
  (`:415-417`) lấy từ `extraction.total_amount` — hai số lệch nhau khi có VAT,
  chiết khấu hoặc làm tròn.

### 3.3. Sửa

```js
const batchResults = await this.classifyBatch(idaccount, {
  items: batchItems,
  merchant: extraction.merchant_name,
  source: 'OCR',
});
```

Truyền `merchant` là bắt buộc chứ không phải thêm cho đẹp: `keyword.matcher.js:23-30`
và `nlp.matcher.js:56-60` đều dùng `context.merchant`, mà nhánh này đang để trống.

Lưu ý thêm: kể cả sau khi sửa, `classifyBatch` chỉ có Tầng 1 (`:134`) và Tầng 2
(`:137-142`) — **không có Tầng 3 LLM** như `classifySingle` (`:74-84`). Cân nhắc
có bổ sung hay không.

### 3.4. Test đề nghị

Dựng `extraction` giả có hai món thuộc hai danh mục rõ ràng khác nhau ("Cà phê
sữa" và "Nước rửa chén"), khẳng định `option_grouped.groups.length === 2`. Test
này **đỏ ngay** với mã hiện tại, nên nó chứng minh được là đang canh đúng chỗ.

> Hiện **không có test nào** phủ pipeline OCR: `package.json` không có script
> `test`, hai file trong `classify/__tests__/` chỉ có comment TODO, và file
> `Test/test_ai_classify_3tier.js` mà `docs/progress/Backend.md` báo "PASS 100%"
> **không tồn tại trong repo**.

---

## 4. Việc 3 — thiếu `GEMINI_API_KEY`, và mã lỗi bị nuốt trên đường về

`vision.extractor.js:47-54` ném lỗi khi không có khoá:

```js
const apiKey = process.env.GEMINI_API_KEY || this.geminiApiKey;
if (!apiKey) {
  throw Object.assign(new Error('Chưa cấu hình GEMINI_API_KEY cho hệ thống OCR'), {
    statusCode: 500, errorCode: 'CONFIG_MISSING',
  });
}
```

Biến này **không có** trong `src/Backend/.env` (đã mở ra đếm: 16 biến, không
biến nào là nó), cũng không có trong `.env.example` hay `config/index.js`.
Nghĩa là **mọi request mang ảnh thật đều chết**; chỉ request mang
`_mockExtraction` mới đi qua được (xem việc 5).

Đi kèm một vấn đề thứ hai làm việc chẩn đoán khó hơn nhiều:
`middleware/error-handler.js` bỏ qua cả `err.statusCode` lẫn `err.errorCode`,
nên `CONFIG_MISSING` biến mất và ở môi trường production chuỗi lỗi bị thay bằng
`"Internal Server Error"` — nguyên nhân thật mất sạch.

**Đề nghị:** thêm `GEMINI_API_KEY=` vào `.env.example` **trước tiên**, kèm một
dòng chú thích lấy khoá ở đâu. Không có nó thì người tiếp quản dự án không có
cách nào biết cần gì. Rồi sửa error handler để giữ `statusCode`/`errorCode`.

---

## 5. Việc 4 — Dedup Quy tắc 3 bỏ quên ba điều kiện

`dedup.service.js:79-86` truyền đủ năm tham số:

```js
const existing = await dedupRepository.findFuzzyTransfer(
  idaccount, totalAmount, txDate, counterpartAccount, note, options
);
```

Nhưng nhánh CSDL thật `dedup.repository.js:158-182` chỉ có:

```js
where: {
  idaccount: parsedId,
  amount: targetAmount,
  date_transaction: { gte: startOfDay, lte: endOfDay },
  deleted_at: null,
},
...
return candidates[0];
```

**Không dùng `counterpartAccount`, không dùng `note`, không lọc `provider`**, và
`findMany` cũng không có `orderBy` nên `candidates[0]` là tuỳ ý.

Đây là thiếu sót chứ không phải chủ ý — Quy tắc 2 ngay bên trên (`findFuzzyInvoice`)
**có** lọc `provider` (`:92`) và **có** hậu lọc tên cửa hàng trong note (`:116-119`).
Tài liệu cũng mô tả hành vi chưa từng được cài: `docs/progress/Backend.md` ghi
Quy tắc 3 đối soát *"theo số tiền và tài khoản/tên người nhận"*.

**Hậu quả:** một biên lai mang mã giao dịch hoàn toàn mới vẫn bị chặn **409** nếu
trong ngày đã có **bất kỳ** giao dịch nào cùng số tiền — kể cả một giao dịch
nhập tay không liên quan. Quy tắc 1 không cứu được: nó chỉ trả về khi tìm thấy
trùng, không thấy thì rơi tiếp xuống Quy tắc 3 (`dedup.service.js:27-42` → `:75`).
Người dùng nhận thông báo sai *"Giao dịch này đã được ghi nhận trước đó"* trỏ vào
một giao dịch không liên quan, và **luồng dừng hẳn** — không có `classify_result`,
không có màn hình chọn cách ghi nhận.

**Sửa:** đưa `counterpartAccount` và `note` vào mệnh đề lọc (hoặc hậu lọc như
Quy tắc 2 đang làm), thêm `provider`, và thêm `orderBy` cho kết quả tất định.

Một chi tiết nhỏ nhưng đáng sửa cùng: mốc đầu/cuối ngày tính bằng `setHours`
theo **giờ cục bộ của máy chủ** (`:153-156`), không theo múi giờ người dùng.

---

## 6. Việc 5 — cửa hậu `_mock*` trên endpoint đang chạy thật

### 6.1. Đường đi

`ocr.controller.js:21` lấy thẳng từ thân request rồi chuyền xuống service:

```js
const { image_base64, mimetype, _mockExtraction, _mockUser, _mockWallets } = req.body;
```

- `vision.extractor.js:24-26` — `if (options._mockExtraction) return options._mockExtraction;`
  chạy **trước** cả lần kiểm API key ở `:47`, nên đây là cách duy nhất hiện tại
  để đi hết pipeline.
- `classify.service.js:219-228` — `params._mockUser` / `params._mockWallets` thay
  cho `getUserProfileAndWallets()`, ép `typeDetector` trả `Transfer` với
  `confidence 1.0` và một `idwallet` tuỳ ý.
- `classify.controller.js:108` truyền **nguyên `req.body`**, nên
  `/api/ai/classify/transaction` còn ăn thêm `_mockBankAccounts`.

Chặn duy nhất là `authenticate` (`ai.routes.js:11`). Không có cờ `NODE_ENV` nào.

### 6.2. Phạm vi thật — hẹp hơn bản đầu tiên của tài liệu này viết

Vòng thẩm định siết lại hai điểm, ghi ra đây để không ai đọc quá lên:

- **Không phải leo thang đặc quyền.** Endpoint chỉ trả DTO, không ghi CSDL, và
  `idaccount` luôn lấy từ `req.user`. Không đọc được dữ liệu người khác.
- **`_mockExistingTransactions` KHÔNG tới được qua HTTP.** `ocr.controller.js:31-37`
  dựng object tường minh nên nó bị lọc mất. Là mã chết ở tầng repository, đừng
  liệt vào phần khai thác được.

Cái thật sự làm được: bịa hồ sơ và ví để ép kết quả thành `Transfer` kèm
`idwallet` tuỳ ý; và chạy toàn bộ tầng phân loại (kể cả Tầng 3 gọi Gemini) mà
không tốn một lần gọi Vision nào.

### 6.3. Sửa

Lọc ở controller bằng một cờ môi trường:

```js
const allowMocks = process.env.NODE_ENV === 'test' || process.env.ALLOW_AI_MOCKS === 'true';
const { image_base64, mimetype } = req.body;
const mocks = allowMocks
  ? { _mockExtraction: req.body._mockExtraction, _mockUser: req.body._mockUser, _mockWallets: req.body._mockWallets }
  : {};
const result = await ocrService.processReceipt(idaccount, { image_base64, mimetype, ...mocks });
```

Và ở `classify.controller.js:108`, thôi truyền nguyên `req.body` — liệt kê tường
minh các trường được nhận.

Gọn hơn nữa nếu test gọi thẳng vào service chứ không qua HTTP: **không đọc
`_mock*` từ `req.body` chút nào**. Khi đó controller không cần cờ môi trường.

---

## 7. Việc 6 — `Bank_tran_id` duy nhất toàn cục thay vì theo tài khoản

> 🟡 **Đọc khung cảnh báo ở đầu tài liệu trước.** Việc này **chưa nổ được** ở
> trạng thái mã hiện tại. Nó là nợ phải trả **trước khi** client nối luồng OCR,
> không phải lỗi đang chảy máu.

### 7.1. Hiện trạng

`prisma/schema.prisma`, model `transaction`:

```prisma
@@unique([provider, bank_tran_id], map: "uq_transaction_external")
```

Khoá này **không có `idaccount`**, trong khi bộ khử trùng lặp
(`dedup.repository.js:27-36`) lại tìm **trong phạm vi một tài khoản**. Hai phạm
vi lệch nhau.

Với hoá đơn mua sắm, `bank_tran_id` được gán bằng `invoice_no`
(`ocr.service.js:76-79`) — số hoá đơn do từng cửa hàng tự đánh, kiểu `0001`,
`HD001`. Hai người dùng khác nhau hoàn toàn có thể cùng cầm hoá đơn số `0001`,
cả hai đều mang `provider = 'ORC'`.

Hậu tố `${invoice_no}_grp_${idx}` (`classify.service.js:409-413`) không giúp gì
cho vế này: nó phân biệt các giao dịch con **trong cùng một hoá đơn**, không
phân biệt hai người dùng.

### 7.2. Vì sao chưa nổ, và khi nào sẽ nổ

Payload đẩy của client (`sync_engine.dart:972-987`) có đúng 11 trường và
**không có `provider` lẫn `bank_tran_id`**. Backend do đó ghi
`bank_tran_id = NULL` (`sync.repository.js:260`) và `provider = 'Manual'`
(`:264`). PostgreSQL coi mỗi NULL là khác biệt, nên `uq_transaction_external`
hiện **trơ hoàn toàn** với dữ liệu client đẩy lên. Phép đo ở đầu tài liệu xác
nhận: 5 hàng, tất cả `Manual`/`Confirmed`, không hàng nào có `Bank_tran_id`.

Nó sẽ nổ **đúng lúc** client làm theo `docs/progress/Client-app.md` mục 6.4 và
thêm hai trường đó vào payload đẩy.

### 7.3. Đề nghị sửa

**Phương án 1 — đưa `Idaccount` vào khoá · khuyến nghị.** Mã hoá đơn và mã giao
dịch ngân hàng chỉ có ý nghĩa duy nhất trong phạm vi một người dùng:

```prisma
@@unique([idaccount, provider, bank_tran_id], map: "uq_transaction_external")
```

Khoá mới **lỏng hơn** khoá cũ nên không hàng nào bị từ chối. Vẫn nên chạy phép
kiểm sau trước khi migrate:

```sql
SELECT "Provider", "Bank_tran_id", COUNT(DISTINCT "Idaccount") AS so_tai_khoan
FROM "transaction"
WHERE "Bank_tran_id" IS NOT NULL AND "Deleted_at" IS NULL
GROUP BY "Provider", "Bank_tran_id"
HAVING COUNT(DISTINCT "Idaccount") > 1;
```

**Phương án 2 — bỏ ràng buộc, chỉ giữ `@@index`.** Rẻ hơn nhưng mất lưới an toàn
cuối cùng ở CSDL. Chỉ nên chọn nếu tin chắc `dedup` phủ hết mọi đường ghi — hiện
**không** phải vậy: client ghi thẳng qua `/sync/push` không đi qua `dedup` lần
nào, và `/api/ai/classify/*` (`classify.routes.js:14-17`) cũng đi thẳng.

---

## 8. Việc 7 — bốn chỗ nhỏ hơn

**7a. Endpoint trả ba hình dạng DTO khác nhau.** Nhánh Transfer dùng
`transfer_details` + `options` (`classify.service.js:314-360`); nhánh
BANK_TRANSFER/SMS có `transaction_info` + `option_single` nhưng **vứt bỏ
`optionGrouped` đã tính xong** ở `:363-419` — gồm cả một lượt `classifyBatch`;
chỉ nhánh RECEIPT đủ cả hai (`:457-482`). Client phải viết ba nhánh phân tích
cho một endpoint. Đề nghị thống nhất một hình dạng, các trường không áp dụng thì
để `null`.

**7b. `findByBankTranId` so mã theo hai luật khác nhau.** Nhánh mock chuẩn hoá
`toLowerCase().trim()` (`dedup.repository.js:15-22`), nhánh Prisma so nguyên văn
(`:27-36`), mà cột là `VARCHAR(100)` thường, không `citext`. Lệch khoảng trắng
đầu/cuối là khả dĩ nhất. Một lệch nữa: nhánh Prisma lọc `deleted_at: null`
(`:31`), nhánh mock không. Đề nghị chuẩn hoá **một lần** trước khi so, dùng chung
cho cả hai nhánh.

**7c. Hai tên cho cùng một nguồn: `'ORC'` và `'OCR'`.** `ocr.service.js:77` sinh
`'ORC'`; `sync.validation.js:118` chấp nhận **cả hai**; `sync.repository.js:263`
liệt kê cả hai trong danh sách suy ra `status`. Chốt một tên chuẩn rồi sửa hết
một lượt, đừng để hai tên cùng sống — đây đúng loại lệch âm thầm mà dự án hay
vấp.

**7d. Trạng thái `'Interrupted'` là mã chết.** `audit-log.middleware.js:12-14`
đặt `req.auditStatus = 'Interrupted'` trong `req.on('aborted')`, nhưng
`recordAuditLog` chỉ được gọi trong `res.on('finish')` (`:17`, `:75`) — mà
`finish` không nổ khi client cắt kết nối bằng RST. Với POST có body như
`/sync/push`, `'aborted'` thậm chí không nổ vì `express.json()` mount trước
middleware (`app.js:29` so với `:41`). Bán kính chỉ ở nhật ký kiểm toán, nhưng
nó đang ghi `'Pass'` cho những request thật ra đã đứt.

---

## 9. Việc 8 — ba chỗ sai trong tài liệu

Frontend Team **không tự sửa** tài liệu của đội Backend; ghi lại để đội Backend
quyết.

### 9.1. `docs/progress/Client-app.md` — sai tên endpoint đồng bộ

Mục 6.6 và bảng ở mục 8 đều ghi `POST /api/sync/batch`. Route thật là
**`/api/sync/push`** (`api/sync.routes.js:10`), và client đang gọi đúng tên đó
(`src/Client-app/lib/core/sync/sync_engine.dart:1172`). Không có route nào tên
`batch`.

### 9.2. `docs/progress/Client-app.md` mục 6.4 — khẳng định sai về ràng buộc unique

> Điều này đảm bảo tuân thủ 100% ràng buộc Unique CSDL
> `@@unique([provider, bank_tran_id])` của PostgreSQL, ngăn chặn triệt để lỗi
> xung đột khi đồng bộ!

Hậu tố `_grp_N` chỉ phân biệt các giao dịch con **trong cùng một hoá đơn của
cùng một người dùng**. Nó không đụng tới vế liên tài khoản ở mục 7.

**Và một điều kiện tiên quyết mà tài liệu không nhắc:** hướng dẫn này bảo client
gán `bank_tran_id` và `provider` khi lưu — nhưng **hai trường đó hiện không nằm
trong payload đồng bộ theo chiều nào cả**. Chiều đẩy
(`sync_engine.dart:972-987`) không có; chiều kéo về (`:469-495`) cũng không đọc.
Client làm theo mục 6.4 thì giá trị chỉ nằm lại trong SQLite của đúng máy đó.
Muốn nó có tác dụng thì phải mở rộng hợp đồng đồng bộ **và** sửa mục 7 trước.

### 9.3. `docs/AI/ORC.md:494` và `:498` — "không ghi bất kỳ bản ghi nào vào CSDL"

Đúng với **dữ liệu giao dịch**: truy tận cùng `eventBus.publish('ocr.completed')`
→ `notification.service.js:38-57` chỉ gọi `emitOcrCompleted`, không chạm Prisma;
`schema.prisma` cũng không có model notification nào. Không có "giao dịch ma".

Nhưng **không đúng với CSDL nói chung**: `auditLogMiddleware` gắn toàn cục ở
`app.js:41`, hook `res.on('finish')` → `auth.service.js:653` →
`auth.repository.js:225` `prisma.auditlog.create`. Mọi request OCR **đã xác
thực** đều sinh một hàng `auditlog`.

Phạm vi hẹp: request 401 không sinh hàng (`audit-log.middleware.js:71-73`), việc
ghi là best-effort trong `setImmediate`, và hàng chỉ chứa siêu dữ liệu chứ không
có kết quả bóc tách. Nên kết luận *"mất mạng giữa chừng là mất trắng kết quả"*
vẫn đúng. Chỉ cần sửa lại câu chữ cho khớp.

---

## 10. Liên hệ với các tài liệu khác trong thư mục này

- **`CATEGORY_KEYWORD_SYNC.md`** — lỗ hổng phân quyền ở mục 4 của tài liệu đó
  **vẫn còn nguyên** (`classify.service.js:196` → `classify.repository.js:64`,
  vẫn không đọc `create_by`). Mức nghiêm trọng đã tăng vì `keyword.matcher` nay
  nằm trên đường chạy thật của OCR.
  **Bổ sung sau thẩm định:** backend **đã** gửi cột `Keyword` xuống trong
  `/sync/pull` (`sync.repository.js:184` có `keyword: true`) — chính client bỏ
  qua nó ở nhánh kéo về. **Client đã vá ngày 2026-09-04**: pull tách CSV rồi gieo
  vào `CategoryKeywords`, chỉ gieo khi trống. Nghĩa là chiều **xuống** đã xong và
  không cần backend làm gì; chỉ chiều **lên** mới cần quyết định về mô hình dữ liệu.
- **`2026-09-04-backend-idempotent-delete.md`** — việc (A) và (B) ở tài liệu đó
  vẫn là thứ biến một lỗi ghi đơn lẻ thành hỏng vĩnh viễn. Sửa (A) trước vẫn là
  bước rẻ nhất, vì nó cắt vòng lặp cho **mọi** nguyên nhân gốc.
- **`CATEGORY_NAME_UNIQUENESS.md`** — dòng "hàng đã xoá mềm vẫn giữ chỗ" ở bảng
  mục 2 của tài liệu đó **không còn là rủi ro lý thuyết**: vòng thẩm định tìm ra
  một đường kích hoạt cụ thể, và nó chạy ở **mỗi lần mở app**.

  Người dùng xoá một trong 5 danh mục cá nhân mặc định → xoá mềm, đẩy lên, server
  đặt `Delete_at`. Lần mở app sau, `PersonalDefaultCategories.ensureMissing`
  (`src/Client-app/lib/features/category/data/services/personal_default_categories.dart:93`,
  gọi ở `auth_bloc.dart:135` và `:176`) dùng `CategoryDao.getNamesInUse`, mà hàm
  đó lọc `isDeleted = false` — nên nó **không thấy hàng đã xoá**, tưởng tài khoản
  còn thiếu, và tạo lại với **UUID mới** ở trạng thái `pending`. Đẩy lên đụng
  `uq_category_owner_name_classify` (`schema.prisma:129`, **không có mệnh đề
  WHERE** nên hàng xoá mềm vẫn giữ chỗ) → **23505**.

  **Client đã cầm máu ngày 2026-09-04:** `_classifyFailure` xếp vi phạm UNIQUE
  vào `permanent`, nên bản ghi bị chặn theo thời gian thay vì đẩy lại ở mọi chu
  kỳ. Hàng đợi đồng bộ không còn bị kéo chậm. Nhưng bản ghi **vẫn sinh ra ở mỗi
  lần mở app** và vẫn không bao giờ lên được server.
  
  Vế backend là mệnh đề `WHERE "Delete_at" IS NULL` còn thiếu trên index — đúng
  thứ `CATEGORY_NAME_UNIQUENESS.md` mục 4.1 đã đề nghị. Có nó thì mọi bản ghi
  đang bị chặn **tự quay lại hàng đợi** và đồng bộ thành công. Đây là lý do cụ
  thể để nâng ưu tiên cho tài liệu đó.
- **`CATEGORY_CLASSIFY_ALIGNMENT.md`** — bước thu hẹp `validClassify` vẫn chưa
  làm (`sync.validation.js:103`). Không liên quan đợt đẩy này.

---

## 11. Ghi chú về phương pháp

Bản đầu của tài liệu này viết từ một lượt đọc mã. Bản này viết lại sau khi từng
phát hiện bị một vòng phản biện độc lập soi hai lần — lượt một kiểm *bằng chứng
có đúng không*, lượt hai kiểm *hậu quả có thật ở trạng thái hôm nay không*. Lượt
hai bác bỏ gần một nửa số phát hiện "mức cao" của lượt một.

Đó là lý do tài liệu này phân biệt rõ **"đang hỏng"** với **"nợ phải trả trước
khi làm bước tiếp theo"**. Trộn hai loại đó vào nhau là cách nhanh nhất để người
đọc mất niềm tin vào cả danh sách.

Toàn bộ rà soát chỉ **đọc** mã tại `fcf7659`, cộng ba truy vấn **chỉ đọc** vào
CSDL `PersonFinance`. **Không có dòng mã backend nào bị thay đổi, không có dữ
liệu nào bị sửa.** Số dòng trích dẫn đúng với commit đó và sẽ trôi khi mã đổi —
đối chiếu lại với mã nguồn thật trước khi kết luận.
