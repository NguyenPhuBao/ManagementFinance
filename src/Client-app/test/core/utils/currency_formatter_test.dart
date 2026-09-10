/// Quy tắc hiển thị số tiền — **một định nghĩa duy nhất cho cả app**.
///
/// Thông lệ Việt Nam: dấu **chấm** ngăn từng ba chữ số của phần nguyên, dấu
/// **phẩy** cho phần thập phân. `1.234.567` và `1.234.567,50`.
///
/// ## Vì sao tệp này quan trọng hơn vẻ ngoài của nó
///
/// Trước 2026-09-09, dự án có sẵn `CurrencyFormatter` nhưng **21 tệp vẫn gọi
/// thẳng `NumberFormat` với sáu kiểu khác nhau, 45 chỗ**. Hậu quả đo được: 18
/// chỗ hiện ký hiệu `đ` còn `CurrencyFormatter` hiện `đ` — cùng một app, hai ký
/// hiệu tiền. Đổi quy tắc ở một nơi khi ấy chỉ làm app hiện hai định dạng lẫn
/// lộn thay vì một.
///
/// Test cuối tệp này canh chừng đúng chuyện đó tái diễn.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/currency_formatter.dart';

void main() {
  group('phần nguyên dùng dấu chấm', () {
    test('ngăn từng ba chữ số', () {
      expect(CurrencyFormatter.format(1234567), '1.234.567 đ');
      expect(CurrencyFormatter.format(1000), '1.000 đ');
      expect(CurrencyFormatter.format(999), '999 đ');
    });

    test('số rất lớn vẫn đúng nhịp ba chữ số', () {
      expect(CurrencyFormatter.format(1234567890123), '1.234.567.890.123 đ');
    });

    test('số 0', () {
      expect(CurrencyFormatter.format(0), '0 đ');
    });

    test('số âm mang dấu trừ ở đầu', () {
      expect(CurrencyFormatter.format(-50000), '-50.000 đ');
      expect(CurrencyFormatter.format(-1234567), '-1.234.567 đ');
    });
  });

  group('phần thập phân dùng dấu phẩy', () {
    test('format LÀM TRÒN về đồng chẵn', () {
      expect(CurrencyFormatter.format(1234567.5), '1.234.568 đ',
          reason: 'Tiền Việt không có đơn vị nhỏ hơn đồng, và cả 17 chỗ trong '
              'app trước đây đều cố ý decimalDigits: 0. Bản đầu của lớp này '
              'hiện phần lẻ khi có, và bộ test lộ ra ngay hậu quả: mọi số TÍNH '
              'RA (thiếu hụt, chi trung bình, dự phóng) đều có đuôi lẻ, nên màn '
              'hình đầy "7.927.272,73 đ" thay vì "7.927.273 đ".');
      expect(CurrencyFormatter.format(1234567.4), '1.234.567 đ');
      expect(CurrencyFormatter.format(1234567.0), '1.234.567 đ');
    });

    test('formatCoLe hiện hai chữ số, ngăn bằng dấu PHẨY', () {
      expect(CurrencyFormatter.formatCoLe(1234567.5), '1.234.567,50 đ');
      expect(CurrencyFormatter.formatCoLe(0.25), '0,25 đ');
      expect(CurrencyFormatter.formatCoLe(-1234.75), '-1.234,75 đ');
      expect(CurrencyFormatter.formatCoLe(1000), '1.000,00 đ');
    });

    test('lẻ quá hai chữ số thì làm tròn', () {
      expect(CurrencyFormatter.formatCoLe(1234.567), '1.234,57 đ');
    });

    test('dấu chấm KHÔNG bao giờ đứng trước phần thập phân', () {
      final ra = CurrencyFormatter.formatCoLe(1234567.89);
      final viTriPhay = ra.indexOf(',');
      expect(viTriPhay, greaterThan(0),
          reason: 'Phần thập phân phải ngăn bằng dấu phẩy.');
      expect(ra.substring(viTriPhay).contains('.'), isFalse,
          reason: 'Sau dấu phẩy không được còn dấu chấm nào — đó là dấu hiệu '
              'lối Anh–Mỹ lọt vào.');
    });
  });

  group('số không kèm ký hiệu — cho ô nhập liệu', () {
    test('vẫn đúng quy tắc dấu, chỉ khác là không có "đ"', () {
      expect(CurrencyFormatter.formatSoThoi(1234567), '1.234.567');
      expect(CurrencyFormatter.formatSoThoi(1234567.5), '1.234.568');
      expect(CurrencyFormatter.formatSoThoi(0), '0');
      expect(CurrencyFormatter.formatSoThoi(-1000), '-1.000');
    });

    test('không lẫn ký hiệu vào', () {
      expect(CurrencyFormatter.formatSoThoi(1000).contains('đ'), isFalse,
          reason: 'Ô nhập liệu tự thêm ký hiệu ở chỗ khác; lẫn vào đây là ô '
              'nhập hiện "1.000 đ" rồi parse lại thành rác.');
    });
  });

  group('thu và chi', () {
    test('thu nhập mang dấu cộng', () {
      expect(CurrencyFormatter.formatIncome(500000), '+500.000 đ');
    });

    test('chi tiêu mang dấu trừ', () {
      expect(CurrencyFormatter.formatExpense(500000), '-500.000 đ');
    });

    test('hai hàm trên luôn dùng trị tuyệt đối', () {
      expect(CurrencyFormatter.formatIncome(-500000), '+500.000 đ',
          reason: 'Chiều tiền do nơi gọi quyết định, không suy từ dấu của số — '
              'nếu không một khoản chi lưu số âm sẽ thành "--500.000".');
      expect(CurrencyFormatter.formatExpense(-500000), '-500.000 đ');
    });
  });

  group('đọc ngược chuỗi về số', () {
    test('chuỗi người dùng gõ vào', () {
      expect(CurrencyFormatter.parse('1.234.567'), 1234567.0);
      expect(CurrencyFormatter.parse('1.234.567 đ'), 1234567.0);
      expect(CurrencyFormatter.parse('1.234,50'), 1234.5,
          reason: 'Dấu phẩy là phần thập phân, đúng chiều ngược của format.');
    });

    test('chuỗi không phải số trả về null', () {
      expect(CurrencyFormatter.parse('linh tinh'), isNull);
      expect(CurrencyFormatter.parse(''), isNull);
    });

    test('format rồi parse lại ra đúng số ban đầu', () {
      for (final n in [0, 999, 1000, 1234567]) {
        expect(CurrencyFormatter.parse(CurrencyFormatter.format(n)), n * 1.0,
            reason: 'Hai chiều phải khớp nhau; lệch là ô nhập tiền đọc sai thứ '
                'chính nó vừa hiện ra.');
      }
    });
  });

  test('KHÔNG tệp nào trong lib/ được tự dựng NumberFormat cho tiền', () {
    // Canh chừng chuyện đã xảy ra: 45 chỗ tự dựng `NumberFormat`, sáu kiểu khác
    // nhau, hai ký hiệu tiền cùng tồn tại. Ai thêm một chỗ nữa sẽ làm test này
    // đỏ ngay thay vì để app lệch định dạng trong im lặng.
    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      // Chính tệp định nghĩa quy tắc thì được phép.
      if (f.path.replaceAll(r'\', '/').endsWith('core/utils/currency_formatter.dart')) {
        continue;
      }
      if (f.readAsStringSync().contains('NumberFormat')) {
        viPham.add(f.path.replaceAll(r'\', '/'));
      }
    }

    expect(viPham, isEmpty,
        reason: 'Những tệp này tự dựng NumberFormat thay vì gọi '
            'CurrencyFormatter, nên chúng KHÔNG đổi theo khi quy tắc hiển thị '
            'tiền đổi:\n  ${viPham.join('\n  ')}');
  });
}
