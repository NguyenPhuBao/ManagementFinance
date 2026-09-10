import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_payload_normalizer.dart';

/// Tạo cho mỗi tài khoản một **bản sao riêng** của bộ danh mục mặc định.
///
/// ## Vì sao có lớp này
///
/// Trước 2026-09-07 mọi tài khoản dùng chung 18 hàng mặc định của backend
/// (`Is_default = true`, `Create_by = 1`). Chúng **không đồng bộ** và không
/// thuộc về ai, nên người dùng không sửa, không đổi tên, không xoá được.
///
/// Nay mỗi tài khoản có bản của riêng mình; bản mặc định chỉ còn là **khuôn**.
/// Thiết kế đầy đủ:
/// `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.
///
/// ## Luật
///
/// Với **mỗi** danh mục mặc định: nếu tài khoản **chưa từng** có danh mục riêng
/// nào cùng (tên chuẩn hoá, `classify`) — **tính cả hàng đã xoá mềm** — thì tạo
/// một bản.
///
/// ⚠️ Ba chữ "kể cả đã xoá" là khác biệt **duy nhất** với `ensureMissing()` cũ,
/// thứ đã sinh ra **G16**: nó chỉ nhìn hàng đang sống, nên xoá một danh mục là
/// nó mọc lại ở mỗi lần mở app, và mỗi lần mọc lại là một thao tác đẩy hỏng
/// vĩnh viễn. Ai "dọn dẹp" điều kiện ấy sẽ tái hiện nguyên vẹn G16.
///
/// ⚠️ Hàm này chạy sau **mọi** lần pull, không phải một lần trong đời — đó là
/// cách một danh mục mặc định thêm về sau tới được tài khoản đã seed. Vì thế
/// tính luỹ đẳng là thứ tuyệt đối không được làm hỏng.
class DefaultCategorySeeder {
  DefaultCategorySeeder({required this.db, String Function()? sinhId})
      : _sinhId = sinhId ?? (() => const Uuid().v4());

  final AppDatabase db;
  final String Function() _sinhId;

  /// Trả **số bản sao đã tạo**. Nơi gọi dùng số này để ghi nhật ký.
  ///
  /// Cố ý **không** nuốt lỗi: bản mặc định đã bị ẩn khỏi mọi danh sách, nên một
  /// lượt seed hỏng trong im lặng nghĩa là người dùng mở app ra thấy danh sách
  /// danh mục rỗng và không ghi nổi một giao dịch, mà không ai biết vì sao.
  /// Luật ở trên vốn luỹ đẳng nên lần mở app sau tự thử lại.
  Future<int> seedForAccount(int idaccount) async {
    if (idaccount <= 0) return 0; // danh tính chỉ đến từ phiên đăng nhập

    final khuon = await db.categoryDao.getBackendDefaults();
    // Chưa pull được bộ mặc định thì KHÔNG đoán. Tạo danh mục khi CSDL cục bộ
    // chưa đáng tin chính là G14.
    if (khuon.isEmpty) return 0;

    final daCo = await db.categoryDao.getOwnedIncludingDeleted(idaccount);
    var daTao = 0;

    for (final mau in khuon) {
      if (_daCoBanSao(daCo, mau)) continue;

      // UUID chứ không phải slug: `_resolveCategoryId` chỉ chấp nhận danh mục
      // người dùng khi id là UUID hợp lệ, id dạng slug sẽ bị trả null và giao
      // dịch kẹt vĩnh viễn.
      final id = _sinhId();
      final bayGio = DateTime.now();

      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: id,
        idaccount: idaccount,
        name: mau.name,
        classify: mau.classify,
        icon: Value(mau.icon),
        colour: Value(mau.colour),
        isDefault: const Value(false),
        // Cố ý KHÔNG kế thừa nhóm: `CategoryGroupMemberships` không đồng bộ
        // được (G10), nên chép nhóm là chép một thứ vốn đã không đi đâu.
        parentId: const Value(null),
        isLocalOnly: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: bayGio,
      ));

      final tuKhoa = await db.categoryDao.getKeywords(idaccount, mau.id);
      if (tuKhoa.isNotEmpty) {
        await db.categoryDao.replaceKeywords(
          accountId: idaccount,
          categoryId: id,
          keywords: tuKhoa,
          now: bayGio,
        );
      }

      // Dời TRƯỚC, ẩn SAU. Bản mặc định sắp biến mất khỏi mọi danh sách; dữ
      // liệu còn trỏ vào nó sẽ thành mồ côi — người dùng mở giao dịch cũ ra
      // thấy một danh mục không còn tồn tại với họ. Đảo thứ tự này chính là
      // lỗi 11.6, và dự án đã dính nó một lần.
      await db.repointCategoryReferences(
        idaccount: idaccount,
        fromCategoryId: mau.id,
        toCategoryId: id,
      );

      daTao++;
    }

    return daTao;
  }

  /// Tài khoản đã **từng** có bản sao của [mau] chưa.
  ///
  /// "Từng" chứ không phải "đang có": [daCo] cố ý bao gồm cả hàng đã xoá mềm.
  ///
  /// So **cả tên lẫn `classify`**: hai thứ cùng tên khác loại là hai khái niệm
  /// khác nhau, và `uq_category_owner_name_classify` phía CSDL cũng cho chúng
  /// cùng tồn tại.
  bool _daCoBanSao(List<Category> daCo, Category mau) {
    final ten = normalizeCategoryName(mau.name);
    for (final c in daCo) {
      if (normalizeCategoryName(c.name) != ten) continue;
      if (!SyncPayloadNormalizer.sameCategoryClassify(
        c.classify,
        mau.classify,
      )) {
        continue;
      }
      return true;
    }
    return false;
  }
}
