# Soát sau gộp `main` @ `29e9a89` (commit gộp client `8d31143`): AIOps Quarantine chặn IP ở đường bình thường của client

**Ngày:** 2026-10-03 · **Phía gửi:** Client-app · **Loại:** đơn xin (**lỗi mã** ở `modules/aiops/` — client không đổi gì).

PR #109 (`7f1a096`, Admin-web thời gian thực + AIOps Sentinel) gộp vào nhánh client ngày 2026-10-03, **không xung đột**,
**không đụng `src/Client-app`** (hash cây giữ nguyên `f65c6734…`). Client soát bằng mã tại HEAD sau gộp, `node --check`
20 tệp JS đổi (0 lỗi), khởi động lại backend dev (10:53, khởi động sạch, `/health` 200) và đo bằng `curl` trên backend
dev. Phần Admin-web (sự kiện `admin_room`, luồng số đo 3 giây, `emitUser*`) **không chạm** client: client chỉ đọc tên
sự kiện nó biết, tên lạ bị bỏ qua.

## 0. Kết luận nhanh

| # | Việc | Mức |
|---|---|---|
| 1 | **Heuristic 4**: một lần `/auth/refresh` trả 401 là IP bị cô lập **15 phút** (mọi route trừ `/api/admin`, kể cả đăng nhập → 403). Mà 401 ở `/auth/refresh` là **đường bình thường** của client — refresh token hết hạn, tài khoản bị khoá / xoá (G36), token bị thu hồi | **lỗi mã — nặng** |
| 2 | IP lấy từ phần tử **đầu** của `X-Forwarded-For` — client tự khai được. Ai cũng **chặn được IP của người khác** bằng một request, và né mọi heuristic bằng cách đổi header | **lỗi mã — bảo mật** |
| 3 | Đếm và chặn **theo IP** phạt cả nhóm dùng chung một IP: CGNAT nhà mạng, Wi-Fi văn phòng / ký túc xá, và môi trường dev (mọi điện thoại qua `adb reverse` + máy ảo đều là `127.0.0.1`) | thiết kế — vừa |
| 4 | Thân 403 mang `error: 'AIOPS_QUARANTINED'`, còn hợp đồng chung dùng khoá **`code`** (`MAINTENANCE_MODE`, `ACCOUNT_INACTIVE`…) | thấp |

## 1. Heuristic 4 — một 401 ở `/auth/refresh` là chặn IP 15 phút

`modules/aiops/feature.collector.js:120-129`:

```js
} else if (status === 401 && path.includes('/refresh')) {
  this.recordTokenReuse();
  if (clientIp && !req.isAdmin) {
    // Heuristic 4: Phát hiện sử dụng token đã thu hồi (Token Hijacking)
    defaultAIOpsQuarantine.quarantine(clientIp, 'Phát hiện tái sử dụng Token đã thu hồi …', 15 * 60 * 1000);
```

Middleware `aiops.quarantine.js:182-205` đứng ở bước **1b** của `app.js` (trước bảo trì, trước mọi route) và trả
**403** cho mọi request của IP ấy, trừ `/api/admin`.

**Vì sao đây là đường bình thường chứ không phải tấn công** — client gọi `/auth/refresh` mỗi khi access token hết hạn,
và nhận 401 trong ít nhất ba trường hợp **không ai tấn công ai**:

1. **Refresh token hết hạn** — người dùng mở lại app sau một thời gian dài.
2. **Tài khoản bị khoá hoặc xoá** — chính backend thiết kế đường này: 401 + `code: ACCOUNT_INACTIVE` / `ACCOUNT_DELETED`
   ở cấp gốc (CAN-LAM 17, 20; client đo đầu-cuối ba ca ngày 2026-09-13, G36). Client dựa vào nó để hiện hộp thoại
   *"tài khoản bị vô hiệu hoá"*.
3. **Refresh token bị thu hồi** — đăng xuất ở máy khác / đổi mật khẩu / admin thu hồi.

Ở cả ba, client đăng xuất người dùng (`ketQuaTuLoiLamMoi`: 400/401 = phiên chết) và đưa về màn Đăng nhập — rồi **mọi lần
đăng nhập trong 15 phút nhận 403** *"Kết nối từ thiết bị của bạn tạm thời bị phong tỏa…"* (màn Đăng nhập hiện nguyên
`message` của server). Ca 2 tệ nhất: admin mở khoá lại tài khoản mà người dùng vẫn bị chặn thêm 15 phút.

**Đo trên backend dev (2026-10-03 10:53, mã sau gộp)** — dùng IP tài liệu `203.0.113.7` (TEST-NET-3) để không chặn
`127.0.0.1` đang phục vụ máy thật:

```
POST /api/auth/refresh  {refreshToken: <token rác>}   X-Forwarded-For: 203.0.113.7  → 401 "Refresh token khong hop le"
GET  /api/auth/profile                                 X-Forwarded-For: 203.0.113.7  → 403 AIOPS_QUARANTINED
GET  /api/auth/profile                                 (không header, 127.0.0.1)     → 401 "Missing or invalid token"
GET  /api/auth/profile                                 X-Forwarded-For: 203.0.113.8  → 401 "Missing or invalid token"
```

