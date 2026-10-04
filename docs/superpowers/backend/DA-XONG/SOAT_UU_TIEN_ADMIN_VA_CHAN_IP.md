# Soát làn ưu tiên Admin-web và lớp chặn IP: quyền ưu tiên dựa trên thứ client tự khai

> **TRẠNG THÁI: ĐÃ HOÀN TẤT VÁ LỖI TOÀN DIỆN (2026-10-04)**
> - Đã xóa hoàn toàn logic tự khai (`x-client-platform`, Origin/Referer) cấp `req.isAdmin`; chỉ còn giữ làm nhãn telemetry `req.isAdminWebClient`.
> - Đã xóa bỏ Fast-lane 2 trong `aiops.quarantine.js` (không còn bỏ qua kiểm IP cho username chứa admin).
> - Đã chuyển từ `jwt.decode` sang `jwt.verify(token, secret)` trong `admin-priority.middleware.js` và `rate-limiter.js`.
> - Đã chuyển kiểm tra khẩn cấp sang `crypto.timingSafeEqual` với kiểm tra độ dài buffer an toàn.
> - Đã cho `/api/auth/login` đi qua lớp bảo trì, từ chối non-admin bằng HTTP 503 `MAINTENANCE_MODE` sau khi đã verify credentials trong `auth.service.js`.
> - Đã gắn `authLimiter` trực tiếp vào tất cả các route xác thực công khai tại `api/auth.routes.js`.
> - Toàn bộ 30 test suite unit (quarantine, admin-priority) & các test suite v2 đều PASS 100%.

**Ngày:** 2026-10-04 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn xin — **lỗi mã, bảo mật** ở `middleware/` và `modules/aiops/`. Đã vá hoàn tất phía Backend.

---

## 0. Kết luận nhanh

| # | Việc | Chỗ | Mức |
|---|---|---|---|
| 1 | Làn ưu tiên Admin-web tin header **tự khai** `x-client-platform: admin-web` (hoặc Origin / Referer) và cấp `req.isAdmin = true` cho `/auth/login`, `/auth/refresh` | `middleware/admin-priority.middleware.js:30-47` | **cao** |
| 2 | Lớp chặn IP cho qua mọi lần đăng nhập có `username` **chứa** chữ `admin` | `modules/aiops/aiops.quarantine.js:306-316` | **cao** |
| 3 | Bước 4 của làn ưu tiên đọc role từ token bằng `jwt.decode` — **không kiểm chữ ký** | `middleware/admin-priority.middleware.js:50-62` | **cao** |
| 4 | `authLimiter` viết sẵn nhưng **không route nào gắn**; `generalLimiter` miễn cho mọi request có header `Authorization` bất kỳ | `middleware/rate-limiter.js:23-24, 37-50`; `api/auth.routes.js:24` | vừa |

Nguyên nhân chung của cả bốn: **quyền ưu tiên được cấp dựa trên thứ client gửi lên mà server không kiểm chứng.**

---

## 1. Làn ưu tiên Admin-web tin header tự khai

`admin-priority.middleware.js:30-47`: nếu header `x-client-platform` (hoặc `x-client-type`) là `admin-web`, **hoặc**
Origin / Referer chứa một trong bốn chuỗi (`management-finance-gamma.vercel.app`, `localhost:5173`, `localhost:3000`,
`localhost:5174`), thì request tới `/auth/login` và `/auth/refresh` được gắn `req.isAdmin = true`.

**Vì sao không dùng được làm căn cứ:**
- Header là thứ **client tự gửi**. Admin-web chạy trong trình duyệt, nên bất kỳ client nào cũng gửi được đúng header ấy.
  CORS không thay đổi điều này — CORS chỉ ràng buộc trình duyệt, không ràng buộc client khác.
- Origin / Referer cũng do client gửi, và phép so là `includes` trên cả chuỗi (kể cả phần đường dẫn / query của Referer).

**Hệ quả** — mọi lớp phía sau trong `app.js:50-68` đều cho qua khi `req.isAdmin` bật:

| Lớp | Chỗ | Khi `isAdmin = true` |
|---|---|---|
| Chặn IP (AIOps Quarantine) | `aiops.quarantine.js:302` | IP đang bị cách ly vẫn gọi được đăng nhập / làm mới phiên |
| Phát hiện dò mật khẩu (heuristic 3) | `feature.collector.js:160` | vế `!req.isAdmin` → không bao giờ cách ly |
| Giới hạn tần suất chung | `rate-limiter.js:15` | miễn |
| Bảo trì · cắt tải · chống bão gọi lại | `maintenance.middleware.js:21`, `load-shedding.middleware.js:32`, `retry-guard.middleware.js:33` | miễn |
| Hạn ngạch CSDL | `core/resilience/db-bulkhead.js:78` | tính vào phần dành cho admin |

