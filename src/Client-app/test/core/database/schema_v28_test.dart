/// Schema v28 (G63): cột cục bộ `wallets.bi_tu_choi_trung_ten`. Spec 2026-10-05 mục 4.1.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema là v28', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 28);
  });

  test('bảng wallets có cột bi_tu_choi_trung_ten', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('wallets')").get();
    expect(cols.map((r) => r.read<String>('name')), contains('bi_tu_choi_trung_ten'));
  });

  test('migration v27 → v28: thêm cột, hàng cũ mang 0, hàng cũ còn nguyên', () async {
    final cu = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        // Chỉ bảng wallets của v27; chuỗi migration từ 27 chỉ chạy đúng bước v28.
        database.execute('''
          CREATE TABLE wallets (
            id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'cash', balance REAL NOT NULL DEFAULT 0.0,
            currency TEXT NOT NULL DEFAULT 'VND', icon TEXT NOT NULL DEFAULT 'wallet',
            colour TEXT NOT NULL DEFAULT '#4CAF50', is_default INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0, allow_negative INTEGER NOT NULL DEFAULT 0,
            include_in_total INTEGER NOT NULL DEFAULT 1, bank_casso_id TEXT NULL,
            status TEXT NOT NULL DEFAULT 'active', sync_status TEXT NOT NULL DEFAULT 'pending',
            sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT NULL,
            sync_blocked_until INTEGER NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL
          )
        ''');
        database.execute(
            "INSERT INTO wallets (id, idaccount, name, updated_at) VALUES ('w-cu', 7, 'Tiền mặt', 1791219600)");
        database.execute('PRAGMA user_version = 27');
      },
    ));
    addTearDown(cu.close);

    final hang = await cu
        .customSelect("SELECT name, bi_tu_choi_trung_ten AS co FROM wallets WHERE id = 'w-cu'")
        .getSingle();
    expect(hang.read<String>('name'), 'Tiền mặt');
    expect(hang.read<int>('co'), 0,
        reason: 'Không điền dữ liệu cũ: mặc định false chính là hành vi trước bản này.');
  });
}
