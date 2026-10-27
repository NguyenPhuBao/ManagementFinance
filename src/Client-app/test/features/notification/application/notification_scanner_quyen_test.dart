/// B1 (spec 2026-10-27 mục 5) — vòng quét bỏ `billDueSoon` khi không quyền `bill_reminder_notifications` (quá hạn VẪN
/// báo) và bỏ `budgetNearLimit` / `budgetOverspent` khi không quyền `budget_overspend_alert`.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/notification/application/notification_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

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

  BillEntity hd(String id, DateTime han) => BillEntity(
        id: id,
        idaccount: 1,
        walletId: 'w1',
        categoryId: 'c1',
        name: 'Hoá đơn $id',
        amount: 100000,
        dueDate: han,
        payStatus: 'Pending',
        isPaid: false,
        autoPayEnabled: false,
        timeNotification: '3',
        isRecurrence: false,
        timeRecurrence: 'Month',
        recurrence: 'monthly',
        icon: 'receipt',
        colour: '#4CAF50',
        note: '',
        isDeleted: false,
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 10, 1),
      );

  final vuot = BudgetView(
    budget: BudgetEntity(
      id: 'ns1',
      idaccount: 1,
      categoryId: 'c1',
      amount: 1000000,
      spent: 1200000,
      startDate: DateTime(2026, 10, 1),
      recurrence: true,
      updatedAt: DateTime(2026, 10, 1),
    ),
    categoryName: 'Ăn uống',
  );

  NotificationScanner dung({bool Function()? nhacTruocHan, bool Function()? canhBaoNganSach}) {
    var soId = 0;
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (_, __) async => [vuot],
      loadBills: (_, __) async => [hd('sap', DateTime(2026, 10, 12)), hd('qua', DateTime(2026, 10, 8))],
      nhacTruocHanDuocPhep: nhacTruocHan,
      canhBaoNganSachDuocPhep: canhBaoNganSach,
      syncStatus: syncStatus.stream,
      clock: () => now,
      idGenerator: () => 'id-${soId++}',
    );
  }

  Future<Set<String>> loai() async => {for (final h in await db.notificationDao.getAll(1)) h.kind};

  test('tiền đề: có quyền (không truyền vị từ) → sắp hạn, quá hạn, vượt ngân sách đều sinh', () async {
    await dung().scan(1, now: now);
    expect(await loai(), containsAll(['billDueSoon', 'billOverdue', 'budgetOverspent']));
  });

  test('⭐ không quyền bill_reminder_notifications → bỏ billDueSoon; billOverdue VẪN báo', () async {
    await dung(nhacTruocHan: () => false).scan(1, now: now);
    final k = await loai();
    expect(k, isNot(contains('billDueSoon')));
    expect(k, contains('billOverdue'), reason: 'spec mục 3: quá hạn vẫn báo — nợ quá hạn không phải "nhắc trước"');
  });

  test('⭐ không quyền budget_overspend_alert → bỏ budgetNearLimit / budgetOverspent; hoá đơn không đổi', () async {
    await dung(canhBaoNganSach: () => false).scan(1, now: now);
    final k = await loai();
    expect(k, isNot(contains('budgetOverspent')));
    expect(k, isNot(contains('budgetNearLimit')));
    expect(k, containsAll(['billDueSoon', 'billOverdue']));
  });
}
