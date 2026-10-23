# 📋 KẾ HOẠCH CHI TIẾT SỬA LỖI TỒN ĐỌNG XÁC THỰC MÃ PIN & VALIDATION BẢO MẬT ADMIN
> **Tài liệu nguồn sự thật phục vụ thực thi:** `docs/Admin-web/PIN_AND_SECURITY_VALIDATION_PLAN.md`  
> **Ngày lập:** 2026-10-22  
> **Tác giả:** AI Assistant (Lead BA + Lead FullStack + Lead Tester)  
> **Người duyệt:** Product Owner (PO)  
> **Trạng thái:** ✅ ĐÃ PO PHÊ DUYỆT & TRIỂN KHAI HOÀN TẤT (PO Approved & Fully Implemented)

---

## 🎯 1. BỐI CẢNH & KHẢO SÁT CHI TIẾT CÁC ISSUE LOG

Qua khảo sát trực tiếp mã nguồn toàn diện giữa **Backend** (`src/Backend`) và **Admin-web** (`src/Admin-web`), các lỗi tồn đọng được xác nhận chính xác nguyên nhân gốc rễ (Root Cause) như sau:

### 🔴 ISSUE 1: Xác thực mã PIN sai làm văng ra trang Login (`/login`)
- **Mô tả hiện tượng:** Khi quản trị viên đang thao tác các hành động cần mã PIN (như Khóa/Mở khóa tài khoản trong `UserListPage`, Kích hoạt/Hủy bảo trì trong `BroadcastPage`, Hoàn tiền trong `PaymentHistoryPage`, Đồng bộ danh mục trong `CategoryPage`, hoặc Cấp tài khoản Admin trong `SettingsModal`), nếu nhập sai mã PIN thì hệ thống tự động đăng xuất toàn bộ và chuyển hướng (redirect) về màn hình Đăng nhập `/login`. Mất sạch ngữ cảnh và form làm việc hiện tại.
- **Nguyên nhân gốc rễ (Root Cause):**
  1. **Tại Backend (`src/Backend/modules/admin/admin.service.js`):**
     - Hàm `verifySecurityAction` (line 818) và `createAdminAccount` (line 1172) trả về lỗi với `err.statusCode = 401`.
  2. **Tại Frontend (`src/Admin-web/src/api/axios-client.js`):**
     - Response interceptor của `axiosClient` bắt mã lỗi `401`. Do URL không phải `/auth/login` hay `/auth/refresh`, interceptor ngỡ rằng phiên đăng nhập JWT hết hạn nên tự động gọi `POST /api/auth/refresh`.
     - Token được làm mới thành công, request xác thực PIN được gửi lại (`retry`).
     - Tuy nhiên, vì mã PIN người dùng vừa nhập vẫn là mã PIN sai, Backend lại tiếp tục trả về `401`.
     - Vì request đã gắn cờ `originalRequest._retry = true`, `axiosClient` kích hoạt hàm `handleLogoutRedirect()`, xóa sạch Token và chuyển hướng thẳng về `/login`.

---

### 🔴 ISSUE 2: Đổi mã PIN & Đổi mật khẩu chưa có validation
- **Mô tả hiện tượng:**
  1. **Đổi mã PIN:**
     - Cho phép nhập mã PIN mới trùng hệt với mã PIN cũ (cả Frontend `SettingsModal.jsx` và Backend `changeAdminPin` đều không chặn).
     - Ô nhập PIN chưa có ràng buộc bàn phím số chuẩn (`inputMode="numeric"`, `pattern="[0-9]*"`) và chưa có thông báo lỗi riêng cho trường hợp người dùng cố tình nhập ký tự không phải số.
  2. **Đổi mật khẩu:**
     - Form đổi mật khẩu trong `SettingsModal.jsx` thiếu validation kiểm tra `newPassword === oldPassword` ở Client-side. Người dùng nhập mật khẩu mới trùng mật khẩu cũ vẫn bấm gửi được lên server.
     - Ô nhập mã PIN cũ khi đổi mật khẩu cần được củng cố ràng buộc chỉ nhập số (6 số).

---

## 🛠️ 2. PHƯƠNG ÁN KỸ THUẬT & KIẾN TRÚC TOÀN DIỆN (DUAL-AXIS REASONING)

