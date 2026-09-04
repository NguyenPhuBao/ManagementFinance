import '../database/app_database.dart';
import '../../features/budget/data/models/budget_entity.dart';
import '../../features/goal/data/models/goal_entity.dart';
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
  final List<Bill> bills;
  final List<GoalEntity> goals;
  final List<Wallet> wallets;

  /// Lượt đồng bộ gần nhất kết thúc ở trạng thái lỗi.
  ///
  /// Là `bool` chứ không phải cả `SyncStatus`: bộ luật chỉ cần biết "hỏng hay
  /// không", và thu hẹp đầu vào thì test không phải dựng một enum của tầng
  /// khác chỉ để hỏi một câu.
  final bool syncFailed;

  /// Mọi sự kiện xảy ra TRƯỚC mốc này bị bỏ qua.
  ///
  /// Dùng cho lần bật tính năng đầu tiên: không có nó thì lượt quét đầu nhìn
  /// thấy mọi hoá đơn quá hạn của mấy tháng trước và bắn hàng chục thông báo
  /// cùng lúc — ấn tượng đầu tiên tệ nhất có thể. `null` = không lọc gì.
  final DateTime? silenceBefore;

  /// Số ngày nhắc trước hạn cho hoá đơn **không tự đặt**.
  ///
  /// Đến từ tuỳ chọn của người dùng (`NotificationPrefs.soNgayNhacHoaDon`).
  /// Bỏ qua nó là công tắc "nhắc trước" trong trang cài đặt trông như có tác
  /// dụng mà thật ra không.
  final int defaultBillLeadDays;

  const NotificationRuleInput({
    required this.now,
    this.budgets = const [],
    this.bills = const [],
    this.goals = const [],
    this.wallets = const [],
    this.syncFailed = false,
    this.silenceBefore,
    this.defaultBillLeadDays = mocNhacMacDinh,
  });
}

/// Sinh danh sách thông báo cần tạo từ trạng thái hiện tại.
///
/// Hàm thuần: cùng đầu vào luôn cho cùng đầu ra, không đọc đồng hồ, không chạm
/// CSDL. Đây là nơi đặt gần như toàn bộ test của tính năng.
List<NotificationCandidate> buildNotificationCandidates(
  NotificationRuleInput input,
) {
  final ra = [
    ..._budgetCandidates(input),
    ..._billCandidates(input),
    ..._goalCandidates(input),
    ..._walletCandidates(input),
    ..._syncCandidates(input),
  ];

  final chan = input.silenceBefore;
  if (chan == null) return ra;
  return ra.where((c) => !c.createdAt.isBefore(chan)).toList();
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

// ── Hoá đơn ──────────────────────────────────────────────────────────────────

/// Số ngày nhắc trước hạn khi cả hoá đơn lẫn tuỳ chọn đều không nói gì.
///
/// Khớp `@default("3")` của cột `Time_notification` phía backend, để một hoá
/// đơn tạo ở client và một hoá đơn tạo ở nơi khác hành xử như nhau.
const int mocNhacMacDinh = 3;

/// Số ngày nhắc trước hạn thật sự dùng cho [bill].
///
/// Giá trị đặt riêng cho một hoá đơn **thắng** giá trị mặc định chung: nó là
/// lựa chọn cụ thể hơn.
int billLeadDays(Bill bill, {int fallback = mocNhacMacDinh}) =>
    int.tryParse(bill.timeNotification ?? '') ?? fallback;

/// Khoá chống trùng của thông báo "hoá đơn sắp đến hạn".
///
/// **Hàm này là điểm nối duy nhất giữa thông báo trong app và lịch đặt trước ở
/// hệ điều hành.** Lịch nổ lúc app đóng mang `payload = dedupeKey`; người dùng
/// bấm vào, app mở, vòng quét chạy và `insertOrIgnore` sinh **đúng** hàng ấy,
/// một lần duy nhất. Hai nơi tự dựng khoá theo hai cách là mỗi sự kiện sinh
/// hai thông báo — và không có lỗi nào báo ra.
String billDueDedupeKey({
  required String billId,
  required DateTime dueDate,
  required int leadDays,
}) =>
    'billDue:$billId:${_ngayGon(_dauNgay(dueDate))}:$leadDays';

List<NotificationCandidate> _billCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];
  final homNay = _dauNgay(input.now);

  for (final b in input.bills) {
    if (b.isDeleted) continue;

    // Lọc theo CẢ HAI cột trạng thái: hàng kéo về từ backend có thể mang
    // `payStatus = 'Payed'` trong khi `isPaid` còn false, và ngược lại.
    if (b.isPaid || b.payStatus == 'Payed') continue;

    final hanTra = _dauNgay(b.dueDate);

    // So theo NGÀY, không theo giờ: trừ DateTime thô thì cùng một hoá đơn nhắc
    // hay không tuỳ vào giờ trong ngày người dùng mở app — hỏng ngẫu nhiên và
    // rất khó lần ra.
    final soNgayConLai = hanTra.difference(homNay).inDays;

    if (soNgayConLai < 0) {
      ra.add(NotificationCandidate(
        kind: NotificationKind.billOverdue,
        dedupeKey: 'billOverdue:${b.id}:${_ngayGon(hanTra)}',
        title: 'Hoá đơn quá hạn',
        body: '${b.name} đã quá hạn thanh toán '
            '${-soNgayConLai} ngày (${_tien(b.amount)}).',
        severity: NotificationSeverity.critical,
        subjectType: 'bill',
        subjectId: b.id,
        deeplink: '/bills',
        // Mốc sự kiện là NGÀY QUÁ HẠN, không phải lúc quét — nếu không thì
        // `silenceBefore` không loại được hoá đơn quá hạn từ mấy tháng trước.
        createdAt: hanTra,
      ));
      continue;
    }

    final nhacTruoc = billLeadDays(b, fallback: input.defaultBillLeadDays);
    if (soNgayConLai > nhacTruoc) continue;

    final mocNhac = hanTra.subtract(Duration(days: nhacTruoc));
    ra.add(NotificationCandidate(
      kind: NotificationKind.billDueSoon,
      dedupeKey: billDueDedupeKey(
        billId: b.id,
        dueDate: hanTra,
        leadDays: nhacTruoc,
      ),
      title: 'Hoá đơn sắp đến hạn',
      body: soNgayConLai == 0
          ? '${b.name} đến hạn hôm nay (${_tien(b.amount)}).'
          : '${b.name} còn $soNgayConLai ngày tới hạn (${_tien(b.amount)}).',
      severity: NotificationSeverity.warning,
      subjectType: 'bill',
      subjectId: b.id,
      deeplink: '/bills',
      createdAt: mocNhac,
    ));
  }

  return ra;
}

