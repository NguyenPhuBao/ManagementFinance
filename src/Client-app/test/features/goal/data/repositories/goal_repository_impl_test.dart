import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
// `isNull`/`isNotNull` của drift trùng tên với matcher của flutter_test. Ẩn hai
// cái của drift đi — trong file test thì matcher mới là thứ hay dùng.
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví Tết',
        balance: const Value(5000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_nhan',
        idaccount: 1,
        name: 'Ví Tiết Kiệm',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    // Mục tiêu LUÔN có ví nhận: trang tạo bắt chọn, và trang chi tiết chỉ cho
    // đổi sang ví khác chứ không cho bỏ trống.
    await db.goalDao.insert(
      GoalsCompanion.insert(
        id: 'g1',
        idaccount: 1,
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        currentAmount: const Value(2000000.0),
        walletId: const Value('w_nhan'),
        targetDate: DateTime.now().add(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('nạp tiền ghi MỘT giao dịch chuyển khoản', () {
    test('đúng một hàng, kiểu "transfer", mang cả ví nguồn lẫn ví đích',
        () async {
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 1000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      final txs = await db.transactionDao.getAll(1);
      expect(txs.length, 1,
          reason: 'Trước đây một lần nạp đẻ HAI hàng rời ("chi" ở ví nguồn và '
              '"thu" ở ví đích) cho một việc duy nhất là chuyển tiền giữa hai '
              'ví của cùng người dùng.');

      final tx = txs.single;
      expect(tx.type, 'transfer',
          reason: 'Cùng quy ước với chuyển khoản của tính năng giao dịch '
              'thường. Ghi "chi" làm phần thống kê đếm khoản này thành chi '
              'tiêu thật, trong khi tiền chỉ đổi chỗ.');
      expect(tx.walletId, 'w1');
      expect(tx.walletTransfer, 'w_nhan',
          reason: 'Cột này là chỗ duy nhất ghi lại tiền đã đi đâu. Bỏ trống '
              'thì nhìn vào hàng không biết được ví nào nhận — và payload đẩy '
              'đã có sẵn `idwallet_transfer` cho nó.');
      expect(tx.amount, 1000000.0);
      expect(tx.note, 'Tích lũy mục tiêu: Mua Laptop');
      expect(tx.goalId, 'g1');
    });

    test('số dư hai ví và tiến độ mục tiêu đều đổi đúng', () async {
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 1000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      expect((await db.walletDao.getById('w1'))?.balance, 4000000.0);
      expect((await db.walletDao.getById('w_nhan'))?.balance, 1000000.0);
      expect((await repository.getGoalById('g1'))?.currentAmount, 3000000.0);
    });

    test('nạp đủ số thì đánh dấu hoàn thành', () async {
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 18000000.0,
        walletId: 'w1',
        idaccount: 1,
      );
      expect((await repository.getGoalById('g1'))?.isCompleted, isTrue);
    });
  });

  group('ví nhận lấy từ mục tiêu, nơi gọi không truyền vào', () {
    test('mục tiêu chưa có ví nhận thì TỪ CHỐI, không ghi gì', () async {
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(const GoalsCompanion(walletId: Value(null)));

      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 1000000.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<StateError>()),
        reason: 'Chỉ mục tiêu tạo bởi bản app cũ mới rơi vào trạng thái này. '
            'Đoán bừa một ví nhận là đúng cái lỗi vừa gỡ bỏ; im lặng ghi tiến '
            'độ mà không chuyển tiền thì số dư và sổ sách lệch nhau.',
      );

      expect((await db.walletDao.getById('w1'))?.balance, 5000000.0);
      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('ví nguồn trùng ví nhận thì TỪ CHỐI', () async {
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 1000000.0,
          walletId: 'w_nhan',
          idaccount: 1,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Chuyển tiền từ một ví sang chính nó không đổi gì ngoài việc '
            'đẻ ra một hàng vô nghĩa, nhưng tiến độ mục tiêu vẫn tăng — tức là '
            'tích luỹ được tiền từ hư không.',
      );
    });
  });

  group('rút khỏi mục tiêu', () {
    setUp(() async {
      // Ví tích luỹ đang giữ đúng số mục tiêu đã tích được.
      await db.walletDao.updateBalance('w_nhan', 2000000.0);
    });

    test('ghi MỘT giao dịch chuyển khoản ngược chiều', () async {
      await repository.withdrawFromGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        amount: 500000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      final tx = (await db.transactionDao.getAll(1)).single;
      expect(tx.type, 'transfer');
      expect(tx.walletId, 'w_nhan',
          reason: 'Rút thì ví tích luỹ là NGUỒN. Chiều tiền đọc được từ vị trí '
              'ví ấy trong hàng, nên không cần thêm cột nào để phân biệt nạp '
              'với rút.');
      expect(tx.walletTransfer, 'w1');
      expect(tx.goalId, 'g1');
      expect(tx.amount, 500000.0);
    });

    test('giảm tiến độ và chuyển tiền về ví đích', () async {
      await repository.withdrawFromGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        amount: 500000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      expect((await repository.getGoalById('g1'))?.currentAmount, 1500000.0);
      expect((await db.walletDao.getById('w_nhan'))?.balance, 1500000.0);
      expect((await db.walletDao.getById('w1'))?.balance, 5500000.0);
    });

    test('KHÔNG rút quá số mục tiêu đang giữ', () async {
      await expectLater(
        repository.withdrawFromGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          amount: 3000000.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Mục tiêu mới tích được 2 triệu. Cho rút 3 triệu là tiến độ '
            'xuống âm, và tiền lấy ra từ hư không.',
      );
      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
    });

    test('KHÔNG rút quá số dư thật của ví tích luỹ', () async {
      // Người dùng đã tiêu bớt tiền trong ví tích luỹ, nên số dư thật thấp hơn
      // số mục tiêu ghi nhận. Đây chính là ca lệch mà cảnh báo sẽ phơi ra.
      await db.walletDao.updateBalance('w_nhan', 300000.0);

      await expectLater(
        repository.withdrawFromGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          amount: 1000000.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<StateError>()),
        reason: 'Tiến độ nói còn 2 triệu nhưng ví chỉ còn 300 nghìn. Chuyển đi '
            '1 triệu là đưa ví về số dư âm — tạo tiền từ hư không.',
      );
    });

    test('số tiền không hợp lệ thì từ chối', () async {
      for (final xau in [0.0, -1.0]) {
        await expectLater(
          repository.withdrawFromGoal(
            goalId: 'g1',
            goalName: 'Mua Laptop',
            amount: xau,
            walletId: 'w1',
            idaccount: 1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('ví đích trùng ví tích luỹ thì từ chối', () async {
      await expectLater(
        repository.withdrawFromGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          amount: 500000.0,
          walletId: 'w_nhan',
          idaccount: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rút xuống dưới mục tiêu thì GỠ cờ đã hoàn thành', () async {
      await (db.update(db.goals)..where((t) => t.id.equals('g1'))).write(
        const GoalsCompanion(
          currentAmount: Value(20000000.0),
          isCompleted: Value(true),
        ),
      );
      await db.walletDao.updateBalance('w_nhan', 20000000.0);

      await repository.withdrawFromGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        amount: 5000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      final goal = await repository.getGoalById('g1');
      expect(goal?.isCompleted, isFalse,
          reason: 'Giữ cờ thì `_goalCandidates` bỏ qua mục tiêu này vĩnh viễn '
              '— rút gần hết mà nó không bao giờ nhắc "chậm tiến độ" nữa. Cờ '
              'và thanh tiến độ phải nói cùng một điều.');
      expect(goal?.currentAmount, 15000000.0);
    });

    test('rút hết thì mở lại khoá đổi ví', () async {
      await repository.withdrawFromGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        amount: 2000000.0,
        walletId: 'w1',
        idaccount: 1,
      );
      expect((await repository.getGoalById('g1'))?.currentAmount, 0.0);

      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_khac',
          idaccount: 1,
          name: 'Ví Khác',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await repository.changeWallet('g1', 'w_khac');
      expect((await repository.getGoalById('g1'))?.walletId, 'w_khac',
          reason: 'Không còn đồng nào của mục tiêu nằm trong ví cũ thì đổi ví '
              'không gây phân mảnh gì cả.');
    });

    test('ví đích không tồn tại thì từ chối, KHÔNG ghi gì', () async {
      await expectLater(
        repository.withdrawFromGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          amount: 500000.0,
          walletId: 'vi-dich-khong-ton-tai',
          idaccount: 1,
        ),
        throwsA(isA<StateError>()),
        reason: 'Cột `walletTransfer` KHÔNG khai khoá ngoại, nên không có gì ở '
            'tầng CSDL chặn việc chuyển tới một ví không tồn tại. Thiếu phép '
            'kiểm này thì tiền rời ví tích lũy mà không ví nào được cộng — nó '
            'biến mất khỏi tổng tài sản, im lặng.',
      );

      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
      expect((await db.walletDao.getById('w_nhan'))?.balance, 2000000.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });
  });

  group('nạp tiền là một khối nguyên tử', () {
    test('hỏng giữa chừng thì KHÔNG để lại tiến độ đã tăng', () async {
      // Ví nguồn không tồn tại → chèn giao dịch cho ví đó vi phạm khoá ngoại
      // (PRAGMA foreign_keys = ON). Dựng lại sự cố giữa chừng mà không phải giả
      // lập gì: tiến độ mục tiêu đã ghi xong trước khi thao tác sau nổ.
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 1000000.0,
          walletId: 'vi-khong-ton-tai',
          idaccount: 1,
        ),
        throwsA(anything),
      );

      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0,
          reason: 'Tiến độ tăng mà tiền chưa rời ví nào là mục tiêu tự đầy lên '
              'từ hư không — hỏng lặng lẽ, không exception nào tới màn hình.');
      expect((await db.walletDao.getById('w_nhan'))?.balance, 0.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });
  });

  group('đổi ví nhận', () {
    test('trỏ mục tiêu sang ví khác và đánh dấu cần đẩy', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.goals)..where((t) => t.id.equals('g1'))).write(
        const GoalsCompanion(
          syncStatus: Value('synced'),
          currentAmount: Value(0.0),
        ),
      );

      await repository.changeWallet('g1', 'w_moi');

      final goal = await repository.getGoalById('g1');
      expect(goal?.walletId, 'w_moi',
          reason: 'Đây là đường thoát cho bế tắc xoá ví: ví cũ còn liên kết thì '
              'không xoá được, nên phải trỏ mục tiêu sang ví khác trước.');
      expect(goal?.syncStatus, 'pending',
          reason: 'Không đánh dấu thì máy khác vẫn thấy mục tiêu gắn ví cũ.');
    });

    test('mục tiêu ĐÃ tích được tiền thì KHÔNG cho đổi ví', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      // g1 trong setUp đã có sẵn 2.000.000đ.

      await expectLater(
        repository.changeWallet('g1', 'w_moi'),
        throwsA(isA<StateError>()),
        reason: 'Tiền đã tích được đang nằm THẬT trong ví cũ. Đổi ví mà không '
            'chuyển tiền theo thì mục tiêu báo 2 triệu trong khi số ấy nằm rải '
            'ở ví khác — càng đổi càng phân mảnh, không ai lần lại được.',
      );

      expect((await repository.getGoalById('g1'))?.walletId, 'w_nhan',
          reason: 'Từ chối thì không được đổi gì cả.');
    });

    test('mục tiêu chưa tích đồng nào thì đổi ví thoải mái', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(const GoalsCompanion(currentAmount: Value(0.0)));

      await repository.changeWallet('g1', 'w_moi');
      expect((await repository.getGoalById('g1'))?.walletId, 'w_moi');
    });

    test('mục tiêu chưa có ví nào thì gắn được dù đã tích tiền', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(const GoalsCompanion(walletId: Value(null)));

      await repository.changeWallet('g1', 'w_moi');
      expect((await repository.getGoalById('g1'))?.walletId, 'w_moi',
          reason: 'Mục tiêu do bản app cũ tạo có thể vừa chưa có ví vừa đã '
              'tích được tiền. Chặn cả ca này là chúng nó kẹt vĩnh viễn, không '
              'nạp thêm được mà cũng không gắn được ví.');
    });

    test('đổi ví KHÔNG đụng tới số tiền đã tích được', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(const GoalsCompanion(currentAmount: Value(0.0)));
      await repository.changeWallet('g1', 'w_moi');
      expect((await repository.getGoalById('g1'))?.currentAmount, 0.0);
    });

    test('lần nạp sau đi vào ví MỚI', () async {
      await db.walletDao.insert(
        WalletsCompanion.insert(
          id: 'w_moi',
          idaccount: 1,
          name: 'Ví Đầu Tư',
          balance: const Value(0.0),
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(const GoalsCompanion(currentAmount: Value(0.0)));
      await repository.changeWallet('g1', 'w_moi');

      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 1000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      expect((await db.walletDao.getById('w_moi'))?.balance, 1000000.0);
      expect((await db.walletDao.getById('w_nhan'))?.balance, 0.0,
          reason: 'Ví cũ không được nhận thêm đồng nào sau khi đã đổi.');
    });
  });

  group('lịch sử tích luỹ thuộc về đúng mục tiêu', () {
    setUp(() async {
      // Tên mục tiêu thứ hai là TIỀN TỐ của tên mục tiêu thứ nhất. Truy vấn cũ
      // lọc bằng `note LIKE '%Tích lũy mục tiêu: <tên>%'`, nên "Mua" khớp luôn
      // ghi chú của "Mua xe".
      await db.goalDao.insert(
        GoalsCompanion.insert(
          id: 'g_mua_xe',
          idaccount: 1,
          name: 'Mua xe',
          targetAmount: 500000000.0,
          walletId: const Value('w_nhan'),
          targetDate: DateTime.now().add(const Duration(days: 365)),
          updatedAt: DateTime.now(),
        ),
      );
      await db.goalDao.insert(
        GoalsCompanion.insert(
          id: 'g_mua',
          idaccount: 1,
          name: 'Mua',
          targetAmount: 1000000.0,
          walletId: const Value('w_nhan'),
          targetDate: DateTime.now().add(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        ),
      );
    });

    test('mục tiêu tên là tiền tố của mục tiêu khác KHÔNG nuốt lịch sử của nó',
        () async {
      await repository.depositToGoal(
        goalId: 'g_mua_xe',
        goalName: 'Mua xe',
        depositAmount: 3000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      final lichSuCuaMua = await repository
          .watchGoalTransactions(1, 'g_mua', 'Mua')
          .first as List;

      expect(lichSuCuaMua, isEmpty,
          reason: 'Chưa nạp đồng nào vào mục tiêu "Mua". Lịch sử phải nối bằng '
              'ID mục tiêu; nối bằng tên thì "Mua" hiện luôn khoản 3 triệu của '
              '"Mua xe" — người dùng thấy tiền mình không hề gửi.');
    });

    test('mỗi mục tiêu chỉ thấy khoản nạp của chính nó', () async {
      await repository.depositToGoal(
        goalId: 'g_mua_xe',
        goalName: 'Mua xe',
        depositAmount: 3000000.0,
        walletId: 'w1',
        idaccount: 1,
      );
      await repository.depositToGoal(
        goalId: 'g_mua',
        goalName: 'Mua',
        depositAmount: 500000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      final cuaMuaXe = await repository
          .watchGoalTransactions(1, 'g_mua_xe', 'Mua xe')
          .first as List;
      expect(cuaMuaXe.length, 1);
      expect((cuaMuaXe.first as Transaction).amount, 3000000.0);

      final cuaMua =
          await repository.watchGoalTransactions(1, 'g_mua', 'Mua').first
              as List;
      expect(cuaMua.length, 1);
      expect((cuaMua.first as Transaction).amount, 500000.0);
    });

    test('hàng cũ không có goalId vẫn tra được bằng ghi chú', () async {
      // Giao dịch tích luỹ tạo bởi bản app trước, hoặc kéo về từ server (cột
      // goalId là cục bộ nên hàng từ server luôn để trống).
      await db.transactionDao.insert(
        TransactionsCompanion.insert(
          id: 'tx_cu',
          idaccount: 1,
          walletId: 'w1',
          amount: 750000.0,
          type: 'chi',
          note: const Value('Tích lũy mục tiêu: Mua xe'),
          date: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final cuaMuaXe = await repository
          .watchGoalTransactions(1, 'g_mua_xe', 'Mua xe')
          .first as List;
      expect(cuaMuaXe.length, 1,
          reason: 'Siết sang goalId không được làm biến mất lịch sử đã có. '
              'Hàng cũ và hàng kéo về từ server đều không mang goalId.');
    });
  });

  group('addGoal đặt mốc bắt đầu', () {
    test('mục tiêu mới tạo có startDate', () async {
      final truoc = DateTime.now();
      final goal = await repository.addGoal(
        idaccount: 1,
        name: 'Mua xe',
        targetAmount: 100000000.0,
        targetDate: DateTime.now().add(const Duration(days: 100)),
        walletId: 'w_nhan',
      );
      final sau = DateTime.now();

      expect(goal.startDate, isA<DateTime>(),
          reason: 'Không có startDate thì isBehindSchedule bỏ qua mục tiêu '
              'này vĩnh viễn — luật thông báo "chậm tiến độ" chết lặng, '
              'không exception, không log.');
      expect(
        goal.startDate!.isBefore(truoc.subtract(const Duration(seconds: 1))),
        isFalse,
        reason: 'Mốc bắt đầu phải là lúc tạo, không phải một ngày quá khứ '
            'nào đó — nhịp tiến độ tính từ đây.',
      );
      expect(goal.startDate!.isAfter(sau.add(const Duration(seconds: 1))),
          isFalse);
    });

    test('startDate được ghi xuống SQLite, không chỉ nằm trong object trả về',
        () async {
      final goal = await repository.addGoal(
        idaccount: 1,
        name: 'Mua xe',
        targetAmount: 100000000.0,
        targetDate: DateTime.now().add(const Duration(days: 100)),
        walletId: 'w_nhan',
      );

      final duocLuu = await repository.getGoalById(goal.id);
      expect(duocLuu?.startDate, isA<DateTime>(),
          reason: 'toCompanion() phải mang startDate qua Drift. Rớt ở đây thì '
              'object trả về đúng mà hàng trong CSDL vẫn thiếu mốc.');
      expect(duocLuu?.walletId, 'w_nhan',
          reason: 'Ví nhận là bắt buộc khi tạo, nên nó phải xuống tới CSDL.');
    });

    test('mục tiêu vừa tạo mà tụt nhịp thì BỊ coi là trễ', () async {
      final goal = await repository.addGoal(
        idaccount: 1,
        name: 'Mua xe',
        targetAmount: 100000000.0,
        targetDate: DateTime.now().add(const Duration(days: 100)),
        walletId: 'w_nhan',
      );

      // Đi được nửa kỳ mà chưa tích được đồng nào.
      final nuaKy = DateTime.now().add(const Duration(days: 50));
      expect(goal.isBehindSchedule(nuaKy), isTrue,
          reason: 'Đây là lỗi gốc: thiếu startDate làm isBehindSchedule trả '
              'false cho MỌI mục tiêu tạo trên máy, nên thông báo "chậm tiến '
              'độ" không bao giờ nổ cho tới khi mục tiêu đi một vòng lên '
              'server rồi kéo về.');
    });
  });
}
