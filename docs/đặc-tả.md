# Đặc tả

> Nguồn: đặc-tả.pdf — bản chuyển đổi tự động, giữ nguyên nội dung theo từng trang.

<!-- Trang 1 -->

4, Sơ đồ Use Case tổng quát  
 
5, Đặc tả chức năng 5.1. Đặc tả chức năng “Đăng ký tài khoản”   
Đăng ký tài khoản

---

<!-- Trang 2 -->

Tiền điều kiện Người dùng chưa có tài khoản trên hệ thống, thiết bị có kết nối mạng và đang ở trang đăng ký. Hậu điều kiện Tài khoản mới được khởi tạo thành công trong database với trạng thái hoạt động mặc định. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Nhập thông tin đăng ký (Họ tên, Email, Mật khẩu, Xác nhận mật khẩu).  
  
  2. Kiểm tra tính hợp lệ của dữ liệu đầu vào (độ dài mật khẩu, định dạng email).  
3. Bấm nút “Đăng ký”. 4. Kiểm tra sự tồn tại của Email trong cơ sở dữ liệu. 5. Thực hiện băm mật khẩu, lưu thông tin tài khoản mới. 6. Hiển thị thông báo “Đăng ký thành công”  
  7. Chuyển hướng về trang Đăng nhập. Alternative flow 2.1. Dữ liệu nhập vào không hợp lệ 1. Hệ thống hiển thị thông báo lỗi cụ thể dưới ô thông tin tương ứng. 2. Quay lại bước 1. 4.1. Email đã tồn tại trên hệ thống 1. Hệ thống hiển thị thông báo: “Email này đã được sử dụng”. 2. Quay lại bước 1. - Ghi chú: xây dựng tại backend, bắt buộc phải có internet thì mới đăng ký được.  
5.2. Đặc tả chức năng “Đăng nhập”  
Đăng nhập Tiền điều kiện Người dùng đã có tài khoản trên hệ thống.

---

<!-- Trang 3 -->

Hậu điều kiện Phiên đăng nhập được thiết lập, JWT token được cấp phát và người dùng truy cập màn hình tương ứng. Actor chính Người dùng, Admin Actor phụ Không Basic flow Người dùng / Admin Hệ thống 1. Nhập thông tin đăng nhập (Email, Mật khẩu).  
  
2. Bấm nút “Đăng nhập”. 3. Kiểm tra tài khoản theo Email và so khớp mật khẩu đã băm. 4. Xác định quyền hạn truy cập của tài khoản (User hoặc Admin). 5. Sinh chuỗi JWT Token (Access Token & Refresh Token). 6. Chuyển hướng về màn hình Home (đối với User) hoặc Dashboard quản trị (đối với Admin). Alternative flow 3.1. Sai thông tin đăng nhập 1. Hệ thống hiển thị thông báo: “Email hoặc mật khẩu không chính xác”. 2. Quay lại bước 1. 3.2. Tài khoản đã bị khóa 1. Hệ thống phát hiện tài khoản đang bị khóa (status = Locked). 2. Hiển thị thông báo: “Tài khoản của bạn đã bị khóa”. - Admin bắt buộc phải có internet để đăng nhập - xây tại backend -   
5.3. Đặc tả chức năng “Đăng xuất”  
Đăng xuất Tiền điều kiện Người dùng hoặc Admin đang ở trạng thái đăng nhập. Hậu điều kiện Token phiên làm việc bị vô hiệu hóa và xóa sạch trên Client. Actor chính Người dùng, Admin Actor phụ Không

---

<!-- Trang 4 -->

Basic flow Người dùng / Admin Hệ thống 1. Bấm chọn nút “Đăng xuất”. 2. Xác nhận đồng ý đăng xuất. 3. Gửi yêu cầu vô hiệu hóa token lên Server.  
  4. Thu hồi token, xóa dữ liệu session lưu trữ trên Server. 5. Xóa dữ liệu JWT Token lưu trữ ở Client (Cookies/LocalStorage). 6. Chuyển hướng người dùng về trang Đăng nhập. Alternative flow - Backend + mobile_app  
5.4. Đặc tả chức năng “Quên mật khẩu”  
Quên mật khẩu Tiền điều kiện Người dùng không nhớ mật khẩu tài khoản của mình. Hậu điều kiện Hệ thống gửi liên kết hoặc mã OTP khôi phục mật khẩu về email đã đăng ký. Actor chính Người dùng Actor phụ Hệ thống Email (SMTP Service) Basic flow Người dùng Hệ thống Hệ thống Email (SMTP Service) 1. Bấm liên kết “Quên mật khẩu” tại trang đăng nhập.  
2. Hiển thị giao diện nhập Email tài khoản.  
  
3. Nhập Email. 4. Bấm “Gửi yêu cầu”. 5. Kiểm tra sự tồn tại của Email trong DB.  
  
  6. Sinh mã OTP/Link khôi phục mật khẩu (hiệu lực 15 phút).  
  
  7. Gửi dữ liệu OTP/Link khôi phục tới SMTP Service.

---

<!-- Trang 5 -->

8. Nhận thông tin, định dạng email và gửi tới hòm thư người dùng. 9. Hiển thị thông báo: “Mã khôi phục đã được gửi đến email của bạn”.  
  
Alternative flow 5.1. Email không tồn tại trên hệ thống 1. Hệ thống hiển thị lỗi “Email chưa được đăng ký”. 2. Quay lại bước 3. - Backend (phải có internet, mobile_app dùng) (Gửi otp qua email)  
5.5. Đặc tả chức năng “đổi mật khẩu”  
Đổi mật khẩu Tiền điều kiện Người dùng đã đăng nhập và truy cập trang Cấu hình tài khoản. Hậu điều kiện Mật khẩu mới thay thế mật khẩu cũ thành công trong Database. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Nhập mật khẩu hiện tại, mật khẩu mới và xác nhận mật khẩu mới.  
  
2. Bấm nút “Lưu thay đổi”. 3. Kiểm tra mật khẩu hiện tại có khớp với mật khẩu cũ trong DB hay không. 4. Kiểm tra sự trùng khớp giữa mật khẩu mới và xác nhận mật khẩu mới. 5. Thực hiện băm (hash) mật khẩu mới và lưu đè vào DB. 6. Hiển thị thông báo: “Đổi mật khẩu thành công”. Alternative flow

---

<!-- Trang 6 -->

3.1. Sai mật khẩu hiện tại 1. Hệ thống hiển thị thông báo lỗi: “Mật khẩu hiện tại không chính xác”. 2. Quay lại bước 1. 4.1. Mật khẩu mới trùng với mật khẩu hiện tại hoặc không khớp xác nhận 1. Hệ thống thông báo lỗi tương ứng. 2. Quay lại bước 1. - Backend (phải có internet, dùng cho cả admin và mobile)  
5.6. Đặc tả chức năng “Yêu cầu xóa tài khoản”  
Yêu cầu xóa tài khoản Tiền điều kiện Người dùng đã đăng nhập và truy cập phần cài đặt tài khoản. Hậu điều kiện Trạng thái tài khoản chuyển thành “Pending_Deletion”, tạm ẩn dữ liệu và lên lịch xóa vĩnh viễn sau 30 ngày. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn chức năng “Yêu cầu xóa tài khoản”.  
2. Hiển thị cảnh báo hậu quả của việc xóa tài khoản và thời gian chờ 30 ngày. 3. Nhập mật khẩu xác thực. 4. Bấm “Xác nhận xóa”. 5. Kiểm tra tính chính xác của mật khẩu. 6. Chuyển trạng thái tài khoản thành “Chờ xóa”, lưu thời gian yêu cầu. 7. Thực hiện đăng xuất người dùng, hiển thị thông báo tài khoản sẽ bị xóa vĩnh viễn sau 30 ngày. Alternative flow 5.1. Nhập sai mật khẩu xác thực 1. Hệ thống báo lỗi mật khẩu không khớp. 2. Quay lại bước 3. - Backend (Phải có internet, dành cho mobile)  
5.7. Đặc tả chức năng “Profile cá nhân”  
Profile cá nhân

