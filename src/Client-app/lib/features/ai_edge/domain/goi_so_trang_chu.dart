/// Gói số của Trang chủ — nhận **đúng các con số trang đang hiện** (thu/chi
/// tháng của `TheSoLieuThang`, tổng số dư của thẻ tài sản, danh sách ngân sách
/// của thẻ Ngân sách) chứ không tự cộng giao dịch: "số trên thẻ = số trong gói"
/// là điều kiện 12 của mục 13 bản đánh giá, và lớp này không tính gì (test quét
/// thứ 14). Ngân sách nhắc tới là ngân sách căng nhất — cùng `pickHomeBudget`
/// với thẻ ngay trên nó.
library;

import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/pick_home_budget.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

class GoiSoTrangChu extends GoiSo {
  @override
  String get man => 'trang_chu';

  final double thu;
  final double chi;
  final double tongSoDu;

  /// `null` khi không có ngân sách nào đang chạy.
  final String? tenNganSach;
  final double? phanTramNganSach;

  @override
  final List<SoLieu> soLieu;

  GoiSoTrangChu._({
    required this.thu,
    required this.chi,
    required this.tongSoDu,
    required this.tenNganSach,
    required this.phanTramNganSach,
    required this.soLieu,
    required List<SoLieu> theoKy,
  }) : _theoKy = theoKy;

  /// Thu / chi / còn lại — số THÁNG NÀY (thẻ `TheSoLieuThang`), cho `kyCua`.
  final List<SoLieu> _theoKy;

  /// [boTongSoDu] — tài khoản không có quyền `net_worth_overview` (B1 spec 2026-10-27 mục 3; người dùng chốt 6 phiên 17):
  /// gói bỏ hẳn mục *"Tổng số dư"* — chip, tập cho phép của `kiemSo` và phần vào prompt cùng mất; thẻ Tổng số dư của trang
  /// đã là thẻ khoá. Mẫu câu không đọc nhãn ấy nên câu không đổi. Khuôn `GoiSoPhanTich.tu(boChiBatThuong:)`.
  factory GoiSoTrangChu.tu({
    required double thu,
    required double chi,
    required double tongSoDu,
    required List<BudgetView> nganSach,
    required DateTime now,
    bool boTongSoDu = false,
  }) {
    final v = pickHomeBudget(nganSach, now);
    final pt = v == null ? null : v.budget.rawPercentSpent * 100;
    final chenh = thu - chi;
    final thuS = soTien('Thu', thu);
    final chiS = soTien('Chi', chi);
    // Trị tuyệt đối: câu tự nói "còn lại" hay "chi vượt thu", và số 0
    // không mang dấu (cùng luật `formatCoDau`).
    final chenhS = soTien(chenh >= 0 ? 'Còn lại' : 'Chi vượt thu', chenh.abs());
    return GoiSoTrangChu._(
      thu: thu,
      chi: chi,
      tongSoDu: tongSoDu,
      tenNganSach: v?.displayName,
      phanTramNganSach: pt,
      soLieu: [
        thuS,
        chiS,
        chenhS,
        if (!boTongSoDu) soTien('Tổng số dư', tongSoDu),
        if (pt != null) soPhanTram('Ngân sách căng nhất', pt),
      ],
      theoKy: [thuS, chiS, chenhS],
    );
  }

  @override
  bool get thieuDuLieu => thu == 0 && chi == 0;

  /// G5 (b) cổng F: thu / chi / còn lại là số tháng này; tổng số dư và ngân
  /// sách căng nhất là số hiện tại — không kỳ.
  @override
  Set<String>? kyCua(SoLieu s) => _theoKy.contains(s) ? const {'tháng này'} : null;

  /// Tên ngân sách căng nhất có trong mẫu câu mà mục "Ngân sách căng nhất" không
  /// mang tên — xem `GoiSo.tenDoiTuong`.
  @override
  Iterable<String> get tenDoiTuong => [
        ...super.tenDoiTuong,
        if (tenNganSach != null) tenNganSach!,
      ];

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Tháng này chưa có giao dịch.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = chuoiTheoNhan(soLieu);
    final vuot = chi > thu;
    final b = StringBuffer('Tháng này thu ${s['Thu']}, chi ${s['Chi']}, ');
    b.write(vuot
        ? 'chi vượt thu ${s['Chi vượt thu']}.'
        : 'còn lại ${s['Còn lại']}.');
    if (tenNganSach != null) {
      b.write(' Ngân sách $tenNganSach đã dùng ${s['Ngân sách căng nhất']}.');
    }
    return NhanXet(
      cau: b.toString(),
      theSoLieu: soLieu,
      muc: vuot ? MucNhanXet.canhBao : MucNhanXet.binhThuong,
    );
  }
}
