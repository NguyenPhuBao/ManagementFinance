/// `TransactionDao.getById` — tra khoản chi theo id, **kể cả hàng đã xoá mềm**.
///
/// DAO vốn chỉ có `getByBill(billId)`, tức tra **ngược chiều** với cái
/// `BillPaymentConflictResolver` cần: nó cầm id khoản chi vừa bị server từ chối
/// và muốn tìm hoá đơn của nó.
///
/// Vì sao không lọc `deletedAt`: tới lúc resolver chạy, một chu kỳ đồng bộ
/// trước đó có thể đã gỡ khoản chi rồi. Hàm lọc sẵn sẽ trả `null`, resolver
/// coi như "không có gì để làm" và **bỏ qua im lặng** một ca đáng xử — trong
/// khi hai bản ghi vẫn còn kẹt hàng đợi đẩy.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  const accountId = 7;
  const idVi = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Ví phải có trước: `transactions.walletId` mang khoá ngoại tới `wallets`.
    await db.walletDao.insert(WalletsCompanion.insert(
      id: idVi,
      idaccount: accountId,
      name: 'Tiền mặt',
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() => db.close());

  Future<void> themKhoanChi(String id, {bool daXoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: idVi,
        idaccount: accountId,
        amount: 50000,
        type: 'chi',
        date: DateTime(2026, 9, 1),
        billId: const Value('bill-1'),
        isDeleted: Value(daXoa),
        deletedAt: daXoa ? Value(DateTime(2026, 9, 2)) : const Value.absent(),
        updatedAt: DateTime(2026, 9, 1),
      ));

  test('trả về giao dịch theo id', () async {
    await themKhoanChi('tx-1');
    final t = await db.transactionDao.getById('tx-1');
    expect(t, isNotNull);
    expect(t!.id, 'tx-1');
    expect(t.billId, 'bill-1',
        reason: 'Đây là cả lý do hàm tồn tại: đi từ id khoản chi sang hoá đơn.');
  });

  test('VẪN trả về hàng đã xoá mềm', () async {
    await themKhoanChi('tx-2', daXoa: true);
    final t = await db.transactionDao.getById('tx-2');
    expect(t, isNotNull,
        reason: 'Lọc `deletedAt.isNull()` như `getByBill` là bỏ qua im lặng ca '
            'mà một chu kỳ trước đã gỡ khoản chi nhưng hai bản ghi vẫn còn kẹt '
            'hàng đợi đẩy.');
    expect(t!.isDeleted, isTrue);
  });

  test('trả null khi id không có', () async {
    expect(await db.transactionDao.getById('khong-co'), isNull);
  });
}
