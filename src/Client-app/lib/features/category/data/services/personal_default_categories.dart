import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';

/// Một danh mục mà **backend không có** trong bộ mặc định, nên ở client nó
/// thuộc về từng tài khoản thay vì là danh mục hệ thống.
class PersonalCategorySpec {
  const PersonalCategorySpec(this.legacyId, this.name, this.classify, this.icon, this.colour);
  final String legacyId;
  final String name;
  final String classify;
  final String icon;
  final String colour;
}

/// Tạo cho mỗi tài khoản những danh mục mà bộ mặc định của backend không có.
///
/// ## Vì sao tồn tại
///
/// Bộ danh mục mặc định hai phía từng lệch nhau: client seed 18 mục, backend
/// chỉ có 13, và **chỉ 10 mục khớp tên**. Danh mục mặc định thì KHÔNG được đẩy
/// lên backend, còn `_resolveCategoryId` lại ánh xạ chúng sang UUID của backend
/// **bằng cách so tên** — nên 5 mục dưới đây không tìm được bản UUID nào, trả
/// `null`, và mọi giao dịch dùng chúng bị hoãn đẩy VĨNH VIỄN mà không có lỗi
/// nào báo ra.
///
/// Cách xử lý: bỏ chúng khỏi bộ mặc định (client nay seed đúng 13 mục khớp
/// backend) và tạo lại thành **danh mục riêng của tài khoản**. Danh mục người
/// dùng thì có đồng bộ, nên chúng đẩy lên được bình thường — backend không phải
/// thêm gì.
///
/// Hai mục "Khác" là đường người dùng hay đi nhất khi không có mục nào hợp, và
/// `Trả nợ` / `Thu nợ` là một nửa nghiệp vụ vay nợ; xoá hẳn sẽ mất dữ liệu thật.
class PersonalDefaultCategories {
  PersonalDefaultCategories({required this.db, Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final Uuid _uuid;

  /// `legacyId` là id seed của bản client CŨ — dùng để nhận ra dữ liệu cần
  /// chuyển đổi trên máy đã cài từ trước.
  static const List<PersonalCategorySpec> specs = [
    PersonalCategorySpec('cat_other_chi', 'Chi khác', 'chi', 'more_horiz', '#9E9E9E'),
    PersonalCategorySpec('cat_other_thu', 'Thu khác', 'thu', 'more_horiz', '#4CAF50'),
    PersonalCategorySpec('cat_freelance', 'Làm thêm', 'thu', 'laptop', '#00BCD4'),
    PersonalCategorySpec('cat_repay', 'Trả nợ', 'vay_no', 'payment', '#795548'),
    PersonalCategorySpec('cat_collect', 'Thu nợ', 'vay_no', 'attach_money', '#4CAF50'),
  ];

  Future<void> ensureForAccount(int idaccount) async {
    if (idaccount <= 0) return; // danh tính chỉ đến từ phiên đăng nhập
    final owned = await db.categoryDao.getNamesInUse(idaccount);

    for (final spec in specs) {
      final target = normalizeCategoryName(spec.name);
      final existing = owned
          .where((c) =>
              !c.isDefault && normalizeCategoryName(c.name) == target)
          .toList();

      final categoryId = existing.isNotEmpty
          ? existing.first.id
          : await _create(spec, idaccount);

      await _convertLegacyRow(spec, idaccount, categoryId);
    }
  }

  Future<String> _create(PersonalCategorySpec spec, int idaccount) async {
    // UUID chứ không phải id dạng `cat_*`: `_resolveCategoryId` chỉ chấp nhận
    // danh mục người dùng có UUID hợp lệ, id dạng slug sẽ bị trả null và giao
    // dịch lại kẹt y như cũ.
    final id = _uuid.v4();
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: spec.name,
      classify: spec.classify,
      icon: Value(spec.icon),
      colour: Value(spec.colour),
      isDefault: const Value(false),
      isLocalOnly: const Value(false),
      syncStatus: const Value('pending'),
      updatedAt: DateTime.now(),
    ));
    return id;
  }

  /// Chuyển dữ liệu cũ trỏ vào hàng seed `cat_*` sang danh mục cá nhân mới.
  ///
  /// Repoint TRƯỚC, xoá mềm SAU — đảo lại chính là lỗi 11.6.
  Future<void> _convertLegacyRow(
    PersonalCategorySpec spec,
    int idaccount,
    String newCategoryId,
  ) async {
    final legacy = await db.categoryDao.getById(spec.legacyId);
    if (legacy == null || legacy.isDeleted) return;

    await db.repointCategoryReferences(
      idaccount: idaccount,
      fromCategoryId: spec.legacyId,
      toCategoryId: newCategoryId,
    );
    await db.categoryDao.softDelete(spec.legacyId);
  }
}
