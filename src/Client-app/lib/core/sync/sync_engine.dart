import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:drift/drift.dart';

import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'sync_models.dart';
import 'category_icon_registry.dart';

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
    _lastPullTime =
        null; // Clear checkpoint để tài khoản vừa đăng nhập kéo toàn bộ dữ liệu mới ngay lập tức

    // Lắng nghe thay đổi kết nối
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncEngine] Network restored — scheduling sync');
        syncNow();
      }
    });

    // Kích hoạt đồng bộ LẬP TỨC ngay khi vừa đăng nhập (không cần chờ thao tác)
    syncNow();
  }

  /// Dừng SyncEngine khi logout.
  void stop() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _currentIdaccount = null;
    _lastPullTime = null; // Clear checkpoint khi đăng xuất
    _setStatus(SyncStatus.idle);
  }

  // ── Trigger ───────────────────────────────────────────────────────────────

  /// Kích hoạt đồng bộ LẬP TỨC (Immediate Sync) không cần chờ timer debounce.
  void syncNow() {
    _debounceTimer?.cancel();
    _runSync();
  }

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

  DateTime? _lastPullTime;

  Future<void> _runSync() async {
    int accountId = _currentIdaccount ?? 1;
    if (_currentIdaccount == null || _currentIdaccount == 1) {
      final wallets = await _db.walletDao.getAllNonDeleted();
      if (wallets.isNotEmpty && wallets.first.idaccount > 0) {
        accountId = wallets.first.idaccount;
        _currentIdaccount = accountId;
      } else {
        final txs = await _db.transactionDao.getAll(0);
        if (txs.isNotEmpty && txs.first.idaccount > 0) {
          accountId = txs.first.idaccount;
          _currentIdaccount = accountId;
        }
      }
    }
    if (_status == SyncStatus.syncing) return; // Tránh concurrent sync

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
      if (ops.isNotEmpty) {
        final result = await _sendBatch(ops);
        debugPrint('[SyncEngine] Push complete: $result');
      } else {
        debugPrint(
            '[SyncEngine] No pending local ops — proceeding to Pull from backend');
      }

      // 2. Pull all updated data from Backend PostgreSQL to SQLite local
      await _pullFromBackend(accountId);

      _setStatus(SyncStatus.idle);
    } catch (e) {
      debugPrint('[SyncEngine] Sync error: $e');
      _setStatus(SyncStatus.error);
    }
  }

  // ── Pull data from backend to local SQLite ────────────────────────────────

  Future<void> _pullFromBackend(int accountId) async {
    final allWallets = await _db.walletDao.getAllNonDeleted();
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
                id: Value(w['id'].toString()),
                idaccount:
                    Value(int.tryParse(w['idaccount'].toString()) ?? accountId),
                name: Value(w['name'].toString()),
                type: Value(w['type']?.toString() ?? 'cash'),
                balance: Value(
                    (num.tryParse(w['balance'].toString()) ?? 0.0).toDouble()),
                currency: Value(w['currency']?.toString() ?? 'VND'),
                icon: Value(w['icon']?.toString() ?? 'wallet'),
                colour: Value(w['colour']?.toString() ?? '#4CAF50'),
                isDefault: Value(w['is_default'] == true),
                isDeleted: Value(w['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(w['updated_at']?.toString() ?? '') ??
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
                id: Value(t['id'].toString()),
                idaccount:
                    Value(int.tryParse(t['idaccount'].toString()) ?? accountId),
                walletId: Value(t['wallet_id'].toString()),
                categoryId: Value(t['category_id']?.toString()),
                amount: Value(
                    (num.tryParse(t['amount'].toString()) ?? 0.0).toDouble()),
                type: Value(t['type']?.toString() ?? 'chi'),
                note: Value(t['note']?.toString() ?? ''),
                date: Value(DateTime.tryParse(t['date']?.toString() ?? '') ??
                    DateTime.now()),
                isDeleted: Value(t['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(t['updated_at']?.toString() ?? '') ??
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
            for (final c in categories) {
              final catUuid = (c['uuid'] ?? c['id']).toString();
              final catName = (c['namecategory'] ?? c['name'] ?? '').toString();
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
                idaccount: Value(int.tryParse(
                        (c['created_by'] ?? c['idaccount'] ?? 0).toString()) ??
                    0),
                name: Value(catName),
                classify: Value(c['classify']?.toString() ?? 'chi'),
                icon: Value(finalIcon),
                colour: Value(finalColor),
                isDefault: Value(c['is_default'] == true),
                isDeleted: const Value(false),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(c['updated_at']?.toString() ?? '') ??
                        DateTime.now()),
              ));
            }
            await _db.categoryDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${categories.length} categories into SQLite local.');
          }

          // 4. Budgets
          final budgets = (payloadData['budgets'] ?? payloadData['budget'])
                  as List<dynamic>? ??
              [];
          if (budgets.isNotEmpty) {
            final companions = budgets.map((b) {
              return BudgetsCompanion(
                id: Value(b['id'].toString()),
                idaccount:
                    Value(int.tryParse(b['idaccount'].toString()) ?? accountId),
                categoryId: Value(b['category_id']?.toString()),
                amount: Value(
                    (num.tryParse(b['amount'].toString()) ?? 0.0).toDouble()),
                period: Value(b['period']?.toString() ?? 'thang'),
                startDate: Value(
                    DateTime.tryParse(b['start_date']?.toString() ?? '') ??
                        DateTime.now()),
                isDeleted: Value(b['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
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
              return BillsCompanion(
                id: Value(bill['id'].toString()),
                idaccount: Value(
                    int.tryParse(bill['idaccount'].toString()) ?? accountId),
                name: Value(bill['name'].toString()),
                amount: Value((num.tryParse(bill['amount'].toString()) ?? 0.0)
                    .toDouble()),
                dueDate: Value(
                    DateTime.tryParse(bill['due_date']?.toString() ?? '') ??
                        DateTime.now()),
                isPaid: Value(bill['is_paid'] == true),
                recurrence:
                    Value(bill['recurrence']?.toString() ?? 'hang_thang'),
                isDeleted: Value(bill['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(bill['updated_at']?.toString() ?? '') ??
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
              return GoalsCompanion(
                id: Value(g['id'].toString()),
                idaccount:
                    Value(int.tryParse(g['idaccount'].toString()) ?? accountId),
                name: Value(g['name'].toString()),
                targetAmount: Value(
                    (num.tryParse(g['target_amount'].toString()) ?? 0.0)
                        .toDouble()),
                currentAmount: Value(
                    (num.tryParse(g['current_amount'].toString()) ?? 0.0)
                        .toDouble()),
                targetDate: Value(
                    DateTime.tryParse(g['target_date']?.toString() ?? '') ??
                        DateTime.now()),
                walletId: Value(g['wallet_id']?.toString()),
                isDeleted: Value(g['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(g['updated_at']?.toString() ?? '') ??
                        DateTime.now()),
              );
            }).toList();
            await _db.goalDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${goals.length} goals into SQLite local.');
          }

          _lastPullTime = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('[SyncEngine] HTTP Sync Pull Error: $e');
    }
  }

  // ── Collect pending operations ────────────────────────────────────────────

  Future<List<SyncOperation>> _collectPendingOps(int idaccount) async {
    final ops = <SyncOperation>[];
    final now = DateTime.now();

    // Wallets
    final pendingWallets = await _db.walletDao.getPending(idaccount);
    for (final w in pendingWallets) {
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
          'idaccount': w.idaccount > 0 ? w.idaccount : (_currentIdaccount ?? 1),
        },
        createdAt: now,
      ));
    }

    // Transactions
    final pendingTx = await _db.transactionDao.getPending(idaccount);
    for (final t in pendingTx) {
      final validId = _toValidUuid(t.id);
      final validWalletId = _toValidUuid(t.walletId);
      ops.add(SyncOperation(
        localId: t.id,
        entity: SyncEntityType.transaction,
        operation:
            t.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'wallet_id': validWalletId,
          'category_id': t.categoryId != null ? _toValidUuid(t.categoryId!) : null,
          'amount': t.amount,
          'type': t.type,
          'note': t.note,
          'date': t.date.toUtc().toIso8601String(),
          'is_deleted': t.isDeleted,
          'updated_at': t.updatedAt.toUtc().toIso8601String(),
          'idaccount': t.idaccount > 0 ? t.idaccount : (_currentIdaccount ?? 1),
        },
        createdAt: now,
      ));
    }

    // Categories
    final syncableCategories =
        await _db.categoryDao.getSyncableCategories(idaccount);
    for (final c in syncableCategories) {
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
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
          'idaccount': c.idaccount > 0 ? c.idaccount : (_currentIdaccount ?? 1),
        },
        createdAt: now,
      ));
    }

    // Budgets, Bills, Goals
    for (final b in await _db.budgetDao.getPending(idaccount)) {
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
          'category_id': validCatId,
          'amount': b.amount,
          'period': b.period,
          'start_date': b.startDate.toUtc().toIso8601String(),
          'is_deleted': b.isDeleted,
          'updated_at': b.updatedAt.toUtc().toIso8601String(),
          'idaccount': b.idaccount > 0 ? b.idaccount : (_currentIdaccount ?? 1),
        },
        createdAt: now,
      ));
    }
    for (final bill in await _db.billDao.getPending(idaccount)) {
      final validId = _toValidUuid(bill.id);
      ops.add(SyncOperation(
        localId: bill.id,
        entity: SyncEntityType.bill,
        operation: bill.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': bill.name,
          'amount': bill.amount,
          'due_date': bill.dueDate.toUtc().toIso8601String(),
          'is_paid': bill.isPaid,
          'recurrence': bill.recurrence,
          'is_deleted': bill.isDeleted,
          'updated_at': bill.updatedAt.toUtc().toIso8601String(),
          'idaccount':
              bill.idaccount > 0 ? bill.idaccount : (_currentIdaccount ?? 1),
        },
        createdAt: now,
      ));
    }
    for (final g in await _db.goalDao.getPending(idaccount)) {
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
          'target_date': g.targetDate.toUtc().toIso8601String(),
          'wallet_id': g.walletId != null ? _toValidUuid(g.walletId!) : null,
          'is_deleted': g.isDeleted,
          'updated_at': g.updatedAt.toUtc().toIso8601String(),
          'idaccount': g.idaccount > 0 ? g.idaccount : (_currentIdaccount ?? 1),
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
          'operations': ops.map((op) => op.toJson()).toList(),
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
                conflictIds.add(op.localId);
              } else {
                failed++;
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
        );
      }
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    stop();
    _statusController.close();
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
