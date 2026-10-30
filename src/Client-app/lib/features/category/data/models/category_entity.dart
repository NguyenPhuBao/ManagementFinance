import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart';

/// Entity danh mục — kiểu **duy nhất** từ repository trở lên (G88 gạch 3, đợt 3/4; spec `2026-10-15-entity-danh-muc-design.md` 4.1).
///
/// Ảnh **chỉ đọc** của hàng Drift `Category`: 14 trường = 19 cột − 5 cột cố ý không chép — `isLocalOnly`, `idhousehold` (lát 1 gia đình, 2026-10-28: truy vấn cá nhân bỏ hàng của nhà ở DAO nên Entity thường là hàng của danh sách cá nhân — `getById` cố ý không lọc (giới hạn quét 37); lát 2 mới đưa vào) và ba cột lỗi đồng bộ
/// `syncRetryCount` · `syncError` · `syncBlockedUntil` (của hàng đợi đẩy). `deletedAt` vào Entity từ 2026-10-27 (luật ẩn theo khuôn). `category_entity_test`
/// đếm cột bảng để canh. Không có `toCompanion`: mọi đường ghi danh mục đi qua `CategoryChildDraft` / `CategoryGroupDraft`
/// (`category_tree.dart`) → Companion trong `CategoryManagementRepositoryImpl`. Phép ánh xạ `fromDrift` ở đây là MỘT định nghĩa.
///
/// `Equatable` là bắt buộc, không phải tiện: `DropdownButton<CategoryEntity>` ở Thêm / Sửa hoá đơn so `value` với từng `item` bằng
/// `==` — hàng Drift so theo giá trị, Entity so theo danh tính thì dropdown mất lựa chọn mà không lỗi nào báo.
class CategoryEntity extends Equatable {
  final String id;
  final int idaccount;
  final String name;

  /// `'chi'` | `'thu'` | `'vay_no'` — `kCategoryClassifies` (`category/domain/category_classify.dart`).
  final String classify;
  final String icon;
  final String colour;

  /// Hàng khuôn toàn cục (`idaccount = 0`) — quy tắc 8 `CLAUDE.md`: không hiện ở danh sách nào, chỉ nuôi seeder và bảng tra tên.
  final bool isDefault;
  final bool isDeleted;

  /// Lúc xoá mềm. Hàng KHUÔN cần nó: luật *ẩn theo khuôn* (`ban_sao_mac_dinh.dart`) chỉ áp khuôn xoá từ `kMocAnTheoKhuon`
  /// (spec 2026-10-27 mục 3). Hàng của người dùng vẫn đọc [isDeleted].
  final DateTime? deletedAt;
  final String? parentId;
  final bool isGroup;

  /// Cờ *Cố định — AI không đề xuất cắt* (cục bộ, schema v24; không đi qua đồng bộ — quét 15).
  final bool aiCoDinh;
  final String syncStatus;
  final DateTime updatedAt;

  const CategoryEntity({
    required this.id,
    required this.idaccount,
    required this.name,
    required this.classify,
    this.icon = 'category',
    this.colour = '#4CAF50',
    this.isDefault = false,
    this.isDeleted = false,
    this.deletedAt,
    this.parentId,
    this.isGroup = false,
    this.aiCoDinh = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  factory CategoryEntity.fromDrift(Category c) => CategoryEntity(
        id: c.id,
        idaccount: c.idaccount,
        name: c.name,
        classify: c.classify,
        icon: c.icon,
        colour: c.colour,
        isDefault: c.isDefault,
        isDeleted: c.isDeleted,
        deletedAt: c.deletedAt,
        parentId: c.parentId,
        isGroup: c.isGroup,
        aiCoDinh: c.aiCoDinh,
        syncStatus: c.syncStatus,
        updatedAt: c.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        idaccount,
        name,
        classify,
        icon,
        colour,
        isDefault,
        isDeleted,
        deletedAt,
        parentId,
        isGroup,
        aiCoDinh,
        syncStatus,
        updatedAt,
      ];
}
