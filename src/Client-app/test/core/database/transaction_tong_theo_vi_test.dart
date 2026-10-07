/// `TransactionDao.tongTheoVi` — **công thức số dư**, định nghĩa duy nhất.
///
/// Luật phải khớp **nguyên văn** với `TransactionRepository._applyBalances`, kể
/// cả ngoại lệ của nó. Lệch một chỗ là số dư tính lại khác số dư từng cộng dồn,
/// và không gì báo ra.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  const acc = 7;
  const viA = 'wallet-a';
  const viB = 'wallet-b';
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final v in [viA, viB]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: v,
        idaccount: acc,
        name: 'Ví $v',
        updatedAt: DateTime(2026, 9, 1),
      ));
    }
  });

  tearDown(() => db.close());

  Future<void> them({
    required String id,
    required String vi,
    required String loai,
    required double soTien,
    String? viDich,
    bool xoa = false,
  }) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: acc,
        amount: soTien,
        type: loai,
        date: DateTime(2026, 9, 10),
        walletTransfer: Value(viDich),
        deletedAt: Value(xoa ? DateTime(2026, 9, 11) : null),
        updatedAt: DateTime(2026, 9, 10),
      ));

  test('thu cộng, chi trừ', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viA, loai: 'chi', soTien: 300);
    expect(await db.transactionDao.tongTheoVi(viA), 700);
  });

  test('khoản chuyển: trừ ví nguồn, cộng ví đích', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viA, loai: 'transfer', soTien: 400, viDich: viB);
    expect(await db.transactionDao.tongTheoVi(viA), 600);
    expect(await db.transactionDao.tongTheoVi(viB), 400);
  });

  test('khoản chuyển THIẾU ví đích: không tính bên nào', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viA, loai: 'transfer', soTien: 400);
    expect(await db.transactionDao.tongTheoVi(viA), 1000,
        reason: 'Luật lấy NGUYÊN VĂN từ `_applyBalances`: khoản chuyển không có '
            'ví đích thì KHÔNG động vào ví nào — "đừng trừ một nửa". Lệch khỏi '
            'nó là số dư tính lại khác số dư từng cộng dồn, và không gì báo ra.');
  });

  test('giao dịch đã xoá mềm KHÔNG được tính', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viA, loai: 'chi', soTien: 300, xoa: true);
    expect(await db.transactionDao.tongTheoVi(viA), 1000,
        reason: 'Hoàn tác một khoản trả là xoá MỀM nó (quy tắc 5). Đếm hàng đã '
            'xoá là tiền không bao giờ quay về ví.');
  });

  test('ví không có giao dịch nào trả 0', () async {
    expect(await db.transactionDao.tongTheoVi(viA), 0);
  });

  test('không lẫn giao dịch của ví khác', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viB, loai: 'thu', soTien: 500);
    expect(await db.transactionDao.tongTheoVi(viA), 1000);
    expect(await db.transactionDao.tongTheoVi(viB), 500);
  });

  test('⭐ bienDongTheoVi (E6): mỗi khoản một biến động có dấu, cộng lại ĐÚNG bằng tongTheoVi', () async {
    await them(id: 't1', vi: viA, loai: 'thu', soTien: 1000);
    await them(id: 't2', vi: viA, loai: 'chi', soTien: 300);
    await them(id: 't3', vi: viA, loai: 'transfer', soTien: 400, viDich: viB);
    await them(id: 't4', vi: viB, loai: 'transfer', soTien: 50, viDich: viA);
    await them(id: 't5', vi: viA, loai: 'transfer', soTien: 70);
    await them(id: 't6', vi: viA, loai: 'chi', soTien: 9, xoa: true);
    final bd = await db.transactionDao.bienDongTheoVi(viA);
    expect({for (final b in bd) b.id: b.soTien}, {'t1': 1000.0, 't2': -300.0, 't3': -400.0, 't4': 50.0},
        reason: 'chuyển thiếu ví đích (t5) và khoản đã xoá (t6) không phải biến động — cùng luật tongTheoVi');
    expect(bd.fold<double>(0, (a, b) => a + b.soTien), await db.transactionDao.tongTheoVi(viA));
  });
}
