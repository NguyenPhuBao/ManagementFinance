# 🛡️ CƠ SỞ DỮ LIỆU CHUẨN (NEW_DATABASE) — MANAGEMENTFINANCE
> **Source of Truth** về Lược đồ CSDL PostgreSQL, Quy chuẩn Ràng buộc, Đánh giá Tuân thủ Pháp luật & Quy định Thời hạn Lưu trữ Dữ liệu.
>
> *Ngày cập nhật:* 2026-09-10  
> *Phạm vi áp dụng:* Toàn bộ hệ thống (`src/Backend`, `src/Admin-web`, `src/Client-app`).  
> *Căn cứ pháp lý:* Nghị định 13/2023/NĐ-CP (PDPD), Nghị định 53/2022/NĐ-CP (An ninh mạng), Luật Kế toán 2015 (Luật số 88/2015/QH13), Chuẩn PCI-DSS v4.0, Khuyến nghị OWASP Top 10.

---

# 1. Quy Tắc Chung

1. **Phân loại ID & Khóa chính (PK):**
   - **Bảng nghiệp vụ offline-first** (`Category`, `Bank_account`, `Wallet`, `Budget`, `Bill`, `Goal`, `Transaction`): Khóa chính là `varchar(36) UUID v4` do **Client-app tự sinh** khi tạo mới ngoại tuyến. Backend đảm nhận việc ghi nhận và lưu trữ nguyên vẹn UUID.
   - **Bảng hệ thống** (`Role`, `Account`, `User`, `Audit_log`, `OTP_code`, `RefreshToken`): Khóa chính dùng `int auto-increment`.
2. **Cột đồng bộ SQLite (Client-app):**
   - Tại SQLite phía thiết bị di động, mọi bảng đều có thêm cột `Sync_status` (Pending, Synced, Conflict).
3. **Cơ chế Xóa mềm (Soft Delete) & Tính Toàn Vẹn:**
   - Dùng cột `Delete_at` (hoặc `Deleted_at` đối với bảng `Transaction`).
   - Nếu cột **có giá trị** (Timestamp) $\rightarrow$ Dữ liệu đã bị xóa mềm; nếu cột **rỗng** (NULL) $\rightarrow$ Dữ liệu đang hoạt động bình thường.
   - **Tuyệt đối không dùng lệnh `DELETE` vật lý** đối với dữ liệu giao dịch tài chính người dùng nhằm đảm bảo tính toàn vẹn sổ cái và tuân thủ Luật Kế toán 2015.
4. **Bảng Nhật ký kiểm toán (`Audit_log`):**
   - Dùng để theo dõi, bảo vệ các request gửi về backend và phục vụ an ninh thông tin — không theo dõi hành vi lướt UI của người dùng. Áp dụng cơ chế **Append-only** (cấm sửa/xóa), lưu tối thiểu 12 tháng theo Nghị định 53/2022/NĐ-CP.
5. **Nguyên tắc Bảo mật Dữ liệu Bắt buộc (Xem chi tiết tại [`Data_Security.md`](./Data_Security.md)):**
   - Không lưu trữ dữ liệu cấm (Mật khẩu Internet Banking, CVV/CVC thẻ tín dụng, Biometric trên server).
   - Mật khẩu bắt buộc băm bằng Argon2id hoặc bcrypt (work factor $\ge$ 12).
   - OTP và Refresh Token bắt buộc băm một chiều SHA-256.
   - Dữ liệu tài chính nhạy cảm (SĐT, Số tài khoản, Ghi chú giao dịch) phải được mã hóa at-rest (AES-256) và che bớt (masking) khi trả về API cho Admin-web/Client-app.

---

# 2. Cấu Trúc Bảng CSDL Chi Tiết & Đánh Giá Bảo Mật Từng Cột

## 2.1. Bảng `Role`
Bảng lưu trữ danh sách các vai trò trong hệ thống (Admin, User).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idrole` | int | PK - Auto increment | Mã vai trò | ✅ Cho phép. Plaintext | Vĩnh viễn theo hệ thống |
| `Rolename` | varchar(40) | Unique | Tên vai trò (`admin`, `user`) | ✅ Cho phép. Plaintext | Vĩnh viễn theo hệ thống |
| `Description` | text | NULL | Mô tả vai trò | ✅ Cho phép. Plaintext | Vĩnh viễn theo hệ thống |

---

## 2.2. Bảng `Account`
Bảng tài khoản đăng nhập hệ thống.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idaccount` | int | PK - Auto increment | Mã tài khoản nội bộ | ✅ Cho phép. Plaintext | Suốt vòng đời tài khoản |
| `Idrole` | int | FK - Role (`Idrole`) | Quyền/Vai trò tài khoản | ✅ Cho phép. Plaintext | Suốt vòng đời tài khoản |
| `Email` | varchar(100) | Unique | Email đăng nhập | ✅ Cho phép. **Masking khi trả về API** (`ph***@gmail.com`). Ẩn danh hóa khi tài khoản bị xóa | Suốt thời gian Active; xóa/ẩn danh sau 30 ngày `PendingDelete` |
| `Username` | varchar(255) | Unique | Tên đăng nhập | ✅ Cho phép. Masking trên public log | Suốt thời gian Active |
| `Password` | varchar(255) | Hash | Mật khẩu xác thực | ✅ Cho phép. **BẮT BUỘC HASH 1 CHIỀU** (Argon2id/bcrypt $\ge$ 12). Cấm lưu plaintext, cấm log | Suốt thời gian Active; xóa khi tài khoản bị xóa triệt để |
| `Status` | varchar(20) | Check in (`Active`, `Inactive`, `PendingDelete`, `Deleted`) | Trạng thái tài khoản | ✅ Cho phép. Plaintext | Suốt vòng đời hệ thống |
| `Type` | varchar(7) | Check in (`Basic`, `Premium`) | Loại gói tài khoản | ✅ Cho phép. Plaintext | Suốt thời gian Active |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Vĩnh viễn theo tài khoản |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Vĩnh viễn theo tài khoản |
| `Delete_at` | Timestamp | NULL | Thời điểm yêu cầu xóa | ✅ Cho phép. Plaintext | Sau 30 ngày kích hoạt Purge/Anonymize |

