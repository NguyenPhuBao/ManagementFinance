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

  /// Giai đoạn 1 — chạy **TRƯỚC** chu kỳ đồng bộ đầu tiên.
  ///
  /// Chuyển dữ liệu đang trỏ vào hàng seed `cat_*` sang danh mục cá nhân, rồi
  /// xoá mềm hàng seed. Phải xong trước khi đồng bộ chạm vào, nếu không chu kỳ
  /// đầu tiên sẽ gặp dữ liệu dở dang.
  ///
  /// **Chỉ đụng tới máy thật sự còn hàng `cat_*`.** Máy sạch thì không tạo gì —
  /// đây là điểm khác so với bản trước 2026-09-04, và là bản vá cho G14: hàm
  /// này chạy trước lần pull đầu tiên, lúc CSDL cục bộ còn rỗng, nên tạo danh
  /// mục ở đây là **tạo mù**. Trên một máy mới, nó sinh ra đúng những bản trùng
  /// tên với bản đã có trên backend; đẩy lên thì hỏng vĩnh viễn và kéo cả engine
  /// vào giãn cách. Xem G14 trong `docs/CLIENT_APP_KNOWN_GAPS.md`.
  Future<void> convertLegacyRows(int idaccount) async {
    if (idaccount <= 0) return; // danh tính chỉ đến từ phiên đăng nhập
    final owned = await db.categoryDao.getNamesInUse(idaccount);

    for (final spec in specs) {
      final legacy = await db.categoryDao.getById(spec.legacyId);
      if (legacy == null || legacy.isDeleted) continue;

      // Chỉ tới đây mới cần một danh mục đích để trỏ vào — tạo mới là hợp lý
      // vì đã có dữ liệu thật đang trỏ vào hàng seed.
      //
      // Loại chính hàng seed ra khỏi tập ứng viên: nó cùng tên với `spec` nên
      // phép so tên sẽ khớp chính nó, và khi đó dữ liệu bị "chuyển" về đúng chỗ
      // cũ rồi hàng đó bị xoá mềm ngay sau — giao dịch kết thúc ở một danh mục
      // đã xoá. Bình thường hàng seed mang `isDefault = true` nên đã bị
      // `_findOwned` loại sẵn; điều kiện này canh trường hợp máy nào đó có nó ở
      // dạng danh mục riêng.
      final candidate = _findOwned(owned, spec, exceptId: spec.legacyId);
      final categoryId = candidate?.id ?? await _create(spec, idaccount);
      await _convertLegacyRow(spec, idaccount, categoryId);
    }
  }

  /// Giai đoạn 2 — chạy **SAU** khi pull xong.
  ///
  /// Tạo những danh mục mà tài khoản còn thiếu. Chờ tới sau pull vì lúc đó mới
  /// biết tài khoản thật sự đang có gì: 5 danh mục này có thể đã được một máy
  /// khác tạo và đẩy lên từ trước.
  Future<void> ensureMissing(int idaccount) async {
    if (idaccount <= 0) return;
    final owned = await db.categoryDao.getNamesInUse(idaccount);

    for (final spec in specs) {
      if (_findOwned(owned, spec) != null) continue;
      await _create(spec, idaccount);
    }
  }

  /// Danh mục **riêng của tài khoản** trùng tên với [spec], hoặc null.
  ///
  /// Cố ý loại danh mục mặc định: chúng không đẩy lên được, nên một danh mục
  /// mặc định cùng tên mà tính là "đã có" sẽ khiến tài khoản mãi mãi không có
  /// bản riêng — mà bản riêng mới là bản đồng bộ được.
  Category? _findOwned(
    List<Category> owned,
    PersonalCategorySpec spec, {
    String? exceptId,
  }) {
    final target = normalizeCategoryName(spec.name);
    for (final c in owned) {
      if (c.id == exceptId) continue;
      if (!c.isDefault && normalizeCategoryName(c.name) == target) return c;
    }
    return null;
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
