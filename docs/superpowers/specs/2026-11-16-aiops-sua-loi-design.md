# Sửa trang AIOps — thiết kế và kế hoạch (Chủ dự án duyệt 2026-11-16)

Nguồn: khảo sát trang AIOps 2026-11-16 và quyết định của Chủ dự án trong phiên cùng ngày.

> **Trạng thái 2026-11-16:** Phần 1 đã commit (`72385774`). Phần 2 và 3 commit `eed78b84`; migration 56 đã áp Supabase 2026-11-16. Kiểm tra trên trình duyệt làm một đợt sau cùng.
> Lệch so với kế hoạch: (1) mỗi tài khoản giữ **một** dòng trong `aiops_account_quarantine` (khoá lại thì dòng đó trở lại trạng thái khoá) thay vì thêm dòng mới, vì mã dòng đã gắn với bảng liên kết điều tra; (2) không có `UNBLOCKED` trong mã, tên trạng thái thống nhất sẵn là `UNLOCKED`; (3) danh sách khoá phân trang ở Admin-web (máy chủ trả tối đa 500 dòng gần nhất mỗi bảng); (4) sửa thêm lỗi mã dòng gộp nhầm tên trùng 16 ký tự đầu và thiếu import `logger` trong `admin.service.js`.
Phạm vi: `src/Backend`, `src/Admin-web`, `src/Backend/database/`. **Không** sửa Client-app. **Không** commit / push khi Chủ dự án chưa yêu cầu. **Không** áp migration lên Supabase khi chưa được xác nhận đích danh; không tạo dữ liệu thử trên Supabase.
Quy trình mỗi bước: viết test → chạy thấy **ĐỎ** → mã tối thiểu cho **XANH** → chạy cả bộ (`npm run test:unit` ở Backend, `npm test` + `npm run lint` ở Admin-web).
Làm theo thứ tự Phần 1 → 2 → 3. Thấy kế hoạch sai hoặc thiếu thì **dừng và báo**, không tự đổi.

---

## Phần 1 — Admin-web: đếm sự cố, Làm mới, biểu đồ, định dạng số (không đụng Backend)

### 1.1 Đếm sự cố realtime (`pages/system/aiops/useAIOps.js`, `onAnomaly` ~dòng 248)
- Sự kiện `admin.anomaly_detected` trùng `id` một sự cố đang có trong danh sách → cập nhật dòng đó tại chỗ (số lần, lần cuối, trạng thái), **không** cộng tổng.
- Sự cố mới: chỉ cộng tổng khi khớp bộ lọc đang xem (vectơ, trạng thái; khoảng ngày tự chọn đã kết thúc trước thời điểm sự cố thì không khớp). Chỉ chèn lên đầu bảng khi đang ở trang 1, và cắt danh sách về đúng cỡ trang.
- Đọc tên trường payload từ chỗ Backend phát sự kiện (`modules/aiops/`), không đoán.
- Test: (a) sự kiện trùng id → tổng giữ nguyên, số lần tăng; (b) lọc "Đã xử lý" + sự cố ACTIVE mới → không chèn, tổng không đổi; (c) đang ở trang 2 → không chèn, tổng +1 nếu khớp lọc; (d) trang 1 đủ 5 dòng → sau chèn vẫn 5 dòng.

### 1.2 Nút "Làm mới" (`useAIOps.js` ~dòng 137, 274–282)
- `fetchAIOpsData` trả về kết quả thành công / thất bại (vẫn nuốt lỗi khi chạy định kỳ).
- `handleManualRefresh` tải lại **đúng trang và bộ lọc đang xem** (không ép về trang 1); thất bại thì hiện thông báo lỗi, không hiện "Đã làm mới".
- Test: đang ở trang 3 → gọi `getIncidents` với trang 3; API lỗi → hiện thông báo lỗi, không có thông báo thành công.

### 1.3 Biểu đồ xu hướng (`pages/system/aiops/TrendSection.jsx`)
1. Nhãn trục cho các khung có sẵn tính theo thời gian thật: vị trí nhãn `v` = `(cửaSổ + v·đơnVị) / cửaSổ`. Khung 7 ngày dùng `-7…0`.
2. Khoảng tự chọn: ≤ 24 giờ hiện `HH:mm`; > 24 giờ và ≤ 3 ngày hiện `dd/MM HH:mm`; > 3 ngày hiện `dd/MM`. Không có hai nhãn trùng nhau liền kề.
3. Đứt nét khi mất số liệu: hai điểm liền nhau cách nhau > 3 lần khoảng cách trung vị thì bắt đầu đoạn mới (`M`), không nối thẳng.
4. Điểm nằm ngoài khung thời gian bị bỏ, không dồn vào mép.
5. Trục dọc có vạch 0, 50, 100 (giữ hai đường ngưỡng 70, 85).
6. Con số cạnh chú thích: chế độ thời gian thực hiện điểm số hiện tại; xem khung quá khứ / tự chọn hiện điểm số của mẫu cuối cùng trong khung.
- Test cho từng điểm 1–6 (đọc nhãn `<text>`, thuộc tính `d` của `<path>`, số điểm `trend-hit`).

