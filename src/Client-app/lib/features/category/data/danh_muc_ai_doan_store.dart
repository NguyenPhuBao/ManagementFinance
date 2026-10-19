/// Nơi ghi / đọc dấu *"danh mục do AI chọn, lưu nguyên"* — bảng cục bộ `DanhMucAiDoans` (v31), không đi qua đồng bộ.
///
/// Người dùng chốt 2026-10-16 (vòng lặp học sai, mục 5d `CATEGORY_RATIONALE.md`): giao dịch MỚI có danh mục do Gemma chọn
/// (ô Nhập nhanh gõ / nói, ảnh quét) mà người dùng lưu nguyên thì đánh dấu; B1 bỏ chúng khỏi mẫu học; mở Sửa giao dịch
/// rồi Lưu là gỡ dấu. Giao diện tách khỏi bản Drift để test tiêm bản trong bộ nhớ — khuôn `GoiYPhanHoiStore`.
library;

import '../../../core/database/app_database.dart';

abstract class DanhMucAiDoanStore {
  Future<void> danhDau({required int idaccount, required String transactionId, required String categoryId});
  Future<void> go({required int idaccount, required String transactionId});

  /// Mã giao dịch mang dấu của [idaccount] — B1 bỏ chúng khỏi mẫu học.
  Future<Set<String>> idsCua(int idaccount);
}

class DanhMucAiDoanStoreDrift implements DanhMucAiDoanStore {
  DanhMucAiDoanStoreDrift(this._db);
  final AppDatabase _db;

  @override
  Future<void> danhDau({required int idaccount, required String transactionId, required String categoryId}) =>
      _db.danhMucAiDoanDao.danhDau(idaccount: idaccount, transactionId: transactionId, categoryId: categoryId);

  @override
  Future<void> go({required int idaccount, required String transactionId}) =>
      _db.danhMucAiDoanDao.go(idaccount: idaccount, transactionId: transactionId);

  @override
  Future<Set<String>> idsCua(int idaccount) => _db.danhMucAiDoanDao.idsCua(idaccount);
}
