# Transaction Offline Management Design

## 1. Overview
Hệ thống quản lý Giao dịch (Transaction) theo kiến trúc **Offline-First** cho ứng dụng Flutter. 
Người dùng có thể Thêm, Xem, Lọc và Xóa các giao dịch thu/chi/chuyển khoản khi không có kết nối mạng. Tất cả dữ liệu được lưu trực tiếp vào cơ sở dữ liệu SQLite local (`Drift`) và tự động cập nhật số dư các Ví liên quan. Khi có mạng, `SyncEngine` sẽ tự động đồng bộ bản ghi `pending` lên Backend.

---

## 2. Architecture & Component Isolation

```
[ UI Components ]
  ├── AddTransactionPage (Giao diện nhập giao dịch)
  ├── ChooseCategoryPage (Giao diện chọn danh mục)
  └── TransactionListPage / Home (Hiển thị giao dịch)
         │
         ▼
[ State Management ]
  └── TransactionBloc (Xử lý sự kiện & phát State)
         │
         ▼
[ Domain / Repository Layer ]
  └── TransactionRepository & Impl
         │
         ▼
[ Local Data Layer ]
  └── TransactionLocalDataSource (Thực thi Drift Transaction nguyên tố)
         │
         ├── TransactionsTable (Drift SQLite)
         └── WalletsTable (Drift SQLite - Cập nhật số dư)
```

---

## 3. Data Schema & Models

### 3.1 `TransactionEntity` (`lib/features/transaction/data/models/transaction_entity.dart`)
- **Trường dữ liệu:**
  - `id`: `String` (UUIDv4)
  - `walletId`: `String` (ID Ví nguồn)
  - `idaccount`: `int` (ID tài khoản)
  - `categoryId`: `String?` (ID Danh mục, null nếu chuyển khoản)
  - `amount`: `double` (Số tiền giao dịch)
  - `type`: `String` (`'chi'` | `'thu'` | `'transfer'` | `'adjustment'`)
  - `note`: `String` (Ghi chú)
  - `date`: `DateTime` (Thời gian giao dịch)
  - `images`: `List<String>` (Danh sách đường dẫn hình ảnh đính kèm)
  - `syncStatus`: `String` (`'pending'` | `'synced'`)
  - `updatedAt`: `DateTime`
  - `isDeleted`: `bool`

- **Mapping Methods:**
  - `fromDrift(Transaction d)`
  - `toCompanion()`

---

## 4. Local Data Source & Atomic Balance Logic

### 4.1 `TransactionLocalDataSource`
- `Future<List<TransactionEntity>> getTransactions(int idaccount)`
- `Stream<List<TransactionEntity>> watchTransactions(int idaccount)`
- `Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month)`
- `Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month)`
- `Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId})`
- `Future<void> deleteTransaction(TransactionEntity transaction)`

### 4.2 Logic Cập nhật Số dư Nguyên tố (Atomic Operations)
Mọi thao tác ghi dữ liệu được thực thi trong một `db.transaction(() async { ... })`:

1. **Chi tiêu (`type == 'chi'`)**:
   - Thêm bản ghi vào `TransactionsTable`.
   - Giảm `wallet.balance` theo `amount`.
   - Đánh dấu `wallet.syncStatus = 'pending'`, `updatedAt = DateTime.now()`.

2. **Thu nhập (`type == 'thu'`)**:
   - Thêm bản ghi vào `TransactionsTable`.
   - Tăng `wallet.balance` theo `amount`.
   - Đánh dấu `wallet.syncStatus = 'pending'`, `updatedAt = DateTime.now()`.

3. **Chuyển khoản (`type == 'transfer'`)**:
   - Thêm 2 bản ghi giao dịch (1 Chi từ Ví Nguồn, 1 Thu tới Ví Đích).
   - Giảm số dư Ví Nguồn theo `amount`.
   - Tăng số dư Ví Đích theo `amount`.

4. **Xóa giao dịch**:
   - Cập nhật `isDeleted = true`, `syncStatus = 'pending'` cho bản ghi giao dịch.
   - Hoàn lại số dư ví tương ứng (Giao dịch chi tiêu bị xóa -> cộng lại tiền vào ví; giao dịch thu nhập bị xóa -> trừ tiền khỏi ví).

---

## 5. State Management (Transaction BLoC)

### 5.1 Events (`transaction_event.dart`)
- `LoadTransactionsEvent({required int idaccount})`
- `TransactionsUpdatedEvent(List<TransactionEntity> transactions)`
- `AddTransactionEvent({required TransactionEntity transaction, String? destinationWalletId})`
- `DeleteTransactionEvent(TransactionEntity transaction)`
- `FilterMonthEvent({required int year, required int month})`

### 5.2 States (`transaction_state.dart`)
- `TransactionInitialState`
- `TransactionLoadingState`
- `TransactionLoadedState`
  - `transactions`: `List<TransactionEntity>`
  - `monthlyTransactions`: `List<TransactionEntity>`
  - `totalIncome`: `double`
  - `totalExpense`: `double`
  - `selectedYear`: `int`
  - `selectedMonth`: `int`
  - `isSubmitting`: `bool`
  - `actionSuccess`: `bool?`
  - `errorMessage`: `String?`
- `TransactionErrorState`

### 5.3 Background Sync Trigger
Khi `AddTransactionEvent` hoặc `DeleteTransactionEvent` thực thi thành công tại SQLite local:
- Gọi `SyncEngine.instance.triggerSync()` để tự động kích hoạt đồng bộ lên Backend nếu có mạng internet.

---

## 6. UI Integration & Dependency Injection

1. **`AddTransactionPage`**:
   - Lấy danh sách ví từ SQLite thông qua `WalletDao` / `WalletBloc` để hiển thị trong bottom sheet chọn ví.
   - Lấy danh mục được chọn từ `ChooseCategoryPage`.
   - Xử lý bàn phím nhập số tiền và kiểm tra điều kiện validation (`amount > 0`).
   - Tạo UUIDv4 cho ID giao dịch và dispatch `AddTransactionEvent`.

2. **`ChooseCategoryPage`**:
   - Truy vấn dữ liệu danh mục từ `CategoryDao` phân loại theo `'chi'` / `'thu'`.
   - Trả đối tượng danh mục được chọn về `AddTransactionPage`.

3. **Dependency Injection (`injection_container.dart`)**:
   - Đăng ký `TransactionLocalDataSource`, `TransactionRepository`, và `TransactionBloc`.

---

## 7. Verification Plan
- Chạy `flutter analyze` kiểm tra lỗi cú pháp và cảnh báo context.
- Thực thi thêm giao dịch Thu nhập, Chi tiêu, Chuyển khoản offline và kiểm tra số dư Ví thay đổi chính xác.
- Kiểm tra danh sách giao dịch hiển thị realtime trên UI.
