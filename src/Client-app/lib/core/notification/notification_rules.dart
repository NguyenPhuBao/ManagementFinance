import '../../features/budget/data/models/budget_entity.dart';
import '../../features/budget/presentation/widgets/budget_visuals.dart';

/// Loại thông báo. Giá trị `.name` được ghi thẳng vào cột `kind`.
enum NotificationKind {
  budgetNearLimit,
  budgetOverspent,
  billDueSoon,
  billOverdue,
  goalCompleted,
  goalBehind,
  syncFailed,
  walletNegative,
}

enum NotificationSeverity { info, warning, critical }

/// Một thông báo **cần được tạo** — chưa chạm CSDL.
class NotificationCandidate {
  final NotificationKind kind;

  /// Khoá chống trùng. Xem chú thích cột `dedupeKey` ở `notification_table.dart`.
  final String dedupeKey;

  final String title;
  final String body;
  final NotificationSeverity severity;
  final String? subjectType;
  final String? subjectId;
  final String? deeplink;

  /// Mốc của **sự kiện**, không phải mốc quét.
  final DateTime createdAt;

  const NotificationCandidate({
    required this.kind,
    required this.dedupeKey,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    this.subjectType,
    this.subjectId,
    this.deeplink,
  });
}

/// Dữ liệu vào cho một lượt quét.
///
/// [now] luôn được tiêm — luật **không bao giờ** gọi `DateTime.now()`, nếu
/// không thì không test được hành vi quanh biên kỳ và biên ngày.
class NotificationRuleInput {
  final DateTime now;
  final List<BudgetView> budgets;

  const NotificationRuleInput({
    required this.now,
    this.budgets = const [],
  });
}

/// Sinh danh sách thông báo cần tạo từ trạng thái hiện tại.
///
/// Hàm thuần: cùng đầu vào luôn cho cùng đầu ra, không đọc đồng hồ, không chạm
/// CSDL. Đây là nơi đặt gần như toàn bộ test của tính năng.
List<NotificationCandidate> buildNotificationCandidates(
  NotificationRuleInput input,
) {
  return [
    ..._budgetCandidates(input),
  ];
}

// ── Ngân sách ────────────────────────────────────────────────────────────────

List<NotificationCandidate> _budgetCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final view in input.budgets) {
    final b = view.budget;

    // Ngân sách đã hết hạn thì nhắc là nhiễu thuần tuý: người dùng không làm gì
    // được với một ngân sách đã chết.
    if (b.isExpired(input.now)) continue;

    // Mốc gốc của kỳ đang chạy — cũng chính là thứ làm khoá đổi khi sang kỳ
    // mới. Dùng lại `currentPeriod` thay vì tự cắt tháng: hàm đó đã xử lý xong
    // ngân sách hết hạn, ngân sách không chu kỳ, và chống trôi ngày 31 → 28.
    final ky = _ngayGon(b.currentPeriod(input.now).from);

    // KHÔNG tự so `rawPercentSpent` với 0.9 ở đây. `isNearLimit` và
    // `isOverBudget` là định nghĩa duy nhất của hai trạng thái này; cài lại là
    // để màu trên thẻ và thông báo nói hai chuyện khác nhau.
    if (b.isOverBudget) {
      ra.add(NotificationCandidate(
        kind: NotificationKind.budgetOverspent,
        dedupeKey: 'budgetOver:${b.id}:$ky',
        title: 'Đã vượt ngân sách',
        body: '${view.displayName} đã vượt hạn mức '
            '${_tien(b.overAmount)}.',
        severity: NotificationSeverity.critical,
        subjectType: 'budget',
        subjectId: b.id,
        deeplink: '/budget',
        createdAt: input.now,
      ));
      continue;
    }

    if (!b.isNearLimit) continue;

    // Bậc màu vào khoá để mỗi ngân sách được nhắc tối đa một lần MỖI BẬC trong
    // một kỳ: leo từ 70% lên 90% là sự kiện mới, còn nhích trong cùng bậc thì
    // không. Tuyệt đối không đưa `spent` hay tỉ lệ thô vào đây — làm vậy là
    // mỗi giao dịch đẻ một thông báo.
    final bac = budgetHealthOf(b).name;

    ra.add(NotificationCandidate(
      kind: NotificationKind.budgetNearLimit,
      dedupeKey: 'budgetNear:${b.id}:$ky:$bac',
      title: 'Sắp vượt ngân sách',
      body: 'Bạn đã chi tiêu ${_phanTram(b.rawPercentSpent)} ngân sách '
          '${view.displayName}.',
      severity: NotificationSeverity.warning,
      subjectType: 'budget',
      subjectId: b.id,
      deeplink: '/budget',
      createdAt: input.now,
    ));
  }

  return ra;
}

// ── Định dạng ────────────────────────────────────────────────────────────────

/// `yyyy-MM-dd`, đủ để phân biệt kỳ và ổn định qua các phiên chạy.
String _ngayGon(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _phanTram(double ratio) => '${(ratio * 100).round()}%';

/// Rút gọn kiểu "1,2 triệu" / "500 nghìn" cho câu thông báo — số đầy đủ đã có
/// trên màn ngân sách, ở đây chỉ cần đủ để người dùng quyết định có mở app.
String _tien(double v) {
  if (v >= 1000000) {
    final trieu = v / 1000000;
    final s = trieu.toStringAsFixed(trieu >= 10 ? 0 : 1).replaceAll('.', ',');
    return '${s.endsWith(',0') ? s.substring(0, s.length - 2) : s} triệu';
  }
  if (v >= 1000) return '${(v / 1000).round()} nghìn';
  return '${v.round()} đồng';
}
