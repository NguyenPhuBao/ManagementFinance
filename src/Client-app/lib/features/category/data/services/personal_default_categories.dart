import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_payload_normalizer.dart';

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

/// Đưa năm danh mục mà bộ mặc định của backend từng thiếu về đúng chỗ của chúng.
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
///
/// ## Chặng hai (2026-09-05): backend đã có chúng
///
/// Năm hàng ấy nay nằm trong bộ mặc định của backend (`Create_by = 1`,
/// `Is_default = true`), nên mỗi tài khoản không cần giữ bản riêng nữa.
/// [foldIntoBackendDefaults] gộp bản riêng vào bản mặc định rồi xoá mềm bản
/// riêng, và **không tạo mới bản nào** — thay hẳn cho `ensureMissing()` cũ.
///
/// Việc này cũng rút chân **G16**: danh mục mặc định là toàn cục, không thuộc
/// tài khoản nào, nên không còn gì để "mọc lại" ở mỗi lần mở app. Vòng lặp
/// tạo-đẩy-hỏng mà G16 mô tả không còn nguồn kích hoạt cho năm mục này.
///
/// Tên lớp giữ nguyên dù nghĩa đã lệch: [convertLegacyRows] vẫn tạo danh mục
/// riêng cho dữ liệu `cat_*` của bản client cũ, và đổi tên chỉ làm diff phình
/// ra mà không đổi hành vi nào.
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
  /// đây là điểm khác so với bản trước 2026-09-03, và là bản vá cho G14: hàm
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
  /// Gộp bản riêng của tài khoản vào bản mặc định tương ứng của backend: dời
  /// mọi tham chiếu sang bản mặc định, rồi **xoá mềm** bản riêng. Không tạo mới
  /// gì cả.
  ///
  /// Phải chờ tới sau pull vì bản mặc định chỉ có mặt ở máy này sau khi pull
  /// mang nó về.
  ///
  /// **Không thấy bản mặc định thì không đụng gì.** Backend chưa có hàng, hoặc
  /// pull hỏng — cả hai đều không phải lý do để xoá một danh mục người dùng
  /// đang dùng. Tạo bản riêng ở nhánh này cũng không: đó chính là thứ đang được
  /// gỡ bỏ.
  ///
  /// Gộp là thao tác **phá huỷ**, nên nó đòi khớp **cả tên lẫn classify**. Quy
  /// tắc trùng tên của dự án không tính classify (quy tắc 7), nên một danh mục
  /// do người dùng tự tạo hoàn toàn có thể trùng tên mà khác loại — gộp nó vào
  /// bản mặc định là âm thầm đổi loại của mọi giao dịch bên trong.
  Future<void> foldIntoBackendDefaults(int idaccount) async {
    if (idaccount <= 0) return; // danh tính chỉ đến từ phiên đăng nhập
    final rows = await db.categoryDao.getNamesInUse(idaccount);

    for (final spec in specs) {
      final macDinh = _findDefault(rows, spec);
      if (macDinh == null) continue;

      final rieng = _findOwned(rows, spec, idaccount: idaccount, matchClassify: true);
      if (rieng == null || rieng.id == macDinh.id) continue;

      // Dời TRƯỚC, xoá SAU. Đảo lại là lỗi 11.6: hàng bị xoá trước khiến
      // `getById()` trả null và giao dịch kẹt vĩnh viễn.
      await db.repointCategoryReferences(
        idaccount: idaccount,
        fromCategoryId: rieng.id,
        toCategoryId: macDinh.id,
      );
      await db.categoryDao.softDelete(rieng.id);
    }
  }

  /// Bản **mặc định** của [spec] đã có ở máy này, hoặc null.
  ///
  /// Chỉ có mặt sau khi pull mang nó về; `sync_engine` quy `is_default = true`
  /// thành `idaccount = 0` nên không lọc theo tài khoản ở đây.
  Category? _findDefault(List<Category> rows, PersonalCategorySpec spec) {
    final target = normalizeCategoryName(spec.name);
    for (final c in rows) {
      if (!c.isDefault) continue;
      if (normalizeCategoryName(c.name) != target) continue;
      if (!SyncPayloadNormalizer.sameCategoryClassify(c.classify, spec.classify)) {
        continue;
      }
      return c;
    }
    return null;
  }

  /// Danh mục **riêng của tài khoản** trùng tên với [spec], hoặc null.
  ///
  /// Cố ý loại danh mục mặc định: chúng không đẩy lên được, nên một danh mục
  /// mặc định cùng tên mà tính là "đã có" sẽ khiến tài khoản mãi mãi không có
  /// bản riêng — mà bản riêng mới là bản đồng bộ được.
  ///
  /// [idaccount] phải được truyền ở đường **gộp**: `getNamesInUse` trả cả hàng
  /// mặc định của mọi tài khoản, nên không lọc ở đây là gộp nhầm hàng của người
  /// khác. Đường chuyển đổi dữ liệu cũ không cần vì nó chỉ đọc chính máy này.
  ///
  /// [matchClassify] cũng chỉ bật ở đường gộp — xem [foldIntoBackendDefaults].
  Category? _findOwned(
    List<Category> owned,
    PersonalCategorySpec spec, {
    String? exceptId,
    int? idaccount,
    bool matchClassify = false,
  }) {
    final target = normalizeCategoryName(spec.name);
    for (final c in owned) {
      if (c.id == exceptId) continue;
      if (c.isDefault) continue;
      if (idaccount != null && c.idaccount != idaccount) continue;
      if (normalizeCategoryName(c.name) != target) continue;
      if (matchClassify &&
          !SyncPayloadNormalizer.sameCategoryClassify(c.classify, spec.classify)) {
        continue;
      }
      return c;
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
