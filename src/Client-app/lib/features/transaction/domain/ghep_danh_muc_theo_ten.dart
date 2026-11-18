/// Đổi nguồn danh mục của form (cá nhân ↔ nhà, spec 2026-11-16 quyết định 1): giữ danh mục đang chọn nếu bên đích có
/// danh mục CÙNG TÊN và CÙNG classify; không thì `null` (người dùng chọn lại). So tên bằng `normalizeCategoryName` —
/// định nghĩa duy nhất (quy tắc 7), KHÔNG bỏ dấu.
library;

import '../../../core/category/category_name.dart';
import '../../category/data/models/category_entity.dart';

CategoryEntity? ghepDanhMucTheoTen(CategoryEntity? dangChon, Iterable<CategoryEntity> dich) {
  if (dangChon == null) return null;
  final ten = normalizeCategoryName(dangChon.name);
  for (final c in dich) {
    if (c.classify == dangChon.classify && normalizeCategoryName(c.name) == ten) return c;
  }
  return null;
}
