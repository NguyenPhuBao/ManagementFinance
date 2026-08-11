# Transaction Offline Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai module Quản lý Giao dịch (Transaction) theo kiến trúc Offline-First với SQLite local (Drift), tự động cập nhật số dư ví nguyên tố và kích hoạt đồng bộ khi có kết nối mạng.

**Architecture:** Tạo `TransactionEntity` cho Data Layer, triển khai `TransactionLocalDataSource` sử dụng Drift Database Transactions để vừa lưu bản ghi giao dịch vừa cập nhật số dư ví `WalletsTable`. Sử dụng `TransactionBloc` để quản lý trạng thái và UI phản hồi realtime.

**Tech Stack:** Flutter, Drift (SQLite), BLoC / HydratedBloc, GoRouter, GetIt (Service Locator), Uuid.

## Global Constraints

- Dart / Flutter project path: `src/Client-app`
- Data persistence: SQLite via Drift (`AppDatabase`, `TransactionDao`, `WalletDao`)
- Soft Delete: Set `isDeleted = true`, `syncStatus = 'pending'`, `updatedAt = DateTime.now()`
- Atomic Balance Updates: Use `db.transaction(() async { ... })` in `TransactionLocalDataSourceImpl`

---

### Task 1: Create TransactionEntity Model

**Files:**
- Create: `src/Client-app/lib/features/transaction/data/models/transaction_entity.dart`

**Interfaces:**
- Produces: `TransactionEntity` class with `fromDrift`, `toCompanion`, `copyWith`.

- [ ] **Step 1: Create `transaction_entity.dart`**

```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class TransactionEntity {
  final String id;
  final String walletId;
  final int idaccount;
  final String? categoryId;
  final double amount;
  final String type; // 'chi' | 'thu' | 'transfer' | 'adjustment'
  final String note;
  final DateTime date;
  final List<String> images;
  final String syncStatus;
  final DateTime updatedAt;
  final bool isDeleted;

  TransactionEntity({
    required this.id,
    required this.walletId,
    required this.idaccount,
    this.categoryId,
    required this.amount,
    required this.type,
    this.note = '',
    required this.date,
    this.images = const [],
    this.syncStatus = 'pending',
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory TransactionEntity.fromDrift(Transaction d) {
    List<String> imgList = [];
    if (d.images.isNotEmpty && d.images != '[]') {
      try {
        imgList = (d.images.replaceAll('[', '').replaceAll(']', '').split(','))
            .map((e) => e.trim().replaceAll('"', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    return TransactionEntity(
      id: d.id,
      walletId: d.walletId,
      idaccount: d.idaccount,
      categoryId: d.categoryId,
      amount: d.amount,
      type: d.type,
      note: d.note,
      date: d.date,
      images: imgList,
      syncStatus: d.syncStatus,
      updatedAt: d.updatedAt,
      isDeleted: d.isDeleted,
    );
  }

  TransactionsCompanion toCompanion() {
    final imgJson = '[${images.map((e) => '"$e"').join(',')}]';
    return TransactionsCompanion.insert(
      id: id,
      walletId: walletId,
      idaccount: idaccount,
      categoryId: Value(categoryId),
      amount: amount,
      type: type,
      note: Value(note),
      date: date,
      images: Value(imgJson),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt,
      isDeleted: Value(isDeleted),
    );
  }

  TransactionEntity copyWith({
    String? id,
    String? walletId,
    int? idaccount,
    String? categoryId,
    double? amount,
    String? type,
    String? note,
    DateTime? date,
    List<String>? images,
    String? syncStatus,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
      images: images ?? this.images,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
```

- [ ] **Step 2: Verify `TransactionEntity` model**

Run: `cd src/Client-app && flutter analyze`
Expected: No errors in `transaction_entity.dart`.

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/data/models/transaction_entity.dart
git commit -m "feat(transaction): add TransactionEntity model"
```

---

### Task 2: Create TransactionLocalDataSource with Atomic Operations

**Files:**
- Create: `src/Client-app/lib/features/transaction/data/datasources/transaction_local_data_source.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `TransactionEntity`
- Produces: `TransactionLocalDataSource` interface and `TransactionLocalDataSourceImpl`

- [ ] **Step 1: Create `transaction_local_data_source.dart`**

