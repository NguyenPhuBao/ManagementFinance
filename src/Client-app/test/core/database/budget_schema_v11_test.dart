/// Migration v10 → v11 cho bảng `budgets`.
///
/// Bảng này lệch với backend theo **cả hai chiều**:
/// - THIẾU `threshold_warning_percent` — backend có cột đó từ đợt DB v2, nên
///   ngưỡng cảnh báo theo phần trăm người dùng đặt trên một máy không bao giờ
///   sang được máy khác. Thiếu một trường trong payload không gây lỗi, nó chỉ
///   lặng lẽ không được ghi.
/// - THỪA `remaining`, `percent_spent`, `period` — ba cột backend KHÔNG có.
///
/// Điều đáng canh nhất ở đây là **dữ liệu người dùng phải sống sót**: migration
/// dùng `TableMigration`, tức Drift dựng bảng mới rồi chép sang. Chép sai một
/// cột là mất hạn mức hoặc mất ngày bắt đầu của mọi ngân sách đang có, và
/// không có exception nào báo ra.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';

/// Bảng ở hình dạng **v10**: có đủ ba cột thừa, chưa có cột phần trăm.
void _createV10Schema(dynamic database) {
  database.execute('''
    CREATE TABLE budgets (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      spent REAL NOT NULL DEFAULT 0,
      remaining REAL,
      percent_spent INTEGER NOT NULL DEFAULT 0,
      over_spending TEXT NOT NULL DEFAULT 'Over',
      over_amount REAL,
      threshold_warning_amount REAL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0,
      time_recurrence TEXT NOT NULL DEFAULT 'Month',
      period TEXT NOT NULL DEFAULT 'monthly',
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

/// Các bảng còn lại ở hình dạng v10 — migration không đụng tới chúng, nhưng
/// thiếu bảng thì `beforeOpen` và các bước trước sẽ chết vì "no such table".
void _createOtherV10Tables(dynamic database) {
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
  // 2026-06-01 12:00 UTC. Drift ở dự án này lưu DateTime dạng Unix **giây**,
  // không phải mili giây — fixture phải dùng đúng đơn vị đó.
  const startSec = 1780315200;
  const updatedSec = 1780401600;

  group('migration v10 lên v11', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          _createV10Schema(database);
          _createOtherV10Tables(database);
          database.execute('''
            INSERT INTO budgets (
              id, idaccount, category_id, amount, spent, remaining,
              percent_spent, over_spending, threshold_warning_amount,
              start_date, recurrence, time_recurrence, period, note,
              is_deleted, sync_status, updated_at
            ) VALUES (
              'b-cu', 7, 'cat-an-uong', 5000000, 2000000, 3000000,
              40, 'Stop', 400000,
              $startSec, 1, 'Week', 'weekly', 'ngan sach cu',
              0, 'synced', $updatedSec
            )
          ''');
          database.execute('PRAGMA user_version = 10');
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
      expect(row.startDate.millisecondsSinceEpoch, startSec * 1000);
      expect(row.recurrence, isTrue);
      expect(row.timeRecurrence, 'Week');
      expect(row.note, 'ngan sach cu');
      expect(row.syncStatus, 'synced',
          reason: 'Migration này không sửa dữ liệu, nên không được đánh dấu '
              'lại là cần đẩy — làm vậy sẽ dựng cả bảng vào hàng đợi đẩy.');
      expect(row.updatedAt.millisecondsSinceEpoch, updatedSec * 1000,
          reason: 'updatedAt nhảy lên sẽ khiến LWW cho máy này thắng oan.');
    });

    test('cột phần trăm mới có mặt và mặc định null', () async {
      final row = await db.budgetDao.getById('b-cu');

      expect(row!.thresholdWarningPercent, isNull,
          reason: 'Hàng cũ chưa từng có giá trị này. Điền một số mặc định sẽ '
              'bật cảnh báo cho ngân sách mà người dùng chưa hề đặt ngưỡng.');
    });

    test('ghi được giá trị vào cột mới sau migration', () async {
      await db.budgetDao.updateBudget(
        'b-cu',
        const BudgetsCompanion(thresholdWarningPercent: Value(80)),
      );

      expect((await db.budgetDao.getById('b-cu'))!.thresholdWarningPercent, 80);
    });

    test('ba cột thừa đã biến mất khỏi bảng', () async {
      final columns = await db
          .customSelect('PRAGMA table_info(budgets)')
          .map((row) => row.read<String>('name'))
          .get();

      expect(columns, isNot(contains('remaining')));
      expect(columns, isNot(contains('percent_spent')));
      expect(columns, isNot(contains('period')),
          reason: '`period` đã bị `time_recurrence` thay thế từ DB v2. Giữ cả '
              'hai chỉ khiến người viết mã sau phải đoán cột nào là thật.');
      expect(columns, contains('threshold_warning_percent'));
      expect(columns, contains('time_recurrence'));
    });
  });

  group('BudgetEntity dùng ngưỡng phần trăm', () {
    BudgetEntity budget({
      double amount = 1000000,
      double spent = 0,
      double? percent,
      double? byAmount,
    }) {
      return BudgetEntity(
        id: 'b',
        idaccount: 7,
        amount: amount,
        spent: spent,
        thresholdWarningPercent: percent,
        thresholdWarningAmount: byAmount,
        startDate: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
    }

    test('ngưỡng 80% bật cảnh báo sớm hơn mốc mặc định 90%', () {
      expect(budget(spent: 850000, percent: 80).isNearLimit, isTrue);
      expect(budget(spent: 850000).isNearLimit, isFalse,
          reason: 'Không đặt ngưỡng thì vẫn là mốc 90% như trước v11.');
    });

    test('cột lưu 0–100, phép so sánh chạy trên tỉ lệ', () {
      expect(budget(spent: 790000, percent: 80).isNearLimit, isFalse);
      expect(budget(spent: 800000, percent: 80).isNearLimit, isTrue,
          reason: 'Quên chia 100 thì ngưỡng 80 sẽ thành 8000% và cảnh báo '
              'không bao giờ bật — sai hoàn toàn im lặng.');
    });

    test('ngưỡng theo số tiền được ưu tiên hơn ngưỡng phần trăm', () {
      // Đã tiêu 85% → chạm ngưỡng phần trăm 80. Nhưng còn lại 150k vẫn trên
      // ngưỡng tiền 100k, nên KHÔNG cảnh báo.
      final b = budget(spent: 850000, percent: 80, byAmount: 100000);
      expect(b.isNearLimit, isFalse,
          reason: 'Người đặt "báo khi còn dưới 100k" muốn đúng con số đó.');
    });

    test('giá trị vô nghĩa bị bỏ qua như thể chưa đặt', () {
      for (final bad in [0.0, -5.0, 150.0]) {
        expect(budget(spent: 850000, percent: bad).warningRatio, isNull,
            reason: 'Ngưỡng $bad không dùng được.');
        expect(budget(spent: 850000, percent: bad).isNearLimit, isFalse,
            reason: 'Rơi về mốc 90%, chứ không biến cảnh báo thành luôn-bật '
                'hoặc luôn-tắt vì một hàng hỏng do đồng bộ.');
      }
    });

    test('đã vượt hẳn thì không còn là "gần chạm ngưỡng"', () {
      expect(budget(spent: 1200000, percent: 80).isOverBudget, isTrue);
      expect(budget(spent: 1200000, percent: 80).isNearLimit, isFalse);
    });
  });
}