---

<!-- Trang 7 -->

Tiền điều kiện Người dùng đã đăng nhập và đang ở màn hình thông tin cá nhân. Hậu điều kiện Hồ sơ thông tin cá nhân được cập nhật thành công trong Database. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chỉnh sửa thông tin cá nhân (Họ tên, …).  
  
2. Bấm nút “Lưu thay đổi”. 3. Kiểm tra tính hợp lệ của dữ liệu. 4. Cập nhật các trường thông tin trong DB.  
  5. Thay đổi hiển thị trên giao diện của Client. 6. Hiển thị thông báo: “Cập nhật hồ sơ thành công”. Alternative flow 3.1. Dữ liệu nhập vào trống hoặc không hợp lệ 1. Hệ thống hiển thị thông báo lỗi tương ứng. 2. Quay lại bước 1. - Mobile app  
5.8. Đặc tả chức năng “Quản lý danh sách người dùng”  
Quản lý danh sách người dùng Tiền điều kiện Admin đăng nhập thành công và truy cập phân hệ quản lý của Admin. Hậu điều kiện Xem danh sách và thực hiện khóa/mở khóa tài khoản người dùng thành công. Actor chính Admin Actor phụ Không Basic flow Admin Hệ thống 1. Chọn mục “Quản lý người dùng”. 2. Truy vấn danh sách toàn bộ người dùng từ DB (phân trang hiển thị).

---

<!-- Trang 8 -->

3. Hiển thị danh sách kèm thông tin cơ bản: Họ tên, Email, Trạng thái (Action/Inactive).  
4. Chọn một tài khoản, bấm “Khóa tài khoản” (hoặc “Mở khóa”).  
5. Kiểm tra quyền hạn của Admin và cập nhật trạng thái hoạt động của tài khoản người dùng tương ứng trong DB. 6. Ghi chép nhật ký kiểm toán (Audit Log) về thao tác này. 7. Cập nhật hiển thị danh sách mới và báo “Thao tác thành công”. Alternative flow -backend (dành cho admin)  
5.9. Đặc tả chức năng “Thiết lập ví” Phân rã ch ứ c năng:  
 5.9.1. Đặc tả chức năng Thêm ví Thêm Ví Tiền điều kiện Người dùng đã đăng nhập và đang ở màn hình Quản lý ví. Hậu điều kiện Một tài khoản ví tài chính mới được tạo lập thành công trong DB.

---

<!-- Trang 9 -->

Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn chức năng “Thêm ví mới”. 2. Hiển thị form nhập thông tin ví (Tên ví, loại ví: tiền mặt/ngân hàng/ví điện tử, số dư ban đầu). 3. Nhập dữ liệu 4. Nhấn “Lưu”. 5. Kiểm tra tên ví không được để trống và số dư ban đầu hợp lệ. 6. Lưu bản ghi ví mới vào DB và liên kết với tài khoản người dùng. 7. Cập nhật lại số tiền hiển thị tổng tài sản.  
  8. Hiển thị thông báo “Tạo ví thành công” và cập nhật danh sách ví hiển thị.  
Alternative flow 5.1. Tên ví trống hoặc số dư không hợp lệ 1. Hệ thống báo lỗi tương ứng bên dưới ô dữ liệu. 2. Quay lại bước 3. - mobile  
5.9.2. Đặc tả chức năng Sửa ví Sửa Ví Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý ví và chọn một ví hoạt động.  
Hậu điều kiện Thông tin của ví được cập nhật thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn chiếc ví cần chỉnh sửa, bấm nút “Sửa ví”.  
2. Hiển thị form chỉnh sửa ví chứa thông tin cũ (Tên ví, loại ví). 3. Thay đổi thông tin

---

<!-- Trang 10 -->

4. Nhấn “Cập nhật”. 5. Kiểm tra thông tin nhập hợp lệ và không bị trống. 6. Thực hiện ghi đè thông tin mới vào DB.  
  7. Cập nhật danh sách hiển thị và thông báo “Chỉnh sửa thành công”. Alternative flow 5.1. Tên ví mới bị sửa thành trống 1. Hệ thống báo lỗi “Tên ví không được để trống”. 2. Quay lại bước 3. - mobile  
5.9.3. Đặc tả chức năng Xóa ví Xóa Ví Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý ví và chọn một ví hoạt động.  
Hậu điều kiện Trạng thái ví chuyển sang “Deleted” (Soft Delete) trong DB, ẩn khỏi giao diện hoạt động. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn ví muốn xóa 2. Nhấn nút “Xóa ví”. 3. Hiển thị thông báo xác nhận: “Bạn có chắc chắn muốn xóa ví này?”. 4. Chọn “Xác nhận xóa”. 5. Cập nhật trạng thái ví trong DB thành deleted (Soft Delete). 6. Trừ số dư ví đó khỏi tổng tài sản hiển thị.  
  7. Cập nhật danh sách ví hoạt động và hiển thị thông báo “Xóa ví thành công”. Alternative flow - Mobile   
5.10. Đặc tả chức năng “Thiết lập ví mặc định”  
Thiết lập ví mặc định

---

<!-- Trang 11 -->

Tiền điều kiện Người dùng đã đăng nhập và có ít nhất 2 ví đang hoạt động. Hậu điều kiện Ví được chọn trở thành ví mặc định để tự động điền khi tạo giao dịch mới. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Truy cập trang Danh sách ví. 2. Tải và hiển thị danh sách ví đang có của người dùng. 3. Chọn một ví cụ thể 4. Bấm “Đặt làm mặc định”. 5. Cập nhật thuộc tính isDefault = true cho ví được chọn và đặt isDefault = false cho tất cả ví còn lại trong DB.  
  6. Làm mới danh sách hiển thị với nhãn “Ví mặc định” gắn bên cạnh ví được chọn và thông báo thành công. Alternative flow - mobile SQLite  
5.11. Đặc tả chức năng “Kích hoạt/vô hiệu hóa ví”  
Kích hoạt/Vô hiệu hóa ví Tiền điều kiện Người dùng đã đăng nhập và đang quản lý danh sách ví. Hậu điều kiện Ví bị vô hiệu hóa sẽ ẩn khỏi danh sách lựa chọn khi thêm giao dịch nhưng dữ liệu cũ được giữ nguyên. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn ví trong danh sách. 2. Hiển thị công tắc chuyển đổi (toggle) trạng thái “Kích hoạt”. 3. Gạt công tắc chuyển sang Tắt (Vô hiệu hóa) hoặc Bật (Kích hoạt).  
4. Cập nhật trường trạng thái active tương ứng của ví trong DB.

---

<!-- Trang 12 -->

