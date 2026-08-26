# 1. Quy tắc chung
- Tại SQLite với mọi bảng đều có thêm cột Sync_status
- uuid là id tự sinh được thiết lập tại Client-app. Backend chỉ đảm nhận việc ghi nhận mã.
- **Cơ chế xóa mềm**: dùng cột `Delete_at`. Nếu cột `Delete_at` **có giá trị** (Timestamp) thì nghĩa là dữ liệu đã bị xóa mềm; nếu cột **rỗng** (NULL) thì dữ liệu đang dùng (chưa bị xóa).
- Bảng Audit_log dùng để theo dõi yêu cầu gửi về backend - không theo dõi hoạt động của người dùng
# 2. CSDL
## 2.1. Bảng Role

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idrole | int | PK - Auto increment | Mã vai trò |
| Rolename | varchar(20) | unique | Tên vai trò |
| Description | text | NULL | Mô tả vai trò |

## 2.2. Bảng Account

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idaccount | int | PK - Auto increment | Mã tài khoản |
| Idrole | int | FK - Role (Idrole) | Tài khoản có vai trò gì - Mã vai trò |
| Email | varchar(100) | unique | Email (đồng bộ với User.Email) |
| Username | varchar(255) | | Tên đăng nhập |
| Password | varchar(255) | Hash | Mật khẩu - băm |
| Status | varchar(20) | Check in (Active, Inactive, PendingDelete, Deleted) | Trạng thái tài khoản |
| Type | varchar(20) | Check in (Basic, Premium) - Default Basic | Loại tài khoản, cơ bản hay là premium |
| Create_at | Timestamp | Default Getdate() | Thời điểm tạo tài khoản |
| Update_at | Timestamp | NULL | Thời điểm cập nhật tài khoản |
| Delete_at | Timestamp | NULL | Thời điểm xóa tài khoản |

## 2.3. Bảng User

| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Iduser | int | PK | Mã người dùng |
| Idaccount | int | FK - Account (Idaccount) | Người dùng có tài khoản là gì - Mã tài khoản |
| Fullname | nvarchar(100) | | Họ & tên |
| Email | varchar(100) | unique | Email người dùng (phải đồng bộ với Account.Email) |
| Phone | varchar(15) | NULL | Số điện thoại |
| Address | Text | NULL | Địa chỉ người dùng |
| Country_code | char(4) | NULL | (+84, +0, +1, +86 …. ) |
| Create_at | Timestamp | Default Getdate() | Thời điểm tạo người dùng |
| Update_at | Timestamp | NULL | Thời điểm cập nhật người dùng |
| Delete_at | Timestamp | NULL | Thời điểm xóa người dùng |

## 2.4. Bảng Audit_log

### Audit_log
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idlog | int | PK - Auto increment | Mã log |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản thực hiện yêu cầu - Mã tài khoản |
| Request | Varchar(200) | | Yêu cầu từ client -> server |
| TimeReq | Timestamp | Default Getdate() | Thời gian yêu cầu được gửi đến |
| TimeRes | Timestamp | Default Getdate() | Thời gian yêu cầu được giải quyết & gửi đi. |

## 2.5. Bảng OTP_code

### OTP_code
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Id_otp | int | PK - Auto increment | Mã định danh otp |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản thực hiện yêu cầu OTP - Mã tài khoản |
| Email | varchar(100) | | Email |
| code_hash | varchar(255) | | Otp đã được mã hóa |
| purpose | varchar(30) | | Mục đích |
| is_used | Boolean | | Đã được dùng - TRUE hay là chưa dùng - FALSE |
| expires_at | Timestamp | Default Getdate() + 10 minutes | Hết hạn vào thời điểm nào |
| created_at | Timestamp | Default Getdate() | OTP được tạo vào thời điểm nào |

## 2.6. Bảng Category

