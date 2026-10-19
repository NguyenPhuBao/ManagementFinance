# 💳 PHÂN HỆ 03: QUẢN LÝ VÍ TIỀN & TÀI SẢN RÒNG (WALLET MANAGEMENT)

> **Mã phân hệ:** `WALLET`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/wallet`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/wallet)  
> **Quản lý trạng thái:** `WalletBloc` / `WalletCubit`  
> **Cơ sở dữ liệu:** SQLite bảng `wallets` (Đồng bộ 2 chiều qua Entity `wallet`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/wallets` | [`wallet_list_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/wallet/presentation/pages/wallet_list_page.dart) | Danh sách ví & Tổng tài sản | Thẻ Tổng tài sản ròng; Danh sách ví theo loại; Nút Thêm ví (+); Chuyển nhanh sang Sổ GD theo ví |
| `/wallets/add` | [`wallet_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/wallet/presentation/pages/wallet_add_page.dart) | Tạo mới ví tiền | Tên ví; Phân loại ví; Số dư ban đầu; Bảng chọn Icon & Bảng mã màu sắc; Nút Lưu |
| `/wallets/:id/edit` | [`wallet_edit_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/wallet/presentation/pages/wallet_edit_page.dart) | Chỉnh sửa & Xóa ví | Đổi tên ví; Cập nhật số dư thực tế; Công tắc loại trừ khỏi tổng tài sản; Nút Xóa ví |

---

## 2. QUY TẮC NGHIỆP VỤ & PHÂN QUYỀN GÓI CƯỚC

### 2.1. Giới hạn Trần Gói Basic (Feature Gating)
- **Quy tắc:** Tài khoản **Basic** chỉ được sở hữu tối đa **3 ví đang hoạt động** (`active wallets`).
- **Cơ chế Chặn tại Router:**
  ```dart
  GoRoute(
    path: '/wallets/add',
    redirect: redirectTaoTheoGoi(LoaiTran.vi),
    builder: (_, __) => const WalletAddPage(),
  )
  ```
  - Khi người dùng gói Basic nhấn nút "+ Thêm ví" và hệ thống kiểm tra thấy đã có 3 ví: Router lập tức chuyển hướng sang `/premium?tran=vi`.
  - Màn hình Nâng cấp gói hiển thị câu giải thích trực quan: *"Bạn đã sử dụng hết 3/3 ví miễn phí. Nâng cấp Premium để quản lý không giới hạn ví tài chính!"*.
- **Gói Premium:** Tự do tạo số lượng ví không giới hạn (quản lý đồng thời nhiều thẻ ngân hàng, tiền mặt, ví điện tử, tài khoản chứng khoán...).

---

## 3. CHI TIẾT CÁC TÍNH NĂNG VẬN HÀNH CỐT LÕI

### 3.1. Phân loại Ví Tài chính Đa dạng
Ứng dụng hỗ trợ 5 nhóm phân loại ví phổ biến tại Việt Nam:
1. **Tiền mặt (Cash):** Tiền trong ví cầm tay, ống heo, két sắt gia đình.
2. **Tài khoản Ngân hàng (Bank Account):** MB Bank, Vietcombank, Techcombank, ACB, VPBank...
3. **Ví điện tử (E-Wallet):** MoMo, ZaloPay, VNPay, ShopeePay...
4. **Thẻ tín dụng (Credit Card):** Quản lý hạn mức chi tiêu trước, trả sau.
5. **Khác (Other):** Tài khoản đầu tư, chứng khoán, tiền tiết kiệm riêng.

### 3.2. Tính toán & Bảo toàn Số dư Thực tế
- **Số dư ban đầu (Initial Balance):** Được thiết lập khi tạo ví.
- **Tự động cập nhật số dư liên tục:**
  - Giao dịch Thu (+): Số dư ví tăng tương ứng.
  - Giao dịch Chi (-): Số dư ví giảm tương ứng.
  - Chuyển khoản ví ($\leftrightarrow$): Tiền tự động trừ ở Ví nguồn và cộng vào Ví đích, tổng tài sản hệ thống được bảo toàn 100%.
- **Chức năng "Điều chỉnh số dư" (Adjust Balance):**
  - Khi số tiền thực tế trong bóp hoặc tài khoản lệch so với app (do quên ghi chép 1 vài khoản nhỏ):
  - Người dùng nhập số tiền thực tế hiện tại $\rightarrow$ Hệ thống tự động tính toán phần chênh lệch và sinh ra 1 giao dịch điều chỉnh (Adjustment Transaction) để đưa số dư về đúng thực tế.

### 3.3. Tùy chọn "Loại trừ khỏi Tổng tài sản" (Exclude from Net Worth)
- Một số ví dùng cho mục đích đặc biệt (ví dụ: Quỹ lớp, Tiền công ty tạm ứng, Sổ tiết kiệm phong tỏa dài hạn) không muốn tính vào số dư khả dụng hàng ngày trên Trang chủ.
- Người dùng chỉ cần bật công tắc *"Loại trừ khỏi tổng tài sản"*: Số dư ví này vẫn được theo dõi độc lập nhưng không cộng dồn vào tổng số dư Trang chủ.

### 3.4. Xóa ví An toàn (Safe Soft-Delete)
- Áp dụng cơ chế **Soft-Delete** (`delete_at = now()`): Không xóa vật lý dữ liệu khỏi SQLite/PostgreSQL để đảm bảo tính toàn vẹn lịch sử báo cáo tài chính.
- Khi một ví bị xóa: Toàn bộ các giao dịch trong quá khứ gắn với ví này vẫn được bảo toàn trong Sổ giao dịch và các báo cáo thống kê.
