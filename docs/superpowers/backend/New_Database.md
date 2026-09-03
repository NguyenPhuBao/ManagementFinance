# 1. Quy tắc chung
- Tại SQLite với mọi bảng đều có thêm cột `Sync_status`.
- `uuid` là id tự sinh được thiết lập tại Client-app. Backend chỉ đảm nhận việc ghi nhận mã (trừ các bảng hệ thống: `Role`, `Account`, `User`, `Audit_log`, `OTP_code`, `RefreshToken` dùng `int auto-increment`).
- **Cơ chế xóa mềm**: dùng cột `Delete_at` (hoặc `Deleted_at` đối với bảng `Transaction`). Nếu cột **có giá trị** (Timestamp) thì nghĩa là dữ liệu đã bị xóa mềm; nếu cột **rỗng** (NULL) thì dữ liệu đang dùng (chưa bị xóa). Tuyệt đối không dùng lệnh `DELETE` vật lý đối với dữ liệu người dùng.
- Bảng `Audit_log` dùng để theo dõi yêu cầu gửi về backend — không theo dõi hoạt động của người dùng.

---

# 2. Cấu Trúc Bảng CSDL Chi Tiết

## 2.1. Bảng Role
Bảng lưu trữ danh sách các vai trò trong hệ thống (Admin, User).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idrole | int | PK - Auto increment | Mã vai trò |
| Rolename | varchar(40) | Unique | Tên vai trò (admin, user) |
| Description | text | NULL | Mô tả vai trò |

## 2.2. Bảng Account
Bảng tài khoản đăng nhập hệ thống.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idaccount | int | PK - Auto increment | Mã tài khoản |
| Idrole | int | FK - Role (Idrole) | Tài khoản có vai trò gì - Mã vai trò |
| Email | varchar(100) | Unique | Email đăng nhập |
| Username | varchar(255) | Unique | Tên đăng nhập |
| Password | varchar(255) | Hash | Mật khẩu — bắt buộc băm bcrypt/argon2 |
| Status | varchar(20) | Check in (Active, Inactive, PendingDelete, Deleted) - Default Active | Trạng thái tài khoản |
| Type | varchar(7) | Check in (Basic, Premium) - Default Basic | Loại gói tài khoản (Basic / Premium) |
| Create_at | Timestamp | Default Now() | Thời điểm tạo tài khoản |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật tài khoản |
| Delete_at | Timestamp | NULL | Thời điểm xóa tài khoản |

## 2.3. Bảng User
Bảng lưu thông tin cá nhân của người dùng (quan hệ 1-1 với Account).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Iduser | int | PK - Auto increment | Mã người dùng |
| Idaccount | int | FK - Account(Idaccount), UNIQUE | Mã tài khoản sở hữu thông tin này |
| Fullname | nvarchar(100) | | Họ và tên |
| Email | varchar(100) | Unique | Email người dùng (đồng bộ với Account.Email) |
| Phone | varchar(15) | NULL | Số điện thoại |
| Address | Text | NULL | Địa chỉ người dùng |
| Country_code | char(4) | NULL | Mã vùng/quốc gia (+84, +1, ...) |
| Create_at | Timestamp | Default Now() | Thời điểm tạo thông tin |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật thông tin |
| Delete_at | Timestamp | NULL | Thời điểm xóa thông tin |

## 2.4. Bảng Audit_log
Bảng nhật ký kiểm toán theo dõi các request gửi về backend.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idlog | int | PK - Auto increment | Mã log |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản thực hiện yêu cầu |
| Request | Varchar(200) | | Tên hành động yêu cầu |
| Req_status | Varchar(12) | Check in (Accepted, Rejected, Interrupted, Pending, Processing, Pass, Fail) - Default Pass | Trạng thái xử lý yêu cầu |
| Reason | Varchar(200) | NULL | Ghi nhận lý do thất bại / bị chặn |
| TimeReq | Timestamp | Default Now() | Thời gian yêu cầu được gửi đến |
| TimeRes | Timestamp | Default Now() | Thời gian yêu cầu hoàn tất phản hồi |

