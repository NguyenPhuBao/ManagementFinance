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
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';
import 'package:flowmoney/features/goal/domain/id_khoan_trich.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

void main() {
  late AppDatabase db;
  late GoalAutoDepositRunner runner;

  /// 05/09/2025 — mốc bật công tắc trong mọi kịch bản dưới đây.
  ///
  /// Cả bộ test cố ý nằm trong **quá khứ** so với đồng hồ thật. Runner nhận
  /// `now` tiêm vào, nhưng `depositToGoal` ghi theo `DateTime.now()` — ở
  /// production hai thứ ấy là MỘT đồng hồ. Bản trước đặt kịch bản ở tương lai
  /// (`now: 2026-12-06`) nên hai đồng hồ nói ngược nhau, một tiền đề không xảy
  /// ra được ngoài đời. Ngày quá khứ thì mãi mãi vẫn là quá khứ, nên cách này
  /// vừa trung thực vừa không hết hạn.
  final batTu = DateTime(2025, 9, 5, 9);

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
      startDate: Value(DateTime(2025, 1, 1)),
      targetDate: DateTime(2026, 12, 31),
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

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.length, 1);
      expect(events.single.loai, LoaiTrich.trichDu);
      expect(events.single.soTien, 500000);

      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 500000);
      expect(goal.autoDepositLastRun, DateTime(2025, 10, 5, 9),
          reason: 'Mốc chạy phải nhảy tới đúng kỳ vừa xử lý. Để nguyên là lượt '
              'sau trích lại chính kỳ ấy — mỗi lần mở app một lần, bằng tiền '
              'thật.');

      expect((await db.walletDao.getById('w_nguon'))!.balance, 4500000);
      expect((await db.walletDao.getById('w_nhan'))!.balance, 500000);

      final txs = await giaoDichThat(db, 1);
      expect(txs.length, 1);
      expect(txs.single.type, 'transfer');
      expect(txs.single.goalId, 'g1');
      expect(txs.single.note, contains('Tích lũy mục tiêu'),
          reason: 'Dùng ĐÚNG tiền tố của khoản nạp tay. Một tiền tố riêng cho '
              'khoản tự động sẽ rơi khỏi `laKhoanRutKhoiMucTieu` và bị đọc '
              'chiều tiền bằng vị trí ví — đúng cái bẫy 4.2.');
    });

    test('ghi chú mang HẬU TỐ "(tự động)", và chiều tiền vẫn đọc đúng',
        () async {
      await themMucTieu();

      await runner.chay(1, now: DateTime(2025, 10, 6));

      final tx = (await giaoDichThat(db, 1)).single;
      expect(tx.note, 'Tích lũy mục tiêu: MuaXe$kHauToTuDong',
          reason: 'Đây là chỗ DUY NHẤT trong app ghi ra hậu tố. Bộ chạy quên '
              'bật cờ thì khoản do app tự chuyển tiền trông y hệt khoản người '
              'dùng tự bấm — hỏng hoàn toàn im lặng, vì tiền vẫn đi đúng chỗ.');
      expect(laKhoanTuDong(tx.note), isTrue);
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: tx.note,
          viCuaHang: tx.walletId,
          viTichLuy: 'w_nhan',
        ),
        isFalse,
        reason: 'Hậu tố không được đụng tới phép đọc chiều tiền. Kiểm ở ĐÂY '
            'chứ không chỉ ở test thuần: chuỗi thật đi qua CSDL rồi mới quay '
            'về, và đó mới là chuỗi người dùng nhìn thấy.',
      );
    });

    test('chưa tới kỳ thì không làm gì cả', () async {
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2025, 9, 20));

      expect(events, isEmpty);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
      expect(await giaoDichThat(db, 1), isEmpty);
    });
  });

  group('bỏ app nhiều kỳ', () {
    test('trích bù đủ số kỳ, mỗi kỳ một giao dịch', () async {
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2025, 12, 6));

      expect(events.length, 3, reason: 'Tháng 10, 11 và 12.');
      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 1500000);
      expect(goal.autoDepositLastRun, DateTime(2025, 12, 5, 9));
      expect((await giaoDichThat(db, 1)).length, 3,
          reason: 'Gộp ba kỳ thành một giao dịch làm lịch sử nói dối về nhịp '
              'tích luỹ, và bộ dự báo đọc chính lịch sử ấy.');
    });

    test('mỗi hàng giao dịch mang dấu thời gian của KỲ, không phải lúc bù',
        () async {
      await themMucTieu();

      // Mở app lúc 14:28 ngày 06/12 sau khi bỏ ba kỳ.
      await runner.chay(1, now: DateTime(2025, 12, 6, 14, 28));

      final moc = (await giaoDichThat(db, 1))
          .map((t) => t.date)
          .toList()
        ..sort();

      expect(
        moc,
        [
          DateTime(2025, 10, 5, 9),
          DateTime(2025, 11, 5, 9),
          DateTime(2025, 12, 5, 9),
        ],
        reason: 'Ba kỳ bù dồn vào một lượt chạy, nhưng chúng là ba sự việc của '
            'ba thời điểm khác nhau. Trước đây cả ba hàng đều mang '
            '`DateTime.now()` nên phần thống kê THEO NGÀY thấy một cột dựng '
            'đứng ở ngày mở app — trong khi trung tâm thông báo, vốn lấy mốc '
            'kỳ làm `createdAt`, hiện đúng ba ngày. Hai nơi nói hai chuyện '
            'khác nhau về cùng một sự việc.',
      );
    });

    test('ví cạn giữa chừng thì DỪNG, giữ mốc ở kỳ cuối cùng thành công',
        () async {
      await db.walletDao.updateBalance('w_nguon', 1200000);
      await themMucTieu();

      final events = await runner.chay(1, now: DateTime(2026, 3, 6));

      expect(events.where((e) => e.loai == LoaiTrich.trichDu).length, 2);
      expect(events.last.loai, LoaiTrich.viKhongDu);

      final goal = (await db.goalDao.getAll(1)).single;
      expect(goal.currentAmount, 1000000);
      expect(goal.autoDepositLastRun, DateTime(2025, 11, 5, 9),
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
      expect(await runner.chay(1, now: DateTime(2026, 1, 1)), isEmpty);
      expect(await giaoDichThat(db, 1), isEmpty);
    });

    test('mục tiêu đã hoàn thành', () async {
      await themMucTieu(target: 1000000, current: 1000000);
      final events = await runner.chay(1, now: DateTime(2025, 12, 6));
      expect(events, isEmpty,
          reason: 'Mục tiêu xong rồi thì không còn gì để trích, và một thông '
              'báo "đã trích 0 đồng" mỗi tháng là rác.');
      expect(await giaoDichThat(db, 1), isEmpty);
    });

    test('mục tiêu đã xoá mềm', () async {
      await themMucTieu();
      await db.goalDao.softDelete('g1');
      expect(await runner.chay(1, now: DateTime(2025, 12, 6)), isEmpty);
    });

    test('KHÔNG đụng tới mục tiêu của tài khoản khác', () async {
      await themMucTieu();
      expect(await runner.chay(999, now: DateTime(2025, 12, 6)), isEmpty,
          reason: 'Máy dùng chung: trích tiền của tài khoản khác là hỏng nặng '
              'nhất trong mọi cách hỏng ở đây.');
      expect(await giaoDichThat(db, 1), isEmpty);
    });
  });

  group('cấu hình hỏng', () {
    test('ví nguồn đã bị xoá thì báo, không ném', () async {
      await themMucTieu(viNguon: 'w_khong_ton_tai');

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'Ví nguồn KHÔNG được bảo vệ khỏi việc xoá như ví tích luỹ, '
              'nên ca này xảy ra thật. Ném ra ở đây sẽ giết cả vòng quét thông '
              'báo đang gọi nó.');
      expect(await giaoDichThat(db, 1), isEmpty);
    });

    test('⭐ ví nguồn ĐÃ XOÁ MỀM mà còn số dư thì dừng, không rút tiền (lát 3 Task 10 lộ ra)', () async {
      await themMucTieu();
      // Xoá qua DAO — đúng đường của nhánh kéo về khi ví bị xoá ở máy khác /
      // Admin-web, vốn không đi qua chốt "số dư phải bằng 0" của màn Quản lý ví.
      await db.walletDao.softDelete('w_nguon');

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'getById trả cả hàng đã xoá mềm; bản trước chỉ kiểm null nên '
              'ví đã xoá vẫn bị rút tiền.');
      expect(await giaoDichThat(db, 1), isEmpty);
      expect((await db.walletDao.getById('w_nguon'))!.balance, 5000000.0);
    });

    test('ví nguồn ĐÃ LƯU TRỮ thì dừng, không rút tiền', () async {
      await themMucTieu();
      await db.walletDao.setStatus('w_nguon', luuTru: true);

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'Lưu trữ ví là ĐÓNG BĂNG nó. Rút tiền im lặng khỏi một ví mà '
              'người dùng đã cất đi là đúng cách hỏng tệ nhất ở đây: họ không '
              'nhìn ví ấy nữa nên sẽ không thấy gì cả.');
      expect(await giaoDichThat(db, 1), isEmpty);
      expect((await db.walletDao.getById('w_nguon'))!.balance, 5000000.0);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
    });

    test('ví nguồn trùng ví tích luỹ thì báo, không chuyển tiền', () async {
      await themMucTieu(viNguon: 'w_nhan');

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.single.loai, LoaiTrich.khongChayDuoc,
          reason: 'Chuyển tiền sang chính nó không đổi số dư nào mà tiến độ '
              'vẫn tăng — mục tiêu tự đầy lên từ hư không.');
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
    });

    test('một mục tiêu hỏng KHÔNG chặn mục tiêu khác', () async {
      await themMucTieu(id: 'g_hong', ten: 'Hỏng', viNguon: 'w_ma');
      await themMucTieu(id: 'g_tot', ten: 'Tốt');

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

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

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events.single.loai, LoaiTrich.trichPhanConLai);
      expect(events.single.soTien, 200000);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 1200000);
      expect((await db.goalDao.getAll(1)).single.isCompleted, isTrue,
          reason: 'Trích tự động cũng phải bật cờ hoàn thành, vì nó đi qua '
              'đúng `depositToGoal` như khoản nạp tay.');
    });
  });

  // Spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 5: chạy nền làm "hai
  // máy cùng tới kỳ" thành ca thường — id tất định là thứ giữ MỘT hàng.
  Future<void> themKhoanMayKhac(DateTime ky, {bool daXoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: idKhoanTrichTuDong('g1', ky),
        idaccount: 1,
        walletId: 'w_nguon',
        walletTransfer: const Value('w_nhan'),
        amount: 500000,
        type: 'transfer',
        goalId: const Value('g1'),
        date: ky,
        isDeleted: Value(daXoa),
        updatedAt: DateTime(2025, 10, 5, 9, 1),
      ));

  group('id tất định (chạy nền, hai máy)', () {
    test('khoản trích mang id v5 của (mục tiêu, kỳ)', () async {
      await themMucTieu();
      await runner.chay(1, now: DateTime(2025, 10, 6));
      final tx = await db.transactionDao
          .getById(idKhoanTrichTuDong('g1', DateTime(2025, 10, 5, 9)));
      expect(tx, isNotNull, reason: 'id v4 ngẫu nhiên là hai máy cùng kỳ ra hai hàng trên server');
      expect(tx!.amount, 500000);
    });

    test('⭐ máy kia đã trích kỳ ấy (hàng cùng id đã có) → KHÔNG trừ tiền, KHÔNG sự kiện, vẫn đẩy mốc', () async {
      await themMucTieu();
      final ky = DateTime(2025, 10, 5, 9);
      await themKhoanMayKhac(ky);

      final events = await runner.chay(1, now: DateTime(2025, 10, 6));

      expect(events, isEmpty, reason: 'báo "Đã trích…" cho việc máy kia làm là nói dối');
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0,
          reason: 'tiến độ máy này tăng khi kéo về bản ghi mục tiêu của máy kia, không tự cộng');
      expect((await giaoDichThat(db, 1)).length, 1, reason: 'không ghi hàng thứ hai');
      expect((await db.goalDao.getAll(1)).single.autoDepositLastRun, ky,
          reason: 'không đẩy mốc thì lượt sau lại thử đúng kỳ ấy, mãi mãi');
    });

    test('hàng cùng id ĐÃ XOÁ MỀM → vẫn coi là đã trích (người dùng chủ động xoá)', () async {
      await themMucTieu();
      await themKhoanMayKhac(DateTime(2025, 10, 5, 9), daXoa: true);
      final events = await runner.chay(1, now: DateTime(2025, 10, 6));
      expect(events, isEmpty);
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
    });

    test('kỳ 1 đã có, kỳ 2 chưa → bỏ kỳ 1, trích kỳ 2', () async {
      await themMucTieu();
      await themKhoanMayKhac(DateTime(2025, 10, 5, 9));
      final events = await runner.chay(1, now: DateTime(2025, 11, 6));
      expect(events.map((e) => e.ky), [DateTime(2025, 11, 5, 9)]);
      expect((await db.goalDao.getAll(1)).single.autoDepositLastRun, DateTime(2025, 11, 5, 9));
    });
  });

  group('mốc chạy ghi CÙNG giao tác với khoản nạp', () {
    late GoalRepositoryImpl repo;
    setUp(() => repo = GoalRepositoryImpl(
          localDataSource: GoalLocalDataSourceImpl(db: db),
          db: db,
        ));

    test('depositToGoal(mocChayMoi:) ghi autoDepositLastRun', () async {
      await themMucTieu();
      await repo.depositToGoal(
        goalId: 'g1', goalName: 'MuaXe', depositAmount: 100000, walletId: 'w_nguon', idaccount: 1,
        occurredAt: DateTime(2025, 10, 5, 9), mocChayMoi: DateTime(2025, 10, 5, 9),
      );
      expect((await db.goalDao.getAll(1)).single.autoDepositLastRun, DateTime(2025, 10, 5, 9));
    });

    test('khoản nạp bị từ chối (ví không đủ) → mốc KHÔNG đổi', () async {
      await themMucTieu();
      await expectLater(
        repo.depositToGoal(
          goalId: 'g1', goalName: 'MuaXe', depositAmount: 99000000, walletId: 'w_nguon', idaccount: 1,
          occurredAt: DateTime(2025, 10, 5, 9), mocChayMoi: DateTime(2025, 10, 5, 9),
        ),
        throwsA(isA<StateError>()),
      );
      expect((await db.goalDao.getAll(1)).single.autoDepositLastRun, batTu,
          reason: 'đẩy mốc khi tiền chưa chuyển là kỳ ấy biến mất vĩnh viễn');
    });

    test('transactionId đã có → KyDaTrichException, không ghi gì', () async {
      await themMucTieu();
      final id = idKhoanTrichTuDong('g1', DateTime(2025, 10, 5, 9));
      await themKhoanMayKhac(DateTime(2025, 10, 5, 9));
      await expectLater(
        repo.depositToGoal(
          goalId: 'g1', goalName: 'MuaXe', depositAmount: 500000, walletId: 'w_nguon', idaccount: 1,
          occurredAt: DateTime(2025, 10, 5, 9), transactionId: id, mocChayMoi: DateTime(2025, 10, 5, 9),
        ),
        throwsA(isA<KyDaTrichException>()),
      );
      expect((await db.goalDao.getAll(1)).single.currentAmount, 0);
    });
  });
}

/// Giao dịch thật của tài khoản — **bỏ khoản mở sổ**.
///
/// Từ 2026-09-13 số dư ví suy từ sổ, nên mỗi ví có thêm một khoản "Số dư ban
/// đầu" làm điểm neo (`wallet/domain/so_du_mo_so.dart`). Nó là hàng thật trong
/// bảng nhưng không phải thu chi nào — đếm nó vào đây là mọi phép `single`
/// thành "Too many elements".
Future<List<Transaction>> giaoDichThat(AppDatabase db, int idaccount) async =>
    (await db.transactionDao.getAll(idaccount))
        .where((t) => !laKhoanMoSo(
            loai: t.type, categoryId: t.categoryId, ghiChu: t.note))
        .toList();
