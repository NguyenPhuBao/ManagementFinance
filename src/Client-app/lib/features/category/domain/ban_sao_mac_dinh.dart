import '../../../core/category/category_name.dart';
import '../data/models/category_entity.dart';
import '../../../core/sync/sync_payload_normalizer.dart';

/// Hàng [c] có phải **bản sao** của một danh mục khuôn trong [khuon] không — cùng tên chuẩn hoá
/// (`normalizeCategoryName`, quy tắc 7) VÀ cùng phân loại.
///
/// Một định nghĩa cho hai chỗ: phép đếm *danh mục riêng* của trần Premium (`premium/data/dem_dang_hoat_dong.dart` — bản
/// sao do bộ tạo bản sao tạo mang `isDefault: false` nhưng không phải thứ người dùng tự tạo, spec phân quyền 2026-10-08
/// mục 4.2) và luật ẩn `dangAnTheoKhuon` (cùng tệp). `DefaultCategorySeeder` KHÔNG dùng hàm này: từ 2026-10-27 nó so theo
/// TÊN (quy tắc 7; `uq_category_owner_name` chỉ có tên), còn hàm này nhận diện bản sao bằng tên + loại.
bool laBanSaoMacDinh(CategoryEntity c, List<CategoryEntity> khuon) {
  final ten = normalizeCategoryName(c.name);
  for (final mau in khuon) {
    if (normalizeCategoryName(mau.name) != ten) continue;
    if (SyncPayloadNormalizer.sameCategoryClassify(c.classify, mau.classify)) {
      return true;
    }
  }
  return false;
}

/// 00:00 giờ Việt Nam 2026-10-27 — chỉ khuôn bị xoá mềm TỪ mốc này mới làm bản sao ẩn (người dùng chốt 2026-10-27, spec
/// `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` mục 1 câu 5): khuôn bị lượt dọn về 13 mã ổn định xoá từ trước
/// không được làm danh mục của ai biến mất lúc cập nhật app.
final DateTime kMocAnTheoKhuon = DateTime.utc(2026, 10, 26, 17);

/// Bản sao [c] đang **ẩn theo khuôn** — admin xoá mềm khuôn của nó ở Admin-web (spec 2026-10-27 mục 3). MỘT định nghĩa cho
/// mọi danh sách CHỌN (`category/data/danh_sach_chon_danh_muc.dart`) và câu báo trùng tên; bảng TRA tên KHÔNG gọi hàm này.
///
/// Đúng khi: [c] là danh mục của tài khoản (không khuôn, chưa xoá, không nhóm); có khuôn đã xoá mềm từ [moc]
/// ([kMocAnTheoKhuon] khi vắng) cùng tên chuẩn hoá + loại ([laBanSaoMacDinh]); và KHÔNG khuôn còn sống nào khớp (admin xoá
/// rồi thêm lại cùng tên). Đổi tên bản sao → không còn khớp → hiện (chốt 2: đổi tên là thành danh mục của người dùng).
bool dangAnTheoKhuon(CategoryEntity c, List<CategoryEntity> khuon, {DateTime? moc}) {
  if (c.isDefault || c.isDeleted || c.isGroup) return false;
  final tu = moc ?? kMocAnTheoKhuon;
  final daXoa = [
    for (final k in khuon)
      if (k.isDefault && k.isDeleted && k.deletedAt != null && !k.deletedAt!.isBefore(tu)) k,
  ];
  if (!laBanSaoMacDinh(c, daXoa)) return false;
  return !laBanSaoMacDinh(c, [for (final k in khuon) if (k.isDefault && !k.isDeleted) k]);
}

/// Câu báo khi tên người dùng gõ trùng một bản sao đang ẩn (chốt 4) — thay câu chung *"Tên đã tồn tại"*, vốn khó hiểu vì
/// danh mục ấy đang không hiện ở đâu.
String cauTrungBanSaoDangAn(String ten) => '‘$ten’ là danh mục hệ thống đang tạm ngừng — hãy đặt tên khác.';