## 2.5. Bảng OTP_code
Bảng mã OTP phục vụ xác thực email, đổi mật khẩu, đổi email.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Id_otp | int | PK - Auto increment | Mã định danh OTP |
| Idaccount | int | FK - Account (Idaccount), NULL | Tài khoản yêu cầu OTP (NULL khi đăng ký mới) |
| Email | varchar(100) | | Email nhận mã OTP |
| code_hash | varchar(255) | | Mã OTP đã băm |
| purpose | varchar(20) | Check in (Register, Reset_password, Change_email) | Mục đích gửi mã OTP |
| is_used | Boolean | Default False | Đã sử dụng (TRUE) hay chưa dùng (FALSE) |
| expires_at | Timestamp | Default Now() + 10 minutes | Thời điểm hết hạn (mặc định 10 phút) |
| created_at | Timestamp | Default Now() | Thời điểm tạo mã OTP |

## 2.6. Bảng Category
Bảng danh mục thu chi — hỗ trợ phân cấp cha/con 2 cấp (nhóm và danh mục con).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idcategory | varchar(36) | PK - UUID v4 | Mã danh mục |
| Create_by | int | FK - Account (Idaccount) | Tài khoản tạo danh mục |
| NameCategory | nvarchar(200) | | Tên danh mục |
| Classify | nvarchar(7) | Check in (Thu, Chi, Vay/no) | Phân loại danh mục: Thu (Thu nhập), Chi (Chi tiêu), Vay/no (Vay mượn/Nợ nần) |
| Is_default | Boolean | Default False | Danh mục mặc định hệ thống (TRUE) hay người dùng tự tạo (FALSE) |
| Is_group | Boolean | Default False | Có phải danh mục cha / nhóm hay không |
| Idgroup | varchar(36) | NULL, FK Category(Idcategory) | Thuộc nhóm danh mục nào (NULL nếu là nhóm hoặc danh mục độc lập) |
| Keyword | Text | NULL | Các từ khóa nhận diện danh mục, phân cách bởi dấu `,` |
| Icon | varchar(20) | NULL | Tên icon danh mục |
| Create_at | Timestamp | Default Now() | Thời điểm tạo danh mục |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật danh mục |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm danh mục |

## 2.7. Bảng Bank_account
Bảng tài khoản ngân hàng liên kết qua Casso Open Banking API.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Id_bank_account | varchar(36) | PK - UUID v4 | Mã định danh tài khoản ngân hàng trong hệ thống |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản người dùng sở hữu liên kết này |
| Id_casso_account | varchar(100) | Unique | Mã định danh tài khoản ngân hàng phía Casso |
| Account_number | varchar(50) | | Số tài khoản ngân hàng |
| Account_name | varchar(255) | | Tên chủ sở hữu tài khoản ngân hàng |
| Bank_name | varchar(100) | | Tên ngân hàng |
| Balance | decimal(15,2) | Default 0 | Số dư tài khoản ngân hàng |
| Connect_status | varchar(12) | Check in (Active, Expired, Disconnected) - Default Active | Trạng thái kết nối: Active (Đang kết nối), Expired (Hết hạn Token), Disconnected (Đã ngắt kết nối) |
| Create_at | Timestamp | Default Now() | Thời điểm liên kết |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật số dư / trạng thái |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm liên kết |