---

## 2.3. Bảng `User`
Bảng lưu thông tin cá nhân của người dùng (quan hệ 1-1 với Account).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Iduser` | int | PK - Auto increment | Mã thông tin người dùng | ✅ Cho phép. Plaintext | Suốt vòng đời tài khoản |
| `Idaccount` | int | FK - Account(`Idaccount`), UNIQUE | Mã tài khoản liên kết | ✅ Cho phép. Plaintext | Suốt vòng đời tài khoản |
| `Fullname` | nvarchar(100) | | Họ và tên người dùng | ✅ Cho phép. Masking khi hiển thị công khai; Ẩn danh hóa khi tài khoản bị xóa | Suốt thời gian Active; Xóa/Anonymize sau 30 ngày `PendingDelete` |
| `Email` | varchar(100) | Unique | Email người dùng | ✅ Cho phép (đồng bộ với Account). Masking khi xuất | Đồng bộ theo Account |
| `Phone` | varchar(256) | NULL | Số điện thoại | ✅ Cho phép. **ĐÃ MÃ HÓA AT-REST (AES-256-GCM)**; **Trigger CSDL chặn Plaintext**; Masking khi hiển thị (`098****321`) | Suốt thời gian Active; Xóa hoàn toàn khi hủy tài khoản |
| `Address` | Text | NULL | Địa chỉ cư trú | ✅ Cho phép. **ĐÃ MÃ HÓA AT-REST (AES-256-GCM)**; Masking khi hiển thị trên Admin-web | Suốt thời gian Active; Xóa hoàn toàn khi hủy tài khoản |
| `Country_code` | char(4) | NULL | Mã vùng điện thoại (`+84`) | ✅ Cho phép. Plaintext | Suốt thời gian Active |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa | ✅ Cho phép. Plaintext | Sau 30 ngày kích hoạt Purge/Anonymize |

---

## 2.4. Bảng `Audit_log`
Bảng nhật ký kiểm toán theo dõi các request gửi về backend phục vụ an ninh mạng.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idlog` | int | PK - Auto increment | Mã log | ✅ Cho phép. Plaintext | Tối thiểu **12 tháng** (Nghị định 53/2022/NĐ-CP) |
| `Idaccount` | int | FK - Account (`Idaccount`) | Tài khoản gửi request | ✅ Cho phép. Plaintext | Tối thiểu 12 tháng |
| `Request` | Varchar(200) | | Tên hành động / API endpoint | ✅ Cho phép. **CẤM CHỨA THÔNG TIN NHẠY CẢM** (Password, Token, OTP, CVV) | Tối thiểu 12 tháng |
| `Req_status` | Varchar(12) | Check in (`Accepted`, `Rejected`, `Interrupted`, `Pending`, `Processing`, `Pass`, `Fail`) | Trạng thái xử lý | ✅ Cho phép. Plaintext | Tối thiểu 12 tháng |
| `Reason` | Varchar(200) | NULL | Lý do chặn / lỗi | ✅ Cho phép. Plaintext (cấm ghi thông tin nhạy cảm vào lý do) | Tối thiểu 12 tháng |
| `TimeReq` | Timestamp | Default Now() | Thời gian nhận request | ✅ Cho phép. Plaintext | Tối thiểu 12 tháng |
| `TimeRes` | Timestamp | Default Now() | Thời gian phản hồi xong | ✅ Cho phép. Plaintext | Tối thiểu 12 tháng |

*Ghi chú quản lý:* Áp dụng quyền **Append-only**. Dữ liệu sau 12-24 tháng được phép nén xuất vào kho lưu trữ lạnh (Cold Storage) hoặc xóa dữ liệu hết hạn điều tra.

---

## 2.5. Bảng `OTP_code`
Bảng mã OTP phục vụ xác thực email, đổi mật khẩu, đổi email.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Id_otp` | int | PK - Auto increment | Mã bản ghi OTP | ✅ Cho phép. Plaintext | Tối đa **24 giờ** |
| `Idaccount` | int | FK - Account (`Idaccount`), NULL | Tài khoản yêu cầu | ✅ Cho phép. Plaintext | Tối đa 24 giờ |
| `Email` | varchar(100) | | Email nhận OTP | ✅ Cho phép. Masking trên log | Tối đa 24 giờ |
| `code_hash` | varchar(255) | | Chuỗi mã OTP đã băm | ✅ Cho phép. **BẮT BUỘC BĂM SHA-256**, tuyệt đối cấm lưu OTP dạng rõ | Tối đa 24 giờ (hiệu lực mã 10 phút) |
| `purpose` | varchar(20) | Check in (`Register`, `Reset_password`, `Change_email`) | Mục đích gửi OTP | ✅ Cho phép. Plaintext | Tối đa 24 giờ |
| `is_used` | Boolean | Default False | Trạng thái đã sử dụng | ✅ Cho phép. Plaintext | Tối đa 24 giờ |
| `expires_at` | Timestamp | Default Now() + 10m | Thời điểm hết hạn | ✅ Cho phép. Plaintext (hiệu lực tối đa 10 phút) | Tối đa 24 giờ |
| `created_at` | Timestamp | Default Now() | Thời điểm tạo mã | ✅ Cho phép. Plaintext | Tối đa 24 giờ |

*Ghi chú thanh lọc:* Bắt buộc thiết lập **Job tự động xóa vật lý (Purge)** hàng ngày cho các bản ghi có `created_at < Now() - INTERVAL '24 hours'`.

---

## 2.6. Bảng `Category`
Bảng danh mục thu chi (hỗ trợ phân cấp cha/con 2 cấp).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idcategory` | varchar(36) | PK - UUID v4 | Mã danh mục | ✅ Cho phép. Plaintext | Vĩnh viễn (hệ thống) / Theo tài khoản (người dùng) |
| `Create_by` | int | FK - Account (`Idaccount`) | Người tạo danh mục | ✅ Cho phép. Plaintext | Theo tài khoản |
| `NameCategory` | nvarchar(200) | | Tên danh mục | ✅ Cho phép. Plaintext (dữ liệu công khai hoặc người dùng tự đặt) | Theo tài khoản |
| `Classify` | nvarchar(7) | Check in (`Thu`, `Chi`, `Vay/no`) | Phân loại danh mục | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Is_default` | Boolean | Default False | Danh mục chuẩn hệ thống | ✅ Cho phép. Plaintext | Vĩnh viễn |
| `Is_group` | Boolean | Default False | Đánh dấu nhóm cha | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Idgroup` | varchar(36) | NULL, FK Category | Thuộc nhóm cha nào | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Keyword` | Text | NULL | Từ khóa gợi ý nhận diện | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Icon` | varchar(20) | NULL | Tên icon giao diện | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Color` | varchar(9) | NULL | Mã màu hex danh mục (`#RRGGBB` hoặc `#RRGGBBAA`) | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Không xóa vật lý nếu đã có giao dịch liên kết |

