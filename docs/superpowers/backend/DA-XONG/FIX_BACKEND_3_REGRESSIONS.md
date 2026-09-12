# Ba hồi quy của `7675b35` ("fix backend 3") — xác thực từ chối mọi tài khoản, chốt trả hai lần chặn hoàn tác, mã lỗi lệch tài liệu

> ⚠️ **2026-09-12 — backend sửa ở `cbbeeb4` (gộp về nhánh cùng ngày): A ✅ đã chạy thật** (bắt tay
> socket nối được trên máy ảo sau 51 lần bị từ chối; `/auth/refresh` mã đúng, chưa đo), **C ✅**,
> **B chỉ nửa đầu** — bước 1 (bỏ chốt ở `upsertBill`) xong và đo thật (hàng `3c90acfa…` lên
> `Pending`), bước 2 (chốt ở `upsertTransaction`, mục 3.6) **chưa làm**: `BILL_ALREADY_PAID` nay
> không ai ném, server không chặn khoản chi thứ hai ở đâu cả. Bảng ở banner `../CAN-LAM/README.md`;
> việc còn lại xin ở `../CAN-LAM/CON_LAI_SAU_CBBEEB4.md` §2.1 (mục 20).

**Ngày:** 2026-09-11 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** **A** —
ba chỗ nhỏ ở `middleware/auth.js`, `core/socket.js`, `modules/auth/auth.service.js`;
**B** — dời một phép kiểm từ `upsertBill` sang `upsertTransaction`; **C** — sửa ba
câu tài liệu. Không migration.

> **Đo trên `origin/main` @ `907294b`** — merge PR #72, chứa `7675b35` của NPBao
> (2026-09-10 23:15) — bằng `git show origin/main:<tệp>`. Nhánh client
> `TranQuangDat` @ `d352809` **chưa gộp** commit ấy lúc viết: số dòng phía backend
> dưới đây là số dòng **trên `main`**, còn số dòng phía client là của `TranQuangDat`.
> ✅ Nhánh client gộp `main` @ `cc65f4f` ngày 2026-09-11, nên số dòng backend nay
> cũng đúng trên `TranQuangDat` — ba hồi quy vẫn nguyên, vì gộp không sửa gì.

---

## 1. Tóm tắt

Theo diff, `7675b35` làm một lượt nhiều mục của thư mục này: body 401 mang mã,
ánh xạ `22001`/`23502`, `goal.Priority` giữ `null`, bộ lọc ghi chú mới,
`sync.completed` ra socket, và tệp `database/12`. Phần còn lại client soát
sau, cùng ngày — `VERIFY_7675B35_REMAINING.md` (mục 18). Tài liệu này chỉ nói về **ba chỗ làm hỏng thứ đang
chạy**, tìm ra khi soát riêng vùng xác thực và hoá đơn — hạng mục cưỡng chế đăng
xuất của client phụ thuộc vào hai vùng ấy.

| | Hỏng gì | Ai bị | Mức |
|---|---|---|---|
| **A** | `accountRejection` không bao giờ trả `null`, nên bắt tay Socket.io và `/auth/refresh` từ chối **mọi** tài khoản, kể cả `Active` | Mọi người dùng app: kênh thời gian thực không nối được, và bị đăng xuất khi token truy cập hết hạn. Mọi admin: bị đăng xuất mỗi lần token 15 phút hết hạn | 🔴 chặn triển khai |
| **B** | Chốt "trả hai lần" đặt ở `upsertBill`, từ chối mọi lần đổi `Pay_status` từ `'Payed'` sang giá trị khác | Người **hoàn tác thanh toán** một hoá đơn đã đồng bộ: hoá đơn kẹt hàng đợi đẩy, dữ liệu server lệch. Và chốt này **không chặn được** hai khoản chi | 🔴 hỏng tính năng đã có |
| **C** | Tài liệu backend ghi `BILL_ALREADY_PAID` / `WALLET_NAME_DUPLICATE` "ánh xạ thành `CONSTRAINT_VIOLATION`"; mã thật trả mã riêng | Người đọc tài liệu kết luận client không phải đổi gì — sai | 🟡 tài liệu |

**Ghi nhận trước:** client góp phần vào cả ba. Hàm ở A chép gần nguyên văn đề
xuất của client (2.4). Tên `BILL_ALREADY_PAID` ở B là tên client đề xuất cho một
chốt khác (3.4). Hai mã `WALLET_*` ở C cũng do client xin — chỉ là client chưa
thêm chúng vào danh sách mã vĩnh viễn của mình (mục 5).