## 2.8. Bảng Wallet
Bảng ví tiền của người dùng (Ví tiền mặt, Ví ngân hàng liên kết, Ví tiết kiệm).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idwallet | varchar(36) | PK - UUID v4 | Mã định danh ví |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản sở hữu ví |
| Id_bank_casso | varchar(36) | FK - Bank_account(Id_bank_account), NULL | Liên kết tài khoản ngân hàng Casso (nếu là ví Banking) |
| Name | nvarchar(100) | | Tên ví (hỗ trợ tối đa 100 ký tự) |
| Type | varchar(7) | Check in (Cash, Bank, Saving, Banking) - Default Cash | Loại ví: Cash (Tiền mặt), Bank (Ngân hàng tự tạo), Saving (Tiết kiệm), Banking (Tự động từ Casso) |
| Balance | decimal(15,2) | Default 0 | Số dư ví |
| Currency | Varchar(3) | Check in (VND, USD) - Default VND | Đơn vị tiền tệ |
| Status | Varchar(7) | Check in (Active, Inactive) - Default Active | Trạng thái ví |
| IncludeInTotal | Boolean | Default TRUE | Có tính vào tổng tài sản hay không (TRUE: có, FALSE: không) |
| Is_default | Boolean | Default False | Có phải ví mặc định hay không |
| Icon | Varchar(20) | NULL | Icon ví |
| Color | Varchar(20) | NULL | Màu hiển thị ví |
| Create_at | Timestamp | Default Now() | Thời điểm tạo ví |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật ví |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm ví |

## 2.9. Bảng Budget
Bảng hạn mức ngân sách chi tiêu.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idbudget | varchar(36) | PK - UUID v4 | Mã ngân sách |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản sở hữu ngân sách |
| Idcategory | varchar(36) | FK - Category (Idcategory), NULL | Danh mục áp dụng (NULL = Ngân sách tổng) |
| TotalAmount | Decimal(15, 2) | Check (> 0) | Tổng tiền hạn mức ngân sách |
| Spent | Decimal(15, 2) | Default 0 | Số tiền thực tế đã chi |
| Threshold_Warning_Amount | Decimal(15, 2) | NULL | Số tiền còn lại chạm ngưỡng cảnh báo |
| Threshold_Warning_Percent | Decimal(15, 2) | NULL, Default 0 - Check (>= 0 AND <= 100) | Phần trăm đã chi chạm ngưỡng cảnh báo (%) |
| OverSpending | Varchar(7) | Check in (Stop, Over) - Default Over | Cho phép chi tiêu vượt hạn mức (Over) hay chặn lại (Stop) |
| OverAmount | Decimal(15, 2) | NULL | Số tiền tối đa cho phép vượt hạn mức |
| Start | Timestamp | | Thời điểm bắt đầu ngân sách |
| End | Timestamp | NULL | Thời điểm kết thúc ngân sách (NULL = không thời hạn) |
| Recurrence | Boolean | Default FALSE | Tự động lặp lại ngân sách chu kỳ tiếp theo (TRUE/FALSE) |
| Time_recurrence | varchar(7) | Check in (Day, Week, Month, Quarter, Year), NULL | Chu kỳ lặp lại ngân sách |
| Nexttime_recurrence | Timestamp | NULL | Thời điểm bắt đầu chu kỳ ngân sách tiếp theo |
| Note | text | NULL | Ghi chú ngân sách |
| Create_at | Timestamp | Default Now() | Thời điểm tạo ngân sách |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật ngân sách |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm ngân sách |