---

## 2.7. Bảng `Bank_account`
Bảng tài khoản ngân hàng liên kết qua Casso Open Banking API.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Id_bank_account` | varchar(36) | PK - UUID v4 | Mã định danh nội bộ | ✅ Cho phép. Plaintext | Theo tài khoản + Tối thiểu **5 năm** |
| `Idaccount` | int | FK - Account (`Idaccount`) | Tài khoản sở hữu | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Id_casso_account` | varchar(100) | Unique | Mã tài khoản phía Casso | ✅ Cho phép. Plaintext/Token tham chiếu | Theo liên kết ngân hàng |
| `Account_number` | varchar(256) | | Số tài khoản ngân hàng | ✅ Cho phép. **ĐÃ MÃ HÓA AT-REST (AES-256-GCM)**; **Trigger CSDL chặn Plaintext**; **Bắt buộc Masking khi hiển thị** (`**** **** **** 1234`) | Lưu theo liên kết; Giữ tối thiểu 5 năm (Luật Kế toán) |
| `Account_number_hash` | varchar(64) | NULL, Index | Hash Blind Index HMAC-SHA256 | ✅ Cho phép. Phục vụ tìm kiếm $O(1)$ cho webhook Casso/SePay mà không giải mã toàn bảng | Theo liên kết ngân hàng |
| `Account_name` | varchar(255) | | Tên chủ sở hữu tài khoản | ✅ Cho phép. Plaintext | Theo liên kết |
| `Bank_name` | varchar(100) | | Tên ngân hàng | ✅ Cho phép. Plaintext | Theo liên kết |
| `Balance` | decimal(15,2) | Default 0 | Số dư tài khoản ngân hàng | ✅ Cho phép. **Dữ liệu tài chính nhạy cảm**; Phân quyền nghiêm ngặt theo `Idaccount` | Cập nhật liên tục; Lưu vết giao dịch tối thiểu 5 năm |
| `Connect_status` | varchar(12) | Check in (`Active`, `Expired`, `Disconnected`) | Trạng thái kết nối | ✅ Cho phép. Plaintext | Theo liên kết |
| `Create_at` | Timestamp | Default Now() | Thời điểm liên kết | ✅ Cho phép. Plaintext | Theo liên kết |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo liên kết |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Giữ tối thiểu 5 năm phục vụ tra soát |

*Cảnh báo tuân thủ pháp luật:* **TUYỆT ĐỐI CẤM THU THẬP/LƯU TRỮ MẬT KHẨU INTERNET BANKING, MÃ PIN, SỐ THẺ ĐẦY ĐỦ CÓ CVV/CVC.** Chỉ nhận webhook biến động số dư qua đối tác Open Banking đã được cấp phép.

---

## 2.8. Bảng `Wallet`
Bảng ví tiền của người dùng (Tiền mặt, Ngân hàng, Tiết kiệm, Tự động Casso).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idwallet` | varchar(36) | PK - UUID v4 | Mã ví | ✅ Cho phép. Plaintext | Theo tài khoản + Tối thiểu **5 năm** |
| `Idaccount` | int | FK - Account (`Idaccount`) | Tài khoản sở hữu ví | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Id_bank_casso` | varchar(36) | FK - Bank_account, NULL | Liên kết ngân hàng Casso | ✅ Cho phép. Plaintext | Theo ví |
| `Name` | nvarchar(100) | | Tên ví | ✅ Cho phép. Plaintext | Theo ví |
| `Type` | varchar(7) | Check in (`Cash`, `Bank`, `Saving`, `Banking`) | Phân loại nguồn ví | ✅ Cho phép. Plaintext | Theo ví |
| `Balance` | decimal(15,2) | Default 0 | Số dư hiện tại của ví | ✅ Cho phép. **Dữ liệu tài chính nhạy cảm**; Phân quyền chặt chẽ | Tối thiểu 5 năm sau khi xóa mềm (Luật Kế toán) |
| `Currency` | Varchar(3) | Check in (`VND`, `USD`) | Đơn vị tiền tệ | ✅ Cho phép. Plaintext | Theo ví |
| `Status` | Varchar(8) | Check in (`Active`, `Inactive`) | Trạng thái ví (Active/Inactive) | ✅ Cho phép. Plaintext | Theo ví |
| `IncludeInTotal` | Boolean | Default TRUE | Có tính vào tổng tài sản | ✅ Cho phép. Plaintext | Theo ví |
| `Is_default` | Boolean | Default False | Ví mặc định | ✅ Cho phép. Plaintext | Theo ví |
| `Icon` | Varchar(20) | NULL | Icon hiển thị | ✅ Cho phép. Plaintext | Theo ví |
| `Color` | Varchar(20) | NULL | Mã màu hiển thị | ✅ Cho phép. Plaintext | Theo ví |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo ví |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo ví |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Không xóa vật lý làm mất cân bằng sổ cái |

