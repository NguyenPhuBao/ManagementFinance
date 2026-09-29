import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/goi_y_hoa_don_phan_hoi_table.dart';

part 'goi_y_hoa_don_dao.g.dart';

/// DAO của bảng phản hồi thẻ gợi ý hoá đơn từ khoản lặp (cục bộ, B2). Chỉ hai
/// phép: ghi một hàng và đọc theo tài khoản — luật ẩn / mở lại chạy ở tầng thuần
/// (`chonDeXuatHoaDon`), không cần truy vấn phức tạp.
@DriftAccessor(tables: [GoiYHoaDonPhanHois])
class GoiYHoaDonDao extends DatabaseAccessor<AppDatabase> with _$GoiYHoaDonDaoMixin {
  GoiYHoaDonDao(super.db);

  Future<void> ghi(GoiYHoaDonPhanHoisCompanion e) => into(goiYHoaDonPhanHois).insert(e);

  Future<List<GoiYHoaDonPhanHoi>> getAll(int idaccount) {
    return (select(goiYHoaDonPhanHois)
          ..where((t) => t.idaccount.equals(idaccount))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Bản `watch` của [getAll] — nguồn thứ tám của trang Phân tích (B4): tầng 3
  /// khối Dự báo bỏ các nhóm lặp đã thành hoá đơn, và người dùng có thể bấm
  /// *Tạo* trong khi trang ấy còn sống ở nhánh khác của shell.
  Stream<List<GoiYHoaDonPhanHoi>> watchAll(int idaccount) {
    return (select(goiYHoaDonPhanHois)
          ..where((t) => t.idaccount.equals(idaccount))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }
}
