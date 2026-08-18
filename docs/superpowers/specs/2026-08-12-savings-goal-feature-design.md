# DESIGN SPECIFICATION: SAVINGS GOAL DEPOSIT & TRANSACTION HISTORY FEATURE

> **Date:** 2026-08-12  
> **Status:** APPROVED BY USER  
> **Target Module:** `src/Client-app/lib/features/goal/` & `src/Client-app/lib/core/database/`

---

## 1. Executive Summary

This specification addresses two key issues in the Savings Goal (Mục tiêu tiết kiệm) feature:
1. **Deposit Money into Goal:** Previously, adding money to a goal only updated `currentAmount` without deducting the source wallet or recording an actual expense transaction.
2. **Transaction History Display:** Currently, the goal detail page displays a single placeholder line for transaction history instead of real transaction records from the SQLite database.

---

## 2. Requirements & Business Rules

### 2.1 Deposit Workflow
* When a user adds money to a goal, they MUST select a **Source Wallet** (`walletId`) from their available wallets.
* The system MUST perform the following atomic actions:
  1. Update Goal `currentAmount = currentAmount + depositAmount` in `GoalDao`.
  2. Deduct Source Wallet balance `balance = balance - depositAmount` in `WalletDao`.
  3. Create an Expense Transaction (`type = 'chi'`) in `TransactionDao` with `note: 'Tích lũy mục tiêu: <Goal Name>'`.
  4. Trigger `SyncEngine.scheduleSync()` to push all 3 pending local records to the PostgreSQL Backend.

### 2.2 Goal Transaction History
* In `GoalDetailPage`, the history section MUST load real transaction records from SQLite filtered by the goal's name or note pattern (`Tích lũy mục tiêu: <Goal Name>`).
* Transactions MUST be displayed in reverse chronological order (newest first) with:
  * Icon `Icons.savings`
  * Date & time of deposit
  * Source wallet name
  * Deposit amount (formatted in VNĐ)

---

## 3. Data & Repository Design

### 3.1 `GoalRepository` Extensions
```dart
abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<GoalEntity?> getGoalById(String id);
  Future<GoalEntity> addGoal({...});
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  });
  Future<List<Transaction>> getGoalTransactions(int idaccount, String goalName);
  Stream<List<Transaction>> watchGoalTransactions(int idaccount, String goalName);
  Future<void> deleteGoal(String id);
}
```

### 3.2 `GoalRepositoryImpl.depositToGoal` Implementation Plan
1. Retrieve current Goal via `localDataSource.getGoalById(goalId)`.
2. Compute `newGoalAmount = goal.currentAmount + depositAmount`.
3. Call `localDataSource.updateGoalAmount(goalId, newGoalAmount)`.
4. Retrieve Wallet via `db.walletDao.getById(walletId)`.
5. Compute `newWalletBalance = wallet.balance - depositAmount`.
6. Call `db.walletDao.updateBalance(walletId, newWalletBalance)`.
7. Insert Transaction into `db.transactionDao`:
   ```dart
   TransactionsCompanion.insert(
     id: const Uuid().v4(),
     idaccount: idaccount,
     walletId: walletId,
     amount: depositAmount,
     type: 'chi',
     note: Value('Tích lũy mục tiêu: $goalName'),
     date: DateTime.now(),
     syncStatus: const Value('pending'),
     updatedAt: DateTime.now(),
   )
   ```
8. Invoke `syncEngine?.scheduleSync()`.

---

## 4. UI Specification

### 4.1 Deposit Modal BottomSheet (`GoalDetailPage._showDepositDialog`)
* Input field for deposit amount with auto-focus and digit formatting.
* Dropdown/Selector for Source Wallet (`walletDao.getAll(idaccount)` with fallback to `getAllNonDeleted()`).
* Submit button *"Xác nhận gửi tiết kiệm"*.

### 4.2 Goal History List (`GoalDetailPage._buildHistorySection`)
* Uses `StreamBuilder<List<Transaction>>` observing `repository.watchGoalTransactions(idaccount, goalName)`.
* Empty state: "Chưa có khoản tích lũy nào."
* Item tile: Icon + Wallet Name + Date + `+Amount đ`.

---

## 5. Verification & Testing Strategy

1. **Unit Tests:**
   * Test `GoalRepositoryImpl.depositToGoal`: verifies goal amount updated, wallet balance deducted, transaction created, and sync engine scheduled.
2. **Integration / E2E Tests:**
   * Test full deposit flow in `test/features/goal/e2e_goal_flow_test.dart`.
