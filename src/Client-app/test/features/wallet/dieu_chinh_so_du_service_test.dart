/// Đường ghi của điều chỉnh số dư — nơi luật thuần gặp CSDL thật.
///
/// Khoản bù đi qua `TransactionRepository.addTransaction`, **cố ý** chứ không
/// ghi thẳng số dư: nhờ đó phép cộng trừ số dư và phép **hoàn lại khi xoá** đều
/// dùng lại `_applyBalances` đã có, đúng cả hai chiều. Một bản ghi thẳng
/// `updateBalance` sẽ tạo ra một khoản không xoá lại được — đúng cái hố mà ô số
/// dư ở màn Sửa ví đang có.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/wallet/data/services/dieu_chinh_so_du_service.dart';

class _SyncEngineGia implements SyncEngine {
  @override
  Future<void> scheduleSync() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl txRepo;
  late DieuChinhSoDuService service;

  const idaccount = 7;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    txRepo = TransactionRepositoryImpl(
      localDataSource: TransactionLocalDataSourceImpl(db),
      walletDao: db.walletDao,
      syncEngine: _SyncEngineGia(),
    );
    service = DieuChinhSoDuService(db: db, transactionRepository: txRepo);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: idaccount,
      name: 'Tiền mặt',
      balance: const Value(1000000),
      updatedAt: DateTime(2026, 9, 10),
    ));
  });

  tearDown(() async => db.close());

  Future<List<Transaction>> giaoDich() => db.transactionDao.getAll(idaccount);

  test('số dư thực LỚN HƠN: ghi một khoản thu, ví về đúng số thực', () async {
    await service.dieuChinh(walletId: 'w1', soDuThucTe: 1250000, lyDo: '');

    final t = (await giaoDich()).single;
    expect(t.type, 'thu');
    expect(t.amount, 250000);
    expect((await db.walletDao.getById('w1'))!.balance, 1250000,
        reason: 'Số dư phải bằng ĐÚNG con số người dùng nhập — đó là toàn bộ '
            'mục đích của việc đối soát.');
  });

  test('số dư thực NHỎ HƠN: ghi một khoản chi', () async {
    await service.dieuChinh(walletId: 'w1', soDuThucTe: 700000, lyDo: '');

    final t = (await giaoDich()).single;
    expect(t.type, 'chi');
    expect(t.amount, 300000);
    expect((await db.walletDao.getById('w1'))!.balance, 700000);
  });

  test('khoản sinh ra mang ĐỦ CẶP dấu hiệu', () async {
    await service.dieuChinh(
        walletId: 'w1', soDuThucTe: 1250000, lyDo: 'đếm lại ví');

    final t = (await giaoDich()).single;
    expect(t.categoryId, isNull,
        reason: 'Chân cấu trúc của phép nhận dạng. Có danh mục là khoản bù bị '
            'đếm vào thống kê.');
    expect(t.note, startsWith('Điều chỉnh số dư'),
        reason: 'Chân ghi chú, dựng bằng `ghiChuDieuChinh` để nơi ghi và nơi '
            'đọc không lệch nhau.');
    expect(t.note, contains('đếm lại ví'));
  });

  test('bằng nhau thì KHÔNG ghi gì và KHÔNG đụng ví', () async {
    await service.dieuChinh(walletId: 'w1', soDuThucTe: 1000000, lyDo: '');

    expect(await giaoDich(), isEmpty,
        reason: 'PostgreSQL có chk_transaction_nonzero_amount bắt Amount <> 0; '
            'ghi một khoản 0đ là bản ghi kẹt hàng đợi đẩy vĩnh viễn.');
    expect((await db.walletDao.getById('w1'))!.balance, 1000000);
  });

  test('XOÁ khoản điều chỉnh thì số dư quay lại như cũ', () async {
    await service.dieuChinh(walletId: 'w1', soDuThucTe: 1250000, lyDo: '');
    final t = (await giaoDich()).single;

    await txRepo.deleteTransaction(TransactionEntity.fromDrift(t));

    expect((await db.walletDao.getById('w1'))!.balance, 1000000,
        reason: 'Đây là lý do khoản bù đi qua `addTransaction` chứ không ghi '
            'thẳng `updateBalance`: phép hoàn lại có sẵn và đúng. Một bản ghi '
            'thẳng sẽ để lại khoản không xoá lại được.');
  });

  test('ví ĐÃ LƯU TRỮ thì từ chối, không ghi gì', () async {
    await db.walletDao.setStatus('w1', luuTru: true);

    await expectLater(
      () => service.dieuChinh(walletId: 'w1', soDuThucTe: 1250000, lyDo: ''),
      throwsA(isA<CacheException>()),
      reason: 'Lưu trữ là ĐÓNG BĂNG: không ghi giao dịch mới. Cho đối soát ví '
          'lưu trữ là mở lại đúng cánh cửa vừa đóng.',
    );
    expect(await giaoDich(), isEmpty);
    expect((await db.walletDao.getById('w1'))!.balance, 1000000);
  });

  test('ví không tồn tại thì ném, không ghi gì', () async {
    await expectLater(
      () => service.dieuChinh(walletId: 'w_ma', soDuThucTe: 1, lyDo: ''),
      throwsA(isA<CacheException>()),
    );
    expect(await giaoDich(), isEmpty);
  });
}