---

## 2. A — `accountRejection` không bao giờ trả `null`

### 2.1. Mã

`middleware/auth.js:60-74`:

```js
function accountRejection(info, idaccount) {
  const inactive = info?.status?.toLowerCase() === 'inactive';
  return {
    message: inactive
      ? (info?.reason_inactive
          ? `Tài khoản đã bị vô hiệu hóa. Lý do: ${info.reason_inactive}`
          : 'Tài khoản đã bị vô hiệu hóa')
      : 'Account no longer exists or has been deleted',
    data: {
      code: inactive ? 'ACCOUNT_INACTIVE' : 'ACCOUNT_DELETED',
      idaccount: Number(idaccount),
      reason_inactive: info?.reason_inactive || null,
    },
  };
}
```

Hàm không đọc `info.valid`, và mọi nhánh đều trả một đối tượng. Ba chỗ gọi:

| Chỗ gọi | Gọi khi nào | Kết quả |
|---|---|---|
| `middleware/auth.js:109-112` — `authenticate` | chỉ bên trong `if (!accountInfo.valid)` | ✅ đúng |
| `core/socket.js:39-49` — bắt tay | **luôn luôn**, rồi `if (rejection)` | ❌ từ chối mọi kết nối |
| `modules/auth/auth.service.js:406-418` — `refresh` | **luôn luôn**, rồi `if (rejection)` | ❌ thu hồi token rồi ném 401 cho mọi lần làm mới |

Hai chỗ ❌ còn đọc `rejection.code` (`socket.js:44`, `auth.service.js:414`) và
`rejection.reason_inactive` (`socket.js:46`, `auth.service.js:416`). Cả hai là
`undefined`, vì hàm đặt chúng dưới `rejection.data`.

### 2.2. Đo — chạy đúng hàm lấy từ `main`, không cần CSDL

```bash
git show origin/main:src/Backend/middleware/auth.js > main_auth.js
node -e '
const src = require("fs").readFileSync(process.argv[1], "utf8");
const m = src.match(/function accountRejection\([\s\S]*?\r?\n}\r?\n/);
const accountRejection = new Function("return (" + m[0] + ")")();
for (const [ten, info] of [
  ["Active, valid=true", { valid: true, status: "Active", reason_inactive: null }],
  ["Inactive co ly do", { valid: false, status: "Inactive", reason_inactive: "spam" }],
  ["Khong ton tai (info null)", null],
]) {
  const r = accountRejection(info, 10);
  console.log("ROW| " + ten + " -> truthy=" + !!r + " | r.code=" + (r && r.code)
    + " | r.data.code=" + (r && r.data && r.data.code) + " | message=" + (r && r.message));
}' main_auth.js
```

Kết quả ngày 2026-09-11 (lệnh đã chạy đặt tệp tạm ở thư mục khác; phần còn lại
như trên):

```
ROW| Active, valid=true -> truthy=true | r.code=undefined | r.data.code=ACCOUNT_DELETED | message=Account no longer exists or has been deleted
ROW| Inactive co ly do -> truthy=true | r.code=undefined | r.data.code=ACCOUNT_INACTIVE | message=Tài khoản đã bị vô hiệu hóa. Lý do: spam
ROW| Khong ton tai (info null) -> truthy=true | r.code=undefined | r.data.code=ACCOUNT_DELETED | message=Account no longer exists or has been deleted
```

Dòng đầu là toàn bộ lỗi: một tài khoản hợp lệ vẫn nhận lý do từ chối, và lý do ấy
là *"tài khoản đã bị xoá"*.

⚠️ **Chưa chạy đầu-cuối trên backend thật.** CSDL dev của client chưa áp
`database/12`, nên Prisma Client sinh từ `schema.prisma` của `main` sẽ đọc những
cột chưa có. Bằng chứng là hàm chạy thật cộng với mã của hai chỗ gọi: ở cả hai
chỗ, giữa `accountRejection(...)` và `if (rejection)` không có dòng nào khác.

### 2.3. Hệ quả

**Bắt tay Socket.io.** Mọi kết nối nhận `connect_error` với thông điệp
*"Authentication error: Account no longer exists or has been deleted"* và
`data.code` rỗng. Không socket nào qua được bước bắt tay, nên **không sự kiện thời
gian thực nào tới được ai**:

