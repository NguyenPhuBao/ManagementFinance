/// `DieuChinhSoDuService` ở ví CHUNG của nhà (gia đình 1B, Task 2): khoản bù mang người ghi từ phiên và `idhousehold` của ví.
/// Ca của ví riêng ở `test/features/wallet/dieu_chinh_so_du_service_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/wallet/application/dieu_chinh_so_du_service.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

import '../../transaction/data/repositories/transaction_repository_test.dart' show DummySyncEngine;

void main() {
  late AppDatabase db;
  late DieuChinhSoDuService svc;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = DieuChinhSoDuService(
      db: db,
      transactionRepository: TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSourceImpl(db),
        syncEngine: DummySyncEngine(),
        soDuVi: SoDuViService(db: db, taiKhoanPhien: () => 20),
      ),
    );
    // Ví của nhà 7 do tài khoản 10 tạo; Chủ nhà hiện tại là 20.
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'vc',
      idaccount: 10,
      name: 'Tiền chợ',
      balance: const Value(1000000),
      idhousehold: const Value(7),
      updatedAt: DateTime(2026, 11, 1),
    ));
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'vr',
      idaccount: 10,
      name: 'Ví riêng',
      balance: const Value(1000000),
      updatedAt: DateTime(2026, 11, 1),
    ));
  });
  tearDown(() => db.close());

  test('đối soát ví chung ghi người ghi từ phiên và mang idhousehold', () async {
    await svc.dieuChinh(walletId: 'vc', soDuThucTe: 500000, lyDo: 'đếm lại', nguoiGhi: 20);
    final bu = (await db.transactionDao.watchTheoNha(7).first).where((t) => t.walletId == 'vc' && t.id != idKhoanMoSo('vc')).toList();
    expect(bu, hasLength(1), reason: 'một khoản bù, hiện trong lịch sử của nhà');
    expect(bu.single.idaccount, 20, reason: 'ghi theo chủ ví cũ (10) là NOT_OWNER khi đẩy');
    expect(bu.single.idhousehold, 7,
        reason: 'thiếu là khoản bù thành hàng riêng trỏ ví nhà, SCOPE_MISMATCH vĩnh viễn');
    expect(bu.single.type, 'chi');
    expect(bu.single.amount, 500000);
  });

  test('ví của nhà không có nguoiGhi thì ném, không ghi gì', () async {
    await expectLater(svc.dieuChinh(walletId: 'vc', soDuThucTe: 500000, lyDo: ''), throwsA(isA<CacheException>()));
    expect(await db.transactionDao.watchTheoNha(7).first, isEmpty);
  });

  test('ví riêng: nguoiGhi bị bỏ qua, khoản bù theo chủ ví và không mang nhà', () async {
    await svc.dieuChinh(walletId: 'vr', soDuThucTe: 1200000, lyDo: '', nguoiGhi: 20);
    final bu = (await db.select(db.transactions).get()).where((t) => t.walletId == 'vr' && t.id != idKhoanMoSo('vr')).single;
    expect(bu.idaccount, 10, reason: 'ví riêng giữ hành vi cũ');
    expect(bu.idhousehold, isNull);
  });
}