### Category
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idcategory | varchar(36) | PK - uuid | Mã danh mục |
| Create_by | int | FK - Account (Idaccount) - **Default = idaccount của admin (đọc từ DB)** | Danh mục được tạo bởi ai - mã tài khoản. Danh mục default toàn cục do admin quản lý → khi seed, `Create_by` được gán bằng **`idaccount` của admin đọc từ DB** (không cứng giá trị) |
| NameCategory | varchar(200) | | Tên danh mục |
| Classify | varchar(10) | Check in (Thu, Chi, Vay/no) | Phân loại danh mục |
| Is_default | Boolean | Default False | Có phải danh mục mặc định hay không: có - TRUE / không - FALSE |
| Is_group | Boolean | Default FALSE | Có phải là nhóm (group) hay không: TRUE - là nhóm; FALSE - là danh mục con (lá) |
| Idgroup | varchar(36) | | Thuộc nhóm danh mục nào - lấy id tương ứng của danh mục đó |
| Keyword | varchar(500) | NULL | Các từ khóa giúp hệ thống nhận diện danh mục, mỗi keyword cách nhau bởi dấu `,` |
| Icon | varchar(20) | | Icon danh mục |
| Create_at | Timestamp | | Thời điểm danh mục được tạo |
| Update_at | Timestamp | NULL | Thời điểm danh mục được cập nhật |
| Delete_at | Timestamp | NULL | Thời điểm danh mục bị xóa |

## 2.7. Bảng Bank_account

### Bank_account
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Id_bank_account | varchar(36) | PK - uuid | Mã định danh cho tài khoản ngân hàng tại hệ thống |
| Idaccount | int | FK - Account (Idaccount) | Tài khoản ngân hàng này thuộc về ai trong hệ thống này - mã tài khoản |
| Id_casso_account | varchar(100) | | Mã định danh cho tài khoản ngân hàng phía Casso |
| Account_number | varchar(50) | | Số tài khoản từ Casso - Real Bank |
| Account_name | varchar(255) | | Chủ sở hữu từ Casso - Real Bank |
| Bank_name | varchar(100) | | Tên ngân hàng từ Casso - Real Bank |
| Balance | decimal(15,2) | | Số dư ban đầu từ Casso - Real Bank |
| Connect_status | varchar(20) | Check in (Active, Inactive) Default Active | Trạng thái kết nối ngân hàng với Casso |
| Create_at | Timestamp | default Getdate() | Thời điểm tạo kết nối |
| Update_at | Timestamp | NULL | Thời điểm kết nối lại |
| Delete_at | Timestamp | NULL | Thời điểm ngắt kết nối |

## 2.8. Bảng Wallet

### Wallet
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idwallet | varchar(36) | PK - uuid | Mã định danh ví ảo |
| Idaccount | int | FK - Account (Idaccount) | Ví thuộc về ai - Mã tài khoản |
| Id_bank_casso | varchar(36) | FK - Bank_account (Id_bank_account) - NULL | Mã định danh ngân hàng từ Casso nếu đó là ví được tạo từ liên kết ngân hàng |
| Name | nvarchar(40) | | Tên ví |
| Type | varchar(10) | Check in (Cash, Bank, Saving, Banking) - Default Cash | Loại ví: Cash - ví tiền mặt ảo; Bank - ví ngân hàng ảo do **người dùng tự tạo**; Saving - ví tiết kiệm ảo; Banking - ví ngân hàng **chỉ tạo từ liên kết Casso**, người dùng KHÔNG tự tạo thủ công được |
| Balance | decimal(15,2) | Default 0 | Số dư ví |
| Currency | Varchar(3) | Check in (VND, USD, RUP, NDT…) - Default VND | Loại tiền tệ |
| Status | Varchar(10) | Check in (Active, Inactive) - default Active | Trạng thái ví |
| IncludeInTotal | Boolean | Default TRUE | Ví này có được tính vào tổng tiền hay không (TRUE được tính; FALSE không được tính) |
| Is_default | Boolean | Default FALSE | Ví mặc định của tài khoản (tối đa 1 ví tự thiết lập mặc định) |
| Icon | Varchar(20) | | Icon ví |
| Color | Varchar(20) | | Màu ví |
| Create_at | Timestamp | default Getdate() | Thời điểm Ví được tạo |
| Update_at | Timestamp | NULL | Thời điểm Ví được cập nhật |
| Delete_at | Timestamp | NULL | Thời điểm Ví được xóa mềm |

## 2.9. Bảng Budget

