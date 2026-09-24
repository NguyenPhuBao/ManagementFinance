/// Tham số do mô hình sinh (spec bước 2b mục 2.4, bẫy 4.43): giá trị giữ chỗ
/// nghĩa là KHÔNG LỌC, và số tiền nằm nhầm trong từ khoá phải nhận ra được.
library;

import 'package:flowmoney/features/ai_edge/domain/tham_so_mo_hinh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('thamSoTen', () {
    test('⭐ ba giá trị đo được ở cổng D lần 1 là giữ chỗ → null (không lọc)', () {
      for (final v in ['tat_ca', 'tất_cả', 'tất cả']) {
        expect(thamSoTen(v), isNull, reason: v);
      }
    });

    test('giữ chỗ không phân biệt hoa thường, khoảng trắng; "all", "tatca" cũng là giữ chỗ', () {
      for (final v in ['Tất Cả', '  TAT_CA ', 'tất  cả', 'all', 'ALL', 'tatca']) {
        expect(thamSoTen(v), isNull, reason: v);
      }
    });

    test('trống → null', () {
      for (final v in [null, '', '   ']) {
        expect(thamSoTen(v), isNull, reason: '$v');
      }
    });

    test('tên thật trả về nguyên, đã cắt khoảng trắng — khớp tên là việc của khopTheoTen', () {
      expect(thamSoTen(' Ăn uống '), 'Ăn uống');
      expect(thamSoTen('tiet kiem'), 'tiet kiem');
      expect(thamSoTen('khoan_chi'), 'khoan_chi',
          reason: 'dấu _ chỉ đổi lúc so giữ chỗ, không đổi giá trị trả về');
    });

    test('⭐ cố ý HẸP: "tất cả danh mục", "mọi", "Mới" không phải giữ chỗ', () {
      expect(thamSoTen('tất cả danh mục'), 'tất cả danh mục',
          reason: 'chưa đo được mô hình viết thế; mô tả tool dặn bỏ trống');
      expect(thamSoTen('mọi'), 'mọi');
      expect(thamSoTen('Mới'), 'Mới',
          reason: '"mọi" bỏ dấu trùng "mới" — nới ra là nuốt một tên thật');
    });

    test('nhận cả số — phép "điền" của GoiSoTraCuu dùng hàm này cho mọi tham số', () {
      expect(thamSoTen(500000), '500000');
      expect(thamSoTen(0), '0');
    });
  });

  group('laSoTien', () {
    test('⭐ số kèm đơn vị, chỉ gồm chữ số, "nửa triệu" → true', () {
      for (final s in [
        '500k', '500 k', '500K', '1 triệu', '1tr', '5 củ', '100 nghìn', '200.000đ',
        '200.000 đồng', '1.000.000', '1000000', 'trên 500k', 'nửa triệu', '50 vnd',
      ]) {
        expect(laSoTien(s), isTrue, reason: s);
      }
    });

    test('⭐ chữ có chữ số trong TÊN, ngày, đơn vị khác → false', () {
      for (final s in [
        'hoa don', 'muaxe', 'T9', 'di h0c', 'test1', '2026-09-04',
        'Kiem thu hoa don 2026-09-04', '2 kg', '1 trà sữa', '10/09', '',
      ]) {
        expect(laSoTien(s), isFalse, reason: s);
      }
    });
  });
}
