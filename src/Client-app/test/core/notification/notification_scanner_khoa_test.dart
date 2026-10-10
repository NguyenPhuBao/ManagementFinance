/// Vòng quét đi qua **khoá thuê** của hai bộ tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục
/// 3.4). Engine nền của WorkManager và engine của app có thể quét cùng lúc trong cùng tiến trình — `_dangQuet` chỉ
/// chặn trong MỘT isolate, nên chốt phải nằm ở CSDL.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay_runner.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit_runner.dart';

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
    Future<List<BillAutoPayEvent>> Function(int, DateTime)? runAutoPays,
    Future<List<GoalAutoDepositEvent>> Function(int, DateTime)? runAutoDeposits,
    Future<bool> Function()? layKhoa,
    Future<void> Function()? nhaKhoa,
  }) {
    var soId = 0;
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (id, at) async => const [],
      loadBills: (id, at) async => const [],
      runAutoPays: runAutoPays,
      runAutoDeposits: runAutoDeposits,
      layKhoa: layKhoa,
      nhaKhoa: nhaKhoa,
      syncStatus: syncStatus.stream,
      clock: () => now,
      idGenerator: () => 'id-${soId++}',
    );
  }

  test('không lấy được khoá → KHÔNG chạy hai bộ tự chuyển tiền, vẫn quét thông báo', () async {
    var tra = 0, trich = 0;
    final s = dung(
      runAutoPays: (id, at) async {
        tra++;
        return const [];
      },
      runAutoDeposits: (id, at) async {
        trich++;
        return const [];
      },
      layKhoa: () async => false,
      nhaKhoa: () async {},
    );
    expect(await s.scan(1, now: now), 0);
    expect(tra, 0, reason: 'lượt khác (engine nền / app) đang giữ khoá — chạy là trừ tiền hai lần');
    expect(trich, 0);
  });

  test('lấy được khoá → chạy cả hai, rồi NHẢ khoá đúng một lần', () async {
    var tra = 0, trich = 0, nha = 0;
    final s = dung(
      runAutoPays: (id, at) async {
        tra++;
        return const [];
      },
      runAutoDeposits: (id, at) async {
        trich++;
        return const [];
      },
      layKhoa: () async => true,
      nhaKhoa: () async => nha++,
    );
    await s.scan(1, now: now);
    expect((tra, trich, nha), (1, 1, 1));
  });

  test('bộ chạy ném lỗi vẫn nhả khoá', () async {
    var nha = 0;
    final s = dung(
      runAutoPays: (id, at) async => throw StateError('hỏng'),
      layKhoa: () async => true,
      nhaKhoa: () async => nha++,
    );
    await s.scan(1, now: now);
    expect(nha, 1, reason: 'khoá giữ lại thì 2 phút sau mới có lượt khác chạy được');
  });

  test('lấy khoá ném lỗi → coi như không lấy được, không chạy', () async {
    var tra = 0;
    final s = dung(
      runAutoPays: (id, at) async {
        tra++;
        return const [];
      },
      layKhoa: () async => throw StateError('SQLITE_BUSY'),
      nhaKhoa: () async {},
    );
    expect(await s.scan(1, now: now), 0);
    expect(tra, 0);
  });

  test('không truyền khoá (test cũ, web) → chạy như trước', () async {
    var tra = 0;
    final s = dung(runAutoPays: (id, at) async {
      tra++;
      return const [];
    });
    await s.scan(1, now: now);
    expect(tra, 1);
  });
}
