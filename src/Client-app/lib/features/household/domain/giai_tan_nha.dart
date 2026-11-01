/// Hộp giải tán bước hai: gõ đúng tên nhà mới mở nút (spec 5.5).
library;

import '../../../core/category/category_name.dart';

/// So bằng `normalizeCategoryName`, GIỮ dấu: `removeVietnameseTones` là phép so mất thông tin (quy tắc 7).
bool tenGiaiTanKhop(String goTay, String tenNha) {
  final go = normalizeCategoryName(goTay);
  return go.isNotEmpty && go == normalizeCategoryName(tenNha);
}
