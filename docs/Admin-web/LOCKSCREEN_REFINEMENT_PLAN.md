# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH MÀN HÌNH KHÓA AN TOÀN (LOCK SCREEN REFINEMENT PLAN)

> **Mã kế hoạch:** `PLAN-ADMIN-LOCKSCREEN-REFINEMENT`  
> **Trạng thái:** `PENDING_PO_APPROVAL` (Đang chờ PO duyệt - TUYỆT ĐỐI CHƯA SỬA CODE KHI CHƯA CÓ PHÊ DUYỆT)  
> **Module liên quan:**  
> - Frontend: `src/Admin-web/src/components/layout/LockScreenModal.jsx`, `src/Admin-web/src/store/settings.context.jsx`, `src/Admin-web/src/store/auth.context.jsx`  
> - Backend: `src/Backend/modules/auth/auth.controller.js` (Endpoint `/api/auth/me`), `src/Backend/modules/auth/auth.service.js`  
> - Tests (2-Tier): `src/Admin-web/src/tests/settings.autolock.security.test.jsx`, `src/Admin-web/src/tests/lockscreen.session.test.jsx`, `src/Admin-web/src/tests/lockscreen.refinement.2tier.test.jsx`  

---

## 🔍 PHẦN 1: BÁO CÁO KHẢO SÁT & XÁC NHẬN CÁC ISSUE LOG TỪ PO

Dựa trên khảo sát thực tế tại mã nguồn [LockScreenModal.jsx](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/components/layout/LockScreenModal.jsx), [auth.controller.js](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/auth/auth.controller.js) và [settings.context.jsx](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/store/settings.context.jsx):

| STT | Issue PO đã log | Hiện trạng mã nguồn | Đánh giá & Giải pháp kỹ thuật |
|:---:|---|---|---|
| **1** | Khi bị khóa, nhập đúng mật khẩu xong bị out ra màn hình đăng nhập mà không mở lại giao diện hiện có | Đã giải quyết trong Task trước đó: `unlockScreen` nhận `syncAuthSession`, đồng bộ token mới vào localStorage và đóng modal mà không đẩy router về `/login`. | **DONE** (Xác nhận đã hoạt động chính xác qua test `lockscreen.session.test.jsx`). |
| **2** | Bỏ phần hình ảnh cá nhân "A" (fix) | Dòng 86-93 của `LockScreenModal.jsx` đang render hộp chữ nhật 80x80px gradient chứa chữ cái `avatarLetter` ("A") kèm badge ổ khóa nhỏ ở góc. | **CẦN SỬA:** Loại bỏ hoàn toàn khối avatar `avatarLetter` mang tính cá nhân này. Thay thế bằng biểu tượng Ổ khóa An ninh trung tâm (`lock` icon) trang trọng, tinh tế bo tròn viền vàng hổ phách chuẩn màn hình khóa Enterprise, giúp người dùng nhận diện ngay tính năng an toàn mà không bị gán hình ảnh thừa. |
| **3** | Phần hiển thị username + Email phải hiển thị đúng giá trị được lấy từ CSDL, không gán cứng như hiện tại (fix) | - `LockScreenModal.jsx` (dòng 30-31) đang gán fallback: `displayName = activeUser?.fullname || activeUser?.username || 'Quản Trị Viên'`; `displayEmail = activeUser?.email || activeUser?.username || 'admin@finance.local'`. Chuỗi `'admin@finance.local'` và `'Quản Trị Viên'` là gán cứng giả lập!<br>- Trong Backend `authController.me` (dòng 104-116), response chỉ bóc tách từ JWT token (vốn chỉ có `username`, `idrole`, thiếu `email` và `fullname`), không truy vấn CSDL PostgreSQL. | **CẦN SỬA:**<br>1. **Backend:** Trong `authController.me`, truy vấn thông tin tươi mới từ CSDL PostgreSQL (`account` kết hợp `User`), trả về đầy đủ `username`, `email` và `fullname` thật từ CSDL.<br>2. **Frontend:** Hiển thị đúng `activeUser?.username` và `activeUser?.email` từ CSDL. Tuyệt đối bãi bỏ mọi chuỗi gán cứng fallback như `'admin@finance.local'`. Nếu tài khoản chưa có email trong CSDL thì không hiển thị dòng email hoặc để trống an toàn. |
| **4** | Bỏ icon "key" (fix) | Dòng 116-118 của `LockScreenModal.jsx` đang render icon `<span className="material-symbols-outlined ...">key</span>` ở bên trái ô input mật khẩu, khiến ô input phải thụt lề `pl-9`. | **CẦN SỬA:** Xóa bỏ thẻ icon `key` này; điều chỉnh padding ô input mật khẩu về chuẩn `px-3.5` hoặc `px-3` thanh thoát, sạch sẽ. |
| **5** | Bỏ dòng "Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị" (fix) | Dòng 166 của `LockScreenModal.jsx` đang render: `<span className="text-[11px] text-slate-500">{t('lockScreen.subtitle', 'Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị')}</span>`. | **CẦN SỬA:** Xóa bỏ hoàn toàn dòng text phụ này để giao diện không bị rối mắt. |
| **6** | Đưa nút "đăng xuất" lên ngang với nút "Mở khóa màn hình" (fix) | Nút "Mở Khóa Màn Hình" (type `submit`) nằm riêng một hàng chiếm `w-full`. Còn nút "Đăng xuất" nằm lẻ loi ở góc dưới cùng bên phải trong thẻ footer `pt-2 border-t border-slate-800`. | **CẦN SỬA:** Đưa nút "Đăng xuất" lên cùng một hàng ngang với nút "Mở Khóa Màn Hình" (layout flex 2 nút cân đối: nút [Đăng xuất] phụ ở bên trái với tone đỏ/viền slate, nút [Mở Khóa Màn Hình] chính ở bên phải với tone emerald rực rỡ). Đồng thời xóa bỏ khối thẻ footer cũ. |

