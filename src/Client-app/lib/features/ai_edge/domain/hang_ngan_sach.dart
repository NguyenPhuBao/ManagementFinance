/// Tool `danh_sach_ngan_sach` — hàng theo TÊN ngân sách kèm trạng thái, đã chi,
/// hạn mức, tỉ lệ, còn lại, số ngày còn lại (spec 4b mục 3.4). Không tính gì:
/// `remaining`, `rawPercentSpent`, `isOverBudget` là getter của `BudgetEntity`;
/// nhịp từ `budgetPaceOf`. "Tổng còn lại" cộng `remaining` của mọi ngân sách
/// đang chạy — đúng phép thẻ tổng trang Ngân sách đang hiện (câu 2 bảng 5.6).
library;

import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';

String chuNhipNganSach(BudgetPaceStatus s) => switch (s) {
      BudgetPaceStatus.fast => 'tiêu nhanh',
      BudgetPaceStatus.onTrack => 'đúng nhịp',
      BudgetPaceStatus.slow => 'tiêu chậm',
    };

KetQuaCongCu hangNganSach(List<BudgetView> dangChay, {required DateTime now}) {
  // Căng nhất trước — thứ tự đáng chú ý, không phải thứ tự CSDL.
  final sap = [...dangChay]..sort(
      (x, y) => y.budget.rawPercentSpent.compareTo(x.budget.rawPercentSpent));

  var tongConLai = 0.0;
  for (final v in dangChay) {
    tongConLai += v.budget.remaining;
  }

  final hang = <HangSoLieu>[];
  for (final v in sap.take(kToiDaMucMoiGoi)) {
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
    ],
  );
}
