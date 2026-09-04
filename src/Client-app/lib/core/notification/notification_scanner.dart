import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import '../sync/sync_models.dart';
import '../../features/budget/data/models/budget_entity.dart';
import 'notification_rules.dart';
import 'os/os_notifier.dart';
import 'os/os_scheduled_id.dart';

/// Nạp ngân sách kèm số đã chi cho một tài khoản tại một mốc thời gian.
///
/// Cố ý là closure chứ không phải cả `BudgetRepository`: scanner chỉ cần đúng
/// một phép đọc, và thu hẹp phụ thuộc thì test không phải giả lập chục phương
/// thức không liên quan.
typedef BudgetViewsLoader = Future<List<BudgetView>> Function(
    int idaccount, DateTime now);

/// Nạp hoá đơn tới hạn trong cửa sổ nhắc. Cùng lý do như trên: closure thay vì
/// cả một repository.
typedef BillsLoader = Future<List<Bill>> Function(int idaccount, DateTime now);

/// Đánh dấu hoá đơn đã quá hạn. Trả về số hàng đổi.
typedef OverdueMarker = Future<int> Function(int idaccount, DateTime now);

/// Chạy bộ luật rồi ghi kết quả xuống bảng thông báo.
///
/// ## Khi nào quét
///
/// Chỉ hai mốc, **không có `Timer.periodic`**: dữ liệu ngân sách/hoá đơn/mục
/// tiêu chỉ đổi khi có ghi cục bộ hoặc pull về, mà cả hai đều kết thúc bằng một
/// trạng thái `isTerminal` trên `SyncEngine.statusStream`. Quét đúng lúc dữ
/// liệu vừa đổi là rẻ nhất và đúng nhất; một bộ đếm giờ 15 phút trong một app
/// mở vài phút mỗi ngày gần như không bao giờ nổ lần thứ hai.
class NotificationScanner {
  final NotificationDao dao;
  final BudgetViewsLoader loadBudgets;
  final BillsLoader loadBills;

  /// Tuỳ chọn: bỏ trống thì scanner chỉ đọc, không ghi gì ngoài bảng thông báo.
  final OverdueMarker? markOverdue;

  /// Tuỳ chọn: bỏ trống thì chỉ có trung tâm thông báo trong app (web).
  final OsNotifier? osNotifier;

  final Stream<SyncStatus> syncStatus;
  final DateTime Function() clock;
  final String Function() idGenerator;

  StreamSubscription<SyncStatus>? _sub;
  int? _idaccount;

  /// Chặn hai lượt quét chồng nhau: một lượt đang chạy mà sự kiện đồng bộ tiếp
  /// theo nổ thì lượt sau bị bỏ, không xếp hàng. Kết quả không mất gì — lượt
  /// đang chạy đọc trạng thái mới nhất, và `insertOrIgnore` lo phần còn lại.
  bool _dangQuet = false;

  /// Sự kiện cũ hơn mốc này không được sinh thông báo.
  ///
  /// Chặn cơn lũ ở lần bật tính năng đầu tiên: không có nó thì lượt quét đầu
  /// nhìn thấy mọi hoá đơn quá hạn của mấy tháng trước và bắn hàng chục thông
  /// báo cùng lúc. Ba mươi ngày cũng là ngưỡng hợp lý cho việc "còn đáng nhắc
  /// nữa không" — quá hạn hai tháng thì người dùng đã biết rồi.
  static const Duration cuaSoSuKien = Duration(days: 30);

