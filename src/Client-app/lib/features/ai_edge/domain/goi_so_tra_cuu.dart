/// Gói số TÍCH LUỸ của một câu hỏi ở bậc tool (spec 4b mục 3.3 / 3.5 / 3.6;
/// bước 2b).
///
/// `extends GoiSo` là thứ giữ ba lớp chắn và thẻ số liệu **không đổi một dòng**:
/// `kiemSoNhieuGoi` / `kiemNhan` / `kiemGiong` / `theCuaCau` nhận `[goiTraCuu]`
/// y như nhận sáu gói dựng sẵn. Khác sáu gói kia, gói này **mutable**: mỗi lời
/// gọi tool `them()` kết quả vào, và vòng lặp kiểm câu trên trạng thái hiện thời.
///
/// ⚠️ [daTraCuu] là chốt L1: chưa lượt tool nào THÀNH CÔNG thì không câu nào của
/// mô hình được hiện — kể cả câu không chứa chữ số, vì `kiemSo` mù với câu bịa
/// tên mà không có số. Tool trả 0 hàng vẫn tính là đã tra cứu: 0 hàng thật là
/// dữ liệu thật. Nhưng lượt bị TỪ CHỐI thì KHÔNG (bước 2b, lật vế ấy của spec
/// 4b): lời từ chối nói "câu hỏi gửi tool bị hỏng", không nói "không có gì" — và
/// cổng D lần 1 đo được E2B đọc nó thành "không có dữ liệu" (bẫy 4.40).
///
/// ⚠️ [choHienChuMoHinh] là cổng hiện chữ của vòng lặp: có lượt thành công VÀ
/// không còn lời từ chối chưa gỡ. Lời từ chối được gỡ THEO THAM SỐ (spec 2b mục
/// 1.2 hàng 4): một lượt thành công SAU đó của CÙNG tool phải điền một trong
/// `thamSoGo` của nó. Gọi lại bằng cách BỎ tham số vẫn là chưa gỡ — nếu không,
/// mô hình bỏ bộ lọc sai, nhận kết quả rộng hơn, rồi nói như thể trả lời câu
/// hỏi hẹp ("các khoản chi cho danh mục abc: …").
///
/// [mauCau] là bản liệt kê tất định — **mẫu câu thật** của bậc tool để L1b / L2 /
/// L2b / L3 rơi về. Mọi số của nó nằm trong chính gói nên nó tự qua `kiemSo`.
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
import 'tham_so_mo_hinh.dart';

class GoiSoTraCuu extends GoiSo {
  final List<HangSoLieu> hang = [];
  final List<SoLieu> tongHop = [];

  /// Tên tool của các lượt THÀNH CÔNG — lượt bị từ chối không vào đây (bước 2b).
  final List<String> tenCongCuDaChay = [];

  /// Tên liên quan của MỌI lượt, kể cả lượt bị từ chối (tên thật trong lời từ
  /// chối và tên SAI mô hình vừa gõ) — bước 2, 2b.
  final List<String> tenLienQuan = [];

  /// Kết quả nguyên vẹn của từng lượt THÀNH CÔNG, theo thứ tự — nguồn của [mauCau].
  final List<KetQuaCongCu> _luot = [];

  /// Lời từ chối CHƯA gỡ, theo thứ tự xảy ra.
  final List<({String ten, KetQuaCongCu kq})> _tuChoi = [];

  @override
  String get man => 'tra_cuu';

  /// Tổng hợp TRƯỚC hàng: `chuoiTheoNhan` lấy mục đầu của mỗi nhãn, và mục tổng
  /// hợp không tên là thứ mẫu câu tra theo nhãn.
  @override
  List<SoLieu> get soLieu => [...tongHop, for (final h in hang) ...h.soLieu];

  /// Có ít nhất một lượt THÀNH CÔNG (kể cả 0 hàng).
  bool get daTraCuu => tenCongCuDaChay.isNotEmpty;

  @override
  bool get thieuDuLieu => !daTraCuu;

  /// Lời từ chối chưa gỡ, theo thứ tự — tên tool để vòng lặp ghi log.
  List<({String ten, KetQuaCongCu kq})> get tuChoiChuaGo =>
      List.unmodifiable(_tuChoi);

  /// Cổng hiện chữ của vòng lặp (spec 2b mục 2.3).
  bool get choHienChuMoHinh => daTraCuu && _tuChoi.isEmpty;

  /// Câu trung thực về phần chưa tra được — `null` khi không còn lời từ chối
  /// chưa gỡ. L2b nối nó sau các câu đã hiện.
  String? get cauChuaTraDuoc =>
      _tuChoi.isEmpty ? null : 'Chưa tra được phần còn lại: ${_lyDo()}.';

  /// Gọi cho tool THẬT đã chạy — tool bịa tên không tới đây (vòng lặp trả lời
  /// mô hình bằng `{"loi": …}` mà không `them`). [args] là tham số của chính lời
  /// gọi ấy: nó quyết định lượt thành công có gỡ lời từ chối trước đó không.
  /// Mặc định rỗng thì không gỡ gì — hỏng theo chiều an toàn.
  void them(
    String tenCongCu,
    KetQuaCongCu kq, {
    Map<String, dynamic> args = const {},
  }) {
    tenLienQuan.addAll(kq.tenLienQuan);
    if (kq.loi != null) {
      _tuChoi.add((ten: tenCongCu, kq: kq));
      return;
    }
    tenCongCuDaChay.add(tenCongCu);
    hang.addAll(kq.hang);
    tongHop.addAll(kq.tongHop);
    _luot.add(kq);
    _tuChoi.removeWhere((r) =>
        r.ten == tenCongCu &&
        r.kq.thamSoGo.any((p) => thamSoTen(args[p]) != null));
  }

  /// Mặc định (mọi `SoLieu.ten`) **cộng** tên liên quan của các lượt: tên danh
  /// mục / ví trong trạng thái của hàng giao dịch không gắn trên `SoLieu` nào,
  /// nhưng mẫu câu in chúng và mô hình được phép nêu chúng.
  @override
  Iterable<String> get tenDoiTuong => [...super.tenDoiTuong, ...tenLienQuan];

  /// Lý do của các lời từ chối chưa gỡ — theo thứ tự, bỏ bản trùng.
  String _lyDo() => {for (final r in _tuChoi) r.kq.choNguoiDung!}.join('; ');

  @override
  NhanXet mauCau() {
    if (!daTraCuu) {
      if (_tuChoi.isEmpty) {
        return const NhanXet(
          cau: 'Chưa tra cứu được số liệu nào.',
          theSoLieu: [],
          muc: MucNhanXet.thieuDuLieu,
        );
      }
      // L1b — mọi lời gọi bị từ chối. Câu nói về CÂU HỎI, không nói về dữ liệu:
      // "không tìm thấy" ở đây là đúng câu SAI C8 của cổng D lần 1 (bẫy 4.40).
      return NhanXet(
        cau: 'Chưa tra được số liệu cho câu này: ${_lyDo()}. '
            'Bạn thử hỏi lại cụ thể hơn.',
        theSoLieu: const [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final ghiChu = cauChuaTraDuoc;
    String noi(String cau) => ghiChu == null ? cau : '$cau $ghiChu';
    if (hang.isEmpty && tongHop.isEmpty) {
      // Mọi lượt THÀNH CÔNG đều rỗng — lúc này câu ấy đúng nghĩa.
      return NhanXet(
        cau: noi('Không tìm thấy dữ liệu khớp câu hỏi.'),
        theSoLieu: const [],
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
      cau: noi(cau),
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
