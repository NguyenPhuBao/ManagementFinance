import '../database/app_database.dart';
import '../../features/budget/data/models/budget_entity.dart';
import '../../features/goal/data/models/goal_entity.dart';
import '../../features/goal/domain/goal_auto_deposit.dart';
import '../../features/goal/domain/goal_auto_deposit_runner.dart';
import '../../features/bill/domain/bill_auto_pay.dart';
import '../../features/bill/domain/bill_auto_pay_runner.dart';
import '../../features/budget/presentation/widgets/budget_visuals.dart';

/// Loại thông báo. Giá trị `.name` được ghi thẳng vào cột `kind`.
enum NotificationKind {
  budgetNearLimit,
  budgetOverspent,
  billDueSoon,
  billOverdue,
  billAutoPaid,
  billAutoPayFailed,
  goalCompleted,
  goalCycleReady,
  goalBehind,
  goalMilestone,
  goalAutoDeposited,
  goalAutoDepositFailed,
  syncFailed,
  walletNegative,
  walletLowBalance,
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

  /// Các kỳ trích tự động **vừa chạy xong** trong chính lượt quét này.
  ///
  /// Khác hẳn bốn danh sách trên: chúng là *trạng thái*, còn đây là *sự kiện*.
  /// Bộ luật vẫn là nơi đặt câu chữ cho cả hai, vì hai nơi cùng viết câu thông
  /// báo là hai giọng khác nhau trong cùng một trung tâm thông báo — và chỉ có
  /// đường qua bộ luật mới được lọc theo tuỳ chọn người dùng, khử trùng, rồi
  /// bắn ra hệ điều hành.
  final List<GoalAutoDepositEvent> autoDeposits;

  /// Các kỳ **tự động thanh toán hoá đơn** vừa chạy xong trong lượt quét này.
  /// Cùng bản chất *sự kiện* như [autoDeposits].
  final List<BillAutoPayEvent> autoPays;

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

  /// Cảnh báo khi số dư một ví xuống tới mức này, đơn vị **đồng**.
  ///
  /// `0` = **tắt**, và đó là mặc định. Một con số thay vì một cặp
  /// công tắc-cộng-số vì cặp ấy biểu diễn được một trạng thái vô nghĩa (bật
  /// nhưng ngưỡng bằng 0), còn một con số thì không.
  ///
  /// Đến từ `NotificationPrefs.nguongSoDuThap`, cùng đường với
  /// [defaultBillLeadDays].
  final int lowBalanceThreshold;

