/// `HangChuaDayNha` / `dongHangChuaDay` — nội dung hộp hỏi lại trước khi Rời nhà / Giải tán (gia đình 1B, Task 2).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/household/domain/hang_chua_day.dart';

void main() {
  test('rỗng: không dòng nào, rong true, không tiền trả về', () {
    const h = HangChuaDayNha();
    expect(dongHangChuaDay(h), isEmpty);
    expect(h.rong, isTrue);
    expect(h.coTienTraVe, isFalse);
  });

  test('chỉ khoản', () {
    const h = HangChuaDayNha(khoan: 2);
    expect(dongHangChuaDay(h), ['2 khoản của nhà']);
    expect(h.rong, isFalse);
    expect(h.coTienTraVe, isFalse, reason: 'khoản thường không được trả về ví riêng');
  });

  test('chỉ góp', () {
    const h = HangChuaDayNha(gop: 1);
    expect(dongHangChuaDay(h), ['1 khoản góp']);
    expect(h.coTienTraVe, isTrue);
  });

  test('góp và rút cùng một dòng', () {
    const h = HangChuaDayNha(gop: 1, rut: 1);
    expect(dongHangChuaDay(h), ['1 khoản góp, 1 khoản rút'], reason: 'hai loại tiền trả về nói chung một dòng');
  });

  test('đủ loại theo thứ tự, loại trống không hiện', () {
    const h = HangChuaDayNha(khoan: 3, rut: 2, vi: 1, danhMuc: 4, khac: 5);
    expect(dongHangChuaDay(h), ['3 khoản của nhà', '2 khoản rút', '1 ví chung', '4 danh mục của nhà', '5 mục khác']);
    expect(h.coTienTraVe, isTrue);
  });
}