### Budget
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idbudget | varchar(36) | PK - uuid | Mã định danh ngân sách |
| Idaccount | int | FK - Account (Idaccount) | Ngân sách này thuộc về ai - mã tài khoản |
| Idcategory | varchar(36) | FK - Category (Idcategory) - **NULL** | Ngân sách này dùng cho mục đích chi tiêu nào - mã danh mục. **NULL = ngân sách tổng** (không theo category) |
| TotalAmount | Decimal(15,2) | | Tổng tiền ngân sách |
| Spent | Decimal(15,2) | Default 0 | Số tiền đã chi |
| Remaining | Decimal(15,2) | NULL | Số tiền còn lại |
| PercentSpent | int | Default 0 - Check (>=0 & <=100) | % số tiền đã chi |
| OverSpending | Varchar(20) | Check in (Stop, Over) - Default Over | Có cho phép chi tiêu vượt hạn mức hay không |
| OverAmount | Decimal(15,2) | NULL | Số tiền cho phép vượt là bao nhiêu. Nếu để là NULL thì số tiền cho phép vượt không giới hạn |
| Start | Timestamp | | Thời điểm bắt đầu ngân sách |
| End | Timestamp | | Thời điểm kết thúc ngân sách |
| Recurrence | Boolean | Default FALSE | Cho phép lặp lại ngân sách hay không: False - không; True - có |
| Time_recurrence | varchar(10) | Check in (Week, Month, Quarter, Year) | Thời gian lặp lại ngân sách là bao lâu: mỗi tuần 1 lần, mỗi tháng 1 lần, mỗi quý (3 tháng) 1 lần, mỗi năm 1 lần |
| Note | text | NULL | Ghi chú thêm cho ngân sách |
| Create_at | Timestamp | default Getdate() | Ngân sách được tạo vào ngày |
| Update_at | Timestamp | NULL | Thời điểm ngân sách được cập nhật |
| Delete_at | Timestamp | NULL | Ngân sách bị xóa vào ngày |

## 2.10. Bảng Bill

### Bill
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idbill | varchar(36) | PK - uuid | Mã hóa đơn |
| Idaccount | int | FK - Account (Idaccount) | Hóa đơn này thuộc về ai - mã tài khoản |
| Idwallet | varchar(36) | FK - Wallet (Idwallet) - **BẮT BUỘC** | Hóa đơn này dùng ví nào để chi trả - mã ví (bắt buộc chọn khi tạo bill) |
| Idcategory | varchar(36) | FK - Category (Idcategory) - **BẮT BUỘC** | Hóa đơn này thuộc danh mục nào - mã danh mục (bắt buộc chọn khi tạo bill) |
| Name | varchar(100) | | Tên hóa đơn |
| Amount | Decimal(15,2) | | Số tiền hóa đơn phải chi trả |
| due_date | Timestamp | | Hạn chi trả hóa đơn |
| Pay_status | Boolean | Default False | Trạng thái thanh toán: True - đã thanh toán; False - chưa thanh toán |
| Recurrence | Boolean | | Cho phép lặp lại hóa đơn hay không: False - không; True - có |
| Time_recurrence | varchar(10) | Check in (Week, Month, Quarter, Year) | Thời gian lặp lại hóa đơn là bao lâu: mỗi tuần 1 lần, mỗi tháng 1 lần, mỗi quý (3 tháng) 1 lần, mỗi năm 1 lần |
| Icon | varchar(20) | | Icon hóa đơn |
| Color | varchar(20) | | Màu hóa đơn |
| Note | Text | NULL | Ghi chú thêm cho hóa đơn |
| Create_at | Timestamp | default Getdate() | Hóa đơn được tạo vào ngày |
| Update_at | Timestamp | NULL | Hóa đơn được cập nhật vào ngày |
| Delete_at | Timestamp | NULL | Hóa đơn bị xóa vào ngày |

## 2.11. Bảng Goal

### Goal
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idgoal | varchar(36) | PK - uuid | Mã mục tiêu tiết kiệm |
| Idaccount | int | FK - Account (Idaccount) | Mục tiêu tiết kiệm này là của ai - mã tài khoản |
| Idwallet | varchar(36) | FK - Wallet (Idwallet) - **NULL** | Khoản tiền tiết kiệm được lưu tại ví nào - mã ví. **NULL = chưa liên kết ví đích** (được gán lần đầu khi user nạp tiền vào goal) |
| Name | varchar(100) | | Tên mục tiêu |
| Target_amount | Decimal(15,2) | | Số tiền cần đạt |
| Current_amount | Decimal(15,2) | | Số tiền đã có |
| Target_date | Timestamp | | Hạn hoàn thành mục tiêu |
| Status_complete | Boolean | Default False | Trạng thái hoàn thành mục tiêu |
| Icon | varchar(20) | | Icon mục tiêu |
| Color | varchar(20) | | Màu mục tiêu |
| Note | Text | NULL | Ghi chú thêm cho mục tiêu |
| Create_at | Timestamp | default Getdate() | Mục tiêu được tạo vào ngày |
| Update_at | Timestamp | NULL | Mục tiêu được cập nhật vào ngày |
| Delete_at | Timestamp | NULL | Mục tiêu bị xóa vào ngày |

