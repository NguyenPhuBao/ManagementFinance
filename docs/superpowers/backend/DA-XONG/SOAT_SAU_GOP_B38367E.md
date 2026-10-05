# Soát sau gộp `main` @ `b38367e`: đơn 35 đạt; lách lớp bảo trì bằng query string và bốn chỗ nhẹ

**Ngày:** 2026-10-05 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat` (commit gộp `9abb785`)
**Loại:** đơn xin — **một lỗi mã mức vừa** ở `middleware/maintenance.middleware.js` và **bốn chỗ nhẹ**. Không đụng
đồng bộ, không đổi lược đồ. **Client-app không phải sửa gì.**

---

## 0. Kết luận nhanh

Đơn 35 (`DA-XONG/SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md`) **đạt cả bốn mục**: header tự khai chỉ còn là nhãn, "Fast-lane 2"
đã xoá, bước 4 dùng `jwt.verify` với **cùng** `config.jwt.accessSecret` mà `middleware/auth.js:100,131` dùng,
`authLimiter` gắn vào 8 route công khai. Cả tám ca kiểm ở mục 6 của đơn có test tương ứng (`admin.priority.maintenance`
ca 12–16, `aiops.quarantine` ca 9–11). `node --test tests/unit/*.test.js` → **166/166 pass** (đo 2026-10-05).

Còn lại:

| # | Việc | Chỗ | Mức |
|---|---|---|---|
| 1 | Lớp bảo trì cho qua mọi URL có **chứa** `/auth/login`, kể cả trong query string | `middleware/maintenance.middleware.js:23-24` | **vừa** |
| 2 | Hai lớp kiểm chữ ký token rơi về khoá `'secret'` khi thiếu `JWT_ACCESS_SECRET`, và không có phép kiểm lúc khởi động | `middleware/admin-priority.middleware.js:20`, `middleware/rate-limiter.js:29` | nhẹ (cấu hình) |
| 3 | Đường `/api/admin/*` được gắn `req.isAdmin = true` **trước khi xác thực** | `middleware/admin-priority.middleware.js:26-29` (+ cùng phép ở các lớp sau) | nhẹ |
| 4 | Lớp cắt tải coi là môi trường test hễ **đường dẫn tiến trình** có chữ `test` | `middleware/load-shedding.middleware.js:25` | nhẹ |
| 5 | CORS cho phép mọi project Vercel tên bắt đầu bằng `management-finance` / `managementfinance` | `config/cors.js:34` | nhẹ |
| 6 | Chưa có test cho nhánh `auth.service` từ chối tài khoản không phải admin lúc bảo trì | `modules/auth/auth.service.js:~367` | test |

---

## 1. Lách lớp bảo trì bằng query string (mức vừa)

`maintenance.middleware.js:23-24`:

```js
const isLoginRoute = (req.path && req.path.includes('/auth/login')) ||
  (req.originalUrl && req.originalUrl.includes('/auth/login'));
```

`req.originalUrl` **gồm cả query string**, và phép so là `includes`. Nên mọi request có `/auth/login` ở bất kỳ đâu
trong URL đều qua được lớp bảo trì.

**Đo bằng chính middleware** (chạy từ `src/Backend`, bảo trì giả lập đang BẬT):

```bash
node -e "
const {createMaintenanceMiddleware}=require('./middleware/maintenance.middleware');
const m=createMaintenanceMiddleware({manager:{isMaintenanceActive:()=>true,getStatus:()=>({})}});
function thu(path,originalUrl){let qua=false,ma=null;const res={setHeader(){},status(c){ma=c;return{json(){}}}};
  m({path,originalUrl,isAdmin:false},res,()=>{qua=true});console.log(qua?'CHO QUA':'CHAN '+ma, originalUrl);}
thu('/api/sync/push','/api/sync/push');
thu('/api/sync/push','/api/sync/push?x=/auth/login');
thu('/api/transactions','/api/transactions?r=/auth/login');
thu('/api/auth/login','/api/auth/login');"
```

Kết quả 2026-10-05:

```
CHAN 503 /api/sync/push
CHO QUA /api/sync/push?x=/auth/login
CHO QUA /api/transactions?r=/auth/login
CHO QUA /api/auth/login
```

**Hệ quả:** lúc bảo trì, người dùng thường gọi được **mọi** API bằng cách thêm `?x=/auth/login`. Vẫn cần token hợp
lệ nên không phải đường vào dữ liệu người khác, nhưng công tắc bảo trì mất tác dụng — đúng thứ nó sinh ra để ngăn
(ghi trong lúc nâng cấp CSDL, v.v.). Đây là cùng họ lỗi `originalUrl.includes(…)` mà đơn 35 mục 4 đã nêu cho
`authLimiter`.

**Đề nghị sửa:** so **đường dẫn đầy đủ, không query**, và **so bằng**, không `includes`:

```js
const duongDan = (req.originalUrl || '').split('?')[0];      // hoặc req.baseUrl + req.path
const isLoginRoute = req.method === 'POST' && duongDan === '/api/auth/login';
```

⚠️ Ở `app.use(defaultMaintenance)` (mount ở gốc, `app.js:57`) thì `req.path` **là** đường dẫn đầy đủ không query,
nên `req.path === '/api/auth/login'` cũng đúng — nhưng đừng giữ vế `originalUrl.includes`. Cùng lượt, soát các phép
`includes` / `startsWith` trên `originalUrl` còn lại (`grep -rn "originalUrl" middleware modules/aiops --include=*.js`):
`startsWith('/api/admin')` không bị query đánh lừa, `includes` thì có.

**Test đề nghị** (thêm vào `tests/unit/admin.priority.maintenance.test.js`): bảo trì BẬT, `originalUrl:
'/api/sync/push?x=/auth/login'`, `path: '/api/sync/push'` → **503 `MAINTENANCE_MODE`**; `GET /api/auth/login` → 503
(chỉ `POST` là đăng nhập).

## 2. Khoá dự phòng `'secret'` (nhẹ, cấu hình)

`admin-priority.middleware.js:20` và `rate-limiter.js:29`:

```js
... || process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || 'secret'
```

Còn `authenticate` (`middleware/auth.js:100`) dùng thẳng `config.jwt.accessSecret` (= `process.env.JWT_ACCESS_SECRET`,
`config/index.js:18`). Không có phép kiểm biến ấy lúc khởi động (`grep JWT_ACCESS_SECRET` trong `config/`, `index.js`,
`core/` chỉ ra dòng 18).

**Hệ quả khi một bản triển khai quên đặt `JWT_ACCESS_SECRET`:** `authenticate` từ chối mọi token (thấy ngay, sẽ được
sửa), nhưng **trong lúc ấy** hai lớp này nhận token tự ký bằng chữ `secret` mang `role: admin` → `req.isAdmin = true`
→ miễn chặn IP, bảo trì, cắt tải, giới hạn tần suất (mọi lớp phía sau trong `app.js:50-69`).

**Đề nghị sửa:** bỏ hẳn vế `'secret'` (và `JWT_SECRET` nếu không còn dùng), lấy đúng `config.jwt.accessSecret`; thiếu
secret thì **không ưu tiên** (coi như không có token). Và kiểm lúc khởi động theo đúng khuôn đã có của
`BLIND_INDEX_SECRET` (`utils/crypto.util.js:28-31`): production thiếu `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` → từ
chối khởi động.

## 3. `/api/admin/*` được ưu tiên trước khi xác thực (nhẹ, có từ trước)

`admin-priority.middleware.js:26-29` gắn `req.isAdmin = true` cho mọi URL bắt đầu bằng `/api/admin` — **trước**
`authenticate`. Các lớp sau còn tự lặp lại phép ấy (`aiops.quarantine.js` trong `createMiddleware`,
`maintenance.middleware.js:26-28`, `load-shedding.middleware.js` bước 1, `rate-limiter.js:16`).

**Hệ quả:** request **chưa đăng nhập** tới `/api/admin/*` được miễn chặn IP, giới hạn tần suất, cắt tải và bảo trì,
và tính vào phần hạn ngạch CSDL dành cho admin (`core/resilience/db-bulkhead.js`). Route vẫn đòi token admin nên
**không** lộ dữ liệu, nhưng đó là đường để một IP đã bị cách ly dội lưu lượng vào máy chủ đúng lúc quá tải. Nó đi
ngược nguyên tắc đơn 35 vừa chốt: *"chỉ ưu tiên dựa trên điều server tự kiểm chứng được"* — đường dẫn URL là thứ client
tự chọn.

**Đề nghị sửa:** bỏ bước 1 (đường dẫn) khỏi làn ưu tiên và bỏ vế `startsWith('/api/admin')` ở các lớp sau; Admin-web
gọi `/api/admin/*` luôn kèm token admin nên bước 4 (`jwt.verify`) đã cấp ưu tiên đúng. Riêng `/health/admin` nếu cần
cho probe thì để lớp nào cần tự miễn theo đúng đường dẫn health.

## 4. Lớp cắt tải nhận diện môi trường test bằng đường dẫn (nhẹ)

`load-shedding.middleware.js:25`:

```js
const isTestEnv = process.env.NODE_ENV === 'test' || Boolean(process.env.NODE_TEST_CONTEXT) || process.argv.some(a => a.includes('test'));
```

`process.argv[1]` là **đường dẫn tuyệt đối** của `index.js`. Đo 2026-10-05 trên máy dev của client (repo ở
`D:\test_kltn\…`): một tệp chạy bằng `node` trong `src/Backend` có `argv = ["…node.exe",
"D:\\test_kltn\\ManagementFinance\\src\\Backend\\…js"]` → `isTestEnv === true` → **warmup 45 s bị tắt** ở backend dev
đang chạy thật. Trên máy chủ, bất kỳ đường dẫn triển khai nào có chữ `test` (thư mục `test`, `latest`, `contest`…)
cũng dính.

**Đề nghị sửa:** bỏ vế `process.argv`. `node --test` đã đặt `NODE_TEST_CONTEXT` cho tiến trình con; nếu vẫn cần, so
**tên tệp** (`path.basename(a).endsWith('.test.js')`) chứ không so cả đường dẫn. Hoặc test truyền
`options.warmupMs = 0` như các test khác đã làm.

## 5. CORS: mọi project Vercel cùng tiền tố (nhẹ)

`config/cors.js:34`: `/^https:\/\/(management-finance|managementfinance)[a-z0-9-]*\.vercel\.app$/`. Tên project
Vercel ai đăng ký trước thì được, nên bất kỳ ai cũng dựng được `management-finance-xyz.vercel.app` và được CORS cho
qua kèm `credentials: true` (`app.js:21-27`, `core/socket.js:17`). Backend **không dùng cookie** (`grep res.cookie` ra
0) và token đi trong header `Authorization`, nên trang lạ không lấy được token của người dùng — tác động thấp. Cùng
lúc, nhánh `localhost:*` / `127.0.0.1:*` (`cors.js:28`) mở ở **cả production**.

**Đề nghị sửa (tuỳ chọn):** liệt kê tên miền Vercel cụ thể qua `CORS_ORIGIN` (preview deployment của Vercel có dạng
`<project>-<hash>-<team>.vercel.app` — có thể khoá theo **hậu tố team**); nhánh localhost chỉ khi
`NODE_ENV === 'development'`.

## 6. Thiếu test cho nhánh từ chối lúc bảo trì trong `auth.service`

Ca 17 của `admin.priority.maintenance.test.js` chỉ kiểm **middleware** cho `/auth/login` đi qua. Nhánh mới trong
`auth.service.login` (sau `bcrypt.compare`, ~dòng 367: tài khoản không phải admin → 503 `MAINTENANCE_MODE`; admin →
tiếp tục) chưa có test. Đề nghị hai ca: bảo trì BẬT + mật khẩu đúng + `idrole = 2` → 503; `idrole = 1` → có token. Và
một ca **mật khẩu sai** lúc bảo trì → vẫn 401 (không lộ ra là hệ thống đang bảo trì trước khi xác thực).

---

## 7. Kiểm lại sau khi sửa

- Lệnh đo ở mục 1 phải in `CHAN 503` cho hai dòng có `?x=/auth/login`.
- `grep -rn "'secret'" middleware --include=*.js` → 0 dòng; khởi động với `NODE_ENV=production` mà thiếu
  `JWT_ACCESS_SECRET` → tiến trình thoát, log nêu tên biến.
- `grep -rn "startsWith('/api/admin')" middleware modules/aiops --include=*.js` → 0 dòng (nếu chọn sửa mục 3).
- `grep -n "process.argv" middleware/load-shedding.middleware.js` → 0 dòng.
- `node --test tests/unit/*.test.js` → toàn bộ pass, gồm các ca mới của mục 1 và 6.

## 8. Ảnh hưởng tới client

- **Client-app không phải sửa gì.** Lúc bảo trì, `/auth/refresh` trả 503 thì client **giữ** token (chỉ 400/401 do server
  trả lời mới là phiên chết — `AuthInterceptor`, spec cưỡng chế đăng xuất §3.8); `/sync/*` trả 503 thì đồng bộ thử lại
  sau. Client không gửi `x-client-platform` / `x-emergency-admin-key`, và không gọi `/api/admin/*`.
- **Admin-web:** sửa mục 3 thì đường `/api/admin/*` chỉ còn được ưu tiên khi kèm token admin hợp lệ — Admin-web vốn
  luôn gửi token, nên không đổi hành vi. Sửa mục 5 thì tên miền Vercel đang dùng phải nằm trong `CORS_ORIGIN`.
- Client **không** đụng `src/Backend` — đơn này chỉ báo và đề nghị; backend chọn cách sửa.

---

## 9. Kết quả nghiệm thu thực tế (2026-10-05)

Backend đã hoàn tất khắc phục trọn vẹn cả 6 điểm theo đúng đề xuất và vượt qua toàn bộ các tiêu chí kiểm tra:

1. **Điểm 1 (Vá lách bảo trì):** Sửa `middleware/maintenance.middleware.js`, dùng `(req.originalUrl || req.path || '').split('?')[0]` và kiểm tra phương thức `req.method === 'POST'`. Lệnh đo CLI xác nhận chặn 503 thành công cho các URL có query string (`?x=/auth/login`).
2. **Điểm 2 (Loại bỏ fallback `'secret'`):** Xóa bỏ triệt để chuỗi fallback `|| 'secret'` trong `admin-priority.middleware.js` và `rate-limiter.js`. Bổ sung kiểm tra `process.exit(1)` khi khởi động production thiếu `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` tại `config/index.js`.
3. **Điểm 3 (Loại bỏ ưu tiên theo đường dẫn `/api/admin/*`):** Xóa bỏ gán `req.isAdmin = true` chưa xác thực tại `admin-priority.middleware.js`. Đồng bộ toàn bộ các middleware/core (`rate-limiter.js`, `load-shedding.middleware.js`, `retry-guard.middleware.js`, `db-bulkhead.js`, `aiops.quarantine.js`, `feature.collector.js`) kiểm tra chặt chẽ `req.isAdmin === true`.
4. **Điểm 4 (Cắt tải không nhận diện nhầm test qua đường dẫn):** Bỏ kiểm tra `process.argv` tại `load-shedding.middleware.js`, chỉ dựa vào `NODE_ENV === 'test' || Boolean(NODE_TEST_CONTEXT)`.
5. **Điểm 5 (Siết chặt CORS):** Giới hạn regex `localhost` / `127.0.0.1` chỉ có hiệu lực ở môi trường `NODE_ENV !== 'production'`.
6. **Điểm 6 (Bổ sung Unit Test):** Đã bổ sung ca 18, 19, 20 cho `auth.service.login` trong `tests/unit/admin.priority.maintenance.test.js`.
7. **Kết quả kiểm thử tự động:**
   - `node --test tests/unit/admin.priority.maintenance.test.js`: **20/20 PASS** (toàn bộ 20 ca).
   - `rtk npm test`: **220/220 PASS 100%**, 0 failed.
   - `grep -rn "'secret'" middleware --include=*.js`: **0 dòng**.
   - `grep -n "process.argv" middleware/load-shedding.middleware.js`: **0 dòng**.
   - Chuyển trạng thái: **ĐÃ XONG 100%**.