## 2.10. Bảng Bill
Bảng quản lý hóa đơn định kỳ phải trả (Tiền điện, nước, internet, thuê nhà...).

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idbill | varchar(36) | PK - UUID v4 | Mã hóa đơn |
| Idaccount | Int | FK - Account(Idaccount) | Tài khoản sở hữu hóa đơn |
| Idwallet | varchar(36) | FK - Wallet (Idwallet) | Ví dự kiến chi trả hóa đơn (bắt buộc) |
| Idcategory | varchar(36) | FK - Category(Idcategory) | Danh mục chi tiêu của hóa đơn (bắt buộc) |
| Name | varchar(100) | | Tên hóa đơn |
| Amount | Decimal(15,2) | Check (> 0) | Số tiền hóa đơn |
| Start_date | Timestamp | Default Now() | Ngày bắt đầu tính hóa đơn |
| Due_date | Timestamp | | Hạn thanh toán hóa đơn |
| Pay_status | varchar(7) | Check in (Pending, Payed, Overdue) - Default Pending | Trạng thái thanh toán: Pending (Chờ trả), Payed (Đã trả), Overdue (Quá hạn) |
| Recurrence | Boolean | Default False | Cho phép lặp lại hóa đơn theo chu kỳ (TRUE/FALSE) |
| Time_recurrence | varchar(7) | Check in (Day, Week, Month, Quarter, Year), NULL | Chu kỳ lặp lại hóa đơn |
| Time_notification | varchar(7) | Check in (1, 3, 5, 7), NULL | Số ngày nhắc nhở trước khi đến hạn |
| Icon | varchar(20) | NULL | Icon hóa đơn |
| Color | varchar(20) | NULL | Màu sắc hóa đơn |
| Note | Text | NULL | Ghi chú thêm |
| Create_at | Timestamp | Default Now() | Thời điểm tạo hóa đơn |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật hóa đơn |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm hóa đơn |

## 2.11. Bảng Goal
Bảng mục tiêu tích lũy và tiết kiệm tiền.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idgoal | varchar(36) | PK - UUID v4 | Mã mục tiêu |
| Idaccount | Int | FK - Account (Idaccount) | Tài khoản sở hữu mục tiêu |
| Idwallet | varchar(36) | FK - Wallet (Idwallet), NULL | Ví lưu trữ khoản tiền tiết kiệm (NULL nếu chưa chọn) |
| Name | varchar(100) | | Tên mục tiêu |
| Target_amount | Decimal(15,2) | Check (> 0) | Số tiền mục tiêu cần đạt |
| Current_amount | Decimal(15,2) | Default 0, Check (>= 0) | Số tiền hiện đã tích lũy được |
| Start_date | Timestamp | Default Now() | Ngày bắt đầu tích lũy |
| Target_date | Timestamp | | Hạn hoàn thành mục tiêu |
| Cycle_take_money | varchar(7) | Check in (Day, Week, Month, Quarter, Year), NULL | Chu kỳ trích tiền tiết kiệm |
| Time_cycle_take_money | Timestamp | NULL | Thời điểm cụ thể trích tiền trong chu kỳ |
| Status_complete | varchar(20) | Check in (True, False) - Default False | Trạng thái đã hoàn thành mục tiêu hay chưa |
| Recurrence | Boolean | Default False | Cho phép lặp lại mục tiêu sau khi hoàn thành |
| Time_recurrence | varchar(7) | Check in (Day, Week, Month, Quarter, Year), NULL | Chu kỳ lặp lại mục tiêu |
| Icon | varchar(20) | NULL | Icon mục tiêu |
| Color | varchar(20) | NULL | Màu sắc mục tiêu |
| Note | Text | NULL | Ghi chú thêm |
| Create_at | Timestamp | Default Now() | Thời điểm tạo mục tiêu |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật mục tiêu |
| Delete_at | Timestamp | NULL | Thời điểm xóa mềm mục tiêu |

