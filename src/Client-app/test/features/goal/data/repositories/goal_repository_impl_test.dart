import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
// `isNull`/`isNotNull` của drift trùng tên với matcher của flutter_test. Ẩn hai
// cái của drift đi — trong file test thì matcher mới là thứ hay dùng.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
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
      // Nạp trọn 18 triệu còn thiếu thì ví nguồn phải có đủ 18 triệu. Bản cũ
      // của test này nạp 18 triệu từ một ví chỉ có 5 triệu — một ca giao diện
      // không bao giờ cho phép, và nay bị trần "tiền THẬT trong ví" chặn lại.
      await db.walletDao.updateBalance('w1', 18000000.0);

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

  group('phép kiểm số tiền nạp nằm ở tầng repository, không chỉ ở form', () {
    test('số tiền 0 thì TỪ CHỐI, không ghi gì', () async {
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 0.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Phép kiểm này trước chỉ có ở ô nhập của trang chi tiết, nên '
            'mọi đường gọi khác đi vòng qua được. Nạp 0 đồng đẻ ra một hàng '
            'giao dịch rỗng trong lịch sử tích luỹ mà không có gì đổi.',
      );

      expect((await db.walletDao.getById('w1'))?.balance, 5000000.0);
      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('số tiền ÂM thì TỪ CHỐI', () async {
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: -1000000.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Số âm nguy hơn số 0 vì nó chạy trót lọt tới cuối: ví nguồn '
            'được CỘNG tiền trong khi tiến độ mục tiêu tụt xuống, và hàng giao '
            'dịch ghi một khoản chuyển khoản âm.',
      );

      expect((await db.walletDao.getById('w1'))?.balance, 5000000.0);
      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('nạp quá số dư ví nguồn thì TỪ CHỐI, không đưa ví xuống âm', () async {
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 5000001.0,
          walletId: 'w1',
          idaccount: 1,
        ),
        throwsA(isA<StateError>()),
        reason: 'Đối xứng với `withdrawFromGoal`, nơi đã có trần "tiền THẬT '
            'trong ví". Thiếu trần này thì repository trừ thẳng và ví nguồn '
            'xuống âm — tạo tiền từ hư không, đúng ca đã chặn ở chiều rút.',
      );

      expect((await db.walletDao.getById('w1'))?.balance, 5000000.0);
      expect((await db.walletDao.getById('w_nhan'))?.balance, 0.0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('nạp ĐÚNG BẰNG số dư ví nguồn thì cho qua', () async {
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 5000000.0,
        walletId: 'w1',
        idaccount: 1,
      );

      expect((await db.walletDao.getById('w1'))?.balance, 0.0,
          reason: 'Trần là "vượt quá", không phải "bằng". Dồn sạch một ví vào '
              'mục tiêu là thao tác hợp lệ — chặn cả ca này là biến một việc '
              'người dùng cố ý làm thành lỗi.');
    });
  });

  group('dấu thời gian của khoản nạp', () {
    test('không truyền thời điểm thì ghi "bây giờ"', () async {
      // Drift lưu `DateTime` thành mốc unix GIÂY, mili-giây bị cắt — nên nới
      // hai đầu ra một giây thay vì so khít.
      final truoc = DateTime.now().subtract(const Duration(seconds: 1));
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 1000000.0,
        walletId: 'w1',
        idaccount: 1,
      );
      final sau = DateTime.now().add(const Duration(seconds: 1));

      final tx = (await db.transactionDao.getAll(1)).single;
      expect(tx.date.isAfter(truoc) && tx.date.isBefore(sau), isTrue,
          reason: 'Khoản nạp TAY vẫn mang thời điểm bấm nút. Tham số '
              '`occurredAt` chỉ dành cho bộ trích bù; để nó rò sang đường nạp '
              'tay là mở cửa cho mọi nơi gọi tự đặt ngày cho tiền của mình.');
    });

    test('thời điểm ở TƯƠNG LAI thì TỪ CHỐI, không ghi gì', () async {
      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 1000000.0,
          walletId: 'w1',
          idaccount: 1,
          occurredAt: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Tham số này tồn tại để một khoản trích BÙ lùi về đúng mốc kỳ '
            'đã qua. Cho phép nó trỏ tới tương lai là biến tầng ghi tiền — chỗ '
            'ít đáng nới lỏng nhất — thành nơi bịa được ngày.',
      );

      expect(await db.transactionDao.getAll(1), isEmpty);
      expect((await db.walletDao.getById('w1'))?.balance, 5000000.0);
      expect((await repository.getGoalById('g1'))?.currentAmount, 2000000.0);
    });

    test('thời điểm TRƯỚC KHI mục tiêu tồn tại thì TỪ CHỐI', () async {
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(GoalsCompanion(startDate: Value(DateTime(2026, 9, 1))));

      await expectLater(
        repository.depositToGoal(
          goalId: 'g1',
          goalName: 'Mua Laptop',
          depositAmount: 1000000.0,
          walletId: 'w1',
          idaccount: 1,
          occurredAt: DateTime(2026, 8, 31),
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Chặn đầu dưới cùng lúc với đầu trên. Không có nó thì một ngày '
            'bịa vẫn lọt được, chỉ cần bịa về quá khứ — và khoản nạp rơi xuống '
            'đáy lịch sử tích luỹ ở một chỗ mục tiêu còn chưa ra đời.',
      );

      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('thời điểm hợp lệ trong quá khứ được ghi thẳng vào cột ngày', () async {
      await (db.update(db.goals)..where((t) => t.id.equals('g1')))
          .write(GoalsCompanion(startDate: Value(DateTime(2026, 1, 1))));

      final ky = DateTime(2026, 8, 5, 9);
      await repository.depositToGoal(
        goalId: 'g1',
        goalName: 'Mua Laptop',
        depositAmount: 1000000.0,
        walletId: 'w1',
        idaccount: 1,
        occurredAt: ky,
      );

      final tx = (await db.transactionDao.getAll(1)).single;
      expect(tx.date, ky);
      expect(tx.updatedAt.isAfter(DateTime(2026, 9, 1)), isTrue,
          reason: '`updatedAt` là sổ sách ĐỒNG BỘ, không phải ngày của sự '
              'việc. Lùi nó về mốc kỳ làm phép phân xử LWW coi bản ghi này cũ '
              'hơn thực tế và ghi đè mất chính khoản vừa trích.');
    });
  });

  group('tên mục tiêu là duy nhất trong phạm vi một tài khoản', () {
    Future<GoalEntity> taoMucTieu(String ten, {int idaccount = 1}) {
      return repository.addGoal(
        idaccount: idaccount,
        name: ten,
        targetAmount: 5000000.0,
        targetDate: DateTime.now().add(const Duration(days: 60)),
        walletId: 'w_nhan',
      );
    }

    test('tạo mục tiêu trùng tên thì TỪ CHỐI, không thêm hàng nào', () async {
      await expectLater(
        taoMucTieu('Mua Laptop'),
        throwsA(isA<GoalValidationException>()),
        reason: 'Hai mục tiêu trùng tên cùng nhận vơ những hàng giao dịch cũ '
            'không mang `goalId`: nhánh dự phòng của `watchByGoal` tra bằng '
            'LIKE trên ghi chú "Tích lũy mục tiêu: <tên>", nên lịch sử của cái '
            'này hiện trong cái kia.',
      );

      expect((await db.goalDao.getAll(1)).length, 1);
    });

    test('khác hoa/thường và thừa khoảng trắng vẫn là TRÙNG', () async {
      await expectLater(
        taoMucTieu('  mua   laptop  '),
        throwsA(isA<GoalValidationException>()),
        reason: 'Dùng chung `normalizeCategoryName()` với danh mục: NFC → chữ '
            'thường → cắt hai đầu → gom khoảng trắng giữa. Tự viết một biến '
            'thể khác là quay lại đúng cái lỗi "mỗi nơi một kiểu" đã dọn ở '
            'vùng danh mục.',
      );
    });

    test('trùng tên với mục tiêu ĐÃ XOÁ MỀM thì cho qua', () async {
      await db.goalDao.softDelete('g1');

      final moi = await taoMucTieu('Mua Laptop');
      expect(moi.name, 'Mua Laptop',
          reason: 'Hàng đã xoá mềm không giữ chỗ tên — cùng luật với danh mục. '
              'Giữ chỗ thì người dùng xoá một mục tiêu rồi không tạo lại được '
              'nó với chính cái tên ấy, mà cũng không thấy gì đang chiếm chỗ.');
    });

    test('tài khoản khác được trùng tên', () async {
      final moi = await taoMucTieu('Mua Laptop', idaccount: 2);
      expect(moi.idaccount, 2,
          reason: 'Phạm vi duy nhất là MỘT tài khoản. Hai người dùng cùng đặt '
              'tên "Mua Laptop" là chuyện bình thường.');
    });

    test('sửa sang tên đã có thì TỪ CHỐI', () async {
      await taoMucTieu('Mua Điện Thoại');

      await expectLater(
        repository.updateGoal(
          id: 'g1',
          name: 'Mua Điện Thoại',
          targetAmount: 20000000.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
        throwsA(isA<GoalValidationException>()),
        reason: 'Đường sửa cũng phải chặn, không chỉ đường tạo — nếu không thì '
            'tạo hai tên khác nhau rồi đổi một cái thành cái kia là đi vòng '
            'qua được toàn bộ quy tắc.',
      );

      expect((await repository.getGoalById('g1'))?.name, 'Mua Laptop');
    });

    test('GIỮ NGUYÊN tên thì không xét trùng, kể cả khi đang có bản trùng',
        () async {
      // Hai mục tiêu trùng tên do bản client trước tạo ra, chèn thẳng qua DAO
      // để dựng lại đúng trạng thái ấy.
      await db.goalDao.insert(GoalsCompanion.insert(
        id: 'g_cu',
        idaccount: 1,
        name: 'Mua Laptop',
        targetAmount: 9000000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ));

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 21000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );

      expect((await repository.getGoalById('g1'))?.targetAmount, 21000000.0,
          reason: 'Phép kiểm chỉ chạy khi tên THẬT SỰ đổi. Chặn tuyệt đối thì '
              'những mục tiêu trùng tên có sẵn trên máy người dùng kẹt vĩnh '
              'viễn — không sửa nổi cả số tiền lẫn biểu tượng, và không có '
              'đường thoát nào ngoài đổi tên.');
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

  group('sửa mục tiêu', () {
    test('đổi tên, số tiền, hạn định và chu kỳ; xếp hàng đồng bộ', () async {
      final hanMoi = DateTime.now().add(const Duration(days: 200));

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop Pro',
        targetAmount: 30000000.0,
        targetDate: hanMoi,
        cycleTakeMoney: 'Week',
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.name, 'Mua Laptop Pro');
      expect(goal.targetAmount, 30000000.0);
      expect(goal.targetDate.day, hanMoi.day);
      expect(goal.cycleTakeMoney, 'Week');
      expect(goal.syncStatus, 'pending',
          reason: 'Sửa mà không đánh dấu pending thì thay đổi nằm lại trên '
              'máy vĩnh viễn — hỏng lặng lẽ, đúng loại lỗi khó thấy nhất ở '
              'đường đồng bộ.');
    });

    test('KHÔNG đụng vào tiến độ, ví tích luỹ hay mốc bắt đầu', () async {
      final truoc = await repository.getGoalById('g1');

      await repository.updateGoal(
        id: 'g1',
        name: 'Tên khác',
        targetAmount: 25000000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
      );

      final sau = await repository.getGoalById('g1');
      expect(sau!.currentAmount, truoc!.currentAmount,
          reason: 'Số đã tích được là tiền THẬT đang nằm trong ví. Form sửa '
              'không có ô nào cho nó, nên nếu companion vô tình gán lại thì '
              'tiền và tiến độ lệch nhau mà không ai báo.');
      expect(sau.walletId, truoc.walletId,
          reason: 'Ví tích luỹ chỉ đổi qua changeWallet, nơi có phép khoá sau '
              'khoản nạp đầu tiên. Cho form sửa ghi thẳng là đi vòng qua khoá '
              'ấy.');
      expect(sau.startDate, truoc.startDate,
          reason: 'startDate là mốc tính nhịp thật của dự báo. Đặt lại nó khi '
              'sửa tên sẽ làm tốc độ tích luỹ nhảy vọt một cách vô nghĩa.');
    });

    test('hạ mục tiêu xuống dưới số đã tích thì ĐÁNH DẤU hoàn thành', () async {
      // g1 đang có 2.000.000 trên mục tiêu 20.000.000.
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 1500000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.isCompleted, isTrue,
          reason: 'Cờ hoàn thành là giá trị SUY RA từ tiến độ so với mục '
              'tiêu, cùng luật với withdrawFromGoal. Bỏ qua ở đường sửa thì '
              'màn hình hiện 133% trong khi cờ vẫn nói chưa xong.');
    });

    test('nâng mục tiêu lên trên số đã tích thì GỠ cờ hoàn thành', () async {
      await db.goalDao.insert(
        GoalsCompanion.insert(
          id: 'g_xong',
          idaccount: 1,
          name: 'Đã xong',
          targetAmount: 1000000.0,
          currentAmount: const Value(1000000.0),
          isCompleted: const Value(true),
          walletId: const Value('w_nhan'),
          targetDate: DateTime.now().add(const Duration(days: 10)),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.updateGoal(
        id: 'g_xong',
        name: 'Đã xong',
        targetAmount: 5000000.0,
        targetDate: DateTime.now().add(const Duration(days: 10)),
      );

      final goal = await repository.getGoalById('g_xong');
      expect(goal!.isCompleted, isFalse,
          reason: 'Giữ cờ thì _goalCandidates bỏ qua mục tiêu này vĩnh viễn — '
              'nâng mục tiêu lên gấp năm mà nó không bao giờ nhắc "chậm tiến '
              'độ" nữa. Cùng lý do với việc rút tiền gỡ cờ.');
    });

    test('tên rỗng thì từ chối, KHÔNG ghi gì', () async {
      await expectLater(
        repository.updateGoal(
          id: 'g1',
          name: '   ',
          targetAmount: 30000000.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
        throwsA(isA<ArgumentError>()),
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.name, 'Mua Laptop',
          reason: 'Phép kiểm ở giao diện có thể bị đường khác đi vòng qua; '
              'tầng dữ liệu phải tự chặn chứ không tin nơi gọi.');
      expect(goal.targetAmount, 20000000.0);
    });

    test('số tiền mục tiêu ≤ 0 thì từ chối', () async {
      await expectLater(
        repository.updateGoal(
          id: 'g1',
          name: 'Mua Laptop',
          targetAmount: 0.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
        throwsA(isA<ArgumentError>()),
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.targetAmount, 20000000.0,
          reason: 'Mục tiêu 0 đồng làm GoalEntity.progress trả thẳng 1.0 — '
              'một mục tiêu tự nhận đã hoàn thành mà không có đồng nào.');
    });

    test('mục tiêu không tồn tại thì báo lỗi', () async {
      await expectLater(
        repository.updateGoal(
          id: 'khong-co',
          name: 'Gì đó',
          targetAmount: 1000000.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('đổi biểu tượng và màu', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        icon: 'laptop_mac',
        colour: '#2196F3',
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.icon, 'laptop_mac');
      expect(goal.colour, '#2196F3');
    });

    test('không truyền biểu tượng/màu thì GIỮ NGUYÊN cái cũ', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        icon: 'school',
        colour: '#9C27B0',
      );

      await repository.updateGoal(
        id: 'g1',
        name: 'Tên mới thôi',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.icon, 'school',
          reason: 'Khác với cycleTakeMoney, null ở đây nghĩa là "không đổi" '
              'chứ không phải "xoá": biểu tượng và màu không có trạng thái '
              '"không có". Gán Value(null) sẽ đưa cột về mặc định và mọi mục '
              'tiêu lặng lẽ trở lại lá cờ xanh sau một lần sửa tên.');
      expect(goal.colour, '#9C27B0');
    });

    test('sửa được ghi chú', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        note: 'Để thay con máy cũ đã ì ạch.',
      );

      expect((await repository.getGoalById('g1'))?.note,
          'Để thay con máy cũ đã ì ạch.');
    });

    test('không truyền ghi chú thì GIỮ NGUYÊN, chuỗi rỗng mới là XOÁ', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        note: 'Lý do ban đầu.',
      );

      await repository.updateGoal(
        id: 'g1',
        name: 'Tên mới thôi',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );
      expect((await repository.getGoalById('g1'))?.note, 'Lý do ban đầu.',
          reason: 'Cùng luật với icon/colour: `null` là "nơi gọi không đụng '
              'tới", không phải "xoá". Trang sửa nào chỉ đổi tên mà vô tình '
              'xoá sạch ghi chú của người dùng là mất dữ liệu trong im lặng.');

      await repository.updateGoal(
        id: 'g1',
        name: 'Tên mới thôi',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        note: '',
      );
      expect((await repository.getGoalById('g1'))?.note, '',
          reason: 'Chuỗi rỗng là ý định XOÁ rõ ràng của người dùng — họ đã xoá '
              'sạch ô nhập. Gộp nó chung với `null` thì không còn cách nào bỏ '
              'ghi chú đi.');
    });

    test('bật trích tự động thì ĐẶT mốc chạy bằng bây giờ', () async {
      final truoc = DateTime.now();

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: 'w1',
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.autoDepositAmount, 500000.0);
      expect(goal.autoDepositWalletId, 'w1');
      expect(goal.autoDepositLastRun, isNotNull);
      // So theo GIÂY: Drift lưu DateTime thành mốc unix giây, nên mili-giây bị
      // cắt và một phép so `isBefore` thô sẽ đỏ ngẫu nhiên.
      expect(goal.autoDepositLastRun!.difference(truoc).inSeconds.abs() <= 5,
          isTrue,
          reason: 'Mốc chạy phải là LÚC BẬT, không phải ngày tạo mục tiêu. '
              'Lấy ngày tạo là bật công tắc hôm nay rồi bị trích ngược lại '
              'từng ấy kỳ cùng một lúc, bằng tiền thật.');
      expect(goal.autoDepositEnabled, isTrue);
    });

    test('sửa mục tiêu khi đang bật KHÔNG đặt lại mốc chạy', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: 'w1',
      );
      final mocDau = (await repository.getGoalById('g1'))!.autoDepositLastRun;

      await repository.updateGoal(
        id: 'g1',
        name: 'Tên khác hẳn',
        targetAmount: 25000000.0,
        targetDate: DateTime.now().add(const Duration(days: 120)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 700000.0,
        autoDepositWalletId: 'w1',
      );

      final sau = await repository.getGoalById('g1');
      expect(sau!.autoDepositLastRun, mocDau,
          reason: 'Đổi tên hay đổi số tiền trích không phải là bật lại. Đặt '
              'lại mốc ở mỗi lần lưu làm kỳ trích lùi ra xa mãi — người dùng '
              'sửa mục tiêu hàng tháng thì không bao giờ tới kỳ nào.');
      expect(sau.autoDepositAmount, 700000.0,
          reason: 'Số tiền mới vẫn phải có hiệu lực từ kỳ kế tiếp.');
    });

    test('tắt trích tự động thì XOÁ cả ba mảnh cấu hình', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: 'w1',
      );

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: null,
        autoDepositAmount: null,
        autoDepositWalletId: null,
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.autoDepositAmount, isNull);
      expect(goal.autoDepositWalletId, isNull);
      expect(goal.autoDepositLastRun, isNull,
          reason: 'Bỏ sót mốc chạy thì bật lại lần sau sẽ tính bù mọi kỳ trôi '
              'qua trong lúc công tắc đang TẮT — tiền bị trích cho quãng thời '
              'gian người dùng đã cố ý dừng.');
      expect(goal.autoDepositEnabled, isFalse);
    });

    test('thiếu ví nguồn thì coi như KHÔNG bật', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: null,
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.autoDepositEnabled, isFalse,
          reason: 'Thiếu một mảnh là không đủ để chuyển tiền. Đoán bù một ví '
              'nguồn mặc định chính là kiểu tự tiện đã bị loại ở mục 3.1.');
      expect(goal.autoDepositLastRun, isNull);
    });

    test('lưu mốc neo người dùng chọn vào cột đồng bộ được', () async {
      final moc = DateTime(2026, 10, 15, 8, 30);

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: 'w1',
        autoDepositAnchor: moc,
      );

      final goal = await repository.getGoalById('g1');
      expect(goal!.timeCycleTakeMoney, moc,
          reason: 'Mốc neo đi vào `time_cycle_take_money` — cột đã có sẵn '
              'trong payload đồng bộ và tên nó vốn nghĩa là "thời điểm cụ thể '
              'trích tiền trong chu kỳ". Kế hoạch thì theo người dùng sang máy '
              'khác; chỉ trạng thái thi hành mới ở lại máy này.');
      expect(goal.syncStatus, 'pending',
          reason: 'Khác ba cột cục bộ: cột này CÓ đi qua đồng bộ nên phải được '
              'đánh dấu cần đẩy.');
    });

    test('tắt trích tự động thì XOÁ luôn mốc neo', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
        autoDepositAmount: 500000.0,
        autoDepositWalletId: 'w1',
        autoDepositAnchor: DateTime(2026, 10, 15, 8),
      );

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: null,
        autoDepositAmount: null,
        autoDepositWalletId: null,
        autoDepositAnchor: null,
      );

      expect((await repository.getGoalById('g1'))!.timeCycleTakeMoney, isNull,
          reason: 'Mốc neo là một nửa của kế hoạch, cùng số phận với chu kỳ. '
              'Để sót lại thì bật công tắc lần sau sẽ dùng một nhịp cũ mà '
              'người dùng không còn nhìn thấy ở đâu trên màn hình.');
    });

    test('bỏ trống chu kỳ thì XOÁ chu kỳ đã lưu', () async {
      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: 'Month',
      );
      expect((await repository.getGoalById('g1'))!.cycleTakeMoney, 'Month');

      await repository.updateGoal(
        id: 'g1',
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        cycleTakeMoney: null,
      );

      expect((await repository.getGoalById('g1'))!.cycleTakeMoney, isNull,
          reason: 'Tắt công tắc "tự động trích tiền định kỳ" phải xoá được kế '
              'hoạch cũ. Dùng Value.absent() cho tham số null thì chu kỳ cũ '
              'dính lại mãi và hộp dự báo cứ so với một nhịp người dùng đã bỏ.');
    });
  });
}
