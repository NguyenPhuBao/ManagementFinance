import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/phan_tich_thu_tu_table.dart';

part 'thu_tu_khoi_dao.g.dart';

/// DAO của hai bảng thứ tự khối trang Phân tích (cục bộ, v29). Luật học chạy ở
/// tầng thuần (`deXuatDuaLen`); ở đây chỉ cộng dồn, đọc và ghi.
@DriftAccessor(tables: [PhanTichGiayXems, PhanTichThuTuPhanHois])
class ThuTuKhoiDao extends DatabaseAccessor<AppDatabase> with _$ThuTuKhoiDaoMixin {
  ThuTuKhoiDao(super.db);

  /// Cộng dồn [giayTheoCum] vào ngày [ngay], rồi dọn hàng có `ngay < xoaTruoc`
  /// — một giao tác.
  Future<void> congGiay(int idaccount, String ngay, Map<String, int> giayTheoCum,
      {required String xoaTruoc}) {
    return transaction(() async {
      for (final e in giayTheoCum.entries) {
        if (e.value <= 0) continue;
        await into(phanTichGiayXems).insert(
          PhanTichGiayXemsCompanion.insert(
              idaccount: idaccount, ngay: ngay, cum: e.key, giay: e.value),
          onConflict: DoUpdate(
            (cu) => PhanTichGiayXemsCompanion.custom(giay: cu.giay + Constant(e.value)),
            target: [phanTichGiayXems.idaccount, phanTichGiayXems.ngay, phanTichGiayXems.cum],
          ),
        );
      }
      await (delete(phanTichGiayXems)
            ..where((t) => t.idaccount.equals(idaccount) & t.ngay.isSmallerThanValue(xoaTruoc)))
          .go();
    });
  }

  Future<List<PhanTichGiayXem>> giayXemTu(int idaccount, String tuNgay) {
    return (select(phanTichGiayXems)
          ..where((t) => t.idaccount.equals(idaccount) & t.ngay.isBiggerOrEqualValue(tuNgay)))
        .get();
  }

  Future<List<PhanTichThuTuPhanHoi>> phanHoi(int idaccount) {
    return (select(phanTichThuTuPhanHois)
          ..where((t) => t.idaccount.equals(idaccount))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> ghiPhanHoi(PhanTichThuTuPhanHoisCompanion e) =>
      into(phanTichThuTuPhanHois).insert(e);
}
