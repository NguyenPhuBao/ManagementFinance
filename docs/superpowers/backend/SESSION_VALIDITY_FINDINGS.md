# Phiên đăng nhập vẫn dùng được sau khi tài khoản đã bị xoá

**Người nhận:** đội Backend
**Bối cảnh:** sự cố ngày 2026-09-02 — client liên tục nhận lỗi vỡ khoá ngoại `fk_category_account` / `fk_transaction_account` khi thêm danh mục.
**Trạng thái:** phía Client-app đã xử lý xong (chi tiết ở mục 5). Tài liệu này ghi lại **các điểm thuộc backend** để đội backend cân nhắc — chưa có dòng mã backend nào bị thay đổi.

---

## 1. Chuyện gì đã xảy ra

CSDL bị reset/xoá dữ liệu, nhưng sequence `Idaccount` không reset. Người dùng đăng ký lại và nhận `idaccount = 10`, trong khi thiết bị vẫn giữ access token JWT cấp cho `idaccount = 9` — một tài khoản không còn tồn tại.

Dòng thời gian dựng lại từ bảng `auditlog` (dữ liệu thật):

| idlog | idaccount | Request | Thời điểm |
|---|---|---|---|
| 121 | 10 | Đăng ký tài khoản | 06:20:31 |
| 122 | 10 | Đăng nhập hệ thống | 06:20:37 |
| 123 | 10 | Tải dữ liệu đồng bộ (Pull) | 06:20:37 |
| 124 | 10 | Đồng bộ dữ liệu (Push) — Pass | 06:20:37 |

Đáng chú ý: **`auditlog` không có một dòng nào của `idaccount = 9`** — toàn bộ dấu vết của tài khoản đó đã bị xoá cùng dữ liệu.

Trạng thái CSDL khi điều tra: bảng `account` chỉ còn `1 (admin)` và `10 (dat)`; `refreshtoken` chỉ có token của account 10; toàn bộ ví và giao dịch đều thuộc account 10.

### Vì sao request của một tài khoản đã bị xoá vẫn đi lọt

1. `middleware/auth.js` chấp nhận token → `req.user.idaccount = 9`.
2. `sync.service.js` so `payload.idaccount` với `req.user.idaccount` → **9 === 9, hợp lệ**, không có "Ownership mismatch".
3. `sync.repository.js` gọi `prisma.category.create({ create_by: 9 })`.
4. PostgreSQL từ chối: `fk_category_account` — account 9 không tồn tại.

Lỗi chỉ nổ ở tầng cuối cùng là CSDL, sau khi đã đi qua toàn bộ các lớp xác thực và phân quyền.

---

## 2. Ba điểm thuộc backend

### F1 — `middleware/auth.js` không kiểm tra tài khoản còn tồn tại — **Cao**

`authenticate()` chỉ làm đúng hai việc: `jwt.verify(token, config.jwt.accessSecret)` rồi `req.user = decoded`. Không có truy vấn CSDL nào.

Hệ quả: một access token của tài khoản đã bị xoá vẫn được chấp nhận **cho tới khi hết hạn** (hiện là 7 ngày). Trong suốt thời gian đó, mọi request ghi dữ liệu đều thất bại ở tầng khoá ngoại, và client không có cách nào biết nguyên nhân là "tài khoản không còn tồn tại".

> **Điểm tích cực cần ghi nhận:** `/auth/refresh` **làm đúng**. `auth.service.js` truy vấn `prisma.refreshtoken.findUnique({ where: { token_hash } })` và trả **401** khi không tìm thấy. Vì `refreshtoken` cascade-delete theo `account`, tài khoản bị xoá sẽ khiến refresh thất bại đúng như mong đợi.
>
> Nghĩa là lỗ hổng **chỉ nằm ở access token**, không phải toàn bộ hệ thống xác thực. Phạm vi cần vá hẹp hơn nhiều so với thoạt nhìn.

### F2 — `/auth/me` không chạm CSDL — **Trung bình**

`auth.controller.js:77-86` trả thẳng dữ liệu từ `req.user`, tức payload trong JWT:

```js
async me(req, res) {
  return ResponseHandler.success(res, {
    idaccount: req.user.idaccount,
    username: req.user.username,
    // ...
  }, 'Token hợp lệ');
}
```

Endpoint này trả **200 "Token hợp lệ"** cho cả tài khoản đã bị xoá. Nếu ai đó dùng nó làm phép kiểm tra phiên thì sẽ nhận kết quả sai. Client hiện **không** gọi `/auth/me`, và đã ghi chú rõ là không được dùng nó cho mục đích này.

Endpoint duy nhất thật sự truy vấn CSDL là **`GET /auth/profile`** — `auth.service.js:471-473` trả **404** khi không tìm thấy dòng `user`. Client đang dùng đúng endpoint này.

### F3 — `/sync/push` trả HTTP 200 kể cả khi mọi thao tác đều thất bại — **Trung bình**

`sync.controller.js` luôn kết thúc bằng `ResponseHandler.success(...)`, kết quả từng thao tác nằm trong mảng `results[]`.

Hệ quả: interceptor phía client (vốn chỉ phản ứng với HTTP 401) **không bao giờ được kích hoạt**. Một lỗi xác thực bị che sau một response mang mã "thành công", và client phải đoán nguyên nhân bằng cách đọc chuỗi thông báo lỗi của Prisma — cách làm dễ vỡ khi đổi tên constraint hoặc nâng version Prisma.

---

## 3. Đề xuất

### Đề xuất 1 — Xác minh tài khoản trong `authenticate()` (giải quyết F1)