- `account.force_logout` — kênh chính của cưỡng chế đăng xuất;
- `sync.completed` — vừa bắc ra socket trong chính commit này;
- `bank_transaction.incoming`, `ocr.completed`, `ocr.duplicate`;
- mọi sự kiện của Admin-web (`src/Admin-web/src/hooks/useSocket.js`).

App client không báo gì: `realtime_channel.dart:159-186` coi mỗi lần bị từ chối là
một lần nối hỏng và hẹn nối lại theo bảng giãn cách, mãi mãi.

**`/auth/refresh`.** Với **mọi** refresh token hợp lệ, `auth.service.js:411` thu
hồi token rồi ném 401. `auth.controller.js:79-85` trả 401 kèm `idaccount` nhưng
**không** kèm `code`, vì `error.code` là `undefined`.

- **App:** máy dev của client đặt `JWT_USER_ACCESS_EXPIRES=7d`. Hết 7 ngày,
  request đầu tiên nhận 401 *"Token expired"* (`middleware/auth.js:99-100`) →
  `auth_interceptor.dart` (`onError` gọi `_lamMoiChung()` → `_lamMoi()`) gọi `/auth/refresh` → 401 →
  xoá token → màn đăng nhập. Người dùng bị đăng xuất mỗi 7 ngày thay vì dùng hết refresh token 90 ngày.
- **Admin-web:** `JWT_ADMIN_ACCESS_EXPIRES=15m`. `src/Admin-web/src/api/axios-client.js:83-107`
  gặp 401 thì làm mới qua `/auth/refresh`; làm mới hỏng thì `handleLogoutRedirect()`
  xoá phiên và về `/login`. Admin bị đăng xuất sau mỗi 15 phút.

Vì `authenticate` không bị ảnh hưởng và token người dùng sống 7 ngày, một lượt
kiểm ngắn bằng request HTTP **không** thấy lỗi này.

### 2.4. Một phần do đề xuất của client

`AUTH_401_BODY_CODE.md` mục 4.2 (client viết 2026-09-10) đề xuất **đúng hàm này**,
và bản đề xuất cũng không bao giờ trả `null`. Đoạn hướng dẫn cho `core/socket.js`
chỉ ghi *"đổi `isAccountValid` sang `getAccountValidity` (đã export sẵn), rồi
`next(Object.assign(new Error(r.message), { data: r.data }))`"* — **không** viết rõ
phải bọc trong `if (!info.valid)`. Một hàm tên `accountRejection` mà luôn trả đối
tượng khiến viết `if (rejection)` trông hoàn toàn tự nhiên. Vì thế 2.6 sửa **ngay
trong hàm**, để chỗ gọi thứ tư không lặp lại được lỗi này. Tài liệu kia đã gắn
cảnh báo trỏ về đây.

### 2.5. Lỗi lược đồ không được đi ra thành `ACCOUNT_DELETED`

Khi Prisma lệch lược đồ, `getAccountValidity` trả
`{ valid: false, status: 'Error', errorType: 'SCHEMA_ERROR' }`
(`middleware/auth.js:48-54`). `authenticate` xử lý ca ấy **trước** khi dựng lý do
từ chối, bằng 503 (`:106-108`). Hai chỗ gọi còn lại thì không. Sửa 2.1 mà quên ca
này thì một lần lệch cấu hình sẽ đi ra ngoài dưới dạng `ACCOUNT_DELETED`.

Đây không phải chi tiết phụ. Client đang dựng cưỡng chế đăng xuất, và đọc
`ACCOUNT_DELETED` là *tài khoản đã bị xoá → dọn dữ liệu của tài khoản ấy trên máy*
(`docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md` mục
3.1 và 3.6). Một lần backend lệch lược đồ không được phép xoá dữ liệu trên điện
thoại người dùng.

### 2.6. Việc cần làm

**1. `middleware/auth.js` — tài khoản hợp lệ thì hàm trả `null`:**

```js
function accountRejection(info, idaccount) {
  // Hợp lệ thì không có gì để từ chối. Nơi gọi vẫn phải xử lý
  // `errorType === 'SCHEMA_ERROR'` TRƯỚC khi gọi hàm này — xem authenticate.
  if (info?.valid) return null;
  const inactive = info?.status?.toLowerCase() === 'inactive';
  // ... phần còn lại giữ nguyên
}
```

`authenticate` không phải đổi gì.

**2. `core/socket.js:39-49`:**