---

## 📐 PHẦN 2: SUY LUẬN 2 CHIỀU (DUAL-AXIS REASONING)

### 1. Suy luận theo Chiều Ngang (Horizontal Reasoning):
- **Cơ sở dữ liệu (PostgreSQL):** Bảng `account` lưu trữ `username`, `email`, liên kết 1-1 với bảng `User` (lưu `fullname`, `email`). Khi Admin đăng nhập hoặc khi lấy thông tin qua `/api/auth/me`, dữ liệu email và username phải được lấy chính xác từ PostgreSQL, không dùng dữ liệu mock.
- **Frontend State Management (`auth.context.jsx` & `settings.context.jsx`):**
  - Khi màn hình bị khóa, `lockScreen()` ghi nhận `LOCKED_USER` với đầy đủ `username` và `email` từ `user` state.
  - Khi `LockScreenModal` render, `activeUser` sẽ lấy đúng dữ liệu thật từ `user || lockedUser`.
- **Đa ngôn ngữ (i18n):** Các nhãn nút bấm "Đăng xuất" (`nav.logout`), "Mở Khóa Màn Hình" (`lockScreen.unlockBtn`) đã sẵn sàng trong `vi.js` và `en.js`, đảm bảo hỗ trợ đầy đủ 2 ngôn ngữ.

### 2. Suy luận theo Chiều Sâu (Vertical / Deep-impact Reasoning):
- **Trải nghiệm người dùng:** Bố cục mới tinh gọn, không còn icon "key" chật chội, không còn subtitle dài dòng, nút Đăng xuất nằm ngay cạnh nút Mở khóa giúp Admin dễ dàng thoát ra nếu không muốn tiếp tục phiên làm việc trên máy tính đó.
- **Tính toàn vẹn dữ liệu và bảo mật:**
  - Token JWT vẫn được tiêu hủy an toàn khỏi localStorage khi màn hình khóa (`lockScreen`).
  - Khi mở khóa bằng mật khẩu, hệ thống gọi API `authApi.login` xác thực lại với bcrypt hash trên server, cấp phát lại cặp token JWT mới hợp lệ.
  - Zero Regressions: Không ảnh hưởng đến các router khác, không phá vỡ logic phân quyền `ProtectedRoute.jsx`.

---

## 🛠️ PHẦN 3: KẾ HOẠCH TRIỂN KHAI TỪNG BƯỚC (STEP-BY-STEP TASKS)

### Task 1: Cập nhật Backend `/api/auth/me` để trả về Email và Username tươi mới từ CSDL
- **Files:** `src/Backend/modules/auth/auth.controller.js`
- **Chi tiết:**
  - Trong phương thức `me(req, res)`: Truy vấn CSDL Prisma `prisma.account.findUnique` theo `req.user.idaccount` (include `User: true, role: true`).
  - Trả về payload đầy đủ:
    ```javascript
    email: account.User ? account.User.email : (account.email || ""),
    fullname: account.User ? account.User.fullname : "",
    username: account.username,
    ...
    ```
- **Kiểm thử:** Chạy unit test backend `rtk npm test -- src/Backend/tests/unit/admin.operations.test.js` hoặc test liên quan auth.

