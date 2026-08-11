# Goal Offline Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement offline-first Goal management allowing users to create and view savings goals locally in SQLite (`Goals` table) with background sync queueing via `SyncEngine`.

**Architecture:** Data layer (`GoalEntity`, `GoalLocalDataSource`, `GoalRepositoryImpl`) interacts with Drift SQLite `GoalDao` and triggers `SyncEngine.notifyDataChanged()`. State management uses `GoalCubit` to handle `GoalLoaded` and mutation operations. Presentation layer (`GoalAddPage`, `GoalPage`) connects to `GoalCubit`.

**Tech Stack:** Flutter, Flutter Bloc / Cubit, Drift (SQLite), GetIt (DI), Equatable.

## Global Constraints
- Target directory: `lib/features/goal/`
- Zero warnings/errors on `flutter analyze`
- All mutations must call `syncEngine.notifyDataChanged()` to push pending changes to `SyncOutboxTable`

---

### Task 1: Goal Data Layer (Model, DataSource & Repository)

**Files:**
- Create: `lib/features/goal/data/models/goal_entity.dart`
- Create: `lib/features/goal/data/datasources/goal_local_data_source.dart`
- Create: `lib/features/goal/data/repositories/goal_repository.dart`
- Create: `lib/features/goal/data/repositories/goal_repository_impl.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`db.goalDao`), `SyncEngine`
- Produces: `GoalEntity`, `GoalLocalDataSource`, `GoalRepository`

- [ ] **Step 1: Create `GoalEntity`**

Create `lib/features/goal/data/models/goal_entity.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

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

  const GoalEntity({
    required this.id,
    required this.idaccount,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.icon = 'flag',
    this.colour = '#4CAF50',
    this.note = '',
    this.isCompleted = false,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  factory GoalEntity.fromDrift(Goal data) {
    return GoalEntity(
      id: data.id,
      idaccount: data.idaccount,
      name: data.name,
      targetAmount: data.targetAmount,
      currentAmount: data.currentAmount,
      targetDate: data.targetDate,
      icon: data.icon,
      colour: data.colour,
      note: data.note,
      isCompleted: data.isCompleted,
      isDeleted: data.isDeleted,
      syncStatus: data.syncStatus,
      updatedAt: data.updatedAt,
    );
  }

  GoalsCompanion toCompanion() {
    return GoalsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: Value(targetDate),
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      isCompleted: Value(isCompleted),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        idaccount,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        icon,
        colour,
        note,
        isCompleted,
        isDeleted,
        syncStatus,
        updatedAt,
      ];
}
```

- [ ] **Step 2: Create `GoalLocalDataSource`**

Create `lib/features/goal/data/datasources/goal_local_data_source.dart`:
```dart
import '../../../../core/database/app_database.dart';
import '../models/goal_entity.dart';

abstract class GoalLocalDataSource {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<void> insertGoal(GoalEntity goal);
  Future<void> updateGoalAmount(String id, double newAmount);
  Future<void> deleteGoal(String id);
}

class GoalLocalDataSourceImpl implements GoalLocalDataSource {
  final AppDatabase db;

  GoalLocalDataSourceImpl({required this.db});

  @override
  Future<List<GoalEntity>> getGoals(int idaccount) async {
    final list = await db.goalDao.getAll(idaccount);
    return list.map((g) => GoalEntity.fromDrift(g)).toList();
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    return db.goalDao
        .watchAll(idaccount)
        .map((list) => list.map((g) => GoalEntity.fromDrift(g)).toList());
  }

  @override
  Future<void> insertGoal(GoalEntity goal) async {
    await db.goalDao.insert(goal.toCompanion());
  }

  @override
  Future<void> updateGoalAmount(String id, double newAmount) async {
    await db.goalDao.updateAmount(id, newAmount);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await db.goalDao.softDelete(id);
  }
}
```

- [ ] **Step 3: Create `GoalRepository` & `GoalRepositoryImpl`**

Create `lib/features/goal/data/repositories/goal_repository.dart`:
```dart
import '../models/goal_entity.dart';

abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String icon = 'flag',
    String colour = '#4CAF50',
    String note = '',
  });
  Future<void> updateAmount({required String id, required double newAmount});
  Future<void> deleteGoal(String id);
}
```

Create `lib/features/goal/data/repositories/goal_repository_impl.dart`:
```dart
import 'package:uuid/uuid.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/goal_local_data_source.dart';
import '../models/goal_entity.dart';
import 'goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource localDataSource;
  final SyncEngine syncEngine;

  GoalRepositoryImpl({
    required this.localDataSource,
    required this.syncEngine,
  });

  @override
  Future<List<GoalEntity>> getGoals(int idaccount) {
    return localDataSource.getGoals(idaccount);
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    return localDataSource.watchGoals(idaccount);
  }

  @override
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String icon = 'flag',
    String colour = '#4CAF50',
    String note = '',
  }) async {
    final goal = GoalEntity(
      id: const Uuid().v4(),
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      targetDate: targetDate,
      icon: icon,
      colour: colour,
      note: note,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    );

    await localDataSource.insertGoal(goal);
    syncEngine.notifyDataChanged();
    return goal;
  }

  @override
  Future<void> updateAmount({required String id, required double newAmount}) async {
    await localDataSource.updateGoalAmount(id, newAmount);
    syncEngine.notifyDataChanged();
  }

  @override
  Future<void> deleteGoal(String id) async {
    await localDataSource.deleteGoal(id);
    syncEngine.notifyDataChanged();
  }
}
```

- [ ] **Step 4: Verify static analysis for Data Layer**

Run: `flutter analyze lib/features/goal/data/`
Expected: No issues found!

- [ ] **Step 5: Commit Data Layer**

```bash
git add lib/features/goal/data/
git commit -m "feat(goal): add GoalEntity, GoalLocalDataSource, and GoalRepositoryImpl"
```

---

### Task 2: Goal State Management (`GoalCubit` & `GoalState`)

**Files:**
- Create: `lib/features/goal/presentation/bloc/goal_state.dart`
- Create: `lib/features/goal/presentation/bloc/goal_cubit.dart`

**Interfaces:**
- Consumes: `GoalRepository`, `GoalEntity`
- Produces: `GoalCubit`, `GoalState`

- [ ] **Step 1: Create `GoalState`**

Create `lib/features/goal/presentation/bloc/goal_state.dart`:
```dart
part of 'goal_cubit.dart';

