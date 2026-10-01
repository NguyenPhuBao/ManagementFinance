/// `gopGiaoDich` — cộng nhóm trên đúng tập `timGiaoDich` đã lọc (spec mục 2.5):
/// không lọc lại, không so chiều tiền bằng chuỗi, chỉ cộng theo enum.
library;

import 'package:flowmoney/features/transaction/domain/gop_giao_dich.dart';
import 'package:flowmoney/features/transaction/domain/tim_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

DongTimThay _d(String dm, double tien, ChieuTim chieu, {String vi = 'Tiền mặt', String? viDich}) =>
    DongTimThay(
      tieuDe: '$dm $tien',
      tenDanhMuc: dm == '-' ? null : dm,
      tenVi: vi,
      tenViDich: viDich,
      soTien: tien,
      chieu: chieu,
      ngay: DateTime(2026, 9, 5),
    );

void main() {
  final dong = [
    _d('Ăn uống', 50000, ChieuTim.chi),
    _d('Di chuyển', 180000, ChieuTim.chi),
    _d('Di chuyển', 20000, ChieuTim.chi),
    _d('Lương', 9000000, ChieuTim.thu),
    _d('-', 500000, ChieuTim.chi),
    _d('-', 100000, ChieuTim.chuyen, viDich: 'Tiết kiệm'),
  ];

  test('⭐ theo danh mục: cộng chi, thu, số khoản; khoản không danh mục vào "Chưa phân loại"; xếp chi giảm dần', () {
    final n = gopGiaoDich(dong, theo: NhomTheo.danhMuc, chieu: ChieuTim.tatCa);
    expect(n.map((x) => x.ten).toList(), ['Chưa phân loại', 'Di chuyển', 'Ăn uống', 'Lương']);
    final dc = n[1];
    expect(dc.chi, 200000);
    expect(dc.thu, 0);
    expect(dc.soKhoan, 2);
    expect(n.first.chi, 500000, reason: 'khoản chi 500.000 không danh mục');
    expect(n.first.chuyen, 100000, reason: 'khoản chuyển không danh mục cũng vào nhóm ấy');
    expect(n.last.thu, 9000000);
  });

  test('chiều thu → xếp theo thu giảm dần', () {
    final n = gopGiaoDich(dong, theo: NhomTheo.danhMuc, chieu: ChieuTim.thu);
    expect(n.first.ten, 'Lương');
  });

  test('theo ví: khoản chuyển tính vào ví NGUỒN', () {
    final n = gopGiaoDich(dong, theo: NhomTheo.vi, chieu: ChieuTim.tatCa);
    expect(n.single.ten, 'Tiền mặt');
    expect(n.single.chuyen, 100000);
    expect(n.single.soKhoan, 6);
  });

  test('tổng các nhóm bằng tổng tập — gộp không làm mất khoản nào', () {
    final n = gopGiaoDich(dong, theo: NhomTheo.danhMuc, chieu: ChieuTim.tatCa);
    expect(n.fold<double>(0, (s, x) => s + x.chi), 750000);
    expect(n.fold<int>(0, (s, x) => s + x.soKhoan), dong.length);
  });

  test('rỗng → rỗng', () {
    expect(gopGiaoDich(const [], theo: NhomTheo.danhMuc, chieu: ChieuTim.chi), isEmpty);
  });
}
