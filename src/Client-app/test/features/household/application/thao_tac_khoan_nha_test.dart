// `ThaoTacKhoanNha.xoa` (đợt 1B, Task 6): khoản cặp đi `GopQuyService.xoa`, khoản thường đi `deleteTransaction`.
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/application/thao_tac_khoan_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _GiaoDichGia implements TransactionRepository {
  final xoa = <(String, String?)>[];

  @override
  Future<void> deleteTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    xoa.add((transaction.id, destinationWalletId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GopQuyGia implements GopQuyService {
  _GopQuyGia(this.tra);

  final bool tra;
  final daXoa = <String>[];

  @override
  Future<bool> xoa(String maCap) async {
    daXoa.add(maCap);
    return tra;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransactionEntity _k({String? cap, String type = 'chi', String? dich}) => TransactionEntity(
      id: 'k1',
      walletId: 'v1',
      walletTransfer: dich,
      idaccount: 10,
      idhousehold: 7,
      fundPairId: cap,
      amount: 1000,
      type: type,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  test('khoản thường: deleteTransaction, không đụng GopQuyService', () async {
    final gd = _GiaoDichGia();
    final gq = _GopQuyGia(true);
    await ThaoTacKhoanNha(giaoDich: gd, gopQuy: gq).xoa(_k());
    expect(gd.xoa, [('k1', null)]);
    expect(gq.daXoa, isEmpty, reason: 'không có mã cặp thì không gỡ cặp');
  });

  test('khoản chuyển: ví đích đi theo để hoàn tiền', () async {
    final gd = _GiaoDichGia();
    await ThaoTacKhoanNha(giaoDich: gd, gopQuy: _GopQuyGia(true)).xoa(_k(type: 'transfer', dich: 'v2'));
    expect(gd.xoa, [('k1', 'v2')], reason: 'bỏ ví đích là ví đích giữ tiền đã chuyển');
  });

  test('khoản cặp: GopQuyService.xoa theo mã cặp, không deleteTransaction', () async {
    final gd = _GiaoDichGia();
    final gq = _GopQuyGia(true);
    await ThaoTacKhoanNha(giaoDich: gd, gopQuy: gq).xoa(_k(cap: 'p1', type: 'thu'));
    expect(gq.daXoa, ['p1']);
    expect(gd.xoa, isEmpty, reason: 'xoá một nửa là lệch cặp');
  });

  test('cặp không còn trên máy: ném CacheException, không im lặng', () async {
    final op = ThaoTacKhoanNha(giaoDich: _GiaoDichGia(), gopQuy: _GopQuyGia(false));
    await expectLater(
      op.xoa(_k(cap: 'p1', type: 'thu')),
      throwsA(isA<CacheException>().having((e) => e.message, 'message', 'Khoản này không còn trên máy.')),
    );
  });
}