### 2.1. Suy Luận Chiều Ngang (Horizontal Reasoning):
- **Tác động Backend:** Cần chuẩn hóa mã phản hồi HTTP của `verifySecurityAction` và `createAdminAccount` từ `401` sang `400` (Bad Request - Sai thông tin xác thực đầu vào), đồng bộ với `changeAdminPin` và `changeAdminPassword` (vốn đã dùng `400`).
- **Tác động Frontend Interceptor:** `axios-client.js` phải có cơ chế chốt chặn (Security Action Guard): Tuyệt đối không gọi `handleLogoutRedirect()` đối với các lỗi xác thực thứ cấp (PIN/Password xác nhận hành động).
- **Tác động UI Modals & Forms:** `SecurityConfirmModal.jsx`, `SettingsModal.jsx`, `CategoryPage.jsx` phải bắt lỗi và hiển thị inline error message đỏ rõ ràng: `"Mã PIN hoặc mật khẩu quản trị viên không chính xác!"`, giữ nguyên trạng thái modal mở để người dùng nhập lại.
- **Tác động Đa Ngôn Ngữ (i18n):** Cập nhật cả `vi.js` và `en.js` với các key thông báo mới.

### 2.2. Suy Luận Chiều Sâu (Vertical / Deep-Impact Reasoning):
- **Bảo mật & Phiên làm việc (Session Security):** Việc giữ nguyên trạng thái làm việc không làm giảm tính bảo mật, vì hành động chí mạng (Critical Action) vẫn bị chặn đứng 100% khi PIN sai. Token đăng nhập của Admin vẫn còn hạn hợp lệ, không bị vô hiệu hóa oan uổng.
- **Toàn vẹn CSDL:** Thao tác đổi mã PIN chặn trùng mã cũ giúp CSDL tránh các bản ghi cập nhật rác và nâng cao tiêu chuẩn an toàn thông tin (chống tái sử dụng mã bảo mật cũ).
- **Zero Regressions:** Đảm bảo các luồng kiểm tra JWT token hết hạn thực sự (ví dụ token bị revoke, hết hạn 15 phút mà không refresh được) vẫn tự động đăng xuất an toàn như thiết kế ban đầu.

---

## 📝 3. KẾ HOẠCH TRIỂN KHAI THEO 4 BƯỚC CHI TIẾT

### Bước 1: Khắc phục lỗi Xác thực mã PIN sai làm văng về Login (Issue 1)
1. **Sửa Backend (`src/Backend/modules/admin/admin.service.js`):**
   - Chuyển `err.statusCode` từ `401` thành `400` tại `verifySecurityAction` (line 818) và `createAdminAccount` (line 1172).
   - Đảm bảo thông điệp lỗi trả về tường minh: `"Mã PIN hoặc mật khẩu quản trị viên không chính xác!"` / `"Mã PIN bảo mật của bạn không chính xác!"`.
2. **Sửa Frontend Network Interceptor (`src/Admin-web/src/api/axios-client.js`):**
   - Bổ sung danh sách bỏ qua auto-logout: Nếu request URL chứa `/admin/verify-security-action`, `/admin/create-admin`, `/admin/change-pin`, `/admin/change-password` thì KHÔNG gọi `handleLogoutRedirect()`, chỉ trả lỗi về caller.
3. **Củng cố các UI Component tiêu thụ (`SecurityConfirmModal.jsx`, `CategoryPage.jsx`, `SettingsModal.jsx`):**
   - Bắt lỗi chính xác và hiển thị message trực tiếp trên giao diện mà không đóng modal hoặc refresh trang.

