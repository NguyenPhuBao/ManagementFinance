# Design Specification: Bill Feature Implementation (Chức Năng Hóa Đơn & Dịch Vụ)

**Date:** 2026-08-12  
**Status:** Approved  
**Scope:** Client-app (`src/Client-app`)

---

## 1. Overview & Goal

Hiện tại, chức năng **Hóa đơn & Dịch vụ (Bill)** tại ứng dụng `Client-app` chỉ mới dừng lại ở mức giao diện mẫu (mock data UI trong 4 trang: `bill_page.dart`, `bill_add_page.dart`, `bill_edit_page.dart`, `bill_delete_page.dart`). 

Mục tiêu của thiết kế này là hiện thực hóa toàn bộ luồng dữ liệu và nghiệp vụ của Hóa đơn theo kiến trúc **Clean Architecture + BLoC + Drift SQLite (Offline-First)**, kết nối giao diện người dùng với cơ sở dữ liệu local và cơ chế đồng bộ `SyncEngine` đã có sẵn.

---

## 2. Key Requirements & Business Logic

1. **Quản lý Hóa đơn (CRUD):**
   - Xem danh sách hóa đơn phân loại theo trạng thái (Sắp đến hạn, Chưa thanh toán, Đã thanh toán).
   - Thêm hóa đơn mới với thông tin: Tên, Số tiền, Ngày đến hạn (`due_date`), Chu kỳ lặp lại (`recurrence`: `once`, `weekly`, `monthly`, `yearly`), Biểu tượng, Màu sắc, Ghi chú.
   - Chỉnh sửa thông tin hóa đơn.
   - Xóa mềm hóa đơn (`is_deleted = true`, `syncStatus = 'pending'`).

2. **Quy trình Thanh toán Hóa đơn (`payBill`):**
   Khi người dùng bấm **"Thanh toán"** cho một Hóa đơn chưa thanh toán:
   - Cập nhật trạng thái Hóa đơn hiện tại thành **Đã thanh toán** (`is_paid = true`, `syncStatus = 'pending'`).
   - Tự động tạo một bản ghi **Giao dịch chi** (`Transaction`) tương ứng: `type = 'chi'`, `amount = bill.amount`, `wallet_id = selected_wallet_id`, `note = 'Thanh toán hóa đơn: ${bill.name}'`, `date = DateTime.now()`, `syncStatus = 'pending'`.
   - Cập nhật trừ số dư Ví tương ứng trong `WalletDao`.
   - **Tự động lặp kỳ mới:** Nếu hóa đơn có chu kỳ lặp lại (`recurrence != 'once'`), hệ thống tự động khởi tạo 1 bản ghi Hóa đơn mới cho kỳ tiếp theo (với `due_date` được cộng thêm 1 tuần / 1 tháng / 1 năm) ở trạng thái **Chưa thanh toán** (`is_paid = false`, `syncStatus = 'pending'`).

3. **Offline-First & Đồng bộ:**
   - Mọi thao tác lưu/sửa/xóa/thanh toán thực hiện trực tiếp trên SQLite local.
   - Tất cả bản ghi bị thay đổi đều mang `syncStatus = 'pending'` và mốc `updatedAt = DateTime.now()`, cho phép `SyncEngine` tự động đẩy (Push) dữ liệu lên Backend PostgreSQL khi có mạng.

---

## 3. Architecture & Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  BillPage | BillAddPage | BillEditPage | BillDeletePage     │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Events & States)
┌──────────────────────────────▼──────────────────────────────┐
│                    State Management                         │
│                        BillBloc                             │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                      Domain / Repository                    │
│                        BillRepository                       │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                       Data Layer                            │
│  BillLocalDataSource ──▶ BillDao & TransactionDao & WalletDao│
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Drift SQLite Database                    │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Data Layer

1. **`BillLocalDataSource` (`lib/features/bill/data/datasources/bill_local_datasource.dart`)**
   - Chứa `BillDao`, `TransactionDao`, `WalletDao`.
   - Phương thức: `watchBills(int idaccount)`, `getBillById(String id)`, `insertBill(BillsCompanion bill)`, `updateBill(BillsCompanion bill)`, `softDeleteBill(String id)`, `markBillPaid(String id)`.

