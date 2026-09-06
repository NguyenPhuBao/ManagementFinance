/// Migration v11 → v12 cho bảng `budgets`: `time_recurrence` thành nullable.
///
/// Vì sao cần: lựa chọn "Ngày cụ thể" nghĩa là ngân sách **không theo chu kỳ**
/// nào cả — người dùng tự chọn ngày kết thúc. Backend biểu diễn trạng thái đó
/// bằng `Time_recurrence = NULL` và ràng buộc `chk_budget_time_recurrence` đã
/// cho phép (`IS NULL OR IN (...)`), nhưng cột phía client trước v12 là
/// `NOT NULL DEFAULT 'Month'` nên không lưu nổi.
///
/// Điều đáng canh nhất vẫn là **dữ liệu người dùng phải sống sót**: migration
/// dùng `TableMigration`, tức Drift dựng bảng mới rồi chép sang. Chép hụt một
/// cột là mất hạn mức hoặc mất ngày bắt đầu của mọi ngân sách đang có, và
/// không có exception nào báo ra.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

/// Bảng ở hình dạng **v11**: `time_recurrence` còn NOT NULL.
void _createV11Schema(dynamic database) {
  database.execute('''
    CREATE TABLE budgets (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      spent REAL NOT NULL DEFAULT 0,
      over_spending TEXT NOT NULL DEFAULT 'Over',
      over_amount REAL,
      threshold_warning_amount REAL,
      threshold_warning_percent REAL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0,
      time_recurrence TEXT NOT NULL DEFAULT 'Month',
      note TEXT NOT NULL DEFAULT '',
      next_time_recurrence INTEGER,
      deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0,
      sync_error TEXT,
      sync_blocked_until INTEGER,
      updated_at INTEGER NOT NULL
    )
  ''');
}

