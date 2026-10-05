/// G63 — `ViTrungTenNguon` đọc MỌI ví chưa xoá (kể cả lưu trữ) rồi gọi `capViTrungTen`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/vi_trung_ten_nguon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc = 7;
  late AppDatabase db;
  late ViTrungTenNguonImpl nguon;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nguon = ViTrungTenNguonImpl(db: db);
  });
  tearDown(() => db.close());

  Future<void> vi(String id, String ten, {String status = 'active', int idaccount = acc}) =>
      db.walletDao.insert(WalletsCompanion.insert(
          id: id, idaccount: idaccount, name: ten, status: Value(status), updatedAt: DateTime(2026, 10, 5)));

  test('⭐ R bị từ chối + P cùng tên → {R}', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), {'r'});
  });

  test('P đang LƯU TRỮ vẫn giữ R', () async {
    await vi('p', 'Ví MB Bank', status: 'inactive');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), {'r'});
  });

  test('P đã xoá mềm → không giữ', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.softDelete('p');
    expect(await nguon.viDangBiGiu(acc), isEmpty);
  });

  test('ví của tài khoản khác không làm thành cặp', () async {
    await vi('p', 'Ví MB Bank', idaccount: 8);
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), isEmpty);
  });
}
