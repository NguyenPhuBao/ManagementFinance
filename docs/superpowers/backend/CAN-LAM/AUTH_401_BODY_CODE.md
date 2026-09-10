# Body 401 không mang `code` / `reason_inactive` — nhánh HTTP của cưỡng chế đăng xuất chưa bao giờ chạy

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** vài
dòng ở `core/response-handler.js`, cộng một hàm dựng lý do từ chối dùng chung
cho HTTP và socket. Không migration.

---

## 1. Tóm tắt

`middleware/auth.js:89-93` gọi:

```js
return ResponseHandler.unauthorized(res, errorMsg, {
  code: isInactive ? 'ACCOUNT_INACTIVE' : 'ACCOUNT_DELETED',
  idaccount: Number(decoded.idaccount),
  reason_inactive: accountInfo.reason_inactive || null,
});
```

nhưng `unauthorized(res, message)` ở `core/response-handler.js:32-34` chỉ nhận
**hai** tham số. Đối số thứ ba rơi mất, nên body 401 thật **không có** `code`,
`idaccount` lẫn `reason_inactive`.

JSON mẫu mà bốn tài liệu dựa vào **chưa từng được sinh ra**:
`docs/Rule_Project/Rule_project.md` 11.3 (dòng 535–542) và 11.5 (dòng 570),
`docs/progress/Client-app.md` 10.3 và 11.3, `docs/progress/Backend.md` 12.1
(dòng 237) và 12.4 (dòng 265). Chỉ kênh socket `account.force_logout` mang mã.

Hệ quả: client không phân biệt được *tài khoản bị khoá hay xoá* với *token hết
hạn*, nên nhánh HTTP của cưỡng chế đăng xuất — dành cho người dùng **ngoại
tuyến** lúc bị khoá rồi mở app lại — không có gì để đọc. **Xin sửa để body mang
mã ở cấp gốc**, đúng hình dạng các tài liệu trên đã mô tả.

---

## 2. Đo được gì — 2026-09-10

### 2.1. Body thật

Chạy `ResponseHandler` với một đối tượng `res` giả — không cần CSDL, không gửi
request nào:

```bash
cd src/Backend && node -e "
const R=require('./core/response-handler');
const mk=()=>({locals:{},status(c){this.c=c;return this},json(b){console.log(this.c, JSON.stringify(b));return this}});
R.unauthorized(mk(),'Tài khoản đã bị vô hiệu hóa. Lý do: test',{code:'ACCOUNT_INACTIVE',idaccount:10,reason_inactive:'test'});
R.error(mk(),'msg',401,{code:'ACCOUNT_INACTIVE'});"
```

```
401 {"success":false,"message":"Tài khoản đã bị vô hiệu hóa. Lý do: test","errors":null,"timestamp":"2026-09-10T10:35:57.129Z"}
401 {"success":false,"message":"msg","errors":{"code":"ACCOUNT_INACTIVE"},"timestamp":"2026-09-10T10:35:57.135Z"}
```

Dòng thứ hai là lý do tài liệu này **không** đề xuất lối tắt "đổi sang
`ResponseHandler.error(res, msg, 401, extra)`": mã khi ấy nằm dưới `errors`,
còn các tài liệu hướng dẫn client đọc `resData['code']` ở cấp gốc.

### 2.2. Mọi chỗ trả 401

Quét bằng script toàn `src/Backend` (trừ `node_modules`), tìm `unauthorized(`
và `forbidden(`:

| Chỗ | Tình huống | Có cần mã không |
|---|---|---|
| `middleware/auth.js:68` | thiếu header `Authorization` | không |
| `middleware/auth.js:77` | token hết hạn | không — client đi làm mới token |
| `middleware/auth.js:79` | token sai chữ ký | không |
| `middleware/auth.js:89` | tài khoản bị khoá, xoá, hoặc hết hạn chờ xoá | **có — định gửi, bị rơi** |
| `middleware/authorize.js:6` | route cần xác thực mà chưa có `req.user` | không |
| `modules/sync/sync.controller.js:27` | mọi thao tác đẩy đều vỡ `ACCOUNT_NOT_FOUND` | nên có — xem 4.3 |

Chỉ **một** chỗ truyền tham số thứ ba, và đó đúng là chỗ duy nhất cần nó.

### 2.3. Socket handshake gắn sai mã cho tài khoản bị khoá

