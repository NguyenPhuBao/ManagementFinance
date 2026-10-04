/// Nhịp chi của một ngân sách trong kỳ hiện tại — logic thuần, không Drift,
/// không giao diện.
///
/// Trả lời ba câu người dùng thật sự hỏi khi nhìn "Còn 2.900.000đ":
/// còn *bao nhiêu ngày*, vậy mỗi ngày *nên chi* bao nhiêu, và mình đang tiêu
/// *nhanh hay chậm* so với thời gian đã trôi.
///
/// Mọi mốc đều lấy từ `BudgetEntity.currentPeriod` chứ không tự cắt tháng:
/// hàm ấy đã xử lý tháng ngắn, ngày 31 bị kẹp, ngân sách hết hạn và "Ngày cụ
/// thể". Tính lại ở đây là hai nơi có thể lệch nhau.
///
/// Có `nhipChi` (dự án C việc hai, `nhip_chi.dart`) thì "đáng lẽ đã chi" theo
/// nhịp riêng đã học từ các kỳ trước thay vì giả định chi đều — tiền nhà trả
/// ngày 1 thôi bị gọi là "nhanh" mỗi đầu tháng. Số ngày, "nên chi/ngày" và phần
/// thời gian đã trôi KHÔNG đổi theo nhịp.
library;

import '../data/models/budget_entity.dart';
import 'nhip_chi.dart';

/// So với **mốc so sánh**: phần thời gian đã trôi của kỳ (chi đều), hoặc phần
/// mọi khi đã chi tới lúc này khi đã học nhịp riêng (`BudgetPace.theoNhipRieng`).
enum BudgetPaceStatus {
  /// Tiêu ít hơn hẳn mốc so sánh.
  slow,

  /// Trong biên ±5 điểm phần trăm quanh mốc so sánh.
  onTrack,

  /// Tiêu nhiều hơn hẳn mốc so sánh.
  fast,
}

class BudgetPace {
  /// Tổng số ngày của kỳ. 0 khi kỳ rỗng (ngân sách chưa tới ngày bắt đầu).
  final int daysTotal;

  /// Số ngày còn lại **kể cả hôm nay**, làm tròn lên. 0 khi kỳ đã qua.
  final int daysLeft;

  /// Số tiền còn lại chia đều cho [daysLeft]. 0 khi đã vượt hoặc đã hết kỳ.
  final double suggestedPerDay;

  /// Số "đáng lẽ" đã tiêu tới lúc này: theo nhịp riêng khi [theoNhipRieng],
  /// không thì nếu chi đều theo thời gian đã trôi.
  final double expectedSpent;

  final BudgetPaceStatus status;

  /// Phần thời gian đã trôi của kỳ, 0–1 — `viTriTrongKy`. Dự phóng của tái phân
  /// bổ đọc nó thay vì tự tính lại.
  final double phanThoiGian;

  /// `true` khi [expectedSpent] và [status] tính theo NHỊP RIÊNG đã học
  /// (`nhip_chi.dart`), `false` khi theo giả định chi đều — giao diện đổi chữ
  /// theo nó.
  final bool theoNhipRieng;

  const BudgetPace({
    required this.daysTotal,
    required this.daysLeft,
    required this.suggestedPerDay,
    required this.expectedSpent,
    required this.status,
    this.phanThoiGian = 0,
    this.theoNhipRieng = false,
  });

  static const BudgetPace empty = BudgetPace(
    daysTotal: 0,
    daysLeft: 0,
    suggestedPerDay: 0,
    expectedSpent: 0,
    status: BudgetPaceStatus.onTrack,
  );
}

/// Biên "đúng nhịp": chênh lệch giữa phần đã tiêu và phần thời gian đã trôi,
/// tính theo tỉ lệ 0–1. Rộng hơn thì ai cũng "đúng nhịp"; hẹp hơn thì một bữa
/// ăn cũng đủ đổi bậc.
const double _paceTolerance = 0.05;

const _oneDay = Duration(days: 1);

/// Số ngày giữa hai mốc, làm tròn lên để một kỳ lẻ giờ vẫn đếm đủ ngày.
int _daysBetween(DateTime from, DateTime to) {
  final micro = to.difference(from).inMicroseconds;
  if (micro <= 0) return 0;
  return (micro / _oneDay.inMicroseconds).ceil();
}

BudgetPace budgetPaceOf(BudgetEntity b, DateTime now, {NhipChi? nhipChi}) {
  final ky = b.currentPeriod(now);
  final daysTotal = _daysBetween(ky.from, ky.to);
  if (daysTotal <= 0) return BudgetPace.empty;

  int daysLeft;
  if (!now.isBefore(ky.to)) {
    daysLeft = 0;
  } else {
    // Làm tròn LÊN và không dưới 1: ngày cuối kỳ người dùng vẫn còn hôm nay,
    // và chia cho 0 ngày là vô cực.
    daysLeft = _daysBetween(now, ky.to).clamp(1, daysTotal);
  }

  final remaining = b.remaining > 0 ? b.remaining : 0.0;
  final suggestedPerDay = daysLeft == 0 ? 0.0 : remaining / daysLeft;

  final elapsedFraction = viTriTrongKy(ky.from, ky.to, now);
  // Phần "đáng lẽ đã chi": nhịp riêng khi đã học, không thì giả định chi đều.
  final mocSoSanh =
      nhipChi?.phanDaChiMoiKhi(elapsedFraction) ?? elapsedFraction;
  final expectedSpent = b.amount * mocSoSanh;

  final spentFraction = b.amount > 0 ? b.spent / b.amount : 0.0;
  final diff = spentFraction - mocSoSanh;
  final status = diff > _paceTolerance
      ? BudgetPaceStatus.fast
      : diff < -_paceTolerance
          ? BudgetPaceStatus.slow
          : BudgetPaceStatus.onTrack;

  return BudgetPace(
    daysTotal: daysTotal,
    daysLeft: daysLeft,
    suggestedPerDay: suggestedPerDay,
    expectedSpent: expectedSpent,
    status: status,
    phanThoiGian: elapsedFraction,
    theoNhipRieng: nhipChi != null,
  );
}
