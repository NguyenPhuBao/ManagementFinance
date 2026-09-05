/// Bộ chạy trích tiền tự động — nơi **duy nhất** trong app tự ý chuyển tiền
/// của người dùng khi họ không có mặt.
///
/// Vì thế mọi test ở đây kiểm cả hai vế: tiền có đi đúng chỗ không, và **có
/// dừng lại đúng lúc không**. Vế thứ hai quan trọng hơn: một khoản trích thiếu
/// thì người dùng bấm nạp tay là xong, còn một vòng lặp trích nhầm sẽ rút cạn
/// ví trước khi ai kịp nhìn thấy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit_runner.dart';

void main() {
  late AppDatabase db;
  late GoalAutoDepositRunner runner;

  /// 05/09/2026 — mốc bật công tắc trong mọi kịch bản dưới đây.
  final batTu = DateTime(2026, 9, 5, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );
    runner = GoalAutoDepositRunner(db: db, repository: repository);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w_nguon',
      idaccount: 1,
      name: 'Tiền mặt',
      balance: const Value(5000000.0),
      updatedAt: DateTime.now(),
    ));
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w_nhan',
      idaccount: 1,
      name: 'Tiết kiệm',
      balance: const Value(0.0),
      updatedAt: DateTime.now(),
    ));
  });

  tearDown(() async => db.close());

  Future<void> themMucTieu({
    String id = 'g1',
    String ten = 'MuaXe',
    double target = 10000000,
    double current = 0,
    String? chuKy = 'Month',
    double? soTien = 500000,
    String? viNguon = 'w_nguon',
    DateTime? mocChay,
    String? viNhan = 'w_nhan',
  }) async {
    await db.goalDao.insert(GoalsCompanion.insert(
      id: id,
      idaccount: 1,
      name: ten,
      targetAmount: target,
      currentAmount: Value(current),
      walletId: Value(viNhan),
      startDate: Value(DateTime(2026, 1, 1)),
      targetDate: DateTime(2027, 12, 31),
      cycleTakeMoney: Value(chuKy),
      autoDepositAmount: Value(soTien),
      autoDepositWalletId: Value(viNguon),
      autoDepositLastRun: Value(mocChay ?? batTu),
      updatedAt: DateTime.now(),
    ));
  }

  group('một kỳ tới hạn', () {
    test('chuyển tiền, tăng tiến độ, ghi MỘT giao dịch, đẩy mốc chạy', () async {
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2026, 10, 6));

      expect(events.length, 1);
      expect(events.single.loai, LoaiTrich.trichDu);
      expect(events.single.soTien, 500000);

      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 500000);
      expect(goal.autoDepositLastRun, DateTime(2026, 10, 5, 9),
          reason: 'Mốc chạy phải nhảy tới đúng kỳ vừa xử lý. Để nguyên là lượt '
              'sau trích lại chính kỳ ấy — mỗi lần mở app một lần, bằng tiền '
              'thật.');

      expect((await db.walletDao.getById('w_nguon'))!.balance, 4500000);
      expect((await db.walletDao.getById('w_nhan'))!.balance, 500000);

      final txs = await db.transactionDao.getAll(1);
      expect(txs.length, 1);
      expect(txs.single.type, 'transfer');
      expect(txs.single.goalId, 'g1');
      expect(txs.single.note, contains('Tích lũy mục tiêu'),
          reason: 'Dùng ĐÚNG tiền tố của khoản nạp tay. Một tiền tố riêng cho '
              'khoản tự động sẽ rơi khỏi `laKhoanRutKhoiMucTieu` và bị đọc '
              'chiều tiền bằng vị trí ví — đúng cái bẫy 4.2.');
    });

    test('chưa tới kỳ thì không làm gì cả', () async {
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2026, 9, 20));

      expect(events, isEmpty);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });
  });

  group('bỏ app nhiều kỳ', () {
    test('trích bù đủ số kỳ, mỗi kỳ một giao dịch', () async {
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2026, 12, 6));

      expect(events.length, 3, reason: 'Tháng 10, 11 và 12.');
      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 1500000);
      expect(goal.autoDepositLastRun, DateTime(2026, 12, 5, 9));
      expect((await db.transactionDao.getAll(1)).length, 3,
          reason: 'Gộp ba kỳ thành một giao dịch làm lịch sử nói dối về nhịp '
              'tích luỹ, và bộ dự báo đọc chính lịch sử ấy.');
    });

    test('ví cạn giữa chừng thì DỪNG, giữ mốc ở kỳ cuối cùng thành công',
        () async {
      await db.walletDao.updateBalance('w_nguon', 1200000);
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2027, 3, 6));

      expect(events.where((e) => e.loai == LoaiTrich.trichDu).length, 2);
      expect(events.last.loai, LoaiTrich.viKhongDu);

      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 1000000);
      expect(goal.autoDepositLastRun, DateTime(2026, 11, 5, 9),
          reason: 'Mốc dừng ở kỳ CUỐI CÙNG thành công, không nhảy tới hiện '
              'tại. Nhảy qua là những kỳ chưa trích được biến mất vĩnh viễn; '
              'giữ lại thì chúng tự thử lại khi ví có tiền.');
      expect((await db.walletDao.getById('w_nguon'))!.balance, 200000,
          reason: 'Số dư không bao giờ được xuống âm.');
    });
  });

  group('những ca phải im lặng bỏ qua', () {
    test('mục tiêu chưa bật trích tự động', () async {
      await themMucTieu(soTien: null, viNguon: null, mocChay: null);
      expect(await runner.chay(1, now: DateTime(2027, 1, 1)), isEmpty);
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('mục tiêu đã hoàn thành', () async {
      await themMucTieu(target: 1000000, current: 1000000);
      final events = await runner.chay(1, now: DateTime(2026, 12, 6));
      expect(events, isEmpty,
          reason: 'Mục tiêu xong rồi thì không còn gì để trích, và một thông '
              'báo "đã trích 0 đồng" mỗi tháng là rác.');
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('mục tiêu đã xoá mềm', () async {
      await themMucTieu();
      await db.goalDao.softDelete('g1');
      expect(await runner.chay(1, now: DateTime(2026, 12, 6)), isEmpty);
    });

    test('KHÔNG đụng tới mục tiêu của tài khoản khác', () async {
      await themMucTieu();
      expect(await runner.chay(999, now: DateTime(2026, 12, 6)), isEmpty,
          reason: 'Máy dùng chung: trích tiền của tài khoản khác là hỏng nặng '
              'nhất trong mọi cách hỏng ở đây.');
      expect(await db.transactionDao.getAll(1), isEmpty);
    });
  });

  group('cấu hình hỏng', () {
    test('ví nguồn đã bị xoá thì báo, không ném', () async {
      await themMucTieu(viNguon: 'w_khong_ton_tai');

      final events = await runner.chay(1, now: DateTime(2026, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'Ví nguồn KHÔNG được bảo vệ khỏi việc xoá như ví tích luỹ, '
              'nên ca này xảy ra thật. Ném ra ở đây sẽ giết cả vòng quét thông '
              'báo đang gọi nó.');
      expect(await db.transactionDao.getAll(1), isEmpty);
    });

    test('ví nguồn trùng ví tích luỹ thì báo, không chuyển tiền', () async {
      await themMucTieu(viNguon: 'w_nhan');

      final events = await runner.chay(1, now: DateTime(2026, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'Chuyển tiền sang chính nó không đổi số dư nào mà tiến độ '
              'vẫn tăng — mục tiêu tự đầy lên từ hư không.');
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
    });

    test('một mục tiêu hỏng KHÔNG chặn mục tiêu khác', () async {
      await themMucTieu(id: 'g_hong', ten: 'Hỏng', viNguon: 'w_ma');
      await themMucTieu(id: 'g_tot', ten: 'Tốt');

      final events = await runner.chay(1, now: DateTime(2026, 10, 6));

      expect(events.length, 2);
      expect(
          events.firstWhere((e) => e.goalId == 'g_tot').loai, LoaiTrich.trichDu,
          reason: 'Duyệt từng mục tiêu độc lập. Để một cấu hình hỏng chặn cả '
              'vòng là một mục tiêu lỗi làm mọi mục tiêu khác ngừng trích, im '
              'lặng, cho tới khi ai đó phát hiện.');
    });
  });

  group('kẹp ở phần còn thiếu', () {
    test('kỳ cuối chỉ trích đúng phần còn lại, không nạp vượt', () async {
      await themMucTieu(target: 1200000, current: 1000000);

      final events = await runner.chay(1, now: DateTime(2026, 10, 6));

      expect(events.single.loai, LoaiTrich.trichPhanConLai);
      expect(events.single.soTien, 200000);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 1200000);
      expect((await db.goalDao.getAll(1)).single.isCompleted, isTrue,
          reason: 'Trích tự động cũng phải bật cờ hoàn thành, vì nó đi qua '
              'đúng `depositToGoal` như khoản nạp tay.');
    });
  });
}
