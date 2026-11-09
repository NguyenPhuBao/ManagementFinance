/// Schema v33: cột `transactions.fund_pair_id` (TEXT NULL) — mã cặp khoản góp / rút của gia đình (`docs/Family/02A` mục 5).
/// KHÁC v24–v31: cột này ĐI QUA đồng bộ (khoá payload `idfund_pair`). NULL = khoản thường.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bang_toi_thieu_v32.dart';

void main() {
  test('schema là v33', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 33);
  });

  test('transactions có cột fund_pair_id TEXT cho phép NULL', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cot = (await db.customSelect("PRAGMA table_info('transactions')").get())
        .where((r) => r.read<String>('name') == 'fund_pair_id')
        .toList();
    expect(cot, hasLength(1), reason: 'thiếu cột thì cặp góp / rút mất liên kết');
    expect(cot.single.read<String>('type'), 'TEXT');
    expect(cot.single.read<int>('notnull'), 0);
  });

  test('migration v32 → v33 thêm cột, giữ hàng cũ, fund_pair_id của hàng cũ là NULL', () async {
    final cu = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) {
      dungBangThieuChoV32(d);
      d.execute("INSERT INTO transactions (id) VALUES ('t_cu')");
      d.execute('PRAGMA user_version = 32');
    }));
    addTearDown(cu.close);
    final hang = await cu.customSelect('SELECT id, fund_pair_id FROM transactions').get();
    expect(hang, hasLength(1), reason: 'bước lên v33 không được làm mất hàng cũ');
    expect(hang.single.read<String>('id'), 't_cu');
    expect(hang.single.readNullable<String>('fund_pair_id'), isNull, reason: 'hàng cũ không phải góp / rút');
  });
}
