/// Gói số TÍCH LUỸ của một câu hỏi ở bậc tool (spec 4b mục 3.3 / 3.5 / 3.6).
///
/// `extends GoiSo` là thứ giữ ba lớp chắn và thẻ số liệu **không đổi một dòng**:
/// `kiemSoNhieuGoi` / `kiemNhan` / `kiemGiong` / `theCuaCau` nhận `[goiTraCuu]`
/// y như nhận sáu gói dựng sẵn. Khác sáu gói kia, gói này **mutable**: mỗi lời
/// gọi tool `them()` hàng vào, và vòng lặp kiểm câu trên trạng thái hiện thời.
///
/// ⚠️ [daTraCuu] là chốt L1: chưa tool thật nào chạy thì không câu nào của mô
/// hình được hiện — kể cả câu không chứa chữ số, vì `kiemSo` mù với câu bịa
/// tên mà không có số. Tool trả 0 hàng (hay từ chối tham số) vẫn tính là đã
/// chạy: mô hình đã có dữ liệu thật trước mắt, dù dữ liệu ấy là "không có gì".
///
/// [mauCau] là bản liệt kê tất định — **mẫu câu thật** của bậc tool để L2/L3 rơi
/// về (trước đó màn Trợ lý AI chỉ có câu "chưa chắc"). Mọi số của nó nằm trong
/// chính gói nên nó tự qua `kiemSo` (ca test cùng tên với mọi gói khác).
library;

import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'nhan_xet.dart';

class GoiSoTraCuu extends GoiSo {
  final List<HangSoLieu> hang = [];
  final List<SoLieu> tongHop = [];
  final List<String> tenCongCuDaChay = [];

  @override
  String get man => 'tra_cuu';

  /// Tổng hợp TRƯỚC hàng: `chuoiTheoNhan` lấy mục đầu của mỗi nhãn, và mục tổng
  /// hợp không tên là thứ mẫu câu tra theo nhãn.
  @override
  List<SoLieu> get soLieu => [...tongHop, for (final h in hang) ...h.soLieu];

  bool get daTraCuu => tenCongCuDaChay.isNotEmpty;

  @override
  bool get thieuDuLieu => !daTraCuu;

  /// Gọi cho tool THẬT đã chạy — tool bịa tên không tới đây (vòng lặp trả lời
  /// mô hình bằng `{"loi": …}` mà không `them`).
  void them(String tenCongCu, KetQuaCongCu kq) {
    tenCongCuDaChay.add(tenCongCu);
    hang.addAll(kq.hang);
    tongHop.addAll(kq.tongHop);
  }

  @override
  NhanXet mauCau() {
    if (!daTraCuu) {
      return const NhanXet(
        cau: 'Chưa tra cứu được số liệu nào.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    if (hang.isEmpty && tongHop.isEmpty) {
      return const NhanXet(
        cau: 'Không tìm thấy dữ liệu khớp câu hỏi.',
        theSoLieu: [],
        muc: MucNhanXet.binhThuong,
      );
    }
    // Tên trước số, một hàng một vế — đúng thứ 4a đo được là mô hình cần đọc.
    final veHang = [
      for (final h in hang)
        '${h.ten}${h.trangThai == null ? '' : ' ${h.trangThai}'}: '
            '${h.soLieu.map((s) => '${s.nhan} ${s.chuoi}').join(', ')}',
    ];
    final veTong = [for (final s in tongHop) '${s.nhan}: ${s.chuoi}'];
    final cau = [
      if (veHang.isNotEmpty) '${veHang.join('; ')}.',
      if (veTong.isNotEmpty) '${veTong.join('; ')}.',
    ].join(' ');
    return NhanXet(
      cau: cau,
      theSoLieu: soLieu,
      muc: hang.any((h) => h.canhBao)
          ? MucNhanXet.canhBao
          : MucNhanXet.binhThuong,
    );
  }
}
