/// Tool `danh_sach_muc_tieu` — mục tiêu đang theo đuổi theo TÊN, đủ số kèm
/// NHỊP (spec bước 2 mục 3.6). Không tính gì: thứ tự từ `chiaMucTieu` (thứ tự
/// trang Mục tiêu), số từ `GoalEntity` và `goal_forecast.dart`.
///
/// ⚠️ KHÁC `GoiSoMucTieu` có chủ ý: khối Nhận xét chỉ in "cần thêm N ngày" khi
/// chậm (lúc đúng kế hoạch nó là tiếng ồn); tool trả lời câu hỏi THẲNG "bao giờ
/// đạt", nên luôn mang số ấy khi tính được. Số `null` là *chưa đủ căn cứ* và
/// bị bỏ hẳn — `?? 0` là bịa một lời hứa.
///
/// [chon] (cổng E lần 1, E11 — mục 9.32): lọc theo trạng thái — `cham_ke_hoach` ·
/// `qua_han` · `dung_ke_hoach`. Hỏi *"mục tiêu nào chậm"* khi cả hai đều đúng kế
/// hoạch thì mô hình vẫn chỉ một tên (số thật nên lọt chắn); nay phép lọc về hàm
/// domain, 0 khớp là `rongTheoBoLoc` → mẫu câu *"không có mục tiêu nào khớp"*.
library;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_forecast.dart';
import '../../goal/domain/goal_grouping.dart';
import '../../goal/domain/goal_stats.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

/// Mã `chon` của tool mục tiêu — trạng thái, không phải tỉ lệ như ngân sách.
const List<String> kChonMucTieu = ['cham_ke_hoach', 'qua_han', 'dung_ke_hoach'];

/// Chữ trạng thái — cũng là `trangThai` của hàng, một định nghĩa.
const Map<String, String> kChuChonMucTieu = {
  'cham_ke_hoach': 'chậm kế hoạch',
  'qua_han': 'đã quá hạn',
  'dung_ke_hoach': 'đúng kế hoạch',
};

KetQuaCongCu hangMucTieu(
  List<GoalEntity> goals, {
  required DateTime now,
  String? chon,
}) {
  if (chon != null && !kChonMucTieu.contains(chon)) {
    return tuChoiGiaTri('chon', chon, kChonMucTieu);
  }
  final nhom = chiaMucTieu(goals);
  final khop = chon == null
      ? nhom.dangTheoDuoi
      : [for (final g in nhom.dangTheoDuoi) if (_maTrangThai(g, now) == chon) g];
  return KetQuaCongCu(
    hang: [for (final g in khop.take(kToiDaMucMoiGoi)) _hang(g, now)],
    tongHop: [
      soDem('Đang theo đuổi', nhom.dangTheoDuoi.length),
      soDem('Đã hoàn thành', nhom.daHoanThanh.length),
      if (chon != null) soDem('Số mục tiêu khớp', khop.length),
    ],
    boLoc: [if (chon != null) kChuChonMucTieu[chon]!],
    rongTheoBoLoc: chon != null && khop.isEmpty,
    doiTuongRong: 'mục tiêu',
  );
}

/// Quá hạn thắng chậm — cùng thứ tự với `trangThai` của hàng.
String _maTrangThai(GoalEntity g, DateTime now) => g.daysLeft(now) < 0
    ? 'qua_han'
    : g.isBehindSchedule(now)
        ? 'cham_ke_hoach'
        : 'dung_ke_hoach';

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
    trangThai: kChuChonMucTieu[_maTrangThai(g, now)],
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