```js
const accountInfo = await getAccountValidity(decoded.idaccount);
if (accountInfo.errorType === 'SCHEMA_ERROR') {
  // Không kèm data.code: đây không phải lý do của tài khoản.
  return next(new Error('Authentication error: Service temporarily unavailable'));
}
const rejection = accountRejection(accountInfo, decoded.idaccount);
if (rejection) {
  return next(Object.assign(new Error(`Authentication error: ${rejection.message}`), {
    data: rejection.data, // { code, idaccount, reason_inactive }
  }));
}
```

**3. `modules/auth/auth.service.js:406-418`:**

```js
const accountInfo = await getAccountValidity(payload.idaccount);
if (accountInfo.errorType === 'SCHEMA_ERROR') {
  throw Object.assign(
    new Error('Dịch vụ xác thực tạm thời gián đoạn do cấu hình hệ thống'),
    { statusCode: 503 },
  );
}
const rejection = accountRejection(accountInfo, payload.idaccount);
if (rejection) {
  await prisma.refreshtoken.update({ where: { idtoken: storedToken.idtoken }, data: { status: true } });
  throw Object.assign(new Error(rejection.message), { statusCode: 401, ...rejection.data });
}
```

`...rejection.data` đưa `code`, `idaccount`, `reason_inactive` lên lỗi — đúng ba
tên `auth.controller.js:79-85` đang đọc, nên controller không phải đổi.

### 2.7. Kiểm lại sau khi sửa

Dùng tài khoản thử, đừng dùng tài khoản thật.

1. **Hàm** — chạy lại lệnh ở 2.2 trên tệp đã sửa. Dòng đầu phải ra `truthy=false`;
   hai dòng sau giữ nguyên.
2. **Bắt tay, tài khoản `Active`** — mở app hoặc Admin-web. Log backend phải có
   dòng `[Socket] Authenticated client connected` (`core/socket.js:62`).
3. **Làm mới, tài khoản `Active`:**
   ```bash
   curl -s -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" \
     -d '{"username":"<tài khoản thử>","password":"<mật khẩu>"}'
   curl -s -X POST http://localhost:3000/api/auth/refresh -H "Content-Type: application/json" \
     -d '{"refreshToken":"<refreshToken vừa nhận>"}'
   ```
   Kỳ vọng: HTTP 200, có `accessToken` và `refreshToken` mới.
4. **Làm mới, tài khoản bị khoá** — đăng nhập lấy refresh token, khoá tài khoản thử
   qua Admin-web, rồi gọi lệnh thứ hai. Kỳ vọng: HTTP 401, body có
   `"code":"ACCOUNT_INACTIVE"` và `reason_inactive` **ở cấp gốc**. Mở khoá lại sau
   khi kiểm.
5. **Admin-web** — đăng nhập, để yên quá 15 phút rồi thao tác. Phiên phải còn.

---

## 3. B — Chốt "trả hai lần" chặn hoàn tác, mà không chặn được trả hai lần

> ✅ **Tái hiện được trên backend thật, 2026-09-12** — không còn là suy luận từ
> đọc mã. Máy ảo `emulator-5554`, tài khoản 11, backend dev của chính nhánh này.
>
> Kịch bản: tạo hoá đơn lặp hàng tháng "Kiem" 50.000 đ → **Thanh toán** → đồng bộ
> → **Hoàn tác**. Đo thẳng PostgreSQL sau đó:
>
> | | Máy (SQLite) | Server (PostgreSQL) |
> |---|---|---|
> | Kỳ 1 `3c90acfa…` `Pay_status` | `Pending` | **`Payed`** ← lệch |
> | Kỳ 2 `19b45be5…` `Delete_at` | có | có ✓ |
> | Khoản chi `8cafb448…` `Deleted_at` | có | có ✓ |
>
> Log của client, nguyên văn:
>
> ```
> [SyncEngine] Push failed [permanent]: entity=bill, localId=3c90acfa-…,
> reason=Hóa đơn đã được thanh toán, không thể thay đổi trạng thái
> ```
>
> Tức: **hai trong ba việc của hoàn tác lên được server, việc thứ ba thì không.**
> Kỳ kế tiếp bị gỡ và khoản chi bị xoá mềm ở cả hai nơi, nhưng hoá đơn gốc kẹt ở
> `Payed` trên server và `Pending` trên máy — lệch **vĩnh viễn**, vì client (đúng)
> xếp `BILL_ALREADY_PAID` là lỗi vĩnh viễn nên không thử lại.
>
> Hệ quả cho người dùng: máy khác kéo về thấy hoá đơn **đã trả** và **không có kỳ
> kế tiếp** — tức kỳ ấy biến mất khỏi chuỗi, không ai nhắc nữa.
>
> ⚠️ Lượt đo này chạy sau khi client mở đường đồng bộ cho `Previous_bill_id`,
> `Anchor_day`, `Idbill` (2026-09-12) — ba cột ấy **đã tới server đúng giá trị**,
> nên đây thuần tuý là hồi quy B, không dính gì tới thay đổi của client.

