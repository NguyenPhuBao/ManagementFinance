import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'sync_models.dart';

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

  Timer? _debounceTimer;
  StreamSubscription? _connectivitySub;
  int? _currentIdaccount;

  static const _debounceSeconds = 2;

  SyncEngine({
    required DioClient dioClient,
    required AppDatabase db,
    Connectivity? connectivity,
  })  : _dioClient = dioClient,
        _db = db,
        _connectivity = connectivity ?? Connectivity();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Khởi động SyncEngine sau khi user đăng nhập thành công.
  void start({required int idaccount}) {
    _currentIdaccount = idaccount;

    // Lắng nghe thay đổi kết nối
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncEngine] Network restored — scheduling sync');
        scheduleSync();
      }
    });

    // Sync lần đầu khi start
    scheduleSync();
  }

  /// Dừng SyncEngine khi logout.
  void stop() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _currentIdaccount = null;
    _setStatus(SyncStatus.idle);
  }

  // ── Trigger ───────────────────────────────────────────────────────────────

  /// Đặt lịch sync với debounce — gọi liên tiếp chỉ trigger 1 lần.
  void scheduleSync() {
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

  Future<void> _runSync() async {
    if (_currentIdaccount == null) return;
    if (_status == SyncStatus.syncing) return;  // Tránh concurrent sync

    // Kiểm tra kết nối
    final connectivity = await _connectivity.checkConnectivity();
    final hasConnection = connectivity.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _setStatus(SyncStatus.pending);
      debugPrint('[SyncEngine] No connection — sync deferred');
      return;
    }

    _setStatus(SyncStatus.syncing);
    debugPrint('[SyncEngine] Starting sync for account $_currentIdaccount');

    try {
      final ops = await _collectPendingOps(_currentIdaccount!);

      if (ops.isEmpty) {
        _setStatus(SyncStatus.idle);
        debugPrint('[SyncEngine] Nothing to sync');
        return;
      }

      final result = await _sendBatch(ops);
      debugPrint('[SyncEngine] Sync complete: $result');

      if (result.isSuccess) {
        _setStatus(SyncStatus.idle);
      } else {
        _setStatus(SyncStatus.error);
        // Retry sau 30 giây nếu có lỗi
        Timer(const Duration(seconds: 30), scheduleSync);
      }
    } catch (e) {
      debugPrint('[SyncEngine] Sync error: $e');
      _setStatus(SyncStatus.error);
    }
  }

  // ── Collect pending operations ────────────────────────────────────────────

  Future<List<SyncOperation>> _collectPendingOps(int idaccount) async {
    final ops = <SyncOperation>[];
    final now = DateTime.now();

    // Wallets
    final pendingWallets = await _db.walletDao.getPending(idaccount);
    for (final w in pendingWallets) {
      ops.add(SyncOperation(
        localId: w.id,
        entity: SyncEntityType.wallet,
        operation: w.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': w.id,
          'name': w.name,
          'type': w.type,
          'balance': w.balance,
          'currency': w.currency,
          'icon': w.icon,
          'colour': w.colour,
          'isDefault': w.isDefault,
          'isDeleted': w.isDeleted,
          'updatedAt': w.updatedAt.toIso8601String(),
          'idaccount': w.idaccount,
        },
        createdAt: now,
      ));
    }

    // Transactions
    final pendingTx = await _db.transactionDao.getPending(idaccount);
    for (final t in pendingTx) {
      ops.add(SyncOperation(
        localId: t.id,
        entity: SyncEntityType.transaction,
        operation: t.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': t.id,
          'walletId': t.walletId,
          'categoryId': t.categoryId,
          'amount': t.amount,
          'type': t.type,
          'note': t.note,
          'date': t.date.toIso8601String(),
          'isDeleted': t.isDeleted,
          'updatedAt': t.updatedAt.toIso8601String(),
          'idaccount': t.idaccount,
        },
        createdAt: now,
      ));
    }

    // Categories (chỉ user-created, không sync default)
    final pendingCats = await _db.categoryDao.getPending(idaccount);
    for (final c in pendingCats) {
      ops.add(SyncOperation(
        localId: c.id,
        entity: SyncEntityType.category,
        operation: c.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': c.id,
          'name': c.name,
          'classify': c.classify,
          'icon': c.icon,
          'colour': c.colour,
          'isDefault': c.isDefault,
          'isDeleted': c.isDeleted,
          'updatedAt': c.updatedAt.toIso8601String(),
          'idaccount': c.idaccount,
        },
        createdAt: now,
      ));
    }

    // Budgets, Bills, Goals
    for (final b in await _db.budgetDao.getPending(idaccount)) {
      ops.add(SyncOperation(
        localId: b.id,
        entity: SyncEntityType.budget,
        operation: b.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {'id': b.id, 'amount': b.amount, 'period': b.period,
                  'startDate': b.startDate.toIso8601String(),
                  'isDeleted': b.isDeleted, 'idaccount': b.idaccount},
        createdAt: now,
      ));
    }
    for (final bill in await _db.billDao.getPending(idaccount)) {
      ops.add(SyncOperation(
        localId: bill.id,
        entity: SyncEntityType.bill,
        operation: bill.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {'id': bill.id, 'name': bill.name, 'amount': bill.amount,
                  'dueDate': bill.dueDate.toIso8601String(), 'isPaid': bill.isPaid,
                  'recurrence': bill.recurrence, 'isDeleted': bill.isDeleted,
                  'idaccount': bill.idaccount},
        createdAt: now,
      ));
    }
    for (final g in await _db.goalDao.getPending(idaccount)) {
      ops.add(SyncOperation(
        localId: g.id,
        entity: SyncEntityType.goal,
        operation: g.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {'id': g.id, 'name': g.name, 'targetAmount': g.targetAmount,
                  'currentAmount': g.currentAmount,
                  'targetDate': g.targetDate.toIso8601String(),
                  'isDeleted': g.isDeleted, 'idaccount': g.idaccount},
        createdAt: now,
      ));
    }

    return ops;
  }

  // ── Send batch to backend ─────────────────────────────────────────────────

  Future<SyncResult> _sendBatch(List<SyncOperation> ops) async {
    // TODO (Plan 6): Implement actual sync API call khi backend sẵn sàng
    // Hiện tại: mark tất cả là đã synced (mock success) để app tiếp tục
    debugPrint('[SyncEngine] Mock sync: ${ops.length} operations (backend not ready)');

    // Mark synced trong local DB
    for (final op in ops) {
      await _markSyncedById(op.entity, op.localId);
    }

    return SyncResult(
      totalOps: ops.length,
      succeeded: ops.length,
      failed: 0,
    );
  }

  Future<void> _markSyncedById(SyncEntityType entity, String id) async {
    switch (entity) {
      case SyncEntityType.wallet:      await _db.walletDao.markSynced(id);
      case SyncEntityType.transaction: await _db.transactionDao.markSynced(id);
      case SyncEntityType.category:    await _db.categoryDao.markSynced(id);
      case SyncEntityType.budget:      await _db.budgetDao.markSynced(id);
      case SyncEntityType.bill:        await _db.billDao.markSynced(id);
      case SyncEntityType.goal:        await _db.goalDao.markSynced(id);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}
