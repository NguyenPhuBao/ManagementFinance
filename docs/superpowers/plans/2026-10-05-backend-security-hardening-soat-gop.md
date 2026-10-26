# 📋 KẾ HOẠCH TRIỂN KHAI: XỬ LÝ TRỌN GÓI 6 ĐIỂM KỸ THUẬT BACKEND (SOÁT SAU GỘP B38367E)

> **Ngày lập kế hoạch:** 05/10/2026  
> **Người thực hiện:** Senior Fullstack & Security Specialist / Antigravity AI  
> **Người duyệt:** Product Owner (PO)  
> **Tài liệu nguồn:** [`docs/superpowers/backend/CAN-LAM/SOAT_SAU_GOP_B38367E.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/superpowers/backend/CAN-LAM/SOAT_SAU_GOP_B38367E.md)  
> **Phạm vi tác động:** `src/Backend/` (Client-app & CSDL Supabase không cần thay đổi).

---

## 🎯 MỤC TIÊU KẾ HOẠCH

Khắc phục triệt để và khép kín 6 vấn đề kỹ thuật phát hiện sau đợt gộp mã nhằm nâng cao an ninh số, bảo đảm tính toàn vẹn của lớp bảo trì khẩn cấp và chuẩn hóa hành vi kiểm thử:
1. **Điểm 1 (Mức vừa):** Khắc phục triệt để lỗ hổng lách qua lớp bảo trì (Maintenance Mode) bằng query string (ví dụ: `?x=/auth/login`).
2. **Điểm 2 (Nhẹ / Cấu hình):** Xóa bỏ fallback khóa bí mật `'secret'` trong các middleware; bổ sung chốt chặn kiểm tra bắt buộc biến `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` khi khởi động môi trường production.
3. **Điểm 3 (Nhẹ / An ninh):** Bỏ cơ chế tự động cấp `req.isAdmin = true` dựa thuần túy trên tiền tố URL `/api/admin/*` trước khi xác thực; chỉ cấp ưu tiên Fast-Lane khi token JWT mang role Admin đã được `jwt.verify` hợp lệ hoặc có khóa khẩn cấp.
4. **Điểm 4 (Nhẹ / Ổn định):** Sửa lỗi nhận diện môi trường test trong middleware Cắt tải (Load Shedding), loại bỏ quét chuỗi `process.argv` tránh tắt nhầm thời gian khởi động (warmup 45s) khi thư mục máy dev chứa từ "test".
5. **Điểm 5 (Nhẹ / Tối ưu CORS):** Siết chặt quy tắc CORS, chỉ kích hoạt nhánh `localhost:*` khi `NODE_ENV === 'development'`, bảo vệ chặt chẽ các origin hợp lệ.
6. **Điểm 6 (Kiểm thử TDD):** Bổ sung 3 test cases cho nhánh từ chối tài khoản thường và cấp phép Admin lúc bảo trì trong `auth.service.js`.

---

## 🛠️ CHI TIẾT CÁC BƯỚC THỰC HIỆN

### BƯỚC 1: Vá Lỗ Hổng Lách Lớp Bảo Trì (Điểm 1)
* **Tệp tác động:** [`src/Backend/middleware/maintenance.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/maintenance.middleware.js)
* **Nguyên nhân:** Dùng `req.originalUrl.includes('/auth/login')` nên bất kỳ request nào có query string chứa chuỗi này đều lọt qua.
* **Giải pháp kỹ thuật:**
  1. Tách bỏ toàn bộ query string: `const cleanPath = (req.originalUrl || req.path || '').split('?')[0];`
  2. So khớp phương thức và đường dẫn chính xác:  
     `const isLoginRoute = req.method === 'POST' && (cleanPath === '/api/auth/login' || cleanPath === '/auth/login');`
  3. Chuẩn hóa kiểm tra Health Check:  
     `const isHealthCheck = cleanPath === '/health' || cleanPath.startsWith('/health/');`
  4. Bỏ điều kiện URL path gán `isAdmin` (xem Bước 3):  
     `const isAdmin = req.isAdmin === true;`
* **Test bổ sung:** Thêm ca kiểm trong `admin.priority.maintenance.test.js`:
  - Request `/api/sync/push?x=/auth/login` khi bảo trì BẬT $\rightarrow$ Bị chặn **503 `MAINTENANCE_MODE`**.
  - Request `GET /api/auth/login` khi bảo trì BẬT $\rightarrow$ Bị chặn **503** (chỉ `POST` được qua).

---

### BƯỚC 2: Loại Bỏ Fallback `'secret'` & Chốt Chặn Khởi Động Production (Điểm 2)
* **Tệp tác động:**
  - [`src/Backend/middleware/admin-priority.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/admin-priority.middleware.js)
  - [`src/Backend/middleware/rate-limiter.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/rate-limiter.js)
  - [`src/Backend/config/index.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/config/index.js)
* **Giải pháp kỹ thuật:**
  1. Trong `admin-priority.middleware.js:20` và `rate-limiter.js:29`:  
     Xóa bỏ chuỗi `|| 'secret'`. Lấy trực tiếp từ `config.jwt.accessSecret || process.env.JWT_ACCESS_SECRET`. Nếu không có secret, không thực thi verify (coi như không có token).
  2. Trong `config/index.js`:  
     Thêm kiểm tra bắt buộc lúc nạp cấu hình:
     ```javascript
     if (config.env === 'production' && (!config.jwt.accessSecret || !config.jwt.refreshSecret)) {
       console.error('\x1b[31m[SECURITY CRITICAL] Thiếu JWT_ACCESS_SECRET hoặc JWT_REFRESH_SECRET trong môi trường production. Từ chối khởi động.\x1b[0m');
       process.exit(1);
     }
     ```

---

### BƯỚC 3: Loại Bỏ Cấp Quyền Ưu Tiên Admin Theo URL Path Chưa Xác Thực (Điểm 3)
* **Tệp tác động:**
  - [`src/Backend/middleware/admin-priority.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/admin-priority.middleware.js)
  - [`src/Backend/middleware/rate-limiter.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/rate-limiter.js)
  - [`src/Backend/middleware/load-shedding.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/load-shedding.middleware.js)
  - [`src/Backend/middleware/retry-guard.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/retry-guard.middleware.js)
  - [`src/Backend/core/resilience/db-bulkhead.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/core/resilience/db-bulkhead.js)
  - [`src/Backend/modules/aiops/aiops.quarantine.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/aiops/aiops.quarantine.js)
* **Giải pháp kỹ thuật:**
  - Xóa bỏ nhánh gán `req.isAdmin = true` ở `admin-priority.middleware.js:25-29`.
  - Trong các middleware và bulkhead: Chỉ kiểm tra `req.isAdmin === true` (đã được server xác thực qua token chữ ký hợp lệ hoặc emergency key). Riêng `/health/admin` được miễn nếu là health probe nội bộ.
  - Cập nhật test 1 trong `admin.priority.maintenance.test.js`: Kiểm tra request vào `/api/admin/*` không có token thì `req.isAdmin` phải là `false`.

---

### BƯỚC 4: Sửa Nhận Diện Môi Trường Test Trong Load Shedding (Điểm 4)
* **Tệp tác động:** [`src/Backend/middleware/load-shedding.middleware.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/middleware/load-shedding.middleware.js)
* **Giải pháp kỹ thuật:**
  - Thay thế dòng 25:
    ```javascript
    // CŨ: process.argv.some(a => a.includes('test')) -> Bị dính tên thư mục máy dev
    // MỚI:
    const isTestEnv = process.env.NODE_ENV === 'test' || Boolean(process.env.NODE_TEST_CONTEXT);
    ```
  - Giữ nguyên cơ chế truyền `warmupMs = 0` trong options của các unit test runner.

---

### BƯỚC 5: Tối Ưu Hóa & Siết Chặt Cấu Hình CORS (Điểm 5)
* **Tệp tác động:** [`src/Backend/config/cors.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/config/cors.js)
* **Giải pháp kỹ thuật:**
  - Chỉ cho phép các origin `localhost` và `127.0.0.1` khi `process.env.NODE_ENV !== 'production'`.
  - Bảo toàn danh sách origin trong `CORS_ORIGIN` và pattern Vercel chính thức của dự án.

---

### BƯỚC 6: Bổ Sung Test Suite Cho Nhánh Login Lúc Bảo Trì (Điểm 6)
* **Tệp tác động:** [`src/Backend/tests/unit/admin.priority.maintenance.test.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/tests/unit/admin.priority.maintenance.test.js)
* **Nội dung test bổ sung:**
  1. `Ca 18`: Bảo trì BẬT + Mật khẩu đúng + Tài khoản User thường (`idrole = 2`) $\rightarrow$ Ném ngoại lệ / trả về mã **503 `MAINTENANCE_MODE`**.
  2. `Ca 19`: Bảo trì BẬT + Mật khẩu đúng + Tài khoản Admin (`idrole = 1`) $\rightarrow$ Đăng nhập thành công, trả về Access & Refresh Token.
  3. `Ca 20`: Bảo trì BẬT + Mật khẩu sai $\rightarrow$ Trả về mã **401 `INVALID_CREDENTIALS`** (tuyệt đối không để lộ thông tin bảo trì trước khi xác thực danh tính).

---

## 🧪 KẾ HOẠCH KIỂM THỬ & NGHIỆM THU

1. **Chạy kiểm chứng lệnh đo cấm lách bảo trì:**
   ```bash
   rtk node -e "const {createMaintenanceMiddleware}=require('./src/Backend/middleware/maintenance.middleware'); const m=createMaintenanceMiddleware({manager:{isMaintenanceActive:()=>true,getStatus:()=>({})}}); function thu(path,originalUrl){let qua=false,ma=null; const res={setHeader(){},status(c){ma=c;return{json(){}}}}; m({path,originalUrl,method:'GET',isAdmin:false},res,()=>{qua=true}); console.log(qua?'CHO QUA':'CHAN '+ma, originalUrl);} thu('/api/sync/push','/api/sync/push?x=/auth/login'); thu('/api/transactions','/api/transactions?r=/auth/login');"
   ```
   *Yêu cầu kết quả:* Phải in `CHAN 503` cho cả 2 trường hợp.
2. **Kiểm tra rà soát mã nguồn:**
   - `grep -rn "'secret'" src/Backend/middleware --include=*.js` $\rightarrow$ 0 kết quả.
   - `grep -n "process.argv" src/Backend/middleware/load-shedding.middleware.js` $\rightarrow$ 0 kết quả.
3. **Thực thi toàn bộ bộ Unit Tests:**
   - `rtk npm test` trong `src/Backend/` $\rightarrow$ **Toàn bộ tests PASS 100%**, bao gồm các test cases mới.
4. **Cập nhật tài liệu:**
   - Cập nhật [`Project.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/Project.md) ghi nhận mục 11.65.
   - Di chuyển [`SOAT_SAU_GOP_B38367E.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/superpowers/backend/CAN-LAM/SOAT_SAU_GOP_B38367E.md) từ `CAN-LAM/` sang `DA-XONG/`.
   - Cập nhật đồ thị mã nguồn: `rtk npx codegraph build`.
