/// Tool `danh_sach_muc_tieu` — mục tiêu đang theo đuổi theo TÊN, đủ số kèm
/// NHỊP (spec bước 2 mục 3.6). Không tính gì: thứ tự từ `chiaMucTieu` (thứ tự
/// trang Mục tiêu), số từ `GoalEntity` và `goal_forecast.dart`.
///
/// ⚠️ KHÁC `GoiSoMucTieu` có chủ ý: khối Nhận xét chỉ in "cần thêm N ngày" khi
/// chậm (lúc đúng kế hoạch nó là tiếng ồn); tool trả lời câu hỏi THẲNG "bao giờ
/// đạt", nên luôn mang số ấy khi tính được. Số `null` là *chưa đủ căn cứ* và
/// bị bỏ hẳn — `?? 0` là bịa một lời hứa.
library;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_forecast.dart';
import '../../goal/domain/goal_grouping.dart';
import '../../goal/domain/goal_stats.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';

KetQuaCongCu hangMucTieu(List<GoalEntity> goals, {required DateTime now}) {
  final nhom = chiaMucTieu(goals);
  return KetQuaCongCu(
    hang: [
      for (final g in nhom.dangTheoDuoi.take(kToiDaMucMoiGoi)) _hang(g, now),
    ],
    tongHop: [
      soDem('Đang theo đuổi', nhom.dangTheoDuoi.length),
      soDem('Đã hoàn thành', nhom.daHoanThanh.length),
    ],
  );
}

HangSoLieu _hang(GoalEntity g, DateTime now) {
  final ten = g.name;
  final ngay = g.daysLeft(now);
  final quaHan = ngay < 0;
  final cham = g.isBehindSchedule(now);
  final ky = tenDonViKy(g.cycleTakeMoney);
  final duBao = duBaoHoanThanh(g, now);
  final canTich = tocDoKeHoach(g, now: now);
  final dangTich = tocDoThucTe(g, now);
  return HangSoLieu(
    ten: ten,
    trangThai: quaHan
        ? 'đã quá hạn'
        : cham
            ? 'chậm kế hoạch'
            : 'đúng kế hoạch',
    canhBao: quaHan || cham,
    soLieu: [
      soPhanTram('Tiến độ', g.progress * 100, ten: ten),
      soTien('Đã tích', g.currentAmount, ten: ten),
      soTien('Mục tiêu', g.targetAmount, ten: ten),
      soTien('Còn thiếu', g.remainingAmount, ten: ten),
      // Quá hạn thì "còn -3 ngày" không ai đọc; trạng thái đã nói thay.
      if (!quaHan) soNgay('Còn', ngay, ten: ten),
      if (duBao != null)
        soNgay(
          'Theo nhịp hiện tại cần thêm',
          duBao.difference(now).inDays,
          ten: ten,
        ),
      if (canTich != null) soTien('Cần tích mỗi $ky', canTich, ten: ten),
      if (dangTich != null) soTien('Đang tích mỗi $ky', dangTich, ten: ten),
    ],
  );
}