---

## 2.9. Bảng `Budget`
Bảng hạn mức ngân sách chi tiêu.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idbudget` | varchar(36) | PK - UUID v4 | Mã ngân sách | ✅ Cho phép. Plaintext | Tối thiểu **3 - 5 năm** |
| `Idaccount` | int | FK - Account (`Idaccount`) | Tài khoản sở hữu | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Idcategory` | varchar(36) | FK - Category, NULL | Danh mục áp dụng | ✅ Cho phép. Plaintext | Theo ngân sách |
| `TotalAmount` | Decimal(15, 2) | Check (> 0) | Tổng hạn mức ngân sách | ✅ Cho phép. Phân quyền `Idaccount` | Tối thiểu 3 - 5 năm |
| `Spent` | Decimal(15, 2) | Default 0 | Số tiền thực tế đã chi | ✅ Cho phép. Phân quyền `Idaccount` | Tối thiểu 3 - 5 năm |
| `Threshold_Warning_Amount` | Decimal(15, 2) | NULL | Số tiền chạm ngưỡng báo động | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Threshold_Warning_Percent` | Decimal(15, 2) | NULL (0-100) | Tỷ lệ % chạm ngưỡng báo (NULL nếu không dùng) | ✅ Cho phép. Plaintext | Theo ngân sách |
| `OverSpending` | Varchar(7) | Check in (`Stop`, `Over`) | Hành vi khi vượt hạn mức | ✅ Cho phép. Plaintext | Theo ngân sách |
| `OverAmount` | Decimal(15, 2) | NULL | Số tiền cho phép vượt tối đa | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Start` | Timestamp | | Thời điểm bắt đầu | ✅ Cho phép. Plaintext | Theo ngân sách |
| `End` | Timestamp | NULL | Thời điểm kết thúc | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Recurrence` | Boolean | Default FALSE | Tự động lặp lại chu kỳ | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Time_recurrence` | varchar(7) | Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL | Chu kỳ lặp lại | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Nexttime_recurrence` | Timestamp | NULL | Thời điểm chu kỳ tiếp theo | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Note` | text | NULL | Ghi chú ngân sách | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo ngân sách |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Cho phép xóa mềm hoặc dọn dẹp sau 5 năm |

---

## 2.10. Bảng `Bill`
Bảng quản lý hóa đơn định kỳ phải trả (Tiền điện, nước, internet, thuê nhà...).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idbill` | varchar(36) | PK - UUID v4 | Mã hóa đơn | ✅ Cho phép. Plaintext | Tối thiểu **5 năm** (Luật Kế toán 2015) |
| `Idaccount` | Int | FK - Account (`Idaccount`) | Tài khoản sở hữu | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Idwallet` | varchar(36) | FK - Wallet (`Idwallet`) | Ví dự kiến thanh toán | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Idcategory` | varchar(36) | FK - Category (`Idcategory`) | Danh mục hóa đơn | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Name` | varchar(100) | | Tên hóa đơn | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Amount` | Decimal(15,2) | Check (> 0) | Số tiền hóa đơn | ✅ Cho phép. Phân quyền `Idaccount` | Tối thiểu 5 năm |
| `Start_date` | Timestamp | Default Now() | Ngày bắt đầu tính | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Due_date` | Timestamp | | Hạn thanh toán | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Pay_status` | varchar(7) | Check in (`Pending`, `Payed`, `Overdue`, `Skipped`) | Trạng thái thanh toán (bổ sung Skipped khi bỏ qua kỳ) | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Recurrence` | Boolean | Default False | Lặp lại định kỳ | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Time_recurrence` | varchar(7) | Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL | Chu kỳ lặp lại | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Time_notification` | varchar(7) | Check in (`1`, `3`, `5`, `7`), NULL | Số ngày nhắc nhở trước hạn | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Previous_bill_id` | varchar(36) | NULL, FK Bill(`Idbill`) | Liên kết hóa đơn chuỗi kỳ trước | ✅ Cho phép. Plaintext | Theo chuỗi hóa đơn |
| `Period_end` | Date | NULL | Ngày kết thúc kỳ tính cước hóa đơn | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Auto_pay` | Boolean | Default False | Tự động thanh toán hóa đơn khi tới hạn | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Anchor_day` | Smallint | NULL, Check (1-31) | Ngày neo chu kỳ thanh toán hàng tháng | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Icon` | varchar(20) | NULL | Icon hiển thị | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Color` | varchar(20) | NULL | Mã màu hiển thị | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Note` | Text | NULL | Ghi chú thêm | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo hóa đơn |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Không xóa vật lý hóa đơn đã thanh toán |

---