## 2.12. Bảng Transaction

### Transaction
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idtran | varchar(36) | PK - uuid | Mã giao dịch |
| Idaccount | int | FK - Account (Idaccount) | Giao dịch do ai thực hiện - mã tài khoản |
| Idwallet | varchar(36) | FK - Wallet (Idwallet) | Giao dịch do ví nào thực hiện - mã ví |
| Idcategory | varchar(36) | FK - Category (Idcategory) | Giao dịch cho danh mục nào - mã danh mục |
| Amount | Decimal(15,2) | **Giữ dấu ±** | Số tiền giao dịch. **Dương (+)** = tiền vào; **Âm (-)** = tiền ra. Giữ dấu để xác định dòng tiền NGAY mà không cần chờ phân loại category. |
| Type | Varchar(20) | Check in (Transaction, Transfer) | Loại giao dịch: Transaction - giao dịch biến động số dư; Transfer - chuyển dời số tiền, không phải giao dịch biến động số dư |
| Provider | Varchar(40) | Check in (Manual, Casso, SMS, OCR) | Nguồn giao dịch - dùng để chống trùng theo nguồn |
| Note | Text | | Ghi chú cho giao dịch |
| Images | Text | Null | Hình ảnh đi kèm giao dịch |
| Create_at | Timestamp | Default Getdate() | Thời điểm giao dịch (ngày tạo) |
| Update_at | Timestamp | NULL | Thời điểm giao dịch được cập nhật |
| Delete_at | Timestamp | NULL | Thời điểm giao dịch bị xóa mềm |
| Wallet_Transfer | varchar(36) | NULL | Nếu giao dịch là Transfer thì sẽ ghi nhận thêm 1 ví thực hiện giao dịch chuyển dời tiền - mã ví |
| Bank_tran_id | varchar(100) | NULL | Mã định danh giao dịch phía ngân hàng - Real Bank (chống trùng webhook) |

## 2.13. Bảng RefreshToken

### RefreshToken
| Tên cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
|---|---|---|---|
| Idtoken | int | PK - Auto increment | Mã định danh refresh token |
| Token_hash | varchar(255) | unique | Refresh token đã được băm - dùng để xác thực |
| Idaccount | int | FK - Account (Idaccount) | Refresh token này thuộc về tài khoản nào |
| Idrole | int | Default 2 | Vai trò của tài khoản tại thời điểm cấp token |
| Expiry | Timestamp | | Thời điểm token hết hạn |
| Revoked | Boolean | Default FALSE | Token đã bị thu hồi hay chưa: TRUE - đã thu hồi; FALSE - còn hiệu lực |
| Device_name | varchar(100) | NULL | Tên thiết bị đăng nhập |
| Ip_address | varchar(45) | NULL | Địa chỉ IP đăng nhập |
| User_agent | text | NULL | User-agent của trình duyệt/thiết bị |
| Create_at | Timestamp | Default Getdate() | Thời điểm token được cấp |
| Update_at | Timestamp | NULL | Thời điểm token được cập nhật |

# 3. Ràng buộc CSDL

## 3.1. Quy tắc chung

- **PK**: Mọi bảng offline-first dùng `varchar(36) uuid` do **Client sinh** — Backend chỉ ghi nhận mã, không tự sinh (trừ `Role`, `Account`, `User`, `Audit_log`, `OTP_code`, `RefreshToken` dùng `int auto-increment`).
- **FK → Account**: Mọi bảng nghiệp vụ (`Category`, `Bank_account`, `Wallet`, `Budget`, `Bill`, `Goal`, `Transaction`, `RefreshToken`) có `Idaccount` làm FK → `Account(Idaccount)`, với `ON DELETE CASCADE` (xóa tài khoản → xóa toàn bộ dữ liệu con).
- **Soft delete**: Các bảng có cột `Delete_at` — nếu cột `Delete_at` **có giá trị** (Timestamp) thì dữ liệu đã bị xóa mềm; nếu **rỗng** (NULL) thì dữ liệu đang dùng. Không dùng `DELETE` vật lý.
- **Sync**: Mọi bảng offline-first (client) có thêm cột `Sync_status`; quyết định bản ghi nào hợp lệ dựa trên `Update_at` (Last-Write-Wins).

