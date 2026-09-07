import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';

class DummySyncEngine implements SyncEngine {
  bool syncScheduled = false;
  @override
  Future<void> scheduleSync() async {
    syncScheduled = true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late TransactionLocalDataSource localDataSource;
  late DummySyncEngine syncEngine;
  late TransactionRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    localDataSource = TransactionLocalDataSourceImpl(db);
    syncEngine = DummySyncEngine();
    repository = TransactionRepositoryImpl(
      localDataSource: localDataSource,
      walletDao: db.walletDao,
      syncEngine: syncEngine,
    );

    // Create initial wallet
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value('w1'),
        idaccount: const Value(1),
        name: const Value('Ví Tiền Mặt'),
        type: const Value('cash'),
        balance: const Value(1000000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Create destination wallet for transfer
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value('w2'),
        idaccount: const Value(1),
        name: const Value('Ví Ngan Hang'),
        type: const Value('bank'),
        balance: const Value(500000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Adding expense (chi) transaction deducts balance from wallet', () async {
    final tx = TransactionEntity(
      id: 't1',
      walletId: 'w1',
      idaccount: 1,
      categoryId: 'c1',
      amount: 100000.0,
      type: 'chi',
      note: 'Coffee',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, equals(900000.0));
    expect(syncEngine.syncScheduled, isTrue);
  });

  test('Adding income (thu) transaction increases balance of wallet', () async {
    final tx = TransactionEntity(
      id: 't2',
      walletId: 'w1',
      idaccount: 1,
      categoryId: 'c2',
      amount: 500000.0,
      type: 'thu',
      note: 'Bonus',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, equals(1500000.0));
  });

  test('Transfer transaction moves balance between source and destination wallets', () async {
    final tx = TransactionEntity(
      id: 't3',
      walletId: 'w1',
      idaccount: 1,
      // Khoản chuyển KHÔNG có danh mục. Fixture cũ gán 'cat_transfer' — một id
      // chưa từng được seed — và chính giá trị đó làm mọi khoản chuyển tạo từ
      // màn thêm giao dịch bị hoãn đẩy vĩnh viễn (xem sync_payload_contract_test).
      amount: 200000.0,
      type: 'transfer',
      note: 'Chuyen tien',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx, destinationWalletId: 'w2');

    final w1 = await db.walletDao.getById('w1');
    final w2 = await db.walletDao.getById('w2');
    expect(w1?.balance, equals(800000.0));
    expect(w2?.balance, equals(700000.0));
  });

  Future<Transaction> hangDaLuu(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  test('Khoản chuyển lưu ví đích xuống SQLite và đổi số dư hai ví từ chính entity',
      () async {
    final tx = TransactionEntity(
      id: 't4',
      walletId: 'w1',
      idaccount: 1,
      amount: 200000.0,
      type: 'transfer',
      walletTransfer: 'w2',
      note: 'Chuyen tien',
      date: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Không truyền destinationWalletId: ví đích nằm trên entity là đủ.
    await repository.addTransaction(tx);

    final row = await hangDaLuu('t4');
    expect(
      row.walletTransfer,
      'w2',
      reason: 'Ví đích là chỗ DUY NHẤT ghi lại tiền đã đi đâu, và payload đẩy '
          'đọc `t.walletTransfer`. Trước đây `toCompanion()` không gán cột này '
          'nên khoản chuyển tạo từ màn thêm giao dịch lên server không có ví '
          'đích, máy khác kéo về không biết tiền chạy đi đâu.',
    );
    expect((await db.walletDao.getById('w1'))?.balance, equals(800000.0));
    expect((await db.walletDao.getById('w2'))?.balance, equals(700000.0));
  });

  test('Xoá khoản chuyển hoàn số dư CẢ HAI ví, ví đích đọc từ giao dịch đã lưu',
      () async {
    final tx = TransactionEntity(
      id: 't5',
      walletId: 'w1',
      idaccount: 1,
      amount: 200000.0,
      type: 'transfer',
      walletTransfer: 'w2',
      date: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.addTransaction(tx);
    // Chốt trạng thái SAU KHI THÊM, để test không xanh hụt khi cả hai đường
    // thêm/xoá cùng bỏ qua ví đích (số dư không đổi ở cả hai bước).
    expect((await db.walletDao.getById('w1'))?.balance, equals(800000.0));
    expect((await db.walletDao.getById('w2'))?.balance, equals(700000.0));

    // Trang danh sách xoá bằng entity đọc lại từ CSDL, không phải entity lúc
    // tạo — nên `fromDrift` phải mang ví đích lên, nếu không nhánh hoàn tiền
    // ví đích không bao giờ chạy và ví ấy giữ lại tiền của một khoản đã xoá.
    final saved = TransactionEntity.fromDrift(await hangDaLuu('t5'));
    expect(saved.walletTransfer, 'w2');

    await repository.deleteTransaction(saved);

    expect((await db.walletDao.getById('w1'))?.balance, equals(1000000.0),
        reason: 'Ví nguồn nhận lại tiền.');
    expect((await db.walletDao.getById('w2'))?.balance, equals(500000.0),
        reason: 'Ví đích trả lại tiền — trước đây nhánh này không chạy vì '
            'bloc không có ví đích để truyền xuống.');
  });

  group('updateTransaction — sửa giao dịch = hoàn hệ quả cũ rồi áp hệ quả mới',
      () {
    TransactionEntity chi(String id, double amount, {String walletId = 'w1'}) =>
        TransactionEntity(
          id: id,
          walletId: walletId,
          idaccount: 1,
          categoryId: 'c1',
          amount: amount,
          type: 'chi',
          date: DateTime(2026, 9, 6),
          updatedAt: DateTime(2026, 9, 6),
        );

    test('đổi số tiền khoản chi: ví chỉ chịu phần chênh lệch', () async {
      await repository.addTransaction(chi('u1', 100000));
      expect((await db.walletDao.getById('w1'))?.balance, 900000.0);

      final before = TransactionEntity.fromDrift(await hangDaLuu('u1'));
      await repository.updateTransaction(before, before.copyWith(amount: 150000));

      expect((await db.walletDao.getById('w1'))?.balance, 850000.0,
          reason: 'Hoàn 100.000 rồi trừ 150.000 — không trừ chồng 250.000.');
      final row = await hangDaLuu('u1');
      expect(row.amount, 150000.0);
      expect(row.syncStatus, 'pending',
          reason: 'Sửa xong phải đẩy lại; trước đó hàng đang synced.');
      expect(row.updatedAt.isAfter(DateTime(2026, 9, 6)), isTrue,
          reason: 'LWW phía server so update_at — giữ mốc cũ là server bỏ qua.');
    });

    test('đổi ví: ví cũ được hoàn, ví mới bị trừ', () async {
      await repository.addTransaction(chi('u2', 100000));
      final before = TransactionEntity.fromDrift(await hangDaLuu('u2'));

      await repository.updateTransaction(before, before.copyWith(walletId: 'w2'));

      expect((await db.walletDao.getById('w1'))?.balance, 1000000.0);
      expect((await db.walletDao.getById('w2'))?.balance, 400000.0);
      expect((await hangDaLuu('u2')).walletId, 'w2');
    });

    test('đổi chi thành thu: hoàn khoản chi rồi cộng khoản thu', () async {
      await repository.addTransaction(chi('u3', 100000));
      final before = TransactionEntity.fromDrift(await hangDaLuu('u3'));

      await repository.updateTransaction(before, before.copyWith(type: 'thu'));

      expect((await db.walletDao.getById('w1'))?.balance, 1100000.0);
    });

    test('đổi ví đích của khoản chuyển: đích cũ trả tiền, đích mới nhận',
        () async {
      await db.walletDao.insert(WalletsCompanion(
        id: const Value('w3'),
        idaccount: const Value(1),
        name: const Value('Ví thứ ba'),
        type: const Value('cash'),
        balance: const Value(100000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ));
      final transfer = TransactionEntity(
        id: 'u4',
        walletId: 'w1',
        idaccount: 1,
        amount: 200000,
        type: 'transfer',
        walletTransfer: 'w2',
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );
      await repository.addTransaction(transfer);
      final before = TransactionEntity.fromDrift(await hangDaLuu('u4'));

      await repository.updateTransaction(
          before, before.copyWith(walletTransfer: 'w3'));

      expect((await db.walletDao.getById('w1'))?.balance, 800000.0,
          reason: 'Nguồn và số tiền không đổi.');
      expect((await db.walletDao.getById('w2'))?.balance, 500000.0,
          reason: 'Đích cũ trả lại 200.000.');
      expect((await db.walletDao.getById('w3'))?.balance, 300000.0,
          reason: 'Đích mới nhận 200.000.');
      expect((await hangDaLuu('u4')).walletTransfer, 'w3');
    });
  });
}
