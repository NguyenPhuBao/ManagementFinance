/// Phần thuần của `redirect` ba route tạo (spec Premium 5.3 / 7.1). Đường SỬA
/// `/budget/rules?id=…` không bao giờ bị chặn, dù kết quả trần là Vượt.
library;

import 'package:flowmoney/features/premium/domain/chuyen_huong_theo_goi.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vuotVi = Vuot(loai: LoaiTran.vi, tran: 3, dangCo: 3);
  const vuotNs = Vuot(loai: LoaiTran.nganSach, tran: 3, dangCo: 3);

  test('Vượt → /premium?tran=<mã>; Được → null', () {
    expect(chuyenHuongTheoGoi(Uri.parse('/wallets/add'), vuotVi),
        '/premium?tran=vi');
    expect(
        chuyenHuongTheoGoi(Uri.parse('/goals/add'),
            const Vuot(loai: LoaiTran.mucTieu, tran: 3, dangCo: 4)),
        '/premium?tran=muc_tieu');
    expect(chuyenHuongTheoGoi(Uri.parse('/budget/rules'), vuotNs),
        '/premium?tran=ngan_sach');
    expect(chuyenHuongTheoGoi(Uri.parse('/wallets/add'), const Duoc()),
        isNull);
  });

  test('⚠️ /budget/rules?id=… là SỬA — không chặn dù ket là Vượt', () {
    expect(
        chuyenHuongTheoGoi(Uri.parse('/budget/rules?id=b1'),
            const Vuot(loai: LoaiTran.nganSach, tran: 3, dangCo: 9)),
        isNull);
  });

  test('/budget/rules?category=…&amount=… (thẻ Chưa đặt ngân sách) là TẠO — chặn',
      () {
    expect(
        chuyenHuongTheoGoi(
            Uri.parse('/budget/rules?category=c1&amount=500000'), vuotNs),
        '/premium?tran=ngan_sach');
  });

  test('?id= rỗng vẫn là tạo', () {
    expect(chuyenHuongTheoGoi(Uri.parse('/budget/rules?id='), vuotNs),
        isNotNull);
  });
}
