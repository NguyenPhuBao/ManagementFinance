/// Gói số của trang Mục tiêu — nhận xét **mục tiêu đầu tiên đang theo đuổi**
/// theo đúng thứ tự trang đang hiện (đã sắp theo ưu tiên ở cubit), chia nhóm
/// bằng `chiaMucTieu` để "đang theo đuổi" có một định nghĩa. Mọi con số từ
/// `GoalEntity`; lớp này không tính gì (test quét thứ 14).
library;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_forecast.dart';
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

  /// Số ngày còn cần **theo nhịp tích luỹ THẬT** (`duBaoHoanThanh`), hoặc
  /// `null` khi chưa đủ căn cứ: thiếu mốc gốc, chưa qua đủ nửa chu kỳ, chưa
  /// tích đồng nào, hay nhịp chậm tới mức ngày đạt vượt 100 năm.
  ///
  /// ⚠️ `null` nghĩa là **chưa biết**, và câu phải im hẳn về nó. Thay bằng một
  /// con số mặc định là bịa ra một lời hứa — cùng lỗi mà `thayDoiTaiSan` (mục
  /// 3.30 `ANALYTICS_FEATURE.md`) đã chặn.
  final int? ngayTheoNhip;

  @override
  final List<SoLieu> soLieu;

  GoiSoMucTieu._({
    required this.ten,
    required this.tienDo,
    required this.conThieu,
    required this.ngayConLai,
    required this.chamKeHoach,
    required this.ngayTheoNhip,
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
        ngayTheoNhip: null,
        soLieu: const [],
      );
    }
    final g = dang.first;
    final tienDo = g.progress * 100;
    final ngay = g.daysLeft(now);
    final cham = g.isBehindSchedule(now);

    // Dự báo theo nhịp THẬT — chỉ giữ khi nó nói thêm được điều gì. Mục tiêu
    // đang đúng kế hoạch mà vẫn in "cần thêm N ngày" thì đó là tiếng ồn: người
    // dùng đã biết mình ổn.
    final duBao = duBaoHoanThanh(g, now);
    final ngayTheoNhip = (cham || ngay < 0) && duBao != null
        ? duBao.difference(now).inDays
        : null;

    return GoiSoMucTieu._(
      ten: g.name,
      tienDo: tienDo,
      conThieu: g.remainingAmount,
      ngayConLai: ngay,
      chamKeHoach: cham,
      ngayTheoNhip: ngayTheoNhip,
      soLieu: [
        soPhanTram('Tiến độ', tienDo),
        soTien('Còn thiếu', g.remainingAmount),
        // Quá hạn thì "còn -12 ngày" là con số không ai đọc; câu nói "đã quá
        // hạn" thay cho nó.
        if (ngay >= 0) soNgay('Còn', ngay),
        if (ngayTheoNhip != null) soNgay('Theo nhịp hiện tại', ngayTheoNhip),
      ],
    );
  }

  @override
  bool get thieuDuLieu => ten == null;

  /// Tên mục tiêu có trong mẫu câu mà không nằm trên [SoLieu] nào — gắn nó lên
  /// [SoLieu] thì `kiemNhan` đòi mọi câu phải nêu tên, đổi luật của gói này.
  @override
  Iterable<String> get tenDoiTuong => [
        ...super.tenDoiTuong,
        if (ten != null) ten!,
      ];

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Chưa có mục tiêu nào đang theo đuổi.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = chuoiTheoNhan(soLieu);
    final quaHan = ngayConLai < 0;
    final duoi = quaHan
        ? 'đã quá hạn'
        : chamKeHoach
            ? 'chậm kế hoạch'
            : 'đúng kế hoạch';
    final veNgay = quaHan ? '' : ', còn ${s['Còn']}';
    // Vế dự báo đứng CUỐI, thành câu riêng: nó trả lời *chậm bao nhiêu*, thứ
    // "chậm kế hoạch" một mình không nói được.
    final veDuBao = ngayTheoNhip == null
        ? ''
        : ' Theo nhịp hiện tại cần thêm ${s['Theo nhịp hiện tại']}.';
    return NhanXet(
      cau: '$ten: ${s['Tiến độ']}, còn thiếu ${s['Còn thiếu']}$veNgay; '
          '$duoi.$veDuBao',
      theSoLieu: soLieu,
      muc: (quaHan || chamKeHoach) ? MucNhanXet.canhBao : MucNhanXet.binhThuong,
    );
  }
}