```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../models/transaction_entity.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionEntity>> getTransactions(int idaccount);
  Stream<List<TransactionEntity>> watchTransactions(int idaccount);
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month);
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month);
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId});
  Future<void> deleteTransaction(TransactionEntity transaction);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final AppDatabase db;

  TransactionLocalDataSourceImpl({required this.db});

  @override
  Future<List<TransactionEntity>> getTransactions(int idaccount) async {
    final list = await db.transactionDao.getAll(idaccount);
    return list.map((t) => TransactionEntity.fromDrift(t)).toList();
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions(int idaccount) {
    return db.transactionDao
        .watchAll(idaccount)
        .map((list) => list.map((t) => TransactionEntity.fromDrift(t)).toList());
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month) async {
    final list = await db.transactionDao.getByMonth(idaccount, year, month);
    return list.map((t) => TransactionEntity.fromDrift(t)).toList();
  }

  @override
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month) {
    return db.transactionDao.getSummaryByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    await db.transaction(() async {
      // 1. Chèn bản ghi giao dịch
      await db.transactionDao.insert(transaction.toCompanion());

      // 2. Cập nhật số dư ví theo loại giao dịch
      final wallet = await db.walletDao.getById(transaction.walletId);
      if (wallet != null) {
        double newBalance = wallet.balance;
        if (transaction.type == 'chi') {
          newBalance -= transaction.amount;
        } else if (transaction.type == 'thu') {
          newBalance += transaction.amount;
        } else if (transaction.type == 'transfer' && destinationWalletId != null) {
          newBalance -= transaction.amount;
          final destWallet = await db.walletDao.getById(destinationWalletId);
          if (destWallet != null) {
            await db.walletDao.updateBalance(
              destinationWalletId,
              destWallet.balance + transaction.amount,
            );
          }
        }
        await db.walletDao.updateBalance(transaction.walletId, newBalance);
      }
    });
  }

  @override
  Future<void> deleteTransaction(TransactionEntity transaction) async {
    await db.transaction(() async {
      // 1. Soft delete giao dịch
      await db.transactionDao.softDelete(transaction.id);

      // 2. Hoàn lại số dư ví
      final wallet = await db.walletDao.getById(transaction.walletId);
      if (wallet != null) {
        double newBalance = wallet.balance;
        if (transaction.type == 'chi') {
          newBalance += transaction.amount; // Cộng lại tiền đã chi
        } else if (transaction.type == 'thu') {
          newBalance -= transaction.amount; // Trừ lại tiền đã thu
        }
        await db.walletDao.updateBalance(transaction.walletId, newBalance);
      }
    });
  }
}
```

- [ ] **Step 2: Verify `TransactionLocalDataSource` implementation**

Run: `cd src/Client-app && flutter analyze`
Expected: No errors in `transaction_local_data_source.dart`.

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/data/datasources/transaction_local_data_source.dart
git commit -m "feat(transaction): add TransactionLocalDataSource with atomic balance updates"
```

---

### Task 3: Create TransactionRepository

**Files:**
- Create: `src/Client-app/lib/features/transaction/data/repositories/transaction_repository.dart`

**Interfaces:**
- Consumes: `TransactionLocalDataSource`, `TransactionEntity`
- Produces: `TransactionRepository` interface and `TransactionRepositoryImpl`

- [ ] **Step 1: Create `transaction_repository.dart`**

```dart
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> getTransactions(int idaccount);
  Stream<List<TransactionEntity>> watchTransactions(int idaccount);
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month);
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month);
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId});
  Future<void> deleteTransaction(TransactionEntity transaction);
}

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource localDataSource;

  TransactionRepositoryImpl({required this.localDataSource});

  @override
  Future<List<TransactionEntity>> getTransactions(int idaccount) {
    return localDataSource.getTransactions(idaccount);
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions(int idaccount) {
    return localDataSource.watchTransactions(idaccount);
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month) {
    return localDataSource.getTransactionsByMonth(idaccount, year, month);
  }

  @override
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month) {
    return localDataSource.getSummaryByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId}) {
    return localDataSource.addTransaction(transaction, destinationWalletId: destinationWalletId);
  }

  @override
  Future<void> deleteTransaction(TransactionEntity transaction) {
    return localDataSource.deleteTransaction(transaction);
  }
}
```

- [ ] **Step 2: Verify `TransactionRepository` implementation**

Run: `cd src/Client-app && flutter analyze`
Expected: No errors in `transaction_repository.dart`.

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/data/repositories/transaction_repository.dart
git commit -m "feat(transaction): add TransactionRepository implementation"
```

