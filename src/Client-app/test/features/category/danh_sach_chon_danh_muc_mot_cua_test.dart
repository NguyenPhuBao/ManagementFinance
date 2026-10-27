/// Test quét `lib/` thứ **40** (2026-10-27): danh sách để CHỌN danh mục có MỘT cửa — `danh_sach_chon_danh_muc.dart`, nơi
/// bỏ bản sao đang ẩn theo khuôn (spec `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` mục 4). Gọi thẳng
/// `getCategoryRows` / `watchCategoryRows` ở chỗ khác là một bộ chọn mới đi vòng qua luật ẩn — admin xoá danh mục hệ thống mà
/// nó vẫn hiện ở đúng bộ chọn ấy, không lỗi nào báo.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _choPhep = {
  'lib/core/database/daos/category_dao.dart',
  'lib/features/category/data/danh_sach_chon_danh_muc.dart',
};

final _mau = RegExp(r'\b(getCategoryRows|watchCategoryRows)\s*\(');

void main() {
  test('đối chứng dương: mẫu bắt được lời gọi thật trong cửa', () {
    expect(_mau.hasMatch(File('lib/features/category/data/danh_sach_chon_danh_muc.dart').readAsStringSync()), isTrue,
        reason: 'mẫu không khớp lời gọi thật thì quét dưới xanh vì mù');
  });

  test('ngoài DAO và cửa không chỗ nào gọi getCategoryRows / watchCategoryRows', () {
    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final tep = f.path.replaceAll(r'\', '/');
      if (_choPhep.contains(tep)) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        if (_mau.hasMatch(dong[i])) viPham.add('$tep:${i + 1}');
      }
    }
    expect(viPham, isEmpty,
        reason: 'Danh sách chọn phải qua hangChonDuoc / theoDoiHangChonDuoc (bỏ bản sao ẩn theo khuôn)');
  });
}
