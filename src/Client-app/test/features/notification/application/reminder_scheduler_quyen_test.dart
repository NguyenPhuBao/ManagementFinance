/// B1 (spec 2026-10-27 mục 5) — quyền `bill_reminder_notifications` và `daily_recording_reminder` gác lịch hệ điều hành.
/// Không quyền → không đặt; lịch đã đặt bị huỷ ở lượt `resync` THƯỜNG kế (không cần `datLai`); quyền về → lịch về.
library;

import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/notification/application/reminder_scheduler.dart';
import 'package:flowmoney/features/notification/data/datasources/os_notifier.dart';
import 'package:flowmoney/features/notification/data/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/domain/cham_hdh.dart';
import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

class _OsGia implements OsNotifier {
  final Map<int, ({DateTime when, String title, String body, String? payload})> lich = {};

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> daCoQuyen() async => true;
  @override
  Future<void> show({required int id, required String title, required String body, String? payload}) async {}
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
  Stream<ChamHdh> get chamTho => const Stream<ChamHdh>.empty();
  @override
  Future<ChamHdh?> chamKhoiDong() async => null;
  @override
  Future<Set<int>> pendingIds() async => lich.keys.toSet();
  @override
  Future<Set<int>> activeIds() async => const {};
  @override
  Future<void> datBadge(int soLuong) async {}
  @override
  Future<void> cancel(int id) async => lich.remove(id);
  @override
  Future<void> cancelAll() async => lich.clear();
}

void main() {
  const id = 7;
  final now = DateTime(2026, 9, 15, 10);
  late _OsGia os;
  late InMemoryNotificationPrefsStore prefs;

  setUp(() async {
    os = _OsGia();
    prefs = InMemoryNotificationPrefsStore();
    await prefs.write(id, const NotificationPrefs(nhacGhiChepBat: true));
  });

  BillEntity hoaDon() => BillEntity(
        id: 'hd1',
        idaccount: id,
        walletId: 'w1',
        categoryId: 'c1',
        name: 'Tiền điện',
        amount: 300000,
        dueDate: DateTime(2026, 9, 20),
        payStatus: 'Pending',
        isPaid: false,
        autoPayEnabled: false,
        timeNotification: '3',
        isRecurrence: true,
        timeRecurrence: 'Month',
        recurrence: 'monthly',
        icon: 'receipt',
        colour: '#4CAF50',
        note: '',
        isDeleted: false,
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 9, 1),
      );

  ReminderScheduler boDat({required bool Function() nhacTruocHan, required bool Function() ghiChep}) =>
      ReminderScheduler(
        osNotifier: os,
        loadBills: (_, __) async => [hoaDon()],
        loadLastTransactionAt: (_) async => null,
        prefsStore: prefs,
        nhacTruocHanDuocPhep: nhacTruocHan,
        nhacGhiChepDuocPhep: ghiChep,
        clock: () => now,
      );

  bool co(String tienTo) => os.lich.values.any((l) => (l.payload ?? '').startsWith(tienTo));

  test('tiền đề: có quyền → có lịch nhắc trước hạn (billDue:) và lịch ghi chép (ghiChep:)', () async {
    await boDat(nhacTruocHan: () => true, ghiChep: () => true).resync(id);
    expect(co('billDue:'), isTrue);
    expect(co('ghiChep:'), isTrue);
  });

  test('⭐ không quyền bill_reminder_notifications → không lịch billDue:; ghi chép vẫn có', () async {
    await boDat(nhacTruocHan: () => false, ghiChep: () => true).resync(id);
    expect(co('billDue:'), isFalse);
    expect(co('ghiChep:'), isTrue);
  });

  test('⭐ không quyền daily_recording_reminder → không lịch ghiChep:; hoá đơn vẫn có', () async {
    await boDat(nhacTruocHan: () => true, ghiChep: () => false).resync(id);
    expect(co('ghiChep:'), isFalse);
    expect(co('billDue:'), isTrue);
  });

  test('⭐ quyền tắt SAU khi đã đặt → resync THƯỜNG kế huỷ lịch (bẫy khongHuy); bật lại → lịch về', () async {
    var quyen = true;
    final s = boDat(nhacTruocHan: () => quyen, ghiChep: () => quyen);
    await s.resync(id);
    expect(co('billDue:'), isTrue);
    quyen = false;
    await s.resync(id);
    expect(co('billDue:'), isFalse,
        reason: '`khongHuy.add` đứng TRƯỚC phép lọc theo mốc và vòng huỷ bỏ qua id trong khongHuy — chặn quyền trong '
            'vòng hoá đơn sau dòng ấy là lịch đã đặt nổ mãi. Hệ quả cố ý của chặn ở nhánh: lịch đã HOÃN của hoá đơn '
            'cũng bị huỷ khi mất quyền — đúng (không quyền thì không nhắc), đừng đọc là lỗi.');
    expect(co('ghiChep:'), isFalse);
    quyen = true;
    await s.resync(id);
    expect(co('billDue:'), isTrue);
    expect(co('ghiChep:'), isTrue);
  });
}
