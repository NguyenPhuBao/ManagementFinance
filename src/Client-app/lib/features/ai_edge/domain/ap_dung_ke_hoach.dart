/// Áp dụng kế hoạch tái phân bổ — hai hàm thuần, không chạm CSDL.
///
/// Sheet kế hoạch (`ke_hoach_tai_phan_bo_sheet.dart`) gom quyết định của người
/// dùng thành `soTienDaChon` (id ngân sách nguồn bù → số tiền cắt, chỉ dòng
/// được tick) rồi hỏi hai hàm này: [hanMucMoi] cho `updateBudget`, [phanHoiTu]
/// cho `AiFeedbackDao.ghi`. Tách khỏi widget để **tổng hạn mức không đổi** là
/// một tính chất kiểm được bằng test thuần — đó là lý do luật D5 bỏ được.
library;

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
import 'tai_phan_bo.dart';

/// Hạn mức mới của từng ngân sách bị ảnh hưởng: mỗi nguồn bù được chọn trừ
/// đúng số cắt, ngân sách thâm hụt cộng đúng tổng ấy. Không dòng nào chọn thì
/// trả rỗng — không sinh một lượt `updateBudget` vô nghĩa.
///
/// Ném [ArgumentError] khi số cắt âm hoặc vượt dư địa của dòng: cắt quá dư
/// địa là đẩy nguồn bù vào thâm hụt, sheet phải chặn trước và đây là chốt thứ
/// hai. Id không thuộc kế hoạch bị bỏ qua.
List<(BudgetEntity, double)> hanMucMoi(
  KeHoachTaiPhanBo kh,
  Map<String, double> soTienDaChon,
) {
  final ra = <(BudgetEntity, double)>[];
  var tong = 0.0;
  for (final d in kh.dong) {
    final id = d.nguon.budget.id;
    final x = soTienDaChon[id];
    if (x == null || x == 0) continue;
    if (x < 0) {
      throw ArgumentError.value(x, 'soTienDaChon[$id]', 'Số cắt phải dương');
    }
    if (x > d.duDia) {
      throw ArgumentError.value(
          x, 'soTienDaChon[$id]', 'Vượt dư địa ${d.duDia}');
    }
    ra.add((d.nguon.budget, d.nguon.budget.amount - x));
    tong += x;
  }
  if (tong == 0) return const [];
  ra.add((kh.thieu.budget, kh.thieu.budget.amount + tong));
  return ra;
}

/// Một hàng phản hồi cho **mỗi** dòng kế hoạch: `accepted` khi tick giữ số đề
/// xuất, `modified` khi tick nhưng đổi số (`actualAmount` = số mới), `rejected`
/// khi không tick — và mọi dòng `rejected` khi [boQua]. Kỳ ghi vào hàng là kỳ
/// **của ngân sách nguồn** tại [now] (luật C3 đếm bằng cặp ấy).
List<AiRebalancingFeedbacksCompanion> phanHoiTu(
  KeHoachTaiPhanBo kh,
  Map<String, double> soTienDaChon, {
  required int idaccount,
  required DateTime now,
  required bool boQua,
}) {
  const uuid = Uuid();
  return [
    for (final d in kh.dong)
      () {
        final b = d.nguon.budget;
        final x = boQua ? null : soTienDaChon[b.id];
        final chon = x != null && x > 0;
        final action = !chon
            ? 'rejected'
            : x == d.soTien
                ? 'accepted'
                : 'modified';
        final ky = b.currentPeriod(now);
        return AiRebalancingFeedbacksCompanion(
          id: Value(uuid.v4()),
          idaccount: Value(idaccount),
          createdAt: Value(now),
          deficitBudgetId: Value(kh.thieu.budget.id),
          donorBudgetId: Value(b.id),
          donorCategoryId: Value(b.categoryId ?? ''),
          suggestedAmount: Value(d.soTien),
          actualAmount: Value(chon ? x : 0),
          action: Value(action),
          periodFrom: Value(ky.from),
          periodTo: Value(ky.to),
        );
      }(),
  ];
}