## 2.11. Bảng `Goal`
Bảng mục tiêu tích lũy và tiết kiệm tiền.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idgoal` | varchar(36) | PK - UUID v4 | Mã mục tiêu tiết kiệm | ✅ Cho phép. Plaintext | Tối thiểu **3 - 5 năm** |
| `Idaccount` | Int | FK - Account (`Idaccount`) | Tài khoản sở hữu | ✅ Cho phép. Plaintext | Theo tài khoản |
| `Idwallet` | varchar(36) | FK - Wallet, NULL | Ví chứa tiền tiết kiệm | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Name` | varchar(100) | | Tên mục tiêu | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Target_amount` | Decimal(15,2) | Check (> 0) | Số tiền mục tiêu cần đạt | ✅ Cho phép. Phân quyền `Idaccount` | Tối thiểu 3 - 5 năm |
| `Current_amount` | Decimal(15,2) | Default 0, Check (>= 0) | Số tiền hiện đã tích lũy | ✅ Cho phép. Phân quyền `Idaccount` | Tối thiểu 3 - 5 năm |
| `Start_date` | Timestamp | Default Now() | Ngày bắt đầu tích lũy | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Target_date` | Timestamp | | Hạn hoàn thành mục tiêu | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Cycle_take_money` | varchar(7) | Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL | Chu kỳ trích tiền | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Time_cycle_take_money` | Timestamp | NULL | Thời điểm trích cụ thể | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Status_complete` | varchar(20) | Check in (`True`, `False`) | Đã hoàn thành hay chưa | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Recurrence` | Boolean | Default False | Lặp lại sau khi đạt | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Time_recurrence` | varchar(7) | Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL | Chu kỳ lặp lại | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `auto_deposit_amount` | Decimal(15,2) | NULL, Check (> 0) | Số tiền trích tự động mỗi kỳ | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `auto_deposit_wallet_id` | varchar(36) | NULL, FK Wallet | Ví nguồn trích tiền tự động | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `auto_deposit_last_run` | Date | NULL | Ngày trích tiền tự động gần nhất | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Priority` | Smallint | NULL, Check (> 0) | Thứ tự ưu tiên trích tích lũy (NULL nếu không đặt) | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Icon` | varchar(20) | NULL | Icon hiển thị | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Color` | varchar(20) | NULL | Màu sắc | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Note` | Text | NULL | Ghi chú | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Create_at` | Timestamp | Default Now() | Thời điểm tạo | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `Delete_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Cho phép xóa mềm hoặc lưu trữ báo cáo |

---

## 2.12. Bảng `Transaction`
Bảng lưu trữ mọi giao dịch thu, chi, chuyển khoản, đồng bộ ngân hàng, quét OCR và SMS.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idtran` | varchar(36) | PK - UUID v4 | Mã giao dịch | ✅ Cho phép. Plaintext | Tối thiểu **5 năm** (Luật Kế toán 2015 Điều 41 & NĐ 174/2016) |
| `Idaccount` | Int | FK - Account (`Idaccount`) | Tài khoản thực hiện | ✅ Cho phép. Phân quyền bắt buộc theo `userId` | Tối thiểu 5 năm |
| `Idwallet` | varchar(36) | FK - Wallet (`Idwallet`) | Ví thực hiện giao dịch | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Idcategory` | varchar(36) | FK - Category, NULL | Danh mục chi tiêu/thu | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Idwallet_transfer` | varchar(36) | FK - Wallet, NULL | Ví nhận tiền (khi Transfer) | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Idgoal` | varchar(36) | FK - Goal, NULL | Liên kết mục tiêu tích lũy/rút tiền | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Idbill` | varchar(36) | FK - Bill, NULL | Liên kết hóa đơn thanh toán | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Bank_tran_id` | varchar(100) | NULL | Mã giao dịch phía ngân hàng | ✅ Cho phép. Dùng chống trùng lặp | Tối thiểu 5 năm |
| `Amount` | Decimal(15,2) | Check (!= 0) | Số tiền giao dịch (±) | ✅ Cho phép. **Dữ liệu tài chính cốt lõi**; Phân quyền chặt chẽ; Audit log | Tối thiểu 5 năm (không xóa vật lý) |
| `Type` | Varchar(20) | Check in (`Transaction`, `Transfer`) | Loại giao dịch | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Status` | Varchar(10) | Check in (`Pending`, `Confirmed`, `Rejected`, `Fail`) | Trạng thái giao dịch | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Provider` | Varchar(40) | Check in (`Manual`, `BankSync`, `SMS`, `OCR`, `Bill`) | Nguồn tạo giao dịch | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Note` | Text | NULL | Ghi chú giao dịch | ✅ Cho phép. **ĐÃ MÃ HÓA AT-REST (AES-256-GCM)** & **Lọc sạch thẻ/CVV/pwd trước khi lưu** | Tối thiểu 5 năm; Xóa khi người dùng xóa tài khoản |
| `Images` | Text | NULL | Đường dẫn ảnh biên lai/chứng từ | ✅ Cho phép. **ĐÃ DÙNG PRE-SIGNED URL (15-30 phút)**; Private Bucket; Xóa ảnh vật lý khi tài khoản bị xóa | Tối thiểu 5 năm theo chứng từ kế toán |
| `DateTransaction` | Timestamp | Default Now() | Thời điểm phát sinh giao dịch | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Update_at` | Timestamp | Default Now() | Thời điểm cập nhật | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
| `Deleted_at` | Timestamp | NULL | Thời điểm xóa mềm | ✅ Cho phép. Plaintext | Sau 5 năm cho phép chuyển Cold Archive |

---

## 2.13. Bảng `RefreshToken`
Bảng lưu trữ Refresh Token đã cấp cho các phiên đăng nhập.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa | Được phép lưu & Chuẩn bảo mật | Thời hạn lưu trữ quy định |
|---|---|---|---|---|---|
| `Idtoken` | int | PK - Auto increment | Mã bản ghi token | ✅ Cho phép. Plaintext | Tối đa **30 ngày** sau hết hạn/thu hồi |
| `Token_hash` | varchar(255) | Unique | Chuỗi token đã băm 1 chiều | ✅ Cho phép. **BẮT BUỘC BĂM SHA-256**, tuyệt đối cấm lưu token plaintext trong DB | Tối đa 30 ngày sau hết hạn |
| `Idaccount` | int | FK - Account (`Idaccount`) | Tài khoản được cấp | ✅ Cho phép. Plaintext | Theo phiên |
| `Idrole` | int | FK - Role (`Idrole`), Default 2 | Quyền tại lúc cấp | ✅ Cho phép. Plaintext | Theo phiên |
| `Expired` | Timestamp | | Thời điểm hết hạn token | ✅ Cho phép. Plaintext | TTL 7 - 30 ngày |
| `Status` | Boolean | Default False | FALSE: Còn hạn, TRUE: Đã thu hồi | ✅ Cho phép. Plaintext | Theo phiên |
| `Device_name` | varchar(100) | NULL | Tên thiết bị đăng nhập | ✅ Cho phép. Dùng cho an ninh phiên (NĐ 13/2023) | Tối đa 30 ngày sau khi token hết hạn |
| `IP_address` | varchar(45) | NULL | Địa chỉ IP đăng nhập | ✅ Cho phép. Masking trên log hệ thống | Tối đa 30 ngày |
| `User_agent` | Text | NULL | Thông tin trình duyệt/OS | ✅ Cho phép. Plaintext | Tối đa 30 ngày |
| `Create_at` | Timestamp | Default Now() | Thời điểm cấp | ✅ Cho phép. Plaintext | Theo phiên |
| `Update_at` | Timestamp | Default Now() | Thời điểm làm mới | ✅ Cho phép. Plaintext | Theo phiên |

*Ghi chú thanh lọc:* Bắt buộc thiết lập **Job tự động xóa vật lý (Purge)** hàng ngày cho các bản ghi có `(Expired < Now() OR Status = TRUE) AND Update_at < Now() - INTERVAL '30 days'`.

---

# 3. Tổng Hợp Ràng Buộc CSDL Chuẩn

## 3.1. Quy tắc kiến trúc
- **Khóa chính (PK)**: Mọi bảng offline-first (`Category`, `Bank_account`, `Wallet`, `Budget`, `Bill`, `Goal`, `Transaction`) dùng `varchar(36) UUID v4` do **Client-app sinh** khi tạo mới ngoại tuyến. Các bảng hệ thống dùng `int auto-increment`.
- **Khóa ngoại (FK) liên kết Account**: Các bảng dữ liệu con trỏ về `Account(Idaccount)` với ràng buộc `ON DELETE CASCADE`.
- **Cơ chế Xóa mềm (Soft Delete)**: Sử dụng `Delete_at` (hoặc `Deleted_at` cho `Transaction`). Khi xóa mềm, ghi nhận `Timestamp` hiện tại và đồng bộ `Update_at = Now()`. Không dùng `DELETE` vật lý đối với dữ liệu người dùng.
- **Xung đột & Đồng bộ (LWW)**: Áp dụng thuật toán Last-Write-Wins dựa trên `Update_at`.

## 3.2. Chi tiết ràng buộc từng bảng (Tóm tắt Schema)

### 3.2.1. Role
- **PK**: `Idrole` (int auto-increment) | **Unique**: `Rolename`

### 3.2.2. Account
- **PK**: `Idaccount` (int auto-increment) | **FK**: `Idrole` $\rightarrow$ `Role(Idrole)`
- **Unique**: `Email`, `Username`
- **Check**: `Status IN ('Active', 'Inactive', 'PendingDelete', 'Deleted')`; `Type IN ('Basic', 'Premium')`
- **Default**: `Status = 'Active'`, `Type = 'Basic'`, `Create_at = Now()`, `Update_at = Now()`

### 3.2.3. User
- **PK**: `Iduser` (int auto-increment) | **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`)
- **Unique**: `Idaccount` (1 User ↔ 1 Account), `Email`
- **Đồng bộ**: `User.Email` luôn đồng bộ với `Account.Email`.

