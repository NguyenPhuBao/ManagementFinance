/// `ghepDongTheoHang` — ML Kit trả chữ theo CỘT, mọi luật đọc phía sau đọc theo HÀNG. Dời từ `spike_c4_test.dart`
/// ngày 2026-10-02 cùng hàm (ca dùng luật hoá đơn của spike ở lại tệp ấy).
library;

import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ảnh hai cột: khối nhãn (trái) rồi mới tới khối số (phải). Hàng cao 30, cách 44.
  DongOcr nhan(String chu, int hang) => DongOcr(chu, trai: 40, tren: 100.0 + 44 * hang, phai: 300, duoi: 130.0 + 44 * hang);
  DongOcr so(String chu, int hang, {double lech = 0}) =>
      DongOcr(chu, trai: 500, tren: 100.0 + 44 * hang + lech, phai: 640, duoi: 130.0 + 44 * hang + lech);

  test('⭐ ảnh hai cột: nhãn và số của CÙNG hàng về một dòng, dù đầu vào xếp theo cột', () {
    final ghep = ghepDongTheoHang([
      nhan('Số tiền', 0),
      nhan('Phí', 1),
      nhan('Nội dung', 2),
      so('150.000 VND', 0),
      so('0 VND', 1),
      so('tien nha', 2),
    ]);
    expect(ghep, 'Số tiền 150.000 VND\nPhí 0 VND\nNội dung tien nha');
  });

  test('trong một hàng: trái trước phải sau, bất kể thứ tự đầu vào', () {
    expect(ghepDongTheoHang([so('90.000', 0), nhan('Tong thanh toan', 0)]), 'Tong thanh toan 90.000');
  });

  test('các hàng xếp từ trên xuống, bất kể thứ tự đầu vào', () {
    expect(ghepDongTheoHang([nhan('Dong duoi', 2), nhan('Dong tren', 0), nhan('Dong giua', 1)]),
        'Dong tren\nDong giua\nDong duoi');
  });

  test('số lệch vài điểm ảnh so với nhãn (ảnh hơi nghiêng) vẫn cùng hàng; hàng kế thì KHÔNG bị gộp', () {
    final ghep = ghepDongTheoHang(
        [nhan('TONG CONG', 0), nhan('Tien khach dua', 1), so('191.862', 0, lech: 9), so('200.000', 1, lech: 9)]);
    expect(ghep, 'TONG CONG 191.862\nTien khach dua 200.000');
  });

  test('dòng tiêu đề chữ to không nuốt hàng ngay dưới nó, dù khung của nó trùm tới tâm dòng ấy', () {
    // Khung tiêu đề 20–120 chứa tâm (111) của dòng dưới; tâm tiêu đề (70) thì KHÔNG nằm trong khung dòng dưới.
    final ghep = ghepDongTheoHang([
      const DongOcr('SIEU THI', trai: 40, tren: 20, phai: 600, duoi: 120),
      const DongOcr('28/09/2026', trai: 400, tren: 96, phai: 600, duoi: 126),
    ]);
    expect(ghep, 'SIEU THI\n28/09/2026', reason: 'cùng hàng phải đúng ở CẢ HAI chiều — một chiều là chữ to nuốt chữ nhỏ');
  });

  test('không có dòng nào → chuỗi rỗng, không ném', () {
    expect(ghepDongTheoHang(const []), '');
  });
}