  const NotificationRuleInput({
    required this.now,
    this.budgets = const [],
    this.bills = const [],
    this.goals = const [],
    this.wallets = const [],
    this.autoDeposits = const [],
    this.autoPays = const [],
    this.syncFailed = false,
    this.silenceBefore,
    this.defaultBillLeadDays = mocNhacMacDinh,
    this.lowBalanceThreshold = 0,
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
    ..._autoDepositCandidates(input),
    ..._autoPayCandidates(input),
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

/// Đường dẫn tới **một** mục tiêu, dùng chung cho cả hai luật thông báo.
///
/// Trước đây cả hai trỏ về `/goals` — danh sách. Thông báo đã biết chính xác
/// mục tiêu nào (nó nằm sẵn ở `subjectId`), nên đổ người dùng xuống danh sách
/// là vứt đi thông tin mình đang cầm: câu nhắc "tiết kiệm thêm 900 nghìn cho
/// MacBook" mà việc cần làm vẫn còn cách vài cú chạm.
///
/// ⚠️ Route này phải nằm **ngoài** `StatefulShellRoute`, y như `/goals`. Trung
/// tâm thông báo chọn `push` hay `go` bằng `thuocThanhTab()`, và `push` một
/// route trong shell từ ngoài shell làm app **chết màn đỏ**. Kéo `/goals/:id`
/// vào một nhánh tab thì phải cập nhật `nhanhThanhTab` cùng lúc —
/// `notification_deeplink_test.dart` canh chỗ đó.
String goalDeeplink(String goalId) => '/goals/$goalId';

/// Các mốc tiến độ được ghi nhận, phần trăm, **xếp giảm dần**.
///
/// Thứ tự giảm dần không phải để cho đẹp: [_mocDaVuot] lấy phần tử **đầu tiên**
/// khớp, nên đảo thứ tự sẽ luôn trả về 25 và hai mốc còn lại chết lặng.
///
/// Cố ý **không có 100**: mốc ấy đã có `goalCompleted` lo, và mục tiêu đạt đủ
/// tiền còn không đi tới được đoạn mã này (nhánh `daHoanThanh` đã `continue`).
/// Thêm 100 vào đây là hai lời chúc mừng cho cùng một việc.
///
/// Cũng cố ý **không có mốc dưới 25**: gần như mọi mục tiêu đều vượt ngay ở
/// khoản nạp đầu tiên, và một lời chúc mừng ai cũng nhận được thì không còn là
/// lời chúc mừng.
const _mocTienDo = [75, 50, 25];

/// Mốc **cao nhất** mà mục tiêu đã vượt, hoặc `null` nếu chưa tới mốc nào.
///
/// Trả về một mốc chứ không phải danh sách, vì một khoản nạp lớn có thể vượt
/// cả ba cùng lúc — bắn ba tin cho MỘT thao tác là ồn, và chỉ mốc cao nhất
/// mang tin mới.
int? _mocDaVuot(GoalEntity g) {
  final phanTram = g.progress * 100;
  for (final m in _mocTienDo) {
    if (phanTram >= m) return m;
  }
  return null;
}

List<NotificationCandidate> _goalCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final g in input.goals) {
    if (g.isDeleted) continue;

    // `GoalEntity.daHoanThanh` là định nghĩa duy nhất của "mục tiêu đã xong",
    // dùng chung với bộ chia tab `chiaMucTieu`. Trước đây chỗ này tự viết
    // `isCompleted || progress >= 1.0` — một bản sao chờ ngày lệch.
    if (g.daHoanThanh) {
      // Lời nhắc vòng mới là một tin RIÊNG, không gộp vào câu chúc mừng.
      //
      // Câu chúc mừng dùng khoá `goalDone:<id>` **cố ý không có mốc thời
      // gian** — "một mục tiêu chỉ hoàn thành một lần trong đời". Mục tiêu lặp
      // lại phá đúng giả định ấy: nhét lời nhắc vào chung thì từ vòng thứ hai
      // trở đi nó rơi vào khoá cũ và không bao giờ hiện nữa.
      //
      // Khoá ở đây gắn `startDate`, và `batDauVongMoi` đặt lại cột ấy bằng
      // "bây giờ" — nên mỗi vòng được nhắc đúng một lần.
      if (g.recurrence) {
        ra.add(NotificationCandidate(
          kind: NotificationKind.goalCycleReady,
          dedupeKey: 'goalCycle:${g.id}:'
              '${g.startDate?.millisecondsSinceEpoch ?? 0}',
          title: 'Bắt đầu vòng mới?',
          body: 'Mục tiêu ${g.name} đã hoàn thành. Mở mục tiêu để bắt đầu một '
              'vòng tích luỹ mới.',
          severity: NotificationSeverity.info,
          subjectType: 'goal',
          subjectId: g.id,
          deeplink: goalDeeplink(g.id),
          createdAt: input.now,
        ));
      }

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
        deeplink: goalDeeplink(g.id),
        createdAt: input.now,
      ));
      continue;
    }

    // ⚠️ Cột mốc phải đứng TRƯỚC phép kiểm chậm tiến độ ngay dưới. Dòng ấy
    // `continue` cho mọi mục tiêu đang đúng nhịp, nên đặt cột mốc sau nó thì
    // chỉ những mục tiêu đang TRỄ mới được ghi nhận quãng đã đi — đúng ngược
    // với ý định. Hai luật này độc lập và một mục tiêu có thể trúng cả hai.
    final moc = _mocDaVuot(g);
    if (moc != null) {
      ra.add(NotificationCandidate(
        kind: NotificationKind.goalMilestone,
        // Khoá theo khuôn `goalCycle:` chứ KHÔNG theo khuôn `goalDone:`.
        // `goalDone:<id>` cố ý không mang mốc thời gian vì "một mục tiêu chỉ
        // hoàn thành một lần trong đời"; mục tiêu lặp lại phá đúng giả định
        // ấy (mục 3.17 `GOAL_FEATURE.md`). Cột mốc thì mỗi vòng phải báo lại,
        // và `batDauVongMoi` đặt lại `startDate` — nên mốc bắt đầu là thứ
        // phân biệt hai vòng. Phần `:$moc` ở cuối giữ cho ba mốc không nuốt
        // nhau: dùng chung một khoá thì người dùng chỉ được báo ở mốc đầu.
        //
        // Id nằm ở đoạn THỨ HAI vì `duongDanTuKhoa` đọc `phan[1]`.
        dedupeKey: 'goalMilestone:${g.id}:'
            '${g.startDate?.millisecondsSinceEpoch ?? 0}:$moc',
        title: 'Đã đi được $moc% chặng đường',
        body: 'Mục tiêu ${g.name} đã tích được ${_tien(g.currentAmount)} '
            'trên ${_tien(g.targetAmount)}.',
        severity: NotificationSeverity.info,
        subjectType: 'goal',
        subjectId: g.id,
        deeplink: goalDeeplink(g.id),
        createdAt: input.now,
      ));
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
      deeplink: goalDeeplink(g.id),
      createdAt: input.now,
    ));
  }

  return ra;
}