## 2.12. Bảng Transaction
Bảng lưu trữ mọi giao dịch thu, chi, chuyển khoản, đồng bộ ngân hàng, quét OCR và SMS.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idtran | varchar(36) | PK - UUID v4 | Mã giao dịch |
| Idaccount | Int | FK - Account(Idaccount) | Tài khoản thực hiện giao dịch |
| Idwallet | varchar(36) | FK - Wallet (Idwallet) | Ví thực hiện giao dịch (hoặc ví chuyển đi) |
| Idcategory | varchar(36) | FK - Category(Idcategory), NULL | Danh mục giao dịch (NULL khi là Transfer hoặc giao dịch chưa phân loại) |
| Idwallet_transfer | varchar(36) | FK - Wallet (Idwallet), NULL | Ví nhận tiền khi loại giao dịch là Transfer |
| Bank_tran_id | varchar(100) | NULL | Mã giao dịch từ phía ngân hàng / hóa đơn (phục vụ chống trùng) |
| Amount | Decimal(15,2) | Check (!= 0) | Số tiền giao dịch (giữ dấu ±: dương = tiền vào, âm = tiền ra) |
| Type | Varchar(20) | Check in (Transaction, Transfer) | Loại giao dịch: Transaction (Biến động số dư), Transfer (Chuyển khoản nội bộ) |
| Status | Varchar(10) | Check in (Pending, Confirmed, Rejected, Fail) - Default Confirmed | Trạng thái giao dịch: Pending (Chờ duyệt), Confirmed (Đã xác nhận), Rejected (Từ chối), Fail (Lỗi xử lý) |
| Provider | Varchar(40) | Check in (Manual, BankSync, SMS, ORC, Bill) - Default Manual | Nguồn tạo giao dịch: Manual (Thủ công), BankSync (Ngân hàng Casso), SMS (Tin nhắn), ORC (OCR hóa đơn), Bill (Hóa đơn) |
| Note | Text | NULL | Ghi chú chi tiết giao dịch |
| Images | Text | NULL | Đường dẫn ảnh đính kèm (hóa đơn, chứng từ) |
| DateTransaction | Timestamp | Default Now() | Thời điểm giao dịch thực tế xảy ra |
| Update_at | Timestamp | Default Now() | Thời điểm cập nhật giao dịch |
| Deleted_at | Timestamp | NULL | Thời điểm xóa mềm giao dịch |

## 2.13. Bảng RefreshToken
Bảng lưu trữ Refresh Token đã cấp cho các phiên đăng nhập.

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idtoken | int | PK - Auto increment | Mã định danh token |
| Token_hash | varchar(255) | Unique | Chuỗi token đã băm 1 chiều |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản được cấp token |
| Idrole | int | FK - Role (Idrole) - Default 2 | Quyền của tài khoản tại thời điểm cấp token |
| Expired | Timestamp | | Thời điểm hết hạn của token |
| Status | Boolean | Default False | Trạng thái token: FALSE (Còn hiệu lực), TRUE (Đã thu hồi / Revoked) |
| Device_name | varchar(100) | NULL | Tên thiết bị đăng nhập |
| IP_address | varchar(45) | NULL | Địa chỉ IP đăng nhập |
| User_agent | Text | NULL | Thông tin trình duyệt / OS / thiết bị |
| Create_at | Timestamp | Default Now() | Thời điểm cấp token |
| Update_at | Timestamp | Default Now() | Thời điểm làm mới token |

---

# 3. Tổng Hợp Ràng Buộc CSDL Chuẩn (100% Khớp Phần 2)

## 3.1. Quy tắc chung
- **Khóa chính (PK)**: Mọi bảng offline-first (`Category`, `Bank_account`, `Wallet`, `Budget`, `Bill`, `Goal`, `Transaction`) dùng `varchar(36) UUID v4` do **Client-app sinh** khi tạo mới ngoại tuyến. Các bảng hệ thống dùng `int auto-increment`.
- **Khóa ngoại (FK) liên kết Account**: Các bảng dữ liệu con trỏ về `Account(Idaccount)` với ràng buộc `ON DELETE CASCADE`.
- **Cơ chế Xóa mềm (Soft Delete)**: Sử dụng `Delete_at` (hoặc `Deleted_at` cho `Transaction`). Khi xóa mềm, ghi nhận `Timestamp` hiện tại và đồng bộ `Update_at = Now()`. Không dùng `DELETE` vật lý.
- **Xung đột & Đồng bộ (LWW)**: Áp dụng thuật toán Last-Write-Wins dựa trên `Update_at`.

## 3.2. Chi tiết ràng buộc từng bảng