### 1.4 Định dạng số và tiền theo ngôn ngữ (toàn Admin-web)
- Thêm vào `utils/format.js`: `formatNumber(value, { minFrac, maxFrac }, lang)`, `formatCurrency(value, currency = 'VND', lang)`, `formatPercent(value, frac, lang)` dùng `Intl.NumberFormat`; `vi` → `vi-VN`, `en` → `en-US`. Thêm hook gọn lấy `lang` từ `language.context`.
- Kết quả mong đợi: vi `1.234,5` / `49.000 ₫`; en `1,234.5` / `₫49,000` (mặc định của `Intl` cho từng ngôn ngữ).
- Thay mọi chỗ tự định dạng (`toFixed`, `toLocaleString`, `Intl.NumberFormat` rời rạc) ở các tệp không phải test, gồm: `ServerHealthPanel`, `Header`, `SettingsSections`, `AvailabilityModal`, `LineChart`, `DashboardPage`, `paymentFormat`, `PaymentHistoryPage`, `AIOpsModals`, `IncidentsSection`, `ScaleSection`, `SignalsSection` (lỗi "0.15 nhân"), `TrendSection`, `useAIOps`, `VectorSection`, `AuditLogPage`, `settings.context`. Liệt kê lại bằng `grep` trước khi làm.
- Test: hàm định dạng ở cả vi và en; thẻ CPU hiện `0,15` (vi) và `0.15` (en).

---

## Phần 2 — Backend + Admin-web: vòng đời khoá, danh sách khoá, PIN, ràng buộc

### 2.1 Vòng đời khoá
- **Tài khoản:**
  - Tạm khoá (mặc định 4 giờ) tự mở khi hết hạn.
  - Từ trạng thái tạm khoá, admin có thể nâng lên khoá vĩnh viễn. Khoá vĩnh viễn giữ tới khi admin mở.
- **IP:** chỉ có tạm khoá.
  - Bỏ khoá vĩnh viễn IP.
  - Nút "Khóa thêm 4 giờ" gọi route mới `POST /aiops/quarantine/extend-ip`.
  - Route cũ `permanent-ip` giữ làm bí danh trỏ cùng hàm, để Admin-web cũ không vỡ trong lúc Vercel và Render deploy lệch nhau.
- **Lý do khoá:** thêm tiền tố `[AIOPS_ADMIN_TEMP]` (admin tạm khoá) và `[AIOPS_ADMIN_BAN]` (admin khoá vĩnh viễn) vào `modules/aiops/aiops.reason.js`. `lyDoChoNguoiDung` bỏ mọi tiền tố AIOps trước khi trả cho app, để Client-app không phải đổi.
- **Tự mở khi hết hạn** dựa vào bảng `aiops_account_quarantine` (status `TEMPORARY`, `expires_at <= now`). Chỉ đổi `account.status` về Active khi `reason_inactive` còn mang tiền tố AIOps tự động hoặc `[AIOPS_ADMIN_TEMP]`; người khác đã đổi lý do thì không đụng. Áp cho cả bản ghi trong bộ nhớ lẫn `_reconcileAutoLocks` ([aiops.quarantine.js:128-143](../../../src/Backend/modules/aiops/aiops.quarantine.js), 684-686, 729-758).
- **Test:**
  - tạm khoá → đặt đồng hồ quá 4 giờ → tài khoản Active và dòng chuyển UNBLOCKED;
  - khoá vĩnh viễn → quá hạn vẫn Inactive;
  - lý do bị đổi tay → không tự mở;
  - không còn đường nào đặt IP thành PERMANENT;
  - `lyDoChoNguoiDung` bỏ được cả ba tiền tố.

