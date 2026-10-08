/// Gói số của trang Phân tích — đọc `ThongKeKy` qua đúng các hàm trang đang
/// dùng: `phanTramSoVoi` (null khi nền bằng 0), `thuNhapCua` + `tyLeTietKiem`
/// (đúng biểu thức của `_TheConLai`), `duBao`, `topChi`.
///
/// ⚠️ Câu **không** chứa nhãn kỳ (`T9 2026`) hay tiêu đề khoản chi: chúng mang
/// chữ số không nằm trong gói, và bộ kiểm số sẽ chặn chính câu mẫu. Đó là lý
/// do câu mở đầu bằng "Kỳ này" — xem bẫy ở `docs/AI_EDGE_FEATURE.md`.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/dong_tien_tu_do.dart';
import '../../analytics/domain/thong_ke_thang.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

class GoiSoPhanTich extends GoiSo {
  @override
  String get man => 'phan_tich';

  final double tongChi;
  final double tongThu;

  /// Phần trăm so kỳ trước, thang 0–100 có dấu; `null` khi nền bằng 0.
  final double? soKyTruoc;

  /// Tỉ lệ tiết kiệm thang 0–100; `null` khi thu nhập không dương hoặc chưa có
  /// chuỗi vay/nợ.
  final double? deDanh;

  /// G56: chi gấp bao nhiêu lần thu nhập — chỉ có khi ≥ 2 lần
  /// (`soLanChiGapThuNhap`, đã làm tròn như sẽ in); khi ấy câu nói *"chi gấp N
  /// lần thu nhập"* thay cho phần trăm vượt.
  final double? gapLan;

  /// Tổng cam kết 30 ngày tới và số cam kết; `null` khi không có dự báo hoặc
  /// không có cam kết nào.
  final double? tongCamKet;
  final int soCamKet;

  final double? khoanChiLonNhat;

  /// B3: tên danh mục chi bất thường đứng ĐẦU (phần vượt lớn nhất); `null` khi
  /// không có — hoặc kỳ không phải Tháng (repository không xét).
  final String? tenBatThuong;

  @override
  final List<SoLieu> soLieu;

  GoiSoPhanTich._({
    required this.tongChi,
    required this.tongThu,
    required this.soKyTruoc,
    required this.deDanh,
    this.gapLan,
    required this.tongCamKet,
    required this.soCamKet,
    required this.khoanChiLonNhat,
    required this.soLieu,
    this.tenBatThuong,
    this.chuKy,
    List<SoLieu> theoKy = const [],
    SoLieu? soKyTruocMuc,
  })  : _theoKy = theoKy,
        _soKyTruoc = soKyTruocMuc;

  /// Chữ kỳ của gói (*tháng này*) — chỉ `NguonGoiSo` của trợ lý truyền; khối
  /// Nhận xét trang Phân tích dựng gói cho MỌI kỳ đang xem nên không truyền.
  final String? chuKy;
  final List<SoLieu> _theoKy;
  final SoLieu? _soKyTruoc;

  /// [boChiBatThuong] — tài khoản không có quyền `anomaly_spending_insights` (spec phân quyền 2026-10-08): gói bỏ hẳn
  /// mục chi bất thường, trang Phân tích hiện dòng khoá thay vào.
  factory GoiSoPhanTich.tu(ThongKeKy tk,
      {String? chuKy, bool boChiBatThuong = false}) {
    final pt = phanTramSoVoi(tk.tong.chi, tk.tongTruoc.chi);
    // Đúng biểu thức của `_TheConLai` (analytics_page.dart): chuỗi vay/nợ rỗng
    // thì bỏ qua chứ không coi như không có vay/nợ.
    final double? thuNhap = tk.chuoiVayNo.isEmpty
        ? null
        : thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last);
    final double? tyLe = thuNhap == null
        ? null
        : tyLeTietKiem(thuNhap: thuNhap, chi: tk.tong.chi);
    final deDanh = tyLe == null ? null : tyLe * 100;
    // G56: từ 2 lần thu nhập trở lên nói "gấp N lần" — cùng hàm với thẻ Số dư
    // còn lại và tool tổng quan.
    final gapLan = thuNhap == null
        ? null
        : soLanChiGapThuNhap(thuNhap: thuNhap, chi: tk.tong.chi);
    final duBao = tk.duBao;
    final coCamKet = duBao != null && duBao.camKet.isNotEmpty;
    final lonNhat = tk.topChi.isEmpty ? null : tk.topChi.first.soTien;

