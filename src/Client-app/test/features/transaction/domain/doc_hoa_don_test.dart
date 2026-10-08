/// A5 mục 5.1 — luật đọc hoá đơn giấy (nâng từ spike C4). Bảy ca đầu chép từ `spike_c4_test.dart` (spike vẫn giữ bản
/// của nó — gọi qua bí danh); ca giờ là phần thêm của A5.
library;

import 'package:flowmoney/features/transaction/domain/doc_hoa_don.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ hoá đơn siêu thị: lấy dòng TỔNG, không lấy tiền khách đưa lớn hơn', () {
    final kq = docHoaDonTuChu('''
CO.OPMART NGUYEN TRAI
Ngay: 28/09/2026 18:42
Sau rieng Ri6   1   152.000
Nuoc suoi       2    39.862
TONG CONG              191.862
Tien khach dua         200.000
Tien thoi lai            8.138
''');
    expect(kq.tong, 191862, reason: 'tiền khách đưa (200.000) lớn hơn tổng — lấy số lớn nhất là sai');
    expect(kq.cuaHang, 'CO.OPMART NGUYEN TRAI');
    expect(kq.ngay, '28/09/2026');
  });

  test('nhãn và số bị OCR tách hai dòng → nhìn dòng kế', () {
    final kq = docHoaDonTuChu('Quán Phở Hùng\nPhở tái 45.000\nTổng thanh toán\n90.000 đ\nCảm ơn quý khách');
    expect(kq.tong, 90000);
  });

  test('nhiều dòng tổng: "Tổng thanh toán" thắng "Thành tiền" của từng dòng hàng', () {
    final kq = docHoaDonTuChu('Cà phê sữa\nThành tiền 35.000\nBánh mì\nThành tiền 25.000\nTổng thanh toán: 60.000');
    expect(kq.tong, 60000);
  });

  test('cùng nhãn hai lần → dòng SAU thắng (tổng sau giảm giá nằm dưới)', () {
    final kq = docHoaDonTuChu('Tổng cộng 120.000\nGiảm giá 20.000\nTổng cộng 100.000');
    expect(kq.tong, 100000);
  });

  test('không có nhãn nào → số lớn nhất, bỏ số quá dài (điện thoại, mã vạch)', () {
    final kq = docHoaDonTuChu('Tap hoa Co Ba\nDT 0901234567\nMi goi 12.000\nTrung 30.000\n8934563138165');
    expect(kq.tong, 30000);
    expect(kq.canCu, contains('không nhãn'));
  });

  test('biên lai chuyển khoản: "Số tiền"', () {
    final kq = docHoaDonTuChu('MB Bank\nGiao dịch thành công\nSố tiền 1.250.000 VND\nNgày 01-10-26');
    expect(kq.tong, 1250000);
    expect(kq.ngay, '01/10/2026');
  });

  test('chữ rỗng → không có gì, không ném', () {
    expect(docHoaDonTuChu('  \n ').tong, isNull);
  });

  test('giờ in trên hoá đơn đi cùng ngày; không có giờ thì null', () {
    final kq = docHoaDonTuChu('CO.OPMART\nNgay: 28/09/2026 18:42\nTONG CONG 191.862');
    expect(kq.ngay, '28/09/2026');
    expect(kq.gio, '18:42');
    expect(docHoaDonTuChu('Pho\nTong 90.000').gio, isNull);
  });

  test('giờ sai (25:61) không nhận', () {
    expect(docHoaDonTuChu('X\n01/10/2026 25:61\nTong 10.000').gio, isNull);
  });

  test('kNhanTongHoaDon / kNhanLoaiHoaDon công khai, cùng nội dung spike', () {
    expect(kNhanTongHoaDon.first, 'tong thanh toan');
    expect(kNhanLoaiHoaDon, contains('khach dua'));
  });
}
