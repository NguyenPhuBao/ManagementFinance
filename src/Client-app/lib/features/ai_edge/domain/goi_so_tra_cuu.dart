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
///
/// ⚠️ Mẫu câu viết **theo từng lượt gọi**, không phải một danh sách phẳng —
/// bẫy **4.35**, OnePlus bắt được ở chặng 4b (2026-09-23): E2B gọi
/// `chi_tieu_theo_ky` cho *tháng này*, *năm nay*, *tháng trước* rồi chạm trần
/// (L3), và bản phẳng in cả bộ hàng hai lần cùng *"Tổng chi: 2.141.000 đ …
/// Tổng chi: 0 đ"* — không số nào bịa, nhưng không nói số nào của kỳ nào nên
/// câu tự mâu thuẫn trước mắt người đọc. Nay mỗi nhóm mở đầu bằng **chữ kỳ**
/// (`chuThem['ky']`), và các lượt **cùng nội dung** gộp làm một nhóm với nhãn
/// kỳ ghép (*"Tháng này, năm nay — …"*).
library;

import 'dart:convert';

import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'nhan_xet.dart';

class GoiSoTraCuu extends GoiSo {
  final List<HangSoLieu> hang = [];
  final List<SoLieu> tongHop = [];
  final List<String> tenCongCuDaChay = [];

  /// Kết quả nguyên vẹn của từng lượt gọi, theo thứ tự — nguồn của [mauCau].
  final List<KetQuaCongCu> _luot = [];

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
    _luot.add(kq);
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
    // Gom lượt theo NỘI DUNG (hàng + tổng, bỏ chữ kỳ): hai kỳ cho cùng số liệu
    // là một nhóm hai nhãn, không phải hai lần kể lại.
    final nhom = <String, ({List<String> ky, KetQuaCongCu kq})>{};
    for (final kq in _luot) {
      if (kq.hang.isEmpty && kq.tongHop.isEmpty) continue;
      final noiDung = jsonEncode(Map.of(kq.json)..remove('ky'));
      final n = nhom.putIfAbsent(noiDung, () => (ky: <String>[], kq: kq));
      final ky = kq.chuThem['ky'];
      if (ky != null && !n.ky.contains(ky)) n.ky.add(ky);
    }
    final cau = [
      for (final n in nhom.values) _cauCuaNhom(n.ky, n.kq),
    ].join(' ');
    return NhanXet(
      cau: cau,
      theSoLieu: soLieu,
      muc: hang.any((h) => h.canhBao)
          ? MucNhanXet.canhBao
          : MucNhanXet.binhThuong,
    );
  }

  /// Một câu cho một nhóm: chữ kỳ (nếu có) rồi các vế. Tên trước số, một hàng
  /// một vế — đúng thứ 4a đo được là mô hình cần đọc.
  static String _cauCuaNhom(List<String> ky, KetQuaCongCu kq) {
    final ve = [
      for (final h in kq.hang)
        '${h.ten}${h.trangThai == null ? '' : ' ${h.trangThai}'}: '
            '${h.soLieu.map((s) => '${s.nhan} ${s.chuoi}').join(', ')}',
      for (final s in kq.tongHop) '${s.nhan}: ${s.chuoi}',
    ];
    final nhanKy = ky.join(', ');
    final tienTo = nhanKy.isEmpty
        ? ''
        : '${nhanKy[0].toUpperCase()}${nhanKy.substring(1)} — ';
    return '$tienTo${ve.join('; ')}.';
  }
}