---

### Task 4: Create Transaction BLoC (Event, State, Bloc)

**Files:**
- Create: `src/Client-app/lib/features/transaction/presentation/bloc/transaction_event.dart`
- Create: `src/Client-app/lib/features/transaction/presentation/bloc/transaction_state.dart`
- Create: `src/Client-app/lib/features/transaction/presentation/bloc/transaction_bloc.dart`

**Interfaces:**
- Consumes: `TransactionRepository`, `SyncEngine`
- Produces: `TransactionBloc`, `TransactionEvent`, `TransactionState`

- [ ] **Step 1: Create `transaction_event.dart`**

```dart
import 'package:equatable/equatable.dart';
import '../../data/models/transaction_entity.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionsEvent extends TransactionEvent {
  final int idaccount;
  const LoadTransactionsEvent({required this.idaccount});

  @override
  List<Object?> get props => [idaccount];
}

class TransactionsUpdatedEvent extends TransactionEvent {
  final List<TransactionEntity> transactions;
  const TransactionsUpdatedEvent(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class AddTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;
  final String? destinationWalletId;

  const AddTransactionEvent({
    required this.transaction,
    this.destinationWalletId,
  });

  @override
  List<Object?> get props => [transaction, destinationWalletId];
}

class DeleteTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;
  const DeleteTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class FilterMonthEvent extends TransactionEvent {
  final int year;
  final int month;

  const FilterMonthEvent({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
```

- [ ] **Step 2: Create `transaction_state.dart`**

```dart
import 'package:equatable/equatable.dart';
import '../../data/models/transaction_entity.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitialState extends TransactionState {}

class TransactionLoadingState extends TransactionState {}

class TransactionLoadedState extends TransactionState {
  final List<TransactionEntity> transactions;
  final List<TransactionEntity> monthlyTransactions;
  final double totalIncome;
  final double totalExpense;
  final int selectedYear;
  final int selectedMonth;
  final bool isSubmitting;
  final bool? actionSuccess;
  final String? errorMessage;

  const TransactionLoadedState({
    required this.transactions,
    required this.monthlyTransactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.selectedYear,
    required this.selectedMonth,
    this.isSubmitting = false,
    this.actionSuccess,
    this.errorMessage,
  });

  TransactionLoadedState copyWith({
    List<TransactionEntity>? transactions,
    List<TransactionEntity>? monthlyTransactions,
    double? totalIncome,
    double? totalExpense,
    int? selectedYear,
    int? selectedMonth,
    bool? isSubmitting,
    bool? actionSuccess,
    String? errorMessage,
  }) {
    return TransactionLoadedState(
      transactions: transactions ?? this.transactions,
      monthlyTransactions: monthlyTransactions ?? this.monthlyTransactions,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionSuccess: actionSuccess,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        transactions,
        monthlyTransactions,
        totalIncome,
        totalExpense,
        selectedYear,
        selectedMonth,
        isSubmitting,
        actionSuccess,
        errorMessage,
      ];
}

class TransactionErrorState extends TransactionState {
  final String message;
  const TransactionErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Create `transaction_bloc.dart`**

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository transactionRepository;
  final SyncEngine? syncEngine;
  StreamSubscription<List<TransactionEntity>>? _subscription;

  TransactionBloc({
    required this.transactionRepository,
    this.syncEngine,
  }) : super(TransactionInitialState()) {
    on<LoadTransactionsEvent>(_onLoadTransactions);
    on<TransactionsUpdatedEvent>(_onTransactionsUpdated);
    on<AddTransactionEvent>(_onAddTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);
    on<FilterMonthEvent>(_onFilterMonth);
  }

  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoadingState());
    await _subscription?.cancel();
    _subscription = transactionRepository
        .watchTransactions(event.idaccount)
        .listen((list) {
      add(TransactionsUpdatedEvent(list));
    });
  }

  void _onTransactionsUpdated(
    TransactionsUpdatedEvent event,
    Emitter<TransactionState> emit,
  ) {
    final now = DateTime.now();
    final year = state is TransactionLoadedState
        ? (state as TransactionLoadedState).selectedYear
        : now.year;
    final month = state is TransactionLoadedState
        ? (state as TransactionLoadedState).selectedMonth
        : now.month;

    _emitLoadedState(event.transactions, year, month, emit);
  }

  void _onFilterMonth(
    FilterMonthEvent event,
    Emitter<TransactionState> emit,
  ) {
    if (state is TransactionLoadedState) {
      final curr = state as TransactionLoadedState;
      _emitLoadedState(curr.transactions, event.year, event.month, emit);
    }
  }

  Future<void> _onAddTransaction(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    if (state is TransactionLoadedState) {
      final curr = state as TransactionLoadedState;
      emit(curr.copyWith(isSubmitting: true, actionSuccess: null));
    }
    try {
      await transactionRepository.addTransaction(
        event.transaction,
        destinationWalletId: event.destinationWalletId,
      );
      syncEngine?.triggerSync();
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(isSubmitting: false, actionSuccess: true));
      }
    } catch (e) {
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(
          isSubmitting: false,
          actionSuccess: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      await transactionRepository.deleteTransaction(event.transaction);
      syncEngine?.triggerSync();
    } catch (e) {
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(errorMessage: e.toString()));
      }
    }
  }

  void _emitLoadedState(
    List<TransactionEntity> allTx,
    int year,
    int month,
    Emitter<TransactionState> emit,
  ) {
    final monthly = allTx.where((t) {
      return t.date.year == year && t.date.month == month;
    }).toList();

    double income = 0;
    double expense = 0;
    for (final t in monthly) {
      if (t.type == 'thu') {
        income += t.amount;
      } else if (t.type == 'chi') {
        expense += t.amount;
      }
    }

    emit(TransactionLoadedState(
      transactions: allTx,
      monthlyTransactions: monthly,
      totalIncome: income,
      totalExpense: expense,
      selectedYear: year,
      selectedMonth: month,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Verify `TransactionBloc`**

Run: `cd src/Client-app && flutter analyze`
Expected: No errors in `transaction_bloc.dart`.

- [ ] **Step 5: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/bloc/
git commit -m "feat(transaction): add TransactionBloc, Events, and States"
```

