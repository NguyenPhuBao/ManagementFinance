# Thiết Kế Chi Tiết Module Giao Dịch Offline-First (Transaction Module Specification)

> **Ngày tạo:** 2026-08-11  
> **Trạng thái:** Đã phê duyệt  
> **Người phụ trách:** Antigravity AI & Nguyễn Phú Bảo  

---

## 1. Mục Tiêu
Triển khai module quản lý Giao dịch (Transaction) theo kiến trúc **Offline-First**, cho phép người dùng ghi nhận thu nhập, chi tiêu, và chuyển khoản giữa các ví ngay cả khi không có kết nối mạng. Dữ liệu được ghi trực tiếp vào cơ sở dữ liệu SQLite local (thông qua Drift) và tự động tính toán lại số dư ví tương ứng ngay lập tức.

---

## 2. Kiến Trúc Dữ Liệu & Nghiệp Vụ Ví (Wallet Balance Adjustment Rules)

### 2.1 Mẫu Dữ Liệu (`TransactionEntity`)
- `id`: `String` (UUID v4 client tạo)
- `walletId`: `String` (Ví nguồn)
- `idaccount`: `int` (ID tài khoản người dùng)
- `categoryId`: `String?` (ID danh mục thu/chi)
- `amount`: `double` (Số tiền giao dịch)
- `type`: `String` (`'chi'` | `'thu'` | `'transfer'`)
- `note`: `String` (Ghi chú)
- `date`: `DateTime` (Thời gian giao dịch)
- `images`: `List<String>` (Đường dẫn danh sách hình ảnh hóa đơn/chứng từ)
- `syncStatus`: `String` (`'pending'` | `'synced'`)
- `updatedAt`: `DateTime`
- `isDeleted`: `bool`

### 2.2 Quy Tắc Cập Nhật Số Dư Ví Tự Động
Mọi thao tác thêm/xóa giao dịch sẽ cập nhật bảng `Wallets` trong SQLite cùng một transaction:

| Thao Tác | Loại Giao Dịch | Biến Động Ví Nguồn (`walletId`) | Biến Động Ví Đích (`destinationWalletId`) |
|---|---|---|---|
| **Thêm mới** | Chi tiêu (`chi`) | `balance = balance - amount` | Không ảnh hưởng |
| **Thêm mới** | Thu nhập (`thu`) | `balance = balance + amount` | Không ảnh hưởng |
| **Thêm mới** | Chuyển khoản (`transfer`) | `balance = balance - amount` | `balance = balance + amount` |
| **Xóa** | Chi tiêu (`chi`) | `balance = balance + amount` | Không ảnh hưởng |
| **Xóa** | Thu nhập (`thu`) | `balance = balance - amount` | Không ảnh hưởng |
| **Xóa** | Chuyển khoản (`transfer`) | `balance = balance + amount` | `balance = balance - amount` |

---

## 3. Cấu Trúc Các Component

### 3.1 Data Layer (`lib/features/transaction/data/`)
1. `TransactionLocalDataSource`:
   - Interface & Impl truy vấn qua Drift `TransactionDao` & `WalletDao`.
2. `TransactionRepositoryImpl`:
   - Thực thi các phương thức: `watchTransactions(idaccount, month, year)`, `addTransaction(...)`, `deleteTransaction(id)`.
   - Đưa thay đổi vào hàng đợi đồng bộ (`SyncEngine`).

### 3.2 State Management Layer (`lib/features/transaction/presentation/bloc/`)
1. `TransactionState`:
   - `TransactionInitial`
   - `TransactionLoading`
   - `TransactionLoaded(List<TransactionEntity> transactions, double totalIncome, double totalExpense)`
   - `TransactionError(String message)`
2. `TransactionCubit`:
   - Quản lý luồng stream `watchTransactions` và các thao tác thêm/xóa giao dịch.

### 3.3 UI Layer (`lib/features/transaction/presentation/pages/`)
1. `AddTransactionPage`:
   - Giao diện form thêm mới 3 tab: **Chi tiêu**, **Thu nhập**, **Chuyển khoản**.
   - Tự động load danh sách ví người dùng và danh mục chi tiêu/thu nhập.
2. `ChooseCategoryPage`:
   - Hiển thị danh mục phân loại theo `chi` hoặc `thu`.
3. `TransactionPage`:
   - Hiển thị danh sách lọc theo tháng/năm, nhóm theo từng ngày với tổng thu/chi trong ngày.

---

## 4. Kế Hoạch Kiểm Thử (Verification Plan)
1. **Kiểm thử thêm giao dịch Chi tiêu:** Kiểm tra số dư ví nguồn bị trừ chính xác trong DB SQLite local.
2. **Kiểm thử thêm giao dịch Chuyển khoản:** Kiểm tra ví nguồn bị trừ và ví đích được cộng đồng thời.
3. **Kiểm thử xóa giao dịch:** Kiểm tra số dư của các ví liên quan được hoàn lại nguyên trạng.
4. **Kiểm thử phản hồi thời gian thực (Reactive UI):** Giao diện danh sách tự động cập nhật ngay khi giao dịch mới được tạo.
