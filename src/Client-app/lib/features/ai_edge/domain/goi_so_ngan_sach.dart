/// Gói số của trang Ngân sách.
///
/// Ngân sách được nhận xét là ngân sách **căng nhất** — cùng luật với thẻ Ngân
/// sách ở Trang chủ (`pickHomeBudget`), để hai chỗ không nói về hai ngân sách
/// khác nhau. Mọi con số từ `budgetPaceOf` và `BudgetEntity`; lớp này không
/// tính gì (test quét thứ 14).
library;

import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import '../../home/presentation/widgets/home_budget_card.dart'
    show pickHomeBudget;
import 'goi_so.dart';
import 'nhan_xet.dart';
import 'tai_phan_bo.dart';

class GoiSoNganSach extends GoiSo {
  @override
  String get man => 'ngan_sach';

  /// `null` khi không có ngân sách nào đang chạy.
  final String? ten;
  final double hanMuc;
  final double daChi;
  final double nenChiMoiNgay;

  /// Thang 0–100, **không** cắt trần (vượt thì > 100).
  final double phanTram;
  final int ngayConLai;
  final bool vuot;
  final KeHoachTaiPhanBo? keHoach;

  @override
  final List<SoLieu> soLieu;

  GoiSoNganSach._({
    required this.ten,
    required this.hanMuc,
    required this.daChi,
    required this.nenChiMoiNgay,
    required this.phanTram,
    required this.ngayConLai,
    required this.vuot,
    required this.keHoach,
    required this.soLieu,
  });

  factory GoiSoNganSach.tu(
    List<BudgetView> dangChay, {
    required DateTime now,
    KeHoachTaiPhanBo? keHoach,
  }) {
    final v = pickHomeBudget(dangChay, now);
    if (v == null) {
      return GoiSoNganSach._(
        ten: null,
        hanMuc: 0,
        daChi: 0,
        nenChiMoiNgay: 0,
        phanTram: 0,
        ngayConLai: 0,
        vuot: false,
        keHoach: keHoach,
        soLieu: const [],
      );
    }
    final b = v.budget;
    final nhip = budgetPaceOf(b, now);
    final pt = b.rawPercentSpent * 100;
    return GoiSoNganSach._(
      ten: v.displayName,
      hanMuc: b.amount,
      daChi: b.spent,
      nenChiMoiNgay: nhip.suggestedPerDay,
      phanTram: pt,
      ngayConLai: nhip.daysLeft,
      vuot: b.isOverBudget,
      keHoach: keHoach,
      soLieu: [
        soTien('Đã chi', b.spent),
        soTien('Hạn mức', b.amount),
        soPhanTram('Tỉ lệ', pt),
        soNgay('Còn', nhip.daysLeft),
        // Đã vượt thì "nên chi mỗi ngày" là 0 — một con số vô nghĩa, bỏ.
        if (!b.isOverBudget) soTien('Mỗi ngày', nhip.suggestedPerDay),
      ],
    );
  }

  @override
  bool get thieuDuLieu => ten == null;

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Chưa có ngân sách nào đang chạy để nhận xét.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = {for (final x in soLieu) x.nhan: x.chuoi};
    final cau = vuot
        ? '$ten đã vượt hạn mức: ${s['Đã chi']} / ${s['Hạn mức']} '
            '(${s['Tỉ lệ']}), còn ${s['Còn']}.'
        : '$ten: đã dùng ${s['Đã chi']} / ${s['Hạn mức']} (${s['Tỉ lệ']}), '
            'còn ${s['Còn']} — nên chi tối đa ${s['Mỗi ngày']} mỗi ngày.';
    final tomTat = keHoach?.cauTomTat ?? '';
    return NhanXet(
      cau: tomTat.isEmpty ? cau : '$cau $tomTat',
      theSoLieu: soLieu,
      muc: vuot ? MucNhanXet.canhBao : MucNhanXet.binhThuong,
    );
  }
}
