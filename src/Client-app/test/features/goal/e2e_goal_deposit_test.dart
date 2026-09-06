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
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w10_nhan',
        idaccount: 1,
        name: 'Ví Tích Lũy',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Goal — ví nhận là bắt buộc kể từ khi phiếu nạp thôi hỏi lại.
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Mua Quà Tết',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 60)),
      walletId: 'w10_nhan',
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

  test('Goal with linked walletId automatically receives deposit without specifying targetWalletId in deposit call', () async {
    // 1. Source Wallet (Cash) & Target Savings Wallet
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_source',
        idaccount: 1,
        name: 'Ví Tiền Mặt',
        balance: const Value(5000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_savings',
        idaccount: 1,
        name: 'Ví Tiết Kiệm Tết',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Goal linked to 'w_savings'
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Mua xe mới',
      targetAmount: 20000000.0,
      targetDate: DateTime.now().add(const Duration(days: 180)),
      walletId: 'w_savings',
    );

    // 3. Deposit money from 'w_source' without targetWalletId parameter
    await repository.depositToGoal(
      goalId: goal.id,
      goalName: goal.name,
      depositAmount: 1500000.0,
      walletId: 'w_source',
      idaccount: 1,
    );

    // 4. Source wallet deducted: 5.000.000 - 1.500.000 = 3.500.000
    final source = await db.walletDao.getById('w_source');
    expect(source?.balance, 3500000.0);

    // 5. Goal's linked savings wallet credited: 1.000.000 + 1.500.000 = 2.500.000
    final savings = await db.walletDao.getById('w_savings');
    expect(savings?.balance, 2500000.0);

    // 6. Goal currentAmount updated: 1.500.000
    final updatedGoal = await repository.getGoalById(goal.id);
    expect(updatedGoal?.currentAmount, 1500000.0);
  });

  test('Nạp từ ví B vào mục tiêu gắn ví A: một giao dịch chuyển khoản duy nhất', () async {
    // 1. Setup Wallet A (Savings) and Wallet B (Source)
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_A',
        idaccount: 1,
        name: 'Ví Tích Lũy A',
        balance: const Value(2000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_B',
        idaccount: 1,
        name: 'Ví Rút Tiền B',
        balance: const Value(8000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Goal linked to Wallet A
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Mua Tủ Lạnh',
      targetAmount: 10000000.0,
      targetDate: DateTime.now().add(const Duration(days: 90)),
      walletId: 'w_A',
    );

    // 3. Nạp từ ví B. Ví nhận KHÔNG truyền vào — repository đọc từ mục tiêu.
    await repository.depositToGoal(
      goalId: goal.id,
      goalName: goal.name,
      depositAmount: 3000000.0,
      walletId: 'w_B',
      idaccount: 1,
    );

    // 4. Wallet B deducted: 8.000.000 - 3.000.000 = 5.000.000đ
    final walletB = await db.walletDao.getById('w_B');
    expect(walletB?.balance, 5000000.0);

    // 5. Wallet A credited: 2.000.000 + 3.000.000 = 5.000.000đ
    final walletA = await db.walletDao.getById('w_A');
    expect(walletA?.balance, 5000000.0);

    // 6. ĐÚNG MỘT hàng, kiểu chuyển khoản, mang cả hai đầu ví.
    final tatCa = await db.transactionDao.getAll(1);
    expect(tatCa.length, 1,
        reason: 'Một lần chuyển tiền giữa hai ví của cùng người dùng là MỘT '
            'giao dịch, không phải một cặp chi/thu rời.');
    expect(tatCa.single.type, 'transfer');
    expect(tatCa.single.walletId, 'w_B');
    expect(tatCa.single.walletTransfer, 'w_A');
    expect(tatCa.single.amount, 3000000.0);

    // Hàng nằm ở ví nguồn; ví đích tra được qua walletTransfer.
    expect((await db.transactionDao.getByWallet('w_B')).length, 1);
    expect((await db.transactionDao.getByWallet('w_A')), isEmpty);
  });
}
