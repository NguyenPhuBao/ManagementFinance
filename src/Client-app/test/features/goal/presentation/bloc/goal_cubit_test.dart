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
