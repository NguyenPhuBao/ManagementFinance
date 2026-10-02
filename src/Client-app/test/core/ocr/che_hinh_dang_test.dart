/// `cheHinhDang` — thứ DUY NHẤT của chữ trên biên lai được phép ra logcat (chế độ thu mẫu, bản debug). Quy tắc §13.6
/// `progress/Client-app.md`: không ghi số dư / số tài khoản ra log kể cả lúc phát triển.
library;

import 'package:flowmoney/core/ocr/che_hinh_dang.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ chữ số → 9, từ ngoài danh sách cấu trúc → …, nhãn giữ nguyên', () {
    expect(cheHinhDang('Số tiền 150.000 VND'), 'Số tiền 999.999 VND');
    expect(cheHinhDang('Người nhận NGUYEN VAN A'), 'Người nhận … … …');
    expect(cheHinhDang('Nội dung: tra tien nha thang 10'), 'Nội dung: … tien … … 99');
    expect(cheHinhDang('Mã giao dịch FT26275123456'), 'Mã giao dịch …99999999999');
  });

  test('không chữ số thật, không tên riêng nào lọt', () {
    final ra = cheHinhDang('TRAN QUANG DAT 0912345678 MB 262');
    expect(ra.contains(RegExp(r'[0-8]')), isFalse);
    expect(ra, isNot(contains('TRAN')));
    expect(ra, isNot(contains('DAT')));
  });

  test('chuỗi rỗng → rỗng', () {
    expect(cheHinhDang(''), '');
  });
}