### 3.2.4. Audit_log
- **PK**: `Idlog` (int auto-increment) | **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`)
- **Check**: `Req_status IN ('Accepted', 'Rejected', 'Interrupted', 'Pending', 'Processing', 'Pass', 'Fail')`
- **Default**: `Req_status = 'Pass'`, `TimeReq = Now()`, `TimeRes = Now()`
- **Index**: `Idaccount`, `TimeReq`

### 3.2.5. OTP_code
- **PK**: `Id_otp` (int auto-increment) | **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE SET NULL`)
- **Check**: `purpose IN ('Register', 'Reset_password', 'Change_email')`; `expires_at > created_at`
- **Default**: `is_used = FALSE`, `created_at = Now()`, `expires_at = Now() + INTERVAL '10 minutes'`
- **Index**: `(Idaccount, purpose)`, `(Email, purpose)`, `expires_at`

### 3.2.6. Category
- **PK**: `Idcategory` (varchar(36) UUID)
- **FK**: `Create_by` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idgroup` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`)
- **Cột mới**: `Color` (varchar(9) NULL - mã màu hex)
- **Check**: `Classify IN ('Thu', 'Chi', 'Vay/no')`
- **Default**: `Is_default = FALSE`, `Is_group = FALSE`, `Create_at = Now()`, `Update_at = Now()`
- **Unique**: `(Create_by, lower(regexp_replace(btrim(NORMALIZE(NameCategory, NFC)), '\s+', ' ', 'g')))` — Cấm trùng lặp trên cùng tài khoản. Áp dụng mô hình **Template & Cloned Model** (Người dùng được phép tạo danh mục cá nhân trùng tên với danh mục mặc định của hệ thống).
- **Check Phân cấp**: Nhóm (`Is_group = TRUE`): `Idgroup IS NULL`. Danh mục con (`Is_group = FALSE`): có thể có `Idgroup` hoặc `NULL` (không cho phép lồng quá 2 cấp).
- **Index**: `Idcategory`, `Idgroup`, `Create_by`

