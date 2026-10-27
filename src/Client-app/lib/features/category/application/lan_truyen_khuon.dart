import 'package:drift/drift.dart';

import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_payload_normalizer.dart';
import 'default_category_seeder.dart';

/// Việc của cổng `SyncEngine.sauKeoVe` cho mảng danh mục: lan truyền thay đổi khuôn TRƯỚC, tạo bản sao SAU — bản sao vừa đổi
/// tên chặn bộ tạo bản sao đẻ bản mang tên mới (spec 2026-10-27 mục 5). DI nối hàm này.
Future<int> viecSauKeoVeDanhMuc(
  LanTruyenKhuon lanTruyen,
  DefaultCategorySeeder seeder,
  int idaccount,
  List<ThayDoiKhuon> thayDoi,
) async =>
    await lanTruyen.apDung(idaccount, thayDoi) + await seeder.seedForAccount(idaccount);

/// Lan truyền thay đổi của danh mục KHUÔN (Admin-web sửa danh mục mặc định) sang **bản sao** của tài khoản — spec
/// `2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` mục 5.
///
/// Bản sao nhận ra bằng tên chuẩn hoá + loại CŨ (như `laBanSaoMacDinh`) — server không lưu mối nối bản sao ↔ khuôn. Đổi tên
/// áp cả bản ĐÃ XOÁ MỀM nhưng chỉ ghi cục bộ (⚠️ mục 5 bước 6: hàng xoá mà `pending` bị đẩy thành `delete`, server bỏ tên mới,
/// kéo về tên cũ đè lên); biểu tượng chỉ khi bản sao còn đúng biểu tượng cũ; từ khoá chỉ THÊM. Đổi loại không áp. Luỹ đẳng.
class LanTruyenKhuon {
  LanTruyenKhuon({required this.db, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

  /// Trả số hàng CHƯA XOÁ vừa đánh dấu `pending` (nơi gọi > 0 thì hẹn đẩy).
  Future<int> apDung(int idaccount, List<ThayDoiKhuon> thayDoi) async {
    if (idaccount <= 0 || thayDoi.isEmpty) return 0;
    var daGhi = 0;
    for (final d in thayDoi) {
      daGhi += await db.transaction(() => _apMot(idaccount, d));
    }
    return daGhi;
  }

  Future<int> _apMot(int idaccount, ThayDoiKhuon d) async {
    final now = _now();
    final daDanhDau = <String>{};
    bool khop(Category c, String ten) =>
        !c.isGroup &&
        SyncPayloadNormalizer.sameCategoryClassify(c.classify, d.loai) &&
        normalizeCategoryName(c.name) == normalizeCategoryName(ten);

    Future<void> ghi(Category c, CategoriesCompanion doi) async {
      final day = !c.isDeleted;
      await (db.update(db.categories)..where((t) => t.id.equals(c.id)))
          .write(day ? doi.copyWith(syncStatus: const Value('pending'), updatedAt: Value(now)) : doi);
      if (day) daDanhDau.add(c.id);
    }

    // 1. Đổi tên — kể cả bản đã xoá mềm (chỉ cục bộ).
    if (normalizeCategoryName(d.tenCu) != normalizeCategoryName(d.tenMoi)) {
      final hang = await db.categoryDao.getOwnedIncludingDeleted(idaccount);
      final tenMoiDaCo =
          hang.any((c) => !c.isDeleted && normalizeCategoryName(c.name) == normalizeCategoryName(d.tenMoi));
      if (!tenMoiDaCo) {
        for (final c in hang.where((c) => khop(c, d.tenCu))) {
          await ghi(c, CategoriesCompanion(name: Value(d.tenMoi)));
        }
      }
    }

    // 2–3. Biểu tượng, từ khoá — chỉ bản CHƯA XOÁ, khớp tên MỚI sau bước 1.
    final them = _tuKhoaThem(d);
    final song =
        (await db.categoryDao.getOwnedIncludingDeleted(idaccount)).where((c) => !c.isDeleted && khop(c, d.tenMoi));
    for (final c in song) {
      if (d.iconCu != d.iconMoi && c.icon == d.iconCu) {
        await ghi(c, CategoriesCompanion(icon: Value(d.iconMoi)));
      }
      if (them.isEmpty) continue;
      final coSan = await db.categoryDao.getKeywords(idaccount, c.id);
      final daCo = {for (final k in coSan) normalizeCategoryName(k)};
      final moi = [for (final k in them) if (!daCo.contains(normalizeCategoryName(k))) k];
      if (moi.isEmpty) continue;
      await db.categoryDao.replaceKeywords(accountId: idaccount, categoryId: c.id, keywords: [...coSan, ...moi], now: now);
      await ghi(c, const CategoriesCompanion());
    }

    // Hàng từ khoá của chính khuôn → bộ mới (bản sao tạo sau nhận bộ mới; lần so sau đúng).
    if (!_cungTap(d.tuKhoaCu, d.tuKhoaMoi)) {
      await db.categoryDao.replaceKeywords(accountId: idaccount, categoryId: d.id, keywords: d.tuKhoaMoi, now: now);
    }
    return daDanhDau.length;
  }

  static List<String> _tuKhoaThem(ThayDoiKhuon d) {
    final cu = {for (final k in d.tuKhoaCu) normalizeCategoryName(k)};
    final daLay = <String>{};
    return [
      for (final k in d.tuKhoaMoi)
        if (normalizeCategoryName(k).isNotEmpty && !cu.contains(normalizeCategoryName(k)) && daLay.add(normalizeCategoryName(k)))
          k,
    ];
  }

  static bool _cungTap(List<String> a, List<String> b) {
    final x = {for (final k in a) normalizeCategoryName(k)}..remove('');
    final y = {for (final k in b) normalizeCategoryName(k)}..remove('');
    return x.length == y.length && x.containsAll(y);
  }
}