5. Làm mới danh sách chọn ví trong màn hình Ghi chép giao dịch. 6. Hiển thị thông báo: “Cập nhật trạng thái ví thành công”. Alternative flow - mobile  
5.12. Đặc tả chức năng “Liên kết ngân hàng”  
Liên kết ngân hàng Tiền điều kiện Người dùng đã đăng nhập và đang ở màn hình liên kết tài khoản tài chính. Hậu điều kiện Kết nối thành công ví của người dùng với tài khoản ngân hàng mô phỏng qua cổng API. Actor chính Người dùng Actor phụ Cổng Bank API (Simulated Bank API Gateway) Basic flow Người dùng Hệ thống Cổng Bank API (Simulated Bank API Gateway)  
1. Chọn ngân hàng muốn liên kết từ danh sách.  
2. Gửi yêu cầu khởi tạo kết nối tới cổng Bank API.  
  
    3. Tiếp nhận yêu cầu, kiểm tra kết nối & khởi tạo phiên.  
  4. Hiển thị giao diện đăng nhập bảo mật giả lập của ngân hàng.  
  
5. Nhập thông tin đăng nhập ngân hàng và mã OTP xác minh.  
    
    6. Xác thực thông tin, cấp Token ủy quyền liên kết và gửi số dư tài khoản. 7. Nhận dữ liệu, lưu Token mã hóa, tạo ví “Ngân hàng” và báo thành công.  
  
Alternative flow

---

<!-- Trang 13 -->

5.1. Xác thực tài khoản ngân hàng thất bại 1. Cổng Bank API báo lỗi OTP/Tài khoản sai. 2. Người dùng nhập quá giới hạn 3. Báo “Liên kết thất bại”. -backend (có internet dùng cho mobile)  
5.13. Đặc tả chức năng “Thiết lập ngân sách” Phân rã chức năng:  
 
5.13.1. Đặc tả chức năng Thêm ngân sách Thêm ngân sách Tiền điều kiện Người dùng đã đăng nhập và đang ở phân hệ Quản lý ngân sách. Hậu điều kiện Hạn mức ngân sách mới được tạo lập thành công trong DB để theo dõi chi tiêu.  
Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Bấm nút “Tạo ngân sách”. 2. Hiển thị form nhập thông tin (Tên ngân sách, số tiền giới hạn, chu kỳ: tuần/tháng, danh mục áp dụng).

---

<!-- Trang 14 -->

3. Nhập dữ liệu ngân sách, chọn danh mục.  
  
4. Nhấn “Lưu”. 5. Kiểm tra số tiền giới hạn phải lớn hơn 0 và danh mục áp dụng được chỉ định.  
  6. Lưu bản ghi ngân sách mới vào DB. 7. Quét lịch sử giao dịch trong chu kỳ hiện tại để tính toán số tiền thực tế đã chi tiêu của danh mục tương ứng. 8. Hiển thị thanh tiến trình trực quan ngân sách và thông báo thành công. Alternative flow 5.1. Hạn mức chi tiêu không hợp lệ 1. Hệ thống báo lỗi: “Số tiền giới hạn phải lớn hơn 0”. 2. Quay lại bước 3. - mobile  
5.13.2. Đặc tả chức năng Sửa ngân sách Sửa ngân sách Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý ngân sách và chọn một ngân sách. Hậu điều kiện Thông tin cấu hình hạn mức/ngân sách được cập nhật thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn ngân sách mong muốn trong danh sách, nhấn “Sửa”.  
2. Hiển thị form thông tin cũ của ngân sách.  
3. Điều chỉnh số tiền hạn mức hoặc danh mục áp dụng.  
  
4. Nhấn “Cập nhật”. 5. Kiểm tra tính hợp lệ của dữ liệu mới. 6. Ghi đè thông tin mới vào DB. 7. Tính toán lại tỷ lệ tiến trình đã chi tiêu và hiển thị thông báo thành công. Alternative flow - mobile

---

<!-- Trang 15 -->

5.13.3. Đặc tả chức năng Xóa ngân sách Xóa ngân sách Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý ngân sách và chọn một ngân sách. Hậu điều kiện Ngân sách bị xóa hoàn toàn khỏi DB và không hiển thị trên giao diện theo dõi.  
Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn ngân sách muốn xóa. 2. Nhấn nút “Xóa ngân sách”. 3. Hiển thị cảnh báo: “Bạn có chắc chắn muốn xóa ngân sách này?”. 4. Chọn “Xác nhận”. 5. Thực hiện xóa bản ghi ngân sách trong DB. 6. Tải lại danh sách ngân sách và hiển thị thông báo thành công. Alternative flow - mobile  
5.14. Đặc tả chức năng “Thiết lập Ngưỡng cảnh báo  
ngân
 
sách”
 
Thiết lập ngưỡng cảnh báo ngân sách Tiền điều kiện Người dùng đã đăng nhập và đã có ít nhất một ngân sách hoạt động. Hậu điều kiện Cấu hình các ngưỡng cảnh báo chi tiêu được lưu trữ thành công vào thông tin ngân sách. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn một ngân sách trong danh sách.

---

<!-- Trang 16 -->

2. Bấm chọn “Thiết lập cảnh báo”. 3. Hiển thị biểu mẫu cấu hình cảnh báo.  
4. Chọn hoặc nhập các mốc phần trăm muốn nhận cảnh báo chi tiêu (ví dụ: 80%, 90% ngân sách).  
5. Kiểm tra các con số phần trăm hợp lệ (lớn hơn 0%).  
6. Bấm nút “Lưu thiết lập”. 7. Cập nhật cấu hình ngưỡng cảnh báo cho ngân sách đó trong DB. 8. Hiển thị thông báo: “Thiết lập ngưỡng cảnh báo thành công”. Alternative flow - Mobile SQLite  
5.15. Đặc tả chức năng “Thiết lập Quy tắc phân bổ ngân  
sách”
 
Thiết lập Quy tắc phân bổ ngân sách Tiền điều kiện Người dùng đã đăng nhập và đang cấu hình kế hoạch tài chính. Hậu điều kiện Quy tắc chia dòng tiền thu nhập tự động được lưu trữ thành công vào hồ sơ người dùng. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn chức năng “Quy tắc phân bổ ngân sách”.  
2. Hiển thị giao diện thiết lập quy tắc phần trăm phân bổ dòng tiền (ví dụ: quy tắc 50/30/20). 3. Nhập tỷ lệ phần trăm phân bổ cho các nhóm quỹ ngân sách (Thiết yếu, Linh hoạt, Tích lũy).  
4. Kiểm tra tổng các tỷ lệ phần trăm phân bổ.  
  5. Xác nhận tổng tỷ lệ phần trăm phải bằng 100%. 6. Bấm “Áp dụng”. 7. Lưu quy tắc phân bổ ngân sách vào cơ sở dữ liệu. 8. Hiển thị thông báo: “Đã áp dụng quy tắc phân bổ ngân sách thành công”. Alternative flow

---

<!-- Trang 17 -->

5.1. Tổng tỷ lệ phần trăm không bằng 100% 1. Hệ thống hiển thị lỗi cảnh báo: “Tổng các tỷ lệ phải bằng 100%”. 2. Quay lại bước 3. - mobile  
5.16. Đặc tả chức năng “Xem danh sách giao dịch ngân  
sách”
 
