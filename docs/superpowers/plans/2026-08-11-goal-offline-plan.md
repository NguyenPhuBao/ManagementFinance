# Implementation Plan - Goal Offline Management Module

**Spec File:** `docs/superpowers/specs/2026-08-11-goal-offline-design.md`  
**Date:** 2026-08-11  
**Architecture:** Offline-First (Drift SQLite, Repository, Cubit, GetIt DI)

---

## User Review Required
> [!IMPORTANT]
> All Goal data operations will be performed locally on SQLite (`Goals` table). Background sync is automatically triggered via `SyncEngine.scheduleSync()`.

---

## Proposed Changes

### Data Layer

#### [NEW] `goal_entity.dart`
- Path: `src/Client-app/lib/features/goal/data/models/goal_entity.dart`
- Implement `GoalEntity` model with `fromDrift`, `toCompanion`, and `copyWith`.

#### [NEW] `goal_local_data_source.dart`
- Path: `src/Client-app/lib/features/goal/data/datasources/goal_local_data_source.dart`
- Implement `GoalLocalDataSource` and `GoalLocalDataSourceImpl` interfacing with `AppDatabase.goalDao`.

#### [NEW] `goal_repository.dart` & `goal_repository_impl.dart`
- Path: `src/Client-app/lib/features/goal/data/repositories/goal_repository.dart`
- Path: `src/Client-app/lib/features/goal/data/repositories/goal_repository_impl.dart`
- Implement `GoalRepository` forwarding calls to local data source and calling `SyncEngine.scheduleSync()`.

---

### Presentation Layer (BLoC / Cubit & Pages)

#### [NEW] `goal_state.dart` & `goal_cubit.dart`
- Path: `src/Client-app/lib/features/goal/presentation/bloc/goal_state.dart`
- Path: `src/Client-app/lib/features/goal/presentation/bloc/goal_cubit.dart`
- Implement Cubit state management for listing, adding, updating amount, and deleting goals.

#### [MODIFY] `injection_container.dart`
- Path: `src/Client-app/lib/core/di/injection_container.dart`
- Register `GoalLocalDataSource`, `GoalRepository`, and `GoalCubit` in DI graph.

#### [MODIFY] `goal_page.dart` & `goal_add_page.dart`
- Path: `src/Client-app/lib/features/goal/presentation/pages/goal_page.dart`
- Path: `src/Client-app/lib/features/goal/presentation/pages/goal_add_page.dart`
- Connect UI to `GoalCubit` with dynamic reactive stream rendering.

---

## Plan Checklist

- [ ] Task 1: Create `GoalEntity` model
- [ ] Task 2: Create `GoalLocalDataSource`
- [ ] Task 3: Create `GoalRepository`
- [ ] Task 4: Create `GoalCubit` & `GoalState`
- [ ] Task 5: Register DI in `injection_container.dart`
- [ ] Task 6: Connect `GoalPage` & `GoalAddPage` to dynamic data

---

## Verification Plan

### Static Analysis
- `cd src/Client-app && flutter analyze lib/features/goal/`
