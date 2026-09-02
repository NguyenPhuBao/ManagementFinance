import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:drift/drift.dart';

import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'sync_models.dart';
import 'category_icon_registry.dart';
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
  Future<void> start({required int idaccount}) async {
    _currentIdaccount = idaccount;
    _lastPullTime =
        null; // Clear checkpoint để tài khoản vừa đăng nhập kéo toàn bộ dữ liệu mới ngay lập tức

    // Lắng nghe thay đổi kết nối
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncEngine] Network restored — scheduling sync');
        unawaited(syncNow());
      }
    });

    // Kích hoạt đồng bộ LẬP TỨC ngay khi vừa đăng nhập (không cần chờ thao tác)
    await syncNow();
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
  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    await _runSync();
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
      SyncResult? pushResult;
      if (ops.isNotEmpty) {
        pushResult = await _sendBatch(ops);
        debugPrint('[SyncEngine] Push complete: $pushResult');
      } else {
        debugPrint(
            '[SyncEngine] No pending local ops — proceeding to Pull from backend');
      }

      // 2. Pull all updated data from Backend PostgreSQL to SQLite local
      await _pullFromBackend(accountId);

      // A failed transaction can reference an old local default-category ID.
      // Retry once after Pull has supplied the Backend category UUIDs.
      if (pushResult != null && pushResult.failed > 0) {
        final retryOps = await _collectPendingOps(accountId);
        if (retryOps.isNotEmpty) {
          final retryResult = await _sendBatch(retryOps);
          debugPrint('[SyncEngine] Push retry complete: $retryResult');
        }
      }

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
                            (c['created_by'] ?? c['idaccount'] ?? 0)
                                .toString()) ??
                        0)),
                name: Value(catName),
                classify: Value(SyncPayloadNormalizer.categoryClassifyFromBackend(
                    c['classify']?.toString() ?? 'Chi')),
                icon: Value(finalIcon),
                colour: Value(finalColor),
                isDefault: Value(c['is_default'] == true),
                isDeleted: const Value(false),
                syncStatus: const Value('synced'),
                updatedAt: Value(
                    DateTime.tryParse(c['update_at']?.toString() ?? '') ??
                        DateTime.now()),
              ));
            }
            await _db.categoryDao.upsertAll(companions);
            // Xóa category seed cục bộ (cat_food...) đã có bản UUID từ backend
            await _db.categoryDao.removeDuplicateLocalSeedCategories();
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

    // ── 1. Categories (phải đứng TRƯỚC transactions/budgets/bills) ────────────
    // Transaction.idcategory, Budget.idcategory, Bill.idcategory đều FK → category
    // Nếu categories push sau thì backend báo FK constraint violation.
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

    // ── 2. Wallets (phải đứng TRƯỚC transactions/bills/goals) ─────────────────
    // Transaction.idwallet, Bill.idwallet, Goal.idwallet đều FK → wallet
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

    // ── 4. Budgets (sau category + wallet) ────────────────────────────────────
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

    // ── 5. Bills (sau category + wallet) ──────────────────────────────────────
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

    // ── 6. Goals (sau wallet) ──────────────────────────────────────────────────
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

  Future<String?> _resolveCategoryId(String? categoryId) async {
    if (categoryId == null) return null;

    final localCategory = await _db.categoryDao.getById(categoryId);
    if (localCategory == null) return null;
    if (!localCategory.isDefault) {
      return _isValidUuidFormat(categoryId) ? categoryId : null;
    }

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

    return _isValidUuidFormat(categoryId) ? categoryId : null;
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
                final message = item['message']?.toString() ?? 'Unknown error';
                errorMessages.add(message);
                debugPrint(
                  '[SyncEngine] Push failed: entity=${op.entity.name}, '
                  'localId=${op.localId}, reason=$message',
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
        );
      }
    } on DioException catch (e) {
      debugPrint(
        '[SyncEngine] Sync push rejected: ${e.response?.data ?? e.message}',
      );
      debugPrint(
        '[SyncEngine] HTTP Sync API Error: $e — Will retry when online',
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