/// Báo kết quả của các kỳ trích tự động.
///
/// ## Vì sao thành công cũng phải báo
///
/// Đây là chỗ duy nhất trong app tự chuyển tiền của người dùng khi họ không có
/// mặt. Im lặng nghĩa là họ chỉ thấy số dư ví hụt đi mà không biết vì sao — và
/// khoản ấy nằm lẫn giữa các giao dịch khác trong sổ. Câu báo phải nói rõ **bao
/// nhiêu** và **từ ví nào**.
///
/// ## Vì sao thất bại càng phải báo
///
/// Bỏ qua một kỳ vì ví cạn mà không nói gì là để người dùng tin rằng tháng này
/// đã tích được, trong khi không có đồng nào rời ví. Tiến độ mục tiêu vẫn đứng
/// yên và họ chỉ phát hiện khi tới hạn.
List<NotificationCandidate> _autoDepositCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final e in input.autoDeposits) {
    final thanhCong = e.loai == LoaiTrich.trichDu ||
        e.loai == LoaiTrich.trichPhanConLai;

    // Không có gì để nói về một kỳ mà mục tiêu đã đủ tiền — bộ chạy cũng đã bỏ
    // qua nó rồi, đây chỉ là lớp chặn thứ hai.
    if (!thanhCong && e.loai == LoaiTrich.mucTieuDaXong) continue;

    final tuVi = e.tenViNguon == null ? '' : ' từ ${e.tenViNguon}';

    ra.add(NotificationCandidate(
      kind: thanhCong
          ? NotificationKind.goalAutoDeposited
          : NotificationKind.goalAutoDepositFailed,
      // Gộp theo KỲ, không theo lượt quét: quét chạy sau mọi lần đồng bộ, nên
      // thiếu đơn vị lặp lại là mỗi lần mở app lại thêm một "Đã trích 500
      // nghìn" cho việc chỉ xảy ra một lần. Hai kỳ khác nhau vẫn phải ra hai
      // thông báo — trích bù hai tháng là hai lần tiền rời ví.
      dedupeKey: thanhCong
          ? 'goalAuto:${khoaKyTrich(e.goalId, e.ky)}'
          : 'goalAutoFail:${khoaKyTrich(e.goalId, e.ky)}',
      title: thanhCong ? 'Đã trích tiền tự động' : 'Chưa trích được tự động',
      body: thanhCong
          ? 'Đã chuyển ${_tien(e.soTien)}$tuVi vào mục tiêu ${e.goalName}.'
          : e.loai == LoaiTrich.viKhongDu
              ? 'Ví nguồn không đủ tiền cho kỳ trích của mục tiêu '
                  '${e.goalName}. Kỳ này sẽ tự thử lại.'
              : 'Không trích được cho mục tiêu ${e.goalName}: ví nguồn không '
                  'còn dùng được. Mở mục tiêu để chọn lại ví.',
      severity: thanhCong
          ? NotificationSeverity.info
          : NotificationSeverity.warning,
      subjectType: 'goal',
      subjectId: e.goalId,
      deeplink: goalDeeplink(e.goalId),
      // Mốc sự kiện là KỲ TRÍCH, không phải lúc quét — nếu không thì
      // `silenceBefore` không loại được những kỳ trích bù từ nửa năm trước, và
      // lần mở app đầu tiên sẽ đổ ra cả chục thông báo cùng lúc.
      createdAt: e.ky,
    ));
  }

  return ra;
}