### 3.2.7. Bank_account
- **PK**: `Id_bank_account` (varchar(36) UUID) | **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`)
- **Unique**: `Id_casso_account` (1 tài khoản ngân hàng Casso chỉ liên kết 1 lần duy nhất)
- **Check**: `Connect_status IN ('Active', 'Expired', 'Disconnected')`
- **Default**: `Balance = 0`, `Connect_status = 'Active'`, `Create_at = Now()`, `Update_at = Now()`
- **Mã hóa & Hash**: `Account_number` (varchar(256), AES-256-GCM At-Rest), `Account_number_hash` (varchar(64), HMAC-SHA256 Blind Index phục vụ tra soát O(1))
- **Trigger Bảo Vệ CSDL**: `trg_check_bank_account_encrypted` (Nghiêm cấm lưu số tài khoản plaintext)
- **Index**: `Idaccount`, `Connect_status`, `Account_number_hash`

### 3.2.8. Wallet
- **PK**: `Idwallet` (varchar(36) UUID)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Id_bank_casso` $\rightarrow$ `Bank_account(Id_bank_account)` (`ON DELETE SET NULL`)
- **Check**: `Type IN ('Cash', 'Bank', 'Saving', 'Banking')`; `Currency IN ('VND', 'USD')`; `Status IN ('Active', 'Inactive')`
- **Default**: `Type = 'Cash'`, `Balance = 0`, `Currency = 'VND'`, `Status = 'Active'`, `IncludeInTotal = TRUE`, `Is_default = FALSE`
- **Unique**: `(Idaccount, Name)` — Không trùng tên ví trong cùng 1 tài khoản; `Id_bank_casso` **WHERE NOT NULL** — 1 tài khoản ngân hàng chỉ tạo tối đa 1 ví Banking. **Đã gỡ bỏ** index `uq_wallet_saving_active` (cho phép người dùng mở nhiều ví Tiết kiệm linh hoạt).
- **Index**: `Idaccount`, `Id_bank_casso`, `Update_at`

### 3.2.9. Budget
- **PK**: `Idbudget` (varchar(36) UUID)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idcategory` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`, NULL = Ngân sách tổng)
- **Check**: `TotalAmount > 0`; `Spent >= 0`; `Threshold_Warning_Percent >= 0 AND Threshold_Warning_Percent <= 100`; `OverSpending IN ('Stop', 'Over')`; `Time_recurrence IN ('Day', 'Week', 'Month', 'Quarter', 'Year')`
- **Default**: `Spent = 0`, `OverSpending = 'Over'`, `Recurrence = FALSE` (Lưu ý: `Threshold_Warning_Percent` cho phép `NULL`, không ép buộc default 0)
- **Index**: `Idaccount`, `Idcategory`

### 3.2.10. Bill
- **PK**: `Idbill` (varchar(36) UUID)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)`; `Idcategory` $\rightarrow$ `Category(Idcategory)`; `Previous_bill_id` $\rightarrow$ `Bill(Idbill)` (`ON DELETE SET NULL`)
- **Cột mới**: `Previous_bill_id` (varchar(36)), `Period_end` (Date), `Auto_pay` (Boolean default FALSE), `Anchor_day` (Smallint 1..31)
- **Check**: `Amount > 0`; `Pay_status IN ('Pending', 'Payed', 'Overdue', 'Skipped')`; `Time_recurrence IN ('Day', 'Week', 'Month', 'Quarter', 'Year')`; `Time_notification IN ('1', '3', '5', '7')`; `Anchor_day IS NULL OR (Anchor_day BETWEEN 1 AND 31)`
- **Default**: `Pay_status = 'Pending'`, `Auto_pay = FALSE`, `Recurrence = FALSE`, `Time_notification = '3'`
- **Index**: `Idaccount`, `Idwallet`, `Idcategory`, `Previous_bill_id`

### 3.2.11. Goal
- **PK**: `Idgoal` (varchar(36) UUID)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`); `auto_deposit_wallet_id` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`)
- **Cột mới**: `Priority` (Smallint check > 0, NULL nếu không đặt), `auto_deposit_amount` (Decimal), `auto_deposit_wallet_id` (varchar(36)), `auto_deposit_last_run` (Date)
- **Check**: `Target_amount > 0`; `Current_amount >= 0`; `Status_complete IN ('True', 'False')`; `Cycle_take_money IN ('Day', 'Week', 'Month', 'Quarter', 'Year')`; `Priority IS NULL OR Priority > 0`
- **Default**: `Current_amount = 0`, `Status_complete = 'False'`, `Recurrence = FALSE`
- **Index**: `Idaccount`, `Idwallet`

### 3.2.12. Transaction
- **PK**: `Idtran` (varchar(36) UUID)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE CASCADE`); `Idcategory` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`); `Idwallet_transfer` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`); `Idgoal` $\rightarrow$ `Goal(Idgoal)` (`ON DELETE SET NULL`); `Idbill` $\rightarrow$ `Bill(Idbill)` (`ON DELETE SET NULL`)
- **Cột mới**: `Idgoal` (varchar(36)), `Idbill` (varchar(36))
- **Check**: `Type IN ('Transaction', 'Transfer')`; `Status IN ('Pending', 'Confirmed', 'Rejected', 'Fail')`; `Provider IN ('Manual', 'BankSync', 'SMS', 'OCR', 'Bill')`; `Amount != 0`
- **Default**: `Type = 'Transaction'`, `Status = 'Confirmed'`, `Provider = 'Manual'`, `DateTransaction = Now()`
- **Unique**: `(Idaccount, Bank_tran_id)` **WHERE Bank_tran_id IS NOT NULL** (Cách ly mã giao dịch theo từng tài khoản người dùng)
- **Bảo vệ CSDL (Trigger)**: Chặn `DELETE` vật lý giao dịch dưới 5 năm theo Luật Kế toán 2015.
- **Mã hóa & Bảo mật**: `Note` mã hóa AES-256-GCM & lọc thẻ/CVV/pwd (chuẩn thuật toán Luhn); `Images` dùng Pre-Signed URL ngắn hạn (15-30 phút).
- **Index**: `Idaccount`, `Idwallet`, `Idcategory`, `Status`, `Provider`, `DateTransaction`, `Update_at`, `Idbill`, `Idgoal`