---

### Task 5: Register Dependency Injection in Injection Container

**Files:**
- Modify: `src/Client-app/lib/core/di/injection_container.dart`

**Interfaces:**
- Registers `TransactionLocalDataSource`, `TransactionRepository`, `TransactionBloc` in GetIt.

- [ ] **Step 1: Register Transaction DI**

Check `injection_container.dart` and add transaction singletons and factory:

```dart
// Data source
sl.registerLazySingleton<TransactionLocalDataSource>(
  () => TransactionLocalDataSourceImpl(db: sl()),
);

// Repository
sl.registerLazySingleton<TransactionRepository>(
  () => TransactionRepositoryImpl(localDataSource: sl()),
);

// Bloc
sl.registerFactory(
  () => TransactionBloc(
    transactionRepository: sl(),
    syncEngine: sl<SyncEngine>(),
  ),
);
```

- [ ] **Step 2: Verify `injection_container.dart`**

Run: `cd src/Client-app && flutter analyze`
Expected: PASS with 0 errors.

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/core/di/injection_container.dart
git commit -m "feat(transaction): register transaction dependencies in DI container"
```

---

### Task 6: Connect AddTransactionPage & ChooseCategoryPage to Dynamic Data

**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart`
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/choose_category_page.dart`

**Interfaces:**
- Dynamically fetch wallets using `AppDatabase` / `WalletDao`.
- Dynamically fetch categories using `CategoryDao`.
- Dispatch `AddTransactionEvent` and handle async pop safely.

- [ ] **Step 1: Update `ChooseCategoryPage` to load categories from SQLite**

Update `choose_category_page.dart` to query `db.categoryDao.getAll(idaccount)` and pop with selected category companion or data.

- [ ] **Step 2: Update `AddTransactionPage` to load wallets and save transaction**

Connect `AddTransactionPage` to dynamic `WalletDao` for wallet picking, category selection, numeric parsing, UUID generation, and `AddTransactionEvent` dispatching.

- [ ] **Step 3: Run `flutter analyze` to ensure code cleanliness**

Run: `cd src/Client-app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/pages/
git commit -m "feat(transaction): connect AddTransactionPage and ChooseCategoryPage to local SQLite data"
```
