import '../../../core/database/app_database.dart';
import '../domain/vi_trung_ten.dart';

/// Chỗ đọc ví trùng tên (G63) — engine và giao diện cùng hỏi ở đây, để không
/// nơi nào đếm trên một tập khác (spec 2026-10-05 mục 4.4, bẫy 9). Luật ở
/// `wallet/domain/vi_trung_ten.dart`.
abstract class ViTrungTenNguon {
  /// Id các ví đang bị giữ (R) của [idaccount].
  Future<Set<String>> viDangBiGiu(int idaccount);
}

class ViTrungTenNguonImpl implements ViTrungTenNguon {
  ViTrungTenNguonImpl({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// Đọc `getAll` — MỌI ví chưa xoá, **kể cả lưu trữ**: index trùng tên của
  /// server không nhìn `Status`.
  @override
  Future<Set<String>> viDangBiGiu(int idaccount) async =>
      idViBiGiu(xetTuHang(await _db.walletDao.getAll(idaccount)));

  /// Hàng Drift → phần phép tìm cặp cần.
  static List<ViXetTrung> xetTuHang(Iterable<Wallet> vi) => [
        for (final w in vi)
          ViXetTrung(
            id: w.id,
            ten: w.name,
            biTuChoi: w.biTuChoiTrungTen,
            daXoa: w.deletedAt != null,
          ),
      ];
}
