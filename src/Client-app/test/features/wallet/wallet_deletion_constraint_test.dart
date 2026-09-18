import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';

void main() {
  late AppDatabase db;
  late WalletLocalDataSourceImpl dataSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = WalletLocalDataSourceImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Cannot delete wallet with non-zero balance', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_balance',
        idaccount: 1,
        name: 'Ví Có Tiền',
        balance: const Value(500000.0),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_balance'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('đang có số dư'),
      )),
    );
  });

  test('Cannot delete wallet with existing transactions', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_tx',
        idaccount: 1,
        name: 'Ví Có Giao Dịch',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: 'tx_1',
        idaccount: 1,
        walletId: 'w_tx',
        amount: 50000.0,
        type: 'chi',
        date: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_tx'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('đã có 1 giao dịch phát sinh'),
      )),
    );
  });

  test('Cannot delete wallet linked to a Savings Goal', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_goal',
        idaccount: 1,
        name: 'Ví Mục Tiêu',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.goalDao.insert(
      GoalsCompanion.insert(
        id: 'g_1',
        idaccount: 1,
        name: 'Mua Xe Máy',
        targetAmount: 30000000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        walletId: const Value('w_goal'),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_goal'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        allOf(
          contains('Mua Xe Máy'),
          // Lời nhắc phải chỉ ra lối thoát CÓ THẬT. Bản trước bảo "vui lòng gỡ
          // liên kết" trong khi app không có chỗ nào làm việc đó.
          contains('đổi ví'),
        ),
      )),
    );
  });

  test('thông báo khi ví còn số dư KHÔNG hứa một lối thoát đã chết', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_loi_thoat',
        idaccount: 1,
        name: 'Ví Có Tiền',
        balance: const Value(500000.0),
        updatedAt: DateTime.now(),
      ),
    );

    final loi = await dataSource
        .softDelete('w_loi_thoat')
        .then<Object?>((_) => null)
        .catchError((Object e) => e);

    final thongBao = (loi! as CacheException).message;
    expect(thongBao, contains('lưu trữ'),
        reason: 'Lối thoát CÓ THẬT cho một ví đã dùng là lưu trữ, nên câu này '
            'phải chỉ vào đó.');
    expect(thongBao, isNot(contains('về 0đ')),
        reason: 'Câu cũ bảo "điều chuyển số dư về 0đ trước khi xóa". Từ khi số '
            'dư suy từ sổ giao dịch (G37), mọi cách đưa số dư về 0 đều SINH '
            'THÊM một giao dịch — nên làm đúng lời khuyên ấy xong thì ràng '
            'buộc "đã có giao dịch phát sinh" chặn lại. Người dùng đi hết một '
            'vòng để về đúng chỗ cũ.');
  });

  // ── Hai lỗ hổng tìm được khi soát toàn bộ mảng ví, 2026-09-18 ─────────────
  //
  // Ba ràng buộc trên đây có chung một lời hứa: **không xoá ví đã có lịch sử
  // tài chính**. Hai ca dưới đây là hai đường đi vòng qua lời hứa ấy mà không
  // chốt nào bắt được, và cả hai đều hỏng **im lặng** — ví biến mất, còn thứ
  // trỏ vào nó thì ở lại.

  test('KHÔNG xoá được ví đang là ví thanh toán của một hoá đơn', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_bill',
        idaccount: 1,
        name: 'Ví Trả Hoá Đơn',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.billDao.insert(
      BillsCompanion.insert(
        id: 'b_1',
        idaccount: 1,
        name: 'Tiền điện',
        amount: 350000.0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        walletId: const Value('w_bill'),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_bill'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        allOf(
          contains('Tiền điện'),
          contains('đổi ví'),
        ),
      )),
      reason: 'Hoá đơn trỏ vào ví đã xoá vẫn trả được: `payBill` không kiểm ví '
          'còn sống, nên khoản chi mới rơi vào một ví bị loại khỏi mọi phép '
          'cộng tổng. Tiền biến mất khỏi màn hình trong khi hoá đơn báo "đã '
          'trả". Phía PostgreSQL `fk_bill_wallet` là ON DELETE RESTRICT, tức '
          'server coi đây là liên kết không được phá.',
    );
  });

  test('KHÔNG xoá được ví CHỈ nhận tiền chuyển đến', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_nguon',
        idaccount: 1,
        name: 'Ví Nguồn',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_dich',
        idaccount: 1,
        name: 'Ví Đích',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    // Ví đích KHÔNG đứng ở cột `walletId` của hàng nào — nó chỉ xuất hiện ở
    // `walletTransfer`. Đó là toàn bộ chỗ hổng.
    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: 'tx_transfer',
        idaccount: 1,
        walletId: 'w_nguon',
        walletTransfer: const Value('w_dich'),
        amount: 200000.0,
        type: 'transfer',
        date: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_dich'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('giao dịch'),
      )),
      reason: 'Ràng buộc "đã có giao dịch phát sinh" đọc qua `getByWallet`, mà '
          'hàm ấy chỉ lọc cột `walletId`. Một ví chỉ nhận tiền chuyển vào thì '
          'được coi là chưa từng dùng, và xoá nó đi ngược chính lời hứa bảo '
          'toàn lịch sử tài chính đứng ngay cạnh.',
    );
  });

  test('Successfully delete empty wallet with no transactions or linked goals', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_empty',
        idaccount: 1,
        name: 'Ví Rỗng',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await dataSource.softDelete('w_empty');

    final wallet = await db.walletDao.getById('w_empty');
    expect(wallet?.isDeleted, true);
  });
}
