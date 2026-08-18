# Bill Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Bill feature in Client-app (Flutter + Drift SQLite + BLoC), turning the mock UI into a fully functional offline-first bill management system with payment transaction creation, auto-recurrence, and sync engine support.

**Architecture:** Clean Architecture + BLoC + Drift SQLite. The Data Layer encapsulates `BillDao`, `TransactionDao`, and `WalletDao`. `BillRepositoryImpl` handles complex business transactions (paying bills, generating next cycle bills, deducting wallet balances). `BillBloc` manages UI state and streams real-time updates from SQLite.

**Tech Stack:** Dart, Flutter, Drift (SQLite), flutter_bloc, go_router, uuid.

## Global Constraints

- Follow Clean Architecture: Data Layer (`datasources`, `repositories`) -> Presentation Layer (`bloc`, `pages`, `widgets`).
- Offline-first: SQLite (`BillDao`) is the source of truth for Client-app. Set `syncStatus = 'pending'` and `updatedAt = DateTime.now()` on write operations.
- Payment logic: Paying a bill marks `isPaid = true`, inserts an expense `Transaction` linked to the selected wallet, updates wallet balance, and creates the next period's bill if `recurrence != 'once'`.

---

### Task 1: Create Data Layer (DataSources & Repository)

**Files:**
- Create: `src/Client-app/lib/features/bill/data/datasources/bill_local_datasource.dart`
- Create: `src/Client-app/lib/features/bill/data/repositories/bill_repository.dart`
- Create: `src/Client-app/lib/features/bill/data/repositories/bill_repository_impl.dart`
- Test: `src/Client-app/test/features/bill/data/repositories/bill_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `BillDao`, `TransactionDao`, `WalletDao`
- Produces: `BillRepository.watchBills`, `BillRepository.addBill`, `BillRepository.editBill`, `BillRepository.deleteBill`, `BillRepository.payBill`

- [ ] **Step 1: Write failing repository test**

Create `src/Client-app/test/features/bill/data/repositories/bill_repository_impl_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillLocalDataSource dataSource;
  late BillRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = BillLocalDataSource(db);
    repository = BillRepositoryImpl(dataSource: dataSource, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('payBill marks bill paid, creates transaction, updates wallet, and generates next bill', () async {
    // 1. Setup initial wallet and bill
    const walletId = 'wallet-1';
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: walletId,
        idaccount: 1,
        name: 'Ví chính',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    const billId = 'bill-1';
    final dueDate = DateTime(2026, 8, 20);
    await db.billDao.insert(
      BillsCompanion.insert(
        id: billId,
        idaccount: 1,
        name: 'Tiền điện',
        amount: 200000.0,
        dueDate: dueDate,
        recurrence: const Value('monthly'),
        updatedAt: DateTime.now(),
      ),
    );

    final bill = (await repository.getBills(1)).first;

    // 2. Pay bill
    await repository.payBill(bill: bill, walletId: walletId, idaccount: 1);

    // 3. Assert current bill is paid
    final bills = await repository.getBills(1);
    final updatedPaidBill = bills.firstWhere((b) => b.id == billId);
    expect(updatedPaidBill.isPaid, true);

    // 4. Assert transaction was created
    final transactions = await db.transactionDao.getAll(1);
    expect(transactions.length, 1);
    expect(transactions.first.amount, 200000.0);
    expect(transactions.first.walletId, walletId);
    expect(transactions.first.type, 'chi');

    // 5. Assert wallet balance was deducted (1000000 - 200000 = 800000)
    final wallet = await db.walletDao.getById(walletId);
    expect(wallet?.balance, 800000.0);

    // 6. Assert next period bill was created (due in Sept 2026)
    expect(bills.length, 2);
    final nextBill = bills.firstWhere((b) => b.id != billId);
    expect(nextBill.isPaid, false);
    expect(nextBill.name, 'Tiền điện');
    expect(nextBill.dueDate.month, 9);
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/bill/data/repositories/bill_repository_impl_test.dart`
Expected: FAIL (files missing/unimplemented)

- [ ] **Step 3: Implement BillLocalDataSource and BillRepositoryImpl**

Create `src/Client-app/lib/features/bill/data/datasources/bill_local_datasource.dart`:
```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class BillLocalDataSource {
  final AppDatabase db;

  BillLocalDataSource(this.db);

  Stream<List<Bill>> watchBills(int idaccount) {
    return db.billDao.watchAll(idaccount);
  }

  Future<List<Bill>> getBills(int idaccount) {
    return db.billDao.getAll(idaccount);
  }

  Future<Bill?> getBillById(String id) async {
    final list = await db.billDao.getPending();
    try {
      return list.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertBill(BillsCompanion bill) {
    return db.billDao.insert(bill);
  }

  Future<void> markPaid(String id) {
    return db.billDao.markPaid(id);
  }

  Future<void> softDeleteBill(String id) {
    return db.billDao.softDelete(id);
  }
}
```

Create `src/Client-app/lib/features/bill/data/repositories/bill_repository.dart`:
```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

abstract class BillRepository {
  Stream<List<Bill>> watchBills(int idaccount);
  Future<List<Bill>> getBills(int idaccount);
  Future<void> addBill(BillsCompanion bill);
  Future<void> editBill(BillsCompanion bill);
  Future<void> deleteBill(String id);
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
  });
}
```

Create `src/Client-app/lib/features/bill/data/repositories/bill_repository_impl.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../datasources/bill_local_datasource.dart';
import 'bill_repository.dart';

class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource dataSource;
  final AppDatabase db;

  BillRepositoryImpl({required this.dataSource, required this.db});

  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    return dataSource.watchBills(idaccount);
  }

  @override
  Future<List<Bill>> getBills(int idaccount) {
    return dataSource.getBills(idaccount);
  }

  @override
  Future<void> addBill(BillsCompanion bill) {
    return dataSource.insertBill(bill);
  }

  @override
  Future<void> editBill(BillsCompanion bill) {
    return dataSource.insertBill(bill);
  }

  @override
  Future<void> deleteBill(String id) {
    return dataSource.softDeleteBill(id);
  }

  @override
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
  }) async {
    final now = DateTime.now();

    // 1. Mark bill as paid
    await dataSource.markPaid(bill.id);

    // 2. Create expense transaction
    final transactionId = const Uuid().v4();
    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: transactionId,
        idaccount: idaccount,
        walletId: walletId,
        amount: bill.amount,
        type: 'chi',
        note: Value('Thanh toán hóa đơn: ${bill.name}'),
        date: now,
        syncStatus: const Value('pending'),
        updatedAt: now,
      ),
    );

    // 3. Deduct wallet balance
    final wallet = await db.walletDao.getById(walletId);
    if (wallet != null) {
      final newBalance = wallet.balance - bill.amount;
      await db.walletDao.updateBalance(walletId, newBalance);
    }

    // 4. Generate next period bill if recurring
    final recurrence = bill.recurrence ?? 'once';
    if (recurrence != 'once') {
      DateTime nextDueDate = bill.dueDate;
      if (recurrence == 'weekly') {
        nextDueDate = bill.dueDate.add(const Duration(days: 7));
      } else if (recurrence == 'monthly') {
        nextDueDate = DateTime(
          bill.dueDate.year,
          bill.dueDate.month + 1,
          bill.dueDate.day,
          bill.dueDate.hour,
          bill.dueDate.minute,
        );
      } else if (recurrence == 'yearly') {
        nextDueDate = DateTime(
          bill.dueDate.year + 1,
          bill.dueDate.month,
          bill.dueDate.day,
          bill.dueDate.hour,
          bill.dueDate.minute,
        );
      }

      final nextBillId = const Uuid().v4();
      await dataSource.insertBill(
        BillsCompanion.insert(
          id: nextBillId,
          idaccount: idaccount,
          name: bill.name,
          amount: bill.amount,
          dueDate: nextDueDate,
          isPaid: const Value(false),
          recurrence: Value(recurrence),
          icon: Value(bill.icon),
          colour: Value(bill.colour),
          note: Value(bill.note),
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/features/bill/data/repositories/bill_repository_impl_test.dart`
Expected: PASS

- [ ] **Step 5: Commit Data Layer**

```bash
git add lib/features/bill/data/ test/features/bill/data/
git commit -m "feat(bill): implement BillLocalDataSource and BillRepositoryImpl"
```

---

### Task 2: Create State Management Layer (BillBloc)

**Files:**
- Create: `src/Client-app/lib/features/bill/presentation/bloc/bill_event.dart`
- Create: `src/Client-app/lib/features/bill/presentation/bloc/bill_state.dart`
- Create: `src/Client-app/lib/features/bill/presentation/bloc/bill_bloc.dart`
- Test: `src/Client-app/test/features/bill/presentation/bloc/bill_bloc_test.dart`

**Interfaces:**
- Consumes: `BillRepository`
- Produces: `BillBloc`, `LoadBillsEvent`, `AddBillEvent`, `EditBillEvent`, `DeleteBillEvent`, `PayBillEvent`, `BillState`

- [ ] **Step 1: Write failing bloc test**

Create `src/Client-app/test/features/bill/presentation/bloc/bill_bloc_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_state.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillBloc bloc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    bloc = BillBloc(repository: repository);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  test('LoadBillsEvent emits BillLoaded with correct unpaid summary', () async {
    await db.billDao.insert(
      BillsCompanion.insert(
        id: '1',
        idaccount: 1,
        name: 'Internet',
        amount: 300000.0,
        dueDate: DateTime.now(),
        isPaid: const Value(false),
        updatedAt: DateTime.now(),
      ),
    );

    bloc.add(LoadBillsEvent(idaccount: 1));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<BillLoaded>().having(
          (s) => s.totalUnpaidAmount,
          'totalUnpaidAmount',
          300000.0,
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/bill/presentation/bloc/bill_bloc_test.dart`
Expected: FAIL (Bloc files not created)

- [ ] **Step 3: Implement BillBloc, Events, and States**

Create `src/Client-app/lib/features/bill/presentation/bloc/bill_event.dart`:
```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

abstract class BillEvent {}

class LoadBillsEvent extends BillEvent {
  final int idaccount;
  LoadBillsEvent({required this.idaccount});
}

class AddBillEvent extends BillEvent {
  final BillsCompanion bill;
  AddBillEvent({required this.bill});
}

class EditBillEvent extends BillEvent {
  final BillsCompanion bill;
  EditBillEvent({required this.bill});
}

class DeleteBillEvent extends BillEvent {
  final String id;
  DeleteBillEvent({required this.id});
}

class PayBillEvent extends BillEvent {
  final Bill bill;
  final String walletId;
  final int idaccount;

  PayBillEvent({
    required this.bill,
    required this.walletId,
    required this.idaccount,
  });
}
```

Create `src/Client-app/lib/features/bill/presentation/bloc/bill_state.dart`:
```dart
import '../../../../core/database/app_database.dart';

abstract class BillState {}

class BillInitial extends BillState {}

class BillLoading extends BillState {}

class BillLoaded extends BillState {
  final List<Bill> bills;
  final double totalUnpaidAmount;
  final int unpaidCount;

  BillLoaded({
    required this.bills,
    required this.totalUnpaidAmount,
    required this.unpaidCount,
  });
}

class BillOperationSuccess extends BillState {
  final String message;
  BillOperationSuccess(this.message);
}

class BillError extends BillState {
  final String message;
  BillError(this.message);
}
```

Create `src/Client-app/lib/features/bill/presentation/bloc/bill_bloc.dart`:
```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/bill_repository.dart';
import 'bill_event.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final BillRepository repository;
  StreamSubscription? _subscription;

  BillBloc({required this.repository}) : super(BillInitial()) {
    on<LoadBillsEvent>(_onLoadBills);
    on<AddBillEvent>(_onAddBill);
    on<EditBillEvent>(_onEditBill);
    on<DeleteBillEvent>(_onDeleteBill);
    on<PayBillEvent>(_onPayBill);
  }

  Future<void> _onLoadBills(
    LoadBillsEvent event,
    Emitter<BillState> emit,
  ) async {
    emit(BillLoading());
    await _subscription?.cancel();
    _subscription = repository.watchBills(event.idaccount).listen((bills) {
      final unpaidBills = bills.where((b) => b.isPaid != true);
      final totalUnpaid = unpaidBills.fold(
        0.0,
        (sum, b) => sum + b.amount,
      );
      emit(
        BillLoaded(
          bills: bills,
          totalUnpaidAmount: totalUnpaid,
          unpaidCount: unpaidBills.length,
        ),
      );
    });
  }

  Future<void> _onAddBill(
    AddBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.addBill(event.bill);
      emit(BillOperationSuccess('Tạo hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể tạo hóa đơn: $e'));
    }
  }

  Future<void> _onEditBill(
    EditBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.editBill(event.bill);
      emit(BillOperationSuccess('Cập nhật hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể cập nhật hóa đơn: $e'));
    }
  }

  Future<void> _onDeleteBill(
    DeleteBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.deleteBill(event.id);
      emit(BillOperationSuccess('Xóa hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể xóa hóa đơn: $e'));
    }
  }

  Future<void> _onPayBill(
    PayBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.payBill(
        bill: event.bill,
        walletId: event.walletId,
        idaccount: event.idaccount,
      );
      emit(BillOperationSuccess('Thanh toán hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Thanh toán thất bại: $e'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Run bloc test to verify pass**

Run: `flutter test test/features/bill/presentation/bloc/bill_bloc_test.dart`
Expected: PASS

- [ ] **Step 5: Commit BLoC Layer**

```bash
git add lib/features/bill/presentation/bloc/ test/features/bill/presentation/bloc/
git commit -m "feat(bill): add BillBloc, events, and states"
```

---

### Task 3: Refactor UI Pages & Wallet Selection BottomSheet

**Files:**
- Create: `src/Client-app/lib/features/bill/presentation/widgets/wallet_selection_bottom_sheet.dart`
- Modify: `src/Client-app/lib/features/bill/presentation/pages/bill_page.dart`
- Modify: `src/Client-app/lib/features/bill/presentation/pages/bill_add_page.dart`
- Modify: `src/Client-app/lib/features/bill/presentation/pages/bill_edit_page.dart`
- Modify: `src/Client-app/lib/features/bill/presentation/pages/bill_delete_page.dart`
- Modify: `src/Client-app/lib/core/constants/app_router.dart`

- [ ] **Step 1: Implement WalletSelectionBottomSheet**

Create `src/Client-app/lib/features/bill/presentation/widgets/wallet_selection_bottom_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';

class WalletSelectionBottomSheet extends StatelessWidget {
  final List<Wallet> wallets;
  final Function(Wallet) onSelected;

  const WalletSelectionBottomSheet({
    super.key,
    required this.wallets,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn ví thanh toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (wallets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Không tìm thấy ví nào khả dụng.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              itemCount: wallets.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                  ),
                  title: Text(
                    wallet.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Số dư: ${wallet.balance.toStringAsFixed(0)}đ',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(wallet);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Refactor BillPage to use BillBloc and SQLite stream**

Connect `BillPage` in `src/Client-app/lib/features/bill/presentation/pages/bill_page.dart` to `BillBloc`, showing real `BillLoaded` items, formatting amounts, displaying delete confirm dialog, and triggering `WalletSelectionBottomSheet` on Pay action.

- [ ] **Step 3: Refactor BillAddPage and BillEditPage**

Update `bill_add_page.dart` and `bill_edit_page.dart` to insert and update real `BillsCompanion` instances via `BillBloc`.

- [ ] **Step 4: Register BillBloc provider in app_router.dart or App level**

Ensure `/bills`, `/bills/add`, `/bills/:id/edit` pass `BillBloc` or initialize `BillBloc` via `BlocProvider`.

- [ ] **Step 5: Run flutter analyze to verify no syntax errors**

Run: `flutter analyze`
Expected: 0 errors

- [ ] **Step 6: Commit UI Refactoring**

```bash
git add lib/features/bill/ lib/core/constants/app_router.dart
git commit -m "feat(bill): connect Bill UI pages to BillBloc and SQLite"
```

---

### Task 4: End-to-End Integration Verification

- [ ] **Step 1: Write E2E integration test for Bill lifecycle**

Create `src/Client-app/test/features/bill/e2e_bill_flow_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_state.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillBloc bloc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    bloc = BillBloc(repository: repository);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  test('Full Bill Lifecycle: Create -> Load -> Pay -> Check Sync Status', () async {
    // 1. Create wallet
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví Thử Nghiệm',
        balance: const Value(500000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Bill via Bloc
    final dueDate = DateTime.now().add(const Duration(days: 3));
    bloc.add(
      AddBillEvent(
        bill: BillsCompanion.insert(
          id: 'b1',
          idaccount: 1,
          name: 'Hóa đơn Internet',
          amount: 200000.0,
          dueDate: dueDate,
          recurrence: const Value('monthly'),
          syncStatus: const Value('pending'),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    // 3. Start Loading Bills
    bloc.add(LoadBillsEvent(idaccount: 1));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<BillLoaded>().having((s) => s.bills.length, 'bills count', 1),
      ),
    );

    // 4. Pay Bill
    final loadedState = bloc.state as BillLoaded;
    final billToPay = loadedState.bills.first;
    bloc.add(
      PayBillEvent(
        bill: billToPay,
        walletId: 'w1',
        idaccount: 1,
      ),
    );

    // 5. Verify pending bills in database for sync engine
    final pendingBills = await db.billDao.getPending();
    expect(pendingBills.isNotEmpty, true);
  });
}
```

- [ ] **Step 2: Run all bill unit and integration tests**

Run: `flutter test test/features/bill/`
Expected: ALL PASS

- [ ] **Step 3: Commit Final Verification**

```bash
git add test/features/bill/
git commit -m "test(bill): add end-to-end bill flow integration test"
```
