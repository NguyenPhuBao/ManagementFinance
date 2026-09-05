import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/goal_local_data_source.dart';
import '../../domain/goal_history_direction.dart';
import '../models/goal_entity.dart';
import 'goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource localDataSource;
  final AppDatabase? db;
  final SyncEngine? syncEngine;

  GoalRepositoryImpl({
    required this.localDataSource,
    this.db,
    this.syncEngine,
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
  Future<GoalEntity?> getGoalById(String id) {
    return localDataSource.getGoalById(id);
  }

  @override
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? walletId,
    String? cycleTakeMoney,
    String? icon,
    String? colour,
    String? note,
  }) async {
    final now = DateTime.now();
    final goal = GoalEntity(
      id: const Uuid().v4(),
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      // Mốc bắt đầu tính nhịp tiến độ là lúc tạo. Bỏ trống thì
      // `isBehindSchedule` trả `false` vĩnh viễn cho mục tiêu này (nó cố ý im
      // lặng khi thiếu căn cứ), nên luật thông báo "chậm tiến độ" không bao
      // giờ nổ — hỏng lặng lẽ, không exception, không log. Nhánh kéo về từ
      // server vẫn ghi đè bằng `Start_date` của backend như trước.
      startDate: now,
      targetDate: targetDate,
      walletId: walletId,
      cycleTakeMoney: cycleTakeMoney,
      icon: icon ?? 'flag',
      colour: colour ?? '#4CAF50',
      note: note ?? '',
      isCompleted: false,
      isDeleted: false,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await localDataSource.addGoal(goal);
    syncEngine?.scheduleSync();
    return goal;
  }

  @override
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  }) async {
    await localDataSource.updateGoalAmount(id, newAmount);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required int idaccount,
    required String walletId,
  }) async {
    // Một lần nạp là bốn thao tác ghi: tăng tiến độ mục tiêu, có thể đánh dấu
    // hoàn thành, đổi số dư hai ví, và chèn MỘT giao dịch chuyển khoản. Chạy
    // rời rạc thì một sự cố ở giữa để lại tiền đã trừ khỏi ví mà mục tiêu chưa
    // tăng — người dùng mất tiền, không có gì ghi nhận, và không có exception
    // nào tới được màn hình. Cả khối phải cùng sống hoặc cùng chết.
    Future<void> ghiCaKhoi() async {
      final goal = await localDataSource.getGoalById(goalId);
      if (goal == null) {
        throw StateError('Không tìm thấy mục tiêu $goalId.');
      }

      // Ví nhận đọc từ chính mục tiêu. Nơi gọi KHÔNG truyền vào: ví ấy được
      // chọn một lần lúc tạo mục tiêu và chỉ đổi qua `changeWallet`.
      //
      // Chỉ mục tiêu do bản app cũ tạo mới có thể thiếu ví. Đoán bừa một ví
      // nhận chính là lỗi vừa gỡ bỏ; còn im lặng tăng tiến độ mà không chuyển
      // tiền thì số dư ví và sổ sách lệch nhau vĩnh viễn.
      final viNhan = goal.walletId;
      if (viNhan == null || viNhan.isEmpty) {
        throw StateError(
          'Mục tiêu "${goal.name}" chưa có ví nhận tiền tích lũy.',
        );
      }
      if (viNhan == walletId) {
        throw ArgumentError.value(
          walletId,
          'walletId',
          'Ví nguồn trùng ví nhận: chuyển tiền sang chính nó chỉ đẻ ra một '
              'hàng vô nghĩa trong khi tiến độ mục tiêu vẫn tăng.',
        );
      }

      final newGoalAmount = goal.currentAmount + depositAmount;
      await localDataSource.updateGoalAmount(goalId, newGoalAmount);

      if (newGoalAmount >= goal.targetAmount && db != null) {
        await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
          const GoalsCompanion(
            isCompleted: Value(true),
            syncStatus: Value('pending'),
          ),
        );
      }

      if (db == null) return;
      final now = DateTime.now();

      final viNguon = await db!.walletDao.getById(walletId);
      if (viNguon != null) {
        await db!.walletDao
            .updateBalance(walletId, viNguon.balance - depositAmount);
      }
      final viDich = await db!.walletDao.getById(viNhan);
      if (viDich != null) {
        await db!.walletDao
            .updateBalance(viNhan, viDich.balance + depositAmount);
      }

      // MỘT hàng duy nhất, kiểu 'transfer' — cùng quy ước với chuyển khoản của
      // tính năng giao dịch thường. Trước đây chỗ này ghi hai hàng rời ('chi' ở
      // ví nguồn, 'thu' ở ví đích) cho một việc duy nhất là chuyển tiền giữa
      // hai ví của cùng người dùng, khiến phần thống kê đếm khoản này thành chi
      // tiêu thật.
      //
      // `walletTransfer` là chỗ duy nhất ghi lại tiền đã đi đâu, và payload đẩy
      // đã có sẵn `idwallet_transfer` cho nó. Tính năng giao dịch thường hiện
      // KHÔNG điền cột này (`TransactionEntity` không có trường tương ứng) —
      // đây là chỗ Goal làm đầy đủ hơn, không phải chỗ lệch.
      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          walletId: walletId,
          walletTransfer: Value(viNhan),
          amount: depositAmount,
          type: 'transfer',
          note: Value('$kGhiChuNapMucTieu$goalName'),
          goalId: Value(goalId),
          date: now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }

    if (db != null) {
      await db!.transaction(ghiCaKhoi);
    } else {
      // Không có `db` thì chỉ có mỗi thao tác cập nhật tiến độ, không có gì để
      // giữ nguyên tử.
      await ghiCaKhoi();
    }

    syncEngine?.scheduleSync();
  }

  @override
  Future<void> withdrawFromGoal({
    required String goalId,
    required String goalName,
    required double amount,
    required String walletId,
    required int idaccount,
  }) async {
    Future<void> ghiCaKhoi() async {
      final goal = await localDataSource.getGoalById(goalId);
      if (goal == null) {
        throw StateError('Không tìm thấy mục tiêu $goalId.');
      }

      final viTichLuy = goal.walletId;
      if (viTichLuy == null || viTichLuy.isEmpty) {
        throw StateError(
          'Mục tiêu "${goal.name}" chưa có ví tích lũy nên không có gì để rút.',
        );
      }
      if (viTichLuy == walletId) {
        throw ArgumentError.value(walletId, 'walletId',
            'Ví đích trùng ví tích lũy: tiền không đi đâu cả.');
      }
      if (amount <= 0) {
        throw ArgumentError.value(amount, 'amount', 'Số tiền phải lớn hơn 0.');
      }

      // Hai trần khác nhau, và phải kiểm CẢ HAI.
      //
      // Trần thứ nhất là tiến độ: rút quá số mục tiêu đang ghi nhận thì tiến độ
      // xuống âm.
      if (amount > goal.currentAmount) {
        throw ArgumentError.value(
          amount,
          'amount',
          'Mục tiêu "${goal.name}" mới tích được ${goal.currentAmount}.',
        );
      }

      if (db == null) return;

      // Trần thứ hai là tiền THẬT trong ví. Hai con số này lệch nhau được —
      // người dùng có thể đã tiêu bớt tiền trong ví tích lũy bằng một giao dịch
      // thường, mà giao dịch ấy không mang `goalId` nên không hạ tiến độ. Bỏ
      // qua trần này là đưa ví về số dư âm, tức tạo tiền từ hư không.
      final viNguon = await db!.walletDao.getById(viTichLuy);
      if (viNguon == null) {
        throw StateError('Không tìm thấy ví tích lũy $viTichLuy.');
      }
      if (amount > viNguon.balance) {
        throw StateError(
          'Ví "${viNguon.name}" chỉ còn ${viNguon.balance} — ít hơn số mục '
          'tiêu đang ghi nhận. Có khoản chi nào đó đã tiêu vào tiền tích lũy.',
        );
      }

      final soConLai = goal.currentAmount - amount;
      final now = DateTime.now();

      // Gỡ cờ hoàn thành khi tụt xuống dưới mục tiêu. Giữ cờ thì
      // `_goalCandidates` bỏ qua mục tiêu này vĩnh viễn — rút gần hết mà nó
      // không bao giờ nhắc "chậm tiến độ" nữa. Cờ và thanh tiến độ phải nói
      // cùng một điều.
      await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
        GoalsCompanion(
          currentAmount: Value(soConLai),
          isCompleted: Value(soConLai >= goal.targetAmount),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ),
      );

      // Ví đích PHẢI tồn tại. Cột `walletTransfer` không khai khoá ngoại, nên
      // thiếu phép kiểm này thì tiền rời ví tích lũy mà không ví nào được
      // cộng — hàng giao dịch ghi một khoản chuyển tới ví ma, và tiền biến mất
      // khỏi tổng tài sản mà không có gì báo.
      final viDich = await db!.walletDao.getById(walletId);
      if (viDich == null) {
        throw StateError('Không tìm thấy ví đích $walletId.');
      }

      await db!.walletDao.updateBalance(viTichLuy, viNguon.balance - amount);
      await db!.walletDao.updateBalance(walletId, viDich.balance + amount);

      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          // Ngược chiều nạp tiền: ví tích lũy là NGUỒN.
          walletId: viTichLuy,
          walletTransfer: Value(walletId),
          amount: amount,
          type: 'transfer',
          note: Value('$kGhiChuRutMucTieu$goalName'),
          goalId: Value(goalId),
          date: now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }

    if (db != null) {
      await db!.transaction(ghiCaKhoi);
    } else {
      await ghiCaKhoi();
    }

    syncEngine?.scheduleSync();
  }

  @override
  Stream<dynamic> watchGoalTransactions(
    int idaccount,
    String goalId,
    String goalName,
  ) {
    if (db != null) {
      return db!.transactionDao.watchByGoal(idaccount, goalId, goalName);
    }
    return Stream.value([]);
  }

  @override
  Future<void> changeWallet(String goalId, String walletId) async {
    if (db == null) return;

    final goal = await localDataSource.getGoalById(goalId);
    if (goal == null) {
      throw StateError('Không tìm thấy mục tiêu $goalId.');
    }

    // Khoá ví sau khoản nạp đầu tiên.
    //
    // Tiền đã tích được đang nằm THẬT trong ví hiện tại. Đổi ví mà không chuyển
    // tiền theo thì mục tiêu báo 2 triệu trong khi số ấy nằm rải ở ví khác —
    // càng đổi càng phân mảnh, và không có gì trong app lần lại được số tiền
    // của một mục tiêu đang nằm ở những đâu.
    //
    // Ngoại lệ: mục tiêu **chưa có ví nào**. Mục tiêu do bản app cũ tạo có thể
    // vừa thiếu ví vừa đã tích được tiền; chặn cả ca đó là chúng kẹt vĩnh viễn,
    // không nạp thêm được mà cũng không gắn được ví.
    if (goal.walletId != null && goal.currentAmount > 0) {
      throw StateError(
        'Mục tiêu "${goal.name}" đã tích được tiền trong ví hiện tại nên '
        'không đổi ví được.',
      );
    }

    await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
      GoalsCompanion(
        walletId: Value(walletId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteGoal(String id) async {
    await localDataSource.deleteGoal(id);
    syncEngine?.scheduleSync();
  }
}
