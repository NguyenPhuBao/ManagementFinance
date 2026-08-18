# Savings Goal Deposit & Transaction History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to deposit money into Savings Goals with source wallet balance deduction, automated transaction creation, real-time transaction history display, and backend sync.

**Architecture:** Clean Architecture with BLoC/Cubit + Repository Pattern + Drift SQLite Local + SyncEngine 2-Way Sync.

**Tech Stack:** Flutter, Dart, Drift (SQLite), flutter_bloc, GetIt, Dio.

## Global Constraints

- Preserve clean architecture boundaries across `data` and `presentation`.
- Dynamically bind user account ID (`idaccount`) from `AuthBloc`.
- Trigger `SyncEngine.scheduleSync()` on all deposit and update actions.

---

### Task 1: Extend Data Layer (GoalRepository & DAOs for Goal Deposits & History)

**Files:**
- Modify: `src/Client-app/lib/features/goal/data/repositories/goal_repository.dart`
- Modify: `src/Client-app/lib/features/goal/data/repositories/goal_repository_impl.dart`
- Modify: `src/Client-app/lib/features/goal/data/datasources/goal_local_data_source.dart`
- Modify: `src/Client-app/lib/core/database/daos/other_daos.dart`
- Modify: `src/Client-app/lib/core/database/daos/transaction_dao.dart`
- Test: `src/Client-app/test/features/goal/data/repositories/goal_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `GoalDao`, `TransactionDao`, `WalletDao`, `SyncEngine`.
- Produces: `GoalRepository.depositToGoal`, `GoalRepository.watchGoalTransactions`.

- [ ] **Step 1: Write failing unit test for depositToGoal**

Create `src/Client-app/test/features/goal/data/repositories/goal_repository_impl_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );

    // Setup initial wallet & goal
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví Tết',
        balance: const Value(5000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.goalDao.insert(
      GoalsCompanion.insert(
        id: 'g1',
        idaccount: 1,
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        currentAmount: const Value(2000000.0),
        targetDate: DateTime.now().add(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('depositToGoal updates goal currentAmount, deducts wallet balance, creates transaction', () async {
    await repository.depositToGoal(
      goalId: 'g1',
      goalName: 'Mua Laptop',
      depositAmount: 1000000.0,
      walletId: 'w1',
      idaccount: 1,
    );

    final goal = await repository.getGoalById('g1');
    expect(goal?.currentAmount, 3000000.0);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, 4000000.0);

    final txs = await db.transactionDao.getAll(1);
    expect(txs.length, 1);
    expect(txs.first.amount, 1000000.0);
    expect(txs.first.note, 'Tích lũy mục tiêu: Mua Laptop');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/goal/data/repositories/goal_repository_impl_test.dart`  
Expected: FAIL with "depositToGoal is not defined".

- [ ] **Step 3: Implement data layer logic**

Update `TransactionDao` in `src/Client-app/lib/core/database/daos/transaction_dao.dart` to add `watchByNotePattern`:
```dart
  Stream<List<Transaction>> watchByNotePattern(int idaccount, String pattern) {
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDeleted.equals(false) &
              t.note.like('%$pattern%'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }
```

Update `GoalRepository` and `GoalRepositoryImpl` to add `depositToGoal` and `watchGoalTransactions`:
```dart
  @override
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  }) async {
    // 1. Update Goal amount
    final goal = await localDataSource.getGoalById(goalId);
    if (goal != null) {
      final newGoalAmount = goal.currentAmount + depositAmount;
      await localDataSource.updateGoalAmount(goalId, newGoalAmount);
    }

    // 2. Deduct wallet balance
    final wallet = await db.walletDao.getById(walletId);
    if (wallet != null) {
      final newBalance = wallet.balance - depositAmount;
      await db.walletDao.updateBalance(walletId, newBalance);
    }

    // 3. Create expense transaction
    final transactionId = const Uuid().v4();
    final now = DateTime.now();
    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: transactionId,
        idaccount: idaccount,
        walletId: walletId,
        amount: depositAmount,
        type: 'chi',
        note: Value('Tích lũy mục tiêu: $goalName'),
        date: now,
        syncStatus: const Value('pending'),
        updatedAt: now,
      ),
    );

    // 4. Schedule Sync
    syncEngine?.scheduleSync();
  }

  @override
  Stream<List<Transaction>> watchGoalTransactions(int idaccount, String goalName) {
    return db.transactionDao.watchByNotePattern(idaccount, 'Tích lũy mục tiêu: $goalName');
  }
```

- [ ] **Step 4: Run unit test to verify it passes**

Run: `flutter test test/features/goal/data/repositories/goal_repository_impl_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/Client-app/lib/features/goal/ src/Client-app/lib/core/database/ test/features/goal/
git commit -m "feat(goal): implement depositToGoal and watchGoalTransactions in data layer"
```

---

### Task 2: Update GoalCubit & GoalDetailPage UI (Wallet Selector & Real Transaction History)

**Files:**
- Modify: `src/Client-app/lib/features/goal/presentation/bloc/goal_cubit.dart`
- Modify: `src/Client-app/lib/features/goal/presentation/pages/goal_detail_page.dart`
- Test: `src/Client-app/test/features/goal/presentation/bloc/goal_cubit_test.dart`

**Interfaces:**
- Consumes: `GoalRepository.depositToGoal`, `GoalRepository.watchGoalTransactions`.
- Produces: UI modal `_showDepositDialog` with Source Wallet picker & `_buildHistorySection` rendering real `StreamBuilder<List<Transaction>>`.

- [ ] **Step 1: Write failing test for GoalCubit depositToGoal**

Create `src/Client-app/test/features/goal/presentation/bloc/goal_cubit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';
import 'package:flowmoney/features/goal/presentation/bloc/goal_cubit.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;
  late GoalCubit cubit;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );
    cubit = GoalCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  test('depositToGoal triggers repository deposit and updates goal state', () async {
    await repository.addGoal(
      idaccount: 1,
      name: 'Đi du lịch',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 30)),
    );

    final goals = await repository.getGoals(1);
    final goalId = goals.first.id;

    await cubit.depositToGoal(
      goalId: goalId,
      goalName: 'Đi du lịch',
      depositAmount: 500000.0,
      walletId: 'w1',
      idaccount: 1,
    );

    final updatedGoal = await repository.getGoalById(goalId);
    expect(updatedGoal?.currentAmount, 500000.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/goal/presentation/bloc/goal_cubit_test.dart`  
Expected: FAIL with "depositToGoal is not defined on GoalCubit".

- [ ] **Step 3: Implement depositToGoal on GoalCubit**

Update `src/Client-app/lib/features/goal/presentation/bloc/goal_cubit.dart`:
```dart
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  }) async {
    try {
      await repository.depositToGoal(
        goalId: goalId,
        goalName: goalName,
        depositAmount: depositAmount,
        walletId: walletId,
        idaccount: idaccount,
      );
      loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }
```

- [ ] **Step 4: Update GoalDetailPage with Wallet Picker & Real History Stream**

In `src/Client-app/lib/features/goal/presentation/pages/goal_detail_page.dart`:
- Fetch wallets via `db.walletDao.getAll(accountId)` with `db.walletDao.getAllNonDeleted()` fallback in `_showDepositDialog`.
- Render Dropdown/Selector for Source Wallet.
- Pass selected `wallet.id` to `_goalRepository.depositToGoal(...)`.
- In `_buildHistorySection()`, use `StreamBuilder<List<Transaction>>` with `_goalRepository.watchGoalTransactions(idaccount, _goal!.name)` to display actual deposit transactions.

- [ ] **Step 5: Run unit tests to verify pass**

Run: `flutter test test/features/goal/presentation/bloc/goal_cubit_test.dart`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/Client-app/lib/features/goal/ test/features/goal/
git commit -m "feat(goal): integrate wallet picker in deposit dialog and stream real transactions in GoalDetailPage"
```

---

### Task 3: End-to-End Integration Verification

**Files:**
- Create: `src/Client-app/test/features/goal/e2e_goal_deposit_test.dart`

- [ ] **Step 1: Write E2E Integration Test**

Create `src/Client-app/test/features/goal/e2e_goal_deposit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Full Goal Lifecycle: Create -> Deposit -> Wallet Deduction -> Pending Sync check', () async {
    // 1. Setup Wallet
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w10',
        idaccount: 1,
        name: 'Ví Tiết Kiệm',
        balance: const Value(10000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Goal
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Mua Quà Tết',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 60)),
    );

    // 3. Deposit money into goal
    await repository.depositToGoal(
      goalId: goal.id,
      goalName: goal.name,
      depositAmount: 2000000.0,
      walletId: 'w10',
      idaccount: 1,
    );

    // 4. Verify Goal amount updated
    final updatedGoal = await repository.getGoalById(goal.id);
    expect(updatedGoal?.currentAmount, 2000000.0);

    // 5. Verify Wallet balance deducted
    final wallet = await db.walletDao.getById('w10');
    expect(wallet?.balance, 8000000.0);

    // 6. Verify Pending Goal & Transaction status for SyncEngine
    final pendingGoals = await db.goalDao.getPending();
    expect(pendingGoals.isNotEmpty, true);

    final pendingTxs = await db.transactionDao.getPending();
    expect(pendingTxs.isNotEmpty, true);
  });
}
```

- [ ] **Step 2: Run all Goal feature tests**

Run: `flutter test test/features/goal/`  
Expected: PASS (All tests passing).

- [ ] **Step 3: Run static analyzer**

Run: `flutter analyze` inside `src/Client-app`  
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add src/Client-app/test/features/goal/
git commit -m "test(goal): add end-to-end integration test for savings goal deposit lifecycle"
```
