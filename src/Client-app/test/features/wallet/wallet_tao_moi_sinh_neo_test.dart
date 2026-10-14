/// Ví mới sinh **khoản mở sổ** ngay lúc tạo.
///
/// Sinh ngay thay vì đợi bộ vá chạy sau lần pull kế tiếp: ngày của khoản mở sổ
/// khớp ngày tạo ví, và máy khác thấy nó ở chu kỳ đồng bộ đầu tiên.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/services/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

class _SyncEngineGia implements SyncEngine {
  @override
  void scheduleSync() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  const acc = 7;
  late AppDatabase db;
  late WalletRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WalletRepositoryImpl(
      localDataSource: WalletLocalDataSourceImpl(db: db),
      syncEngine: _SyncEngineGia(),
      soDuVi: SoDuViService(db: db),
    );
  });

  tearDown(() => db.close());

  test('tạo ví có số dư ban đầu thì sinh NGAY khoản mở sổ', () async {
    final vi = await repository.addWallet(
      idaccount: acc,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 500000,
    );

    final neo = await db.transactionDao.getById(idKhoanMoSo(vi.id));
    expect(neo, isNotNull,
        reason: 'Không có neo thì số dư ví — nay là tổng sổ — ra 0 ngay lần '
            'tính lại đầu tiên, và toàn bộ số dư ban đầu biến mất.');
    expect(neo!.amount, 500000);
    expect(neo.type, 'thu');
    expect(neo.walletId, vi.id);
    expect(neo.idaccount, acc);
    expect(neo.syncStatus, 'pending',
        reason: 'Neo phải đi ra máy khác; đó là cách máy kia biết số dư ban đầu '
            'mà không cần thêm trường nào vào hợp đồng đồng bộ.');
  });

  test('tạo ví số dư 0 thì KHÔNG sinh gì', () async {
    final vi = await repository.addWallet(
      idaccount: acc,
      name: 'Ví rỗng',
      type: 'cash',
      balance: 0,
    );

    expect(await db.transactionDao.getById(idKhoanMoSo(vi.id)), isNull,
        reason: '`chk_transaction_nonzero_amount` bắt `Amount <> 0`, nên một '
            'khoản 0đ là bản ghi vỡ ở tầng CSDL rồi kẹt hàng đợi đẩy.');
  });

  test('số dư ví sau khi tạo vẫn đúng con số người dùng nhập', () async {
    final vi = await repository.addWallet(
      idaccount: acc,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 750000,
    );

    await SoDuViService(db: db).tinhLaiSoDu(vi.id);
    expect((await db.walletDao.getById(vi.id))!.balance, 750000);
  });
}
