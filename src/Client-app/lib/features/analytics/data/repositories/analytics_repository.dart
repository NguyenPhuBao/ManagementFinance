import '../../domain/pham_vi_ky.dart';
import '../models/thong_ke_ky.dart';

abstract class AnalyticsRepository {
  /// Phát lại mỗi khi giao dịch, danh mục **hoặc** ngân sách đổi.
  ///
  /// [now] tiêm được để test không phụ thuộc đồng hồ máy; nó quyết định mốc
  /// tra ngân sách của kỳ đang xem.
  Stream<ThongKeKy> watchKy(
    int idaccount, {
    required Ky ky,
    DateTime? now,
  });
}
