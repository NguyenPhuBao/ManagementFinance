import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:drift/drift.dart';

import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'sync_models.dart';
import 'category_icon_registry.dart';
import 'sync_checkpoint_store.dart';
import 'sync_payload_normalizer.dart';

/// SyncEngine — bộ máy đồng bộ offline-first.
///
/// ## Chiến lược:
/// - **Local-first:** Mọi thao tác ghi vào SQLite ngay (syncStatus = 'pending').
/// - **Background sync:** SyncEngine theo dõi kết nối mạng và tự
///   động sync khi có internet.
/// - **Debounce:** Tránh gửi quá nhiều request liên tiếp — gom
///   các thay đổi trong 2 giây rồi mới gửi 1 batch.
/// - **Conflict resolution:** Last-Write-Wins dựa trên `updatedAt`.
///   Record nào có `updatedAt` mới hơn sẽ "thắng".
///
/// ## Cách dùng:
/// ```dart
/// // Đăng ký với GetIt:
/// sl<SyncEngine>().start(idaccount: currentUser.idaccount);
///
/// // Trigger manual (sau khi ghi local):
/// sl<SyncEngine>().scheduleSync();
/// ```
class SyncEngine {
  // ignore: unused_field — sẽ dùng ở Plan 6 khi backend có sync API
  final DioClient _dioClient;
  final AppDatabase _db;
  final Connectivity _connectivity;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _sessionInvalidController = StreamController<void>.broadcast();

  /// Phát tín hiệu khi server cho thấy phiên đăng nhập trỏ tới một tài khoản
  /// không còn tồn tại (vỡ khoá ngoại `fk_*_account` khi đẩy dữ liệu).
  ///
  /// Dùng kênh RIÊNG chứ không nhét vào [statusStream], vì `stop()` kết thúc
  /// bằng `_setStatus(idle)` nên sẽ ghi đè mất trạng thái lỗi vừa phát.
  Stream<void> get sessionInvalidStream => _sessionInvalidController.stream;

  void _emitSessionInvalid() {
    if (_disposed || _sessionInvalidController.isClosed) return;
    _sessionInvalidController.add(null);
  }

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySub;
  int? _currentIdaccount;

  static const _debounceSeconds = 2;

  /// Chu kỳ đồng bộ nền. Nếu không có, thiết bị này sẽ không bao giờ biết thiết
  /// bị khác vừa thay đổi gì cho tới khi chính nó ghi dữ liệu hoặc đổi mạng.
  static const _periodicSyncMinutes = 15;

  /// Giãn cách sau mỗi chu kỳ đồng bộ hỏng liên tiếp.
  ///
  /// Chỉ giữ trong RAM: một bản bền vững qua các lần mở app cần thêm cột vào
  /// lược đồ SQLite (xem G3 trong `docs/CLIENT_APP_KNOWN_GAPS.md`).
  static const List<Duration> _backoffSteps = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  int _consecutiveFailures = 0;
  DateTime? _nextAllowedSyncAt;

  /// Hẹn giờ chạy lại chu kỳ đã bị nhánh giãn cách từ chối.
  ///
  /// Cần vì các nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên: timer 15
  /// phút, đổi trạng thái mạng, và `start()` lúc mở app. Trước bản vá này,
  /// nhánh chặn chỉ `return` — một thay đổi ghi trong lúc giãn cách nằm chờ
  /// đúng một trong ba nguồn đó, dài hơn bậc giãn cách rất nhiều.
  ///
  /// Đo được trên app thật (2026-09-03): xoá một ngân sách trong lúc engine
  /// đang giãn cách thì thao tác **không** lên tới backend, kể cả sau khi hết
  /// giãn cách; phải mở lại app mới đẩy được. Người dùng thấy mục biến mất
  /// ngay nên tin là đã xong, còn máy khác vẫn thấy nó nguyên vẹn.
  Timer? _backoffRetryTimer;
  DateTime? _backoffRetryAt;

  /// Mốc mà hẹn giờ chạy lại sẽ nổ, `null` khi không nợ ai lần chạy nào.
  @visibleForTesting
  DateTime? get backoffRetryAt => _backoffRetryAt;

