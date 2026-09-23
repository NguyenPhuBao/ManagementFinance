/// Adapter tool `danh_sach_muc_tieu`: đọc repository → `hangMucTieu`.
library;

import '../../goal/data/repositories/goal_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_muc_tieu.dart';
import '../domain/hang_so_lieu.dart';

class CongCuMucTieu implements CongCu {
  CongCuMucTieu(this.mucTieu);
  final GoalRepository mucTieu;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuMucTieu,
        moTa: 'Liệt kê các mục tiêu tiết kiệm đang theo đuổi theo TÊN, kèm trạng thái '
            '(đúng hay chậm kế hoạch, quá hạn), tiến độ, đã tích, số tiền mục tiêu, còn '
            'thiếu, còn bao nhiêu ngày tới hạn, theo nhịp tích luỹ hiện tại cần thêm bao '
            'nhiêu ngày, cần và đang tích mỗi kỳ. Gọi khi hỏi mục tiêu thế nào, bao giờ '
            'đạt, có kịp hạn không, mỗi tháng cần để dành bao nhiêu.',
        thamSo: {'type': 'object', 'properties': <String, dynamic>{}},
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    final goals = await mucTieu.watchGoals(idaccount).first;
    return hangMucTieu(goals, now: now);
  }
}