Xem danh sách giao dịch ngân sách Tiền điều kiện Người dùng đã đăng nhập và có ngân sách đang hoạt động. Hậu điều kiện Hiển thị toàn bộ các giao dịch thực tế đã chi tiêu ảnh hưởng trực tiếp đến ngân sách đang xem. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Vào danh sách ngân sách, chọn ngân sách cần xem.  
2. Xác định các tham số của ngân sách (khoảng thời gian hiệu lực và các danh mục gắn liền). 3. Truy vấn DB tìm toàn bộ giao dịch chi tiêu thỏa mãn điều kiện lọc. 4. Hiển thị chi tiết ngân sách gồm: thanh tiến trình trực quan lượng chi tiêu thực tế, số dư ngân sách còn lại, và danh sách giao dịch chi tiết sắp xếp từ mới nhất đến cũ nhất. 5. Bấm vào một giao dịch cụ thể để xem chi tiết.  
6. Chuyển hướng đến màn hình thông tin chi tiết giao dịch. Alternative flow   
5.17. Đặc tả chức năng “ Thi ế t l ậ p hóa đ ơ n ”  
Phân rã chức năng:

---

<!-- Trang 18 -->

5.17.1. Đặc tả chức năng Thêm hóa đơn định kỳ Thêm hóa đơn định kỳ Tiền điều kiện Người dùng đã đăng nhập và đang ở phân hệ Hóa đơn & Đăng ký. Hậu điều kiện Lịch theo dõi và nhắc nhở hóa đơn định kỳ được tạo mới thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Bấm nút “Thêm hóa đơn định kỳ”. 2. Hiển thị form nhập thông tin (Tên dịch vụ, số tiền, ngày đến hạn thanh toán, chu kỳ: tháng/năm, ví thanh toán). 3. Nhập dữ liệu hóa đơn. 4. Nhấn “Lưu”. 5. Kiểm tra dữ liệu hợp lệ (số tiền > 0, ngày thanh toán hợp lệ). 6. Lưu thông tin hóa đơn vào DB. 7. Thiết lập tác vụ nhắc nhở tự động (Cron Job) trước ngày đến hạn 1-3 ngày.

---

<!-- Trang 19 -->

8. Hiển thị thông báo “Thiết lập hóa đơn thành công”.   
5.17.2. Đặc tả chức năng Sửa hóa đơn định kỳ Sửa hóa đơn Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Hóa đơn và chọn một hóa đơn.  
Hậu điều kiện Dữ liệu cấu hình của hóa đơn định kỳ được cập nhật thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn hóa đơn cần sửa. 2. Nhấn “Sửa hóa đơn”. 3. Hiển thị form chứa thông tin cũ của hóa đơn. 4. Thay đổi số tiền hoặc chu kỳ thanh toán.    
5. Nhấn “Cập nhật”. 6. Kiểm tra tính hợp lệ của thông tin sửa đổi. 7. Cập nhật lại thông tin hóa đơn trong DB.  
  8. Đồng bộ lại tác vụ tự động nhắc nhở (Cron Job) theo chu kỳ mới và báo thành công. Alternative flow   
5.17.3. Đặc tả chức năng Xóa hóa đơn định kỳ Xóa hóa đơn Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Hóa đơn & Đăng ký và chọn một hóa đơn. Hậu điều kiện Hóa đơn bị hủy và xóa khỏi DB, tắt các dịch vụ thông báo nhắc nhở liên quan. Actor chính Người dùng Actor phụ Không

---

<!-- Trang 20 -->

Basic flow Người dùng Hệ thống 1. Chọn hóa đơn trong danh sách. 2. Nhấn “Xóa hóa đơn”. 3. Hiển thị thông báo xác nhận hủy theo dõi hóa đơn định kỳ. 4. Chọn “Đồng ý xóa”. 5. Hủy tác vụ nhắc nhở (Cron Job) khỏi scheduler. 6. Thực hiện xóa bản ghi hóa đơn trong DB. 7. Làm mới danh sách và báo xóa thành công. Alternative flow   
5.18. Đặc tả chức năng “ Xem danh sách giao d ị ch hóa  
đ
ơ
n
”
 
Xem danh sách giao dịch hóa đơn Tiền điều kiện Người dùng đã đăng nhập và có lịch sử các hóa đơn đã thanh toán. Hậu điều kiện Hiển thị chính xác toàn bộ lịch sử giao dịch thanh toán của hóa đơn định kỳ đó.  
Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Truy cập chi tiết một hóa đơn định kỳ trong danh sách.  
2. Lấy thông tin định danh của hóa đơn (billId). 3. Truy vấn DB để lấy toàn bộ danh sách giao dịch thanh toán (giao dịch chi) được gắn với ID hóa đơn này. 4. Hiển thị danh sách lịch sử thanh toán theo thời gian gồm: Ngày thanh toán, số tiền, ví thanh toán nguồn và trạng thái.  
Alternative flow

---

<!-- Trang 21 -->

5.19. Đặc tả chức năng “ Thi ế t l ậ p m ụ c tiêu ti ế t ki ệ m ”  
Phân rã chức năng:  
 
5.17.1. Đặc tả chức năng “ Thêm mục tiêu tiết kiệm” Thêm mục tiêu tiết kiệm Tiền điều kiện Người dùng đã đăng nhập và đang ở phân hệ Mục tiêu tiết kiệm. Hậu điều kiện Một mục tiêu tài chính mới được lập thành công trong DB với số tiền tích lũy ban đầu = 0. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Bấm nút “Tạo mục tiêu mới”. 2. Hiển thị form nhập thông tin (Tên mục tiêu, Số tiền cần đạt, Ngày đến hạn - deadline, chọn ví tích lũy liên kết). 3. Điền dữ liệu. 4. Bấm nút “Lưu”. 5. Kiểm tra dữ liệu hợp lệ (ngày đến hạn lớn hơn ngày hiện tại, số tiền > 0). 6. Lưu thông tin mục tiêu tiết kiệm mới vào DB (số tiền đã tích lũy hiện tại ban đầu = 0).

---

<!-- Trang 22 -->

7. Hiển thị thông báo “Tạo mục tiêu tiết kiệm thành công”. Alternative flow   
5.17.2. Đặc tả chức năng “ Sửa mục tiêu tiết kiệm” Sửa mục tiêu tiết kiệm Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Mục tiêu tiết kiệm và chọn một mục tiêu. Hậu điều kiện Các thông số (hạn định, số tiền cần đạt) của mục tiêu được cập nhật thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn mục tiêu tiết kiệm cần sửa. 2. Nhấn “Sửa mục tiêu”. 3. Hiển thị form cấu hình chứa thông tin cũ.  
4. Cập nhật số tiền cần đạt hoặc ngày đến hạn mới.  
  
5. Nhấn “Cập nhật”. 6. Kiểm tra tính hợp lệ của dữ liệu sửa đổi.  
  7. Ghi đè thông tin mới vào DB. 8. Tính toán lại tiến trình và dự báo ngày hoàn thành theo thông số mới, báo thành công. Alternative flow   
5.17.3. Đặc tả chức năng “ Xóa mục tiêu tiết kiệm” Xóa mục tiêu tiết kiệm Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Mục tiêu tiết kiệm và chọn một mục tiêu. Hậu điều kiện Mục tiêu tiết kiệm bị xóa khỏi DB, giải phóng ví tích lũy liên kết. Actor chính Người dùng

---

<!-- Trang 23 -->

Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn mục tiêu muốn xóa. 2. Nhấn nút “Xóa mục tiêu”. 3. Hiển thị hộp thoại cảnh báo: “Bạn có chắc chắn muốn xóa mục tiêu này?”. 4. Chọn “Đồng ý xóa”. 5. Thực hiện xóa bản ghi mục tiêu trong DB. 6. Cập nhật danh sách mục tiêu hiển thị và báo thành công. Alternative flow   
5.20. Đặc tả chức năng “ T ự đ ộ ng t ạ o giao d ị ch ti ế t  
ki
ệ
m
”
 
