/// G63 — "thả" một ví khỏi trạng thái bị giữ: gỡ cờ + mốc chặn, và LÀM MỚI giờ sửa của ví cùng mọi bản ghi đang chờ
/// từng bị giữ vì nó.
///
/// Nghiệm thu hai máy ảo 2026-10-05 (bước 4 — Đổi tên): máy kia thấy ví đã đổi tên với số dư 0 đ và KHÔNG có giao
/// dịch nào. Kéo về là tăng dần theo `update_at` lớn nhất đã thấy, còn server giữ nguyên giờ ghi của máy; giao dịch ghi
/// lúc offline rồi bị giữ tới khi Đổi tên lên server với giờ CŨ hơn mốc của máy kia → không bao giờ được kéo.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/services/tha_vi_bi_giu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc = 7;
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final cu = DateTime(2026, 10, 5, 7, 43);

  Future<void> vi(String id, {String sync = 'pending'}) => db.walletDao.insert(WalletsCompanion.insert(
      id: id, idaccount: acc, name: 'Ví $id', syncStatus: Value(sync), updatedAt: cu));

  Future<void> gd(String id, String w, {String sync = 'pending', String? billId}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: w,
        idaccount: acc,
        amount: 1000,
        type: 'chi',
        date: cu,
        billId: Value(billId),
        syncStatus: Value(sync),
        updatedAt: cu,
      ));

  Future<void> hd(String id, String w) => db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: acc,
      name: 'Hoá đơn $id',
      amount: 1000,
      dueDate: cu,
      walletId: Value(w),
      syncStatus: const Value('pending'),
      updatedAt: cu));

  Future<void> mt(String id, String w, {String? viNguon}) => db.goalDao.insert(GoalsCompanion.insert(
      id: id,
      idaccount: acc,
      name: 'Mục tiêu $id',
      targetAmount: 1000000,
      targetDate: DateTime(2027, 1, 1),
      walletId: Value(w),
      autoDepositWalletId: Value(viNguon),
      syncStatus: const Value('pending'),
      updatedAt: cu));

  Future<DateTime> moiGd(String id) async => (await db.transactionDao.getById(id))!.updatedAt;

  test('⭐ làm mới giờ sửa của ví và MỌI bản ghi đang chờ dính tới nó; thứ không dính thì giữ nguyên', () async {
    await vi('r');
    await vi('p', sync: 'synced');
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.markSyncBlocked('r', DateTime.now().add(const Duration(hours: 1)), 'trùng tên');
    await gd('t-r', 'r');
    await hd('b-r', 'r');
    await gd('t-b', 'p', billId: 'b-r'); // dính qua hoá đơn bị giữ
    await mt('g-r', 'p', viNguon: 'r'); // trích từ ví bị giữ
    await gd('t-p', 'p'); // không dính
    final truoc = DateTime.now().subtract(const Duration(seconds: 2));

    await ThaViBiGiu(db: db).tha('r');

    final r = (await db.walletDao.getById('r'))!;
    expect(r.biTuChoiTrungTen, isFalse);
    expect(r.syncBlockedUntil, isNull, reason: 'còn mốc chặn thì giao dịch lên trước ví, vỡ khoá ngoại (bẫy 1)');
    expect(r.updatedAt.isAfter(truoc), isTrue);
    for (final id in ['t-r', 't-b']) {
      expect((await moiGd(id)).isAfter(truoc), isTrue, reason: '$id phải mang giờ mới để máy kia kéo được');
    }
    expect((await db.billDao.getById('b-r'))!.updatedAt.isAfter(truoc), isTrue);
    expect((await db.goalDao.getById('g-r'))!.updatedAt.isAfter(truoc), isTrue);
    expect(await moiGd('t-p'), cu, reason: 'không dính tới ví được thả — đừng đổi giờ sửa của nó');
  });

  test('bản ghi ĐÃ đồng bộ dính tới ví thì không bị đổi giờ (chỉ hàng đang chờ)', () async {
    await vi('r');
    await gd('t-cu', 'r', sync: 'synced');
    await ThaViBiGiu(db: db).tha('r');
    expect(await moiGd('t-cu'), cu);
  });

  test('ví không tồn tại → không ném', () async {
    await ThaViBiGiu(db: db).tha('khong-co');
  });
}
