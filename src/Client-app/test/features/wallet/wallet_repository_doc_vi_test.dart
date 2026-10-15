/// Ba phép đọc ví của `WalletRepository` trả Entity (spec Entity Giao dịch + Ví 2026-10-14, 4.3): `getActive` cho bộ chọn,
/// `getAll` / `watchAll` cho bảng tra tên (gồm ví lưu trữ), `getById` trả cả hàng xoá mềm (tra tên giao dịch cũ — bẫy 4.8
/// GOAL_FEATURE). Chuyển từ `wallet_repository_rows_test` khi sáu lối `…Rows` rút.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

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
    );
  });
  tearDown(() => db.close());

  Future<void> them(String id, {String status = 'active', bool xoa = false}) =>
      db.into(db.wallets).insert(WalletsCompanion.insert(
            id: id,
            idaccount: 10,
            name: 'Ví $id',
            updatedAt: moc,
            status: Value(status),
            deletedAt: Value(xoa ? moc : null),
          ));

  test('getActive chỉ trả ví đang hoạt động — đúng walletDao.getActive',
      () async {
    await them('w1');
    await them('w2', status: 'inactive');
    await them('w3', xoa: true);
    final ds = await repo.getActive(10);
    expect(ds.map((w) => w.id), ['w1'],
        reason:
            'Bộ chọn ví không được thấy ví lưu trữ hay đã xoá (wallet_picker_sources_test).');
  });

  test('getAll / watchAll trả cả ví lưu trữ, bỏ ví đã xoá — bảng tra tên',
      () async {
    await them('w1');
    await them('w2', status: 'inactive');
    await them('w3', xoa: true);
    expect((await repo.getAll(10)).map((w) => w.id), ['w1', 'w2']);
    expect((await repo.watchAll(10).first).map((w) => w.id), ['w1', 'w2']);
  });

  test('getById trả cả hàng đã xoá mềm — tra tên cho giao dịch cũ', () async {
    await them('w3', xoa: true);
    expect((await repo.getById('w3'))?.name, 'Ví w3');
    expect(await repo.getById('khong-co'), isNull);
  });
}
