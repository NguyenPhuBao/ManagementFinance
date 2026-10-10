/// G87 (2026-10-09) — phần GHI của việc gộp kỳ trùng: `BillRepository.gopKyTrung` và chốt trong `payBill`.
///
/// Hàm chọn (`kyTrungCanGo`) test ở `domain/bill_ky_trung_test.dart`. Ở đây canh ba thứ chỉ CSDL thật lộ ra:
/// lệnh xoá phải lên server (`pending`), cơ chế Pull nuốt lệnh xoá rồi lượt gộp xoá lại, và `payBill` không trừ
/// tiền lần thứ hai cho một kỳ đã có kỳ trùng được trả.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/domain/bill_pay_status.dart';

class _SyncDem implements SyncEngine {
  int soLan = 0;
  @override
  void scheduleSync() => soLan++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repo;
  const tk = 10;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: tk,
      name: 'Tiền mặt',
      balance: const Value(1000000.0),
      updatedAt: DateTime(2025, 1, 1),
    ));
  });

  tearDown(() => db.close());

  BillsCompanion ky(String id, {String? cha, required DateTime han, String trangThai = kBillPending}) =>
      BillsCompanion.insert(
        id: id,
        idaccount: tk,
        walletId: const Value('w1'),
        categoryId: const Value('c1'),
        name: 'Netflix',
        amount: 100000,
        startDate: Value(han.subtract(const Duration(days: 8))),
        dueDate: han,
        payStatus: Value(trangThai),
        isPaid: Value(trangThai == kBillPayed),
        isRecurrence: const Value(true),
        timeRecurrence: const Value(kBillCycleWeek),
        recurrence: const Value('weekly'),
        autoPayEnabled: const Value(true),
        generatedFromBillId: Value(cha),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2025, 10, 1),
      );

  final h0510 = DateTime(2025, 10, 5);

  Future<void> netflixTruoc0810() async {
    await db.billDao.insert(ky('g', han: DateTime(2025, 9, 28), trangThai: kBillPayed));
    await db.billDao.insert(ky('k1', cha: 'g', han: h0510, trangThai: kBillPayed));
    await db.billDao.insert(ky('k2', cha: 'g', han: h0510, trangThai: kBillOverdue));
    await db.billDao.insert(ky('k3', cha: 'g', han: h0510, trangThai: kBillOverdue));
  }

  test('gopKyTrung xoá mềm kỳ trùng và đánh dấu CHỜ ĐẨY — lệnh xoá phải lên server', () async {
    await netflixTruoc0810();

    expect(await repo.gopKyTrung(tk), 2);

    for (final id in ['k2', 'k3']) {
      final b = (await db.billDao.getById(id))!;
      expect(b.isDeleted, isTrue, reason: '$id là kỳ trùng chưa trả');
      expect(b.syncStatus, 'pending',
          reason: 'chỉ xoá trên máy này là hai máy lệch nhau im lặng — cờ xoá phải được đẩy lên');
    }
    expect((await db.billDao.getById('k1'))!.isDeleted, isFalse);
    expect(await repo.gopKyTrung(tk), 0, reason: 'chạy lại không gỡ thêm gì (luỹ đẳng)');
  });

  test('⭐ cơ chế G87: Pull ghi đè lệnh xoá đang chờ đẩy, lượt gộp sau xoá lại', () async {
    await netflixTruoc0810();
    // Bộ gỡ xung đột xoá kỳ con của máy thua…
    await db.billDao.softDelete('k3');
    // …rồi bước Pull cùng chu kỳ mang bản SỐNG của server về (upsertAll không xét hàng đang chờ đẩy).
    await db.billDao.upsertAll([
      ky('k3', cha: 'g', han: h0510, trangThai: kBillOverdue).copyWith(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime(2025, 10, 3)),
      ),
    ]);
    final song = (await db.billDao.getById('k3'))!;
    expect(song.isDeleted, isFalse, reason: 'tiền đề: lỗ của Pull có thật — nếu đỏ, Pull đã đổi và mục G87 cần xem lại');
    expect(song.syncStatus, 'synced');

    await repo.gopKyTrung(tk);

    final sau = (await db.billDao.getById('k3'))!;
    expect(sau.isDeleted, isTrue);
    expect(sau.syncStatus, 'pending');
  });

  test('payBill TỪ CHỐI kỳ có kỳ trùng đã trả — không trừ tiền lần hai, không đẻ kỳ', () async {
    await netflixTruoc0810();
    final k2 = (await db.billDao.getById('k2'))!;

    await expectLater(
      repo.payBill(bill: k2, walletId: 'w1', idaccount: tk, occurredAt: h0510),
      throwsA(isA<BillAlreadyPaidException>()),
    );

    expect((await db.transactionDao.getAll(tk)).where((t) => t.billId == 'k2'), isEmpty,
        reason: 'server chỉ chặn trả hai lần CÙNG Idbill — kỳ trùng mang id khác nên chốt phải ở client');
    expect(await db.billDao.getGeneratedFrom('k2'), isNull);
    expect((await db.billDao.getById('k2'))!.isPaid, isFalse);
  });

  test('gopKyTrung có gỡ thì HẸN ĐỒNG BỘ; không gỡ gì thì không', () async {
    // Nghiệm thu Realme 2026-10-09: lượt gộp đánh dấu xoá đúng bốn kỳ nhưng lệnh xoá nằm chờ tới lần đồng bộ kế
    // tiếp (tới 15 phút) — trong lúc ấy máy khác vẫn thấy và có thể tự trả các kỳ trùng.
    final dem = _SyncDem();
    final r = BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db, syncEngine: dem);
    await netflixTruoc0810();

    await r.gopKyTrung(tk);
    expect(dem.soLan, 1);

    await r.gopKyTrung(tk);
    expect(dem.soLan, 1, reason: 'không gỡ gì thì không hẹn — tránh vòng đồng bộ thừa sau mỗi lượt quét');
  });
}