### Bước 2: Bổ sung Validation cho Đổi mã PIN (Issue 2 - Phần A)
1. **Frontend (`src/Admin-web/src/components/layout/SettingsModal.jsx`):**
   - Trong `handleChangePin`:
     - Kiểm tra bắt buộc mã PIN cũ: `if (!pinForm.oldPin || !/^\d{6}$/.test(pinForm.oldPin))` $\rightarrow$ Báo lỗi: `"Vui lòng nhập đúng mã PIN hiện tại (6 chữ số)"`.
     - Kiểm tra không trùng PIN cũ: `if (pinForm.newPin === pinForm.oldPin)` $\rightarrow$ Báo lỗi: `"Mã PIN mới không được trùng với mã PIN hiện tại"`.
     - Kiểm tra chỉ cho phép nhập số: `if (!/^\d{6}$/.test(pinForm.newPin))` $\rightarrow$ Báo lỗi: `"Mã PIN mới phải bao gồm đúng 6 chữ số (0-9)"`.
   - Trong JSX các ô input PIN (cả modal popup và inline form):
     - Bổ sung `inputMode="numeric"`, `pattern="[0-9]*"`, `maxLength={6}`.
     - Lọc ký tự chặt chẽ: `onChange={(e) => setPinForm({ ...pinForm, [field]: e.target.value.replace(/\D/g, '').slice(0, 6) })}`.
2. **Backend (`src/Backend/modules/admin/admin.service.js`):**
   - Trong `changeAdminPin`:
     - Thêm kiểm tra: `if (oldPin && newPin.trim() === oldPin.trim())` $\rightarrow$ Ném lỗi `statusCode = 400`: `"Mã PIN mới không được trùng với mã PIN hiện tại"`.
     - Đảm bảo mã PIN mới và cũ đều tuân thủ regex `^\d{6}$`.

### Bước 3: Bổ sung Validation cho Đổi Mật Khẩu (Issue 2 - Phần B)
1. **Frontend (`src/Admin-web/src/components/layout/SettingsModal.jsx`):**
   - Trong `handleChangePassword`:
     - Thêm kiểm tra không trùng mật khẩu cũ:
       `if (passwordForm.newPassword === passwordForm.oldPassword)` $\rightarrow$ Báo lỗi: `"Mật khẩu mới không được trùng với mật khẩu hiện tại"`.
     - Kiểm tra mã PIN bảo mật cũ chỉ cho phép nhập số và đủ 6 số:
       `if (!passwordForm.pin || !/^\d{6}$/.test(passwordForm.pin))` $\rightarrow$ Báo lỗi: `"Mã PIN bảo mật phải bao gồm đúng 6 chữ số (0-9)"`.
   - Trong JSX ô input PIN của form đổi mật khẩu:
     - Bổ sung `inputMode="numeric"`, `pattern="[0-9]*"`, `maxLength={6}`.
     - Lọc tự động số: `onChange={(e) => setPasswordForm({ ...passwordForm, pin: e.target.value.replace(/\D/g, '').slice(0, 6) })}`.
2. **Đa ngôn ngữ (`src/Admin-web/src/locales/vi.js` & `en.js`):**
   - Bổ sung các key dịch thuật chuẩn cho các thông báo lỗi mới.

### Bước 4: Kiểm thử 2 Tầng (2-Tier Testing) & Nghiệm thu
1. **Viết/Cập nhật Bộ Test 2 Tầng (`src/Admin-web/src/tests/pin-and-security-validation.2tier.test.jsx`):**
   - **Tầng 1 (Giao diện):**
     - Nhập sai mã PIN trong `SecurityConfirmModal` $\rightarrow$ Hiển thị thông báo lỗi đỏ, modal vẫn mở, URL không bị chuyển về `/login`.
     - Nhập PIN mới trùng PIN cũ $\rightarrow$ Chặn submit, hiện thông báo lỗi.
     - Nhập Mật khẩu mới trùng Mật khẩu cũ $\rightarrow$ Chặn submit, hiện thông báo lỗi.
     - Nhập chữ vào ô PIN $\rightarrow$ Tự động loại bỏ chữ, chỉ nhận số.
   - **Tầng 2 (Tác động Hệ thống):**
     - Xác nhận `axiosClient` không xóa `STORAGE_KEYS.ACCESS_TOKEN` và không gán `window.location.href = '/login'` khi verify PIN thất bại.
     - Xác nhận `adminApi.changePin` không được gọi khi dữ liệu validation không hợp lệ.
     - Khi form hợp lệ: gọi đúng API với payload đã làm sạch.
2. **Chạy toàn bộ Test Suite:**
   - `rtk npx vitest run src/tests/admin.pin.and.audit.columns.test.jsx`
   - `rtk npx vitest run src/tests/security-confirm-modal.test.jsx`
   - `rtk npx vitest run src/tests/pin-and-security-validation.2tier.test.jsx`