  /// Hẹn chạy lại đúng lúc [until] — mốc hết giãn cách.
  ///
  /// Cố ý **không** dựng hẹn giờ mới cho mỗi lần bị chặn: mỗi thao tác ghi đều
  /// gọi `scheduleSync()`, nên làm vậy sẽ đẩy mốc chạy lại lùi mãi về sau.
  void _scheduleBackoffRetry(DateTime until) {
    if (_disposed) return;
    if (_backoffRetryAt == until && (_backoffRetryTimer?.isActive ?? false)) {
      return;
    }
    _backoffRetryTimer?.cancel();
    _backoffRetryAt = until;
    final remaining = until.difference(_now());
    _backoffRetryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _backoffRetryAt = null;
        unawaited(_runSync());
      },
    );
  }

  void _cancelBackoffRetry() {
    _backoffRetryTimer?.cancel();
    _backoffRetryTimer = null;
    _backoffRetryAt = null;
  }

  /// Đồng hồ — tiêm được để test không phải chờ thật 30 giây.
  final DateTime Function() _now;

  @visibleForTesting
  int get consecutiveFailures => _consecutiveFailures;

  @visibleForTesting
  DateTime? get nextAllowedSyncAt => _nextAllowedSyncAt;

  void _registerFailedCycle() {
    _consecutiveFailures++;
    final step = _backoffSteps[
        (_consecutiveFailures - 1).clamp(0, _backoffSteps.length - 1)];
    _nextAllowedSyncAt = _now().add(step);
  }


  /// Bản ghi có đang bị chặn khỏi hàng đợi đẩy không (G3).
  ///
  /// Chặn theo THỜI GIAN chứ không loại hẳn: nhiều lỗi chỉ tự khỏi sau khi Pull
  /// xong, nên một bản ghi bị gạt vĩnh viễn sẽ không bao giờ được sửa.
  bool _isSyncBlocked(DateTime? blockedUntil) =>
      blockedUntil != null && _now().isBefore(blockedUntil);

  Future<void> _markBlockedById(
    SyncEntityType entity,
    String id,
    DateTime until,
    String error,
  ) async {
    switch (entity) {
      case SyncEntityType.wallet:
        await _db.walletDao.markSyncBlocked(id, until, error);
      case SyncEntityType.transaction:
        await _db.transactionDao.markSyncBlocked(id, until, error);
      case SyncEntityType.category:
        await _db.categoryDao.markSyncBlocked(id, until, error);
      case SyncEntityType.budget:
        await _db.budgetDao.markSyncBlocked(id, until, error);
      case SyncEntityType.bill:
        await _db.billDao.markSyncBlocked(id, until, error);
      case SyncEntityType.goal:
        await _db.goalDao.markSyncBlocked(id, until, error);
    }
  }
  void _resetBackoff() {
    _consecutiveFailures = 0;
    _nextAllowedSyncAt = null;
    // Không còn giãn cách thì cũng không còn gì để chờ — một hẹn giờ sót lại
    // chỉ chạy thêm một chu kỳ thừa.
    _cancelBackoffRetry();
  }

  bool _hasCompletedPull = false;

  /// Đã kéo dữ liệu về thành công ít nhất một lần trong phiên này chưa.
  ///
  /// Dùng để biết khi nào **đã có thể tin** vào nội dung SQLite cục bộ. Trước
  /// khi pull xong, một CSDL rỗng không phân biệt được với "tài khoản chưa có
  /// gì" — và `PersonalDefaultCategories` từng vấp đúng chỗ đó: nó tạo 5 danh
  /// mục trên một máy mới trong khi tài khoản đã có sẵn chúng ở backend, sinh
  /// ra 5 thao tác đẩy hỏng vĩnh viễn (G14).
  ///
  /// Cố ý **không** suy ra từ `_lastPullTime`: mốc đó chỉ được đặt khi có dữ
  /// liệu trả về, nên tài khoản mới toanh sẽ mãi trông như chưa pull lần nào.
  bool get hasCompletedPull => _hasCompletedPull;

  /// Nơi lưu mốc pull gần nhất. Null (thường là trong test) → chỉ giữ trong RAM
  /// như hành vi cũ.
  final SyncCheckpointStore? _checkpointStore;

  SyncEngine({
    required DioClient dioClient,
    required AppDatabase db,
    Connectivity? connectivity,
    SyncCheckpointStore? checkpointStore,
    DateTime Function()? now,
  })  : _dioClient = dioClient,
        _db = db,
        _checkpointStore = checkpointStore,
        _now = now ?? DateTime.now,
        _connectivity = connectivity ?? Connectivity();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Khởi động SyncEngine sau khi user đăng nhập thành công.
  Future<void> start({required int idaccount}) async {
    // Đăng nhập / mở app là hành động chủ động của người dùng — xoá giãn cách
    // của phiên trước để họ không phải chờ hết một chu kỳ backoff cũ.
    _resetBackoff();
    _currentIdaccount = idaccount;
    // Khôi phục mốc pull đã lưu để không phải kéo lại toàn bộ dữ liệu mỗi lần
    // mở app. Nếu SQLite cục bộ rỗng, _pullFromBackend vẫn tự ép full pull nên
    // không sợ thiếu dữ liệu khi cài lại app.
    _lastPullTime = await _checkpointStore?.read(idaccount);

    // Lắng nghe thay đổi kết nối
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncEngine] Network restored — scheduling sync');
        unawaited(syncNow());
      }
    });

    // Đồng bộ nền định kỳ để nhận thay đổi từ thiết bị khác.
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: _periodicSyncMinutes),
      (_) => unawaited(syncNow()),
    );

    // Kích hoạt đồng bộ LẬP TỨC ngay khi vừa đăng nhập (không cần chờ thao tác)
    await syncNow();
  }

  /// Dừng SyncEngine khi logout.
  void stop() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _connectivitySub?.cancel();
    _currentIdaccount = null;
    // Phiên sau có thể là tài khoản khác — cờ của phiên này không nói được gì
    // về CSDL cục bộ của tài khoản đó.
    _hasCompletedPull = false;
    _resetBackoff();
    // Chỉ xoá mốc trong RAM. Mốc đã lưu được giữ lại theo từng idaccount để lần
    // đăng nhập sau vẫn pull tăng dần; nếu dữ liệu cục bộ đã bị xoá thì
    // _pullFromBackend tự ép full pull.
    _lastPullTime = null;
    _setStatus(SyncStatus.idle);
  }

  // ── Trigger ───────────────────────────────────────────────────────────────

  /// Kích hoạt đồng bộ LẬP TỨC (Immediate Sync) không cần chờ timer debounce.
  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    await _runSync();
  }

  /// Đặt lịch sync với debounce — gọi liên tiếp chỉ trigger 1 lần.
  void scheduleSync() {
    // Sau logout, `stop()` đặt _currentIdaccount = null nhưng các repository
    // vẫn tiếp tục gọi scheduleSync() sau mỗi lần ghi — bỏ qua cho rẻ.
    if (_currentIdaccount == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(seconds: _debounceSeconds),
      () => _runSync(),
    );
    if (_status == SyncStatus.idle) {
      _setStatus(SyncStatus.pending);
    }
  }

  // ── Core sync logic ───────────────────────────────────────────────────────

  DateTime? _lastPullTime;

  Future<void> _runSync() async {
    // Danh tính CHỈ đến từ phiên đăng nhập, không bao giờ suy ra từ dữ liệu
    // trong SQLite. Trước đây khi `_currentIdaccount` là null hoặc 1, engine
    // đọc `walletDao.getAllNonDeleted()` (không lọc tài khoản) và lấy
    // `idaccount` của ví đầu tiên — đủ để làm sống lại một tài khoản đã bị xoá,
    // hoặc chiếm danh tính của admin (idaccount = 1 vốn là tài khoản THẬT chứ
    // không phải giá trị "chưa biết").
    if (_disposed) return;
    final accountId = _currentIdaccount;
    if (accountId == null || accountId <= 0) {
      debugPrint('[SyncEngine] Chưa có phiên đăng nhập — bỏ qua đồng bộ');
      _setStatus(SyncStatus.idle);
      return;
    }
    if (_status == SyncStatus.syncing) return; // Tránh concurrent sync

    // Giãn dần sau các chu kỳ hỏng liên tiếp. Trước đây thao tác `transient`
    // được thử lại ở MỌI chu kỳ kế tiếp mà không giãn ra, trong khi nguồn kích
    // hoạt thì dày đặc: debounce 2 giây sau mỗi lần ghi, đổi trạng thái mạng,
    // timer 15 phút và mỗi lần start(). Server đang hỏng sẽ nhận đúng lượng
    // request đó lặp lại mãi.
    final blockedUntil = _nextAllowedSyncAt;
    if (blockedUntil != null && _now().isBefore(blockedUntil)) {
      debugPrint('[SyncEngine] Đang trong thời gian giãn cách sau '
          '$_consecutiveFailures chu kỳ hỏng — hoãn tới $blockedUntil');
      // Từ chối một yêu cầu đồng bộ nghĩa là NỢ người gọi một lần chạy. Chỉ
      // `return` ở đây thì thay đổi vừa ghi nằm chờ một nguồn kích hoạt khác —
      // timer 15 phút, đổi mạng, hoặc lần mở app sau.
      _scheduleBackoffRetry(blockedUntil);
      _setStatus(SyncStatus.pending);
      return;
    }

    // Kiểm tra kết nối
    final connectivity = await _connectivity.checkConnectivity();
    final hasConnection = connectivity.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _setStatus(SyncStatus.pending);
      debugPrint('[SyncEngine] No connection — sync deferred');
      return;
    }

    _setStatus(SyncStatus.syncing);
    debugPrint(
        '[SyncEngine] Starting full sync (Push & Pull) for account $accountId');

    try {
      // 1. Push local pending ops to Backend
      final ops = await _collectPendingOps(accountId);
      SyncResult? pushResult;
      if (ops.isNotEmpty) {
        pushResult = await _sendBatch(ops);
        debugPrint('[SyncEngine] Push complete: $pushResult');
      } else {
        debugPrint(
            '[SyncEngine] No pending local ops — proceeding to Pull from backend');
      }

      // Phiên trỏ tới tài khoản không còn tồn tại → thử lại là vô ích, và mỗi
      // chu kỳ lại nhân đôi số request hỏng. Dừng hẳn và báo ra ngoài.
      if (pushResult != null && pushResult.hasSessionInvalid) {
        debugPrint('[SyncEngine] Phiên đăng nhập không còn hợp lệ — dừng đồng bộ');
        _emitSessionInvalid();
        _setStatus(SyncStatus.authExpired);
        return;
      }

      // 2. Pull all updated data from Backend PostgreSQL to SQLite local
      await _pullFromBackend(accountId);

      // Một transaction thất bại có thể đang trỏ tới ID danh mục mặc định cũ;
      // Pull xong mới có UUID từ backend nên đáng thử lại MỘT lần.
      // Chỉ thử lại khi thật sự có lỗi thuộc loại tạm thời — trước đây điều
      // kiện chỉ là `failed > 0` nên lỗi vĩnh viễn cũng bị gửi lại mỗi chu kỳ.
      SyncResult? retryResult;
      if (pushResult != null && pushResult.hasRetryableFailure) {
        final retryOps = await _collectPendingOps(accountId);
        if (retryOps.isNotEmpty) {
          retryResult = await _sendBatch(retryOps);
          debugPrint('[SyncEngine] Push retry complete: $retryResult');
          if (retryResult.hasSessionInvalid) {
            _emitSessionInvalid();
            _setStatus(SyncStatus.authExpired);
            return;
          }
        }
      }

      // Trạng thái kết thúc phải phản ánh kết quả thật. Trước đây chu kỳ nào
      // cũng kết thúc bằng `idle`, kể cả khi mọi thao tác đẩy đều hỏng — nên
      // `SyncStatus.error` gần như là mã chết: `_sendBatch` không ném lỗi ra
      // ngoài nên khối `catch` bên dưới chỉ chạm tới được khi có exception
      // thật sự, chứ không phải khi server từ chối dữ liệu.
      //
      // Lấy kết quả của lần đẩy SAU CÙNG: `_collectPendingOps` gom lại toàn bộ
      // bản ghi còn `pending` nên lần thử lại đã bao gồm cả những thao tác hỏng
      // vĩnh viễn của lần đầu.
      final lastPush = retryResult ?? pushResult;
      final stillFailing = lastPush != null && lastPush.failed > 0;
      if (stillFailing) {
        _registerFailedCycle();
      } else {
        _resetBackoff();
      }
      _setStatus(stillFailing ? SyncStatus.error : SyncStatus.idle);
    } catch (e) {
      debugPrint('[SyncEngine] Sync error: $e');
      _setStatus(SyncStatus.error);
    }
  }

  // ── Pull data from backend to local SQLite ────────────────────────────────

  Future<void> _pullFromBackend(int accountId) async {
    final allWallets = await _db.walletDao.getAll(accountId);
    final isLocalDbEmpty = allWallets.isEmpty;

    final since = (isLocalDbEmpty || _lastPullTime == null)
        ? '1970-01-01T00:00:00.000Z'
        : _lastPullTime!.toUtc().toIso8601String();

    debugPrint(
        '[SyncEngine] Pulling data from backend for account $accountId since $since (isLocalDbEmpty: $isLocalDbEmpty)...');
    try {
      final response = await _dioClient.dio.get(
        '/sync/pull',
        queryParameters: {'since': since},
      );

      if (response.statusCode == 200 && response.data != null) {
        final topData = response.data['data'] as Map<String, dynamic>?;
        // ResponseHandler bọc dữ liệu thành topData['data']['wallets']...
        final Map<String, dynamic>? payloadData =
            (topData != null && topData['data'] is Map<String, dynamic>)
                ? topData['data'] as Map<String, dynamic>?
                : topData;

        if (payloadData != null) {
          // 1. Wallets
          final wallets = (payloadData['wallets'] ?? payloadData['wallet'])
                  as List<dynamic>? ??
              [];
          if (wallets.isNotEmpty) {
            final companions = wallets.map((w) {
              return WalletsCompanion(
                id: Value((w['idwallet'] ?? w['id']).toString()),
                idaccount:
                    Value(int.tryParse(w['idaccount'].toString()) ?? accountId),
                name: Value(w['name'].toString()),
                type: Value(SyncPayloadNormalizer.walletTypeFromBackend(
                    w['type']?.toString() ?? 'Cash')),
                balance: Value(
                    (num.tryParse(w['balance'].toString()) ?? 0.0).toDouble()),
                currency: Value(w['currency']?.toString() ?? 'VND'),
                icon: Value(w['icon']?.toString() ?? 'wallet'),
                colour: Value(
                    (w['color'] ?? w['colour'])?.toString() ?? '#4CAF50'),
                isDefault: Value(w['is_default'] == true),
                isDeleted: Value(w['delete_at'] != null),
                deletedAt: Value(_deletedAtFrom(w['delete_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(w['update_at']?.toString() ?? '') ??
                        DateTime.now()),
              );
            }).toList();
            await _db.walletDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${wallets.length} wallets into SQLite local.');
          }

          // 2. Transactions
          final transactions = (payloadData['transactions'] ??
                  payloadData['transaction']) as List<dynamic>? ??
              [];
          if (transactions.isNotEmpty) {
            final companions = transactions.map((t) {
              return TransactionsCompanion(
                id: Value((t['idtran'] ?? t['id']).toString()),
                idaccount:
                    Value(int.tryParse(t['idaccount'].toString()) ?? accountId),
                walletId: Value((t['idwallet'] ?? t['wallet_id']).toString()),
                categoryId: Value((t['idcategory'] ?? t['category_id'])?.toString()),
                walletTransfer: Value(
                    (t['idwallet_transfer'] ?? t['wallet_transfer'])
                        ?.toString()),
                amount: Value((num.tryParse(t['amount'].toString()) ?? 0.0)
                    .abs()
                    .toDouble()),
                type: Value(SyncPayloadNormalizer.transactionTypeFromBackend(
                  t['type']?.toString() ?? 'Transaction',
                  num.tryParse(t['amount'].toString()) ?? 0,
                )),
                note: Value(t['note']?.toString() ?? ''),
                date: Value(DateTime.tryParse(
                        (t['date_transaction'] ?? t['date'])?.toString() ?? '') ??
                    DateTime.now()),
                isDeleted: Value(t['deleted_at'] != null),
                deletedAt: Value(_deletedAtFrom(t['deleted_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(t['update_at']?.toString() ?? '') ??
                        DateTime.now()),
              );
            }).toList();
            await _db.transactionDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${transactions.length} transactions into SQLite local.');
          }

          // 3. Categories
          final categories = (payloadData['categories'] ??
                  payloadData['category']) as List<dynamic>? ??
              [];
          if (categories.isNotEmpty) {
            final List<CategoriesCompanion> companions = [];
            // Từ khoá phân loại backend gửi kèm mỗi danh mục, gom lại để gieo
            // SAU khi hàng danh mục đã tồn tại ở local.
            final Map<String, List<String>> tuKhoaTheoDanhMuc = {};
            for (final c in categories) {
              final catUuid = (c['idcategory'] ?? c['uuid'] ?? c['id'])
                  .toString();
              if (catUuid.isEmpty || catUuid == 'null') {
                debugPrint('[SyncEngine] Skipping category without an ID.');
                continue;
              }
              final catName =
                  (c['name_category'] ?? c['namecategory'] ?? c['name'] ?? '')
                      .toString();
              final rawIcon = c['icon']?.toString();
              final rawColor = c['colour']?.toString();

              final existingLocal = await _db.categoryDao.getById(catUuid);
              if (existingLocal?.isLocalOnly == true) {
                continue;
              }
              final iconRegistry =
                  await CategoryIconRegistry.getIcon(catUuid, catName);

              String finalIcon;
              if (rawIcon != null &&
                  rawIcon.isNotEmpty &&
                  rawIcon != 'category') {
                finalIcon = rawIcon;
              } else if (existingLocal != null &&
                  existingLocal.icon.isNotEmpty &&
                  existingLocal.icon != 'category') {
                finalIcon = existingLocal.icon;
              } else if (iconRegistry != null &&
                  iconRegistry['icon'] != null &&
                  iconRegistry['icon'] != 'category') {
                finalIcon = iconRegistry['icon']!;
              } else {
                finalIcon = _defaultIconForCategoryName(catName);
              }

              String finalColor;
              if (rawColor != null && rawColor.isNotEmpty) {
                finalColor = rawColor;
              } else if (existingLocal != null &&
                  existingLocal.colour.isNotEmpty) {
                finalColor = existingLocal.colour;
              } else if (iconRegistry != null &&
                  iconRegistry['colour'] != null) {
                finalColor = iconRegistry['colour']!;
              } else {
                finalColor = _defaultColorForCategoryName(catName);
              }

              companions.add(CategoriesCompanion(
                id: Value(catUuid),
                idaccount: Value(c['is_default'] == true
                    ? 0
                    : (int.tryParse(
                            // Backend Prisma field là `create_by` (không có
                            // 'd'). Giữ 'created_by'/'idaccount' làm fallback
                            // để tương thích ngược nếu payload thay đổi.
                            (c['create_by'] ?? c['created_by'] ?? c['idaccount'] ?? 0)
                                .toString()) ??
                        0)),
                name: Value(catName),
                classify: Value(SyncPayloadNormalizer.categoryClassifyFromBackend(
                    c['classify']?.toString() ?? 'Chi')),
                icon: Value(finalIcon),
                colour: Value(finalColor),
                isDefault: Value(c['is_default'] == true),
                // Cấu trúc nhóm do backend lưu (Is_group / Idgroup). BẮT BUỘC
                // phải đọc lại: upsertAll dùng InsertMode.insertOrReplace nên
                // cột nào không gán sẽ bị đưa về mặc định — trước đây điều này
                // xoá sạch nhóm và quan hệ cha–con ở local sau mỗi lần pull.
                isGroup: Value(c['is_group'] == true),
                parentId: Value((c['idgroup'] ?? c['parent_id'])?.toString()),
                // Đọc cờ xoá từ payload như các thực thể khác. Trước đây ghi
                // cứng `false`, nên danh mục đã xoá mềm trên server bị HỒI SINH
                // thành chưa-xoá sau mỗi lần pull — backend không lọc
                // `delete_at` khi trả dữ liệu nên nó vẫn nằm trong response.
                isDeleted: Value(c['delete_at'] != null),
                deletedAt: Value(_deletedAtFrom(c['delete_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(c['update_at']?.toString() ?? '') ??
                        DateTime.now()),
              ));

              // Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy trên hàng
              // category (`classify.repository.js` ghi bằng `join(',')`), client
              // lưu mỗi từ khoá một dòng có `idaccount`. Không tách ra thì cả
              // chuỗi thành một "từ khoá" dài và không bao giờ khớp gì.
              final tuKhoa = (c['keyword'] ?? c['Keyword'])
                      ?.toString()
                      .split(',')
                      .map((k) => k.trim())
                      .where((k) => k.isNotEmpty)
                      .toList() ??
                  const <String>[];
              if (tuKhoa.isNotEmpty && c['delete_at'] == null) {
                tuKhoaTheoDanhMuc[catUuid] = tuKhoa;
              }
            }
            await _db.categoryDao.upsertAll(companions);
            await _gieoTuKhoaKhiTrong(accountId, tuKhoaTheoDanhMuc);
            // Repair TRƯỚC: cập nhật categoryId từ 'cat_food' → UUID trong các
            // pending transactions. PHẢI chạy trước removeDuplicateLocalSeedCategories()
            // vì _resolveCategoryId cần getById('cat_food') để đọc tên category rồi
            // tìm UUID cùng tên — nếu seed 'cat_food' đã bị xóa trước, getById() trả
            // về null và repair sẽ luôn thất bại (transaction bị defer vĩnh viễn).
            final repaired = await _db.transactionDao
                .repairPendingTransactionsCategoryId(_resolveCategoryId);
            if (repaired > 0) {
              debugPrint(
                  '[SyncEngine] Repaired $repaired transactions: updated categoryId to UUID.');
            }
            // Xóa category seed cục bộ (cat_food...) đã có bản UUID từ backend —
            // chạy SAU repair ở trên để không xóa mất row mà repair cần đọc.
            await _db.categoryDao.removeDuplicateLocalSeedCategories();
            // Dọn bản trùng do chính máy này tạo ra trước khi kịp pull (G14).
            // Chạy SAU cùng: hai bước trên vừa dựng lại quan hệ, giờ mới nhìn
            // được toàn cảnh tài khoản đang có gì. Không dọn thì mỗi bản trùng
            // là một thao tác đẩy hỏng vĩnh viễn, và giãn cách luỹ tiến kéo
            // chậm mọi thay đổi khác.
            final gopTrung = await _db.categoryDao
                .mergeDuplicatePersonalCategories(accountId);
            if (gopTrung > 0) {
              debugPrint(
                  '[SyncEngine] Đã gộp $gopTrung danh mục trùng tên do máy này tự tạo.');
            }
            debugPrint(
                '[SyncEngine] Pulled & Saved ${categories.length} categories into SQLite local.');
          }

          // 4. Budgets
          final budgets = (payloadData['budgets'] ?? payloadData['budget'])
                  as List<dynamic>? ??
              [];
          if (budgets.isNotEmpty) {
            final companions = budgets.map((b) {
              // Backend trả field Prisma thật: idbudget, idcategory,
              // total_amount, start, end, delete_at, update_at (không phải
              // id/category_id/amount/start_date/is_deleted/updated_at).
              return BudgetsCompanion(
                id: Value((b['idbudget'] ?? b['id']).toString()),
                idaccount:
                    Value(int.tryParse(b['idaccount'].toString()) ?? accountId),
                categoryId: Value((b['idcategory'] ?? b['category_id'])?.toString()),
                amount: Value((num.tryParse(
                            (b['total_amount'] ?? b['amount']).toString()) ??
                        0.0)
                    .toDouble()),
                spent: Value(
                    (num.tryParse((b['spent'] ?? 0).toString()) ?? 0.0)
                        .toDouble()),
                thresholdWarningAmount: Value(
                    b['threshold_warning_amount'] != null
                        ? num
                            .tryParse(b['threshold_warning_amount'].toString())
                            ?.toDouble()
                        : null),
                // Backend lưu 0–100 (`Decimal(15,2)`), client giữ nguyên đơn vị
                // đó — việc quy về tỉ lệ nằm ở `BudgetEntity.warningRatio`.
                thresholdWarningPercent: Value(
                    b['threshold_warning_percent'] != null
                        ? num
                            .tryParse(b['threshold_warning_percent'].toString())
                            ?.toDouble()
                        : null),
                overSpending: Value(b['over_spending']?.toString() ?? 'Over'),
                overAmount: Value(b['over_amount'] != null
                    ? num.tryParse(b['over_amount'].toString())?.toDouble()
                    : null),
                startDate: Value(DateTime.tryParse(
                        (b['start'] ?? b['start_date'])?.toString() ?? '') ??
                    DateTime.now()),
                endDate: Value((b['end'] ?? b['end_date']) != null
                    ? DateTime.tryParse((b['end'] ?? b['end_date']).toString())
                    : null),
                recurrence: Value(b['recurrence'] == true),
                timeRecurrence:
                    Value(b['time_recurrence']?.toString() ?? 'Month'),
                nextTimeRecurrence: Value(b['nexttime_recurrence'] != null
                    ? DateTime.tryParse(b['nexttime_recurrence'].toString())
                    : null),
                note: Value(b['note']?.toString() ?? ''),
                isDeleted: Value(b['delete_at'] != null),
                deletedAt: Value(_deletedAtFrom(b['delete_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(
                        (b['update_at'] ?? b['updated_at'])?.toString() ??
                            '') ??
                    DateTime.now()),
              );
            }).toList();
            await _db.budgetDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${budgets.length} budgets into SQLite local.');
          }

          // 5. Bills
          final bills =
              (payloadData['bills'] ?? payloadData['bill']) as List<dynamic>? ??
                  [];
          if (bills.isNotEmpty) {
            final companions = bills.map((bill) {
              // Backend trả field Prisma thật: idbill, idwallet, idcategory,
              // start_date, due_date, pay_status, delete_at, update_at
              // (không phải id/is_paid/is_deleted/updated_at).
              final payStatus = bill['pay_status']?.toString() ?? 'Pending';
              return BillsCompanion(
                id: Value((bill['idbill'] ?? bill['id']).toString()),
                idaccount: Value(
                    int.tryParse(bill['idaccount'].toString()) ?? accountId),
                walletId:
                    Value((bill['idwallet'] ?? bill['wallet_id'])?.toString()),
                categoryId: Value(
                    (bill['idcategory'] ?? bill['category_id'])?.toString()),
                name: Value(bill['name'].toString()),
                amount: Value((num.tryParse(bill['amount'].toString()) ?? 0.0)
                    .toDouble()),
                startDate: Value(bill['start_date'] != null
                    ? DateTime.tryParse(bill['start_date'].toString())
                    : null),
                dueDate: Value(
                    DateTime.tryParse(bill['due_date']?.toString() ?? '') ??
                        DateTime.now()),
                payStatus: Value(payStatus),
                isPaid: Value(payStatus == 'Payed'),
                timeNotification: Value(bill['time_notification']?.toString()),
                isRecurrence: Value(bill['recurrence'] == true),
                timeRecurrence:
                    Value(bill['time_recurrence']?.toString() ?? 'Month'),
                icon: Value(bill['icon']?.toString() ?? 'receipt'),
                colour: Value(bill['color']?.toString() ?? '#4CAF50'),
                note: Value(bill['note']?.toString() ?? ''),
                isDeleted: Value(bill['delete_at'] != null),
                deletedAt: Value(_deletedAtFrom(bill['delete_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(
                        (bill['update_at'] ?? bill['updated_at'])
                                ?.toString() ??
                            '') ??
                    DateTime.now()),
              );
            }).toList();
            await _db.billDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${bills.length} bills into SQLite local.');
          }

          // 6. Goals
          final goals =
              (payloadData['goals'] ?? payloadData['goal']) as List<dynamic>? ??
                  [];
          if (goals.isNotEmpty) {
            final companions = goals.map((g) {
              // Backend trả field Prisma thật: idgoal, idwallet,
              // status_complete, delete_at, update_at (không phải
              // id/wallet_id/is_deleted/updated_at).
              return GoalsCompanion(
                id: Value((g['idgoal'] ?? g['id']).toString()),
                idaccount:
                    Value(int.tryParse(g['idaccount'].toString()) ?? accountId),
                name: Value(g['name'].toString()),
                targetAmount: Value(
                    (num.tryParse(g['target_amount'].toString()) ?? 0.0)
                        .toDouble()),
                currentAmount: Value(
                    (num.tryParse(g['current_amount'].toString()) ?? 0.0)
                        .toDouble()),
                startDate: Value(g['start_date'] != null
                    ? DateTime.tryParse(g['start_date'].toString())
                    : null),
                targetDate: Value(
                    DateTime.tryParse(g['target_date']?.toString() ?? '') ??
                        DateTime.now()),
                walletId: Value((g['idwallet'] ?? g['wallet_id'])?.toString()),
                cycleTakeMoney: Value(g['cycle_take_money']?.toString()),
                timeCycleTakeMoney: Value(g['time_cycle_take_money'] != null
                    ? DateTime.tryParse(g['time_cycle_take_money'].toString())
                    : null),
                recurrence: Value(g['recurrence'] == true),
                timeRecurrence: Value(g['time_recurrence']?.toString()),
                icon: Value(g['icon']?.toString() ?? 'flag'),
                colour: Value(g['color']?.toString() ?? '#4CAF50'),
                note: Value(g['note']?.toString() ?? ''),
                isCompleted:
                    Value(g['status_complete']?.toString() == 'True'),
                isDeleted: Value(g['delete_at'] != null),
                deletedAt: Value(_deletedAtFrom(g['delete_at'])),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(
                        (g['update_at'] ?? g['updated_at'])?.toString() ??
                            '') ??
                    DateTime.now()),
              );
            }).toList();
            await _db.goalDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${goals.length} goals into SQLite local.');
          }

          // Mốc mới = `update_at` LỚN NHẤT trong dữ liệu vừa nhận, KHÔNG phải
          // DateTime.now() của client: backend lọc `update_at > since` theo
          // đồng hồ của nó, nên lấy giờ client sẽ bỏ sót bản ghi khi hai đồng
          // hồ lệch nhau. Không nhận được bản ghi nào thì giữ nguyên mốc cũ
          // (cùng lắm là pull lại một ít, không bao giờ mất dữ liệu).
          final newest = _newestUpdateAt(payloadData);
          if (newest != null) {
            _lastPullTime = newest;
            await _checkpointStore?.write(accountId, newest);
          }
          // Cờ RIÊNG, không suy ra từ `_lastPullTime`: mốc đó chỉ được đặt khi
          // có dữ liệu trả về, nên một tài khoản mới toanh (chưa có gì trên
          // server) sẽ mãi mãi trông như "chưa pull lần nào".
          _hasCompletedPull = true;
        }
      }
    } catch (e) {
      debugPrint('[SyncEngine] HTTP Sync Pull Error: $e');
    }
  }

  /// Tìm `update_at` mới nhất trong toàn bộ payload pull (mọi loại thực thể).
  static DateTime? _newestUpdateAt(Map<String, dynamic> payloadData) {
    DateTime? newest;
    for (final value in payloadData.values) {
      if (value is! List) continue;
      for (final row in value) {
        if (row is! Map) continue;
        final raw = (row['update_at'] ?? row['updated_at'])?.toString();
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw)?.toUtc();
        if (parsed == null) continue;
        if (newest == null || parsed.isAfter(newest)) newest = parsed;
      }
    }
    return newest;
  }

  // ── Collect pending operations ────────────────────────────────────────────

  Future<List<SyncOperation>> _collectPendingOps(int idaccount) async {
    final ops = <SyncOperation>[];
    final now = DateTime.now();

    // ── 1. Categories (phải đứng TRƯỚC transactions/budgets/bills) ────────────
    // Transaction.idcategory, Budget.idcategory, Bill.idcategory đều FK → category
    // Nếu categories push sau thì backend báo FK constraint violation.
    final syncableCategories =
        await _db.categoryDao.getSyncableCategories(idaccount);
    // Nhóm phải được đẩy TRƯỚC danh mục con của nó: backend có khoá ngoại
    // fk_category_parent (Idgroup → Idcategory), con đi trước sẽ vi phạm FK.
    syncableCategories.sort((a, b) {
      if (a.isGroup == b.isGroup) return 0;
      return a.isGroup ? -1 : 1;
    });
    for (final c in syncableCategories) {
      if (_isSyncBlocked(c.syncBlockedUntil)) continue;
      final validId = _toValidUuid(c.id);
      String validClassify = c.classify;
      if (validClassify == 'vay_no' || validClassify == 'vay-no') {
        validClassify = 'vay/no';
      }
      ops.add(SyncOperation(
        localId: c.id,
        entity: SyncEntityType.category,
        operation:
            c.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': c.name,
          'namecategory': c.name,
          'classify': validClassify,
          'icon': c.icon,
          'colour': c.colour,
          'is_default': c.isDefault,
          'is_deleted': c.isDeleted,
          // Cấu trúc nhóm — backend mapEntityFields() nhận camelCase:
          // isGroup → Is_group, parentId → Idgroup.
          'isGroup': c.isGroup,
          'parentId': c.parentId != null ? _toValidUuid(c.parentId!) : null,
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
          'idaccount': c.idaccount > 0 ? c.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 2. Wallets (phải đứng TRƯỚC transactions/bills/goals) ─────────────────
    // Transaction.idwallet, Bill.idwallet, Goal.idwallet đều FK → wallet
    final pendingWallets = await _db.walletDao.getPending(idaccount);
    for (final w in pendingWallets) {
      if (_isSyncBlocked(w.syncBlockedUntil)) continue;
      final validId = _toValidUuid(w.id);
      ops.add(SyncOperation(
        localId: w.id,
        entity: SyncEntityType.wallet,
        operation:
            w.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': w.name,
          'type': w.type,
          'balance': w.balance,
          'currency': w.currency,
          'icon': w.icon,
          'colour': w.colour,
          'is_default': w.isDefault,
          'is_deleted': w.isDeleted,
          'include_in_total': w.includeInTotal,
          'updated_at': w.updatedAt.toUtc().toIso8601String(),
          'idaccount': w.idaccount > 0 ? w.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 1b. Bổ sung categories mà pending transactions tham chiếu ────────────
    // Chỉ bổ sung USER category (idaccount == currentIdaccount) chưa có trên backend.
    // KHÔNG bổ sung default/global categories (idaccount == 0) — backend đã có sẵn.
    final currentAccount = _currentIdaccount ?? idaccount;
    final alreadyInBatch = ops.map((o) => o.localId).toSet();
    final pendingTxForCatCheck = await _db.transactionDao.getPending(idaccount);
    for (final t in pendingTxForCatCheck) {
      if (t.categoryId == null) continue;
      final resolvedId = await _resolveCategoryId(t.categoryId);
      if (resolvedId == null) continue;
      if (alreadyInBatch.contains(resolvedId)) continue;
      final cat = await _db.categoryDao.getById(resolvedId);
      if (cat == null) continue;
      if (_isSyncBlocked(cat.syncBlockedUntil)) continue;
      // Chỉ push category thuộc user hiện tại — bỏ qua global/default (idaccount=0)
      if (cat.idaccount != currentAccount) continue;
      // Thêm category này vào batch để đảm bảo nó tồn tại trên backend
      String validClassify = cat.classify;
      if (validClassify == 'vay_no' || validClassify == 'vay-no') {
        validClassify = 'vay/no';
      }
      ops.add(SyncOperation(
        localId: cat.id,
        entity: SyncEntityType.category,
        operation: cat.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': _toValidUuid(cat.id),
          'name': cat.name,
          'namecategory': cat.name,
          'classify': validClassify,
          'icon': cat.icon,
          'colour': cat.colour,
          'is_default': cat.isDefault,
          'is_deleted': cat.isDeleted,
          'isGroup': cat.isGroup,
          'parentId':
              cat.parentId != null ? _toValidUuid(cat.parentId!) : null,
          'updated_at': cat.updatedAt.toUtc().toIso8601String(),
          'idaccount': currentAccount,
        },
        createdAt: now,
      ));
      alreadyInBatch.add(resolvedId);
    }

    // ── 3. Transactions (sau category + wallet vì FK → cả 2) ──────────────────
    final pendingTx = await _db.transactionDao.getPending(idaccount);
    for (final t in pendingTx) {
      if (_isSyncBlocked(t.syncBlockedUntil)) continue;
      final validId = _toValidUuid(t.id);
      final validWalletId = _toValidUuid(t.walletId);
      final validCategoryId = await _resolveCategoryId(t.categoryId);
      if (t.categoryId != null && validCategoryId == null) {
        debugPrint(
          '[SyncEngine] Deferring transaction ${t.id}: '
          'category ${t.categoryId} is not available on backend yet.',
        );
        continue;
      }
      ops.add(SyncOperation(
        localId: t.id,
        entity: SyncEntityType.transaction,
        operation:
            t.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'wallet_id': validWalletId,
          'category_id': validCategoryId,
          // Ví đích khi type = 'transfer' — backend đọc trực tiếp
          // `idwallet_transfer` (bỏ qua nếu không phải giao dịch chuyển khoản).
          'idwallet_transfer':
              t.walletTransfer != null ? _toValidUuid(t.walletTransfer!) : null,
          'amount': t.amount,
          'type': t.type,
          'note': t.note,
          'date': t.date.toUtc().toIso8601String(),
          'is_deleted': t.isDeleted,
          'updated_at': t.updatedAt.toUtc().toIso8601String(),
          'idaccount': t.idaccount > 0 ? t.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 4. Budgets (sau category + wallet) ────────────────────────────────────
    // Payload dùng đúng tên field Prisma của backend (idcategory, total_amount,
    // start, over_spending, ...) vì backend mapEntityFields() chỉ nhận diện
    // các key camelCase cụ thể (totalAmount, categoryId, ...) — gửi sẵn tên
    // snake_case cuối cùng để tránh lệ thuộc vào việc mapper có khớp hay không.
    for (final b in await _db.budgetDao.getPending(idaccount)) {
      if (_isSyncBlocked(b.syncBlockedUntil)) continue;
      final validId = _toValidUuid(b.id);
      final validCatId =
          b.categoryId != null ? _toValidUuid(b.categoryId!) : null;
      ops.add(SyncOperation(
        localId: b.id,
        entity: SyncEntityType.budget,
        operation:
            b.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'idcategory': validCatId,
          'total_amount': b.amount,
          'spent': b.spent,
          'threshold_warning_amount': b.thresholdWarningAmount,
          'threshold_warning_percent': b.thresholdWarningPercent,
          'over_spending': b.overSpending,
          'over_amount': b.overAmount,
          'start': b.startDate.toUtc().toIso8601String(),
          'end': b.endDate?.toUtc().toIso8601String(),
          'recurrence': b.recurrence,
          'time_recurrence': b.timeRecurrence,
          'nexttime_recurrence':
              b.nextTimeRecurrence?.toUtc().toIso8601String(),
          'note': b.note,
          'is_deleted': b.isDeleted,
          'updated_at': b.updatedAt.toUtc().toIso8601String(),
          'idaccount': b.idaccount > 0 ? b.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 5. Bills (sau category + wallet) ──────────────────────────────────────
    // idwallet/idcategory là NOT NULL trên backend — bắt buộc phải gửi kèm.
    // Lưu ý: form tạo/sửa bill hiện tại (bill_edit_page.dart) chưa cho chọn
    // ví/danh mục nên các giá trị này có thể vẫn null cho tới khi UI đó được
    // bổ sung — đây là việc ngoài phạm vi sync engine.
    for (final bill in await _db.billDao.getPending(idaccount)) {
      if (_isSyncBlocked(bill.syncBlockedUntil)) continue;
      final validId = _toValidUuid(bill.id);
      final validWalletId =
          bill.walletId != null ? _toValidUuid(bill.walletId!) : null;
      final validCategoryId =
          bill.categoryId != null ? _toValidUuid(bill.categoryId!) : null;
      ops.add(SyncOperation(
        localId: bill.id,
        entity: SyncEntityType.bill,
        operation: bill.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': validId,
          'idwallet': validWalletId,
          'idcategory': validCategoryId,
          'name': bill.name,
          'amount': bill.amount,
          'start_date': bill.startDate?.toUtc().toIso8601String(),
          'due_date': bill.dueDate.toUtc().toIso8601String(),
          'pay_status': bill.payStatus,
          'recurrence': bill.isRecurrence,
          'time_recurrence': bill.timeRecurrence,
          'time_notification': bill.timeNotification,
          'icon': bill.icon,
          'color': bill.colour,
          'note': bill.note,
          'is_deleted': bill.isDeleted,
          'updated_at': bill.updatedAt.toUtc().toIso8601String(),
          'idaccount':
              bill.idaccount > 0 ? bill.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 6. Goals (sau wallet) ──────────────────────────────────────────────────
    for (final g in await _db.goalDao.getPending(idaccount)) {
      if (_isSyncBlocked(g.syncBlockedUntil)) continue;
      final validId = _toValidUuid(g.id);
      ops.add(SyncOperation(
        localId: g.id,
        entity: SyncEntityType.goal,
        operation:
            g.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': g.name,
          'target_amount': g.targetAmount,
          'current_amount': g.currentAmount,
          'start_date': g.startDate?.toUtc().toIso8601String(),
          'target_date': g.targetDate.toUtc().toIso8601String(),
          'idwallet': g.walletId != null ? _toValidUuid(g.walletId!) : null,
          'cycle_take_money': g.cycleTakeMoney,
          'time_cycle_take_money':
              g.timeCycleTakeMoney?.toUtc().toIso8601String(),
          'status_complete': g.isCompleted ? 'True' : 'False',
          'recurrence': g.recurrence,
          'time_recurrence': g.timeRecurrence,
          'icon': g.icon,
          'color': g.colour,
          'note': g.note,
          'is_deleted': g.isDeleted,
          'updated_at': g.updatedAt.toUtc().toIso8601String(),
          'idaccount': g.idaccount > 0 ? g.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    return ops;
  }


  String _toValidUuid(String id) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    if (uuidRegex.hasMatch(id)) return id;
    final hexCodes =
        id.codeUnits.map((c) => (c % 16).toRadixString(16)).join('');
    final padded = hexCodes.padRight(12, '0').substring(0, 12);
    return '00000000-0000-4000-8000-$padded';
  }

  bool _isValidUuidFormat(String id) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidRegex.hasMatch(id);
  }

  Future<String?> _resolveCategoryId(String? categoryId) async {
    if (categoryId == null) return null;

    final localCategory = await _db.categoryDao.getById(categoryId);
    if (localCategory == null) return null;

    // Non-default user category: chỉ cần UUID hợp lệ
    if (!localCategory.isDefault) {
      return _isValidUuidFormat(categoryId) ? categoryId : null;
    }

    // Default category đã có UUID hợp lệ (từ backend) → dùng luôn
    // KHÔNG tìm UUID khác — tránh trả về UUID sai từ account khác
    if (_isValidUuidFormat(categoryId)) {
      return categoryId;
    }

    // Default category với ID dạng 'cat_food' → tìm UUID tương ứng theo tên
    final categoriesWithSameName =
        await _db.categoryDao.getByName(localCategory.name);
    for (final category in categoriesWithSameName) {
      if (_isValidUuidFormat(category.id) &&
          category.id != localCategory.id &&
          category.isDefault &&
          SyncPayloadNormalizer.sameCategoryClassify(
            category.classify,
            localCategory.classify,
          )) {
        return category.id;
      }
    }

    return null; // Chưa có UUID tương ứng — defer transaction
  }

  // ── Send batch to backend ─────────────────────────────────────────────────

  Future<SyncResult> _sendBatch(List<SyncOperation> ops) async {
    debugPrint(
        '[SyncEngine] Sending batch ${ops.length} operations to backend...');
    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final response = await _dioClient.dio.post(
        '/sync/push',
        data: {
          'clientId': 'flutter-client-app',
          'pushedAt': nowUtcIso,
          'operations': ops.map((op) {
            final operation = op.toJson();
            operation['payload'] = switch (op.entity) {
              SyncEntityType.wallet =>
                SyncPayloadNormalizer.walletForPush(op.payload),
              SyncEntityType.transaction =>
                SyncPayloadNormalizer.transactionForPush(op.payload),
              SyncEntityType.category =>
                SyncPayloadNormalizer.categoryForPush(op.payload),
              _ => SyncPayloadNormalizer.forPush(op.payload),
            };
            return operation;
          }).toList(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final topData = response.data['data'] as Map<String, dynamic>? ??
            response.data as Map<String, dynamic>;
        final results = (topData['results'] ?? response.data['results'])
                as List<dynamic>? ??
            [];
        int succeeded = 0;
        int failed = 0;
        final List<String> conflictIds = [];
        final List<String> errorMessages = [];
        final List<SyncOpFailure> failures = [];

        for (final item in results) {
          final respLocalId = item['localId'] as String?;
          final status = item['status'] as String?;
          if (respLocalId != null) {
            final opIndex = ops.indexWhere(
              (e) =>
                  e.localId == respLocalId ||
                  _toValidUuid(e.localId) == respLocalId,
            );
            if (opIndex != -1) {
              final op = ops[opIndex];
              if (status == 'synced') {
                await _markSyncedById(op.entity, op.localId);
                succeeded++;
              } else if (status == 'conflict') {
                // Backend trả 'conflict' khi bản trên server có `update_at`
                // mới hơn payload vừa đẩy — tức LWW đã phân xử xong và server
                // thắng. Trước đây bản ghi chỉ được ghi vào `conflictIds` rồi
                // bỏ đó: nó vẫn mang `pending`, nên mọi chu kỳ sau lại đẩy lên
                // và lại thua đúng như vậy, mãi mãi.
                //
                // Đánh dấu đã đồng bộ để thoát vòng lặp. Bản thắng cuộc về máy
                // ở bước Pull ngay sau đó trong cùng chu kỳ: `update_at` của nó
                // lớn hơn payload nên cũng lớn hơn mốc đồng bộ đang lưu.
                await _markSyncedById(op.entity, op.localId);
                conflictIds.add(op.localId);
                debugPrint(
                  '[SyncEngine] Push conflict (bản server mới hơn, lấy theo '
                  'server): entity=${op.entity.name}, localId=${op.localId}',
                );
              } else if (op.operation == SyncOperationType.delete &&
                  _recordNotFoundPattern
                      .hasMatch(item['message']?.toString() ?? '')) {
                // Xoá một bản ghi server không có = **mục tiêu đã đạt**. Đích
                // của thao tác này là "hàng đó không còn trên server", và nó
                // đã không còn.
                //
                // Coi là lỗi thì bản ghi giữ `pending` và được đẩy lại ở mọi
                // chu kỳ, mãi mãi: `_classifyFailure` không có nhánh nào cho
                // thông báo này nên nó rơi vào `transient`. Hai đường dẫn tới
                // đây đều có thật — người dùng tạo một bản ghi khi offline rồi
                // xoá trước khi nó kịp lên server, hoặc hàng đã bị xoá cứng ở
                // phía server.
                await _markSyncedById(op.entity, op.localId);
                succeeded++;
                debugPrint(
                  '[SyncEngine] Push delete: bản ghi vốn đã không có trên '
                  'server, coi như đã xong: entity=${op.entity.name}, '
                  'localId=${op.localId}',
                );
              } else {
                failed++;
                final message = item['message']?.toString() ?? 'Unknown error';
                errorMessages.add(message);
                final kind = _classifyFailure(
                  message,
                  code: item['code'] as String?,
                );
                failures.add(SyncOpFailure(
                  localId: op.localId,
                  entity: op.entity,
                  message: message,
                  kind: kind,
                ));
                if (kind == SyncFailureKind.permanent) {
                  // Lỗi vĩnh viễn: dữ liệu hiện tại đẩy bao nhiêu lần cũng
                  // hỏng như vậy. Trước đây bản ghi vẫn nằm ở 'pending' MÃI
                  // MÃI và được gửi lại ở mọi chu kỳ. Chặn theo thời gian —
                  // vẫn còn đường quay lại nếu người dùng sửa dữ liệu.
                  final step = _backoffSteps[
                      _consecutiveFailures.clamp(0, _backoffSteps.length - 1)];
                  await _markBlockedById(
                    op.entity,
                    op.localId,
                    _now().add(step),
                    message,
                  );
                }
                debugPrint(
                  '[SyncEngine] Push failed [${kind.name}]: '
                  'entity=${op.entity.name}, localId=${op.localId}, '
                  'reason=$message',
                );
              }
            }
          }
        }

        debugPrint(
            '[SyncEngine] Real Sync Complete: $succeeded/${ops.length} synced successfully.');
        return SyncResult(
          totalOps: ops.length,
          succeeded: succeeded,
          failed: failed,
          conflictIds: conflictIds,
          errorMessages: errorMessages,
          failures: failures,
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final reason = e.response?.data?.toString() ?? e.message ?? '$e';
      debugPrint('[SyncEngine] Sync push rejected [HTTP $statusCode]: $reason');

      // Từ 2026-09-03, backend trả 401 cho CẢ batch khi mọi thao tác đều hỏng
      // vì tài khoản không còn tồn tại (xem SESSION_VALIDITY_FINDINGS.md, F3).
      //
      // Trước đây nhánh này trả về một SyncResult có `failures` RỖNG, nên
      // `hasSessionInvalid` luôn false: engine không phát tín hiệu, và việc
      // phát hiện phiên chết phụ thuộc hoàn toàn vào đường vòng qua
      // AuthInterceptor. Nay báo đúng ngay tại đây.
      if (statusCode == 401) {
        return SyncResult(
          totalOps: ops.length,
          succeeded: 0,
          failed: ops.length,
          errorMessages: [reason],
          failures: [
            for (final op in ops)
              SyncOpFailure(
                localId: op.localId,
                entity: op.entity,
                message: reason,
                kind: SyncFailureKind.sessionInvalid,
              ),
          ],
        );
      }

      // Cả batch không tới nơi (mất mạng, timeout, 5xx). Đánh dấu
      // `transportFailed` để KHÔNG thử lại ngay trong cùng chu kỳ — việc thử
      // lại do giãn cách luỹ tiến lo, và cũng để không nhầm thành lỗi dữ liệu
      // rồi chặn oan từng bản ghi.
      return SyncResult(
        totalOps: ops.length,
        succeeded: 0,
        failed: ops.length,
        transportFailed: true,
        errorMessages: [reason],
        failures: [
          for (final op in ops)
            SyncOpFailure(
              localId: op.localId,
              entity: op.entity,
              message: reason,
              kind: SyncFailureKind.transient,
            ),
        ],
      );
    } catch (e) {
      debugPrint(
          '[SyncEngine] HTTP Sync API Error: $e — Will retry when online');
    }

    return SyncResult(
      totalOps: ops.length,
      succeeded: 0,
      failed: ops.length,
    );
  }

  Future<void> _markSyncedById(SyncEntityType entity, String id) async {
    switch (entity) {
      case SyncEntityType.wallet:
        await _db.walletDao.markSynced(id);
      case SyncEntityType.transaction:
        await _db.transactionDao.markSynced(id);
      case SyncEntityType.category:
        await _db.categoryDao.markSynced(id);
      case SyncEntityType.budget:
        await _db.budgetDao.markSynced(id);
      case SyncEntityType.bill:
        await _db.billDao.markSynced(id);
      case SyncEntityType.goal:
        await _db.goalDao.markSynced(id);
    }
  }

  // ── Phân loại lỗi đẩy dữ liệu ─────────────────────────────────────────────

  /// Đọc mốc thời điểm xoá mềm từ payload backend cho khối Pull.
  ///
  /// Cờ xoá phải ghi vào **cả hai** cột `isDeleted` và `deletedAt`. Mọi
  /// `getAll`/`watchAll` trong dự án lọc theo `deletedAt.isNull()`, KHÔNG theo
  /// `isDeleted` — nên nếu chỉ bật cờ boolean thì bản ghi đã xoá trên máy khác
  /// vẫn hiện ra sau khi pull, không exception và không log.
  ///
  /// Chuỗi hỏng vẫn trả về một mốc (giờ hiện tại) thay vì `null`: đã biết chắc
  /// bản ghi bị xoá thì thà lệch vài giây còn hơn để nó sống lại.
  ///
  /// Lưu ý tên cột không nhất quán ở backend: bảng `transaction` dùng
  /// `deleted_at`, các bảng còn lại dùng `delete_at` — nơi gọi phải truyền đúng
  /// khoá, hàm này không tự đoán.
  static DateTime? _deletedAtFrom(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString()) ?? DateTime.now();
  }

  /// Mã lỗi ổn định do backend gắn cho lỗi vỡ khoá ngoại tới bảng `account`
  /// (có từ 2026-09-03, xem `docs/superpowers/backend/SESSION_VALIDITY_FINDINGS.md`).
  static const String accountNotFoundCode = 'ACCOUNT_NOT_FOUND';

  /// Khoá ngoại trỏ tới bảng `account` bị vỡ nghĩa là `idaccount` đang dùng
  /// không tồn tại trên server — tức phiên đăng nhập đã chết.
  /// Khớp `fk_category_account`, `fk_transaction_account`, `fk_wallet_account`…
  static final RegExp _accountFkPattern =
      RegExp(r'fk_\w+_account', caseSensitive: false);

  /// Backend trả thông báo này khi được yêu cầu xoá một bản ghi nó không có
  /// (`sync.service.js`, nhánh `operation === 'delete'`).
  static final RegExp _recordNotFoundPattern =
      RegExp(r'record not found', caseSensitive: false);

  /// PostgreSQL từ chối vì dữ liệu vi phạm một ràng buộc `CHECK` (SQLSTATE
  /// 23514). Khớp cả mã lẫn câu chữ vì Prisma bọc lỗi theo nhiều cách tuỳ
  /// phiên bản, và mã 23514 là phần ổn định nhất.
  static final RegExp _checkConstraintPattern =
      RegExp(r'23514|violates check constraint', caseSensitive: false);

  /// PostgreSQL từ chối vì dữ liệu trùng một ràng buộc `UNIQUE` (SQLSTATE
  /// 23505). Khớp cả mã, câu chữ của PostgreSQL, và câu chữ Prisma bọc lại —
  /// Prisma đổi cách diễn đạt theo phiên bản, mà mã 23505 là phần ổn định nhất.
  ///
  /// Đường kích hoạt đã gặp thật (G16): người dùng xoá một danh mục cá nhân
  /// mặc định, `PersonalDefaultCategories.ensureMissing()` tạo lại nó với UUID
  /// mới ở **mỗi lần mở app**, rồi đẩy lên đụng `uq_category_owner_name_classify`
  /// — index đó không có mệnh đề `WHERE` nên hàng đã xoá mềm vẫn giữ chỗ tên.
  static final RegExp _uniqueConstraintPattern = RegExp(
    r'23505|violates unique constraint|unique constraint failed',
    caseSensitive: false,
  );

  static SyncFailureKind _classifyFailure(String message, {String? code}) {
    // Ưu tiên mã lỗi ổn định. Khớp chuỗi thông báo của Prisma là cách làm dễ
    // vỡ: đổi tên constraint hay nâng version Prisma là mất khả năng phát hiện
    // phiên chết, mà KHÔNG có lỗi nào báo ra.
    if (code == accountNotFoundCode) {
      return SyncFailureKind.sessionInvalid;
    }
    // Dự phòng cho backend chưa cập nhật — vẫn còn đang chạy ở máy khác.
    if (_accountFkPattern.hasMatch(message)) {
      // Đây chỉ là TÍN HIỆU. Quyết định đăng xuất do AuthBloc đưa ra sau khi
      // hỏi lại server bằng verifySession() — không bao giờ dựa mỗi vào việc
      // khớp chuỗi tên constraint (dễ vỡ khi đổi tên hoặc đổi version Prisma).
      return SyncFailureKind.sessionInvalid;
    }
    // Các khoá ngoại KHÁC (category/wallet/parent) thường chỉ là sai thứ tự
    // đẩy: Pull xong là đẩy lại được.
    if (message.contains('Foreign key constraint')) {
      return SyncFailureKind.transient;
    }
    // Sai chủ sở hữu = dòng dữ liệu sót của tài khoản khác. KHÔNG phải phiên
    // chết — đăng xuất ở đây là sai; dữ liệu đó cần được dọn thay vì thử lại.
    if (message.contains('Ownership mismatch')) {
      return SyncFailureKind.permanent;
    }
    // Dữ liệu vi phạm ràng buộc CHECK của PostgreSQL (mã 23514) thì đẩy bao
    // nhiêu lần cũng hỏng y như vậy — ví dụ ngân sách có `End` không lớn hơn
    // `Start`, vi phạm `chk_budget_end_after_start`. Xếp vào `transient` nghĩa
    // là gửi lại ở MỌI chu kỳ, và mỗi chu kỳ đó kết thúc ở `error` nên kích
    // hoạt giãn cách luỹ tiến (G2), kéo chậm mọi thay đổi khác.
    //
    // `permanent` chặn theo THỜI GIAN chứ không loại vĩnh viễn: người dùng sửa
    // lại dữ liệu là bản ghi quay về hàng đợi.
    if (_checkConstraintPattern.hasMatch(message)) {
      return SyncFailureKind.permanent;
    }
    // Trùng một ràng buộc UNIQUE thì đẩy lại bao nhiêu lần cũng hỏng y như vậy,
    // cho tới khi dữ liệu đổi hoặc backend nới ràng buộc. Xếp `transient` như
    // trước đây nghĩa là gửi lại ở MỌI chu kỳ, và vì `ensureMissing()` sinh
    // thêm một bản trùng ở mỗi lần mở app nên số bản ghi kẹt chỉ tăng (G16).
    //
    // `permanent` chặn theo THỜI GIAN chứ không loại vĩnh viễn: khi backend
    // thêm `WHERE "Delete_at" IS NULL` vào index, bản ghi tự quay lại hàng đợi.
    if (_uniqueConstraintPattern.hasMatch(message)) {
      return SyncFailureKind.permanent;
    }
    return SyncFailureKind.transient;
  }

  /// Gieo từ khoá phân loại backend gửi kèm danh mục — **chỉ khi danh mục đó
  /// chưa có từ khoá nào** ở máy này.
  ///
  /// Vì sao không ghi đè: cột `Keyword` phía backend là **một chuỗi dùng chung
  /// cho mọi tài khoản** (xem `docs/superpowers/backend/CATEGORY_KEYWORD_SYNC.md`),
  /// còn `CategoryKeywords` phía client là dữ liệu **riêng từng người dùng**,
  /// sửa được trong màn quản lý danh mục. Ghi đè ở mỗi chu kỳ pull sẽ khiến
  /// thao tác xoá từ khoá của người dùng không bao giờ dính — nó bị hồi sinh ở
  /// lần pull sau, đúng cách danh mục đã xoá từng bị hồi sinh ở G7.
  ///
  /// Đánh đổi có chủ ý: xoá **hết** từ khoá của một danh mục thì lần pull sau
  /// gieo lại, vì "rỗng" không phân biệt được với "chưa từng gieo" nếu không
  /// thêm cột mới.
  ///
  /// `idaccount` dùng để ghi là **tài khoản đang đăng nhập**, không phải
  /// `idaccount` của hàng danh mục — danh mục mặc định lưu với `idaccount = 0`
  /// nhưng `loadKeywords` tra theo tài khoản người dùng.
  Future<void> _gieoTuKhoaKhiTrong(
    int accountId,
    Map<String, List<String>> tuKhoaTheoDanhMuc,
  ) async {
    if (accountId <= 0 || tuKhoaTheoDanhMuc.isEmpty) return;
    final now = DateTime.now();
    var soDanhMucDaGieo = 0;
    for (final entry in tuKhoaTheoDanhMuc.entries) {
      try {
        final daCo = await _db.categoryDao.getKeywords(accountId, entry.key);
        if (daCo.isNotEmpty) continue;
        await _db.categoryDao.replaceKeywords(
          accountId: accountId,
          categoryId: entry.key,
          keywords: entry.value,
          now: now,
        );
        soDanhMucDaGieo++;
      } catch (e) {
        // Một danh mục hỏng không được làm đổ cả chu kỳ pull: từ khoá là dữ
        // liệu phụ trợ cho bộ gợi ý, không phải dữ liệu tài chính.
        debugPrint('[SyncEngine] Bỏ qua từ khoá của ${entry.key}: $e');
      }
    }
    if (soDanhMucDaGieo > 0) {
      debugPrint(
          '[SyncEngine] Đã gieo từ khoá phân loại cho $soDanhMucDaGieo danh mục.');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus s) {
    _status = s;
    // Timer debounce/định kỳ và listener kết nối có thể kích hoạt SAU khi engine
    // đã bị huỷ; khi đó `add()` trên controller đã đóng sẽ ném
    // "Bad state: Cannot add new events after calling close".
    if (_disposed || _statusController.isClosed) return;
    _statusController.add(s);
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    stop();
    _statusController.close();
    _sessionInvalidController.close();
  }

  static String _defaultIconForCategoryName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ăn') || lower.contains('uống')) return 'restaurant';
    if (lower.contains('xe') || lower.contains('di chuyển'))
      return 'directions_car';
    if (lower.contains('sắm')) return 'shopping_bag';
    if (lower.contains('y tế') ||
        lower.contains('sức khoẻ') ||
        lower.contains('sức khỏe') ||
        lower.contains('thuốc')) return 'local_hospital';
    if (lower.contains('học') || lower.contains('giáo dục')) return 'school';
    if (lower.contains('trí') ||
        lower.contains('game') ||
        lower.contains('phim')) return 'sports_esports';
    if (lower.contains('nhà')) return 'home';
    if (lower.contains('đơn') || lower.contains('dịch vụ')) return 'receipt';
    if (lower.contains('lương')) return 'work';
    if (lower.contains('thưởng') || lower.contains('quà'))
      return 'card_giftcard';
    if (lower.contains('đầu tư') || lower.contains('lãi')) return 'trending_up';
    if (lower.contains('vay') || lower.contains('nợ')) return 'attach_money';
    return 'category';
  }

  static String _defaultColorForCategoryName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ăn') || lower.contains('uống')) return '#FF5722';
    if (lower.contains('xe') || lower.contains('di chuyển')) return '#2196F3';
    if (lower.contains('sắm')) return '#9C27B0';
    if (lower.contains('y tế') ||
        lower.contains('sức khoẻ') ||
        lower.contains('sức khỏe')) return '#F44336';
    if (lower.contains('học') || lower.contains('giáo dục')) return '#3F51B5';
    if (lower.contains('trí') || lower.contains('game')) return '#E91E63';
    if (lower.contains('nhà')) return '#607D8B';
    if (lower.contains('đơn')) return '#795548';
    if (lower.contains('lương')) return '#4CAF50';
    if (lower.contains('thưởng')) return '#8BC34A';
    if (lower.contains('đầu tư')) return '#009688';
    return '#4CAF50';
  }
}
