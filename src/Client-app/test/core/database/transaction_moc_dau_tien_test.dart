/// `TransactionDao.getFirstTransactionDate` — mốc giao dịch **sớm nhất** của
/// một tài khoản, tức **tuổi dữ liệu**.
///
/// Nó là mẫu số của `cuaSoNhinLai`: mọi con số "trung bình mỗi tháng" trong app
/// chia cho số ngày mà cửa sổ ấy trả về. Nên hai thứ ở đây quan trọng hơn vẻ
/// ngoài của chúng — lấy đúng đầu **sớm** (DAO đã có `getLastTransactionDate`
/// cho đầu kia, và hai hàm chỉ khác nhau một chữ `min`/`max`), và **bỏ hàng đã
/// xoá mềm**, vì để chúng làm mốc là kéo dài mẫu số bằng dữ liệu người dùng đã
/// bỏ đi — mọi mức tháng nhỏ đi, im lặng.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  const idaccount = 7;
  const idVi = 'vi-1';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.walletDao.insert(WalletsCompanion.insert(
      id: idVi,
      idaccount: idaccount,
      name: 'Tiền mặt',
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() => db.close());

  Future<void> them(String id, DateTime ngay, {bool daXoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: idVi,
        idaccount: idaccount,
        amount: 10000,
        type: 'chi',
        date: ngay,
        isDeleted: Value(daXoa),
        deletedAt: daXoa ? Value(ngay) : const Value.absent(),
        updatedAt: ngay,
      ));

  test('tài khoản chưa có giao dịch nào trả null', () async {
    expect(
      await db.transactionDao.getFirstTransactionDate(idaccount),
      isNull,
      reason: '`cuaSoNhinLai` đọc `null` là "chưa đủ để nói" và im hẳn',
    );
  });

  test('trả mốc SỚM NHẤT, không phải muộn nhất', () async {
    await them('a', DateTime(2026, 9, 10));
    await them('b', DateTime(2026, 9, 2));
    await them('c', DateTime(2026, 9, 20));

    expect(
      await db.transactionDao.getFirstTransactionDate(idaccount),
      DateTime(2026, 9, 2),
      reason: 'lấy nhầm đầu kia thì mẫu số teo lại và mọi mức tháng phồng lên; '
          'DAO đã có `getLastTransactionDate` nên hai hàm rất dễ lẫn',
    );
  });

  test('giao dịch đã xoá mềm KHÔNG được làm mốc', () async {
    await them('cu', DateTime(2026, 6, 1), daXoa: true);
    await them('moi', DateTime(2026, 9, 2));

    expect(
      await db.transactionDao.getFirstTransactionDate(idaccount),
      DateTime(2026, 9, 2),
      reason: 'để hàng đã xoá làm mốc là kéo dài mẫu số bằng dữ liệu người '
          'dùng đã bỏ đi — mọi mức tháng nhỏ đi, và không gì báo',
    );
  });

  test('không lẫn sang tài khoản khác', () async {
    await them('a', DateTime(2026, 9, 10));

    expect(await db.transactionDao.getFirstTransactionDate(999), isNull);
  });
}
