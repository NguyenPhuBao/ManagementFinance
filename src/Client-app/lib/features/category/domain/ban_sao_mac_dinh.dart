import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_payload_normalizer.dart';

/// Hàng [c] có phải **bản sao** của một danh mục khuôn trong [khuon] không — cùng tên chuẩn hoá
/// (`normalizeCategoryName`, quy tắc 7) VÀ cùng phân loại.
///
/// Một định nghĩa cho hai chỗ: `DefaultCategorySeeder` (đã có bản sao thì không tạo nữa — luật đếm cả hàng đã xoá
/// mềm) và phép đếm *danh mục riêng* của trần Premium (bản sao do seeder tạo mang `isDefault: false` nhưng không phải
/// thứ người dùng tự tạo — spec phân quyền 2026-10-08 mục 4.2).
bool laBanSaoMacDinh(Category c, List<Category> khuon) {
  final ten = normalizeCategoryName(c.name);
  for (final mau in khuon) {
    if (normalizeCategoryName(mau.name) != ten) continue;
    if (SyncPayloadNormalizer.sameCategoryClassify(c.classify, mau.classify)) {
      return true;
    }
  }
  return false;
}
