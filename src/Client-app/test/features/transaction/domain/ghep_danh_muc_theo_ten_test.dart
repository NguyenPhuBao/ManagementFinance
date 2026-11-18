import 'package:flowmoney/features/transaction/domain/ghep_danh_muc_theo_ten.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUongRieng = makeCategory(id: 'food', name: 'Ăn uống');
  final anUongNha = makeCategory(id: 'nha-food', name: '  ăn  uống ');
  final anUongThu = makeCategory(id: 'nha-thu', name: 'Ăn uống', classify: 'thu');
  final cho = makeCategory(id: 'nha-cho', name: 'Đi chợ');

  test('cùng tên (chuẩn hoá) + cùng classify → danh mục bên đích', () {
    expect(ghepDanhMucTheoTen(anUongRieng, [cho, anUongNha])?.id, 'nha-food',
        reason: 'so bằng normalizeCategoryName: hoa / thường, khoảng trắng thừa không làm lệch');
  });

  test('cùng tên nhưng khác classify → null (không gắn danh mục thu cho khoản chi)', () {
    expect(ghepDanhMucTheoTen(anUongRieng, [anUongThu]), isNull);
  });

  test('không có tên trùng → null', () {
    expect(ghepDanhMucTheoTen(anUongRieng, [cho]), isNull);
  });

  test('chưa chọn → null', () {
    expect(ghepDanhMucTheoTen(null, [anUongNha]), isNull);
  });

  test('KHÔNG bỏ dấu: "Đá" không ghép "Da"', () {
    expect(ghepDanhMucTheoTen(makeCategory(id: 'a', name: 'Đá'), [makeCategory(id: 'b', name: 'Da')]), isNull,
        reason: 'quy tắc 7: removeVietnameseTones cấm dùng cho phép so tên');
  });
}
