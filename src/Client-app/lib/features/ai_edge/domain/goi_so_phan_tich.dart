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

  /// Tổng cam kết 30 ngày tới và số cam kết; `null` khi không có dự báo hoặc
  /// không có cam kết nào.
  final double? tongCamKet;
  final int soCamKet;

  final double? khoanChiLonNhat;

  @override
  final List<SoLieu> soLieu;

  GoiSoPhanTich._({
    required this.tongChi,
    required this.tongThu,
    required this.soKyTruoc,
    required this.deDanh,
    required this.tongCamKet,
    required this.soCamKet,
    required this.khoanChiLonNhat,
    required this.soLieu,
  });

  factory GoiSoPhanTich.tu(ThongKeKy tk) {
    final pt = phanTramSoVoi(tk.tong.chi, tk.tongTruoc.chi);
    // Đúng biểu thức của `_TheConLai` (analytics_page.dart): chuỗi vay/nợ rỗng
    // thì bỏ qua chứ không coi như không có vay/nợ.
    final double? tyLe = tk.chuoiVayNo.isEmpty
        ? null
        : tyLeTietKiem(
            thuNhap: thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last),
            chi: tk.tong.chi,
          );
    final deDanh = tyLe == null ? null : tyLe * 100;
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
        soTien('Chi', d.soTien, ten: d.ten),
    ];

    return GoiSoPhanTich._(
      tongChi: tk.tong.chi,
      tongThu: tk.tong.thu,
      soKyTruoc: pt,
      deDanh: deDanh,
      tongCamKet: coCamKet ? duBao.tongCamKet : null,
      soCamKet: coCamKet ? duBao.camKet.length : 0,
      khoanChiLonNhat: lonNhat,
      soLieu: [
        soTien('Tổng chi', tk.tong.chi),
        soTien('Tổng thu', tk.tong.thu),
        if (pt != null) soPhanTram('So kỳ trước', pt.abs()),
        // Tỉ lệ ÂM (chi vượt thu nhập) đổi nhãn và lấy trị tuyệt đối: câu
        // "để dành -720,0%" không ai hiểu, còn "chi vượt thu nhập 720,0%" thì có.
        if (deDanh != null)
          deDanh >= 0
              ? soPhanTram('Để dành', deDanh)
              : soPhanTram('Vượt thu nhập', -deDanh),
        if (coCamKet) ...[
          soTien('Cam kết', duBao.tongCamKet),
          soDem('Số cam kết', duBao.camKet.length),
        ],
        if (lonNhat != null) soTien('Khoản lớn nhất', lonNhat),
        // Đặt CUỐI: mẫu câu tra mục theo nhãn, các mục tổng hợp phải gặp trước.
        ...theoDanhMuc,
      ],
    );
  }

  @override
  bool get thieuDuLieu => tongChi == 0 && tongThu == 0;

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
    return NhanXet(
      cau: b.toString(),
      theSoLieu: soLieu,
      muc: tongChi > tongThu ? MucNhanXet.canhBao : MucNhanXet.binhThuong,
    );
  }
}