    // Chặng 4a: top danh mục chi, mang TÊN. Câu 8 của bảng đo — "chi nhiều
    // nhất vào danh mục nào" — nhận về `Khoản lớn nhất`, một con số của **giao
    // dịch**; người hỏi muốn tên **danh mục**, hai thứ khác nhau.
    //
    // `tk.danhMuc` đã giảm dần theo số tiền và đã tra sẵn tên, nên lớp này chỉ
    // chép — không sắp lại, không cộng trừ (test quét thứ 14).
    final theoDanhMuc = <SoLieu>[
      for (final d in tk.danhMuc.take(kToiDaMucMoiGoi))
        // Cùng khuôn hàng của tool tổng kết: xung đột "Thu" (bẫy 4.42).
        soTien('Chi', d.soTien, ten: d.ten, nhanXungDot: const ['Thu']),
    ];

    final tongChiS = soTien('Tổng chi', tk.tong.chi);
    final tongThuS = soTien('Tổng thu', tk.tong.thu);
    final soKyTruocS = pt == null ? null : soPhanTram('So kỳ trước', pt.abs());
    // Tỉ lệ ÂM (chi vượt thu nhập) đổi nhãn và lấy trị tuyệt đối: câu
    // "để dành -30,0%" không ai hiểu, còn "chi vượt thu nhập 30,0%" thì có. Từ
    // 2 lần thu nhập (G56) phần trăm cũng hết đọc được ("26360,0%") nên con số
    // là "gấp N lần".
    final deDanhS = deDanh == null
        ? null
        : deDanh >= 0
            ? soPhanTram('Để dành', deDanh)
            : gapLan != null
                ? soLan('Gấp thu nhập', gapLan)
                : soPhanTram('Vượt thu nhập', -deDanh);
    final lonNhatS = lonNhat == null ? null : soTien('Khoản lớn nhất', lonNhat);

