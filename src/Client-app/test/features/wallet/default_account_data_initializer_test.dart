import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/data/services/default_account_data_initializer.dart';

class _WalletRepositoryStub implements WalletRepository {
  _WalletRepositoryStub(this.wallets);

  final List<WalletEntity> wallets;
  final List<({String name, String type, bool isDefault})> created = [];

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async =>
      wallets.where((wallet) => wallet.idaccount == idaccount).toList();

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
    created.add((name: name, type: type, isDefault: isDefault));
    final wallet = WalletEntity(
      id: 'wallet-${wallets.length + 1}',
      idaccount: idaccount,
      name: name,
      type: type,
      balance: balance,
      currency: currency,
      icon: icon,
      colour: colour,
      isDefault: isDefault,
      includeInTotal: includeInTotal,
      updatedAt: DateTime(2026),
    );
    wallets.add(wallet);
    return wallet;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _wallet({
  required int accountId,
  required String type,
  bool isDefault = false,
}) =>
    WalletEntity(
      id: '$accountId-$type',
      idaccount: accountId,
      name: type,
      type: type,
      balance: 0,
      isDefault: isDefault,
      updatedAt: DateTime(2026),
    );

void main() {
  test('creates a default Saving wallet and a Cash wallet for a new account',
      () async {
    final repository = _WalletRepositoryStub([]);
    final initializer = DefaultAccountDataInitializer(repository);

    await initializer.ensureForAccount(42);

    expect(
      repository.created,
      containsAll([
        (name: 'Tiết kiệm', type: 'saving', isDefault: true),
        (name: 'Tiền mặt', type: 'cash', isDefault: false),
      ]),
    );
  });

  test('does not duplicate the starter wallets for an initialized account',
      () async {
    final repository = _WalletRepositoryStub([
      _wallet(accountId: 42, type: 'saving', isDefault: true),
      _wallet(accountId: 42, type: 'cash'),
    ]);
    final initializer = DefaultAccountDataInitializer(repository);

    await initializer.ensureForAccount(42);

    expect(repository.created, isEmpty);
  });

  test('makes a newly added Saving wallet default when only Cash exists',
      () async {
    final repository = _WalletRepositoryStub([
      _wallet(accountId: 42, type: 'cash', isDefault: true),
    ]);
    final initializer = DefaultAccountDataInitializer(repository);

    await initializer.ensureForAccount(42);

    expect(
      repository.created,
      contains((name: 'Tiết kiệm', type: 'saving', isDefault: true)),
    );
  });
}