### Task 2: Tái cấu trúc giao diện `LockScreenModal.jsx` theo 5 điểm tinh chỉnh của PO
- **Files:** `src/Admin-web/src/components/layout/LockScreenModal.jsx`
- **Chi tiết:**
  1. **Bỏ phần hình ảnh cá nhân "A":** Thay khối `avatarLetter` bằng icon ổ khóa an ninh trang trọng `lock` (viền tròn/bo góc amber thanh lịch).
  2. **Hiển thị username + Email thật từ CSDL:**
     - Dòng 1: `activeUser?.username` (chính xác username từ CSDL).
     - Dòng 2: `activeUser?.email` (nếu có email từ CSDL, không gán chuỗi giả `admin@finance.local`).
  3. **Bỏ icon "key":** Xóa thẻ `<span ...>key</span>`, cập nhật ô input thành padding chuẩn `pl-3.5 pr-10`.
  4. **Bỏ dòng subtitle:** Xóa bỏ dòng chữ "Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị".
  5. **Đưa nút "Đăng xuất" lên ngang hàng với nút "Mở Khóa Màn Hình":**
     - Đặt cả 2 nút vào cùng 1 hàng Flexbox (`flex items-center gap-3 pt-2`):
       - Nút [Đăng xuất]: `type="button"`, viền slate-700, chữ rose-400, icon `logout`, xử lý `handleLogout`.
       - Nút [Mở Khóa Màn Hình]: `type="submit"`, background emerald-600, icon `lock_open`, xử lý submit mở khóa.
     - Xóa bỏ khối thẻ `div` footer cũ ở dưới cùng.

### Task 3: Viết & Cập nhật Test 2 Tầng (2-Tier Testing Architecture - Rule 11)
- **Files:**
  - `src/Admin-web/src/tests/settings.autolock.security.test.jsx` (cập nhật assertion avatar letter thành icon lock, kiểm tra username/email thật)
  - `src/Admin-web/src/tests/lockscreen.refinement.2tier.test.jsx` (viết mới bộ test chuyên sâu thẩm tra cả 5 điểm tinh chỉnh)
- **Nội dung kiểm thử 2 tầng:**
  - 🧱 **Tầng 1 (Giao diện & Thao tác):**
    - [x] Không còn avatar chữ cái cá nhân "A", hiển thị icon ổ khóa an ninh trung tâm.
    - [x] Hiển thị chính xác Username và Email từ mock CSDL, không có chuỗi gán cứng `'admin@finance.local'`.
    - [x] Không còn icon "key" trong ô input mật khẩu.
    - [x] Không còn dòng chữ subtitle "Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị".
    - [x] Nút "Đăng xuất" và nút "Mở Khóa Màn Hình" nằm ngang hàng nhau trong cùng khối điều khiển.
    - [x] Thao tác nhập mật khẩu, toggle ẩn/hiện mật khẩu hoạt động trơn tru.
  - ⚡ **Tầng 2 (Tác động hệ thống thực tế):**
    - [x] Bấm nút [Đăng xuất] -> Gọi `logout()`, xóa sạch toàn bộ 6 keys trong `localStorage` (`IS_LOCKED`, `LOCKED_USER`, `ACCESS_TOKEN`, `REFRESH_TOKEN`, `USER`, `LOCKED_AT`).
    - [x] Bấm [Mở Khóa Màn Hình] với mật khẩu đúng -> Gọi `authApi.login` với username thật từ CSDL, tái cấp phát token, đóng LockScreenModal và giữ nguyên trạng thái phiên làm việc.

### Task 4: Thẩm tra toàn diện và Cập nhật Nguồn sự thật (Rule 8)
- Chạy toàn bộ test suite của Admin-web bằng `rtk npm test`.
- Kiểm tra TypeScript/Lint: `rtk npm run lint` (hoặc test pass 100%).
- Cập nhật tài liệu liên quan [docs/Admin-web/01-authentication-and-authorization.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Admin-web/01-authentication-and-authorization.md) và `Project.md`.
- Chạy `rtk npx codegraph build` trước khi nghiệm thu.

---

## ❓ CÂU HỎI XÁC NHẬN VỚI PO (PO CONFIRMATION)

Kính đề xuất PO xem xét 2 chi tiết giao diện trước khi AI bắt tay vào thực thi:
1. **Khối Header Icon thay thế phần hình ảnh cá nhân "A":**
   - **Đề xuất (Khuyên dùng):** Thay bằng một icon Ổ khóa an ninh (`lock`) kích thước vừa vặn `w-14 h-14` nền `bg-amber-500/10` viền `border-amber-500/30` màu hổ phách trang trọng ở chính giữa, giữ đúng đặc trưng của màn hình khóa bảo mật.
   - **Phương án khác:** Bỏ hoàn toàn khối icon này, đẩy phần thông tin Username/Email lên sát đỉnh modal.
2. **Hiển thị thông tin người dùng:**
   - **Đề xuất:** Dòng trên hiển thị Username (ví dụ: `admin`), dòng dưới hiển thị Email thật từ CSDL (ví dụ: `admin@gmail.com`). (Nếu tài khoản có Họ và tên `fullname`, PO muốn hiển thị `fullname` trước hay ưu tiên `username` như đúng mô tả log?)

---

> ⚠️ **TUÂN THỦ QUY TẮC TỐI CAO 1:** Kế hoạch này đã được lưu tại [docs/Admin-web/LOCKSCREEN_REFINEMENT_PLAN.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Admin-web/LOCKSCREEN_REFINEMENT_PLAN.md). AI đang dừng lại ở Phase 1 và **chờ PO duyệt kế hoạch cũng như xác nhận các câu hỏi trên trước khi sửa code**.
