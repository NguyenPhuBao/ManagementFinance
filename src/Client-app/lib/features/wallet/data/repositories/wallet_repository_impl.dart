import 'package:uuid/uuid.dart';

import '../../../../core/sync/sync_engine.dart';
import '../datasources/wallet_local_data_source.dart';
import '../models/wallet_entity.dart';
import 'wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletLocalDataSource _localDataSource;
  final SyncEngine _syncEngine;

  static const _uuid = Uuid();

  WalletRepositoryImpl({
    required WalletLocalDataSource localDataSource,
    required SyncEngine syncEngine,
  })  : _localDataSource = localDataSource,
        _syncEngine = syncEngine;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) =>
      _localDataSource.getAll(idaccount);

  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) =>
      _localDataSource.watchAll(idaccount);

  @override
  Future<WalletEntity?> getById(String id) => _localDataSource.getById(id);

  @override
  Future<WalletEntity?> getDefault(int idaccount) =>
      _localDataSource.getDefault(idaccount);

  @override
  Future<WalletEntity> addWallet({
    required int idaccount,
    required String name,
    required String type,
    required double balance,
    String currency = 'VND',
    String icon = 'wallet',
    String colour = '#4CAF50',
    bool isDefault = false,
    bool includeInTotal = true,
  }) async {
    final wallet = WalletEntity(
      id:             _uuid.v4(),
      idaccount:      idaccount,
      name:           name,
      type:           type,
      balance:        balance,
      currency:       currency,
      icon:           icon,
      colour:         colour,
      isDefault:      isDefault,
      includeInTotal: includeInTotal,
      syncStatus:     'pending',
      updatedAt:      DateTime.now(),
    );

    // Nếu isDefault = true, bỏ mặc định của ví cũ trước
    if (isDefault) {
      final currentDefault = await _localDataSource.getDefault(idaccount);
      if (currentDefault != null) {
        await _localDataSource.update(
          currentDefault.copyWith(
            isDefault:  false,
            syncStatus: 'pending',
            updatedAt:  DateTime.now(),
          ),
        );
      }
    }

    await _localDataSource.insert(wallet);
    _syncEngine.scheduleSync();   // Trigger background sync
    return wallet;
  }

  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    final updated = wallet.copyWith(
      syncStatus: 'pending',
      updatedAt:  DateTime.now(),
    );
    await _localDataSource.update(updated);
    _syncEngine.scheduleSync();
  }

  @override
  Future<void> deleteWallet(String id) async {
    await _localDataSource.softDelete(id);
    _syncEngine.scheduleSync();
  }

  @override
  Future<double> getTotalBalance(int idaccount) async {
    final wallets = await _localDataSource.getAll(idaccount);
    // Chỉ cộng ví có includeInTotal = true
    return wallets
        .where((w) => w.includeInTotal)
        .fold<double>(0.0, (sum, w) => sum + w.balance);
  }
}