// ── Mục tiêu ─────────────────────────────────────────────────────────────────

List<NotificationCandidate> _goalCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final g in input.goals) {
    if (g.isDeleted) continue;

    if (g.isCompleted || g.progress >= 1.0) {
      ra.add(NotificationCandidate(
        kind: NotificationKind.goalCompleted,
        // KHÔNG có mốc thời gian trong khoá: một mục tiêu chỉ hoàn thành một
        // lần trong đời. Thêm tháng vào đây là mỗi tháng lại chúc mừng lại
        // cùng một việc.
        dedupeKey: 'goalDone:${g.id}',
        title: 'Đã đạt mục tiêu',
        body: 'Chúc mừng! Bạn đã hoàn thành mục tiêu ${g.name}.',
        severity: NotificationSeverity.info,
        subjectType: 'goal',
        subjectId: g.id,
        deeplink: '/goals',
        createdAt: input.now,
      ));
      continue;
    }

    if (!g.isBehindSchedule(input.now)) continue;

    final conThieu = g.targetAmount - g.currentAmount;

    ra.add(NotificationCandidate(
      kind: NotificationKind.goalBehind,
      // Gộp theo THÁNG: trễ tiến độ kéo dài hàng tháng trời, còn quét thì chạy
      // sau mọi lần đồng bộ. Không có đơn vị lặp lại là mỗi lượt quét đẻ một
      // thông báo mới.
      dedupeKey: 'goalBehind:${g.id}:${_thangGon(input.now)}',
      title: 'Mục tiêu đang chậm tiến độ',
      body: 'Tiết kiệm thêm ${_tien(conThieu)} để đạt mục tiêu ${g.name}.',
      severity: NotificationSeverity.warning,
      subjectType: 'goal',
      subjectId: g.id,
      deeplink: '/goals',
      createdAt: input.now,
    ));
  }

  return ra;
}

// ── Ví ───────────────────────────────────────────────────────────────────────

List<NotificationCandidate> _walletCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final v in input.wallets) {
    if (v.isDeleted) continue;
    // Số dư 0 là chuyện bình thường; âm mới là dấu hiệu ghi nhầm giao dịch.
    if (v.balance >= 0) continue;

    ra.add(NotificationCandidate(
      kind: NotificationKind.walletNegative,
      // Gộp theo NGÀY: ví ở trạng thái âm cho tới khi người dùng nạp tiền.
      dedupeKey: 'walletNeg:${v.id}:${_ngayGon(_dauNgay(input.now))}',
      title: 'Số dư ví đang âm',
      body: '${v.name} đang âm ${_tien(-v.balance)}. '
          'Có thể một giao dịch đã bị ghi nhầm.',
      severity: NotificationSeverity.critical,
      subjectType: 'wallet',
      subjectId: v.id,
      deeplink: '/wallets',
      createdAt: input.now,
    ));
  }

  return ra;
}

// ── Hệ thống ─────────────────────────────────────────────────────────────────

List<NotificationCandidate> _syncCandidates(NotificationRuleInput input) {
  if (!input.syncFailed) return const [];

  return [
    NotificationCandidate(
      kind: NotificationKind.syncFailed,
      // Gộp theo NGÀY: mất mạng là hỏng ở MỌI chu kỳ đồng bộ.
      dedupeKey: 'syncFailed:${_ngayGon(_dauNgay(input.now))}',
      title: 'Đồng bộ chưa thành công',
      // Cảnh báo, không phải thảm hoạ: kiến trúc offline-first nghĩa là dữ
      // liệu vẫn nằm an toàn trong máy và sẽ tự đẩy lên khi có mạng.
      body: 'Dữ liệu vẫn được lưu trên máy và sẽ tự đồng bộ lại khi có mạng.',
      severity: NotificationSeverity.warning,
      subjectType: 'sync',
      createdAt: input.now,
    ),
  ];
}

/// Cắt về 00:00 cùng ngày, để mọi phép so là so NGÀY chứ không so thời điểm.
DateTime _dauNgay(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM` — đơn vị lặp lại cho những cảnh báo kéo dài hàng tháng.
String _thangGon(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}';

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