    // B3: chi bất thường theo danh mục — repository đã tính (trung vị + MAD ở
    // `analytics/domain/chi_bat_thuong.dart`); lớp này chỉ CHÉP số của dòng
    // đầu, không tính gì (test quét 14). Nhãn chứa chữ "chi" nên khai cùng
    // xung đột "Thu" với mục Chi theo danh mục (bẫy 4.42).
    final bt = boChiBatThuong ? const <DongChiBatThuong>[] : (tk.chiBatThuong ?? const []);
    final dau = bt.isEmpty ? null : bt.first;
    final chiBtS = dau == null
        ? null
        : soTien('Chi bất thường', dau.d.chi,
            ten: dau.ten, nhanXungDot: const ['Thu']);
    final thuongLeS =
        dau == null ? null : soTien('Thường lệ', dau.d.thuongLe, ten: dau.ten);
    final soBtS =
        bt.length > 1 ? soDem('Số danh mục khác bất thường', bt.length - 1) : null;
    return GoiSoPhanTich._(
      chuKy: chuKy,
      tenBatThuong: dau?.ten,
      // Số CỦA KỲ; cam kết là 30 ngày tới — không vào đây (G5 (b) cổng F).
      theoKy: [
        tongChiS,
        tongThuS,
        if (deDanhS != null) deDanhS,
        if (lonNhatS != null) lonNhatS,
        // B3: số của THÁNG đang xét. "Thường lệ" (trung vị các tháng TRƯỚC) và
        // số danh mục khác không thuộc kỳ nào — gán kỳ là `kiemKy` chặn câu đúng.
        if (chiBtS != null) chiBtS,
        ...theoDanhMuc,
      ],
      soKyTruocMuc: soKyTruocS,
      tongChi: tk.tong.chi,
      tongThu: tk.tong.thu,
      soKyTruoc: pt,
      deDanh: deDanh,
      gapLan: gapLan,
      tongCamKet: coCamKet ? duBao.tongCamKet : null,
      soCamKet: coCamKet ? duBao.camKet.length : 0,
      khoanChiLonNhat: lonNhat,
      soLieu: [
        tongChiS,
        tongThuS,
        if (soKyTruocS != null) soKyTruocS,
        if (deDanhS != null) deDanhS,
        if (coCamKet) ...[
          soTien('Cam kết', duBao.tongCamKet),
          soDem('Số cam kết', duBao.camKet.length),
        ],
        if (lonNhatS != null) lonNhatS,
        if (chiBtS != null) chiBtS,
        if (thuongLeS != null) thuongLeS,
        if (soBtS != null) soBtS,
        // Đặt CUỐI: mẫu câu tra mục theo nhãn, các mục tổng hợp phải gặp trước.
        ...theoDanhMuc,
      ],
    );
  }

  @override
  bool get thieuDuLieu => tongChi == 0 && tongThu == 0;

  /// G5 (b) cổng F: số của kỳ → {chuKy}; so kỳ trước → cả kỳ trước; cam kết
  /// 30 ngày tới → `null`. Không [chuKy] → không xét.
  @override
  Set<String>? kyCua(SoLieu s) {
    final k = chuKy;
    if (k == null) return null;
    if (identical(s, _soKyTruoc)) return {k, if (k == 'tháng này') 'tháng trước'};
    return _theoKy.contains(s) ? {k} : null;
  }

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Kỳ này chưa có giao dịch để nhận xét.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = chuoiTheoNhan(soLieu);
    final b = StringBuffer('Kỳ này chi ${s['Tổng chi']}');
    final pt = soKyTruoc;
    if (pt != null) {
      b.write(
          ', ${pt >= 0 ? 'tăng' : 'giảm'} ${s['So kỳ trước']} so với kỳ trước');
    }
    final dd = deDanh;
    if (dd != null) {
      b.write(dd >= 0
          ? '; để dành ${s['Để dành']} thu nhập'
          : gapLan != null
              ? '; chi gấp ${s['Gấp thu nhập']} lần thu nhập'
              : '; chi vượt thu nhập ${s['Vượt thu nhập']}');
    }
    b.write('.');
    if (tongCamKet != null) {
      b.write(' Một tháng tới có ${s['Số cam kết']} cam kết phải trả, '
          'tổng ${s['Cam kết']}.');
    }
    if (khoanChiLonNhat != null) {
      b.write(' Khoản chi lớn nhất ${s['Khoản lớn nhất']}.');
    }
    // B3. Nói "kỳ này", KHÔNG nêu tên tháng: chữ số của nhãn kỳ không nằm
    // trong gói và bộ kiểm số sẽ chặn chính câu mẫu (cùng lý do câu mở đầu).
    final tenBt = tenBatThuong;
    if (tenBt != null) {
      b.write(' Riêng $tenBt kỳ này đã chi ${s['Chi bất thường']}, '
          'cao hơn hẳn mức thường lệ ${s['Thường lệ']}.');
      final khac = s['Số danh mục khác bất thường'];
      if (khac != null) {
        b.write(' Thêm $khac danh mục khác cũng cao bất thường.');
      }
    }
    return NhanXet(
      cau: b.toString(),
      theSoLieu: soLieu,
      muc: tongChi > tongThu || tenBt != null
          ? MucNhanXet.canhBao
          : MucNhanXet.binhThuong,
    );
  }
}
