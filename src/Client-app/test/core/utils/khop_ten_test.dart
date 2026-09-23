/// Khớp tên tham số của tool (bước 2): danh mục / ví mà mô hình gõ, thường
/// KHÔNG DẤU. Ba luật: bằng nhau sau chuẩn hoá thắng; không có thì bằng nhau
/// sau bỏ dấu; KHÔNG BAO GIỜ so chuỗi con.
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

  test('chữ hỏi rỗng → KhongKhop, kể cả khi danh sách có một tên rỗng', () {
    expect(khopTheoTen('   ', ['Ăn uống', ''], ten), isA<KhongKhop<String>>(),
        reason: 'thiếu chốt rỗng thì "" khớp đúng tên rỗng — tool nhận một tham '
            'số trống như một lựa chọn');
  });
}
