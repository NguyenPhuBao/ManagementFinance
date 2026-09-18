/// Bàn phím số của màn Thêm giao dịch — trần số chữ số.
///
/// Canh chừng điều gì: `transaction."Amount"` là **`numeric(15,2)`**, tức nhiều
/// nhất **13 chữ số phần nguyên**. Tràn cho SQLSTATE `22003`, mà
/// `sync.service.js` **không có nhánh nào** cho mã ấy nên nó rơi về `DB_ERROR`;
/// và `_permanentCodes` của `SyncEngine` là **danh sách trắng**, `DB_ERROR`
/// không nằm trong đó. Kết quả: giao dịch bị **gửi lại ở mọi chu kỳ đồng bộ**,
/// không lỗi, không log, chỉ một hàng đợi càng lúc càng chậm.
///
/// ⚠️ Chỗ này **nặng hơn ô số dư ví** ở hai điểm: giao dịch là thứ người dùng
/// ghi hàng ngày, và bàn phím có phím **`000`** nên ba chữ số vào một lúc —
/// gõ thừa tới 14 chữ số dễ hơn hẳn.
///
/// Màn này không dùng `TextField` mà tự vẽ bàn phím, nên không áp
/// `inputFormatters` được. Phép gõ tách thành hàm thuần để chặn ở đúng một chỗ
/// và test được mà không phải dựng cả trang.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/transaction/domain/ban_phim_so_tien.dart';

void main() {
  group('gõ thêm chữ số', () {
    test('thay số 0 ban đầu thay vì nối vào sau nó', () {
      expect(themPhimSoTien('0', '5'), '5');
    });

    test('nối bình thường khi đã có chữ số', () {
      expect(themPhimSoTien('12', '3'), '123');
    });

    test('DỪNG ở đúng trần, không nối thêm', () {
      const day = '1234567890123'; // 13 chữ số
      expect(day.length, kSoChuSoToiDaSoTien);
      expect(themPhimSoTien(day, '4'), day,
          reason: '`numeric(15,2)` chứa nhiều nhất 13 chữ số phần nguyên. Chữ '
              'số thứ 14 làm giao dịch kẹt hàng đợi đẩy VĨNH VIỄN, im lặng.');
    });
  });

  group('phím 000', () {
    test('thêm trọn ba chữ số khi còn đủ chỗ', () {
      expect(themPhimSoTien('1', '000'), '1000');
    });

    test('KHÔNG làm gì khi số 0 đang đứng một mình', () {
      expect(themPhimSoTien('0', '000'), '0',
          reason: 'Hành vi cũ, giữ nguyên: "000" đứng đầu là một con số vô '
              'nghĩa.');
    });

    test('⚠️ CẮT BỚT cho vừa trần thay vì bỏ cả cụm', () {
      // 11 chữ số + '000' = 14, vượt một. Bỏ cả cụm thì người dùng bấm mà
      // không thấy gì xảy ra; cắt bớt thì họ được đúng phần còn chỗ.
      expect(themPhimSoTien('12345678901', '000'), '1234567890100');
      expect(themPhimSoTien('12345678901', '000').length,
          kSoChuSoToiDaSoTien);
    });

    test('đã đầy thì phím 000 không đổi gì', () {
      const day = '1234567890123';
      expect(themPhimSoTien(day, '000'), day);
    });
  });

  group('những phím KHÔNG phải chữ số vẫn như cũ', () {
    test('xoá lùi bỏ một ký tự, về "0" khi hết', () {
      expect(themPhimSoTien('123', 'backspace'), '12');
      expect(themPhimSoTien('1', 'backspace'), '0');
      expect(themPhimSoTien('0', 'backspace'), '0');
    });

    test('dấu thập phân chỉ vào được một lần', () {
      expect(themPhimSoTien('12', '.'), '12.');
      expect(themPhimSoTien('12.', '.'), '12.');
    });

    test('phím điều khiển không đổi gì', () {
      for (final phim in ['done', '+', '-']) {
        expect(themPhimSoTien('12', phim), '12');
      }
    });

    test('⚠️ trần chỉ đếm CHỮ SỐ, không đếm dấu thập phân', () {
      // 13 chữ số cộng một dấu chấm là 14 ký tự nhưng vẫn đúng 13 chữ số.
      const coCham = '123456789012.3';
      expect(themPhimSoTien(coCham, '4'), coCham,
          reason: 'Đếm cả dấu chấm là chặn sớm hơn thật một chữ số.');
    });
  });
}
