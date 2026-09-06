/// Hợp đồng của phép so tên danh mục. Đây là định nghĩa DUY NHẤT trong dự án,
/// và phía backend phải chuẩn hoá y hệt — lệch một bước thì quy tắc trùng tên
/// thủng âm thầm.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/category/category_name.dart';

void main() {
  // Dựng dạng tách dấu bằng ESCAPE CODE POINT, không viết ký tự trực tiếp:
  // ký tự NFD không sống sót qua nhiều công cụ soạn thảo/ghi file — chúng âm
  // thầm gộp về NFC, và test sẽ xanh giả.
  const nfdCaPhe = 'Cà phê'; // a + huyền, e + mũ
  const nfcCaPhe = 'Cà phê';

  test('Bước 1 — gộp dạng Unicode tách dấu về dựng sẵn (NFC)', () {
    expect(nfdCaPhe == nfcCaPhe, isFalse,
        reason: 'hai chuỗi vốn khác nhau về byte');
    expect(nfdCaPhe.length, 8);
    expect(nfcCaPhe.length, 6);

    expect(
      normalizeCategoryName(nfdCaPhe),
      normalizeCategoryName(nfcCaPhe),
      reason: 'Hai tên nhìn y hệt nhau mà không gộp được thì người dùng vẫn '
          'tạo trùng được, và không có cách nào nhìn ra bằng mắt.',
    );
  });

  test('Bước 1 — chữ vừa có mũ vừa có dấu', () {
    // "Nguyễn": e + mũ + ngã
    expect(normalizeCategoryName('Nguyễn'),
        normalizeCategoryName('Nguyễn'));
    // "khoẻ": e + dấu hỏi
    expect(normalizeCategoryName('khoẻ'), normalizeCategoryName('khoẻ'));
  });

  test('Bước 2 — không phân biệt hoa/thường', () {
    expect(normalizeCategoryName('Ăn Uống'), normalizeCategoryName('ăn uống'));
    expect(normalizeCategoryName('CÀ PHÊ'), normalizeCategoryName('cà phê'));
  });

  test('Bước 3 — cắt khoảng trắng hai đầu', () {
    expect(normalizeCategoryName('  Cà phê  '), 'cà phê');
  });

  test('Bước 4 — gom khoảng trắng ở giữa', () {
    expect(normalizeCategoryName('Cà   phê'), 'cà phê');
    expect(normalizeCategoryName('Cà\tphê'), 'cà phê');
  });

  test('KHÔNG bỏ dấu tiếng Việt', () {
    expect(
      normalizeCategoryName('Ăn uống') == normalizeCategoryName('An uong'),
      isFalse,
      reason: 'Bỏ dấu sẽ gộp nhầm những tên thật sự khác nhau — "má" và "ma" '
          'là hai danh mục khác nhau.',
    );
  });

  test('Giá trị trả về chỉ dùng để SO SÁNH, không phải để lưu', () {
    expect(normalizeCategoryName('Thú Cưng'), 'thú cưng',
        reason: 'Nơi gọi phải lưu chuỗi gốc người dùng gõ; hàm này chỉ sinh '
            'khoá đối chiếu.');
  });
}
