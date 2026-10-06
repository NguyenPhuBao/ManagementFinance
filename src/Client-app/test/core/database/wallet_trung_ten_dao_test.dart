/// G63 — cờ cục bộ `wallets.bi_tu_choi_trung_ten` (spec 2026-10-05 mục 4.1).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc = 7;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'r',
      idaccount: acc,
      name: 'Ví MB Bank',
      updatedAt: DateTime(2026, 10, 5),
    ));
  });
  tearDown(() => db.close());

  Future<Wallet> doc() async => (await db.walletDao.getById('r'))!;

  test('ví mới mặc định KHÔNG mang cờ', () async {
    expect((await doc()).biTuChoiTrungTen, isFalse);
  });

  test('danhDauTrungTen đặt cờ', () async {
    await db.walletDao.danhDauTrungTen('r');
    expect((await doc()).biTuChoiTrungTen, isTrue);
  });

  test('⭐ goCoTrungTen gỡ cờ VÀ mốc chặn theo giờ (bẫy 1)', () async {
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.markSyncBlocked('r', DateTime(2026, 10, 5, 12), 'Tên ví đã tồn tại');

    await db.walletDao.goCoTrungTen('r');

    final w = await doc();
    expect(w.biTuChoiTrungTen, isFalse);
    expect(w.syncBlockedUntil, isNull,
        reason: 'Gỡ mỗi cờ thì ví còn bị chặn tới 60 phút trong khi giao dịch của nó đã được thả — chúng lên '
            'trước ví, vỡ khoá ngoại, quay lại đúng vòng lặp G63.');
    expect(w.syncError, isNull);
    expect(w.syncRetryCount, 0);
  });

  test('markSynced gỡ cờ — ví đã lên server thì không còn bị từ chối', () async {
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.markSynced('r');
    expect((await doc()).biTuChoiTrungTen, isFalse);
  });

  test('⭐ lượt kéo về (upsertAll, companion không mang cột) GIỮ cờ', () async {
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.upsertAll([
      WalletsCompanion(
        id: const Value('r'),
        idaccount: const Value(acc),
        name: const Value('Ví MB Bank'),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 10, 6)),
      ),
    ]);
    expect((await doc()).biTuChoiTrungTen, isTrue,
        reason: 'insertAllOnConflictUpdate chỉ ghi cột companion mang; cột cục bộ phải sống qua mọi lượt kéo về '
            '(quy tắc 3 CLAUDE.md).');
  });

  test('datasource đọc cờ lên entity, và update KHÔNG ghi đè cờ', () async {
    final ds = WalletLocalDataSourceImpl(db: db);
    await db.walletDao.danhDauTrungTen('r');

    final vi = (await ds.getById('r'))!;
    expect(vi.biTuChoiTrungTen, isTrue);

    await ds.update(vi.copyWith(icon: 'bank', biTuChoiTrungTen: false));
    expect((await doc()).biTuChoiTrungTen, isTrue,
        reason: '_toCompanion cố ý không mang cờ: form Sửa ví không sửa nó; ba chỗ ghi ở WalletDao.');
  });
}
