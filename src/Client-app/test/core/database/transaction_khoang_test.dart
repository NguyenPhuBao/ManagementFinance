/// Biên của `watchKhoang` là `[from, to)` — `to` **MỞ**.
///
/// `watchByMonth` cũ dùng biên ĐÓNG (`isSmallerOrEqualValue` với `to` đặt ở
/// 23:59:59 ngày cuối tháng). Nó được thay hẳn ngày 2026-09-21 khi trang Sổ
/// giao dịch bỏ phép buộc-theo-tháng: giữ cả hai là để **hai quy ước biên** sống
/// chung trong một DAO, và khoản ghi đúng mốc giao giữa hai kỳ sẽ bị đếm vào cả
/// hai. Lệch ấy không ném gì cả — chỉ là một con số lớn hơn thực tế.
///
/// Quy ước `to` mở là quy ước đã có sẵn của chính tệp DAO này, dùng cho
/// `tuanTruoc` và `tongThuChi`.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // `transactions.wallet_id` có khoá ngoại sang `wallets`, nên phải có ví
    // trước — chèn thẳng giao dịch cho SqliteException(787).
    for (final acc in [7, 99]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w1-$acc',
        idaccount: acc,
        name: 'Tiền mặt',
        updatedAt: DateTime(2026, 9, 1),
      ));
    }
  });
  tearDown(() => db.close());

  Future<void> them(String id, DateTime luc, {int idaccount = 7}) =>
      db.transactionDao.insert(
        TransactionsCompanion.insert(
          id: id,
          walletId: 'w1-$idaccount',
          idaccount: idaccount,
          amount: 10000,
          type: 'chi',
          date: luc,
          updatedAt: luc,
        ),
      );

  test('khoản ghi đúng mốc `to` KHÔNG thuộc kỳ này mà thuộc kỳ sau', () async {
    final dauT9 = DateTime(2026, 9, 1);
    final dauT10 = DateTime(2026, 10, 1);
    final dauT11 = DateTime(2026, 11, 1);

    await them('trong-ky', DateTime(2026, 9, 30, 23, 59, 59));
    await them('dung-moc-to', dauT10);

    final t9 = await db.transactionDao.watchKhoang(7, dauT9, dauT10).first;
    expect(t9.map((t) => t.id), ['trong-ky'],
        reason: 'biên `to` MỞ: khoản đúng 00:00 ngày 1 tháng sau thuộc kỳ sau');

    final t10 = await db.transactionDao.watchKhoang(7, dauT10, dauT11).first;
    expect(t10.map((t) => t.id), ['dung-moc-to'],
        reason: 'và nó phải xuất hiện ở đúng một chỗ, không phải cả hai');
  });

  test('khoản ghi đúng mốc `from` THUỘC kỳ này', () async {
    final dauT9 = DateTime(2026, 9, 1);
    await them('dung-moc-from', dauT9);
    final ket = await db.transactionDao
        .watchKhoang(7, dauT9, DateTime(2026, 10, 1))
        .first;
    expect(ket.map((t) => t.id), ['dung-moc-from'],
        reason: 'biên `from` ĐÓNG — khoảng là [from, to)');
  });

  test('lọc theo tài khoản và bỏ hàng đã xoá mềm', () async {
    await them('cua-toi', DateTime(2026, 9, 10));
    await them('cua-nguoi-khac', DateTime(2026, 9, 10), idaccount: 99);
    await them('da-xoa', DateTime(2026, 9, 11));
    await db.transactionDao.softDelete('da-xoa');

    final ket = await db.transactionDao
        .watchKhoang(7, DateTime(2026, 9, 1), DateTime(2026, 10, 1))
        .first;
    expect(ket.map((t) => t.id), ['cua-toi']);
  });

  test('sắp xếp mới nhất trước, như bản cũ', () async {
    await them('cu', DateTime(2026, 9, 2));
    await them('moi', DateTime(2026, 9, 20));
    final ket = await db.transactionDao
        .watchKhoang(7, DateTime(2026, 9, 1), DateTime(2026, 10, 1))
        .first;
    expect(ket.map((t) => t.id), ['moi', 'cu']);
  });
}