/// Báo kết quả của các kỳ tự động thanh toán hoá đơn.
///
/// Cùng lý lẽ với [_autoDepositCandidates]: đây là chỗ thứ hai trong app tự
/// chuyển tiền khi người dùng vắng mặt, nên thành công cũng phải báo (bao
/// nhiêu, từ ví nào) và thất bại càng phải báo (nếu không họ tin hoá đơn đã
/// trả rồi phát hiện khi bị cắt điện).
///
/// Khác một điểm: `createdAt` là **lúc quét**, không phải mốc kỳ. Tiền rời ví
/// lúc quét, và cửa sổ im lặng không được nuốt một khoản trả bù cho kỳ hai
/// tháng trước — trần 3 kỳ mỗi lượt của bộ chạy đã chặn cơn lũ rồi.
List<NotificationCandidate> _autoPayCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final e in input.autoPays) {
    final thanhCong = e.loai == LoaiTuTra.traDu;
    final khoa = khoaKyTuTra(e.billId, e.ky);
    final tuVi = e.tenVi == null ? '' : ' từ ví ${e.tenVi}';

    ra.add(NotificationCandidate(
      kind: thanhCong
          ? NotificationKind.billAutoPaid
          : NotificationKind.billAutoPayFailed,
      // Gộp theo KỲ: mỗi kỳ là một hàng riêng nên id + ngày hạn là đủ. Ví
      // thiếu tiền thử lại ở mọi lượt quét nhưng chỉ báo một lần cho kỳ ấy.
      dedupeKey: thanhCong ? 'billAuto:$khoa' : 'billAutoFail:$khoa',
      title: thanhCong ? 'Đã tự thanh toán hoá đơn' : 'Chưa tự trả được hoá đơn',
      body: thanhCong
          ? 'Đã trả ${e.billName} ${_tien(e.soTien)}$tuVi.'
          : e.loai == LoaiTuTra.viKhongDu
              ? 'Ví ${e.tenVi ?? ''} không đủ tiền để tự trả ${e.billName}. '
                  'Sẽ tự thử lại ở lần mở app sau.'
              : 'Không tự trả được ${e.billName}: ví hoặc danh mục không còn '
                  'dùng được. Mở hoá đơn để chọn lại.',
      severity: thanhCong
          ? NotificationSeverity.info
          : NotificationSeverity.warning,
      subjectType: 'bill',
      subjectId: e.billId,
      deeplink: '/bills',
      createdAt: input.now,
    ));
  }

  return ra;
}

// ── Ví ───────────────────────────────────────────────────────────────────────

/// Giá trị cột `type` của ví nợ.
///
/// Cột lưu chuỗi thô (`cash` | `saving` | `bank` | `ewallet` | `investment` |
/// `debt`) và dự án chưa có enum dùng chung cho nó; hằng số này ít nhất giữ
/// chuỗi ấy khỏi nằm trần giữa một câu lệnh điều kiện.
const String _loaiViNo = 'debt';

List<NotificationCandidate> _walletCandidates(NotificationRuleInput input) {
  final ra = <NotificationCandidate>[];

  for (final v in input.wallets) {
    if (v.isDeleted) continue;

    // Ví nợ mang số dư âm là ĐÚNG bản chất của nó, không phải dấu hiệu ghi
    // nhầm. Trước 2026-09-07 nó bị nhắc lại mỗi ngày cho tới khi trả hết nợ —
    // đúng loại nhiễu khiến người dùng tắt cả nhóm, và khi ấy họ mất luôn
    // những cảnh báo thật sự cần.
    if (v.type == _loaiViNo) continue;

    // Số dư 0 là chuyện bình thường; âm mới là dấu hiệu ghi nhầm giao dịch.
    if (v.balance >= 0) {
      final nguong = input.lowBalanceThreshold;

      // `0` là TẮT, không phải "báo khi hết sạch". Đây là mặc định của tuỳ
      // chọn, nên hiểu nó thành một ngưỡng thật là bật tính năng cho mọi bản
      // đã cài mà người dùng chưa hề đặt gì.
      if (nguong <= 0 || v.balance > nguong) continue;

      ra.add(NotificationCandidate(
        kind: NotificationKind.walletLowBalance,
        // Gộp theo NGÀY, cùng lý lẽ với ví âm: ví ở trạng thái cạn cho tới khi
        // người dùng nạp tiền.
        dedupeKey: 'walletLow:${v.id}:${_ngayGon(_dauNgay(input.now))}',
        title: 'Số dư ví sắp cạn',
        body: '${v.name} chỉ còn ${_tien(v.balance)}.',
        // Cảnh báo, không phải nghiêm trọng: ví cạn là chuyện còn kịp xử lý,
        // chỉ ví ÂM mới là dấu hiệu có gì đó đã sai.
        severity: NotificationSeverity.warning,
        subjectType: 'wallet',
        subjectId: v.id,
        deeplink: '/wallets',
        createdAt: input.now,
      ));
      continue;
    }

    // Số dư âm cũng thoả điều kiện "dưới ngưỡng". `continue` ở nhánh trên là
    // thứ giữ cho mỗi ví chỉ ra MỘT thông báo — không có nó thì mỗi ví âm đẻ
    // hai thông báo nói cùng một chuyện.
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
