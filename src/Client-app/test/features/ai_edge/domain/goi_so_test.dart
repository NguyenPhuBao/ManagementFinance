/// Định dạng số liệu của gói số — thẻ số liệu, tập cho phép của bộ kiểm số,
/// và phần đưa vào prompt đều đọc đúng chuỗi này, nên nó phải theo đúng quy
/// ước tiền của app (chấm nghìn, `đ` có cách) và luật G2 (một chữ số thập
/// phân cho phần trăm).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('soTien dùng CurrencyFormatter: chấm nghìn, có cách, ký hiệu đ', () {
    expect(soTien('Đã chi', 2100000).chuoi, '2.100.000 đ');
    expect(soTien('Đã chi', 2100000).loai, LoaiSo.tien);
  });

  test('soPhanTram in ĐÚNG một chữ số thập phân, phẩy thập phân (G2)', () {
    expect(soPhanTram('Tăng', 12.5).chuoi, '12,5%');
    expect(soPhanTram('Tăng', 35).chuoi, '35,0%');
    expect(soPhanTram('Tăng', 12.55).chuoi, '12,6%',
        reason: 'làm tròn, không cắt');
    expect(soPhanTram('Giảm', -8.25).chuoi, '-8,3%',
        reason: 'số âm giữ dấu — hướng giảm phải đọc được');
  });

  test('soNgay và soDem', () {
    expect(soNgay('Còn', 9).chuoi, '9 ngày');
    expect(soNgay('Còn', 9).loai, LoaiSo.soNgay);
    expect(soDem('Số cam kết', 3).chuoi, '3');
    expect(soDem('Số cam kết', 3).loai, LoaiSo.soDem);
  });
}