### 3.2.1. Role
| Loại | Ràng buộc |
|---|---|
| PK | `Idrole` (int auto-increment) |
| Unique | `Rolename` |

### 3.2.2. Account
| Loại | Ràng buộc |
|---|---|
| PK | `Idaccount` (int auto-increment) |
| FK | `Idrole` $\rightarrow$ `Role(Idrole)` |
| Unique | `Email`, `Username` |
| Check | `Status IN ('Active', 'Inactive', 'PendingDelete', 'Deleted')`; `Type IN ('Basic', 'Premium')` |
| Default | `Status = 'Active'`, `Type = 'Basic'`, `Create_at = Now()`, `Update_at = Now()` |

### 3.2.3. User
| Loại | Ràng buộc |
|---|---|
| PK | `Iduser` (int auto-increment) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`) |
| Unique | `Idaccount` (1 User ↔ 1 Account), `Email` |
| Đồng bộ | `User.Email` luôn đồng bộ với `Account.Email`. |

### 3.2.4. Audit_log
| Loại | Ràng buộc |
|---|---|
| PK | `Idlog` (int auto-increment) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`) |
| Check | `Req_status IN ('Accepted', 'Rejected', 'Interrupted', 'Pending', 'Processing', 'Pass', 'Fail')` |
| Default | `Req_status = 'Pass'`, `TimeReq = Now()`, `TimeRes = Now()` |
| Index | `Idaccount` |

### 3.2.5. OTP_code
| Loại | Ràng buộc |
|---|---|
| PK | `Id_otp` (int auto-increment) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE SET NULL`) |
| Check | `purpose IN ('Register', 'Reset_password', 'Change_email')`; `expires_at > created_at` |
| Default | `is_used = FALSE`, `created_at = Now()`, `expires_at = Now() + INTERVAL '10 minutes'` |
| Index | `(Idaccount, purpose)`, `(Email, purpose)`, `expires_at` |

### 3.2.6. Category
| Loại | Ràng buộc |
|---|---|
| PK | `Idcategory` (varchar(36) UUID) |
| FK | `Create_by` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idgroup` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`) |
| Check | `Classify IN ('Thu', 'Chi', 'Vay/no')` |
| Default | `Is_default = FALSE`, `Is_group = FALSE`, `Create_at = Now()`, `Update_at = Now()` |
| Unique | `(Create_by, NameCategory, Classify)` — Không trùng tên danh mục trong cùng phân loại của 1 tài khoản |
| Check Phân cấp | Nhóm (`Is_group = TRUE`): `Idgroup IS NULL`. Danh mục con (`Is_group = FALSE`): có thể có `Idgroup` hoặc `NULL` (không cho phép lồng quá 2 cấp). |
| Index | `Idcategory`, `Idgroup`, `Create_by` |

### 3.2.7. Bank_account
| Loại | Ràng buộc |
|---|---|
| PK | `Id_bank_account` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`) |
| Unique | `Id_casso_account` (1 tài khoản ngân hàng Casso chỉ liên kết 1 lần duy nhất) |
| Check | `Connect_status IN ('Active', 'Expired', 'Disconnected')` |
| Default | `Balance = 0`, `Connect_status = 'Active'`, `Create_at = Now()`, `Update_at = Now()` |
| Index | `Idaccount`, `Connect_status` |

