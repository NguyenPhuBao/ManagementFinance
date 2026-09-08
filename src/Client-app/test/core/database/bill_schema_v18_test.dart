/// Migration v17 → v18: cột cục bộ `bills.anchor_day`.
///
/// Vì sao cần canh: cùng lượt nâng cấp này bỏ **quy tắc đoán ngày cuối tháng**
/// mà hoá đơn cũ đã được tính theo. Nếu ngày gốc suy sai, hạn trả của những hoá
/// đơn ấy đổi ngay ở kỳ kế tiếp — người dùng không bấm gì cả mà ngày trả tiền
/// nhà tự dịch. Đó đúng là lớp lỗi âm thầm mà `canhBaoHanCu` sinh ra để chặn,
/// và migration thì chạy êm dù suy sai.
///
/// Chốt chặn: ngày gốc suy từ **ngày đến hạn đang lưu**, không phải ngày bắt
/// đầu. Với hoá đơn 31/01 → 28/02 → hạn 31/03, lấy ngày bắt đầu (28) sẽ hạ hoá
/// đơn xuống ngày 28 vĩnh viễn.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void _createV17Bills(dynamic database) {
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
      auto_pay_enabled INTEGER NOT NULL DEFAULT 0,
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

/// Mốc mili-giây của một ngày địa phương — cùng đơn vị Drift ghi xuống.
int _ms(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

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
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        _createV17Bills(database);
        _createV17Goals(database);

        // Kỳ giữa của một chuỗi "ngày 31": bắt đầu 28/02, hạn 31/03. Đây là
        // hàng mà suy sai sẽ làm hỏng.
        database.execute('''
          INSERT INTO bills (
            id, idaccount, wallet_id, category_id, name, amount,
            start_date, due_date, is_recurrence, time_recurrence,
            sync_status, updated_at
          ) VALUES (
            'chuoi-31', 7, 'vi-1', 'cat-nha', 'Tien nha', 5000000,
            ${_ms(2026, 2, 28)}, ${_ms(2026, 3, 31)}, 1, 'Month',
            'synced', ${_ms(2026, 3, 1)}
          )
        ''');

        // Hoá đơn "ngày 28" bình thường.
        database.execute('''
          INSERT INTO bills (
            id, idaccount, wallet_id, category_id, name, amount,
            start_date, due_date, is_recurrence, time_recurrence,
            sync_status, updated_at
          ) VALUES (
            'ngay-28', 7, 'vi-1', 'cat-nha', 'Internet', 300000,
            ${_ms(2026, 1, 28)}, ${_ms(2026, 2, 28)}, 1, 'Month',
            'synced', ${_ms(2026, 2, 1)}
          )
        ''');

        // Ngày một chữ số — strftime('%d') trả '05', phải ép về số.
        database.execute('''
          INSERT INTO bills (
            id, idaccount, wallet_id, category_id, name, amount,
            start_date, due_date, is_recurrence, time_recurrence,
            sync_status, updated_at
          ) VALUES (
            'ngay-5', 7, 'vi-1', 'cat-nha', 'Nuoc', 100000,
            ${_ms(2026, 1, 5)}, ${_ms(2026, 2, 5)}, 1, 'Month',
            'synced', ${_ms(2026, 2, 1)}
          )
        ''');

        database.execute('PRAGMA user_version = 17');
      },
    ));
  });

  tearDown(() => db.close());

  test('ngày gốc suy từ NGÀY ĐẾN HẠN, không phải ngày bắt đầu', () async {
    final bill = (await db.billDao.getById('chuoi-31'))!;

    expect(
      bill.anchorDay,
      31,
      reason: 'Hoá đơn này bắt đầu 28/02 nhưng đến hạn 31/03 — nó thuộc chuỗi '
          '"ngày 31". Suy từ ngày bắt đầu ra 28 là hạ nó xuống ngày 28 vĩnh '
          'viễn ở kỳ sau, mà người dùng không bấm gì cả.',
    );
  });

  test('hoá đơn ngày 28 giữ đúng 28', () async {
    expect((await db.billDao.getById('ngay-28'))!.anchorDay, 28);
  });

  test('ngày một chữ số không bị đọc thành chuỗi', () async {
    expect(
      (await db.billDao.getById('ngay-5'))!.anchorDay,
      5,
      reason: "strftime('%d') trả '05' có số 0 đứng đầu. So sánh chuỗi với số "
          'ở SQLite KHÔNG báo lỗi — nó chỉ lặng lẽ trả sai.',
    );
  });

  test('migration không đẩy hoá đơn cũ vào hàng đợi đồng bộ', () async {
    for (final id in ['chuoi-31', 'ngay-28', 'ngay-5']) {
      expect(
        (await db.billDao.getById(id))!.syncStatus,
        'synced',
        reason: 'Cột mới là CỤC BỘ, không có trong payload. Đánh dấu pending '
            'cho nó là đẩy rỗng lên server ở lần mở app đầu tiên — và với '
            'hoá đơn thì mỗi lần đẩy hỏng là một vòng lặp thử lại.',
      );
    }
  });

  test('cột mới ghi và đọc lại được', () async {
    await db.billDao.updateFields(const BillsCompanion(
      id: Value('ngay-28'),
      anchorDay: Value(15),
    ));

    expect((await db.billDao.getById('ngay-28'))!.anchorDay, 15);
  });
}
