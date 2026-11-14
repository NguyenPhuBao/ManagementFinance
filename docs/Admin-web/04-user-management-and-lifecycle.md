# 👥 Chức Năng 04: Quản Lý Người Dùng & Vòng Đời Tài Khoản (User Management & Lifecycle)

> **Mã chức năng:** `ADMIN-FEAT-04`  
> **Phiên bản tài liệu:** `v2.6` (Cập nhật ngày 23/10/2026)  
> **Module phụ trách:**  
> - Frontend: `src/Admin-web/src/pages/users/UserListPage.jsx`, `src/Admin-web/src/components/common/UserDetailModal.jsx`, `UserDevices.jsx`, `src/Admin-web/src/components/ui/SecurityConfirmModal.jsx` (trang `/users/:id` đã bỏ ở G2.1)  
> - Backend: `src/Backend/modules/admin/admin.service.js`, `admin.repository.js`, `admin.controller.js`, `src/Backend/utils/masking.util.js`, `src/Backend/utils/content-filter.util.js`  

---

## 📌 1. TỔNG QUAN & MỤC ĐÍCH NGHIỆP VỤ

Chức năng **Quản Lý Người Dùng & Vòng Đời Tài Khoản** cho phép quản trị viên theo dõi, giám sát và can thiệp kịp thời vào trạng thái hoạt động của các tài khoản người dùng cuối (Client-app). 

Hệ thống được thiết kế tuân thủ tuyệt đối **Nghị định 13/2023/NĐ-CP về Bảo vệ dữ liệu cá nhân** và chuẩn **GDPR**:
- **Bảo toàn hiển thị trạng thái xóa mềm (Soft-Delete Visibility):** Sau khi thực hiện xóa mềm, tài khoản không biến mất khỏi bảng một cách khó hiểu mà tự động hiển thị thẻ trạng thái đỏ `Đã xóa` (`Deleted`), giúp kiểm toán viên và quản trị viên dễ dàng theo dõi.
- **Bảo vệ quyền riêng tư 100%:** Dữ liệu nhạy cảm (Email, SĐT, Địa chỉ, IP) hiển thị trên màn hình đều được mặt nạ hóa (Masking) ngay từ tầng Backend.
- **Quy trình khóa tài khoản nghiêm ngặt:** Bắt buộc nhập lý do nghiệp vụ hợp lệ và phát sinh sự kiện **Cưỡng chế đăng xuất (Force Logout)** tức thời trên thiết bị di động.
- **Giao dịch xóa tài khoản an toàn 5 bước:** Đảm bảo toàn vẹn dữ liệu kế toán và lịch sử giao dịch bằng Prisma Transaction, không dùng `DELETE` vật lý.

---

## ⚙️ 2. VÒNG ĐỜI TÀI KHOẢN & CƠ CHẾ HOẠT ĐỘNG (LIFECYCLE FLOW)

```mermaid
stateDiagram-v2
    [*] --> Active: Người dùng đăng ký thành công (OTP)
    
    Active --> Inactive: Admin khóa tài khoản (Bắt buộc nhập lý do)
    Inactive --> Active: Admin mở khóa tài khoản
    
    Active --> PendingDelete: Người dùng yêu cầu xóa tài khoản từ Mobile App
    PendingDelete --> Active: Người dùng hủy yêu cầu xóa (Đăng nhập lại trong 30 ngày)
    
    PendingDelete --> Deleted: Hết hạn 30 ngày (Countdown = 0)
    Active --> Deleted: Admin thực hiện Xóa mềm (Soft-delete khẩn cấp)
    Inactive --> Deleted: Admin thực hiện Xóa mềm
    
    Deleted --> [*]: Lưu trữ kiểm toán tài chính (Hiển thị badge Đã xóa trên Admin-web)
```

### 2.1. Quy trình Khóa Tài Khoản & Cưỡng Chế Đăng Xuất (Force Logout)
Khi quản trị viên phát hiện tài khoản người dùng có dấu hiệu gian lận, rửa tiền hoặc vi phạm điều khoản:
1. Admin chọn **"Vô hiệu hóa (Khóa tài khoản)"** và nhập lý do (ví dụ: *"Phát hiện dấu hiệu đăng nhập bất thường từ nhiều thiết bị lạ"*).
2. Backend kiểm tra tính hợp lệ của lý do (`validateReasonInactive`).
3. Cập nhật `status = 'Inactive'` và lưu lý do vào database.
4. Xóa sạch cache xác thực `invalidateAccountCache(idaccount)`.
5. Phát sự kiện Socket.io `force_logout` mang mã `ACCOUNT_INACTIVE` tới thiết bị di động của người dùng.
6. **Trên ứng dụng Mobile Flutter:** Ứng dụng lập tức bắt sự kiện, hiển thị hộp thoại thông báo lý do khóa của Admin, xóa sạch token trong máy và đẩy người dùng ra khỏi phiên làm việc về màn hình Đăng nhập.