  NotificationScanner({
    required this.dao,
    required this.loadBudgets,
    required this.loadBills,
    required this.syncStatus,
    this.markOverdue,
    this.osNotifier,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? _uuid;

  /// Bắt đầu theo dõi cho [idaccount].
  ///
  /// **Luỹ đẳng theo listener**: huỷ subscription cũ trước khi tạo mới, đúng
  /// như `SyncEngine.start()` làm với `_connectivitySub`. Không có bước huỷ đó
  /// thì mỗi lần gọi lại là thêm một listener, và một sự kiện đồng bộ sẽ kích
  /// hoạt n lượt quét.
  Future<void> start(int idaccount) async {
    await _sub?.cancel();
    _idaccount = idaccount;
    _sub = syncStatus.listen((s) {
      if (!s.isTerminal) return;
      final id = _idaccount;
      if (id == null) return;
      // Bỏ qua lỗi ở đây: quét thất bại không được làm hỏng vòng đồng bộ.
      unawaited(scan(id).catchError((_) => 0));
    });
  }

  /// Dừng hẳn. Gọi khi đăng xuất hoặc khi phiên chết.
  ///
  /// **Phải huỷ cả lịch phía hệ điều hành**, không chỉ cắt subscription. Lịch
  /// nằm trong AlarmManager (Android) / UNUserNotificationCenter (iOS) chứ
  /// không trong SQLite, nên `purgeDataForOtherAccounts` không chạm tới được:
  /// thiếu bước này thì nhắc hoá đơn của người đăng nhập trước vẫn nổ **trên
  /// màn hình khoá** sau khi người khác đăng nhập — dữ liệu tài chính ra khỏi
  /// app hoàn toàn.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _idaccount = null;
    // Nuốt lỗi: đăng xuất không được phép thất bại vì hệ điều hành trở chứng.
    try {
      await osNotifier?.cancelAll();
    } catch (_) {}
  }

  /// Trả về **số hàng thật sự được ghi** — tín hiệu duy nhất để quyết định có
  /// bắn thông báo ra hệ điều hành hay không.
  Future<int> scan(int idaccount, {DateTime? now}) async {
    if (_dangQuet) return 0;
    _dangQuet = true;
    try {
      final at = now ?? clock();

      // Chạy TRƯỚC khi nạp: hoá đơn đọc lên phải mang trạng thái mới nhất, nếu
      // không thì thông báo nói "quá hạn" trong khi bản ghi vẫn ghi 'Pending'.
      await markOverdue?.call(idaccount, at);

      final budgets = await loadBudgets(idaccount, at);
      final bills = await loadBills(idaccount, at);

      final ungVien = buildNotificationCandidates(
        NotificationRuleInput(
          now: at,
          budgets: budgets,
          bills: bills,
          silenceBefore: at.subtract(cuaSoSuKien),
        ),
      );
      if (ungVien.isEmpty) return 0;

      final moi = await dao.insertAllIfAbsent([
        for (final c in ungVien) _toCompanion(c, idaccount),
      ]);

      // Bắn theo danh sách VỪA GHI, không phải danh sách ứng viên: `ungVien`
      // chứa lại đúng những sự kiện cũ ở mọi lượt quét, và quét chạy sau mỗi
      // lần đồng bộ. Bắn theo ứng viên là người dùng nhận lại cùng một thông
      // báo mỗi lần mở app.
      await _banRaHeDieuHanh(moi);

      return moi.length;
    } finally {
      _dangQuet = false;
    }
  }

  /// Đẩy các hàng vừa ghi ra hệ điều hành.
  ///
  /// Mọi lỗi bị nuốt **từng cái một**: người dùng từ chối quyền thông báo là
  /// chuyện thường, và để lỗi đó nổi lên là mất luôn trung tâm thông báo trong
  /// app — tức là mất phần vẫn còn dùng được. Nuốt riêng từng cái để một thông
  /// báo hỏng không chặn những cái sau.
  Future<void> _banRaHeDieuHanh(List<AppNotificationsCompanion> moi) async {
    final os = osNotifier;
    if (os == null || moi.isEmpty) return;

    for (final e in moi) {
      try {
        await os.show(
          id: osScheduledId(e.dedupeKey.value),
          title: e.title.value,
          body: e.body.value,
          payload: e.dedupeKey.value,
        );
      } catch (_) {
        // Bỏ qua có chủ ý — xem chú thích trên.
      }
    }
  }

  AppNotificationsCompanion _toCompanion(
    NotificationCandidate c,
    int idaccount,
  ) {
    return AppNotificationsCompanion.insert(
      id: idGenerator(),
      idaccount: idaccount,
      kind: c.kind.name,
      dedupeKey: c.dedupeKey,
      title: c.title,
      body: c.body,
      severity: c.severity.name,
      subjectType: Value(c.subjectType),
      subjectId: Value(c.subjectId),
      deeplink: Value(c.deeplink),
      createdAt: c.createdAt,
    );
  }
}

String _uuid() => const Uuid().v4();