### 3.1. Mã

`modules/sync/sync.repository.js:450-455`, nhánh cập nhật của `upsertBill`:

```js
if (new Date(mapped.update_at) > new Date(existing.update_at)) {
  if (existing.pay_status === 'Payed' && mapped.pay_status && mapped.pay_status !== 'Payed') {
    throw Object.assign(new Error('Hóa đơn đã được thanh toán, không thể thay đổi trạng thái'), {
      code: 'BILL_ALREADY_PAID',
    });
  }
```

`sync.service.js:171-173` trả lỗi ấy về client thành `code: 'BILL_ALREADY_PAID'`.

### 3.2. Vì sao nó chặn hoàn tác

Client có **hoàn tác thanh toán** từ 2026-09-06. `undoPayment`
(`bill_repository_impl.dart:153-205`) làm bốn việc trong một giao tác SQLite: hoàn
tiền vào ví, xoá mềm khoản chi, xoá mềm kỳ kế tiếp, và đưa hoá đơn về
`payStatus: 'Pending'` với `updatedAt` mới (`:193-201`). Lần đẩy sau gửi
`pay_status: 'Pending'` (`sync_engine.dart:1301`).

Trên `main`, hàng ấy đang là `'Payed'` và `'Pending' !== 'Payed'`, nên bị từ chối.
Hệ quả, suy từ mã:

- **Máy đã hoàn tác.** Trên bản client trước 2026-09-11, `BILL_ALREADY_PAID` không
  có trong danh sách mã vĩnh viễn; `message` là câu tiếng Việt nên không regex dự
  phòng nào khớp, và hàm phân loại rơi xuống `transient`. Hoá đơn bị gửi lại **ở
  mọi chu kỳ**, và mỗi chu kỳ kết thúc bằng lỗi nên giãn cách luỹ tiến áp lên
  **cả** hàng đợi. ✅ Từ 2026-09-11 client xếp mã ấy vĩnh viễn
  (`sync_engine.dart:1631-1648`): bản ghi bị chặn theo thời gian thay vì kéo chậm
  cả hàng đợi — nhưng hoá đơn vẫn không lên được server, nên hoàn tác vẫn hỏng cho
  tới khi sửa B. Bản client cài trước ngày ấy thì vẫn gửi lại mãi.
- **Server.** Mỗi thao tác trong lô có `try/catch` riêng (`sync.service.js:79-217`),
  nên các thao tác còn lại **đi lọt**: khoản chi bị xoá mềm, kỳ kế tiếp bị xoá mềm,
  số dư ví đã hoàn. Chỉ hoá đơn vẫn `'Payed'`. Máy thứ hai của cùng người dùng thấy
  hoá đơn *đã trả* mà không có khoản chi nào.

⚠️ Chưa tái hiện đầu-cuối, cùng lý do ở 2.2.

### 3.3. Vì sao nó không chặn được trả hai lần

Tình huống chốt này sinh ra để chặn (`2026-09-06-bill-chuoi-ky-va-an-han.md` mục
6.2): hai máy cùng bật tự thanh toán, cùng ngoại tuyến qua ngày đến hạn, rồi lần
lượt trực tuyến. Mỗi máy đẩy **khoản chi của riêng nó** cộng hoá đơn `'Payed'`. Máy
đẩy sau gửi `'Payed'` lên một hàng đã `'Payed'` — chốt không nổ — và khoản chi của
nó là một hàng **mới** nên được nhận. Server vẫn có hai khoản chi.

### 3.4. Chốt đã xin

Mục 6.3 tài liệu hoá đơn, nguyên văn: *"ở `/sync/push`, một `transaction` mang
`Idbill` trỏ tới hoá đơn **đã có** một `transaction` khác cùng `Idbill` chưa xoá
mềm thì **từ chối** với mã lỗi riêng (đề xuất `BILL_ALREADY_PAID`)."* Chốt nằm ở
**giao dịch**, không ở trạng thái hoá đơn: hoàn tác rồi trả lại là hợp lệ.

