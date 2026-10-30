/// Schema v32: cột `idhousehold` (INTEGER NULL) cho năm bảng đồng bộ — gia đình phần 1 (spec
/// `docs/superpowers/specs/2026-10-23-gia-dinh-nen-mong-design.md` mục 3.2, 7.2). KHÁC v24–v31: cột này ĐI QUA đồng bộ
/// (khoá payload `idhousehold`, đơn 50 D.2). NULL = dữ liệu riêng như trước.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

const _namBang = ['wallets', 'transactions', 'goals', 'budgets', 'categories'];

void main() {
  test('schema là v32', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 32);
  });

  test('năm bảng đồng bộ có cột idhousehold INTEGER cho phép NULL; hoá đơn KHÔNG có', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final bang in [..._namBang, 'bills']) {
      final cot = (await db.customSelect("PRAGMA table_info('$bang')").get())
          .where((r) => r.read<String>('name') == 'idhousehold')
          .toList();
      if (bang == 'bills') {
        expect(cot, isEmpty, reason: 'hoá đơn chung ngoài phạm vi cả bốn phần (spec mục 2)');
        continue;
      }
      expect(cot, hasLength(1), reason: bang);
      expect(cot.single.read<String>('type'), 'INTEGER', reason: bang);
      expect(cot.single.read<int>('notnull'), 0, reason: '$bang: NULL = dữ liệu riêng');
    }
  });

  test('hàng mới không nêu nhà là hàng RIÊNG', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.walletDao.insert(WalletsCompanion(
      id: const Value('w1'),
      idaccount: const Value(10),
      name: const Value('Ví'),
      updatedAt: Value(DateTime(2026, 10, 28)),
    ));
    expect((await db.walletDao.getById('w1'))!.idhousehold, isNull);
  });

  test('migration v31 → v32 thêm cột, giữ dữ liệu, hàng có sẵn là hàng riêng', () async {
    final cu = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) {
      for (final bang in _namBang) {
        d.execute('CREATE TABLE $bang (id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL)');
        d.execute("INSERT INTO $bang VALUES ('${bang}_1', 10)");
      }
      d.execute('PRAGMA user_version = 31');
    }));
    addTearDown(cu.close);
    for (final bang in _namBang) {
      final hang = await cu.customSelect('SELECT id, idhousehold FROM $bang').get();
      expect(hang, hasLength(1), reason: bang);
      expect(hang.single.read<String>('id'), '${bang}_1');
      expect(hang.single.readNullable<int>('idhousehold'), isNull, reason: '$bang: mọi hàng có sẵn là hàng riêng');
    }
  });
}