## 3.2. Chi tiết ràng buộc từng bảng

### 3.2.1. Role
| Loại | Ràng buộc |
|---|---|
| PK | `Idrole` |
| Unique | `Rolename` |

### 3.2.2. Account
| Loại | Ràng buộc |
|---|---|
| PK | `Idaccount` |
| FK | `Idrole` → `Role(Idrole)` |
| Unique | `Email`, `Username` |
| Check | `Status IN (Active, Inactive, PendingDelete, Deleted)`; `Type IN (Basic, Premium)` |
| Default | `Status='Active'`, `Type='Basic'` |

### 3.2.3. User
| Loại | Ràng buộc |
|---|---|
| PK | `Iduser` |
| FK | `Idaccount` → `Account(Idaccount)` |
| Unique | `Idaccount` (1 user ↔ 1 account), `Email` |
| Đồng bộ | **`User.Email` PHẢI đồng bộ với `Account.Email`** (cùng giá trị). Khi đổi email phải cập nhật cả 2 bảng trong cùng transaction. |

### 3.2.4. Audit_log
| Loại | Ràng buộc |
|---|---|
| PK | `Idlog` |
| FK | `Idaccount` → `Account(Idaccount)` |
| Index | `Idaccount` (truy vấn theo tài khoản) |

### 3.2.5. OTP_code
| Loại | Ràng buộc |
|---|---|
| PK | `Id_otp` |
| FK | `Idaccount` → `Account(Idaccount)` |
| Index | `(Idaccount, purpose)` — lấy OTP còn hạn theo tài khoản & mục đích; `(Email, purpose)` — tra theo email; `expires_at` — dọn OTP hết hạn |
| Check | `expires_at > created_at` |

### 3.2.6. Category
| Loại | Ràng buộc |
|---|---|
| PK | `Idcategory` |
| FK | `Create_by` → `Account(Idaccount)`; `Idgroup` → `Category(Idcategory)` (tự tham chiếu, nhóm) |
| Check | `Classify IN (Thu, Chi, Vay/no)` |
| Unique | `(Create_by, NameCategory, Classify)` — không trùng tên danh mục trong cùng phân loại của 1 tài khoản |
| Unique | `(NameCategory, Classify)` **WHERE `Is_default = TRUE`** — không trùng tên danh mục mặc định toàn cục (do admin quản lý; `Create_by` = `idaccount` admin đọc từ DB) |
| Check (Idgroup) | Parent phải là danh mục nhóm: `Is_group = TRUE`, cùng `Create_by` (cùng tài khoản), `Is_default = FALSE`, và group đó có `Idgroup IS NULL` (không cho nhóm lồng nhau) |
| Check (Is_group) | Group (`Is_group = TRUE`): `Idgroup IS NULL` (nhóm cấp cao nhất); Con (`Is_group = FALSE`): có thể có `Idgroup` (con của nhóm) hoặc `NULL` (chưa nhóm) |
| Index | `Create_by`; `Idgroup` |

### 3.2.7. Bank_account
| Loại | Ràng buộc |
|---|---|
| PK | `Id_bank_account` |
| FK | `Idaccount` → `Account(Idaccount)` |
| Unique | `Id_casso_account` — 1 tài khoản Casso chỉ liên kết 1 lần |
| Check | `Connect_status IN (Active, Inactive)` |
| Default | `Connect_status='Active'` |
| Index | `Idaccount` |

### 3.2.8. Wallet
| Loại | Ràng buộc |
|---|---|
| PK | `Idwallet` |
| FK | `Idaccount` → `Account(Idaccount)`; `Id_bank_casso` → `Bank_account(Id_bank_account)` (`ON DELETE SET NULL`) |
| Check | `Type IN (Cash, Bank, Saving, Banking)`; `Currency IN (VND, USD, ...)` |
| Default | `Type='Cash'`, `Balance=0`, `Currency='VND'`, `Status='Active'`, `IncludeInTotal=TRUE`, `Is_default=FALSE` |
| Unique | `(Idaccount, Name)` — không trùng tên ví trong cùng tài khoản |
| Unique | `Id_bank_casso` **WHERE NOT NULL** — 1 tài khoản NH chỉ tạo 1 ví bank (không trùng ví) |
| Unique | `(Idaccount)` **WHERE `Type='Saving'` AND `Delete_at IS NULL`** — tối đa 1 ví tiết kiệm cứng mỗi tài khoản |
| Unique | `(Idaccount)` **WHERE `Is_default=TRUE` AND `Delete_at IS NULL`** — tối đa 1 ví tự thiết lập mặc định mỗi tài khoản |
| Check (Banking) | `Type='Banking'` → bắt buộc `Id_bank_casso NOT NULL` (chỉ tạo từ liên kết Casso, user không tự tạo); `Type != 'Banking'` → `Id_bank_casso` phải NULL |
| Index | `Idaccount`; `Id_bank_casso` |

