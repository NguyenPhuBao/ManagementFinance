import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/danh_muc_ai_doan_table.dart';

part 'danh_muc_ai_doan_dao.g.dart';

/// DAO của bảng dấu "danh mục do AI chọn, lưu nguyên" (cục bộ, v31). Ba phép: đánh dấu, gỡ, đọc tập mã theo tài khoản.
@DriftAccessor(tables: [DanhMucAiDoans])
class DanhMucAiDoanDao extends DatabaseAccessor<AppDatabase> with _$DanhMucAiDoanDaoMixin {
  DanhMucAiDoanDao(super.db);

  /// Đánh dấu lại cùng giao dịch thì ghi đè (một giao dịch một dấu).
  Future<void> danhDau({required int idaccount, required String transactionId, required String categoryId}) =>
      into(danhMucAiDoans).insertOnConflictUpdate(DanhMucAiDoansCompanion.insert(
        transactionId: transactionId,
        idaccount: idaccount,
        categoryId: categoryId,
        createdAt: DateTime.now(),
      ));

  Future<void> go({required int idaccount, required String transactionId}) => (delete(danhMucAiDoans)
        ..where((t) => t.idaccount.equals(idaccount) & t.transactionId.equals(transactionId)))
      .go();

  Future<Set<String>> idsCua(int idaccount) async => {
        for (final h in await (select(danhMucAiDoans)..where((t) => t.idaccount.equals(idaccount))).get())
          h.transactionId,
      };
}