abstract class GoalState extends Equatable {
  const GoalState();

  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {
  const GoalInitial();
}

class GoalLoading extends GoalState {
  const GoalLoading();
}

class GoalLoaded extends GoalState {
  final List<GoalEntity> goals;
  final double totalTargetAmount;
  final double totalCurrentAmount;

  const GoalLoaded({
    required this.goals,
    required this.totalTargetAmount,
    required this.totalCurrentAmount,
  });

  @override
  List<Object?> get props => [goals, totalTargetAmount, totalCurrentAmount];
}

class GoalOperating extends GoalState {
  final List<GoalEntity> goals;
  const GoalOperating(this.goals);

  @override
  List<Object?> get props => [goals];
}

class GoalOperationSuccess extends GoalState {
  final String message;
  const GoalOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class GoalError extends GoalState {
  final String message;
  const GoalError(this.message);

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 2: Create `GoalCubit`**

Create `lib/features/goal/presentation/bloc/goal_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';

part 'goal_state.dart';

class GoalCubit extends Cubit<GoalState> {
  final GoalRepository _repository;

  GoalCubit({required GoalRepository repository})
      : _repository = repository,
        super(const GoalInitial());

  Future<void> loadGoals(int idaccount) async {
    emit(const GoalLoading());
    try {
      final goals = await _repository.getGoals(idaccount);
      final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
      final totalCurrent = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);

      emit(GoalLoaded(
        goals: goals,
        totalTargetAmount: totalTarget,
        totalCurrentAmount: totalCurrent,
      ));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String icon = 'flag',
    String colour = '#4CAF50',
    String note = '',
  }) async {
    try {
      await _repository.addGoal(
        idaccount: idaccount,
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        icon: icon,
        colour: colour,
        note: note,
      );
      emit(const GoalOperationSuccess('Tạo mục tiêu thành công!'));
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> updateAmount({
    required int idaccount,
    required String id,
    required double newAmount,
  }) async {
    try {
      await _repository.updateAmount(id: id, newAmount: newAmount);
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> deleteGoal({required int idaccount, required String id}) async {
    try {
      await _repository.deleteGoal(id);
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }
}
```

- [ ] **Step 3: Verify static analysis for State Layer**

Run: `flutter analyze lib/features/goal/presentation/bloc/`
Expected: No issues found!

- [ ] **Step 4: Commit State Layer**

```bash
git add lib/features/goal/presentation/bloc/
git commit -m "feat(goal): add GoalCubit and GoalState"
```

---

### Task 3: Dependency Injection Setup for Goal Module

**Files:**
- Modify: `lib/core/di/injection_container.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `SyncEngine`
- Produces: Registered `GoalLocalDataSource`, `GoalRepository`, `GoalCubit` in GetIt

- [ ] **Step 1: Update `injection_container.dart`**

Modify `lib/core/di/injection_container.dart`:
```dart
// Add imports:
import '../../features/goal/data/datasources/goal_local_data_source.dart';
import '../../features/goal/data/repositories/goal_repository.dart';
import '../../features/goal/data/repositories/goal_repository_impl.dart';
import '../../features/goal/presentation/bloc/goal_cubit.dart';

// Inside setupDependencies():
  // ── 7. Features — Goal ───────────────────────────────────────────────────
  sl.registerLazySingleton<GoalLocalDataSource>(
    () => GoalLocalDataSourceImpl(db: sl()),
  );
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepositoryImpl(localDataSource: sl(), syncEngine: sl()),
  );
  sl.registerFactory<GoalCubit>(
    () => GoalCubit(repository: sl()),
  );
```

- [ ] **Step 2: Verify static analysis for DI**

Run: `flutter analyze lib/core/di/injection_container.dart`
Expected: No issues found!

- [ ] **Step 3: Commit DI updates**

```bash
git add lib/core/di/injection_container.dart
git commit -m "feat(di): register GoalLocalDataSource, GoalRepository, and GoalCubit"
```

---

### Task 4: UI Integration (`GoalAddPage` & `GoalPage`)

**Files:**
- Modify: `lib/features/goal/presentation/pages/goal_add_page.dart`
- Modify: `lib/features/goal/presentation/pages/goal_page.dart`

**Interfaces:**
- Consumes: `GoalCubit`, `GoalState`, `GoalEntity`, `AuthBloc` (for `user.idaccount`)

- [ ] **Step 1: Wire up `GoalAddPage` form & save button**

Update `lib/features/goal/presentation/pages/goal_add_page.dart`:
- Add `TextEditingController`s for `_nameController` and `_targetAmountController`.
- Add `DateTime _targetDate`.
- Connect "Lưu" button & "Tạo Mục Tiêu & Bật Lập Lịch Tự Động" button to submit handler:
```dart
  void _submitForm() {
    final name = _nameController.text.trim();
    final amountText = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(amountText) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên mục tiêu')),
      );
      return;
    }
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền mục tiêu hợp lệ')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final idaccount = (authState is AuthSuccess) ? authState.user.idaccount : 1;

    context.read<GoalCubit>().addGoal(
          idaccount: idaccount,
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo mục tiêu tiết kiệm!')),
    );
    context.pop();
  }
```

- [ ] **Step 2: Wire up `GoalPage` to list real goals from `GoalCubit`**

Update `lib/features/goal/presentation/pages/goal_page.dart`:
- Wrap `GoalPage` body with `BlocBuilder<GoalCubit, GoalState>`.
- In `initState()`, trigger `context.read<GoalCubit>().loadGoals(idaccount)`.
- Render goal cards dynamically:
  - Total Target & Total Saved in Header Card.
  - Goals List with real Goal names, progress bars (`currentAmount / targetAmount`), target dates, and target amounts.

- [ ] **Step 3: Run `flutter analyze` across entire project**

Run: `flutter analyze`
Expected: 0 errors/warnings (except pre-existing drift/web.dart info).

- [ ] **Step 4: Commit UI integration**

```bash
git add lib/features/goal/presentation/pages/
git commit -m "feat(goal): connect GoalAddPage and GoalPage to GoalCubit for offline goal management"
```
