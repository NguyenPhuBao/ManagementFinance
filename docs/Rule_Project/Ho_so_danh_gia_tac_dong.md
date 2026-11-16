# Hồ sơ đánh giá tác động xử lý dữ liệu cá nhân — BẢN NHÁP

Căn cứ: Luật Bảo vệ dữ liệu cá nhân 2025 (91/2025/QH15) Điều 21, 22: lập hồ sơ, gửi 01 bản chính cho cơ quan chuyên trách trong 60 ngày kể từ ngày bắt đầu xử lý, cập nhật khi thay đổi. Mẫu hồ sơ chính thức nằm trong phụ lục Nghị định 356/2025/NĐ-CP (10 mẫu): **chưa có bản gốc**, bản nháp này gom sẵn dữ liệu thật của hệ thống để điền vào mẫu khi có. Ngày lập: 2026-11-13. Nguồn: mã nguồn, `schema.prisma`, `Data_Security.md`.

## 1. Bên kiểm soát và xử lý dữ liệu

- Hệ thống: FlowMoney (ứng dụng quản lý tài chính cá nhân và gia đình; Client-app Flutter, Admin-web, Backend).
- Bên kiểm soát: (điền tên tổ chức / cá nhân chịu trách nhiệm, địa chỉ, đầu mối).
- Ngày bắt đầu xử lý dữ liệu: (điền ngày phát hành bản đầu tiên cho người dùng thật).
- Nhân sự bảo vệ dữ liệu: (điền; Nghị định 356/2025 Điều 13 yêu cầu tối thiểu cao đẳng, 2 năm kinh nghiệm, đã đào tạo — mức xác minh: một nguồn).

## 2. Mục đích xử lý

| Mục đích | Dữ liệu dùng |
|---|---|
| Tạo và quản lý tài khoản, đăng nhập | email, tên đăng nhập, mật khẩu (băm), họ tên, số điện thoại (mã hóa), địa chỉ (mã hóa) |
| Ghi chép, đồng bộ, thống kê thu chi | giao dịch, ví, ngân sách, hóa đơn, mục tiêu, danh mục |
| Quản lý tài chính gia đình (household) | thành viên, quyền, ví / ngân sách chung |
| Thanh toán gói Premium | đơn hàng, giao dịch thanh toán (qua PayOS) |
| Bảo mật, chống chiếm đoạt tài khoản, điều tra sự cố | lịch sử thiết bị, IP (che + mã hóa), nhật ký kiểm toán, dữ liệu AIOps |
| Trợ lý AI, phân loại giao dịch, đọc hóa đơn (OCR) | nội dung câu hỏi, mô tả giao dịch, ảnh hóa đơn (gửi dịch vụ AI đám mây; văn bản đi qua `utils/masking.util.js`, phạm vi che với ảnh hóa đơn: cần xác minh — xem `docs/AI/`) |
| Thông báo hệ thống, email | email, nội dung thông báo |

## 3. Loại dữ liệu

| Nhóm | Bảng | Phân loại |
|---|---|---|
| Định danh | `account`, `user` | cơ bản (số điện thoại, địa chỉ mã hóa AES-256-GCM) |
| Tài chính | `transaction`, `wallet`, `budget`, `bill`, `goal`, `bank_account`, `payment_order`, `payment_transaction` | **nhạy cảm** |
| Hoạt động trên mạng | `account_device_history`, `refreshtoken`, `audit_log`, `aiops_*` | **nhạy cảm** (Nghị định 356/2025) |
| Xác thực | mật khẩu, PIN (băm bcrypt), OTP (băm) | bảo mật đặc biệt |

## 4. Bên xử lý và chuyển dữ liệu ra nước ngoài

| Bên | Vai trò | Vị trí | Ghi chú |
|---|---|---|---|
| Supabase (AWS) | CSDL PostgreSQL, lưu trữ tệp | Tokyo, Nhật Bản | **chuyển dữ liệu ra nước ngoài** |
| Render | chạy Backend | (điền khu vực) | |
| Redis (nhà cung cấp theo `REDIS_URL`) | hàng đợi, bộ đếm | (điền) | |
| Dịch vụ AI đám mây (theo `GEMINI_API_KEY`, `DEEPSEEK_API_KEY`) | trợ lý AI, OCR, phân loại | nước ngoài | **chuyển dữ liệu ra nước ngoài**; phạm vi che dữ liệu trước khi gửi: cần xác minh |
| Dịch vụ email (Resend / SMTP) | gửi OTP, thông báo | (điền) | |
| PayOS | cổng thanh toán | Việt Nam | |
| SePay | đối soát ngân hàng (chức năng Bank đang tạm dừng) | Việt Nam | |

Việc chuyển dữ liệu ra nước ngoài cần **hồ sơ đánh giá tác động chuyển dữ liệu cá nhân ra nước ngoài** riêng (Luật 91/2025; mẫu trong Nghị định 356/2025) — chưa lập.

## 5. Biện pháp bảo vệ đã áp dụng

- Mã hóa AES-256-GCM khi lưu: số điện thoại, địa chỉ, tài khoản ngân hàng, IP đầy đủ; chỉ mục mù HMAC để tra cứu; TLS khi truyền.
- Cách ly người dùng: mọi truy vấn lọc `idaccount` lấy từ JWT; `/sync/push` kiểm chủ sở hữu.
- Nhật ký kiểm toán chỉ ghi thêm (trigger `trg_protect_auditlog`), giao dịch được bảo vệ (`trg_protect_transaction`).
- Admin: PIN cho thao tác nhạy cảm, khóa xác thực sau 5 lần sai / 15 phút; xem IP đầy đủ phải nhập PIN và ghi nhật ký.
- AIOps phát hiện bất thường, cách ly IP / tài khoản.
- Thời hạn lưu và thanh lọc tự động: `Data_Security.md` mục 8, 9.

## 6. Rủi ro còn lại và việc cần làm

| Rủi ro | Việc | Trạng thái |
|---|---|---|
| Chưa lưu bằng chứng đồng ý, chưa thông báo xử lý dữ liệu nhạy cảm | Bảng + API đồng ý (T3), màn hình ở Client-app | đang làm |
| Thời hạn xóa 30 ngày có thể vượt mức 20 ngày | Rà soát luồng `PendingDelete` (T3) | đang làm |
| Chưa có chức năng người dùng nhận bản sao dữ liệu | API xuất dữ liệu (T3) | đang làm |
| Chưa có màn hình theo dõi sự cố 72 giờ | Admin-web (T4) | đang làm |
| CSDL đặt ngoài Việt Nam | Đối chiếu Nghị định 333/2026 Điều 19 với văn bản gốc | chưa xác minh |
| `hashIp` của AIOps dùng muối viết cứng | Chuyển sang khóa bí mật (G4.1) | kế hoạch |
