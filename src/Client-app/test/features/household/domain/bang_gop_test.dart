// Bảng ai góp bao nhiêu (`docs/Family/02A` mục 8).
import 'package:flowmoney/features/household/domain/bang_gop.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

var _dem = 0;

/// [cap] khác null = nửa góp / rút (không danh mục); ngược lại là khoản thường có danh mục.
TransactionEntity gd(double tien, DateTime ngay,
        {int ai = 10,
        int? nha = 7,
        String? cap,
        String type = 'chi',
        String vi = 'v',
        bool daXoa = false,
        DateTime? xoaLuc}) =>
    TransactionEntity(
      id: 'g${_dem++}',
      walletId: vi,
      idaccount: ai,
      amount: tien,
      type: type,
      categoryId: cap == null ? 'c' : null,
      date: ngay,
      updatedAt: ngay,
      idhousehold: nha,
      fundPairId: cap,
      isDeleted: daXoa,
      deletedAt: xoaLuc,
    );

DongBangGop? dong(List<DongBangGop> b, int id) => b.where((d) => d.idaccount == id).firstOrNull;

void main() {
  final now = DateTime(2026, 11, 15);

  test('người ghi hai khoản góp hai tháng khác nhau', () {
    final b = bangGop([
      gd(100, DateTime(2026, 10, 20), type: 'thu', cap: 'p1'),
      gd(50, DateTime(2026, 11, 3), type: 'thu', cap: 'p2'),
    ], now: now);
    expect(dong(b, 10)!.gopThangNay, 50);
    expect(dong(b, 10)!.gopTuTruoc, 150, reason: 'gopTuTruoc là tổng từ trước tới giờ, gồm cả tháng này');
  });

  test('tiền mặt trao tay (chỉ nửa của nhà) vẫn tính cho người ghi', () {
    final b = bangGop([gd(70, DateTime(2026, 11, 2), ai: 11, type: 'thu', cap: 'p')], now: now);
    expect(dong(b, 11)!.gopThangNay, 70);
  });

  test('rút vào cột daRut, chi vào chiThangNay', () {
    final b = bangGop([
      gd(30, DateTime(2026, 11, 4), cap: 'p'),
      gd(20, DateTime(2026, 11, 5)),
      gd(99, DateTime(2026, 10, 5)),
    ], now: now);
    expect(dong(b, 10)!.daRut, 30);
    expect(dong(b, 10)!.chiThangNay, 20, reason: 'chi tháng trước không vào chiThangNay');
  });

  test('lọc theo ví', () {
    final b = bangGop([
      gd(10, DateTime(2026, 11, 2), type: 'thu', cap: 'p', vi: 'a'),
      gd(20, DateTime(2026, 11, 2), type: 'thu', cap: 'q', vi: 'b'),
    ], now: now, walletId: 'b');
    expect(dong(b, 10)!.gopTuTruoc, 20);
  });

  test('tháng 2 năm nhuận qua now', () {
    final b = bangGop([
      gd(1, DateTime(2028, 2, 29), type: 'thu', cap: 'p'),
      gd(2, DateTime(2028, 3, 1), type: 'thu', cap: 'q'),
    ], now: DateTime(2028, 2, 10));
    expect(dong(b, 10)!.gopThangNay, 1, reason: '29/2 năm nhuận còn trong tháng 2, 1/3 thì không');
  });

  test('người chỉ có khoản chi CŨ (tháng trước) vẫn có dòng, các số bằng 0 — "người đã rời có khoản trong ví" (02A mục 8)', () {
    final b = bangGop([gd(40, DateTime(2026, 10, 5), ai: 55)], now: now);
    final d = dong(b, 55);
    expect(d, isNotNull, reason: 'khoản chi tháng trước bị bỏ qua thì người ấy mất hẳn khỏi bảng');
    expect(d!.chiThangNay, 0);
    expect(d.gopTuTruoc, 0);
    expect(d.daRut, 0);
  });

  test('người đã rời vẫn có dòng theo idaccount; xoá mềm bị bỏ', () {
    final b = bangGop([
      gd(5, DateTime(2026, 11, 2), ai: 99, type: 'thu', cap: 'p'),
      gd(6, DateTime(2026, 11, 2), ai: 98, type: 'thu', cap: 'q', daXoa: true),
      gd(7, DateTime(2026, 11, 2), ai: 97, type: 'thu', cap: 'r', xoaLuc: DateTime(2026, 11, 3)),
    ], now: now);
    expect(dong(b, 99)!.gopThangNay, 5);
    expect(dong(b, 98), isNull);
    expect(dong(b, 97), isNull);
  });
}
