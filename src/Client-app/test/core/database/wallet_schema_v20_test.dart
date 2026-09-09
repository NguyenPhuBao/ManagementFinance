/// Migration v19 → v20: thu loại ví về ba loại hợp lệ.
///
/// Vì sao cần canh: PostgreSQL có `chk_wallet_type` chỉ nhận
/// `Cash | Bank | Saving | Banking` (đo thẳng trên CSDL 2026-09-09). Giao diện
/// cũ lại cho chọn `ewallet` và `debt`, nên mọi ví tạo bằng hai loại ấy **vỡ
/// CHECK ở mỗi lần đẩy** và nằm lại trong hàng đợi vĩnh viễn — im lặng, không
/// log, không gì trên màn hình.
///
/// Migration này là chỗ **duy nhất** gỡ được chúng ra: đổi loại thôi chưa đủ,
/// còn phải xoá dấu vết thất bại cũ (`sync_error`, `sync_blocked_until`) thì
/// bản ghi mới quay lại hàng đợi ngay thay vì chờ hết thời gian chặn.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

int _ms(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

void _createV19Wallets(dynamic database) {
  database.execute('''
    CREATE TABLE wallets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'cash',
      balance REAL NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT 'VND',
      icon TEXT NOT NULL DEFAULT 'wallet', colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
      include_in_total INTEGER NOT NULL DEFAULT 1, bank_casso_id TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL, deleted_at INTEGER
    )
  ''');
}

Future<String> _loai(AppDatabase db, String id) async {
  final rows = await db
      .customSelect('SELECT type FROM wallets WHERE id = ?',
          variables: [Variable<String>(id)])
      .get();
  return rows.single.data['type'] as String;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        _createV19Wallets(database);

        // Ví điện tử đang KẸT: đã hỏng đẩy nhiều lần và đang bị chặn theo thời
        // gian. Đây là hàng mà migration phải cứu.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status,
            sync_retry_count, sync_error, sync_blocked_until, updated_at)
          VALUES ('vi-momo', 7, 'Momo', 'ewallet', 250000, 'pending',
            9, 'chk_wallet_type', ${_ms(2027, 1, 1)}, ${_ms(2026, 9, 1)})
        ''');

        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status, updated_at)
          VALUES ('vi-the', 7, 'The tin dung', 'debt', -1200000, 'pending',
            ${_ms(2026, 9, 1)})
        ''');

        // Ba loại hợp lệ — KHÔNG được đụng tới.
        // Ví đã đồng bộ xong nhưng còn mang dấu vết một lần hỏng CŨ. Đây là
        // hàng phân biệt được điều kiện `WHERE sync_status = 'pending'` — thiếu
        // nó thì migration quét cả bảng.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status,
            sync_retry_count, sync_error, updated_at)
          VALUES ('vi-mat', 7, 'Tien mat', 'cash', 500000, 'synced',
            3, 'loi cu', ${_ms(2026, 9, 1)})
        ''');
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status, updated_at)
          VALUES ('vi-nh', 7, 'Vietcombank', 'bank', 3000000, 'synced', ${_ms(2026, 9, 1)})
        ''');
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status, updated_at)
          VALUES ('vi-tk', 7, 'Tiet kiem', 'saving', 9000000, 'synced', ${_ms(2026, 9, 1)})
        ''');

        // Ví liên kết ngân hàng do server tạo — cũng KHÔNG được đụng.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, bank_casso_id,
            sync_status, updated_at)
          VALUES ('vi-lk', 7, 'Lien ket', 'banking', 100000, 'bank-1',
            'synced', ${_ms(2026, 9, 1)})
        ''');

        // Giá trị chưa từng có trong giao diện nào, nhưng cột là TEXT tự do.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, type, balance, sync_status, updated_at)
          VALUES ('vi-la', 7, 'La hoac', 'investment', 700000, 'pending',
            ${_ms(2026, 9, 1)})
        ''');
        // Drift đọc phiên bản CSDL từ `PRAGMA user_version`; đặt 19 để chuỗi
        // migration chạy đúng một bước sang v20. Thiếu dòng này thì Drift coi
        // đây là CSDL mới và không migration nào chạy cả.
        database.execute('PRAGMA user_version = 19');
      },
      logStatements: false,
    ));
  });

  tearDown(() async => db.close());

  test('ví điện tử và thẻ tín dụng chuyển thành ví ngân hàng', () async {
    expect(await _loai(db, 'vi-momo'), 'bank');
    expect(await _loai(db, 'vi-the'), 'bank',
        reason: 'Phải khớp `WalletType.tuKhoa` và `walletForPush` — ba chỗ cùng '
            'một phép ánh xạ thì mới không lệch nhau.');
  });

  test('loại lạ về tiền mặt', () async {
    expect(await _loai(db, 'vi-la'), 'cash',
        reason: 'Cột là TEXT tự do nên vẫn có thể chứa chuỗi chưa từng có ở '
            'giao diện. Để nguyên là bản ghi kẹt hàng đợi đẩy vĩnh viễn.');
  });

  test('bốn loại hợp lệ KHÔNG bị đụng tới', () async {
    expect(await _loai(db, 'vi-mat'), 'cash');
    expect(await _loai(db, 'vi-nh'), 'bank');
    expect(await _loai(db, 'vi-tk'), 'saving');
    expect(await _loai(db, 'vi-lk'), 'banking',
        reason: 'Ví liên kết ngân hàng phải giữ nguyên loại: đổi nó sang bank '
            'là vỡ chk_wallet_banking_link vì bank_casso_id vẫn còn.');
  });

  test('ví đang bị chặn được gỡ dấu vết thất bại để đẩy lại ngay', () async {
    final rows = await db
        .customSelect(
            'SELECT sync_status, sync_error, sync_blocked_until, sync_retry_count '
            'FROM wallets WHERE id = ?',
            variables: [const Variable<String>('vi-momo')])
        .get();
    final r = rows.single.data;

    expect(r['sync_status'], 'pending');
    expect(r['sync_error'], isNull,
        reason: 'Đổi loại thôi chưa đủ. Bản ghi vẫn mang lỗi cũ và mốc chặn ở '
            'tương lai thì nó nằm im tới tận lúc ấy — người dùng không thấy ví '
            'của mình lên server dù bản vá đã cài.');
    expect(r['sync_blocked_until'], isNull);
    expect(r['sync_retry_count'], 0);
  });

  test('ví đã đồng bộ xong KHÔNG bị migration đụng tới', () async {
    final rows = await db
        .customSelect(
            'SELECT sync_status, sync_error, sync_retry_count '
            'FROM wallets WHERE id = ?',
            variables: [const Variable<String>('vi-mat')])
        .get();
    final r = rows.single.data;

    expect(r['sync_status'], 'synced');
    // Canh THẲNG điều kiện `WHERE sync_status = 'pending'`. Bản đầu của test
    // này chỉ kiểm `sync_status`, thứ mà câu lệnh không hề chạm vào — nên bỏ
    // hẳn điều kiện WHERE vẫn xanh. Đã kiểm bằng bản sai có chủ ý.
    expect(r['sync_error'], 'loi cu',
        reason: 'Migration chỉ được dọn hàng ĐANG chờ đẩy. Quét cả bảng là đụng '
            'vào bản ghi không liên quan gì tới loại ví.');
    expect(r['sync_retry_count'], 3);
  });
}
