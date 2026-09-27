/// Tool `danh_sach_ngan_sach` — hàng theo TÊN ngân sách kèm trạng thái, đã chi,
/// hạn mức, tỉ lệ, còn lại, số ngày còn lại (spec 4b mục 3.4). Không tính gì:
/// `remaining`, `rawPercentSpent`, `isOverBudget` là getter của `BudgetEntity`;
/// nhịp từ `budgetPaceOf`. "Tổng còn lại" cộng `remaining` của mọi ngân sách
/// đang chạy — đúng phép thẻ tổng trang Ngân sách đang hiện (câu 2 bảng 5.6).
///
/// [chon] (spec tool truy vấn 2026-09-27, mục 4 — E18): lọc hoặc chọn theo tỉ
/// lệ đã dùng — `duoi_nua` / `tren_nua` giữ mọi hàng thoả, `nhieu_nhat` /
/// `it_nhat` giữ một hàng. Tổng hợp vẫn cộng MỌI ngân sách đang chạy; "Số ngân
/// sách khớp" chỉ có khi lọc, và 0 khớp là `rongTheoBoLoc` (không phải "không
/// có ngân sách").
library;

import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import 'chon.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

String chuNhipNganSach(BudgetPaceStatus s) => switch (s) {
      BudgetPaceStatus.fast => 'tiêu nhanh',
      BudgetPaceStatus.onTrack => 'đúng nhịp',
      BudgetPaceStatus.slow => 'tiêu chậm',
    };

KetQuaCongCu hangNganSach(
  List<BudgetView> dangChay, {
  required DateTime now,
  String? chon,
}) {
  if (chon != null && !kChon.contains(chon)) {
    return tuChoiGiaTri('chon', chon, kChon);
  }
  // Căng nhất trước — thứ tự đáng chú ý, không phải thứ tự CSDL.
  final sap = [...dangChay]..sort(
      (x, y) => y.budget.rawPercentSpent.compareTo(x.budget.rawPercentSpent));
  // Ngưỡng "một nửa" là 0,5 của rawPercentSpent — đúng phép trang Ngân sách,
  // không làm tròn trước khi so.
  final khop = switch (chon) {
    'nhieu_nhat' => sap.take(1).toList(),
    'it_nhat' => sap.isEmpty ? <BudgetView>[] : [sap.last],
    'duoi_nua' => [for (final v in sap) if (v.budget.rawPercentSpent < 0.5) v],
    'tren_nua' => [for (final v in sap) if (v.budget.rawPercentSpent >= 0.5) v],
    _ => sap,
  };

  var tongConLai = 0.0;
  for (final v in dangChay) {
    tongConLai += v.budget.remaining;
  }

  final hang = <HangSoLieu>[];
  for (final v in khop.take(kToiDaMucMoiGoi)) {
    final b = v.budget;
    final nhip = budgetPaceOf(b, now);
    final ten = v.displayName;
    hang.add(HangSoLieu(
      ten: ten,
      trangThai: b.isOverBudget ? 'vượt hạn mức' : chuNhipNganSach(nhip.status),
      canhBao: b.isOverBudget,
      soLieu: [
        soTien('Đã chi', b.spent, ten: ten),
        soTien('Hạn mức', b.amount, ten: ten),
        soPhanTram('Tỉ lệ', b.rawPercentSpent * 100, ten: ten),
        // Đã vượt thì "còn lại" là số âm người đọc phải tự đảo nghĩa — bỏ,
        // trạng thái đã nói "vượt hạn mức".
        if (!b.isOverBudget) soTien('Còn lại', b.remaining, ten: ten),
        soNgay('Còn', nhip.daysLeft, ten: ten),
      ],
    ));
  }
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Tổng còn lại', tongConLai),
      soDem('Số ngân sách', dangChay.length),
      if (chon != null) soDem('Số ngân sách khớp', khop.length),
    ],
    boLoc: [if (chon != null) kChuChon[chon]!],
    rongTheoBoLoc: chon != null && khop.isEmpty,
  );
}