3. **Cập nhật tài liệu & CodeGraph:**
   - Cập nhật `Project.md`.
   - Chạy `rtk npx codegraph build` trước khi bàn giao.

---

## 🛡️ 4. BẢNG TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Kịch bản kiểm thử | Kết quả mong đợi | Trạng thái |
|:---:|---|---|:---:|
| 1 | Nhập sai mã PIN trong `SecurityConfirmModal` | Thông báo `"Mã PIN hoặc mật khẩu quản trị viên không chính xác!"`, modal giữ nguyên, **KHÔNG văng về /login** | ✅ ĐÃ ĐẠT (PASS) |
| 2 | Nhập sai mã PIN khi tạo Admin mới | Thông báo `"Mã PIN bảo mật của bạn không chính xác!"`, giữ nguyên step 2, **KHÔNG văng về /login** | ✅ ĐÃ ĐẠT (PASS) |
| 3 | Đổi PIN: Nhập PIN mới trùng PIN cũ | Chặn submit tại Client, hiện lỗi `"Mã PIN mới không được trùng với mã PIN hiện tại"` | ✅ ĐÃ ĐẠT (PASS) |
| 4 | Đổi PIN: Nhập chữ cái hoặc ký tự đặc biệt | Ô input chỉ nhận số (0-9), tối đa 6 ký tự | ✅ ĐÃ ĐẠT (PASS) |
| 5 | Đổi Mật khẩu: Mật khẩu mới trùng Mật khẩu cũ | Chặn submit tại Client, hiện lỗi `"Mật khẩu mới không được trùng với mật khẩu hiện tại"` | ✅ ĐÃ ĐẠT (PASS) |
| 6 | Đổi Mật khẩu: Nhập chữ vào ô PIN bảo mật | Ô input chỉ nhận số (0-9), nếu không đủ 6 số thì chặn submit và báo lỗi | ✅ ĐÃ ĐẠT (PASS) |
| 7 | Kiểm thử 2 Tầng (Rule 11) | 100% test cases Tầng 1 (Giao diện) và Tầng 2 (Tác động hệ thống thực tế) đều PASS | ✅ ĐÃ ĐẠT (PASS) |

---

## 🏆 5. KẾT QUẢ KIỂM THỬ THỰC TẾ & CHỨNG THỰC ZERO REGRESSIONS

1. **Backend Unit & Security Action Tests (`node:test`):**
   - `src/Backend/tests/unit/admin.security.action.test.js`: **5/5 tests PASS** (Xác thực HTTP 400 cho sai PIN, trả về thông điệp lỗi chính xác).
   - `src/Backend/tests/unit/admin.security.refinement.test.js`: **7/7 tests PASS** (Xác thực kiểm tra `samePin`, regex 6 số, bảo vệ an toàn CSDL).
   - **Toàn bộ Backend Regression Suite:** **418/418 tests PASS 100%** (76 suites, 0 failed, duration ~9.6s).
2. **Admin-web Frontend Tests (`vitest`):**
   - `src/Admin-web/src/tests/pin-and-security-validation.2tier.test.jsx`: **8/8 tests PASS** (Bộ test 2 tầng chuyên biệt cho Issue 1 & Issue 2).
   - `src/Admin-web/src/tests/admin.pin.and.audit.columns.test.jsx`: **8/8 tests PASS**.
   - `src/Admin-web/src/tests/security-confirm-modal.test.jsx`: **3/3 tests PASS**.
   - `src/Admin-web/src/tests/broadcast.maintenance.history.test.jsx`: **9/9 tests PASS**.
   - `src/Admin-web/src/tests/broadcast.page.test.jsx`: **11/11 tests PASS**.
   - `src/Admin-web/src/tests/broadcast.schedule.multi.2tier.test.jsx`: **7/7 tests PASS**.
   - `src/Admin-web/src/tests/broadcast.refinement.2tier.test.jsx`: **11/11 tests PASS**.
   - `src/Admin-web/src/tests/phase1.i18n.test.jsx` & `phase3.i18n.test.jsx`: **PASS 100%**.
