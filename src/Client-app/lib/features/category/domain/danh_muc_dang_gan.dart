/// Form SỬA giữ giá trị đang chọn — spec `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` mục 4.
library;

import '../../../core/sync/sync_payload_normalizer.dart';
import '../data/models/category_entity.dart';

/// Danh sách CHỌN [ds] + danh mục [dangGan] của mục đang sửa khi nó KHÔNG có trong [ds] — thực tế là bản sao đang ẩn theo
/// khuôn (danh sách chọn đã có mọi danh mục lá còn sống khác). `DropdownButton` văng (hoặc form rơi về "chưa chọn") khi
/// `value` không nằm trong `items`. Chỉ kèm danh mục còn sống, không nhóm, không khuôn, cùng [classify]; còn lại (đã xoá,
/// nhóm) giữ hành vi cũ: ô trống, đòi chọn lại.
List<CategoryEntity> kemDanhMucDangGan(List<CategoryEntity> ds, CategoryEntity? dangGan, {required String classify}) {
  if (dangGan == null || ds.any((c) => c.id == dangGan.id)) return ds;
  if (dangGan.isDefault || dangGan.isDeleted || dangGan.isGroup) return ds;
  if (!SyncPayloadNormalizer.sameCategoryClassify(dangGan.classify, classify)) return ds;
  return [...ds, dangGan];
}
