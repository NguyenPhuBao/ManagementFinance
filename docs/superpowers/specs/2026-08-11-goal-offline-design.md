# Goal Offline Feature Design Document

**Date:** 2026-08-11  
**Status:** Approved  
**Scope:** Client App Goal Module (Offline-First via Drift SQLite & SyncEngine)

---

## 1. Overview
The Goal feature allows users to create, manage, and track financial savings goals (e.g. buying a MacBook, emergency fund). This design enables full offline capabilities for adding and listing goals, storing records directly in the local Drift SQLite database (`Goals` table), and queuing mutations in `SyncOutboxTable` for automatic background synchronization when online.

---

## 2. Architecture & Data Flow

```
[GoalAddPage / GoalPage (UI)]
       │
       ▼
  [GoalCubit]
       │
       ▼
[GoalRepositoryImpl]
   ├──► [GoalLocalDataSource] ──► [Drift SQLite: GoalDao & Goals Table]
   └──► [SyncEngine]           ──► [SyncOutboxTable Queue]
```

---

## 3. Data Layer

### 3.1. Entity: `GoalEntity`
**File:** `lib/features/goal/data/models/goal_entity.dart`
```dart
class GoalEntity extends Equatable {
  final String id;
  final int idaccount;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String icon;
  final String colour;
  final String note;
  final bool isCompleted;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  // Constructors, toCompanion, fromDrift, copyWith
}
```

### 3.2. Local Data Source: `GoalLocalDataSource`
**Files:** 
- `lib/features/goal/data/datasources/goal_local_data_source.dart`

Methods:
- `Future<List<GoalEntity>> getGoals(int idaccount)`
- `Stream<List<GoalEntity>> watchGoals(int idaccount)`
- `Future<void> addGoal(GoalEntity goal)`
- `Future<void> updateGoalAmount(String id, double newAmount)`
- `Future<void> deleteGoal(String id)`

### 3.3. Repository: `GoalRepository`
**Files:**
- `lib/features/goal/data/repositories/goal_repository.dart`
- `lib/features/goal/data/repositories/goal_repository_impl.dart`

Methods:
- `Future<List<GoalEntity>> getGoals(int idaccount)`
- `Stream<List<GoalEntity>> watchGoals(int idaccount)`
- `Future<GoalEntity> addGoal({required int idaccount, required String name, required double targetAmount, required DateTime targetDate, String? icon, String? colour, String? note})`
- `Future<void> updateAmount({required String id, required double newAmount})`
- `Future<void> deleteGoal(String id)`

---

## 4. State Management Layer

### 4.1. `GoalCubit` & `GoalState`
**Files:**
- `lib/features/goal/presentation/bloc/goal_cubit.dart`
- `lib/features/goal/presentation/bloc/goal_state.dart`

States:
- `GoalInitial`: Initial state
- `GoalLoading`: Loading goals
- `GoalLoaded`: Contains `List<GoalEntity> goals`, `double totalTargetAmount`, `double totalCurrentAmount`
- `GoalError`: Contains error message string

Operations:
- `Future<void> loadGoals(int idaccount)`
- `Future<void> addGoal(...)`
- `Future<void> updateAmount(...)`
- `Future<void> deleteGoal(...)`

---

## 5. Presentation Layer (UI Integration)

### 5.1. `GoalAddPage`
- Add form controllers: `nameController`, `targetAmountController`, `targetDateNotifier`.
- On Save tap:
  1. Validate name & target amount (> 0).
  2. Parse date.
  3. Call `context.read<GoalCubit>().addGoal(...)`.
  4. Display success snackbar / pop back to `GoalPage`.

### 5.2. `GoalPage`
- Wrap body in `BlocBuilder<GoalCubit, GoalState>`.
- Render goal cards using real `GoalEntity` data from SQLite.
- Provide progress bar percentage (`currentAmount / targetAmount`).
- Display empty state if `goals.isEmpty`.

---

## 6. Dependency Injection
Update `lib/core/di/injection_container.dart`:
- Register `GoalLocalDataSource` (LazySingleton).
- Register `GoalRepository` (LazySingleton).
- Register `GoalCubit` (Factory).

---

## 7. Verification Plan
1. **Unit / Static Analysis**: Run `flutter analyze` ensuring zero warnings/errors.
2. **Offline Manual Test**:
   - Disconnect network / stop backend.
   - Navigate to Goal Add Page -> Create new goal (e.g. "Mua Laptop MacBook", 40.000.000đ).
   - Tap Save -> Verify goal is immediately displayed on Goal Page with 0% progress bar.
   - Restart app -> Goal persists from SQLite database.
