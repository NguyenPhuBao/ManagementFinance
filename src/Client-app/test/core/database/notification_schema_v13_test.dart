/// Migration v12 → v13: thêm bảng thông báo cục bộ `app_notifications`.
///
/// Vì sao cần canh: bảng mới được tạo bằng `createTable` chứ không phải
/// `TableMigration`, nên bản thân nó không có dữ liệu để mất. Thứ dễ hỏng là
/// **những bảng khác** — một nhánh `onUpgrade` viết sai có thể dựng lại bảng
/// hoặc đánh dấu lại toàn bộ bản ghi là cần đẩy, và cả hai đều không ném
/// exception nào. Test này mở một CSDL đang ở v12 có sẵn dữ liệu thật rồi
/// khẳng định: bảng mới dùng được, dữ liệu cũ nguyên vẹn, và không bản ghi nào
/// bị đẩy vào hàng đợi đồng bộ.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

/// Bảng ở hình dạng **v12** — `budgets.time_recurrence` đã nullable, và chưa
/// có `app_notifications`.
void _createV12Schema(dynamic database) {
  database.execute('''
    CREATE TABLE budgets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      category_id TEXT, amount REAL NOT NULL, spent REAL NOT NULL DEFAULT 0,
      over_spending TEXT NOT NULL DEFAULT 'Over', over_amount REAL,
      threshold_warning_amount REAL, threshold_warning_percent REAL,
      start_date INTEGER NOT NULL, end_date INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0, time_recurrence TEXT,
      note TEXT NOT NULL DEFAULT '', next_time_recurrence INTEGER,
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE bills (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, wallet_id TEXT,
      category_id TEXT, name TEXT NOT NULL, amount REAL NOT NULL,
      start_date INTEGER, due_date INTEGER NOT NULL,
      pay_status TEXT NOT NULL DEFAULT 'Pending', is_paid INTEGER NOT NULL DEFAULT 0,
      time_notification TEXT, is_recurrence INTEGER NOT NULL DEFAULT 0,
      time_recurrence TEXT NOT NULL DEFAULT 'Month',
      recurrence TEXT NOT NULL DEFAULT 'monthly',
      icon TEXT NOT NULL DEFAULT 'receipt', colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '', deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

void main() {
  // Drift ở dự án này lưu DateTime dạng Unix **giây**.
  const startSec = 1780315200; // 2026-06-01 12:00 UTC
  const dueSec = 1789000000;
  const updatedSec = 1780401600;

  group('migration v12 lên v13', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          _createV12Schema(database);
          database.execute('''
            INSERT INTO budgets (
              id, idaccount, category_id, amount, spent, threshold_warning_percent,
              start_date, recurrence, time_recurrence, note, sync_status, updated_at
            ) VALUES (
              'b-cu', 7, 'cat-an-uong', 5000000, 4600000, 80,
              $startSec, 1, 'Month', 'ngan sach cu', 'synced', $updatedSec
            )
          ''');
          database.execute('''
            INSERT INTO bills (
              id, idaccount, wallet_id, category_id, name, amount,
              start_date, due_date, time_notification, is_recurrence,
              time_recurrence, sync_status, updated_at
            ) VALUES (
              'hd-cu', 7, 'vi-1', 'cat-hoa-don', 'Tien dien', 300000,
              $startSec, $dueSec, '3', 1, 'Month', 'synced', $updatedSec
            )
          ''');
          database.execute('PRAGMA user_version = 12');
        },
      ));
    });

    tearDown(() => db.close());

    test('bảng thông báo mới dùng được ngay sau migration', () async {
      final chen = await db.notificationDao.insertIfAbsent(
        AppNotificationsCompanion.insert(
          id: 'n1',
          idaccount: 7,
          kind: 'budgetNearLimit',
          dedupeKey: 'budgetNear:b-cu:2026-06-01:critical',
          title: 'Sắp vượt ngân sách',
          body: 'Bạn đã chi tiêu vượt 90% ngân sách Ăn uống',
          severity: 'warning',
          createdAt: DateTime(2026, 9, 4),
        ),
      );
      expect(chen, true);
      expect((await db.notificationDao.getAll(7)).length, 1);
    });

    test('ràng buộc chống trùng được tạo cùng bảng, không bị bỏ sót', () async {
      Future<bool> chen(String id) => db.notificationDao.insertIfAbsent(
            AppNotificationsCompanion.insert(
              id: id,
              idaccount: 7,
              kind: 'budgetNearLimit',
              dedupeKey: 'cung-mot-khoa',
              title: 't',
              body: 'b',
              severity: 'warning',
              createdAt: DateTime(2026, 9, 4),
            ),
          );

      expect(await chen('n1'), true);
      expect(await chen('n2'), false,
          reason: 'createTable phải mang theo cả uniqueKeys. Thiếu ràng buộc '
              'thì migration vẫn chạy êm, chỉ có điều mỗi vòng quét đẻ thêm '
              'một bản sao — hỏng âm thầm đúng nghĩa.');
    });

    test('dữ liệu ngân sách và hoá đơn cũ sống sót nguyên vẹn', () async {
      final ns = await db.budgetDao.getById('b-cu');
      expect(ns, isNotNull);
      expect(ns!.amount, 5000000);
      expect(ns.spent, 4600000);
      expect(ns.thresholdWarningPercent, 80);
      expect(ns.note, 'ngan sach cu');

      final hd = (await db.billDao.getAll(7)).single;
      expect(hd.name, 'Tien dien');
      expect(hd.timeNotification, '3',
          reason: 'Cột này là nguyên liệu cho nhắc hoá đơn — mất nó là mất cấu '
              'hình nhắc của người dùng.');
      expect(hd.timeRecurrence, 'Month');
    });

    test('không bản ghi nào bị đẩy vào hàng đợi đồng bộ', () async {
      expect((await db.budgetDao.getPending(7)).length, 0,
          reason: 'Migration này không sửa dữ liệu. Đánh dấu lại là cần đẩy sẽ '
              'dựng cả CSDL vào hàng đợi và gửi lên backend một lượt.');
      expect((await db.billDao.getPending(7)).length, 0);
    });
  });
}