⚠️ Cùng mục ấy còn ghi *"không dùng unique index cho việc này"*. Lý lẽ ấy chỉ đúng
với unique index **thường**. Partial unique index
`("Idbill") WHERE "Idbill" IS NOT NULL AND "Deleted_at" IS NULL` cho phép đúng ca
hoàn tác rồi trả lại (hàng cũ đã xoá mềm), và hơn phép kiểm ở tầng ứng dụng ở chỗ
**không hở khi hai lần đẩy chạy đồng thời**. Cả hai cách đều vấp bẫy ở 3.5.

### 3.5. Bẫy thứ tự trong một lô

`getOperationWeight` (`sync.service.js:57-63`) cho **ghi** giao dịch trọng số 40
và **xoá** giao dịch trọng số `100 − 40 = 60`: trong một lô, mọi thao tác xoá giao
dịch chạy **sau** mọi thao tác ghi giao dịch. Client đẩy giao dịch đã xoá mềm bằng
thao tác `delete` (`sync_engine.dart:1213-1214`).

Người dùng hoàn tác rồi trả lại **trước khi** kịp đồng bộ: lô chứa *xoá T1* và
*ghi T2*, cùng `Idbill`. T2 được xử lý khi T1 **còn sống**, nên chốt từ chối nhầm —
với partial unique index thì T2 vỡ 23505.

### 3.6. Việc cần làm

1. **Bỏ** `sync.repository.js:451-455`.
2. **Đặt chốt ở `upsertTransaction`** (`sync.repository.js:292`), chạy trước
   `create` và trước `update`, chỉ khi hàng **kết quả** mang `idbill` và chưa xoá
   mềm, và **loại trừ** giao dịch đang bị xoá trong cùng lô:

   ```js
   // sync.service.js — processPush, trước vòng lặp
   const dangXoaTrongLo = new Set(
     operations
       .filter((o) => o?.entity === 'transaction' && o?.operation === 'delete')
       .map((o) => o.payload?.id || o.payload?.idtran)
       .filter(Boolean),
   );
   // ... truyền dangXoaTrongLo vào upsertTransaction

   // sync.repository.js
   async function chanTraHaiLan({ idtran, idbill, deleted_at }, dangXoaTrongLo) {
     if (!idbill || deleted_at) return;
     const khac = await prisma.transaction.findFirst({
       where: { idbill, deleted_at: null, idtran: { notIn: [idtran, ...dangXoaTrongLo] } },
       select: { idtran: true },
     });
     if (khac) {
       throw Object.assign(new Error('Hóa đơn đã được thanh toán bằng một giao dịch khác'), {
         code: 'BILL_ALREADY_PAID',
       });
     }
   }
   ```

   Ở nhánh `update`, `idbill` và `deleted_at` của hàng kết quả là
   `mapped.x !== undefined ? mapped.x : existing.x` — cùng quy ước với các trường
   khác của hàm ấy.

   Muốn kín cả khe hở đồng thời bằng partial unique index ở 3.4 thì tập loại trừ
   **không** đủ, vì CSDL không biết lô. Khi ấy phải xử lý các thao tác **xoá giao
   dịch** của lô **trước** các thao tác ghi giao dịch — xoá mềm chỉ là một phép
   `UPDATE`, không vỡ khoá ngoại nào — rồi ánh xạ 23505 trên index ấy về
   `BILL_ALREADY_PAID` ở `sync.service.js`.