Tự động tạo giao dịch tiết kiệm (schedule) Tiền điều kiện Người dùng đã tạo mục tiêu tiết kiệm và liên kết ví nguồn trích tiền. Hậu điều kiện Lịch tự động chuyển tiền định kỳ được đăng ký thành công vào hệ thống. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn một mục tiêu tiết kiệm.    
2. Bấm chọn “Lập lịch tiết kiệm tự động”.   
3. Hiển thị màn hình cấu hình lịch chuyển tiền tự động. 4. Nhập số tiền trích, chọn chu kỳ (Hàng tuần/Hàng tháng) và ngày cố định thực hiện, chọn ví nguồn trích tiền.  
5. Kiểm tra tính hợp lệ của cấu hình chu kỳ và số dư ví nguồn.  
6. Bấm “Kích hoạt lịch tự động”. 7. Lưu cấu hình lịch trích tiền vào DB. 8. Đăng ký một công việc định kỳ (Cron Job) trên Server để tự động thực hiện giao dịch chuyển khoản vào ngày cấu hình.

---

<!-- Trang 24 -->

9. Hiển thị thông báo: “Thiết lập lịch tự động thành công”. Alternative flow   
5.21. Đặc tả chức năng “ D ự đoán th ờ i gian hoàn thành  
m
ụ
c
 
tiêu
”
 
Dự đoán thời gian hoàn thành mục tiêu Tiền điều kiện Người dùng có mục tiêu tiết kiệm đang hoạt động và có lịch sử nạp tiền tiết kiệm thực tế. Hậu điều kiện Hệ thống hiển thị ngày dự kiến hoàn thành mục tiêu tài chính dựa trên dữ liệu tích lũy thực tế. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Truy cập màn hình xem chi tiết của một mục tiêu tiết kiệm đang theo dõi.  
2. Kiểm tra số tiền mục tiêu cần đạt và số tiền đã tích lũy thực tế trong ví liên kết.  
  3. Truy xuất lịch sử các giao dịch nạp tiền tích lũy của mục tiêu này trong 3 tháng gần nhất để tính toán tốc độ tiết kiệm trung bình ngày (X đồng/ngày). 4. Tính toán số ngày cần thiết còn lại để hoàn thành mục tiêu. 5. Cộng số ngày còn lại đó vào ngày hiện tại để tính ra ngày dự kiến hoàn thành thực tế. 6. Hiển thị ngày hoàn thành dự đoán lên giao diện chi tiết mục tiêu. Alternative flow   
5.22. Đặc tả chức năng “ Thi ế t l ậ p danh m ụ c ”  
Phân rã chức năng:

---

<!-- Trang 25 -->

5.22.1. Đặc tả chức năng Thêm danh mục Thêm danh mục Tiền điều kiện Người dùng đã đăng nhập và đang ở màn hình Quản lý danh mục. Hậu điều kiện Danh mục thu/chi tự tạo mới được lưu thành công vào DB của người dùng. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn chức năng “Tạo danh mục mới”. 2. Hiển thị form nhập thông tin (Tên danh mục, chọn loại: Thu nhập/Chi tiêu, chọn biểu tượng và màu sắc). 3. Nhập dữ liệu danh mục. 4. Bấm “Lưu”. 5. Kiểm tra dữ liệu đầu vào không được trống. 6. Lưu bản ghi danh mục mới liên kết với tài khoản người dùng vào DB.

---

<!-- Trang 26 -->

7. Cập nhật hiển thị danh mục trong màn hình Ghi chép giao dịch và báo thành công.  
Alternative flow   
5.22.2. Đặc tả chức năng Sửa danh mục Sửa danh mục Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý danh mục và chọn một danh mục tự tạo. Hậu điều kiện Các thay đổi về thuộc tính (tên, màu sắc, biểu tượng) được cập nhật thành công vào DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn danh mục cần sửa. 2. Nhấn “Sửa danh mục”. 3. Hiển thị form chứa thông tin cũ. 4. Thay đổi tên hoặc biểu tượng hiển thị.    
5. Nhấn “Cập nhật”. 6. Kiểm tra tính hợp lệ của dữ liệu. 7. Ghi đè dữ liệu mới vào DB. 8. Đồng bộ làm mới lại hiển thị các giao dịch cũ đang dùng danh mục này và báo thành công. Alternative flow   
5.22.3. Đặc tả chức năng Xóa danh mục Xóa danh mục Tiền điều kiện Người dùng đã đăng nhập, đang ở màn hình Quản lý danh mục và chọn một danh mục tự tạo. Hậu điều kiện Danh mục bị ẩn đi (Soft Delete) trong DB để tránh phá vỡ liên kết với giao dịch cũ.  
Actor chính Người dùng

---

<!-- Trang 27 -->

Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn danh mục cần xóa. 2. Nhấn “Xóa danh mục”. 3. Hiển thị cảnh báo: “Giao dịch cũ dùng danh mục này vẫn sẽ được giữ lại. Bạn đồng ý xóa?”. 3. Chọn “Xác nhận”. 4. Thực hiện chuyển trạng thái danh mục thành ẩn (Soft Delete) trong DB. 5. Làm mới danh sách danh mục và báo thành công. Alternative flow   
5.23. Đặc tả chức năng “ Phân lo ạ i danh m ụ c ”  
Phân loại danh mục giao dịch Tiền điều kiện Người dùng đang thực hiện ghi chép giao dịch mới hoặc cập nhật giao dịch thô tự động. Hậu điều kiện Giao dịch được gán vào một danh mục cụ thể nhằm phục vụ cho phân tích báo cáo chi tiêu. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Tại giao diện nhập/sửa giao dịch, bấm vào ô “Chọn danh mục”.  
2. Xác định loại giao dịch hiện tại (Thu nhập hay Chi tiêu). 3. Truy vấn DB lấy toàn bộ danh mục tương ứng với loại giao dịch đó (gồm danh mục mặc định hệ thống và danh mục tự tạo). 4. Hiển thị danh sách danh mục lựa chọn.  
5. Bấm chọn một danh mục (ví dụ: Ăn uống) và lưu giao dịch.  
6. Gán mã ID danh mục cho giao dịch hiện tại và lưu vào DB.

---

<!-- Trang 28 -->

7. Đồng bộ cập nhật lại hạn mức ngân sách của danh mục đó (nếu có thiết lập ngân sách) và báo thành công. Alternative flow   
5.24. Đặc tả chức năng “ Gom nhóm danh m ụ c ”  
Gom nhóm danh mục Tiền điều kiện Người dùng đã đăng nhập và đang quản lý cấu trúc các danh mục thu chi. Hậu điều kiện Tạo liên kết mối quan hệ cha-con giữa các danh mục thành công trong DB. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Bấm nút “Tạo nhóm danh mục mới” (Tạo danh mục cha).  
2. Hiển thị form nhập tên nhóm lớn.  
3. Nhập tên nhóm (ví dụ: “Chi tiêu sinh hoạt”) và chọn các danh mục con hiện có muốn gộp vào nhóm này (ví dụ: “Tiền điện”, “Tiền nước”).  
4. Kiểm tra các danh mục con được chọn không trùng lặp và đang ở trạng thái hoạt động.  
5. Bấm “Lưu nhóm”. 6. Cập nhật thuộc tính liên kết parent_id của các danh mục con bằng ID của danh mục cha vừa tạo trong DB. 7. Làm mới giao diện hiển thị cây phân cấp danh mục và thông báo thành công.  
Alternative flow   
5.25. Đặc tả chức năng “ Thi ế t l ậ p t ừ khóa nh ậ n di ệ n  
danh
 