### 3.2.9. Budget
| Loại | Ràng buộc |
|---|---|
| PK | `Idbudget` |
| FK | `Idaccount` → `Account(Idaccount)`; `Idcategory` → `Category(Idcategory)` (**NULL = ngân sách tổng**) |
| Check | `TotalAmount > 0`; `PercentSpent BETWEEN 0 AND 100`; `Time_recurrence IN (Week, Month, Quarter, Year)`; `End > Start` |
| Default | `Spent=0`, `PercentSpent=0`, `OverSpending='Over'`, `Recurrence=FALSE` |
| Index | `Idaccount`; `Idcategory` |

### 3.2.10. Bill
| Loại | Ràng buộc |
|---|---|
| PK | `Idbill` |
| FK | `Idaccount` → `Account(Idaccount)`; `Idwallet` → `Wallet(Idwallet)` (**BẮT BUỘC** — bắt buộc chọn ví khi tạo bill); `Idcategory` → `Category(Idcategory)` (**BẮT BUỘC** — bắt buộc chọn danh mục khi tạo bill) |
| Check | `Amount > 0`; `Time_recurrence IN (Week, Month, Quarter, Year)` |
| Default | `Pay_status=FALSE` |
| Index | `Idaccount`; `Idwallet`; `Idcategory` |

### 3.2.11. Goal
| Loại | Ràng buộc |
|---|---|
| PK | `Idgoal` |
| FK | `Idaccount` → `Account(Idaccount)`; `Idwallet` → `Wallet(Idwallet)` (**NULL** = chưa liên kết ví đích, gán lần đầu khi nạp tiền; `ON DELETE SET NULL` — xóa ví không xóa mục tiêu) |
| Check | `Target_amount > 0`; `Current_amount >= 0` |
| Default | `Status_complete=FALSE` |
| Index | `Idaccount`; `Idwallet` |

### 3.2.12. Transaction
| Loại | Ràng buộc |
|---|---|
| PK | `Idtran` |
| FK | `Idaccount` → `Account(Idaccount)`; `Idwallet` → `Wallet(Idwallet)`; `Idcategory` → `Category(Idcategory)`; `Wallet_Transfer` → `Wallet(Idwallet)` |
| Check | `Type IN (Transaction, Transfer)`; `Provider IN (Manual, Casso, SMS, OCR)`; **`Amount != 0`** (giữ dấu ±: dương = vào, âm = ra) |
| Check (đồng bộ) | `Provider IN ('Casso','SMS')` → `Bank_tran_id IS NOT NULL`; `Provider IN ('Manual','OCR')` → `Bank_tran_id IS NULL` |
| Unique | **`(Provider, Bank_tran_id)`** (chống trùng **theo nguồn** — giao dịch cùng nguồn & cùng mã ngân hàng chỉ có 1 bản ghi) |
| Index | `Idaccount`; `Idwallet`; `Idcategory`; `Create_at`; `Provider`; `Bank_tran_id` |
| Default | `Provider='Manual'`, `Images=NULL`, `Wallet_Transfer=NULL`, `Bank_tran_id=NULL` |
| Ghi chú luồng | Giao dịch webhook Casso: **ghi vào CSDL TRƯỚC** (Amount giữ dấu, `Idcategory=NULL`) → **phân loại danh mục SAU** (AI/worker cập nhật `Idcategory`) |

### 3.2.13. RefreshToken
| Loại | Ràng buộc |
|---|---|
| PK | `Idtoken` |
| FK | `Idaccount` → `Account(Idaccount)` (`ON DELETE CASCADE`) |
| Unique | `Token_hash` |
| Index | `Idaccount`; `Expiry` (dọn token hết hạn); `Revoked`; `Token_hash` |
| Default | `Idrole=2`, `Revoked=FALSE` |
| Check | `Expiry > Create_at` |
