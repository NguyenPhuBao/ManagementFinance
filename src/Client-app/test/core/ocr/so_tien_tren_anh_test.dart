import 'package:flowmoney/core/ocr/so_tien_tren_anh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('docSoTrenAnh: ngăn nghìn chấm / phẩy, bỏ phần lẻ', () {
    expect(docSoTrenAnh('150.000'), 150000);
    expect(docSoTrenAnh('1,250,000'), 1250000);
    expect(docSoTrenAnh('191.862,50'), 191862);
    expect(docSoTrenAnh('abc'), isNull);
  });

  test('⭐ tienTrenDong: bỏ số điện thoại, số tài khoản liền từ 9 chữ số, số dưới 1.000', () {
    expect(tienTrenDong('Số tiền 150.000 VND'), [150000]);
    expect(tienTrenDong('TK 0123456789'), isEmpty, reason: 'bắt đầu bằng 0 là số điện thoại / tài khoản');
    expect(tienTrenDong('Mã GD 123456789012'), isEmpty, reason: 'chuỗi liền ≥ 9 chữ số không ngăn nghìn là mã');
    expect(tienTrenDong('Phí 0 đ, lúc 18:45'), isEmpty);
  });
}