m
ụ
c
”
 
Thiết lập từ khóa nhận diện danh mục Tiền điều kiện Người dùng đã đăng nhập và quản lý danh sách danh mục.

---

<!-- Trang 29 -->

Hậu điều kiện Các từ khóa nhận diện (Keywords) được lưu trữ thành công để AI sử dụng tự động phân loại thô từ SMS/OCR. Actor chính Người dùng Actor phụ Không Basic flow Người dùng Hệ thống 1. Chọn danh mục cần thiết lập (ví dụ: “Ăn uống”).  
  
2. Bấm nút “Thiết lập từ khóa nhận diện”. 3. Hiển thị danh sách từ khóa hiện có của danh mục đó (nếu có). 4. Nhập từ khóa nhận diện mới (ví dụ: “Highlands Coffee”, “Phuc Long”, “GrabFood”) và bấm “Lưu”.  
5. Kiểm tra các từ khóa mới không trùng với các từ khóa đã cấu hình ở các danh mục khác của người dùng đó.  
  6. Lưu danh sách từ khóa nhận diện liên kết với danh mục tương ứng vào DB.  
  7. Đồng bộ tập luật từ khóa cho worker AI phân loại thô và báo thành công. Alternative flow 4.1. Từ khóa trùng lặp với danh mục khác 1. Hệ thống hiển thị thông báo: “Từ khóa này đã được sử dụng cho danh mục [Tên danh mục khác]”. 2. Quay lại bước 3.   
5.26. Đặc tả chức năng “ Qu ả n lý danh m ụ c m ặ c đ ị nh ”  
Quản lý danh mục mặc định Tiền điều kiện Admin đăng nhập thành công và truy cập trang cấu hình của hệ thống. Hậu điều kiện Thay đổi hoặc bổ sung danh mục mẫu mặc định áp dụng cho tất cả tài khoản mới đăng ký. Actor chính Admin Actor phụ Không Basic flow Admin Hệ thống

---

<!-- Trang 30 -->

1. Chọn chức năng “Quản lý danh mục mặc định”.s  
2. Hiển thị danh sách danh mục mẫu mặc định hiện tại của hệ thống. 3. Thực hiện thêm mới hoặc sửa đổi tên/biểu tượng/màu sắc của danh mục mẫu.  
4. Kiểm tra dữ liệu đầu vào hợp lệ.  
5. Bấm “Lưu và đồng bộ”. 6. Cập nhật bảng mẫu danh mục hệ thống trong DB. 7. Đảm bảo toàn bộ tài khoản đăng ký mới sau thời điểm này sẽ được khởi tạo kèm bộ danh mục mặc định vừa cập nhật.  
Alternative flow   
5.27. Đặc tả chức năng “ Thu th ậ p d ữ li ệ u t ừ thông báo  
SMS
”
 
Thu th ậ p d ữ li ệ u t ừ thông báo SMS  
Tiền điều kiện - Người dùng đã đăng nhập thành công  
Hậu điều kiện - Một bản ghi Transaction mới được tạo trong hệ thống và được lưu vào CSDL với trạng thái “Pending” - Sự kiện data_collection.created_transaction được phát sinh Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
 
1, Nhận tin nhắn biến động số dư SMS   
 2, Kiểm tra quyền READ_SMS (Android)  
 
3, Xác định ngân hàng   
 4, Parse nội dung SMS & tạo bản ghi giao dịch   
5, Phát sinh sự kiện data_collection.read

---

<!-- Trang 31 -->

6, Kích hoạt chức năng kiểm tra trùng lặp dữ liệu    
7, Kiểm tra internet & Kích hoạt chức năng Phân loại giao dịch    
8, Tạo giao dịch với trạng thái “Pending”  
 
9, Phát sự kiện data_collection.create_transaction (gọi tới chức năng Tạo giao dịch tự động từ ORC và SMS) Alternative flow  
2.1. Người dùng chưa cấp quyền đọc tin nhắn 1. Hướng dẫn người dùng cấp quyền đọc tin nhắn 2. Người dùng cấp quyền đọc tin nhắn 3. Quay lại bước 3 2.2. Người dùng từ chối cấp quyền đọc tin nhắn 1. Kết thúc 3.1. Không xác định được ngân hàng 1. Thông báo ngân hàng không xác định, kèm nút xác nhận & thử lại 2. Nếu người dùng nhấn xác nhận thì kết thúc; Nếu người dùng nhấn thử lại thì quay lại bước 2 4.1. Parse dữ liệu thất bại 1. Thông báo đọc dữ liệu không thành công, kèm nút xác nhận & thử lại 2. Nếu người dùng nhấn xác nhận thì kết thúc; Nếu người dùng nhấn thử lại thì quay lại bước 2 6.1. Dữ liệu trùng lặp 1. Ghi log dữ liệu và thông báo trùng lặp dữ liệu 2. Kết thúc 7.1. Có internet 1. Kích hoạt chức năng AI phân loại giao dịch 2. Quay lại bước 8

---

<!-- Trang 32 -->

5.28. Đặc tả chức năng “Thu thập dữ liệu từ hình  
ảnh
 
ORC
”
 Thu th ậ p d ữ li ệ u t ừ hình ả nh ORC  
Tiền điều kiện - Người dùng đã đăng nhập thành công  
Hậu điều kiện - Một bản ghi Transaction mới được tạo trong hệ thống và được lưu vào CSDL với trạng thái “Pending” - Sự kiện data_collection.created_transaction được phát sinh Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn chức năng quét hình ảnh  
2, Hệ thống kiểm tra quyền truy cập máy ảnh và thư viện  
 
3, Hệ thống chuyển tới giao diện chụp hình 4, Người dùng chụp hình hóa đơn giao dịch  
5, Hệ thống xử lý ảnh  
 6, Sử dụng ORC để nhận dạng văn bản & tạo bản ghi giao dịch   
7, phát sự kiện data_collection.read    
8, Kích hoạt chức năng kiểm tra trùng lặp dữ liệu   
9, Kiểm tra internet & kích hoạt chức năng Phân loại giao dịch   
10, Tạo giao dịch với trạng thái Pending  
 
11, phát sự kiện data_collection.create_transaction (gọi tới chức năng Tạo giao dịch tự động từ ORC và SMS) Alternative flow  
2.1. Người dùng chưa cấp quyền truy cập máy ảnh và thư viện 4. Hướng dẫn người dùng cấp quyền 5. Người dùng cấp quyền 6. Quay lại bước 3

---

<!-- Trang 33 -->