2. **`BillRepository` & `BillRepositoryImpl` (`lib/features/bill/data/repositories/`)**
   - Định nghĩa Interface `BillRepository` và lớp triển khai `BillRepositoryImpl`.
   - Triển khai phương thức `payBill({required Bill bill, required String walletId, required int idaccount})`:
     - Gọi `markBillPaid`.
     - Tạo `TransactionsCompanion` lưu giao dịch chi.
     - Trừ số dư ví trong `WalletDao`.
     - Tính ngày `nextDueDate` dựa trên `bill.recurrence` (`weekly` $\rightarrow$ `+7 days`, `monthly` $\rightarrow$ `+1 month`, `yearly` $\rightarrow$ `+1 year`), tạo Hóa đơn mới nếu `recurrence != 'once'`.

### 3.2 State Management (BillBloc)

- **Events (`lib/features/bill/presentation/bloc/bill_event.dart`):**
  - `LoadBillsEvent({required int idaccount})`
  - `AddBillEvent({required BillsCompanion bill})`
  - `EditBillEvent({required BillsCompanion bill})`
  - `DeleteBillEvent({required String id})`
  - `PayBillEvent({required Bill bill, required String walletId, required int idaccount})`

- **States (`lib/features/bill/presentation/bloc/bill_state.dart`):**
  - `BillInitial`
  - `BillLoading`
  - `BillLoaded`: `List<Bill> bills`, `double totalUnpaidAmount`, `int unpaidCount`.
  - `BillOperationSuccess`: `String message`
  - `BillError`: `String message`

### 3.3 UI Integration (Presentation Layer)

1. **`bill_page.dart`:**
   - Dùng `BlocBuilder<BillBloc, BillState>` lắng nghe danh sách Hóa đơn thực tế từ SQLite.
   - Thẻ Summary Card hiển thị tổng số tiền hóa đơn chưa thanh toán và số lượng hóa đơn chưa thanh toán.
   - Nút "Thanh toán" hiển thị `WalletSelectionBottomSheet` cho người dùng chọn ví thanh toán trước khi dispatch `PayBillEvent`.
   - Nút "Xóa" mở Dialog xác nhận trước khi dispatch `DeleteBillEvent`.

2. **`bill_add_page.dart`:**
   - Biểu mẫu tạo mới hóa đơn với đầy đủ validation (tên không trống, số tiền > 0, ngày đến hạn hợp lệ).
   - Khi Submit: sinh UUID client (`const Uuid().v4()`), dispatch `AddBillEvent`, quay lại màn hình chính.

3. **`bill_edit_page.dart`:**
   - Đọc dữ liệu từ bản ghi `Bill` được truyền vào, điền sẵn thông tin lên form.
   - Khi Submit: dispatch `EditBillEvent`, quay lại màn hình chính.

---

## 4. Testing & Verification Plan

1. **Unit Tests:**
   - Test `BillRepositoryImpl.payBill`: kiểm tra bản ghi hóa đơn hiện tại được gán `isPaid = true`, giao dịch chi mới được chèn vào `Transactions`, số dư ví được cập nhật, và hóa đơn kỳ mới được sinh ra với ngày `dueDate` đúng chu kỳ.
2. **Integration & Manual Verification:**
   - Chạy ứng dụng Flutter Web/Chrome (`flutter run -d chrome`).
   - Thao tác Tạo hóa đơn $\rightarrow$ Kiểm tra hiển thị danh sách hóa đơn trong CSDL SQLite local.
   - Thao tác Thanh toán $\rightarrow$ Chọn ví $\rightarrow$ Kiểm tra số dư ví giảm, giao dịch chi xuất hiện trong trang Giao dịch, và hóa đơn kỳ mới xuất hiện.
   - Kiểm tra `SyncEngine` đẩy dữ liệu hóa đơn mới lên Backend REST API.