### 3.2.8. Wallet
| Loại | Ràng buộc |
|---|---|
| PK | `Idwallet` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Id_bank_casso` $\rightarrow$ `Bank_account(Id_bank_account)` (`ON DELETE SET NULL`) |
| Check | `Type IN ('Cash', 'Bank', 'Saving', 'Banking')`; `Currency IN ('VND', 'USD')`; `Status IN ('Active', 'Inactive')` |
| Default | `Type = 'Cash'`, `Balance = 0`, `Currency = 'VND'`, `Status = 'Active'`, `IncludeInTotal = TRUE`, `Is_default = FALSE` |
| Unique | `(Idaccount, Name)` — Không trùng tên ví trong cùng 1 tài khoản |
| Unique | `Id_bank_casso` **WHERE NOT NULL** — 1 tài khoản ngân hàng chỉ tạo tối đa 1 ví Banking |
| Index | `Idaccount`, `Id_bank_casso`, `Update_at` |

### 3.2.9. Budget
| Loại | Ràng buộc |
|---|---|
| PK | `Idbudget` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idcategory` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`, NULL = Ngân sách tổng) |
| Check | `TotalAmount > 0`; `Spent >= 0`; `Threshold_Warning_Percent >= 0 AND Threshold_Warning_Percent <= 100`; `OverSpending IN ('Stop', 'Over')`; `Time_recurrence IN ('Day', 'Week', 'Month', 'Quarter', 'Year')` |
| Default | `Spent = 0`, `Threshold_Warning_Percent = 0`, `OverSpending = 'Over'`, `Recurrence = FALSE` |
| Index | `Idaccount`, `Idcategory` |

### 3.2.10. Bill
| Loại | Ràng buộc |
|---|---|
| PK | `Idbill` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)`; `Idcategory` $\rightarrow$ `Category(Idcategory)` |
| Check | `Amount > 0`; `Pay_status IN ('Pending', 'Payed', 'Overdue')`; `Time_recurrence IN ('Day', 'Week', 'Month', 'Quarter', 'Year')`; `Time_notification IN ('1', '3', '5', '7')` |
| Default | `Pay_status = 'Pending'`, `Recurrence = FALSE`, `Time_notification = '3'` |
| Index | `Idaccount`, `Idwallet`, `Idcategory` |

### 3.2.11. Goal
| Loại | Ràng buộc |
|---|---|
| PK | `Idgoal` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`) |
| Check | `Target_amount > 0`; `Current_amount >= 0`; `Status_complete IN ('True', 'False')`; `Cycle_take_money IN ('Day', 'Week', 'Month', 'Quarter', 'Year')` |
| Default | `Current_amount = 0`, `Status_complete = 'False'`, `Recurrence = FALSE` |
| Index | `Idaccount`, `Idwallet` |

### 3.2.12. Transaction
| Loại | Ràng buộc |
|---|---|
| PK | `Idtran` (varchar(36) UUID) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idwallet` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE CASCADE`); `Idcategory` $\rightarrow$ `Category(Idcategory)` (`ON DELETE SET NULL`); `Idwallet_transfer` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`) |
| Check | `Type IN ('Transaction', 'Transfer')`; `Status IN ('Pending', 'Confirmed', 'Rejected', 'Fail')`; `Provider IN ('Manual', 'BankSync', 'SMS', 'ORC', 'Bill')`; `Amount != 0` |
| Default | `Type = 'Transaction'`, `Status = 'Confirmed'`, `Provider = 'Manual'`, `DateTransaction = Now()` |
| Unique | `(Provider, Bank_tran_id)` **WHERE Bank_tran_id IS NOT NULL** (Chống trùng giao dịch ngân hàng / hóa đơn theo nguồn) |
| Index | `Idaccount`, `Idwallet`, `Idcategory`, `Status`, `Provider`, `DateTransaction`, `Update_at` |

### 3.2.13. RefreshToken
| Loại | Ràng buộc |
|---|---|
| PK | `Idtoken` (int auto-increment) |
| FK | `Idaccount` $\rightarrow$ `Account(Idaccount)` (`ON DELETE CASCADE`); `Idrole` $\rightarrow$ `Role(Idrole)` |
| Unique | `Token_hash` |
| Check | `Expired > Create_at` |
| Default | `Idrole = 2`, `Status = FALSE` (FALSE: còn hiệu lực, TRUE: đã thu hồi), `Create_at = Now()`, `Update_at = Now()` |
| Index | `Idaccount`, `Expired`, `Status`, `Token_hash` |
