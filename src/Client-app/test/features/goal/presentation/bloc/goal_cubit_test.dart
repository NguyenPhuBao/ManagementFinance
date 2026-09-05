import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
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

    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví tiền mặt',
        balance: const Value(3000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_nhan',
        idaccount: 1,
        name: 'Ví tích lũy',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  test('depositToGoal triggers repository deposit and updates goal state',
      () async {
    await repository.addGoal(
      idaccount: 1,
      name: 'Đi du lịch',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      walletId: 'w_nhan',
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
    expect((await db.walletDao.getById('w_nhan'))?.balance, 500000.0,
        reason: 'Tiền phải thật sự chuyển sang ví tích lũy của mục tiêu.');
    expect((await db.walletDao.getById('w1'))?.balance, 2500000.0,
        reason: 'Trước đây test này nạp vào một ví KHÔNG tồn tại: khoá ngoại '
            'chặn giao dịch, nhưng tiến độ mục tiêu đã kịp ghi trước đó nên '
            'phép khẳng định vẫn xanh. Nó đang canh chừng đúng cái trạng thái '
            'nửa vời. Nay ví có thật, nên số dư phải giảm tương ứng.');
  });

  test('nạp hỏng thì cubit báo lỗi VÀ không để lại thay đổi nửa vời', () async {
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Đi du lịch',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      walletId: 'w_nhan',
    );

    await cubit.depositToGoal(
      goalId: goal.id,
      goalName: 'Đi du lịch',
      depositAmount: 500000.0,
      walletId: 'vi-nguon-khong-ton-tai',
      idaccount: 1,
    );

    expect(cubit.state, isA<GoalError>(),
        reason: 'Cubit bắt exception và phát GoalError. Nuốt lỗi ở đây là '
            'người dùng bấm "gửi tiết kiệm" rồi không thấy gì thay đổi mà '
            'cũng không thấy báo lỗi.');
    expect((await repository.getGoalById(goal.id))?.currentAmount, 0.0);
    expect((await db.walletDao.getById('w1'))?.balance, 3000000.0);
  });
}