### 2.2. Giao Dịch Xóa Mềm 5 Bước An Toàn (Soft-Delete Transaction)
Khi Admin thực hiện xóa tài khoản, để bảo toàn tính toàn vẹn dữ liệu kế toán và lịch sử giao dịch, hệ thống không chạy lệnh `DELETE` vật lý mà thực thi giao dịch Prisma Transaction 5 bước bất khả xâm phạm:
```javascript
return prisma.$transaction(async (tx) => {
  // Bước 1: Đánh dấu xóa Account (status = 'Deleted', countdown = 0, delete_at = now)
  await tx.account.update({ where: { idaccount }, data: { status: 'Deleted', countdown: 0, delete_at: now } });
  
  // Bước 2: Đánh dấu xóa User (delete_at = now)
  await tx.user.update({ where: { iduser }, data: { delete_at: now } });
  
  // Bước 3: Đóng băng toàn bộ ví tài chính liên quan (status = 'Inactive')
  await tx.wallet.updateMany({ where: { idaccount, delete_at: null }, data: { status: 'Inactive' } });
  
  // Bước 4: Ngắt kết nối ngân hàng nhưng giữ lại lịch sử đối soát
  await tx.bank_account.updateMany({ where: { idaccount }, data: { connect_status: 'Disconnected' } });
  
  // Bước 5: Thu hồi toàn bộ Refresh Token ngay lập tức
  await tx.refreshtoken.updateMany({ where: { idaccount }, data: { status: true } });
});
```

Sau khi xóa thành công, giao diện Frontend tự động mở rộng bộ lọc `filter.statuses` để bao gồm `'deleted'`, giúp dòng người dùng vừa bị xóa lập tức hiển thị badge đỏ pastel `Đã xóa` thay vì biến mất đột ngột.

---

## 📐 3. CÁC QUY TẮC MẶT NẠ HÓA DỮ LIỆU (DATA MASKING RULES)

Nhằm đảm bảo quản trị viên không thể thu thập hoặc làm rò rỉ dữ liệu cá nhân của khách hàng:

| Trường thông tin | Quy tắc mặt nạ hóa (Masking Formula) | Dữ liệu gốc mẫu | Dữ liệu hiển thị trên Admin-web |
|---|---|---|---|
| **Email** | Giữ ký tự đầu + `***` + ký tự cuối trước `@` + giữ domain | `nguyenphubao@gmail.com` | `n***o@gmail.com` |
| **Số điện thoại** | Giữ 2 số đầu + `****` + 3 số cuối | `0901234567` | `09****567` |
| **Địa chỉ** | Thay thế số nhà & tên đường bằng `***`, giữ lại Tỉnh/Thành phố | `123 Nguyễn Văn Cừ, Quận 5, TP. Hồ Chí Minh` | `***, TP. Hồ Chí Minh` |
| **Địa chỉ IP** | Giữ 2 octet đầu, che 2 octet cuối dạng `xx.xx` | `113.161.45.12` | `113.161.xx.xx` |

---

## ⛔ 4. CÁC RÀNG BUỘC PHÁP LÝ & AN NINH TUYỆT ĐỐI

1. **Ràng buộc Quyền Tự Chủ GDPR (`PendingDelete Protection`):**
   - Khi người dùng gửi yêu cầu xóa tài khoản từ Mobile App, tài khoản chuyển sang trạng thái `PendingDelete` với thời gian đếm ngược 30 ngày (Countdown).
   - **Quy tắc bất di bất dịch:** Admin **tuyệt đối KHÔNG ĐƯỢC PHÉP** thay đổi trạng thái hoặc thao tác xóa trên tài khoản đang trong trạng thái `PendingDelete`. Server sẽ từ chối với lỗi HTTP 400 để bảo vệ quyền tự do thu hồi yêu cầu của người dùng.
2. **Bảo vệ tài khoản Quản trị viên Tối cao:**
   - Admin không thể tự xóa tài khoản của chính mình hoặc xóa tài khoản của các Admin khác (`idrole === 1`).
3. **Bảo vệ nội dung lý do khóa (`validateReasonInactive`):**
   - Lý do vô hiệu hóa bắt buộc phải có độ dài từ 5 đến 255 ký tự, không được bỏ trống và không được chứa các từ ngữ phản cảm.

---

## 💼 5. CÔNG DỤNG & GIÁ TRỊ NGHIỆP VỤ

- **Kiểm soát rủi ro tức thì:** Ngăn chặn ngay lập tức các tài khoản đang có hành vi spam giao dịch hoặc tấn công hệ thống.
- **Minh bạch thông tin:** Quản trị viên nắm rõ tài khoản nào đang hoạt động, tài khoản nào đang trong diện chờ thanh lý 30 ngày, và tài khoản nào đã bị xóa mềm phục vụ đối soát.
- **Tuân thủ pháp luật:** Tránh mọi rủi ro kiện tụng liên quan đến việc nhân viên nội bộ xem lén thông tin liên lạc cá nhân của khách hàng.

---

