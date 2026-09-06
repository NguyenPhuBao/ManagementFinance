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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';

/// Ghi lại mọi lời gọi xuống hệ điều hành. Không dùng thư viện mock: cái cần
/// canh ở đây là **hành vi của scanner**, và một lớp tay viết thì đọc test là
/// thấy ngay scanner phải làm gì.
class OsNotifierGia implements OsNotifier {
  final List<({int id, String title, String body, String? payload})> daBan = [];
  final List<int> daHuy = [];
  int soLanHuyHet = 0;
  int soLanKhoiTao = 0;

  /// Bật lên để mô phỏng nền tảng ném lỗi — trường hợp thật hay gặp nhất là
  /// người dùng đã từ chối quyền thông báo.
  bool nemKhiBan = false;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async => soLanKhoiTao++;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (nemKhiBan) throw Exception('quyền thông báo bị từ chối');
    daBan.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<Set<int>> pendingIds() async => const {};

  @override
  Future<void> cancel(int id) async => daHuy.add(id);

  @override
  Future<void> cancelAll() async => soLanHuyHet++;
}

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

  NotificationScanner dungScanner({
    List<BudgetView>? budgets,
    List<Bill> bills = const [],
    List<GoalEntity> goals = const [],
    List<Wallet> wallets = const [],
    OsNotifier? osNotifier,
    NotificationPrefsStore? prefs,
    Future<void> Function(int idaccount)? onResyncLich,
  }) {
    var soId = 0;
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (id, at) async {
        soLanNap++;
        return budgets ?? [nganSach()];
      },
      loadBills: (id, at) async => bills,
      loadGoals: (id, at) async => goals,
      loadWallets: (id, at) async => wallets,
      syncStatus: syncStatus.stream,
      osNotifier: osNotifier,
      prefsStore: prefs,
      resyncLich: onResyncLich,
      clock: () => now,
      idGenerator: () => 'id-${soId++}',
    );
  }

  Bill hoaDon({required DateTime denHan, String id = 'hd1'}) {
    return Bill(
      id: id,
      idaccount: accountId,
      name: 'Tiền điện',
      amount: 300000,
      dueDate: denHan,
      payStatus: 'Pending',
      isPaid: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: 'Month',
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
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

  group('bắn ra hệ điều hành', () {
    test('mỗi hàng MỚI được bắn một thông báo hệ điều hành', () async {
      final os = OsNotifierGia();
      final moi = await dungScanner(osNotifier: os).scan(accountId);

      expect(moi, 1);
      expect(os.daBan.length, 1,
          reason: 'Thông báo chỉ nằm trong app thì người dùng phải mở app mới '
              'thấy — đúng thứ tính năng này sinh ra để tránh.');
      expect(os.daBan.single.title, 'Sắp vượt ngân sách');
      expect(os.daBan.single.body, contains('Ăn uống'));
    });

    test('id bắn ra đúng bằng osScheduledId(dedupeKey)', () async {
      final os = OsNotifierGia();
      await dungScanner(osNotifier: os).scan(accountId);

      final hang = (await db.notificationDao.getAll(accountId)).single;
      expect(os.daBan.single.id, osScheduledId(hang.dedupeKey),
          reason: 'Id phải suy được từ dedupeKey mà không cần đọc CSDL, nếu '
              'không thì lát sau không huỷ được lịch của một hoá đơn vừa bị '
              'xoá. Đây cũng là chỗ dễ lỡ tay dùng String.hashCode.');
      expect(os.daBan.single.payload, hang.dedupeKey,
          reason: 'Payload là đường duy nhất để lúc người dùng bấm vào thông '
              'báo, app biết mở đúng bản ghi nào.');
    });

    test('quét lần hai không bắn lại thông báo cũ', () async {
      final os = OsNotifierGia();
      final scanner = dungScanner(osNotifier: os);
      await scanner.scan(accountId);
      await scanner.scan(accountId);

      expect(os.daBan.length, 1,
          reason: 'Quét chạy sau MỌI lần đồng bộ. Bắn theo danh sách đọc lên '
              'thay vì theo danh sách vừa ghi là người dùng nhận lại đúng '
              'thông báo ấy mỗi lần mở app, và họ sẽ tắt hẳn tính năng.');
    });

    test('nền tảng ném lỗi thì lượt quét vẫn hoàn tất', () async {
      final os = OsNotifierGia()..nemKhiBan = true;
      final moi = await dungScanner(osNotifier: os).scan(accountId);

      expect(moi, 1,
          reason: 'Người dùng từ chối quyền thông báo là chuyện thường. Để lỗi '
              'đó nổ lên trên là mất luôn trung tâm thông báo trong app, tức '
              'là mất phần vẫn còn dùng được.');
      expect((await db.notificationDao.getAll(accountId)).length, 1,
          reason: 'Hàng đã ghi rồi thì phải ở lại — bắn ra hệ điều hành là '
              'bước phụ, không phải điều kiện để lưu.');
    });

    test('không cấu hình osNotifier thì quét vẫn chạy bình thường', () async {
      final moi = await dungScanner().scan(accountId);
      expect(moi, 1,
          reason: 'Trên web không có thông báo hệ điều hành. Scanner phải chạy '
              'được khi không có notifier nào cả.');
    });

    test('stop() huỷ toàn bộ lịch đã đặt trên hệ điều hành', () async {
      final os = OsNotifierGia();
      final scanner = dungScanner(osNotifier: os);
      await scanner.start(accountId);
      await scanner.stop();

      expect(os.soLanHuyHet, 1,
          reason: 'Đây là lỗ rò dữ liệu nghiêm trọng nhất của tính năng: lịch '
              'nằm trong AlarmManager/UNUserNotificationCenter chứ không trong '
              'SQLite, nên purgeDataForOtherAccounts không chạm tới được. '
              'Thiếu cancelAll() là nhắc hoá đơn của người đăng nhập trước nổ '
              'trên màn hình khoá của người đăng nhập sau.');
    });
  });

  group('tuỳ chọn của người dùng', () {
    test('tắt một nhóm thì không sinh thông báo của nhóm đó', () async {
      final prefs = InMemoryNotificationPrefsStore();
      await prefs.write(
        accountId,
        const NotificationPrefs(nhomTat: {NotificationGroup.budget}),
      );

      final moi = await dungScanner(
        prefs: prefs,
        bills: [hoaDon(denHan: DateTime(2026, 9, 17))],
      ).scan(accountId);

      expect(moi, 1);
      expect(
          (await db.notificationDao.getAll(accountId)).single.kind,
          'billDueSoon',
          reason: 'Tắt nhóm là không sinh thông báo nhóm ấy — cả trong app lẫn '
              'ra hệ điều hành. Chỉ chặn ở bước bắn thì trung tâm thông báo '
              'vẫn đầy những mục người dùng đã nói là không muốn thấy.');
    });

    test('tắt một nhóm không làm im các nhóm còn lại', () async {
      final prefs = InMemoryNotificationPrefsStore();
      await prefs.write(
        accountId,
        const NotificationPrefs(nhomTat: {NotificationGroup.bill}),
      );

      final moi = await dungScanner(
        prefs: prefs,
        bills: [hoaDon(denHan: DateTime(2026, 9, 17))],
      ).scan(accountId);

      expect(moi, 1);
      expect((await db.notificationDao.getAll(accountId)).single.kind,
          'budgetNearLimit',
          reason: 'Đây là lý do người dùng có bốn công tắc chứ không phải một.');
    });

    test('tắt công tắc OS thì VẪN ghi vào app, chỉ không bắn ra ngoài',
        () async {
      final os = OsNotifierGia();
      final prefs = InMemoryNotificationPrefsStore();
      await prefs.write(accountId, const NotificationPrefs(osBat: false));

      final moi =
          await dungScanner(prefs: prefs, osNotifier: os).scan(accountId);

      expect(moi, 1);
      expect((await db.notificationDao.getAll(accountId)).length, 1,
          reason: 'Công tắc OS là "đừng làm phiền tôi", không phải "đừng ghi '
              'lại gì". Người tắt nó vẫn muốn mở app xem lại được.');
      expect(os.daBan, isEmpty,
          reason: 'Bật lại đúng thứ người dùng vừa tắt là cách nhanh nhất để '
              'họ tắt hẳn tính năng.');
    });

    test('không cấu hình kho tuỳ chọn thì chạy như mặc định', () async {
      final os = OsNotifierGia();
      final moi = await dungScanner(osNotifier: os).scan(accountId);

      expect(moi, 1);
      expect(os.daBan.length, 1,
          reason: 'Thiếu kho tuỳ chọn không được làm tính năng im lặng — mặc '
              'định là bật hết.');
    });

    test('số ngày nhắc trong tuỳ chọn được dùng thật', () async {
      final prefs = InMemoryNotificationPrefsStore();
      await prefs.write(
          accountId, const NotificationPrefs(soNgayNhacHoaDon: 7));

      // Hoá đơn KHÔNG tự đặt số ngày, còn 5 ngày nữa tới hạn.
      final hd = hoaDon(denHan: DateTime(2026, 9, 20))
          .copyWith(timeNotification: const Value.absent());

      final moi = await dungScanner(
        prefs: prefs,
        budgets: const [],
        bills: [hd.copyWith(timeNotification: const Value(null))],
      ).scan(accountId);

      expect(moi, 1,
          reason: 'Tuỳ chọn "nhắc trước 7 ngày" phải tới được bộ luật. Lưu mà '
              'không ai đọc thì công tắc trông như có tác dụng mà thật ra '
              'không — kiểu hỏng không ai báo lỗi.');
      expect((await db.notificationDao.getAll(accountId)).single.kind,
          'billDueSoon');
    });

    test('đọc tuỳ chọn theo ĐÚNG tài khoản đang quét', () async {
      final prefs = InMemoryNotificationPrefsStore();
      // Tài khoản 9 tắt hết; tài khoản 7 để mặc định.
      await prefs.write(
        9,
        const NotificationPrefs(nhomTat: {NotificationGroup.budget}),
      );

      final moi = await dungScanner(prefs: prefs).scan(accountId);

      expect(moi, 1,
          reason: 'Đọc nhầm tuỳ chọn của tài khoản khác là người dùng thấy '
              'thông báo bật/tắt ngẫu nhiên trên máy dùng chung.');
    });
  });

  group('lát 6 — mục tiêu, ví, đồng bộ', () {
    GoalEntity mucTieu({double current = 1000}) => GoalEntity(
          id: 'mt1',
          idaccount: accountId,
          name: 'MacBook',
          targetAmount: 1000,
          currentAmount: current,
          startDate: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 12, 31),
          updatedAt: DateTime(2026, 9, 1),
        );

    Wallet viAm() => Wallet(
          id: 'vi1',
          idaccount: accountId,
          name: 'Tiền mặt',
          type: 'cash',
          balance: -50000,
          currency: 'VND',
          icon: 'wallet',
          colour: '#4CAF50',
          isDefault: false,
          status: 'active',
          isDeleted: false,
          syncRetryCount: 0,
          includeInTotal: true,
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 9, 1),
        );

    test('quét sinh cả thông báo mục tiêu lẫn ví', () async {
      final moi = await dungScanner(
        budgets: const [],
        goals: [mucTieu()],
        wallets: [viAm()],
      ).scan(accountId);

      expect(moi, 2);
      final loai = (await db.notificationDao.getAll(accountId))
          .map((n) => n.kind)
          .toSet();
      expect(loai, {'goalCompleted', 'walletNegative'});
    });

    test('đồng bộ kết thúc ở trạng thái lỗi thì sinh thông báo', () async {
      final scanner = dungScanner(budgets: const []);
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.error);
      await Future<void>.delayed(Duration.zero);

      expect((await db.notificationDao.getAll(accountId)).single.kind,
          'syncFailed',
          reason: 'statusStream và cột syncError tồn tại từ lâu mà chưa có ai '
              'tiêu thụ. Người dùng cần biết dữ liệu chưa lên được server.');
      await scanner.stop();
    });

    test('đồng bộ xong bình thường thì KHÔNG báo hỏng', () async {
      final scanner = dungScanner(budgets: const []);
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.idle);
      await Future<void>.delayed(Duration.zero);

      expect(await db.notificationDao.getAll(accountId), isEmpty);
      await scanner.stop();
    });

    test('hết lỗi rồi thì lượt quét sau không báo lại', () async {
      final scanner = dungScanner(budgets: const []);
      await scanner.start(accountId);

      syncStatus.add(SyncStatus.error);
      await Future<void>.delayed(Duration.zero);
      await db.notificationDao.purgeOlderThan(DateTime(2030));

      syncStatus.add(SyncStatus.idle);
      await Future<void>.delayed(Duration.zero);

      expect(await db.notificationDao.getAll(accountId), isEmpty,
          reason: 'Cờ hỏng phải được xoá khi lượt đồng bộ kế tiếp thành công, '
              'nếu không mỗi lần quét về sau đều báo lại một sự cố đã qua.');
      await scanner.stop();
    });
  });

  group('dọn thông báo cũ', () {
    test('start() xoá những thông báo quá 90 ngày', () async {
      await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: 'cu',
        idaccount: accountId,
        kind: 'billOverdue',
        dedupeKey: 'k-cu',
        title: 'Cũ',
        body: 'Cũ',
        severity: 'warning',
        createdAt: now.subtract(const Duration(days: 200)),
      ));
      await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: 'moi',
        idaccount: accountId,
        kind: 'billOverdue',
        dedupeKey: 'k-moi',
        title: 'Mới',
        body: 'Mới',
        severity: 'warning',
        createdAt: now.subtract(const Duration(days: 10)),
      ));

      final scanner = dungScanner();
      await scanner.start(accountId);

      final conLai =
          (await db.notificationDao.getAll(accountId)).map((n) => n.id).toSet();
      expect(conLai, contains('moi'));
      expect(conLai, isNot(contains('cu')),
          reason: 'Hàng đã xoá mềm phải giữ để chặn trùng, nên bảng này chỉ lớn '
              'lên. Không dọn thì sau một năm màn danh sách tải hàng nghìn '
              'hàng.');
      await scanner.stop();
    });
  });

  group('nối với lịch đặt trước', () {
    test('mỗi lượt quét kéo theo một lần đồng bộ lại lịch', () async {
      var soLanResync = 0;
      final scanner = dungScanner(
        onResyncLich: (id) async => soLanResync++,
      );

      await scanner.scan(accountId);

      expect(soLanResync, 1,
          reason: 'Lịch đặt trước phải theo kịp dữ liệu. Hoá đơn vừa thanh '
              'toán mà lịch cũ còn nguyên là điện thoại vẫn kêu nhắc trả một '
              'hoá đơn đã trả — lỗi khó chịu nhất của loại tính năng này.');
    });

    test('quét không sinh hàng nào vẫn phải đồng bộ lại lịch', () async {
      var soLanResync = 0;
      final scanner = dungScanner(
        budgets: const [],
        onResyncLich: (id) async => soLanResync++,
      );

      final moi = await scanner.scan(accountId);

      expect(moi, 0);
      expect(soLanResync, 1,
          reason: 'Việc "không có gì mới để báo" và việc "lịch tương lai đã '
              'đúng chưa" là hai chuyện khác nhau. Hoá đơn bị xoá không sinh '
              'thông báo nào nhưng vẫn phải gỡ lịch của nó.');
    });

    test('đồng bộ lịch hỏng không làm hỏng lượt quét', () async {
      final scanner = dungScanner(
        onResyncLich: (id) async => throw Exception('AlarmManager trở chứng'),
      );

      expect(await scanner.scan(accountId), 1,
          reason: 'Hàng đã ghi vào CSDL rồi; để lỗi đặt lịch nổi lên là mất cả '
              'trung tâm thông báo trong app.');
    });

    test('đồng bộ lịch theo ĐÚNG tài khoản đang quét', () async {
      int? idDaResync;
      final scanner = dungScanner(
        onResyncLich: (id) async => idDaResync = id,
      );

      await scanner.scan(9);

      expect(idDaResync, 9,
          reason: 'Đặt nhắc hoá đơn của tài khoản khác lên máy này là rò dữ '
              'liệu tài chính ra màn hình khoá.');
    });
  });

  group('hoá đơn', () {
    test('quét sinh cả thông báo hoá đơn lẫn ngân sách', () async {
      final moi = await dungScanner(
        bills: [hoaDon(denHan: DateTime(2026, 9, 17))],
      ).scan(accountId);

      expect(moi, 2);
      final loai = (await db.notificationDao.getAll(accountId))
          .map((n) => n.kind)
          .toSet();
      expect(loai, {'budgetNearLimit', 'billDueSoon'});
    });

    test('bỏ qua sự kiện quá cũ để không dội lũ ở lần bật đầu tiên', () async {
      final moi = await dungScanner(
        budgets: const [],
        bills: [hoaDon(denHan: DateTime(2026, 1, 5))],
      ).scan(accountId);

      expect(moi, 0,
          reason: 'Một hoá đơn quá hạn từ tám tháng trước không đáng bắn thông '
              'báo lúc người dùng vừa bật tính năng. Scanner phải tự đặt mốc '
              'silenceBefore chứ không để bộ luật trả về tất cả.');
    });

    test('hoá đơn quá hạn gần đây vẫn được báo', () async {
      final moi = await dungScanner(
        budgets: const [],
        bills: [hoaDon(denHan: DateTime(2026, 9, 10))],
      ).scan(accountId);

      expect(moi, 1);
      expect((await db.notificationDao.getAll(accountId)).single.kind,
          'billOverdue');
    });
  });
}
