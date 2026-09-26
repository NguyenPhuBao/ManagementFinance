/// Khớp tên tham số của tool (bước 2): danh mục / ví mà mô hình gõ, thường
/// KHÔNG DẤU. Bốn luật: bằng nhau sau chuẩn hoá thắng; không có thì bằng nhau
/// sau bỏ dấu; không có nữa thì bằng nhau sau khi đọc `_` là dấu cách rồi bỏ
/// dấu (bước 2c, bẫy 4.45); KHÔNG BAO GIỜ so chuỗi con.
library;

import 'package:flowmoney/core/utils/khop_ten.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String ten(String x) => x;

  test('trùng chính xác theo normalizeCategoryName (hoa thường, khoảng trắng)', () {
    final kq = khopTheoTen('  ĂN   uống ', ['Ăn uống', 'Di chuyển'], ten);
    expect(kq, isA<KhopMot<String>>());
    expect((kq as KhopMot<String>).muc, 'Ăn uống');
  });

  test('⭐ không dấu vẫn khớp — câu đo gõ không dấu', () {
    expect((khopTheoTen('an uong', ['Ăn uống', 'Di chuyển'], ten) as KhopMot<String>).muc, 'Ăn uống');
    expect((khopTheoTen('do an', ['Đồ ăn'], ten) as KhopMot<String>).muc, 'Đồ ăn',
        reason: 'đ không phải d + dấu — removeVietnameseTones phải hạ nó về d');
  });

  test('trùng chính xác một mục THẮNG trùng bỏ dấu nhiều mục', () {
    final kq = khopTheoTen('Đá', ['Da', 'Đá'], ten);
    expect((kq as KhopMot<String>).muc, 'Đá');
  });

  test('nhiều mục trùng sau bỏ dấu → KhopNhieu', () {
    final kq = khopTheoTen('da', ['Dá', 'Đá'], ten);
    expect(kq, isA<KhopNhieu<String>>());
    expect((kq as KhopNhieu<String>).ds, ['Dá', 'Đá']);
  });

  test('⭐ KHÔNG so chuỗi con: "tiết kiệm" không khớp "Tiết kiệm mua nhà"', () {
    expect(khopTheoTen('tiết kiệm', ['Tiết kiệm mua nhà'], ten), isA<KhongKhop<String>>());
    expect((khopTheoTen('tiet kiem', ['Tiết kiệm', 'Tiết kiệm mua nhà'], ten) as KhopMot<String>).muc,
        'Tiết kiệm');
  });

  test('⭐ bậc ba: `_` đọc là dấu cách — "tiet_kiem" khớp Tiết kiệm (bẫy 4.45)', () {
    expect(
      (khopTheoTen('tiet_kiem', ['Tiết kiệm', 'Tiết kiệm mua nhà'], ten) as KhopMot<String>).muc,
      'Tiết kiệm',
      reason: 'C11 cổng D lần 2: E2B gõ vi: "tiet_kiem" → từ chối → L1b dù câu hỏi đúng ý',
    );
    expect(khopTheoTen('tiet_kiem', ['Tiết kiệm mua nhà'], ten), isA<KhongKhop<String>>(),
        reason: 'bậc ba vẫn không so chuỗi con');
  });

  test('tên thật có `_`: gõ y hệt khớp bậc 1, gõ dấu cách khớp bậc 3', () {
    expect((khopTheoTen('vi_test', ['vi_test'], ten) as KhopMot<String>).muc, 'vi_test');
    expect((khopTheoTen('vi test', ['vi_test'], ten) as KhopMot<String>).muc, 'vi_test');
  });

  test('bậc ba: hai tên thật chỉ khác ở `_` / dấu cách sau bỏ dấu → KhopNhieu', () {
    final kq = khopTheoTen('tiet_kiem', ['Tiết kiệm', 'Tiet kiem'], ten);
    expect(kq, isA<KhopNhieu<String>>());
    expect((kq as KhopNhieu<String>).ds, ['Tiết kiệm', 'Tiet kiem']);
  });

  test('⭐ bậc 2 THẮNG bậc 3: "an uong" giữa Ăn uống và an_uong → KhopMot Ăn uống', () {
    final kq = khopTheoTen('an uong', ['Ăn uống', 'an_uong'], ten);
    expect(kq, isA<KhopMot<String>>(),
        reason: 'bậc ba chỉ chạy khi hai bậc đầu trượt; chạy sớm thì cả hai cùng khớp → KhopNhieu oan');
    expect((kq as KhopMot<String>).muc, 'Ăn uống');
  });

  test('chữ hỏi rỗng → KhongKhop, kể cả khi danh sách có một tên rỗng', () {
    expect(khopTheoTen('   ', ['Ăn uống', ''], ten), isA<KhongKhop<String>>(),
        reason: 'thiếu chốt rỗng thì "" khớp đúng tên rỗng — tool nhận một tham '
            'số trống như một lựa chọn');
  });
}
