# Kế hoạch Khắc phục Triệt để Sự cố: Admin Bị Phong Tỏa Nhầm Khi Đăng Nhập (False Positive AIOps Quarantine)

> **Mục tiêu:** Đảm bảo Admin-web và tài khoản Quản trị viên không bao giờ bị hệ thống AIOps phong tỏa nhầm, loại bỏ bẫy bắt lỗi token hết hạn sai quy cách, và cung cấp lối thoát hiểm tự động giải cứu khi đăng nhập Admin thành công.

---

## 1. Nguyên nhân Gốc rễ (Root Cause Analysis)

1. **False Positive tại `feature.collector.js` (Heuristic 4):**
   - Bộ lắng nghe sự kiện `res.on('finish')` của Express bắt mọi request có mã `401` trên đường dẫn `/refresh` và tự động đánh dấu là `TOKEN_HIJACKING_ATTACK`.
   - Khi Admin mở web, trình duyệt tự động gửi `POST /api/auth/refresh` với refresh token cũ trong `localStorage`. Do phiên làm việc đã hết hạn (sau nhiều ngày hoặc sau khi server restart), server trả về `401`.
   - `feature.collector.js` quy chụp ngay lập tức là hành vi tấn công, tự động gọi `defaultAIOpsQuarantine.quarantine(clientIp, ...)` phong tỏa IP của Admin 15 phút.

2. **Chặn đứng Cửa ngõ Đăng nhập tại `aiops.quarantine.js`:**
   - Middleware `aiops.quarantine` chỉ miễn trừ nếu `req.isAdmin === true` hoặc URL bắt đầu bằng `/api/admin`.
   - Khi Admin nhập tài khoản và bấm "Đăng nhập", request gửi đến `POST /api/auth/login`. Vì URL này không thuộc `/api/admin` và lúc này người dùng chưa đăng nhập nên `req.isAdmin` là `false`.
   - Do IP đã bị phong tỏa ở bước 1, request đăng nhập bị từ chối với mã `HTTP 403 AIOPS_QUARANTINED`. Admin bị nhốt ngoài hệ thống.

3. **Thiếu Định danh Kênh Admin-web & Cơ chế Tự giải phóng IP:**
   - Client Admin-web chưa truyền header định danh `x-client-platform: admin-web`.
   - Khi đăng nhập thành công với tài khoản Admin hợp lệ, hệ thống chưa có hook tự động xóa lệnh phong tỏa cho IP tương ứng.

---

## 2. Các bước Triển khai Chi tiết

### Bước 1: Sửa đổi `feature.collector.js` & `auth.service.js`
- **File:** `src/Backend/modules/auth/auth.service.js`
  - Trong phương thức `refresh(oldRefreshToken, req)`:
    - Khi `storedToken && storedToken.status === true` (Token thực sự đã bị thu hồi trước đó nhưng bị đem ra dùng lại): gán cờ `if (req) req.tokenReuseDetected = true;`.
    - Khi token chỉ đơn thuần hết hạn thời gian (`new Date() > storedToken.expired`) hoặc không tồn tại: không gán cờ này.
- **File:** `src/Backend/modules/aiops/feature.collector.js`
  - Sửa Heuristic 4: Chỉ gọi `recordTokenReuse()` và `quarantine()` khi `req.tokenReuseDetected === true`.
  - Nếu chỉ là 401 hết hạn phiên làm việc bình thường: bỏ qua, không phong tỏa IP.

### Bước 2: Nâng cấp `admin-priority.middleware.js`
- **File:** `src/Backend/middleware/admin-priority.middleware.js`
  - Nhận diện `x-client-platform: admin-web` hoặc Origin/Referer từ Admin-web frontend.
  - Khi phát hiện request từ kênh Admin-web: gán `req.isAdminWebClient = true`. Nếu request là login/refresh hoặc admin API: gán `req.isAdmin = true`.

### Bước 3: Nâng cấp `aiops.quarantine.js` & Thêm Auto-Unquarantine
- **File:** `src/Backend/modules/aiops/aiops.quarantine.js`
  - Thêm phương thức `unquarantine(rawIp)` (gọi `this.unblock(...)`).
  - Trong middleware của quarantine:
    - Nếu request là `POST /api/auth/login` và (request từ Admin-web HOẶC username trong body là `admin`): cho phép đi tiếp (next) để vào Auth Controller xác thực mật khẩu.
- **File:** `src/Backend/modules/auth/auth.service.js`
  - Trong phương thức `login(username, password, req)`:
    - Khi xác thực mật khẩu bcrypt thành công: Nếu tài khoản là Admin (`account.idrole === 1` hoặc `admin`), tự động gọi `defaultAIOpsQuarantine.unquarantine(clientIp)` để giải phóng phong tỏa ngay lập tức nếu IP này từng bị gán cờ.

### Bước 4: Đồng bộ Header Phía Client Admin-web & Cấu hình CORS
- **File:** `src/Admin-web/src/api/axios-client.js`
  - Thêm header cố định `x-client-platform: admin-web` cho instance `axiosClient` và request refresh token.
- **File:** `src/Backend/app.js`
  - Bổ sung `x-client-platform`, `x-emergency-admin-key` vào danh sách `allowedHeaders` của cấu hình CORS.

### Bước 5: Cập nhật Unit Tests & Kiểm tra Toàn diện
- Cập nhật và bổ sung test cases trong `src/Backend/tests/unit/aiops.collector.test.js` và `aiops.quarantine.test.js`.
- Chạy test suite: `rtk node --test src/Backend/tests/unit/aiops.*.test.js`
- Chạy test toàn diện: `rtk npm test`
- Build frontend Admin-web: `rtk npm --prefix src/Admin-web run build`
- Cập nhật CodeGraph: `rtk npx codegraph build`

---

## 3. Tiêu chí Hoàn thành (Acceptance Criteria)
- [ ] Mở Admin-web với refresh token hết hạn không bị phong tỏa IP.
- [ ] Đăng nhập tài khoản `admin` thành công 100%, không bao giờ gặp lỗi 403 `AIOPS_QUARANTINED`.
- [ ] Nếu một IP bị phong tỏa trước đó do lỗi từ thiết bị khác, việc đăng nhập đúng tài khoản Quản trị viên trên IP đó sẽ tự động gỡ bỏ phong tỏa ngay tức thì.
- [ ] 100% Unit test pass, build frontend thành công 0 lỗi.