/// Các bảng còn lại ở hình dạng v11 — migration không đụng tới chúng, nhưng
/// thiếu bảng thì `beforeOpen` và các bước trước sẽ chết vì "no such table".
void _createOtherV11Tables(dynamic database) {
  database.execute('''
    CREATE TABLE wallets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'cash',
      balance REAL NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT 'VND',
      icon TEXT NOT NULL DEFAULT 'wallet', colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0, include_in_total INTEGER NOT NULL DEFAULT 1,
      bank_casso_id TEXT, status TEXT NOT NULL DEFAULT 'active', deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0, sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE transactions (
      id TEXT NOT NULL PRIMARY KEY, wallet_id TEXT NOT NULL,
      idaccount INTEGER NOT NULL, category_id TEXT, amount REAL NOT NULL,
      type TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', date INTEGER NOT NULL,
      images TEXT NOT NULL DEFAULT '[]', status TEXT NOT NULL DEFAULT 'Confirmed',
      provider TEXT NOT NULL DEFAULT 'Manual', wallet_transfer TEXT,
      bank_tran_id TEXT, deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE categories (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, classify TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'category', colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
      parent_id TEXT, is_group INTEGER NOT NULL DEFAULT 0,
      is_local_only INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE category_keywords (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, idaccount INTEGER NOT NULL,
      category_id TEXT NOT NULL, keyword TEXT NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE category_group_memberships (
      idaccount INTEGER NOT NULL, group_id TEXT NOT NULL, child_id TEXT NOT NULL,
      PRIMARY KEY (idaccount, group_id, child_id)
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
      recurrence TEXT NOT NULL DEFAULT 'monthly', icon TEXT NOT NULL DEFAULT 'receipt',
      colour TEXT NOT NULL DEFAULT '#4CAF50', note TEXT NOT NULL DEFAULT '',
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE goals (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, name TEXT NOT NULL,
      target_amount REAL NOT NULL, current_amount REAL NOT NULL DEFAULT 0,
      start_date INTEGER, target_date INTEGER NOT NULL, wallet_id TEXT,
      cycle_take_money TEXT, time_cycle_take_money INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0, time_recurrence TEXT,
      icon TEXT NOT NULL DEFAULT 'flag', colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '', is_completed INTEGER NOT NULL DEFAULT 0,
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

void main() {
  // 2026-06-01 12:00 UTC. Drift ở dự án này lưu DateTime dạng Unix **giây**.
  const startSec = 1780315200;
  const updatedSec = 1780401600;

  group('migration v11 lên v12', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          _createV11Schema(database);
          _createOtherV11Tables(database);
          database.execute('''
            INSERT INTO budgets (
              id, idaccount, category_id, amount, spent, over_spending,
              threshold_warning_amount, threshold_warning_percent,
              start_date, end_date, recurrence, time_recurrence, note,
              is_deleted, sync_status, updated_at
            ) VALUES (
              'b-cu', 7, 'cat-an-uong', 5000000, 2000000, 'Stop',
              400000, 80,
              $startSec, NULL, 1, 'Week', 'ngan sach cu',
              0, 'synced', $updatedSec
            )
          ''');
          database.execute('PRAGMA user_version = 11');
        },
      ));
    });

    tearDown(() => db.close());

    test('dữ liệu của ngân sách cũ sống sót nguyên vẹn', () async {
      final row = await db.budgetDao.getById('b-cu');

      expect(row, isNotNull,
          reason: 'TableMigration dựng bảng mới rồi chép sang. Chép hụt là mất '
              'sạch ngân sách của người dùng mà không có lỗi nào báo ra.');
      expect(row!.idaccount, 7);
      expect(row.categoryId, 'cat-an-uong');
      expect(row.amount, 5000000);
      expect(row.spent, 2000000);
      expect(row.overSpending, 'Stop');
      expect(row.thresholdWarningAmount, 400000);
      expect(row.thresholdWarningPercent, 80);
      expect(row.startDate.millisecondsSinceEpoch, startSec * 1000);
      expect(row.recurrence, isTrue);
      expect(row.note, 'ngan sach cu');
      expect(row.syncStatus, 'synced',
          reason: 'Migration này không sửa dữ liệu, nên không được đánh dấu '
              'lại là cần đẩy — làm vậy sẽ dựng cả bảng vào hàng đợi đẩy.');
      expect(row.updatedAt.millisecondsSinceEpoch, updatedSec * 1000,
          reason: 'updatedAt nhảy lên sẽ khiến LWW cho máy này thắng oan.');
    });

    test('chu kỳ cũ KHÔNG bị migration làm rỗng', () async {
      final row = await db.budgetDao.getById('b-cu');

      expect(
        row!.timeRecurrence,
        'Week',
        reason: 'Cột nay cho phép null, nhưng hàng cũ có giá trị thì phải giữ '
            'nguyên. Để nó thành null là biến mọi ngân sách định kỳ cũ thành '
            '"Ngày cụ thể" — chu kỳ biến mất mà không ai được báo.',
      );
    });

    test('cột chấp nhận NULL sau migration', () async {
      await db.budgetDao.insert(BudgetsCompanion.insert(
        id: 'b-ngay-cu-the',
        idaccount: 7,
        amount: 1000000,
        startDate: DateTime.fromMillisecondsSinceEpoch(startSec * 1000),
        endDate: Value(
            DateTime.fromMillisecondsSinceEpoch((startSec + 86400 * 45) * 1000)),
        timeRecurrence: const Value(null),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedSec * 1000),
      ));

      final row = await db.budgetDao.getById('b-ngay-cu-the');

      expect(
        row!.timeRecurrence,
        isNull,
        reason: 'Đây là cả lý do tồn tại của migration này: "Ngày cụ thể" được '
            'biểu diễn bằng NULL, đúng như backend đã cho phép ở ràng buộc '
            'chk_budget_time_recurrence.',
      );
      expect(row.endDate, isNotNull,
          reason: 'Ngân sách kiểu này bắt buộc phải có ngày kết thúc — không '
              'có chu kỳ thì không suy ra được hạn dùng.');
    });
  });
}