**Đề nghị** (backend chọn):
- Bỏ heuristic 4; **hoặc** chỉ đếm 401 mà lý do là **chữ ký sai / token giả** (không phải hết hạn, không phải đã thu hồi,
  không phải tài khoản khoá / xoá), và chỉ cô lập khi **lặp nhiều lần** trong cửa sổ ngắn — giống heuristic 3 đòi 5 lần.
- Không bao giờ cô lập vì một 401 mang `code: ACCOUNT_INACTIVE` / `ACCOUNT_DELETED` — đó là câu trả lời đúng của
  chính backend.

## 2. IP lấy từ `X-Forwarded-For` mà không qua `trust proxy`

`feature.collector.js:53` và `aiops.quarantine.js:189` cùng đọc:

```js
const clientIp = req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress;
```

`app.js:15` đã đặt `app.set('trust proxy', 1)` — tức `req.ip` lấy đúng **một** chặng proxy tin cậy (phần tử **cuối** của
header do proxy thêm vào). Đọc thẳng phần tử **đầu** là bỏ qua cấu hình ấy: phần tử đầu do **client tự khai**.

Hệ quả (đo ở mục 1 — `203.0.113.7` bị chặn chỉ vì một header):
- **Chặn người khác:** một request `/auth/refresh` với token rác và `X-Forwarded-For: <IP nạn nhân>` là IP ấy bị chặn 15
  phút. Lặp lại mỗi 15 phút là chặn vĩnh viễn — một DoS nhắm đích không cần gì ngoài `curl`.
- **Né chặn:** kẻ dò mật khẩu (heuristic 3) hay dội request (heuristic 1) đổi header mỗi lần là không bao giờ bị đếm đủ.

**Đề nghị:** dùng **`req.ip`** ở cả hai chỗ (đã đúng theo `trust proxy`), bỏ đọc thẳng header.

## 3. Đếm theo IP phạt cả nhóm dùng chung IP

Heuristic 1 (> 120 request / 10 giây), 3 (5 lần đăng nhập sai) và 4 đều tính **gộp theo IP**:
- **Ngoài đời:** người dùng di động sau **CGNAT** của nhà mạng, Wi-Fi văn phòng / ký túc xá chung một IP công cộng —
  một người dính là cả nhóm bị chặn.
- **Môi trường dev của nhóm:** mọi điện thoại thật nối qua `adb reverse tcp:3000` và máy ảo (`10.0.2.2`) đều tới backend
  dưới dạng **`127.0.0.1`**. Một máy nhận 401 ở `/auth/refresh` là **cả bàn thử nghiệm** bị chặn 15 phút, kể cả máy
  đang đăng nhập bình thường.

**Đề nghị:** cân nhắc đếm theo **tài khoản / token** cho các heuristic gắn với xác thực; tối thiểu cho phép tắt cô lập
(hoặc miễn trừ loopback) khi `NODE_ENV=development`.

## 4. Khoá mã lỗi

Thân 403 (`aiops.quarantine.js:193-200`) dùng `error: 'AIOPS_QUARANTINED'`. Các mã khác client đọc đều ở khoá **`code`**
(`maintenance.middleware.js`: `code: 'MAINTENANCE_MODE'`; `ResponseHandler.unauthorized(…, {code})`). Đề nghị đổi sang
`code: 'AIOPS_QUARANTINED'` cho cùng hợp đồng.

## 5. Phía client — không đổi gì

- 403 ở `/auth/refresh` được client xếp **tạm thời** (`LamMoiTamThoi`: giữ token, thử lại lần sau) — không đăng xuất
  oan. 401 vẫn là phiên chết như cũ.
- Màn Đăng nhập hiện nguyên `message` của server, nên người dùng bị chặn ít nhất đọc được lý do.
- Client **không** xin thêm gì cho Admin-web (`admin.*`, `user.*` phát tới `admin_room`).

## 6. Câu kiểm sau khi sửa

Trên backend dev (đổi `203.0.113.7` thành một IP tài liệu chưa dùng; danh sách cô lập nằm trong bộ nhớ, khởi động lại là
sạch):

```bash
B=http://127.0.0.1:3000/api
# (mục 1) một 401 ở refresh KHÔNG được làm request kế tiếp nhận 403
curl -s -o /dev/null -w "%{http_code}\n" -H "Content-Type: application/json" \
  -d '{"refreshToken":"eyJhbGciOiJIUzI1NiJ9.eyJpZGFjY291bnQiOjF9.sai"}' $B/auth/refresh      # → 401
curl -s -o /dev/null -w "%{http_code}\n" $B/auth/profile                                   # → 401 (KHÔNG 403)
# (mục 2) không chỗ nào trong modules/aiops đọc thẳng header — kiểm bằng mã, KHÔNG bằng request:
grep -rn "x-forwarded-for" src/Backend/modules/aiops                                    # → 0 dòng
```

⚠️ Đừng kiểm mục 2 bằng cách gửi nhiều lần đăng nhập sai kèm header: khi đã sửa đúng (`req.ip` = `127.0.0.1` trên máy
dev), chính phép kiểm ấy kích heuristic 3 và **chặn `127.0.0.1`** 15 phút — tức chặn mọi máy thật đang nối qua
`adb reverse`.
