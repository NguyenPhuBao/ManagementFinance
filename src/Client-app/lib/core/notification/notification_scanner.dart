import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import '../sync/sync_models.dart';
import '../../features/budget/data/models/budget_entity.dart';
import 'notification_rules.dart';

/// Nạp ngân sách kèm số đã chi cho một tài khoản tại một mốc thời gian.
///
/// Cố ý là closure chứ không phải cả `BudgetRepository`: scanner chỉ cần đúng
/// một phép đọc, và thu hẹp phụ thuộc thì test không phải giả lập chục phương
/// thức không liên quan.
typedef BudgetViewsLoader = Future<List<BudgetView>> Function(
    int idaccount, DateTime now);

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
  final Stream<SyncStatus> syncStatus;
  final DateTime Function() clock;
  final String Function() idGenerator;

  StreamSubscription<SyncStatus>? _sub;
  int? _idaccount;

  /// Chặn hai lượt quét chồng nhau: một lượt đang chạy mà sự kiện đồng bộ tiếp
  /// theo nổ thì lượt sau bị bỏ, không xếp hàng. Kết quả không mất gì — lượt
  /// đang chạy đọc trạng thái mới nhất, và `insertOrIgnore` lo phần còn lại.
  bool _dangQuet = false;

  NotificationScanner({
    required this.dao,
    required this.loadBudgets,
    required this.syncStatus,
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
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _idaccount = null;
  }

  /// Trả về **số hàng thật sự được ghi** — tín hiệu duy nhất để quyết định có
  /// bắn thông báo ra hệ điều hành hay không.
  Future<int> scan(int idaccount, {DateTime? now}) async {
    if (_dangQuet) return 0;
    _dangQuet = true;
    try {
      final at = now ?? clock();
      final budgets = await loadBudgets(idaccount, at);

      final ungVien = buildNotificationCandidates(
        NotificationRuleInput(now: at, budgets: budgets),
      );
      if (ungVien.isEmpty) return 0;

      final moi = await dao.insertAllIfAbsent([
        for (final c in ungVien) _toCompanion(c, idaccount),
      ]);
      return moi.length;
    } finally {
      _dangQuet = false;
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