`core/socket.js:39-44` dùng `isAccountValid` (chỉ trả boolean), rồi **luôn** gắn
`data: { code: 'ACCOUNT_DELETED', idaccount }` — kể cả với tài khoản `Inactive`,
và không kèm `reason_inactive`. Trong khi đó `emitForceLogout`
(`core/socket.js:170-189`, gọi từ `admin.service.js:140`) phát
`reason: 'ACCOUNT_INACTIVE'` đúng.

Nên cùng một tài khoản bị khoá: máy **đang online** nhận `ACCOUNT_INACTIVE` kèm
lý do; máy **kết nối lại sau đó** nhận `ACCOUNT_DELETED`, không lý do. Hai chỗ tự
dựng mã riêng và đã lệch nhau — đó là lý do 4.2 xin gom về một hàm.

### 2.4. Không có test nào canh

Quét `*.test.js` / `*.spec.js` toàn `src/Backend`: **2** tệp, cả hai của AI
phân loại (`modules/ai/features/classify/__tests__/`); **0** chỗ nhắc
`ACCOUNT_INACTIVE`, `reason_inactive` hay `unauthorized`. Năm script
`Test/test_*.js` mà `docs/progress/Backend.md` mục 10 ghi "100% PASS" **không có
trong repo** — xem `RULE_PROJECT_DOC_DRIFT.md` mục 2.4.

### 2.5. Trên CSDL dev hôm nay, nhánh này thậm chí không tới được

`getAccountValidity` chọn `reason_inactive` và `countdown`, mà Prisma Client
trong `node_modules` sinh trước khi có hai cột ấy, nên phép truy vấn ném lỗi và
`catch` ở `middleware/auth.js:47-50` trả `valid: true`. Không một 401 nào được
phát cho tài khoản bị khoá. Đó là mục 11 của `README.md`
(`DEV_DB_MIGRATIONS_7_11.md` mục 3.1 và 4.3).

**Thứ tự đúng:** làm mục 11 trước, rồi mới kiểm được tài liệu này đầu-cuối. Sửa
tài liệu này trước cũng không hại gì — chỉ là chưa đo được bằng request thật.

---

## 3. Client hôm nay làm gì khi gặp 401 ấy

Đọc mã client ngày 2026-09-10:

1. `lib/core/api/interceptors/auth_interceptor.dart:53-85`: mọi 401 → gọi
   `/auth/refresh` → thử lại request gốc. Làm mới hỏng thì xoá token và phát
   `sessionExpiredStream` để `AuthBloc` đưa về màn đăng nhập.
2. `/auth/refresh` (`modules/auth/auth.service.js:368-411`) **không kiểm trạng
   thái tài khoản** — chỉ kiểm refresh token còn hạn và chưa bị thu hồi. Nhánh
   vô hiệu hoá (`admin.service.js:127-141`) cũng không thu hồi refresh token.
3. Nên với tài khoản `Inactive`: làm mới token **thành công**, request thử lại
   vẫn 401, lúc ấy interceptor mới xoá token. Người dùng về màn đăng nhập như một
   phiên hết hạn bình thường — **không một chữ nào về lý do**.

Phần client còn thiếu là việc **của client** và chưa làm: `realtime_event.dart`
chỉ nhận ba sự kiện (`bank_transaction.incoming`, `ocr.completed`,
`ocr.duplicate`) nên `account.force_logout` bị bỏ qua, và `UserModel` không đọc
`status` / `countdown`. Nhánh **socket** client làm được ngay, không cần gì từ
tài liệu này. Nhánh **HTTP** thì chờ mục 4.1.

---

## 4. Việc cần làm

### 4.1. `ResponseHandler.unauthorized` nhận thêm `extra`, trải ở cấp gốc

```js
static unauthorized(res, message = 'Unauthorized', extra = null) {
  if (!extra) return this.error(res, message, 401);
  if (res.locals) res.locals.errorMessage = message;
  return res.status(401).json({
    success: false,
    message,
    ...extra, // code, idaccount, reason_inactive — ở CẤP GỐC
    errors: null,
    timestamp: new Date().toISOString(),
  });
}
```

Không đổi chữ ký của `error()`: nhiều chỗ khác dùng `errors` cho danh sách lỗi
kiểm tra đầu vào (`sync.controller.js:15`).

Body kỳ vọng sau khi sửa:

```json
{
  "success": false,
  "message": "Tài khoản đã bị vô hiệu hóa. Lý do: …",
  "code": "ACCOUNT_INACTIVE",
  "idaccount": 10,
  "reason_inactive": "…",
  "errors": null,
  "timestamp": "…"
}
```

JSON mẫu ở `Rule_project.md` 11.3 có thêm `"statusCode": 401`. Client không cần
trường ấy vì đọc mã HTTP từ chính phản hồi — xin **sửa mẫu** cho khớp hình dạng
trên thay vì thêm trường.

### 4.2. Một hàm dựng lý do từ chối, dùng chung cho HTTP và socket

```js
// middleware/auth.js
function accountRejection(info, idaccount) {
  const inactive = info.status?.toLowerCase() === 'inactive';
  return {
    message: inactive
      ? (info.reason_inactive
          ? `Tài khoản đã bị vô hiệu hóa. Lý do: ${info.reason_inactive}`
          : 'Tài khoản đã bị vô hiệu hóa')
      : 'Account no longer exists or has been deleted',
    data: {
      code: inactive ? 'ACCOUNT_INACTIVE' : 'ACCOUNT_DELETED',
      idaccount: Number(idaccount),
      reason_inactive: info.reason_inactive || null,
    },
  };
}
```

- `authenticate` (`middleware/auth.js:83-94`):
  `const r = accountRejection(accountInfo, decoded.idaccount);`
  `return ResponseHandler.unauthorized(res, r.message, r.data);`
- `core/socket.js:39-44`: đổi `isAccountValid` sang `getAccountValidity` (đã
  export sẵn), rồi `next(Object.assign(new Error(r.message), { data: r.data }))`.

Tài khoản `PendingDelete` đã quá hạn và tài khoản `Deleted` cùng rơi vào
`ACCOUNT_DELETED` — client xử lý hai ca ấy như nhau.

### 4.3. Ba chỗ phụ — không chặn client

- **`sync.controller.js:26-28`** trả 401 `'Account no longer exists'` không mã.
  Nên gắn `{ code: 'ACCOUNT_DELETED', idaccount }` cùng khuôn 4.1. Chỉ tới được
  khi middleware đã cho qua: lỗi truy vấn (2.5) hoặc bộ nhớ đệm 60 giây
  (`middleware/auth.js:10`).
- **Đăng nhập 403** (`auth.service.js:311-332` → `auth.controller.js:58-61`):
  lỗi mang `reason_inactive` nhưng controller chỉ trả `message`. Lý do vẫn nằm
  trong câu chữ nên client hiện được. Xin thêm một `code` ổn định để client khỏi
  phải đoán từ câu tiếng Việt — tên mã do backend chọn, cho ba ca *bị khoá*,
  *đã xoá*, *hết 30 ngày khôi phục*.
- **`/auth/refresh` không kiểm trạng thái tài khoản** (mục 3). Nếu sửa, trả 401
  cùng body 4.1, để client dừng ngay thay vì làm mới thành công rồi vỡ ở request
  kế tiếp.

---

## 5. Kiểm lại sau khi sửa

1. Chạy lại lệnh ở 2.1. Dòng đầu phải có `"code":"ACCOUNT_INACTIVE"` ở cấp gốc.
2. Đầu-cuối, **sau khi xong mục 11**: vô hiệu hoá một tài khoản thử qua
   Admin-web, rồi gọi API bằng access token còn hạn của nó:
   ```bash
   curl -s -i -H "Authorization: Bearer <access_token>" http://localhost:3000/api/sync/status
   ```
   Kỳ vọng `HTTP/1.1 401` và body có `code`, `idaccount`, `reason_inactive`.
3. Socket: kết nối bằng chính token ấy. `connect_error` phải mang
   `err.data.code === 'ACCOUNT_INACTIVE'` kèm `reason_inactive`.

Rồi báo lại ở đây; client nối nhánh HTTP của cưỡng chế đăng xuất.

---

## 6. Liên quan tới client

- Nhánh socket (`account.force_logout`) không phụ thuộc tài liệu này.
- Yêu cầu gốc về phía client nằm ở `docs/progress/Client-app.md` mục 10–12. Mã
  mẫu ở 10.3 và 11.3 đọc `resData['code']` — chạy được ngay khi 4.1 xong, không
  cần đổi tài liệu ấy.