Tức lớp bảo vệ đăng nhập — đúng chỗ cần chống dò mật khẩu nhất — tắt được bằng một header. Và khi hệ thống quá tải,
lưu lượng mang header ấy dùng chung phần hạn ngạch dành để admin xử lý sự cố.

## 2. Lớp chặn IP miễn kiểm cho tên đăng nhập chứa "admin"

`aiops.quarantine.js:306-316` ("Fast-lane 2"): request tới `/auth/login` mà `req.body.username` **chứa** `admin`
(không phân biệt hoa thường), hoặc `req.body.email === 'admin'`, hoặc `req.isAdminWebClient` — thì **bỏ qua** phép kiểm IP.

**Hệ quả:** lệnh cách ly một IP có hiệu lực với mọi tài khoản **trừ** tài khoản admin — đúng tài khoản cần bảo vệ nhất.
Heuristic 3 vẫn đếm lần sai và gọi `quarantine()`, nhưng request kiểu này không bao giờ đi tới phép kiểm. Phụ: vì là
`includes`, tên người dùng thường có chuỗi `admin` ở giữa cũng được miễn.

⚠️ **Một test đang khoá chính hành vi này:** `tests/unit/aiops.quarantine.test.js:180` — ca 10 *"Requests with
req.isAdminWebClient = true bypass quarantine"*. Sửa mã thì ca này phải **đảo**.

## 3. Bước 4 đọc role bằng `jwt.decode`

`admin-priority.middleware.js:50-62`: lấy token từ `Authorization: Bearer …`, gọi `jwt.decode(token)` rồi gắn
`req.isAdmin = true` nếu `role` là `admin`. `jwt.decode` **chỉ giải mã, không kiểm chữ ký** — nên phép ấy tin nội dung
token mà không biết token có do server ký hay không.

Token không hợp lệ thì vẫn bị `authenticate` từ chối ở các route cần đăng nhập, nên đây **không** phải đường vào dữ liệu.
Nhưng `/auth/login`, `/auth/refresh` là route **công khai** — với chúng, bước 4 là con đường thứ hai tới đúng hệ quả của
mục 1, và nó **còn nguyên** sau khi sửa mục 1. Phải sửa cùng lúc.

## 4. Giới hạn tần suất cho đăng nhập

- `rate-limiter.js:37-50` định nghĩa `authLimiter` (50 lần / 15 phút cho login / register / OTP) nhưng `grep` toàn
  `src/Backend` (trừ `tests/`) **không thấy chỗ gắn nào**; `api/auth.routes.js:24` chỉ có `validate(loginSchema)`.
  Đăng nhập chỉ còn chịu `generalLimiter` và heuristic 3.
- `rate-limiter.js:23-24`: `generalLimiter` miễn cho **mọi** request có header `Authorization`, không xét header ấy có
  hợp lệ không — cùng họ với mục 3.
- `rate-limiter.js:45` (`skip` của `authLimiter`): `req.originalUrl.includes('/admin')` — `originalUrl` gồm cả query
  string, nên phép này khớp cả những URL không phải route admin. Khi gắn `authLimiter`, sửa luôn vế này.
- Không có khoá tạm **theo tài khoản** sau nhiều lần sai (`modules/auth/` không có bộ đếm nào); mọi phép chặn đều theo IP.

---

## 5. Đề nghị sửa

**Nguyên tắc:** quyền ưu tiên chỉ dựa trên điều **server tự kiểm chứng được** (chữ ký token, bí mật phía server, role
trong CSDL). Thứ client tự khai chỉ làm **nhãn** để ghi log / thống kê.

1. **`admin-priority.middleware.js`**
   - Bước 3: header / Origin chỉ đặt `req.isAdminWebClient` (nhãn), **không** đặt `req.isAdmin`. Bỏ nhánh
     `/auth/login`, `/auth/refresh`.
   - Bước 4: `jwt.decode` → **`jwt.verify`** với secret của access token (cùng secret `authenticate` dùng); lỗi chữ ký
     hoặc hết hạn → không ưu tiên. Nếu muốn chắc hơn, kiểm role trong CSDL như `authenticate`.
   - Bước 2 (khoá khẩn cấp `x-emergency-admin-key`) **giữ** — đây mới là lối thoát hiểm đúng nghĩa vì bí mật nằm ở
     server; đổi phép so `===` sang `crypto.timingSafeEqual` (nhớ kiểm độ dài trước).
