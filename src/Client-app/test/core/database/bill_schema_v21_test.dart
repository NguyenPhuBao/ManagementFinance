/// Migration v20 → v21: cột `bills.period_end` (ngày kết thúc kỳ tính tiền).
///
/// Vì sao cần canh: cột mới **không đổi dữ liệu** — hàng cũ giữ NULL, và NULL
/// đọc là "kết thúc kỳ trùng hạn trả" (hành vi trước v21). Migration nào chạm
/// vào hàng cũ ở đây là đổi hạn trả của người dùng mà họ không bấm gì.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

/// Drift ghi `DateTime` theo GIÂY Unix (không phải mili-giây) — chèn mili-giây
/// là đọc lại ra năm 58687.
int _s(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch ~/ 1000;

/// Bảng `bills` đúng hình dạng v20 (v17 + `anchor_day` của v18).
void _createV20Bills(dynamic database) {
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
      note TEXT NOT NULL DEFAULT '', generated_from_bill_id TEXT,
      auto_pay_enabled INTEGER NOT NULL DEFAULT 0, anchor_day INTEGER,
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        _createV20Bills(database);
        database.execute('''
          INSERT INTO bills (id, idaccount, name, amount, start_date, due_date,
            is_recurrence, anchor_day, sync_status, updated_at)
          VALUES ('hd-cu', 7, 'Tien dien', 250000, ${_s(2026, 8, 20)},
            ${_s(2026, 9, 20)}, 1, 20, 'synced', ${_s(2026, 9, 1)})
        ''');
        // Drift đọc phiên bản từ `PRAGMA user_version`; đặt 20 để chuỗi
        // migration chạy đúng một bước sang v21.
        database.execute('PRAGMA user_version = 20');
      },
      logStatements: false,
    ));
  });

  tearDown(() async => db.close());

  test('v21 thêm cột period_end và hàng cũ giữ NULL', () async {
    final cols = await db.customSelect('PRAGMA table_info(bills)').get();
    expect(cols.map((r) => r.data['name']), contains('period_end'));

    final hang = (await db.billDao.getById('hd-cu'))!;
    expect(hang.periodEnd, isNull,
        reason: 'NULL = "kết thúc kỳ trùng hạn trả" — đúng hành vi trước v21. '
            'Migration mà điền giá trị vào đây là tự quyết định thay người dùng.');
    expect(hang.dueDate, DateTime(2026, 9, 20),
        reason: 'Hạn trả cũ phải nguyên vẹn.');
    expect(hang.anchorDay, 20, reason: 'Cột v18 không được đụng tới.');
  });

  test('schemaVersion là 21', () {
    expect(db.schemaVersion, 21);
  });
}
