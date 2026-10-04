/// Phép học nhịp chi (dự án C việc hai, spec mục 4.2): hai trung vị theo phần thời
/// gian của kỳ, chỉ trên kỳ CÓ CHI, im hẳn khi dưới 3 kỳ.
library;

import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nhip_chi_mau.dart';

void main() {
  final xMau =
      viTriTrongKy(DateTime(2026, 11, 1), DateTime(2026, 12, 1), mocMau);

  test('viTriTrongKy: 5,5/30 ngày; kẹp [0, 1]; kỳ rỗng → 0', () {
    expect(xMau, closeTo(5.5 / 30, 1e-9));
    expect(
        viTriTrongKy(DateTime(2026, 11, 1), DateTime(2026, 12, 1),
            DateTime(2026, 10, 1)),
        0);
    expect(
        viTriTrongKy(DateTime(2026, 11, 1), DateTime(2026, 12, 1),
            DateTime(2027, 1, 1)),
        1);
    expect(
        viTriTrongKy(DateTime(2026, 11, 1), DateTime(2026, 11, 1),
            DateTime(2026, 11, 1)),
        0);
  });

  test('⭐ Nhà ở: mọi khi tới trưa ngày 6 đã chi 4/4,6 của kỳ, còn chi 600.000',
      () {
    final n = nhipNhaO();
    expect(n.soKy, 3);
    expect(n.phanDaChiMoiKhi(xMau), closeTo(4000000 / 4600000, 1e-9));
    expect(n.conChiMoiKhi(xMau), closeTo(600000, 1e-6),
        reason: 'Khoản ngày 10 ở vị trí 9/31 ≈ 0,29 > 0,183 nên còn "phải tới".');
  });

  test('Ăn uống chi đều: tới trưa ngày 6 mọi khi đã chi 6 ngày (600.000), còn 2.200.000',
      () {
    final n = nhipAnUong();
    expect(n.phanDaChiMoiKhi(xMau), closeTo(600000 / 2800000, 1e-9));
    expect(n.conChiMoiKhi(xMau), closeTo(2200000, 1e-6));
  });

  test('Mua sắm: tới trưa ngày 6 mọi khi đã chi 1/4, còn 900.000', () {
    final n = nhipMuaSam();
    expect(n.phanDaChiMoiKhi(xMau), closeTo(0.25, 1e-9));
    expect(n.conChiMoiKhi(xMau), closeTo(900000, 1e-6));
  });

  test('dưới 3 kỳ có chi → null (im hẳn)', () {
    expect(hocNhipChi(kyNhaO().sublist(0, 2)), isNull);
  });

  test('kỳ KHÔNG CHI không tính (spec quyết định 7): 3 kỳ mà 1 kỳ rỗng → null',
      () {
    final ky = [
      ...kyNhaO().sublist(0, 2),
      KyChi(
          from: DateTime(2026, 10, 1), to: DateTime(2026, 11, 1), khoan: const []),
    ];
    expect(hocNhipChi(ky), isNull);
  });

  test('4 kỳ có chi + 2 kỳ rỗng → học 4 kỳ, kỳ rỗng không vào trung vị', () {
    final ky = [
      KyChi(
          from: DateTime(2026, 4, 1), to: DateTime(2026, 5, 1), khoan: const []),
      kyThang(2026, 5, [(1, 4000000), (10, 600000)]),
      KyChi(
          from: DateTime(2026, 6, 1), to: DateTime(2026, 7, 1), khoan: const []),
      ...kyNhaO(),
    ];
    final n = hocNhipChi(ky)!;
    expect(n.soKy, 4);
    expect(n.tongTheoKy, [4600000, 4600000, 4600000, 4600000]);
    expect(n.conChiMoiKhi(xMau), closeTo(600000, 1e-6),
        reason: 'Tính cả hai kỳ rỗng thì trung vị của 6 số {0,0,600k×4} vẫn 600k — '
            'nên ca này canh bằng tongTheoKy, không bằng trung vị.');
  });

  test('trung vị số chẵn = trung bình hai giá trị giữa', () {
    final ky = [
      kyThang(2026, 7, [(1, 100), (28, 100)]),
      kyThang(2026, 8, [(1, 100), (28, 300)]),
      kyThang(2026, 9, [(1, 100), (28, 500)]),
      kyThang(2026, 10, [(1, 100), (28, 700)]),
    ];
    // Còn chi sau x: 100, 300, 500, 700 → trung vị (300 + 500) / 2 = 400.
    expect(hocNhipChi(ky)!.conChiMoiKhi(xMau), closeTo(400, 1e-9));
  });

  test('một tháng bất thường không kéo lệch nhịp', () {
    final ky = [
      ...kyNhaO(),
      kyThang(2026, 7, [(1, 4000000), (3, 20000000), (10, 600000)]),
    ];
    // Còn chi sau x ở bốn kỳ: 600k, 600k, 600k, 600k (laptop ngày 3 ở vị trí 2/31 < x).
    expect(hocNhipChi(ky)!.conChiMoiKhi(xMau), closeTo(600000, 1e-6));
    // Phần đã chi: 0,8696 ×3 và 24/24,6 ≈ 0,9756 → trung vị (0,8696 + 0,8696) / 2.
    expect(hocNhipChi(ky)!.phanDaChiMoiKhi(xMau),
        closeTo(4000000 / 4600000, 1e-9));
  });

  test('khoản đúng vị trí x tính là ĐÃ chi (≤)', () {
    final ky = [
      for (final t in [7, 8, 10]) kyThang(2026, t, [(1, 100), (17, 100)]),
    ];
    final n = hocNhipChi(ky)!;
    // Tháng 7, 8, 10 có 31 ngày: ngày 17 ở vị trí 16/31.
    expect(n.conChiMoiKhi(16 / 31), closeTo(0, 1e-9));
    expect(n.conChiMoiKhi(16 / 31 - 1e-6), closeTo(100, 1e-9));
  });
}
