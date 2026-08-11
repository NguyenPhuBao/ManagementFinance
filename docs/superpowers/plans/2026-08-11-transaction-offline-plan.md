# Transaction Module Offline-First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai Module Giao dịch Offline-First với tính năng tự động điều chỉnh số dư ví local khi thực hiện Chi tiêu, Thu nhập, hoặc Chuyển khoản, kèm bộ lọc theo tháng và nhóm theo từng ngày.

**Architecture:** Mẫu Clean Architecture (Data Source -> Repository -> Cubit -> UI) với Drift SQLite local DB và SyncEngine hàng đợi offline.

**Tech Stack:** Flutter, Drift (SQLite), flutter_bloc, get_it, intl, uuid.

## Global Constraints

- Platform: Web, Android, iOS.
- Local DB: Drift SQLite via `AppDatabase`.
- State Management: `flutter_bloc` (`TransactionCubit`).

---

### Task 1: Extend TransactionDao & Create TransactionLocalDataSource

**Files:**
- Modify: `src/Client-app/lib/core/database/daos/transaction_dao.dart`
- Create: `src/Client-app/lib/features/transaction/data/datasources/transaction_local_data_source.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `TransactionDao`
- Produces: `TransactionLocalDataSource` (`watchByMonth`, `insertTransaction`, `deleteTransaction`)

- [ ] **Step 1: Add `watchByMonth` in `TransactionDao`**

```dart
Stream<List<Transaction>> watchByMonth(int idaccount, int year, int month) {
  final from = DateTime(year, month, 1);
  final to   = DateTime(year, month + 1, 0, 23, 59, 59);
  return (select(transactions)
        ..where((t) =>
            t.idaccount.equals(idaccount) &
            t.isDeleted.equals(false) &
            t.date.isBiggerOrEqualValue(from) &
            t.date.isSmallerOrEqualValue(to))
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();
}
```

- [ ] **Step 2: Create `TransactionLocalDataSource` interface and implementation**

```dart
abstract class TransactionLocalDataSource {
  Stream<List<TransactionEntity>> watchTransactionsByMonth(int idaccount, int year, int month);
  Future<void> addTransaction(TransactionEntity entity);
  Future<void> deleteTransaction(String id);
}
```

- [ ] **Step 3: Verify code compilation**

Run: `flutter analyze --no-fatal-infos` in `src/Client-app`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/lib/core/database/daos/transaction_dao.dart src/Client-app/lib/features/transaction/data/datasources/transaction_local_data_source.dart
git commit -m "feat(transaction): add watchByMonth DAO method and TransactionLocalDataSource"
```

---

### Task 2: Implement TransactionRepository with Wallet Balance Adjustment Logic

**Files:**
- Create: `src/Client-app/lib/features/transaction/data/repositories/transaction_repository.dart`

**Interfaces:**
- Consumes: `TransactionLocalDataSource`, `WalletDao`, `SyncEngine`
- Produces: `TransactionRepository` (`watchTransactions`, `addTransaction`, `deleteTransaction`)

- [ ] **Step 1: Create `TransactionRepository` abstract class and implementation**

Implement automatic wallet adjustments:
- If type == `'chi'`, `wallet.balance - amount`
- If type == `'thu'`, `wallet.balance + amount`
- If type == `'transfer'`, `sourceWallet.balance - amount` AND `destWallet.balance + amount`

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze --no-fatal-infos` in `src/Client-app`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/data/repositories/transaction_repository.dart
git commit -m "feat(transaction): implement TransactionRepository with automatic wallet balance adjustment"
```

---

### Task 3: Implement TransactionCubit and Register Dependency Injection

**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/bloc/transaction_bloc.dart` (or create `transaction_cubit.dart`)
- Modify: `src/Client-app/lib/core/di/injection_container.dart`

**Interfaces:**
- Consumes: `TransactionRepository`
- Produces: `TransactionCubit`, `TransactionState`

- [ ] **Step 1: Create or update `TransactionCubit` & `TransactionState`**

```dart
class TransactionLoaded extends TransactionState {
  final List<TransactionEntity> transactions;
  final double totalIncome;
  final double totalExpense;
}
```

- [ ] **Step 2: Register DI in `injection_container.dart`**

```dart
sl.registerLazySingleton<TransactionLocalDataSource>(
  () => TransactionLocalDataSourceImpl(sl<AppDatabase>()),
);
sl.registerLazySingleton<TransactionRepository>(
  () => TransactionRepositoryImpl(
    localDataSource: sl(),
    walletDao: sl<AppDatabase>().walletDao,
    syncEngine: sl(),
  ),
);
sl.registerFactory(() => TransactionCubit(repository: sl()));
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze --no-fatal-infos` in `src/Client-app`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/bloc/ src/Client-app/lib/core/di/injection_container.dart
git commit -m "feat(transaction): implement TransactionCubit and register DI"
```

---

### Task 4: Connect AddTransactionPage & ChooseCategoryPage to Local Database & Cubit

**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart`
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/choose_category_page.dart`

**Interfaces:**
- Consumes: `TransactionCubit`, `CategoryDao`, `WalletDao`
- Produces: Real working Add Transaction & Category Selection UI

- [ ] **Step 1: Connect `ChooseCategoryPage` to `CategoryDao`**
Read categories from local SQLite DB seeded categories.

- [ ] **Step 2: Connect `AddTransactionPage` to `TransactionCubit`**
Call `context.read<TransactionCubit>().addTransaction(...)` on Save, handle loading/success state, navigate back, and trigger wallet balance refresh.

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze --no-fatal-infos` in `src/Client-app`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/pages/
git commit -m "feat(transaction): connect AddTransactionPage and ChooseCategoryPage to SQLite DB and Cubit"
```

---

### Task 5: Connect Main Transaction List UI (Filtered by Month, Grouped by Day)

**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/transaction_page.dart` (or main tab)

**Interfaces:**
- Consumes: `TransactionCubit` (`watchTransactions`)
- Produces: Reactive transaction list grouped by day with monthly summary

- [ ] **Step 1: Implement monthly date picker & day-grouped transaction list UI**
- [ ] **Step 2: Verify compilation and run analyze**

Run: `flutter analyze --no-fatal-infos` in `src/Client-app`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/pages/
git commit -m "feat(transaction): implement reactive transaction list filtered by month and grouped by day"
```

---

### Task 6: Final Verification & Integration Test

- [ ] **Step 1: Run `flutter analyze`**
- [ ] **Step 2: Manual UI test in Flutter Web browser**
- [ ] **Step 3: Commit final updates**
