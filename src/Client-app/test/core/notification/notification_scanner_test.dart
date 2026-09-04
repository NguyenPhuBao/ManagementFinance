/// `NotificationScanner` — nối bộ luật với CSDL và với vòng đời app.
///
/// Ba điều đáng canh, cả ba đều không làm app chết mà chỉ làm thông báo sai:
///
/// 1. **Quét lại không được đẻ thêm hàng.** Đây là hệ quả trực tiếp của việc
///    thông báo là dữ liệu suy ra được — mỗi lượt quét nhìn thấy lại đúng sự
///    kiện cũ.
/// 2. **`stop()` phải cắt đứt hẳn.** Còn sót subscription là sau khi đăng xuất
///    vẫn quét, và quét bằng `idaccount` của người vừa rời đi.
/// 3. **`start()` gọi nhiều lần không được nhân listener.** `home_page.dart`
///    gọi `SyncEngine.start()` ngay trong `build()`; ai đó chép mẫu ấy sang đây
///    thì mỗi lần Home rebuild là thêm một listener, và một sự kiện đồng bộ sẽ
///    kích hoạt n lượt quét.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';

void main() {
  const accountId = 7;
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase db;
  late StreamController<SyncStatus> syncStatus;
  late int soLanNap;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncStatus = StreamController<SyncStatus>.broadcast();
    soLanNap = 0;
  });

  tearDown(() async {
    await syncStatus.close();
    await db.close();
  });

  BudgetView nganSach({String id = 'b1', double spent = 4600000}) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: accountId,
        categoryId: 'cat-an-uong',
        amount: 5000000,
        spent: spent,
        overSpending: 'Over',
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        note: '',
        isDeleted: false,
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );
  }

  NotificationScanner dungScanner({List<BudgetView>? budgets}) {
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (id, at) async {
        soLanNap++;
        return budgets ?? [nganSach()];
      },
      syncStatus: syncStatus.stream,
      clock: () => now,
      idGenerator: () => 'id-$soLanNap',
    );
  }

  group('quét', () {
    test('sinh hàng từ bộ luật và ghi xuống CSDL', () async {
      final moi = await dungScanner().scan(accountId);

      expect(moi, 1);
      final rows = await db.notificationDao.getAll(accountId);
      expect(rows.single.kind, 'budgetNearLimit');
      expect(rows.single.idaccount, accountId,
          reason: 'Ghi nhầm idaccount là thông báo hiện cho người khác.');
      expect(rows.single.body, contains('Ăn uống'));
    });

    test('quét lần hai với dữ liệu không đổi không đẻ thêm hàng', () async {
      final scanner = dungScanner();
      await scanner.scan(accountId);
      final lanHai = await scanner.scan(accountId);

      expect(lanHai, 0,
          reason: 'Giá trị trả về điều khiển việc bắn thông báo ra hệ điều '
              'hành. Trả khác 0 là người dùng nhận lại thông báo cũ mỗi lần '
              'mở app.');
      expect((await db.notificationDao.getAll(accountId)).length, 1);
    });

    test('không có gì để báo thì trả 0', () async {
      final moi = await dungScanner(
        budgets: [nganSach(spent: 1000000)],
      ).scan(accountId);
      expect(moi, 0);
    });
  });

  group('vòng đời', () {
    /// Chờ cho micro-task của listener chạy xong.
    Future<void> nhipTho() => Future<void>.delayed(Duration.zero);

    test('sự kiện đồng bộ kết thúc thì kích hoạt quét', () async {
      final scanner = dungScanner();
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.idle);
      await nhipTho();

      expect(soLanNap, 1);
      expect((await db.notificationDao.getAll(accountId)).length, 1);
      await scanner.stop();
    });

    test('trạng thái chưa kết thúc thì KHÔNG quét', () async {
      final scanner = dungScanner();
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.syncing);
      await nhipTho();

      expect(soLanNap, 0,
          reason: 'Quét giữa chừng là đọc dữ liệu đang dở dang — số đã chi có '
              'thể thiếu những giao dịch vừa kéo về.');
      await scanner.stop();
    });

    test('stop() rồi thì không quét nữa', () async {
      final scanner = dungScanner();
      await scanner.start(accountId);
      await scanner.stop();

      syncStatus.add(SyncStatus.idle);
      await nhipTho();

      expect(soLanNap, 0,
          reason: 'Còn sót subscription là sau khi đăng xuất vẫn quét, và quét '
              'bằng idaccount của người vừa rời đi.');
    });

    test('start() hai lần thì mỗi sự kiện chỉ quét MỘT lần', () async {
      final scanner = dungScanner();
      await scanner.start(accountId);
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.idle);
      await nhipTho();

      expect(soLanNap, 1,
          reason: 'home_page.dart gọi SyncEngine.start() ngay trong build(). '
              'Chép mẫu đó sang đây mà không huỷ subscription cũ thì mỗi lần '
              'Home rebuild là thêm một listener.');
      await scanner.stop();
    });

    test('start() cho tài khoản khác thì quét theo tài khoản mới', () async {
      final scanner = dungScanner();
      await scanner.start(accountId);
      await scanner.start(9);

      syncStatus.add(SyncStatus.idle);
      await nhipTho();

      expect((await db.notificationDao.getAll(9)).length, 1);
      expect((await db.notificationDao.getAll(accountId)).length, 0,
          reason: 'Đổi người đăng nhập mà scanner còn giữ id cũ là ghi thông '
              'báo của người mới vào hồ sơ người cũ.');
      await scanner.stop();
    });
  });
}