2.2. Người dùng từ chối cấp quyền truy cập 2. Kết thúc 4.1. Người dùng chọn hình ảnh từ thư viện 1. Quay lại bước 5 5.1 Hệ thống xử lý ảnh thất bại 1. Thông báo ảnh không thể xử lý 2. Người dùng xác nhận 3. Quay lại bước 3 6.1 Hệ thống không trích xuất được văn bản (text = 0) 1. Thông báo không thể trích xuất văn bản từ hình ảnh 2. Người dùng xác nhận 3. Quay lại bước 3 8.1. Dữ liệu trùng lặp 3. Ghi log dữ liệu và thông báo trùng lặp dữ liệu 4. Kết thúc 9.1. Có internet 3. Kích hoạt chức năng AI phân loại giao dịch 4. Quay lại bước 10   
5.29. Đặc tả chức năng “Khử trùng lặp dữ liệu” Kh ử trùng l ặ p d ữ li ệ u  
Tiền điều kiện - Người dùng đã đăng nhập thành công (iduser) - Dữ liệu giao dịch đã được parse (từ ORC & SMS)  
Hậu điều kiện - Trả về kết quả là  
DUPLICATE
 hoặc  
UNIQUE Actor chính Hệ thống Actor phụ Không Basic flow  
System  
1, Dữ liệu được gửi đến & kích hoạt yêu cầu kiểm tra trùng lặp

---

<!-- Trang 34 -->

2, Xác định các điều kiện liên quan (Khoảng thời gian áp dụng, Loại giao dịch, iduser)  
3, Truy vấn CSDL & Kiểm tra tham chiếu (mã giao dịch nếu có)  
4, Check theo nhiều tiêu chí (Ngân hàng + số tiền + ngày giao dịch + ghi chú)  
5, Ghi log kết quả phiên kiểm tra  
6, Trả về UNIQUE  
7, Phát sự kiện duplicate.checked  
Alternative flow  
3.1. Mã tham chiếu trùng khớp 1. Ghi log kết quả phiên kiểm tra 2. Trả về  
DUPLICATE
   4.1. Các tiêu chí kiểm tra khớp hoàn toàn 1. Ghi log kết quả phiên kiểm tra 2. Trả về  
DUPLICATE
   
5.30. Đặc tả chức năng “ Thi ế t l ậ p giao d ị ch” Phân rã ch ứ c năng: Thêm giao d ị ch, Xóa giao d ị ch, S ử a giao d ị ch
   5.30.1. Đặc tả chức năng Thêm giao dịch  
Thêm giao d ị ch

---

<!-- Trang 35 -->

Tiền điều kiện - Người dùng đã đăng nhập - Có ít nhất 1 Ví  
Hậu điều kiện - Giao dịch được tạo & lưu vào SQLite - Dữ liệu được đánh dấu để đồng bộ lên server - Phát sự kiện transaction.created Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn nút thêm giao dịch 2, Hệ thống hiển thị giao diện giao dịch  
3, Người dùng chọn ví được giao dịch hoặc ví mặc định có trạng thái là đang hoạt động  
 
4, Người dùng nhập số tiền giao dịch   
5, Người dùng chọn danh mục giao dịch   
6, Người dùng chọn thời gian giao dịch <= thời gian giao dịch hiện tại (mặc định là ngày hiện tại)  
 
7, Người dùng nhập ghi chú giao dịch   
8, Người dùng nhấn nút tạo giao dịch 9, Hệ thống kiểm tra tính hợp lệ của dữ liệu 10, Lưu giao dịch vào Table Transactions và đánh dấu dữ liệu để đồng bộ 11, Hệ thống cập nhật số dư ví dùng để giao dịch. Hệ thống cập nhật ngân sách nếu khớp danh mục và thời gian. Hệ thống cập nhật hóa đơn nếu khớp danh mục và thời gian. Hệ thống cập nhật mục tiêu tiết kiệm nếu khớp danh mục và thời gian. 12, Phát sự kiện transaction.created  
Alternative flow

---

<!-- Trang 36 -->

9.1. Người dùng nhập số tiền giao dịch <= 0 1. Hiển thị thông báo vui lòng nhập số tiền giao dịch 2. Quay lại bước 4 9.2. Người dùng không chọn danh mục giao dịch 1. Hiển thị thông báo vui lòng chọn danh mục giao dịch 2. Quay lại bước 5   
5.30.2. Đặc tả chức năng Sửa giao dịch S ử a giao d ị ch  
Tiền điều kiện - Người dùng đã đăng nhập - Giao dịch đã được tạo  
Hậu điều kiện - Giao dịch được sửa & cập nhật vào SQLite - Dữ liệu mới được đánh dấu để đồng bộ lên Server - Phát sự kiện transaction.updated Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn nút Sửa giao dịch 2, Hệ thống hiển thị giao diện giao dịch với dữ liệu giao dịch đã chọn 3, Người dùng sửa nội dung giao dịch   
4, Người dùng nhấn nút cập nhật 5, Hệ thống kiểm tra dữ liệu hợp lệ  
 6, Khôi phục số dư ví, ngân sách, hóa đơn, tiết kiệm (nếu có) 7, Cập nhật thông tin giao dịch & đánh dấu dữ liệu mới để đồng bộ 8, Hệ thống cập nhật số dư ví dùng để giao dịch. Hệ thống cập nhật ngân sách nếu khớp danh mục và thời gian. Hệ thống cập nhật hóa đơn nếu khớp danh mục và thời gian. Hệ thống cập nhật mục tiêu tiết kiệm nếu khớp danh mục và thời gian.

---

<!-- Trang 37 -->

9, Phát sự kiện transaction.updated 
Alternative flow  
5.1. Người dùng nhập số tiền giao dịch <= 0 3. Hiển thị thông báo vui lòng nhập số tiền giao dịch 4. Quay lại bước 4  
 
5.30.3. Đặc tả chức năng Xóa giao dịch Xóa giao d ị ch  
Tiền điều kiện - Người dùng đã đăng nhập - Giao dịch đã được tạo  
Hậu điều kiện - Trạng thái giao dịch trong SQLite được thay đổi - Dữ liệu mới được đánh dấu để đồng bộ lên Server - Phát sự kiện transaction.deleted Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn xóa giao dịch 2, Hệ thống hiển thị thông báo xác nhận xóa giao dịch 3, Người dùng xác nhận xóa giao dịch 4, Hệ thống Hoàn tác ảnh hưởng do giao dịch liên quan đến Ví, ngân sách, hóa đơn, tiết kiệm. 5, Cập nhật trạng thái giao dịch “Deleted”  
 6, Phát sự kiện transaction.deleted 
Alternative flow  
 
 
5.31. Đặc tả chức năng “Xem danh sách giao dịch” Xem danh sách giao d ị ch

---

<!-- Trang 38 -->

Tiền điều kiện - Người dùng đã đăng nhập  
Hậu điều kiện - Người dùng xem được danh sách giao dịch - Người dùng có thể lọc giao dịch theo tiêu chí mong muốn Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn lịch sử giao dịch 2, Hệ thống hiển thị toàn bộ giao dịch  
Alternative flow  
 
 
5.32. Đặc tả chức năng “Tạo giao dịch tự động từ SMS,  
ORC”
 T ạ o giao d ị ch t ự đ ộ ng t ừ SMS, ORC  
Tiền điều kiện - Sự kiện  
data_collection.created_transaction
 được phát - idtran được truyền tới chức năng T ạ o giao d ị ch t ự đ ộ ng Hậu điều kiện - Giao dịch được tạo thành công với trạng thái “Complete” - Sự kiện transaction.created được phát Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
 1, Lấy giao dịch pending từ SQLite thông qua idtran 2, Hiển thị nội dung giao dịch lên màn hình  
3, Người dùng xác nhận giao dịch 4, Hệ thống cập nhật trạng thái giao dịch thành “CONFIRM” 5, Hệ thống cập nhật số dư ví dùng để giao dịch.

---

