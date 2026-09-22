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
    // Chặng 4a: mỗi ngân sách góp một mục mang TÊN của nó, để câu hỏi "ngân
    // sách nào sắp hết" trả lời được bằng tên thay vì bằng con số trần (câu 3
    // bảng đo, mục 5.6 `docs/AI_AGENT_ARCHITECTURE.md`).
    //
    // ⚠️ Ngân sách được nhận xét (`v`) **không** vào danh sách này: mục `Tỉ lệ`
    // của nó ở dưới đã mang `ten`. Thêm một mục trùng vừa phí prompt vừa tự
    // dựng ra đúng tình huống "hai mục cùng giá trị" mà thẻ số liệu phải gỡ.
    //
    // ⚠️ Căng nhất trước: mô hình đọc từ trên xuống và hay lấy mục đầu khi
    // phải chọn một. Thứ tự ở đây là thứ tự *đáng chú ý*, không phải thứ tự
    // CSDL.
    final conLai = [
      for (final w in dangChay)
        if (w.budget.id != b.id) w,
    ]..sort((x, y) => y.budget.rawPercentSpent.compareTo(
        x.budget.rawPercentSpent,
      ));
    final theoTen = <SoLieu>[
      // Trần tính cả `v`, nên danh sách còn lại lấy bớt một suất.
      for (final w in conLai.take(kToiDaMucMoiGoi - 1))
        soPhanTram(
          'Tỉ lệ',
          w.budget.rawPercentSpent * 100,
          ten: w.displayName,
        ),
    ];
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
        // `ten` để câu hỏi "ngân sách nào sắp hết" đáp được bằng tên.
        soPhanTram('Tỉ lệ', pt, ten: v.displayName),
        soNgay('Còn', nhip.daysLeft),
        // Đã vượt thì "nên chi mỗi ngày" là 0 — một con số vô nghĩa, bỏ.
        if (!b.isOverBudget) soTien('Mỗi ngày', nhip.suggestedPerDay),
        // Số của câu tóm tắt kế hoạch — phải có trong gói thì bộ kiểm số mới
        // cho câu mẫu đi qua (`KeHoachTaiPhanBo.cauTomTat`).
        if (keHoach != null) ...[
          soTien('Thâm hụt', keHoach.thamHut),
          soDem('Nguồn bù', keHoach.dong.length),
          if (keHoach.trangThai == TrangThaiKeHoach.thieuNguonBu) ...[
            soTien('Bù được', keHoach.tongCat),
            soTien('Còn thiếu', keHoach.soThieu),
          ],
        ],
        // Đặt CUỐI: các mục trên là của ngân sách căng nhất và mẫu câu tra
        // chúng theo nhãn (`{for … x.nhan: x.chuoi}`), nên chúng phải gặp
        // trước để không bị mục cùng nhãn của ngân sách khác đè mất.
        ...theoTen,
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
    // ⚠️ Lấy mục ĐẦU TIÊN của mỗi nhãn, không phải mục cuối.
    //
    // `{for (final x in soLieu) x.nhan: x.chuoi}` — khuôn năm gói kia vẫn
    // dùng — cho giá trị **cuối** khi trùng khoá. Từ chặng 4a gói này mang
    // nhiều mục cùng nhãn `Tỉ lệ` (một cho mỗi ngân sách), nên khuôn ấy làm
    // câu nhận xét về Giáo dục in tỉ lệ của ngân sách đứng cuối danh sách:
    // *"Giáo dục: đã dùng 45.000 đ / 50.000 đ (7,1%)"* — sai **im lặng**, và
    // ca `contains('Giáo dục')` vẫn xanh.
    final s = <String, String>{};
    for (final x in soLieu) {
      s.putIfAbsent(x.nhan, () => x.chuoi);
    }
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
