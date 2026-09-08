/// Migration v16 → v17: cột cục bộ `bills.auto_pay_enabled`.
///
/// Vì sao cần canh: migration thêm cột chạy êm dù có đặt mặc định sai, và
/// mặc định sai ở đây nghĩa là **app tự chuyển tiền** của mọi hoá đơn cũ dựa
/// trên một lựa chọn người dùng chưa từng đưa ra. Test mở một CSDL đang ở v16
/// có sẵn hoá đơn rồi khẳng định: hàng cũ mang `false`, và không hàng nào bị
/// đẩy vào hàng đợi đồng bộ vì một cột không có trong payload.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void _createV16Bills(dynamic database) {
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
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

/// Bảng `goals` của một CSDL v17 — dựng ở đây chỉ để chuỗi migration chạy
/// tới cuối.
///
/// Tệp này canh phần **hoá đơn**, nhưng migration v19 thêm cột
/// `goals.priority`, và `ALTER TABLE` trên một bảng không tồn tại thì cả
/// chuỗi dừng ngay ở đó. Một CSDL v17 thật luôn có bảng này — thiếu nó ở
/// đây là thiếu ở phía **bản dựng thử**, không phải ở phía mã nguồn.
void _createV17Goals(dynamic database) {
  database.execute('''
    CREATE TABLE goals (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0, start_date INTEGER,
      target_date INTEGER NOT NULL, wallet_id TEXT,
      cycle_take_money TEXT, time_cycle_take_money INTEGER,
      auto_deposit_amount REAL, auto_deposit_wallet_id TEXT,
      auto_deposit_last_run INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0, time_recurrence TEXT,
      icon TEXT NOT NULL DEFAULT 'flag', colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '',
      is_completed INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

void main() {
  const startSec = 1780315200; // 2026-06-01 12:00 UTC
  const dueSec = 1789000000;
  const updatedSec = 1780401600;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        _createV16Bills(database);
        _createV17Goals(database);
        database.execute('''
          INSERT INTO bills (
            id, idaccount, wallet_id, category_id, name, amount,
            start_date, due_date, is_recurrence, time_recurrence,
            sync_status, updated_at
          ) VALUES (
            'hd-cu', 7, 'vi-1', 'cat-hoa-don', 'Tien dien', 300000,
            $startSec, $dueSec, 1, 'Month', 'synced', $updatedSec
          )
        ''');
        database.execute('PRAGMA user_version = 16');
      },
    ));
  });

  tearDown(() => db.close());

  test('hoá đơn cũ KHÔNG được bật tự động thanh toán', () async {
    final bill = (await db.billDao.getById('hd-cu'))!;

    expect(bill.autoPayEnabled, isFalse,
        reason: 'Chưa ai trong số hoá đơn cũ ĐỒNG Ý cho app tự chuyển tiền. '
            'Bật cho chúng là trừ ví người dùng dựa trên một lựa chọn họ chưa '
            'từng đưa ra — cùng lập luận với migration v15 của mục tiêu.');
  });

  test('migration không đẩy hoá đơn cũ vào hàng đợi đồng bộ', () async {
    final bill = (await db.billDao.getById('hd-cu'))!;

    expect(bill.syncStatus, 'synced',
        reason: 'Cột mới là CỤC BỘ, không có trong payload. Đánh dấu pending '
            'cho nó là đẩy rỗng lên server ở lần mở app đầu tiên.');
  });

  test('cột mới ghi và đọc lại được', () async {
    await db.billDao.updateFields(const BillsCompanion(
      id: Value('hd-cu'),
      autoPayEnabled: Value(true),
    ));

    expect((await db.billDao.getById('hd-cu'))!.autoPayEnabled, isTrue);
  });
}
