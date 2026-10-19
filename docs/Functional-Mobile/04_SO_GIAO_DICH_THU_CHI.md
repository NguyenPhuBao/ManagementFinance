# 📖 PHÂN HỆ 04: SỔ GIAO DỊCH THU / CHI / VAY NỢ (TRANSACTION MANAGEMENT)

> **Mã phân hệ:** `TX`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/transaction`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction)  
> **Quản lý trạng thái:** `TransactionBloc`  
> **Cơ sở dữ liệu:** SQLite bảng `transactions` (Đồng bộ 2 chiều qua Entity `transaction`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/transactions` | [`transaction_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction/presentation/pages/transaction_page.dart) | Sổ giao dịch tổng thể | Thanh thống kê Thu/Chi/Ròng; Gom nhóm theo ngày; Lọc theo Ví/Thời gian; Tìm kiếm |
| `/add` | [`add_transaction_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart) | Tạo mới & Chỉnh sửa giao dịch | 3 Tab: Chi tiền / Thu tiền / Chuyển khoản; Bàn phím số tính toán; Chọn Ví & Danh mục; Ghi chú; Gắn ảnh biên lai |
| `/add/category` | [`choose_category_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction/presentation/pages/choose_category_page.dart) | Chọn danh mục giao dịch | Lưới icon danh mục trực quan; Phân loại Thu/Chi; Thanh tìm kiếm nhanh danh mục |
| `/transactions/gan-danh-muc` | [`gan_danh_muc_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/gan_danh_muc_page.dart) | Gắn danh mục nhanh (C1) | Danh sách giao dịch chưa có danh mục; Thẻ gắn nhanh 1 chạm; Gợi ý danh mục tự động |
| `/quet` | [`quet_anh_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction/presentation/pages/quet_anh_page.dart) | Quét hóa đơn OCR tự động | Màn hình xem trước ảnh; Quét bóc tách số tiền; Trích xuất ngày giờ & Tên hóa đơn; Chuyển tiếp vào Form |

---

## 2. QUY TRÌNH THÊM MỚI GIAO DỊCH ĐA PHƯƠNG THỨC

FlowMoney hỗ trợ **4 phương thức nhập liệu giao dịch linh hoạt**, từ thủ công đến tự động hóa thông minh:

### 2.1. Phương thức 1: Nhập tay truyền thống (Manual Form)
- **Chọn Chiều giao dịch:**
  - **Chi tiền (-):** Tiêu dùng hàng ngày (Ăn uống, Di chuyển, Mua sắm...).
  - **Thu tiền (+):** Tiền vào (Lương, Thưởng, Bán đồ, Lãi đầu tư...).
  - **Chuyển tiền ($\leftrightarrow$):** Rút tiền ATM, nạp tiền ví điện tử, chuyển giữa các ngân hàng cá nhân.
- **Bàn phím máy tính bỏ túi tích hợp:** Cho phép cộng trừ trực tiếp trên ô số tiền (ví dụ: `25000 + 30000 = 55000 ₫`) kèm phím tắt `000` tiện lợi.
- **Chọn Ví & Danh mục:** Tự động lọc danh mục phù hợp theo chiều Thu hoặc Chi.
- **Đính kèm hóa đơn:** Lưu ảnh chụp hóa đơn vào bộ nhớ cục bộ để đối chiếu sau này.

### 2.2. Phương thức 2: Nhập liệu bằng Giọng nói On-Device (Voice Input - Whisper)
- Khi bấm nút Micro tại Trang chủ hoặc truy cập `/add?noi=1`:
- Ứng dụng tự động kích hoạt bộ thu âm nhận diện giọng nói tiếng Việt chạy trực tiếp trên máy (On-Device Inference).
- **Trích xuất thông minh:**
  - Câu nói: *"Ăn trưa cơm tấm bốn mươi lăm nghìn tiền mặt"*
  - Hệ thống tự động phân tích:
    - Số tiền: `45,000 ₫`
    - Chiều: `Chi tiền`
    - Danh mục: `Ăn uống` (dựa trên từ khóa "ăn trưa", "cơm tấm")
    - Ví: `Tiền mặt`
    - Ghi chú: *"Ăn trưa cơm tấm"*
- Người dùng chỉ cần liếc nhìn màn hình đã điền sẵn và bấm "Lưu" (chỉ mất 3 giây).

### 2.3. Phương thức 3: Quét ảnh hóa đơn thông minh (OCR Scan Bill)
- Bấm icon Camera $\rightarrow$ Chụp biên lai hoặc chọn ảnh từ bộ sưu tập.
- Màn hình `/quet` chạy thuật toán nhận diện chữ OCR On-Device (Google MLKit Text Recognition):
  - Tự động tìm kiếm dòng chứa từ khóa tổng tiền (`Tổng cộng`, `Total`, `Payment Amount`, `Thanh toán`).
  - Lọc bỏ tiền khách đưa, tiền thừa thối lại.
  - Tự động trích xuất ngày tháng in trên hóa đơn.
  - Điền sẵn số tiền và tên cửa hàng vào form `/add`.

### 2.4. Phương thức 4: Nhập tự động từ Biến động số dư Ngân hàng (D1 Deep Link)
- Khi app phát hiện người dùng vừa chuyển khoản từ app ngân hàng (xem Phân hệ 11):
- Thông báo hiện lên $\rightarrow$ Chạm vào thông báo $\rightarrow$ Form `/add` tự động mở ra với số tiền và nội dung chuyển khoản đã được điền sẵn từ biến động số dư.

---

## 3. MÀN HÌNH GẮN DANH MỤC NHANH (QUICK CATEGORIZE - C1)

- **Vấn đề giải quyết:** Các giao dịch được nhập tự động từ ngân hàng hoặc sao kê thường chưa có danh mục cụ thể (được xếp vào mục "Chưa phân loại").
- **Màn hình `/transactions/gan-danh-muc`:**
  - Hiển thị danh sách các giao dịch chưa được gắn danh mục.
  - Cung cấp gợi ý danh mục thông minh dựa trên lịch sử chi tiêu của người dùng.
  - Người dùng chạm 1 lần vào icon gợi ý là giao dịch được gắn danh mục ngay lập tức.

---

## 4. TÁC ĐỘNG TỚI TOÀN BỘ HỆ THỐNG KHI TẠO / SỬA / XÓA GIAO DỊCH

Mỗi thao tác trên giao dịch tạo ra hiệu ứng dây chuyền (Cascade Impact) tức thì:
1. **Số dư Ví (`wallets`):** Tự động cộng/trừ số dư thực tế tương ứng.
2. **Tiến độ Ngân sách (`budgets`):** Nếu giao dịch thuộc danh mục có đặt hạn mức, số tiền đã chi của ngân sách tăng lên; nếu vượt ngưỡng 80% hoặc 100%, hệ thống tự động kích hoạt thông báo cảnh báo.
3. **Tiến độ Mục tiêu (`goals`):** Giao dịch chuyển tiền vào/ra mục tiêu cập nhật thanh tiến độ tích lũy.
4. **Báo cáo Phân tích (`analytics`):** Tức thì cập nhật số liệu biểu đồ tròn và biểu đồ xu hướng.
5. **Hàng đợi Đồng bộ (`sync_engine`):** Ghi một bản ghi thao tác vào hàng đợi offline để đẩy lên server khi có mạng.
