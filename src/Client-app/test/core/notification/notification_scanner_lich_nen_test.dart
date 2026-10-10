/// Vòng quét hẹn lượt nền kế tiếp (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.1): bộ tự trả / trích vừa
/// đổi kỳ trong lượt quét, nên lịch nền phải tính lại ở CUỐI mỗi lượt — và huỷ khi đăng xuất.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/sync/sync_models.dart';

void main() {
  final now = DateTime(2026, 10, 10, 8);
  late AppDatabase db;
  late StreamController<SyncStatus> syncStatus;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncStatus = StreamController<SyncStatus>.broadcast();
  });

  tearDown(() async {
    await syncStatus.close();
    await db.close();
  });

  NotificationScanner dung({
    Future<void> Function(int)? henLichNen,
    Future<void> Function()? huyLichNen,
  }) {
    var soId = 0;
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (id, at) async => const [],
      loadBills: (id, at) async => const [],
      henLichNen: henLichNen,
      huyLichNen: huyLichNen,
      syncStatus: syncStatus.stream,
      clock: () => now,
      idGenerator: () => 'id-${soId++}',
    );
  }

  test('cuối mỗi lượt quét gọi henLichNen với đúng tài khoản', () async {
    final goi = <int>[];
    final s = dung(henLichNen: (id) async => goi.add(id));
    await s.scan(7, now: now);
    expect(goi, [7]);
  });

  test('stop() gọi huyLichNen', () async {
    var huy = 0;
    final s = dung(huyLichNen: () async => huy++);
    await s.stop();
    expect(huy, 1, reason: 'không ai đăng nhập thì không ai uỷ quyền chuyển tiền — lượt nền phải bị huỷ');
  });

  test('henLichNen ném lỗi không làm hỏng lượt quét', () async {
    final s = dung(henLichNen: (id) async => throw StateError('kênh'));
    expect(await s.scan(7, now: now), 0);
  });
}
