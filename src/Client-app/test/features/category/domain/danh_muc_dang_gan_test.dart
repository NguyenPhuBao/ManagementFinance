/// Form SỬA giữ danh mục đang gắn khi nó không có trong danh sách chọn (bản sao ẩn theo khuôn — spec 2026-10-27 mục 4).
library;

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/domain/danh_muc_dang_gan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 27);
  CategoryEntity dm(String id, {String classify = 'chi', bool xoa = false, bool nhom = false, bool khuon = false}) =>
      CategoryEntity(
        id: id,
        idaccount: khuon ? 0 : 10,
        name: id,
        classify: classify,
        isDeleted: xoa,
        isGroup: nhom,
        isDefault: khuon,
        updatedAt: now,
      );
  final ds = [dm('a'), dm('b')];

  test('⭐ danh mục đang gắn vắng khỏi danh sách (đang ẩn) → kèm vào cuối', () {
    expect(kemDanhMucDangGan(ds, dm('an'), classify: 'chi').map((c) => c.id), ['a', 'b', 'an'],
        reason: 'DropdownButton văng / rơi về trống khi value không nằm trong items.');
  });

  test('đã có trong danh sách hoặc null → giữ nguyên', () {
    expect(kemDanhMucDangGan(ds, dm('a'), classify: 'chi'), same(ds));
    expect(kemDanhMucDangGan(ds, null, classify: 'chi'), same(ds));
  });

  test('đã xoá, nhóm, khuôn, khác loại → không kèm (giữ hành vi cũ: ô trống, đòi chọn lại)', () {
    expect(kemDanhMucDangGan(ds, dm('x', xoa: true), classify: 'chi'), same(ds));
    expect(kemDanhMucDangGan(ds, dm('x', nhom: true), classify: 'chi'), same(ds));
    expect(kemDanhMucDangGan(ds, dm('x', khuon: true), classify: 'chi'), same(ds));
    expect(kemDanhMucDangGan(ds, dm('x', classify: 'thu'), classify: 'chi'), same(ds));
  });
}
