// Số liệu của nhà (`docs/Family/02A` mục 7.3): tiền vào quỹ, chi của nhà, biên `[tu, den)`.
import 'package:flowmoney/features/household/domain/so_lieu_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

var _dem = 0;
TransactionEntity gd(double tien,
        {int? nha = 7,
        String? cap,
        String type = 'chi',
        String note = '',
        String? cat,
        DateTime? ngay,
        bool daXoa = false,
        DateTime? xoaLuc}) =>
    TransactionEntity(
      id: 'g${_dem++}',
      walletId: 'v',
      idaccount: 10,
      amount: tien,
      type: type,
      note: note,
      categoryId: cat,
      date: ngay ?? DateTime(2026, 11, 5),
      updatedAt: DateTime(2026, 11, 5),
      idhousehold: nha,
      fundPairId: cap,
      isDeleted: daXoa,
      deletedAt: xoaLuc,
    );

void main() {
  test('tiền vào quỹ = góp + thu khác', () {
    final ds = [
      gd(100, type: 'thu', cap: 'p'),
      gd(50, type: 'thu', cat: 'c'),
      gd(30, cat: 'c'),
      gd(20, cap: 'p'),
    ];
    expect(tienVaoQuy(ds), 150);
  });

  test('chi của nhà không gồm rút, chuyển, neo, điều chỉnh', () {
    final ds = [
      gd(10, cat: 'c'),
      gd(20, cap: 'p'),
      gd(40, type: 'transfer'),
      gd(80, type: 'thu', note: tienToMoSo),
      gd(160, type: 'thu', note: '$tienToDieuChinh giảm'),
      gd(5, nha: null, cat: 'c'),
    ];
    expect(chiCuaNha(ds), 10, reason: 'chỉ chi thường của nhà');
  });

  test('biên [tu, den): khoản đúng mốc den không tính', () {
    final ds = [
      gd(1, ngay: DateTime(2026, 11, 1)),
      gd(2, ngay: DateTime(2026, 11, 30)),
      gd(4, ngay: DateTime(2026, 12, 1)),
      gd(8, ngay: DateTime(2026, 10, 31)),
    ];
    expect(chiCuaNha(ds, tu: DateTime(2026, 11, 1), den: DateTime(2026, 12, 1)), 3);
  });

  test('hàng xoá mềm không tính', () {
    final ds = [gd(1, daXoa: true), gd(2, xoaLuc: DateTime(2026, 11, 6)), gd(4)];
    expect(chiCuaNha(ds), 4);
  });
}