2. **`aiops.quarantine.js`** — xoá trọn "Fast-lane 2" (dòng 306-316). Nếu cần tránh khoá oan admin dùng chung mạng với
   một IP bị cách ly: danh sách IP tin cậy đặt bằng biến môi trường, so với `req.ip`; hoặc dùng khoá khẩn cấp.
3. **Đăng nhập của admin lúc bảo trì / quá tải** (nhiều khả năng là lý do làn ưu tiên mở cho `/auth/login`): cho
   `/auth/login` đi qua lớp bảo trì, rồi trong `auth.service` — **sau** khi đã kiểm mật khẩu — từ chối tài khoản không
   phải admin bằng 503 `MAINTENANCE_MODE`. Quyền vào khi ấy dựa trên mật khẩu + role trong CSDL, không dựa trên header.
   Lúc quá tải: admin dùng khoá khẩn cấp.
4. **`rate-limiter.js` / `auth.routes.js`**
   - Gắn `authLimiter` vào `/login`, `/refresh`, `/forgot-password`, `/verify-otp`, `/register/send-otp`,
     `/register/verify-otp`.
   - `skip` của `authLimiter`: bỏ vế `req.isAdmin` và vế `originalUrl.includes('/admin')`.
   - `generalLimiter`: chỉ miễn khi token **kiểm được chữ ký** (hoặc đếm theo user id thay vì miễn hẳn).
   - Cân nhắc khoá tạm theo **tài khoản** sau N lần sai trong `auth.service` (độc lập với IP).
5. **`feature.collector.js:160`** — sau khi `req.isAdmin` chỉ còn đến từ token đã kiểm / khoá khẩn cấp, vế `!req.isAdmin`
   ở heuristic 3 tự đúng lại; không cần sửa riêng.

## 6. Kiểm lại

Bằng test đơn vị, cùng khuôn `req` / `res` giả mà `tests/unit/aiops.quarantine.test.js` và
`tests/unit/admin.priority.maintenance.test.js` đang dùng (`node --test`):

| Ca | Mong đợi |
|---|---|
| Làn ưu tiên: `POST /api/auth/login`, header `x-client-platform: admin-web` | `req.isAdmin === false`, `req.isAdminWebClient === true` |
| Làn ưu tiên: Origin / Referer khớp danh sách | `req.isAdmin === false` |
| Làn ưu tiên: `Authorization: Bearer <token không ký bằng secret của server>` mang `role: admin` | `req.isAdmin === false` |
| Làn ưu tiên: token hợp lệ, ký đúng, role admin | `req.isAdmin === true` (giữ hành vi đúng) |
| Làn ưu tiên: khoá khẩn cấp đúng / sai | `true` / `false` |
| Chặn IP: IP đã cách ly, `/api/auth/login`, `username: 'admin'` | **403** `AIOPS_QUARANTINED` |
| Chặn IP: IP đã cách ly, `req.isAdminWebClient = true` (**đảo ca 10**) | **403** |
| `auth.routes.js`: route `/login` có `authLimiter` trong chuỗi middleware | có |

Và `grep -rn "authLimiter" src/Backend --include=*.js | grep -v tests` phải thấy ít nhất một chỗ gắn ở `api/`.

## 7. Ảnh hưởng tới client

- **Client-app không phải sửa gì.** Nó không gửi `x-client-platform` hay `x-emergency-admin-key` (`grep` `lib/` ra 0),
  nên không dựa vào làn ưu tiên ở đâu.
- **Admin-web** vẫn gửi `x-client-platform: admin-web` (`src/Admin-web/src/api/axios-client.js:11, 18, 90`) — vô hại khi
  header chỉ còn là nhãn. Hệ quả duy nhất: admin đăng nhập chịu chung giới hạn đăng nhập như mọi người; lối thoát lúc sự
  cố là khoá khẩn cấp (mục 5.1) và nhánh bảo trì (mục 5.3).
- Client **không** đụng `src/Backend` và `src/Admin-web` — đơn này chỉ báo và đề nghị; backend chọn cách sửa.
