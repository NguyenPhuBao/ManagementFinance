/// Bốn phương thức HÀNG DRIFT của `WalletRepository` (spec bịt điểm rò 2026-10-10, mục 4.3): chỉ chuyển tiếp đúng DAO,
/// không luật — trang cầm `List<Wallet>` nên repository trả đúng kiểu ấy thay vì ép UI cầm `AppDatabase`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/services/so_du_vi_service.dart';

class _SyncEngineGia implements SyncEngine {
  @override
  void scheduleSync() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late WalletRepositoryImpl repo;
  final moc = DateTime(2026, 10, 10);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WalletRepositoryImpl(
      localDataSource: WalletLocalDataSourceImpl(db: db),
      syncEngine: _SyncEngineGia(),
      soDuVi: SoDuViService(db: db),
      walletDao: db.walletDao,
    );
  });
  tearDown(() => db.close());

  Future<void> them(String id, {String status = 'active', bool xoa = false}) =>
      db.into(db.wallets).insert(WalletsCompanion.insert(
        id: id, idaccount: 10, name: 'Ví $id', updatedAt: moc,
        status: Value(status), deletedAt: Value(xoa ? moc : null),
      ));

  test('getActiveRows chỉ trả ví đang hoạt động — đúng walletDao.getActive', () async {
    await them('w1'); await them('w2', status: 'inactive'); await them('w3', xoa: true);
    final ds = await repo.getActiveRows(10);
    expect(ds.map((w) => w.id), ['w1'],
        reason: 'Bộ chọn ví không được thấy ví lưu trữ hay đã xoá (wallet_picker_sources_test).');
  });

  test('getAllRows / watchAllRows trả cả ví lưu trữ, bỏ ví đã xoá — bảng tra tên', () async {
    await them('w1'); await them('w2', status: 'inactive'); await them('w3', xoa: true);
    expect((await repo.getAllRows(10)).map((w) => w.id), ['w1', 'w2']);
    expect((await repo.watchAllRows(10).first).map((w) => w.id), ['w1', 'w2']);
  });

  test('getRowById trả cả hàng đã xoá mềm — tra tên cho giao dịch cũ', () async {
    await them('w3', xoa: true);
    expect((await repo.getRowById('w3'))?.name, 'Ví w3');
    expect(await repo.getRowById('khong-co'), isNull);
  });
}
