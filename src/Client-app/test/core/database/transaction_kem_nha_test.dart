/// Danh sách Trang chủ / Sổ hiện khoản của NHÀ do tôi ghi (spec 2026-11-16 mục 3): `watchAllKemNha` / `watchKhoangKemNha`
/// trả riêng + khoản nhà tôi ghi, bỏ khoản nhà người khác ghi, bỏ nửa NHÀ của cặp góp / rút (nửa riêng đã là dòng của
/// lần góp), bỏ hàng xoá mềm. Hai hàm chỉ cho DANH SÁCH — `watchAll` / `watchKhoang` vẫn chỉ cá nhân.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.walletDao.insert(
        WalletsCompanion.insert(id: 'rieng', idaccount: 1, name: 'Tiền mặt', updatedAt: DateTime(2026, 11, 1)));
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'chung', idaccount: 2, name: 'Tiền chợ', updatedAt: DateTime(2026, 11, 1), idhousehold: const Value(7)));
  });
  tearDown(() => db.close());

  Future<void> them(String id, int ngay,
          {String vi = 'rieng', int idaccount = 1, int? nha, String? cap, DateTime? xoa}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: idaccount,
        amount: 10000,
        type: 'chi',
        date: DateTime(2026, 11, ngay),
        updatedAt: DateTime(2026, 11, ngay),
        idhousehold: Value(nha),
        fundPairId: Value(cap),
        deletedAt: Value(xoa),
      ));

  Future<void> soCai() async {
    await them('A-rieng', 1);
    await them('B-nha-toi', 2, vi: 'chung', nha: 7);
    await them('C-nha-nguoi-khac', 3, vi: 'chung', idaccount: 2, nha: 7);
    await them('D-nua-nha-cap', 4, vi: 'chung', nha: 7, cap: 'm');
    await them('E-nua-rieng-cap', 4, cap: 'm');
    await them('F-nha-toi-da-xoa', 5, vi: 'chung', nha: 7, xoa: DateTime(2026, 11, 6));
  }

  test('watchAllKemNha: riêng + khoản nhà tôi ghi, bỏ nhà người khác / nửa nhà của cặp / hàng xoá', () async {
    await soCai();
    final ds = await db.transactionDao.watchAllKemNha(1).first;
    expect(ds.map((t) => t.id).toSet(), {'A-rieng', 'B-nha-toi', 'E-nua-rieng-cap'},
        reason: 'D bị bỏ: nửa riêng E cùng mã đã kể lần góp — hiện cả hai là một lần góp thành hai dòng');
  });

  test('watchKhoangKemNha cắt đúng [from, to)', () async {
    await soCai();
    final ds = await db.transactionDao.watchKhoangKemNha(1, DateTime(2026, 11, 2), DateTime(2026, 11, 4)).first;
    expect(ds.map((t) => t.id), ['B-nha-toi']);
  });

  test('đối chứng: watchAll / watchKhoang vẫn CHỈ cá nhân', () async {
    await soCai();
    expect((await db.transactionDao.watchAll(1).first).map((t) => t.id).toSet(), {'A-rieng', 'E-nua-rieng-cap'});
  });
}
