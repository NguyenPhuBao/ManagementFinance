/// `chuPhanTram` — chữ phần trăm từ một tỉ lệ; định nghĩa duy nhất (test quét 33).
library;

import 'package:flowmoney/core/utils/phan_tram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nhân 100, làm tròn về số nguyên gần nhất, thêm %', () {
    expect(chuPhanTram(0.25), '25%', reason: 'tỉ lệ tròn');
    expect(chuPhanTram(0.426), '43%', reason: 'làm tròn lên khi phần lẻ > .5');
    expect(chuPhanTram(0.424), '42%', reason: 'làm tròn xuống khi phần lẻ < .5');
    expect(chuPhanTram(0), '0%', reason: 'số 0');
  });

  test('không kẹp: vượt 100% hiện đúng mức vượt; số âm giữ dấu; -0 không thành "-0%"', () {
    expect(chuPhanTram(1.37), '137%', reason: 'chi vượt ngân sách phải thấy 137%, không phải 100%');
    expect(chuPhanTram(-0.25), '-25%', reason: 'để dành âm (chi > thu) giữ dấu');
    expect(chuPhanTram(-0.004), '0%', reason: 'round() trả int, int không có -0');
  });
}