Thêm một bước kiểm tra tài khoản còn tồn tại và đang hoạt động:

```js
const account = await prisma.account.findUnique({
  where: { idaccount: decoded.idaccount },
  select: { idaccount: true, status: true },
});
if (!account) {
  return ResponseHandler.unauthorized(res, 'Account no longer exists');
}
```

> **Cảnh báo về hiệu năng:** làm thẳng như trên sẽ thêm **một truy vấn CSDL cho mỗi request đã xác thực**. Nên có cache ngắn (in-memory TTL 30–60 giây theo `idaccount`, hoặc Redis nếu đã có sẵn) và xoá cache khi tài khoản bị xoá/đình chỉ. Với một đồ án tốt nghiệp, cache in-memory là đủ.
>
> **Phương án nhẹ hơn nếu ngại chi phí:** chỉ kiểm tra ở các route ghi dữ liệu (`/sync/push`, `/admin/*`), bỏ qua các route chỉ đọc. Vá được đúng chỗ đau mà gần như không tốn thêm gì.

### Đề xuất 2 — Trả mã lỗi máy đọc được thay vì để client đoán chuỗi (giải quyết F3)

Khi `processPush` bắt được lỗi vỡ khoá ngoại tới bảng `account`, nên trả kèm một mã ổn định trong `results[i]`, ví dụ:

```json
{ "localId": "...", "status": "failed", "code": "ACCOUNT_NOT_FOUND",
  "message": "Foreign key constraint violated: fk_category_account" }
```

Client hiện phải nhận diện bằng regex `fk_\w+_account` trên thông báo lỗi Prisma — chạy được nhưng sẽ hỏng âm thầm nếu constraint đổi tên. Một trường `code` ổn định sẽ loại bỏ hẳn sự phụ thuộc đó.

Cân nhắc thêm: nếu **toàn bộ** thao tác trong batch thất bại vì tài khoản không tồn tại, trả HTTP **401** thay vì 200 — khi đó interceptor chuẩn của client sẽ tự xử lý.

### Đề xuất 3 — Ghi chú vào tài liệu (giải quyết F2)

Ghi rõ trong tài liệu API: **`/auth/me` không dùng để kiểm tra phiên còn hiệu lực** (chỉ giải mã JWT). Dùng `/auth/profile` nếu cần xác minh thật.

---

## 4. Mức ưu tiên

| # | Việc | Ưu tiên | Công sức |
|---|---|---|---|
| 1 | Kiểm tra account tồn tại trong `authenticate()` (có cache) | **Cao** | Trung bình |
| 2 | Trả `code` ổn định trong `results[]` của `/sync/push` | Trung bình | Thấp |
| 3 | Ghi chú `/auth/me` không dùng để kiểm phiên | Thấp | Rất thấp |

Không mục nào **bắt buộc** để hệ thống chạy — phía client đã tự bảo vệ được. Đây là các lớp phòng vệ chiều sâu, và mục 1 là thứ duy nhất chặn được vấn đề tận gốc.

---

## 5. Phía Client-app đã làm gì (để backend không làm trùng)

| Việc | Cách làm |
|---|---|
| Xác minh phiên khi mở app | Gọi `GET /auth/profile`; nhận 401/404 → đăng xuất, không khởi động đồng bộ |
| Phát hiện ngay khi đang chạy | Nhận diện lỗi `fk_*_account` lúc đẩy dữ liệu → hỏi lại server → đăng xuất nếu server phủ nhận |
| Giữ được offline-first | Mất mạng / lỗi 5xx → **không** đăng xuất, giữ nguyên phiên |
| Không tự suy ra danh tính | Bỏ đoạn lấy `idaccount` từ dữ liệu SQLite cục bộ |
| Dọn dữ liệu tài khoản cũ | Khi đăng nhập, xoá các dòng thuộc tài khoản khác trên máy |
| Hết thử lại vô ích | Lỗi vĩnh viễn không còn được gửi lại mỗi chu kỳ |

Client **không** dựa vào việc backend sẽ sửa gì. Các đề xuất ở mục 3 chỉ làm hệ thống chắc chắn hơn, không phải điều kiện để client hoạt động.

---

## 6. Cách kiểm chứng

Tái hiện sự cố trên môi trường dev:

```sql
-- 1. Đăng nhập bằng một tài khoản test, giữ nguyên app đang chạy
-- 2. Xoá tài khoản đó khỏi CSDL
DELETE FROM "account" WHERE "Idaccount" = <id_tai_khoan_test>;
-- 3. Trong app, thử thêm một danh mục mới
```

- **Hiện tại:** request đi lọt qua `authenticate()`, vỡ khoá ngoại ở tầng CSDL, `/sync/push` vẫn trả 200.
- **Sau Đề xuất 1:** request bị chặn ngay tại middleware với **401**.

Kiểm tra `/auth/me` vẫn trả 200 cho token của tài khoản đã xoá — đó là biểu hiện của F2.

---

## 7. Ghi chú

Toàn bộ điều tra chỉ **đọc** mã nguồn và **truy vấn chỉ đọc** vào CSDL (`findMany`, `count`, `groupBy`). **Không có dòng mã backend nào bị thay đổi, không có dữ liệu nào bị sửa.** Mọi thay đổi mã nguồn đều nằm trong `src/Client-app/`.

Xem thêm: `CATEGORY_CLASSIFY_ALIGNMENT.md` (cùng thư mục) — một vấn đề khác cần backend quyết định, không liên quan tới tài liệu này.