## 🧩 6. TÍNH NĂNG ĐI KÈM TRÊN GIAO DIỆN (cập nhật 2026-11-14 theo mã)

1. **Danh sách người dùng (`UserListPage.jsx`):** 4 thẻ số liệu; 5 tab trạng thái (mặc định ẩn "Đã xóa"); tìm kiếm; bộ lọc gói và trạng thái; phân trang; số điện thoại đã che; cập nhật realtime. Vô hiệu hóa bắt buộc lý do; kích hoạt lại có xác nhận; xóa mềm phải xác thực PIN và chỉ áp cho tài khoản đã vô hiệu hóa.
2. **Hộp chi tiết người dùng (`UserDetailModal.jsx`):** ngày tạo, gói, trạng thái, lý do khóa, ngày chờ xóa; dòng **Chính sách bảo mật** ("Đã đồng ý vN · thời gian" hoặc "Chưa đồng ý vN", `GET /api/admin/getuser/:id/policy`); dòng **Bản sao dữ liệu** (trạng thái yêu cầu gần nhất: chưa yêu cầu / đang tạo / sẵn sàng tới … / đã hết hạn / tạo lỗi, `GET /api/admin/getuser/:id/data-exports`).
3. **Thiết bị đăng nhập (`components/common/UserDevices.jsx`):** 10 lượt truy cập gần nhất, tên thiết bị rút gọn, IP đã che; "Xem IP đầy đủ" bắt buộc PIN trong cùng request và ghi nhật ký; IP đầy đủ quá 365 ngày đã bị xóa nên không còn nút xem.
4. **Cập nhật realtime:** `admin.user_registered` chèn người dùng mới; `admin.user_status_changed` cập nhật trạng thái và số ngày chờ xóa.
5. **Kiểm thử:** `src/Admin-web/src/tests/users.test.jsx` (17 ca).

---

## 📱 7. ẢNH HƯỞNG ĐẾN HỆ THỐNG & MOBILE APP (CLIENT-APP)

- **Đến Backend:**
  - Lệnh soft-delete được gói gọn trong 1 Transaction nguyên tử (ACID), cam kết hoặc hoàn tất tất cả hoặc rollback, không bao giờ để lại dữ liệu rác.
  - Thu thập và lưu vết thiết bị người dùng vào bảng `account_device_history` qua cơ chế Diff Check (Đổi IP/Device thì INSERT dòng mới, trùng thì UPDATE `last_active_at`).
- **Đến Mobile App (Client-app):**
  - **Khóa tài khoản:** Client nhận Socket `force_logout`, bị xóa JWT, chuyển về màn hình đăng nhập. Mọi API sau đó đều trả về HTTP 401/403 kèm thông báo lý do Admin đã nhập.
  - **Mở khóa tài khoản:** Người dùng có thể đăng nhập lại bình thường trên điện thoại.
  - **Xóa mềm:** Toàn bộ liên kết ngân hàng bị ngắt kết nối an toàn, các giao dịch offline trên SQLite Drift sẽ không thể push sync lên máy chủ.
  - **Gửi Device Name:** Client-app (bản Android) đính kèm header `x-device-name` trên các request API (qua kênh Kotlin `flowmoney/thiet_bi`) để hệ thống ghi nhận lịch sử thiết bị.

---

## 📡 8. DANH MỤC API & SOCKET.IO PHỤ TRÁCH

### REST API Endpoints
| Phương thức | Endpoint | Chức năng | Phân quyền |
|---|---|---|---|
| `GET` | `/api/admin/getuser` | Lấy danh sách toàn bộ người dùng Client-app (đã mask) | Admin |
| `GET` | `/api/admin/getuser/:id` | Lấy chi tiết thông tin tài khoản và người dùng | Admin |
| `PATCH` | `/api/admin/updatestatus/:id` | Khóa hoặc mở khóa tài khoản người dùng | Admin |
| `DELETE` | `/api/admin/deleteuser/:id` | Xóa mềm tài khoản an toàn 5 bước | Admin |
| `GET` | `/api/admin/getuser/:id/devices` | 10 lượt truy cập gần nhất (IP đã che) | Admin |
| `POST` | `/api/admin/getuser/:id/devices/:deviceId/reveal-ip` | Xem IP đầy đủ, bắt buộc PIN (`REVEAL_IP`), ghi nhật ký | Admin |
| `GET` | `/api/admin/getuser/:id/policy` | Phiên bản chính sách hiện hành và các lần đồng ý | Admin |
| `GET` | `/api/admin/getuser/:id/data-exports` | 5 yêu cầu bản sao dữ liệu gần nhất | Admin |

### Socket.io Events
- **Lắng nghe (`Client -> Server`):**
  - `admin.user_registered`: Nhận thông tin tài khoản mới đăng ký từ Client-app.
  - `admin.user_status_changed`: Nhận biến động trạng thái tài khoản.
- **Phát tán (`Server -> Client-app`):**
  - `force_logout`: Gửi tới socket của người dùng cụ thể để cưỡng chế đăng xuất thiết bị.