### 3.2.13. RefreshToken
- **PK**: `Idtoken` (int auto-increment)
- **FK**: `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idrole` $\rightarrow$ `Role(Idrole)`
- **Unique**: `Token_hash`
- **Check**: `Expired > Create_at`
- **Default**: `Idrole = 2`, `Status = FALSE`, `Create_at = Now()`, `Update_at = Now()`
- **Index**: `Idaccount`, `Expired`, `Status`, `Token_hash`

---

# 4. Đánh Giá Tổng Thể Tuân Thủ Pháp Luật & Trạng Thái Hoàn Tất

Toàn bộ 13 bảng (149 cột) trong CSDL đã được tối ưu và triển khai đầy đủ các cơ chế bảo mật kỹ thuật để tuân thủ 100% các quy định pháp luật:
- **Nghị định 13/2023/NĐ-CP** (Bảo vệ dữ liệu cá nhân & Quyền xóa dữ liệu)
- **Nghị định 53/2022/NĐ-CP** (Thời hạn lưu trữ nhật ký an ninh mạng tối thiểu 12 tháng)
- **Luật Kế toán 2015 (Điều 41) & Nghị định 174/2016/NĐ-CP** (Thời hạn lưu trữ dữ liệu tài chính kế toán tối thiểu 5 năm)
- **PCI-DSS v4.0** (Bảo vệ dữ liệu chủ thẻ, mã hóa số tài khoản, cấm lưu CVV/PIN)

## Bảng Tổng Hợp Triển Khai Kỹ Thuật

| STT | Yêu cầu pháp lý & Tiêu chuẩn | Giải pháp kỹ thuật đã triển khai | Trạng thái |
|:---:|---|---|:---:|
| **1** | **Bảo vệ Dữ liệu cá nhân (PII At-Rest)**<br>• Phone, Address (User)<br>• STK (Bank_account) | • Mã hóa AES-256-GCM trước khi ghi vào CSDL.<br>• Mở rộng kích thước cột lên `VARCHAR(256)`.<br>• **Trigger CSDL chặn Plaintext**: Ném ngoại lệ SQL chặn đứng nếu lọt dữ liệu số rõ. | **✅ ĐÃ TRIỂN KHAI** (Migration 11 & Crypto Util) |
| **2** | **Tra soát nhanh STK ngân hàng (Blind Indexing)** | • Thêm cột `Account_number_hash` `VARCHAR(64)` có Index B-Tree.<br>• Tính `HMAC-SHA256` với secret key cho tra cứu $O(1)$ phía Webhook SePay/Casso. | **✅ ĐÃ TRIỂN KHAI** |
| **3** | **Che mờ dữ liệu (Data Masking)** | • Hàm `maskEmail`, `maskPhone`, `maskAccountNumber`, `maskFullname`, `maskAddress`.<br>• Áp dụng tự động trên API danh sách Admin và xuất báo cáo công cộng. | **✅ ĐÃ TRIỂN KHAI** |
| **4** | **Kiểm soát Lý do khóa tài khoản (`Reason_Inactive`)** | • Chặn đứng nếu chứa SĐT, Email, CCCD, Thẻ ngân hàng hoặc từ ngữ xúc phạm/thô tục.<br>• Trả về mã lỗi `400 Bad Request`. | **✅ ĐÃ TRIỂN KHAI** |
| **5** | **Bảo vệ Ghi chú giao dịch & ngân sách (`Note`)** | • Tự động lọc sạch số thẻ tín dụng, mã bảo mật CVV, mật khẩu.<br>• Mã hóa At-Rest AES-256-GCM khi lưu vào CSDL. | **✅ ĐÃ TRIỂN KHAI** |
| **6** | **Bảo mật Ảnh hóa đơn chứng từ (`Images`)** | • Sử dụng Private Bucket kết hợp Pre-Signed URL có thời hạn ngắn (15-30 phút).<br>• Cấm public URL trực tiếp ra ngoài Internet. | **✅ ĐÃ TRIỂN KHAI** |
| **7** | **Làm sạch Audit Log & Winston Logger Redaction** | • `Reason` của `Audit_log` chỉ lưu lý do kỹ thuật ngắn gọn, đã khử PII/Token.<br>• Winston Logger tự động redact: `balance`, `password`, `token`, `otp`, `code_hash`, `cvv`, `refreshtoken`. | **✅ ĐÃ TRIỂN KHAI** |
| **8** | **Thời hạn lưu trữ & Tự động thanh lọc (Data Retention & Purge)** | • Purge OTP cũ sau 24 giờ.<br>• Purge RefreshToken hết hạn/thu hồi sau 30 ngày.<br>• Trigger CSDL khóa lệnh `DELETE` vật lý bảng `transaction` và `audit_log`. | **✅ ĐÃ TRIỂN KHAI** (Scheduler & Migration 10) |
| **9** | **Quy trình Ẩn danh hóa triệt để khi xóa tài khoản** | • Soft Delete 30 ngày cho phép khôi phục.<br>• Sau 30 ngày: Ẩn danh hóa toàn bộ Họ tên, Email, SĐT, Địa chỉ, Ghi chú, Ảnh biên lai.<br>• Bảo toàn số dư và số tiền giao dịch cho tính toàn vẹn hệ thống tài chính. | **✅ ĐÃ TRIỂN KHAI** |

