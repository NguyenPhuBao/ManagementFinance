/// Schema v31: bảng CỤC BỘ `danh_muc_ai_doans` — giao dịch có danh mục do AI (Gemma) chọn mà người dùng lưu nguyên, để
/// B1 không học từ chúng (người dùng chốt 2026-10-16; vòng lặp học sai mục 5d `CATEGORY_RATIONALE.md`).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema là v31', () => expect(db.schemaVersion, 31));

  test('bảng KHÔNG có cột đồng bộ', () async {
    final cols = await db.customSelect("PRAGMA table_info('danh_muc_ai_doans')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, {'transaction_id', 'idaccount', 'category_id', 'created_at'}, reason: 'bảng cục bộ — quy tắc 9');
  });

  test('đánh dấu, đọc theo TÀI KHOẢN, gỡ', () async {
    final dao = db.danhMucAiDoanDao;
    await dao.danhDau(idaccount: 10, transactionId: 't1', categoryId: 'c-an');
    await dao.danhDau(idaccount: 10, transactionId: 't2', categoryId: 'c-an');
    await dao.danhDau(idaccount: 11, transactionId: 't3', categoryId: 'c-an');
    expect(await dao.idsCua(10), {'t1', 't2'}, reason: 'quy tắc 2 — mọi phép đọc lọc theo tài khoản');

    await dao.go(idaccount: 10, transactionId: 't1');
    expect(await dao.idsCua(10), {'t2'});
    expect(await dao.idsCua(11), {'t3'}, reason: 'gỡ của tài khoản 10 không đụng tài khoản 11');
  });

  test('đánh dấu lại cùng giao dịch không nhân đôi', () async {
    final dao = db.danhMucAiDoanDao;
    await dao.danhDau(idaccount: 10, transactionId: 't1', categoryId: 'c-an');
    await dao.danhDau(idaccount: 10, transactionId: 't1', categoryId: 'c-dc');
    expect(await dao.idsCua(10), {'t1'});
  });

  test('purgeDataForOtherAccounts dọn bảng này', () async {
    final dao = db.danhMucAiDoanDao;
    await dao.danhDau(idaccount: 10, transactionId: 't1', categoryId: 'c');
    await dao.danhDau(idaccount: 11, transactionId: 't2', categoryId: 'c');
    await db.purgeDataForOtherAccounts(10);
    expect(await dao.idsCua(11), isEmpty, reason: 'dấu của người đăng nhập trước không được sót lại');
    expect(await dao.idsCua(10), {'t1'});
  });
}