### 2.2 Danh sách khoá lấy từ CSDL, giữ lịch sử
- `GET /aiops/quarantine` đọc hai bảng `aiops_ip_quarantine`, `aiops_account_quarantine`, gồm cả dòng UNBLOCKED, sắp `banned_at` giảm dần, có phân trang và lọc trạng thái (Đang khoá / Đã mở / Tất cả). Không còn phụ thuộc `_pairs` trong bộ nhớ.
- Mọi đường khoá (tự động, thủ công, nút trên bảng) đều ghi dòng vào bảng tương ứng. Mở khoá đặt `UNBLOCKED`, `unblocked_at`, `unblocked_by`; dòng vẫn ở lại danh sách.
  - **Lỗi hiện tại phải sửa:** `aiops.quarantine.repository.updateAccountStatus` (~dòng 627) chỉ `UPDATE`. Tài khoản chưa có dòng thì không ghi được gì. Đổi thành: chưa có dòng đang khoá thì `INSERT` dòng mới (`idaccount`, `username`, `status`, `reason`, `banned_by`, `expires_at`). Khoá lại tài khoản đã từng được mở thì **thêm dòng mới**, không ghi đè dòng UNBLOCKED cũ, để giữ lịch sử.
  - Thống nhất tên trạng thái mở khoá: mã đang dùng cả `UNLOCKED` lẫn `UNBLOCKED`. Kiểm dữ liệu có sẵn rồi chọn một, đọc được cả hai cho dữ liệu cũ.
  - `temporaryBlockAccount` mặc định `reason = 'Admin tạm khóa Tài khoản'` làm câu lý do có số giờ không bao giờ dùng tới. Sửa để lý do ghi đúng thời hạn.
- Mở tài khoản ở trang Người dùng (`PATCH /admin/updatestatus` → Active) cũng đặt các dòng AIOps đang khoá của tài khoản đó thành UNBLOCKED (`unblock_reason` "Mở từ trang Người dùng").
- **Giả định (Chủ dự án sửa nếu sai):** danh sách gồm các khoá do AIOps (tự động và thủ công trên trang AIOps). Khoá ở trang Người dùng vẫn chỉ hiện ở trang Người dùng.
- Admin-web `QuarantineSection`:
  - thêm bộ lọc trạng thái và phân trang;
  - dòng đã mở hiện nhãn "Đã mở" kèm người mở và thời điểm;
  - IP vẫn che, bấm "Xem" + PIN để thấy bản đầy đủ (giữ cơ chế hiện tại, hợp lệ theo khảo sát pháp lý L13).
- **Test:**
  - khoá thủ công một tài khoản chưa dính sự cố → có dòng trong danh sách;
  - mở khoá → dòng còn, trạng thái UNBLOCKED;
  - khởi động lại (xoá bộ nhớ) → danh sách không đổi;
  - mở ở trang Người dùng → dòng AIOps thành UNBLOCKED.

### 2.3 PIN cho mọi thao tác ghi trên trang AIOps (máy chủ kiểm)
- Mọi route ghi AIOps gọi `adminService.verifySecurityAction({ pin, action, targetId }, req.user)` trước khi làm, theo mẫu `revealQuarantineIp`, với `pin` lấy từ body:
  - `vectors/toggle`, `calibrate`, `scale`;
  - `quarantine` (khoá thủ công);
  - `unblock-ip`, `extend-ip` / `permanent-ip`, `temporary-ip`;
  - `unblock-account`, `permanent-account`, `temporary-account`.
- `POST /system/maintenance` (giảm thiểu bằng bảo trì) dùng chung với trang Bảo trì:
  - kiểm xem đã đòi PIN ở máy chủ chưa;
  - nếu chưa, **dừng và báo**, vì sửa nó sẽ đổi cả trang Bảo trì.
- Thao tác chỉ đọc không cần PIN: xem, lọc, phân trang, đổi khung biểu đồ, Làm mới.
- Admin-web: mọi nút ghi mở `SecurityConfirmModal` (PIN) rồi gửi `pin` trong body; bỏ các `ConfirmModal` không PIN của những thao tác này.
- **Test Backend:** mỗi route ghi thiếu PIN hoặc sai PIN → bị từ chối và không đổi trạng thái; đúng PIN → thực hiện.
- **Test Admin-web:** mỗi nút ghi mở hộp PIN, và payload có `pin`.

### 2.4 Ràng buộc khoá tài khoản
- Admin không tự khoá tài khoản của mình. So `idaccount` / `username` đích với `req.user`, vi phạm thì trả 403 `CANNOT_LOCK_SELF`. Áp cho cả ba route khoá tài khoản và khoá thủ công.
- Admin khoá được tài khoản admin khác.
- Khoá IP của chính mình vẫn cho phép (giữ chặn IP loopback như hiện tại).
- Admin-web hiện thông báo dễ hiểu cho `CANNOT_LOCK_SELF`.
- Test: tự khoá → 403 và tài khoản không đổi; khoá admin khác → thành công.

