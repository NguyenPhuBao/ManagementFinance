/// Gói số của trang Mục tiêu — nhận xét **mục tiêu đầu tiên đang theo đuổi**
/// theo đúng thứ tự trang đang hiện (đã sắp theo ưu tiên ở cubit), chia nhóm
/// bằng `chiaMucTieu` để "đang theo đuổi" có một định nghĩa. Mọi con số từ
/// `GoalEntity`; lớp này không tính gì (test quét thứ 14).
library;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_grouping.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

class GoiSoMucTieu extends GoiSo {
  @override
  String get man => 'muc_tieu';

  /// `null` khi không có mục tiêu nào đang theo đuổi.
  final String? ten;

  /// Thang 0–100, đã kẹp như `GoalEntity.progress`.
  final double tienDo;
  final double conThieu;

  /// Âm khi đã quá hạn.
  final int ngayConLai;
  final bool chamKeHoach;

  @override
  final List<SoLieu> soLieu;

  GoiSoMucTieu._({
    required this.ten,
    required this.tienDo,
    required this.conThieu,
    required this.ngayConLai,
    required this.chamKeHoach,
    required this.soLieu,
  });

  factory GoiSoMucTieu.tu(List<GoalEntity> goals, {required DateTime now}) {
    final dang = chiaMucTieu(goals).dangTheoDuoi;
    if (dang.isEmpty) {
      return GoiSoMucTieu._(
        ten: null,
        tienDo: 0,
        conThieu: 0,
        ngayConLai: 0,
        chamKeHoach: false,
        soLieu: const [],
      );
    }
    final g = dang.first;
    final tienDo = g.progress * 100;
    final ngay = g.daysLeft(now);
    return GoiSoMucTieu._(
      ten: g.name,
      tienDo: tienDo,
      conThieu: g.remainingAmount,
      ngayConLai: ngay,
      chamKeHoach: g.isBehindSchedule(now),
      soLieu: [
        soPhanTram('Tiến độ', tienDo),
        soTien('Còn thiếu', g.remainingAmount),
        // Quá hạn thì "còn -12 ngày" là con số không ai đọc; câu nói "đã quá
        // hạn" thay cho nó.
        if (ngay >= 0) soNgay('Còn', ngay),
      ],
    );
  }

  @override
  bool get thieuDuLieu => ten == null;

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Chưa có mục tiêu nào đang theo đuổi.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = {for (final x in soLieu) x.nhan: x.chuoi};
    final quaHan = ngayConLai < 0;
    final duoi = quaHan
        ? 'đã quá hạn'
        : chamKeHoach
            ? 'chậm kế hoạch'
            : 'đúng kế hoạch';
    final veNgay = quaHan ? '' : ', còn ${s['Còn']}';
    return NhanXet(
      cau: '$ten: ${s['Tiến độ']}, còn thiếu ${s['Còn thiếu']}$veNgay; $duoi.',
      theSoLieu: soLieu,
      muc: (quaHan || chamKeHoach) ? MucNhanXet.canhBao : MucNhanXet.binhThuong,
    );
  }
}
