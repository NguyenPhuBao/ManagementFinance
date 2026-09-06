/// Lịch nhắc hệ điều hành cho hoá đơn **bật tự trả**.
///
/// Bộ tự trả chỉ chạy khi app mở, nên tới đúng ngày đến hạn mà app đang đóng
/// thì không có đồng nào rời ví. Lịch "sắp đến hạn" đang có là thứ kéo người
/// dùng mở app; với hoá đơn tự trả, thân câu phải nói điều đó thay vì bảo họ
/// đi trả tay. Không thêm lịch mới — cùng khoá, cùng mốc.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/core/notification/reminder_scheduler.dart';

class _OsGia implements OsNotifier {
  final Map<int, ({DateTime when, String title, String body, String? payload})>
      lich = {};

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    lich[id] = (when: when, title: title, body: body, payload: payload);
  }

  @override
  Future<Set<int>> pendingIds() async => lich.keys.toSet();
  @override
  Future<void> cancel(int id) async => lich.remove(id);
  @override
  Future<void> cancelAll() async => lich.clear();
}

void main() {
  const accountId = 7;
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase db;
  late _OsGia os;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    os = _OsGia();
  });

  tearDown(() => db.close());

  Bill hoaDon({required bool tuTra}) => Bill(
        id: 'hd1',
        idaccount: accountId,
        walletId: 'w1',
        categoryId: 'c1',
        name: 'Tiền điện',
        amount: 300000,
        dueDate: DateTime(2026, 9, 20),
        payStatus: 'Pending',
        isPaid: false,
        autoPayEnabled: tuTra,
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

  Future<void> dong(List<Bill> bills) => ReminderScheduler(
        osNotifier: os,
        loadBills: (id, at) async => bills,
        prefsStore: InMemoryNotificationPrefsStore(),
        clock: () => now,
      ).resync(accountId);

  test('hoá đơn tự trả: thân câu bảo mở app để được tự trả', () async {
    await dong([hoaDon(tuTra: true)]);

    final l = os.lich.values.single;
    expect(l.body, contains('Tiền điện'));
    expect(l.body.toLowerCase(), contains('mở app'),
        reason: 'Người dùng đã uỷ quyền cho app trả. Bảo họ "còn 3 ngày tới '
            'hạn" là bảo họ đi trả tay — sai kỳ vọng.');
    expect(l.body.toLowerCase(), contains('tự'));
  });

  test('hoá đơn thường: thân câu như cũ', () async {
    await dong([hoaDon(tuTra: false)]);

    expect(os.lich.values.single.body, contains('ngày tới hạn'));
  });

  test('cùng khoá lịch dù bật hay tắt tự trả', () async {
    await dong([hoaDon(tuTra: false)]);
    final khoaCu = os.lich.values.single.payload;
    os.lich.clear();

    await dong([hoaDon(tuTra: true)]);

    expect(os.lich.values.single.payload, khoaCu,
        reason: 'Đổi thân câu không được đổi khoá: khoá là điểm nối với thông '
            'báo trong app, và một hoá đơn đổi công tắc không phải một sự kiện '
            'mới.');
  });
}