### 2.5 Khoá IP chặn cả admin (Chủ dự án chốt phương án (b), 2026-11-16)
Nghiệp vụ: admin hoặc IP đã bị khoá thì vẫn bị chặn như mọi người, kể cả khi đăng nhập đúng. Chỉ tài khoản quản trị gốc không bị chặn ngay từ đầu.
- **Bỏ hẳn cơ chế "phiên admin tự miễn khoá IP"** ([aiops.quarantine.js:177-221](../../../src/Backend/modules/aiops/aiops.quarantine.js), gọi từ [auth.service.js:423-432](../../../src/Backend/modules/auth/auth.service.js) và `auth.controller.js:136`):
  - đăng nhập admin không còn gỡ khoá IP;
  - không còn danh sách IP admin miễn khoá 24 giờ (`_activeAdminSessions`, `registerAdminSession`, `unregisterAdminSession`, nhánh 3–4 của `isProtectedIp`);
  - áp dụng cho mọi admin, kể cả tài khoản gốc (tài khoản gốc không cần vì đã được miễn ở lớp chặn).
- `isProtectedIp` chỉ còn: loopback mặc định + `ADMIN_TRUSTED_IPS` + hash hệ thống. Trên Render hiện chưa đặt `ADMIN_TRUSTED_IPS`, nên chỉ còn loopback.
- **Lớp chặn IP** (`createMiddleware`, ~dòng 1226): bỏ miễn trừ `req.isAdmin === true`. Chỉ miễn khi:
  - request mang access token **hợp lệ của tài khoản gốc** (xác thực chữ ký và dấu vân tay khoá ở Phần 3);
  - hoặc `POST /auth/login` có email / tên đăng nhập trùng tài khoản gốc (vẫn phải qua mật khẩu và khoá `.env`).
  - Cho tới khi làm Phần 3, chưa có miễn trừ nào ngoài loopback / `ADMIN_TRUSTED_IPS`.
- `req.isAdmin` giữ nguyên cho các lớp khác (giới hạn tốc độ, quá tải, bảo trì); chỉ lớp khoá IP đổi.
- Admin-web: nhận 403 `AIOPS_QUARANTINED` thì hiện thông báo "IP này đang bị khoá đến …" thay vì lỗi chung; ở trang Đăng nhập cũng vậy.
- Test (sửa test cũ trước, phải ĐỎ trên mã hiện tại):
  - admin thường từ IP đang khoá → 403, kể cả có token hợp lệ;
  - admin đăng nhập → khoá IP vẫn còn, admin khác vẫn khoá tay được IP đó;
  - IP trong `ADMIN_TRUSTED_IPS` → không khoá được;
  - (Phần 3) tài khoản gốc từ IP đang khoá → đăng nhập và gọi API được.
- Test cũ về `registerAdminSession` / miễn khoá phiên admin phải xoá hoặc đảo nghĩa; ghi rõ trong báo cáo là do đổi nghiệp vụ.

---

## Phần 3 — Tài khoản quản trị gốc (Backend + CSDL + Admin-web)

### Quyết định của Chủ dự án
- Không thêm cột vào bảng `account`. Trigger chỉ đích danh tài khoản bằng email.
- Đăng nhập tài khoản này cần hai bước:
  - mật khẩu, kiểm ở CSDL;
  - khoá thứ hai, kiểm với biến môi trường.
- Chỉ email này áp dụng cách đăng nhập hai bước.
- Bị lộ thì đổi biến môi trường.

### 3.1 Biến môi trường (`.env`, không commit; `.env.example` để trống)
- `ROOT_ADMIN_USERNAME=admin`
- `ROOT_ADMIN_EMAIL=admin@wealthcommand.com`
- `ROOT_ADMIN_PASSWORD=123456`: chỉ dùng để tạo tài khoản lần đầu.
- `ROOT_ADMIN_SECOND_KEY=<chuỗi bí mật>`: bước xác thực thứ hai. Thiếu biến này thì tài khoản gốc **không** đăng nhập được (an toàn khi thiếu cấu hình).
- Chủ dự án tự thêm các biến này (kèm `ADMIN_TRUSTED_IPS` nếu cần) lên Render. Deploy Phần 3 trước khi có biến thì tài khoản gốc chưa đăng nhập được; các admin khác không bị ảnh hưởng.