3. ⚠️ **Bước 2 NAY ĐÃ GẤP — đổi so với bản trước.** Câu cũ ở đây ("client chưa gửi
   `idbill`, nên chốt ấy chưa có gì để chặn") đúng tới 2026-09-12; từ ngày ấy client
   **đã gửi** `idbill` trong payload đẩy giao dịch (nay **13 trường**,
   `sync_payload_contract_test.dart` khoá lại), và đã đo thấy nó tới server đúng giá
   trị. Nên chốt ở bước 2 nay có dữ liệu thật để chặn, và bước 1 vẫn phải đi **cùng
   lượt triển khai** với A vì hoàn tác đang hỏng thật — xem bằng chứng đo được ở đầu
   mục 3.

### 3.7. Kiểm lại sau khi sửa

Dùng tài khoản thử. `<id>` là `idaccount`; `<ví>` và `<danh mục>` là id có thật của
tài khoản ấy; `<hd>`, `<t1>`, `<t2>`, `<t3>` là UUID v4 mới.

```bash
push() { curl -s -X POST http://localhost:3000/api/sync/push \
  -H "Authorization: Bearer <access_token>" -H "Content-Type: application/json" -d "$1"; echo; }
```

1. **Hoàn tác** — tạo hoá đơn `'Payed'`, rồi đẩy nó về `'Pending'` với mốc mới hơn:
   ```bash
   push '{"clientId":"kiem-tra","pushedAt":"2026-09-11T00:00:00.000Z","operations":[{"localId":"b1","entity":"bill","operation":"update","payload":{"id":"<hd>","idaccount":<id>,"idwallet":"<ví>","idcategory":"<danh mục>","name":"Thu hoan tac","amount":100000,"due_date":"2026-09-30T00:00:00.000Z","pay_status":"Payed","updatedAt":"2026-09-11T00:00:00.000Z"}}]}'
   push '{"clientId":"kiem-tra","pushedAt":"2026-09-11T00:01:00.000Z","operations":[{"localId":"b1","entity":"bill","operation":"update","payload":{"id":"<hd>","idaccount":<id>,"pay_status":"Pending","updatedAt":"2026-09-11T00:01:00.000Z"}}]}'
   ```
   Kỳ vọng: cả hai `results[0].status` là `"synced"`, và
   `SELECT "Pay_status" FROM bill WHERE "Idbill" = '<hd>'` ra `Pending`.
2. **Trả hai lần** — hai khoản chi cùng `billId`, hai lô riêng:
   ```bash
   push '{"clientId":"kiem-tra","pushedAt":"2026-09-11T00:02:00.000Z","operations":[{"localId":"t1","entity":"transaction","operation":"update","payload":{"id":"<t1>","idaccount":<id>,"idwallet":"<ví>","idcategory":"<danh mục>","amount":-100000,"type":"Transaction","billId":"<hd>","dateTransaction":"2026-09-11T00:02:00.000Z","updatedAt":"2026-09-11T00:02:00.000Z"}}]}'
   push '{"clientId":"kiem-tra","pushedAt":"2026-09-11T00:03:00.000Z","operations":[{"localId":"t2","entity":"transaction","operation":"update","payload":{"id":"<t2>","idaccount":<id>,"idwallet":"<ví>","idcategory":"<danh mục>","amount":-100000,"type":"Transaction","billId":"<hd>","dateTransaction":"2026-09-11T00:02:00.000Z","updatedAt":"2026-09-11T00:03:00.000Z"}}]}'
   ```
   Kỳ vọng: lô đầu `synced`, lô sau `error` với `code: "BILL_ALREADY_PAID"`, và
   `SELECT count(*) FROM transaction WHERE "Idbill" = '<hd>' AND "Deleted_at" IS NULL`
   ra `1`.
3. **Hoàn tác rồi trả lại trong cùng lô** — một lô gồm
   `{"localId":"t1","entity":"transaction","operation":"delete","payload":{"id":"<t1>"}}`
   và khoản chi `<t3>` mới cùng `billId`. Kỳ vọng: cả hai `synced`; phép đếm trên
   vẫn ra `1`.

Xoá mềm các hàng thử sau khi kiểm — không xoá vật lý.

---

## 4. C — Tài liệu backend ghi mã lỗi khác mã thật

| Tệp trên `main` | Dòng | Câu hiện tại | Mã thật trong `sync.service.js` |
|---|---|---|---|
| `docs/Rule_Project/Rule_project.md` | 326 | *"`/sync/push` ánh xạ thành mã lỗi `CONSTRAINT_VIOLATION` (với detail `WALLET_NAME_DUPLICATE`)"* | `code: 'WALLET_NAME_DUPLICATE'` (`:182-184`) |
| `docs/Rule_Project/Rule_project.md` | 423 | *"trả lỗi `BILL_ALREADY_PAID` (ánh xạ thành `CONSTRAINT_VIOLATION`)"* | `code: 'BILL_ALREADY_PAID'` (`:171-173`) |
| `docs/progress/Backend.md` | 512 | *"ánh xạ chi tiết các mã lỗi PostgreSQL `22001` (quá độ dài), `23502` (thiếu trường), `BILL_ALREADY_PAID` (hóa đơn đã trả), `WALLET_NAME_DUPLICATE` sang mã lỗi chuẩn `CONSTRAINT_VIOLATION`"* | chỉ `22001`/`23502` thành `CONSTRAINT_VIOLATION` (`:197-203`); hai mã kia trả **nguyên tên**, và `WALLET_DEFAULT_DUPLICATE` (`:185-187`) không được nhắc |

**Vì sao đáng sửa.** Danh sách mã vĩnh viễn của client là **danh sách trắng**
(`SYNC_PUSH_ERROR_MAPPING.md` mục 3.1). Ai đọc ba câu trên sẽ kết luận client không
phải đổi gì, vì `CONSTRAINT_VIOLATION` đã có trong danh sách. Thật ra ba mã mới đều
rơi xuống `transient` và bị gửi lại mãi, cho tới khi client thêm chúng. Client đã thêm
cả ba ngày 2026-09-11, nhưng bản client cài trước ngày ấy thì vẫn thế.

**Xin giữ mã riêng** — client đã xin chúng — và sửa câu cho khớp mã:

- `Rule_project.md:326` → *"Vi phạm trả SQLSTATE `23505`; `/sync/push` trả
  `code: 'WALLET_NAME_DUPLICATE'`."*
- `Rule_project.md:423`, sau khi sửa B → *"`/sync/push` từ chối giao dịch thứ hai
  cùng `Idbill` chưa xoá mềm, với `code: 'BILL_ALREADY_PAID'`. Đổi `Pay_status`
  của hoá đơn — kể cả hoàn tác về `Pending` — không bị chặn."*
- `Backend.md:512` → *"Ánh xạ `22001`/`P2000` và `23502`/`P2011`/`P2012` sang
  `CONSTRAINT_VIOLATION`; thêm ba mã riêng `BILL_ALREADY_PAID`,
  `WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE`."*

Làm cùng lượt với `RULE_PROJECT_DOC_DRIFT.md`.

---

## 5. Liên quan tới client

- **Client đã gộp `7675b35`** (2026-09-11, sau khi viết tài liệu này), và CSDL dev
  trên máy client **đã áp** `database/12` cùng ngày. Trước khi áp, đo bằng truy vấn chỉ
  đọc: không có cột nào của tệp 12 (`category.Color`, `transaction.Idbill`, bốn cột mới
  của `bill`), `uq_wallet_saving_active` còn, `chk_bill_pay_status` chưa có `'Skipped'`;
  sau khi áp cả ba đã đổi. Ba hồi quy ở tài liệu này nằm ở mã, không ở CSDL, nên vẫn nguyên.
- **Phía client có hai việc:**
  1. ✅ **Đã làm 2026-09-11:** thêm `WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE`
     và cả `BILL_ALREADY_PAID` vào `_permanentCodes` (`sync_engine.dart:1631-1648`),
     canh bởi ba test ở `sync_failure_handling_test.dart`. Hai mã ví do client xin
     (`WALLET_SAVING_INDEX.md` mục 4.2). Xếp `BILL_ALREADY_PAID` vĩnh viễn chỉ ngăn
     việc gửi lại vô ích — không làm hoàn tác bị chặn ở mục 3 chạy được.
  2. Đón `BILL_ALREADY_PAID` theo đúng nghĩa của chốt ở mục 3.4 — tự hoàn tác khoản
     trả cục bộ — chỉ có nghĩa sau khi chốt nằm đúng chỗ **và** client bắt đầu gửi
     `idbill`. Chưa làm.
- **Làm mới hỏng vì 5xx cũng làm app đăng xuất.** `_tryRefreshToken` trả `null` cho
  mọi phản hồi khác 200 và mọi `DioException` (`auth_interceptor.dart:88-119`), rồi
  `onError` xoá token — mô tả mã **trước** 2026-09-11, giữ làm lịch sử vì sao có đề
  xuất này. Cách app đón 503 ở 2.6 là việc của client — ✅ **đã sửa 2026-09-11**
  (`4903c97`, `1edeb49`): chỉ 400/401 do server **trả lời** `/auth/refresh` mới là
  phiên chết, 5xx/mất mạng giữ token; nhiều 401 cùng lúc chờ chung một lượt làm mới
  (spec cưỡng chế đăng xuất §3.8). Đề xuất 503 ở 2.6 vẫn đứng.
- **Cưỡng chế đăng xuất** (spec dẫn ở 2.5) phụ thuộc A: nhánh socket cần bắt tay
  chạy được, và nhánh làm mới cần 2.5.
