/// Nơi ghi / đọc phản hồi thẻ *"Gợi ý danh mục"* (B1, spec 2026-09-28 mục 3.3) — bảng cục bộ
/// `GoiYDanhMucPhanHois`, không đi qua đồng bộ.
///
/// Giao diện tách khỏi bản Drift để widget test của màn Thêm giao dịch tiêm một bản trong bộ nhớ, đúng khuôn
/// `viHayDung` / `boPhanLoai`.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/phan_loai_ghi_chu.dart';
import 'models/category_suggestion.dart';

abstract class GoiYPhanHoiStore {
  /// [ketQua] là một trong `kKetQuaGoiY*`. [chonCategoryId] `null` khi bỏ qua mà không lưu.
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  });

  Future<List<PhanHoiGoiY>> doc(int idaccount);
}

class GoiYPhanHoiStoreDrift implements GoiYPhanHoiStore {
  GoiYPhanHoiStoreDrift(this._db);
  final AppDatabase _db;

  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) =>
      _db.goiYPhanHoiDao.ghi(GoiYDanhMucPhanHoisCompanion.insert(
        id: const Uuid().v4(),
        idaccount: idaccount,
        createdAt: DateTime.now(),
        nguon: goiY.nguon,
        amTietChinh: goiY.amTietChinh,
        goiYCategoryId: goiY.categoryId,
        ketQua: ketQua,
        chonCategoryId: Value(chonCategoryId),
      ));

  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => [
        for (final h in await _db.goiYPhanHoiDao.getAll(idaccount))
          PhanHoiGoiY(
            nguon: h.nguon,
            amTietChinh: h.amTietChinh,
            goiYCategoryId: h.goiYCategoryId,
            ketQua: h.ketQua,
            createdAt: h.createdAt,
          ),
      ];
}
