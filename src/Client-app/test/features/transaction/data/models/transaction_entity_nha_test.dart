import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionEntity moi() => TransactionEntity(
        id: 'g1', walletId: 'v1', idaccount: 10, amount: 2000, type: 'thu',
        date: DateTime(2026, 11, 1), updatedAt: DateTime(2026, 11, 1),
        idhousehold: 7, fundPairId: 'cap-1',
      );

  test('toCompanion mang idhousehold và fundPairId', () {
    final c = moi().toCompanion();
    expect(c.idhousehold.value, 7, reason: 'thiếu là khoản của nhà lưu thành khoản riêng');
    expect(c.fundPairId.value, 'cap-1');
  });

  test('copyWith giữ idhousehold và fundPairId', () {
    final e = moi().copyWith(amount: 5);
    expect(e.idhousehold, 7, reason: 'sửa khoản của nhà không được biến nó thành khoản riêng');
    expect(e.fundPairId, 'cap-1');
  });
}