### 3.2 Migration `database/56_root_admin_guard.sql` (luỹ đẳng; kiểm số 56 chưa dùng)
- Hàm và trigger `trg_protect_root_admin` trên `account`, chạy BEFORE UPDATE OR DELETE, khi `OLD."Email" = 'admin@wealthcommand.com'`:
  - DELETE → báo lỗi;
  - UPDATE đổi `Email`, `Username`, `Idrole` → báo lỗi;
  - UPDATE đặt `Status` khác `Active` hoặc đặt `Delete_at` → báo lỗi;
  - cho phép đổi mật khẩu, PIN, `is_first_login`, `Update_at`.
- Email viết cứng trong trigger phải trùng `ROOT_ADMIN_EMAIL`. Tài liệu ghi rõ: email tài khoản gốc cố định, muốn đổi phải có migration mới.
- Thứ tự áp: CSDL thử trước. Supabase chỉ khi Chủ dự án xác nhận.
- Không đổi `schema.prisma` (không có cột mới); chạy `npm run db:verify-indexes`.
- Test (CSDL thử, `TEST_DATABASE_URL`): xoá, khoá, đổi vai tài khoản gốc → lỗi; đổi mật khẩu → được; tài khoản khác không bị ảnh hưởng.

### 3.3 Script `scripts/seed_root_admin.js`
- Tạo tài khoản gốc nếu chưa có: vai admin, mật khẩu bcrypt từ `ROOT_ADMIN_PASSWORD`, `is_first_login = true` để lần đầu bắt đổi mật khẩu và đặt PIN theo luồng `first-login-setup` sẵn có.
- `--reset-password` đặt lại mật khẩu từ biến môi trường.
- Luỹ đẳng, cần cờ `--xac-nhan-tu-xa` khi trỏ CSDL ngoài máy.

### 3.4 Đăng nhập hai bước (`modules/auth/`)
- Tài khoản không phải gốc: không đổi gì.
- `POST /auth/login` với tài khoản gốc, mật khẩu đúng:
  - thiếu `rootKey` → 401 `ROOT_KEY_REQUIRED`, không cấp token;
  - sai → 401 `ROOT_KEY_INVALID`, tính như một lần đăng nhập sai (AIOps nhìn thấy);
  - so bằng `crypto.timingSafeEqual` trên băm SHA-256 của hai chuỗi.
- Token của tài khoản gốc mang dấu vân tay khoá (16 ký tự đầu HMAC-SHA256 của `ROOT_ADMIN_SECOND_KEY`). Middleware xác thực và `/auth/refresh` từ chối token có dấu vân tay khác giá trị hiện tại. Nhờ vậy, đổi biến môi trường thì phiên của kẻ chiếm tài khoản bị cắt ngay sau khi máy chủ khởi động lại.
- Mỗi lần tài khoản gốc đăng nhập thành công: gửi email cảnh báo tới `ADMIN_ALERT_EMAIL`, ghi nhật ký kiểm toán.
- Admin-web trang Đăng nhập: nhận `ROOT_KEY_REQUIRED` thì hiện thêm ô "Khoá quản trị gốc" và gửi lại kèm `rootKey`.
- **Test:**
  - thiếu, sai, đúng `rootKey`;
  - thiếu biến môi trường → từ chối;
  - đổi khoá → token cũ bị từ chối ở middleware và refresh;
  - tài khoản thường đăng nhập không cần `rootKey`.

### 3.5 Chặn ở tầng dịch vụ (báo lỗi dễ hiểu trước khi chạm trigger)
- Chặn mọi thao tác lên tài khoản gốc, kể cả do chính nó thực hiện, trả 403 `ROOT_ACCOUNT_PROTECTED`:
  - trang Người dùng: vô hiệu hoá, xoá;
  - quản lý admin: đổi vai, xoá;
  - AIOps: tạm khoá, khoá vĩnh viễn, khoá thủ công.
- AIOps tự động bỏ qua tài khoản gốc khi khoá tài khoản. IP của tài khoản gốc vẫn có thể nằm trong danh sách khoá (để chặn người khác dùng chung IP đó), nhưng request của tài khoản gốc đi qua lớp chặn IP theo mục 2.5.
- Admin-web hiện thông báo tương ứng.
- Test cho từng đường.

### 3.6 Tài liệu
Cập nhật:
- `docs/AIOps/`;
- `docs/Admin-web/` (đặc tả trang AIOps, Đăng nhập);
- `docs/Rule_Project/Data_Security.md` (tài khoản gốc, trách nhiệm giữ an toàn thuộc admin đứng đầu nắm tài khoản);
- `docs/progress/Backend.md`;
- `.env.example`.

Client-app không phải làm gì: mã lỗi mới chỉ xảy ra với tài khoản admin; lý do khoá trả cho app đã bỏ tiền tố.
