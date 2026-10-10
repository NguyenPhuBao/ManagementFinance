/// A5 mục 11.2b — đọc danh sách món trên hoá đơn giấy để người dùng tick món cho từng phần tách. Chữ OCR ở đây là GIẢ
/// LẬP; thêm chữ của hoá đơn thật khi có (nghiệm thu mục 9).
library;

import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ món một dòng, bỏ SL / đơn giá khỏi tên; dừng ở TONG CONG; không lấy khách đưa', () {
    final ds = docMonHang('''
CO.OPMART NGUYEN TRAI
Ngay: 28/09/2026 18:42
Ten hang   SL   Don gia   Thanh tien
Sau rieng Ri6   1   152.000
Nuoc suoi       2   19.931   39.862
TONG CONG              191.862
Tien khach dua         200.000''');
    expect([for (final m in ds) (m.ten, m.soTien)], [('Sau rieng Ri6', 152000.0), ('Nuoc suoi', 39862.0)],
        reason: 'tiêu đề cột "Thanh tien" KHÔNG được dừng đọc; ngày/giờ/năm không phải món');
  });

  test('món hai dòng: tên ở trên, dòng chỉ có số ở dưới → một món, tiền là số cuối', () {
    final ds =
        docMonHang('SUA TUOI VNM 180ML\n2 x 16.000 = 32.000\nBANH MI SANDWICH\n1 18.000 18.000\nTong cong 50.000');
    expect([for (final m in ds) (m.ten, m.soTien)], [('SUA TUOI VNM 180ML', 32000.0), ('BANH MI SANDWICH', 18000.0)]);
  });

  test('giảm giá / KM / dấu trừ → số âm; VAT vẫn là món; dừng ở tạm tính', () {
    final ds = docMonHang('OMO 3KG 120.000\nKM OMO -10.000\nVAT 8% 14.000\nTam tinh 124.000\nGiam gia 20.000');
    expect([for (final m in ds) m.soTien], [120000.0, -10000.0, 14000.0]);
  });

  test('bỏ số điện thoại, mã vạch dài, dòng không có ngăn nghìn', () {
    final ds = docMonHang('Tap hoa Co Ba\nDT 0901234567\n8934563138165 MI GOI 12.000\nTrung 30000\nTong 42.000');
    expect([for (final m in ds) m.ten], ['MI GOI'],
        reason: 'mã vạch bị gỡ khỏi tên; "30000" không ngăn nghìn → không món');
  });

  test('tên món chứa "tong" / "total" KHÔNG dừng đọc (so theo từ trọn)', () {
    final ds = docMonHang('BANH TONGHOP 25.000\nNUOC TOTALFRESH 12.000\nTong cong 37.000');
    expect(ds.length, 2);
  });

  test('id là chỉ số dòng, ổn định; toJson ↔ fromJson; fromJson rác → null', () {
    final ds = docMonHang('A 10.000\nB 20.000');
    expect(ds.map((m) => m.id), [0, 1]);
    expect(MonHang.fromJson(ds[1].toJson())!.ten, 'B');
    expect(MonHang.fromJson({'id': 'x'}), isNull);
    expect(MonHang.fromJson(42), isNull);
  });

  test('chữ rỗng → rỗng', () => expect(docMonHang('  \n'), isEmpty));
}
