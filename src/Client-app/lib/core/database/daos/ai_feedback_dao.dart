import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ai_feedback_table.dart';

part 'ai_feedback_dao.g.dart';

/// DAO của bảng phản hồi tái phân bổ (cục bộ). Chỉ hai phép: ghi một hàng và
/// đọc theo tài khoản — Tầng 2 lọc theo ngân sách/kỳ ở tầng thuần
/// (`daBiCatHaiKyLienTruoc`), không cần truy vấn phức tạp.
@DriftAccessor(tables: [AiRebalancingFeedbacks])
class AiFeedbackDao extends DatabaseAccessor<AppDatabase>
    with _$AiFeedbackDaoMixin {
  AiFeedbackDao(super.db);

  Future<void> ghi(AiRebalancingFeedbacksCompanion e) =>
      into(aiRebalancingFeedbacks).insert(e);

  Future<List<AiRebalancingFeedback>> getAll(int idaccount) =>
      (select(aiRebalancingFeedbacks)
            ..where((t) => t.idaccount.equals(idaccount))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
}
