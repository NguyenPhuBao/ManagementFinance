import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/goi_y_phan_hoi_table.dart';

part 'goi_y_phan_hoi_dao.g.dart';

/// DAO của bảng phản hồi thẻ gợi ý danh mục (cục bộ, B1). Chỉ hai phép: ghi một hàng và đọc theo tài khoản — luật
/// thôi gợi ý / mở lại chạy ở tầng thuần (`tatCapTu`), không cần truy vấn phức tạp.
@DriftAccessor(tables: [GoiYDanhMucPhanHois])
class GoiYPhanHoiDao extends DatabaseAccessor<AppDatabase> with _$GoiYPhanHoiDaoMixin {
  GoiYPhanHoiDao(super.db);

  Future<void> ghi(GoiYDanhMucPhanHoisCompanion e) => into(goiYDanhMucPhanHois).insert(e);

  Future<List<GoiYDanhMucPhanHoi>> getAll(int idaccount) => (select(goiYDanhMucPhanHois)
        ..where((t) => t.idaccount.equals(idaccount))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
}