<!-- Trang 39 -->

Hệ thống cập nhật ngân sách nếu khớp danh mục và thời gian. Hệ thống cập nhật hóa đơn nếu khớp danh mục và thời gian. Hệ thống cập nhật mục tiêu tiết kiệm nếu khớp danh mục và thời gian. 6, Hệ thống cập nhật trạng thái giao dịch thành “COMPLETE” 7, Phát sự kiện transaction.created  
Alternative flow  
3.1. Người dùng từ chối tạo giao dịch 1. Hệ thống cập nhật trạng thái giao dịch thành “rejected” 2. Phát sự kiện transaction.rejected  
5.33. Đặc tả chức năng “Phân loại giao dịch”   
5.34. Đặc tả chức năng “Thống kê thu chi theo biểu đồ” Th ố ng kê thu chi theo bi ể u đ ồ  
Tiền điều kiện - Người dùng đã đăng nhập  
Hậu điều kiện - Hệ thống hiển thị thống kê thu chi theo nhiều loại biểu đồ  
Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn chức năng thống kê thu chi  
2, Hệ thống hiển thị các biểu đồ thống kê - Tổng quan thu chi theo thời gian → Grouped Bar Chart - Xu hướng thu/chi → Line Chart - Phân bổ thu chi theo danh mục → Pie Chart - Tiến độ ngân sách → Progress Bar - Dòng tiền tích lũy → Vertical Progress Bar

---

<!-- Trang 40 -->

Và hiển thị dữ liệu liên quan tới từng loại biểu đồ Alternative flow  
2.1. Không có dữ liệu 1. Hiển thị thông báo bổ sung dữ liệu   
5.35. Đặc tả chức năng “So sánh thu chi” So sánh thu chi  
Tiền điều kiện - Người dùng đã đăng nhập  
Hậu điều kiện - Hệ thống hiển thị thông tin so sánh thu chi  
Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn chức năng so sánh thu chi  
2, Hệ thống hiển thị dữ liệu so sánh thu chi - So sánh tổng quan thu chi → Grouped Bar Chart - So sánh theo danh mục → Grouped Bar Chart - % Thay đổi theo danh mục → Bar Chart Alternative flow  
2.1. Không có dữ liệu 2. Hiển thị thông báo bổ sung dữ liệu   
5.36. Đặc tả chức năng “Phân tích xu hướng dòng tiền” So sánh thu chi  
Tiền điều kiện - Người dùng đã đăng nhập  
Hậu điều kiện - Hệ thống xác định xu hướng dòng tiền - Dự báo chi tiêu trong 3 tháng tới - Các điểm xu hướng bất thường được đánh dấu Actor chính Người dùng

---

<!-- Trang 41 -->

Actor phụ Không Basic flow  
Người dùng System  
1, Người dùng chọn phân tích xu hướng dòng tiền  
2, Hiển thị giao diện chọn tham số 3, Chọn tham số (thời gian, loại (thu chi all), dự báo)   
4, Truy vấn dữ liệu giao dịch  
 5, Xác định xu hướng  
 6, Dự báo  
 7, Xác định bất thường   
Alternative flow  
 
 
5.37. Đặc tả chức năng “Xuất báo cáo thu chi” Xu ấ t báo cáo thu chi  
Tiền điều kiện - Người dùng đã đăng nhập  
Hậu điều kiện - Hệ thống xác định xu hướng dòng tiền - Dự báo chi tiêu trong 3 tháng tới - Các điểm xu hướng bất thường được đánh dấu - sự kiện được phát Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Truy cập chức năng xuất báo cáo  
2, Hiển thị giao diện xuất báo cáo  
3, Chọn loại báo cáo   
4, Chọn tham số báo cáo (Ngày, loại giao dịch, danh mục, ví)

---

<!-- Trang 42 -->

5, Chọn định dạng xuất (pdf, excel)   
6, Chọn vị trí lưu   
7, Chọn xuất báo cáo 8, Truy vấn dữ liệu, lọc giao dịch theo tham số & tổng hợp dữ liệu 9, Tạo file - Định dạng dữ liệu theo loại báo cáo - Tạo file tương ứng 10, Lưu file vào vị trí đã chọn  
 11, Phát sự kiện report.generated Alternative flow  
 
 
5.38. Đặc tả chức năng “Chatbot AI” Chatbot AI  
Tiền điều kiện - Người dùng đã đăng nhập - Có internet Hậu điều kiện - Người dùng nhận được câu hỏi cho câu trả lời của mình  
Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Mở chatbot 2, khởi tạo chatbot  
3, Người dùng nhập câu hỏi (text) hoặc chọn các câu hỏi gợi ý có trước và gửi đi  
4, Chatbot nhận và lưu trữ câu hỏi  
 5, Phân tích câu hỏi và đưa ra câu trả lời  
 6, Phản hồi lại cho người dùng  
Alternative flow  
4.1. Mất internet đột ngột 1. Phát sinh sự kiện AI.nointernet 2. Chatbot gửi lại tin nhắn lỗi “mất kết nối”

---

<!-- Trang 43 -->

3. Kết thúc 5.1. Mất internet đột ngột 1. Phát sinh sự kiện AI.nointernet 2. Chatbot gửi lại tin nhắn lỗi “mất kết nối” 3. Kết thúc  
 5.39. Đặc tả chức năng “AI phân loại giao dịch” AI phân lo ạ i giao d ị ch  
Tiền điều kiện - Người dùng đã đăng nhập - Có internet - Sự kiện duplicate.checked được kích hoạt với trạng thái UNIQUE Hậu điều kiện - Giao dịch được phân loại - Sự kiện AI.Classified được phát đi Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
 1, Hệ thống nhận sự kiện và dữ liệu giao dịch được tạo qua “idtran” với trạng thái là Pending 2, Dữ liệu giao dịch và dữ liệu keyword nhận diện giao dịch được đẩy lên cho AI phân tích và phân loại giao dịch 3, Trả dữ liệu về và phát sinh sự kiện AI.Classified Alternative flow  
2.1. Mất internet trong quá trình phân loại 1. Sự kiện AI.nointenetclassify được phát 2. Gọi tới chức năng Phân loại giao dịch

---

<!-- Trang 44 -->

5.40. Đặc tả chức năng “AI dự đoán thời gian hoàn  
thành
 
Goal”
 AI d ự đoán th ờ i gian hoàn thành goal  
Tiền điều kiện - Người dùng đã đăng nhập - Có internet - Có ít nhất 1 thiết lập khoản tiết kiệm Hậu điều kiện - AI đưa ra thời gian hoàn thành goal dự kiến  
Actor chính Người dùng Actor phụ Không Basic flow  
Người dùng System  
1, Truy cập trang tiết kiệm 2, Kiểm tra có internet  
 3, Với mỗi box goal, truy vấn SQLite lấy dữ liệu goal, danh sách dữ liệu giao dịch 4, Xây dựng prompt và dự đoán từ AI  
 5, Hiển thị kết quả ngắn  
6, Người dùng chọn vào kết quả ngắn 7, Hiển thị box kết quả dự đoán chi tiết  
Alternative flow  
2.1. Kiểm tra không có internet 1. Gọi chức năng “dự đoán thời gian hoàn thành goal”   
5.41. Đặc tả chức năng “AI phân tích hành vi chi tiêu” 5.42. Đặc tả chức năng “AI dự báo chi tiêu” 5.43. Đặc tả chức năng “AI đưa ra lời khuyên tài chính”
