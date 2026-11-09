/// `GoalDao.upsertKeoVe` — ghi mục tiêu kéo về mà GIỮ hàng của NHÀ còn `pending` (gia đình đợt 2, đợt sửa cuối, I-1).
/// Chủ bấm *Bỏ mục tiêu* hoặc đổi số tiền đúng lúc một lượt kéo đang bay: bản server (còn sống / số cũ) đè lên hàng `pending`,
/// hàng thành `synced` và lệnh của Chủ mất im lặng. Mục tiêu RIÊNG giữ hành vi cũ (ghi đè không điều kiện).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final luc = DateTime(2026, 11, 1, 9);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> them(String id, {int? nha, bool xoa = false, String sync = 'synced', double dich = 1000}) =>
      db.goalDao.insert(GoalsCompanion.insert(
        id: id,
        idaccount: 10,
        name: id,
        targetAmount: dich,
        targetDate: DateTime(2027, 1, 1),
        idhousehold: Value(nha),
        walletId: const Value('v'),
        isDeleted: Value(xoa),
        deletedAt: Value(xoa ? luc : null),
        syncStatus: Value(sync),
        updatedAt: luc,
      ));

  /// Bản server trả về: sống, số tiền cũ 1000, `synced`.
  GoalsCompanion tuServer(String id, {int? nha}) => GoalsCompanion(
        id: Value(id),
        idaccount: const Value(10),
        idhousehold: nha == null ? const Value.absent() : Value(nha),
        name: const Value('server'),
        targetAmount: const Value(1000),
        targetDate: Value(DateTime(2027, 1, 1)),
        walletId: const Value('v'),
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        syncStatus: const Value('synced'),
        updatedAt: Value(luc),
      );

  test('hàng của nhà đã xoá mềm mà còn pending: bản sống server KHÔNG làm nó sống lại', () async {
    await them('n', nha: 5, xoa: true, sync: 'pending');
    final giu = await db.goalDao.upsertKeoVe([tuServer('n', nha: 5)]);
    final g = (await db.goalDao.getById('n'))!;
    expect(g.isDeleted, isTrue, reason: 'lệnh Bỏ mục tiêu của Chủ chưa lên server: bản server đè là mục tiêu sống lại, synced');
    expect(g.syncStatus, 'pending', reason: 'còn pending để lượt đẩy sau mang lệnh xoá đi');
    expect(giu, 1);
  });

  test('hàng của nhà đã sửa số tiền mà còn pending: số tiền vừa sửa không bị bản server cũ đè', () async {
    await them('n', nha: 5, sync: 'pending', dich: 5000);
    await db.goalDao.upsertKeoVe([tuServer('n', nha: 5)]);
    expect((await db.goalDao.getById('n'))!.targetAmount, 5000);
  });

  test('hàng của nhà đã synced: bản server ghi đè như cũ; hàng mới trong cùng lô vẫn về', () async {
    await them('n', nha: 5, xoa: true, sync: 'synced');
    final giu = await db.goalDao.upsertKeoVe([tuServer('n', nha: 5), tuServer('moi', nha: 5)]);
    expect((await db.goalDao.getById('n'))!.isDeleted, isFalse);
    expect(await db.goalDao.getById('moi'), isNotNull);
    expect(giu, 0);
  });

  test('mục tiêu RIÊNG còn pending vẫn bị bản server ghi đè như cũ (không đổi hành vi mục tiêu riêng)', () async {
    await them('r', xoa: true, sync: 'pending');
    final giu = await db.goalDao.upsertKeoVe([tuServer('r')]);
    final g = (await db.goalDao.getById('r'))!;
    expect(g.isDeleted, isFalse,
        reason: 'chốt chỉ áp cho hàng của nhà: mục tiêu riêng giữ nguyên hành vi trước đợt này');
    expect(g.syncStatus, 'synced');
    expect(giu, 0);
  });

  test('lệnh Bỏ mục tiêu ghi XEN KẼ lúc đang ghi kéo về không bị bản sống đè (đọc + ghi cùng giao tác)', () async {
    await them('n', nha: 5, sync: 'synced');
    final ghi = db.goalDao.upsertKeoVe([tuServer('n', nha: 5)]);
    // Không `await` giữa hai lệnh: lệnh xoá xếp hàng NGAY sau lượt đọc. Không có giao tác thì nó lọt vào khe giữa đọc và ghi.
    final xoa = db.goalDao.softDelete('n');
    await Future.wait([ghi, xoa]);
    final g = (await db.goalDao.getById('n'))!;
    expect(g.isDeleted, isTrue,
        reason: 'lệnh xoá của Chủ đến sau phải thắng: không giao tác thì bản sống server ghi đè, mục tiêu sống lại + synced');
    expect(g.syncStatus, 'pending');
  });

  test('entries rỗng: không ném, trả 0', () async {
    expect(await db.goalDao.upsertKeoVe(const []), 0);
  });

  test('lô dài hơn trần tham số SQLite: không ném, hàng nhà pending vẫn được giữ', () async {
    await them('giu', nha: 5, xoa: true, sync: 'pending');
    final lo = [
      tuServer('giu', nha: 5),
      for (var i = 0; i < 33000; i++) tuServer('h$i', nha: 5),
    ];
    await db.goalDao.upsertKeoVe(lo);
    expect((await db.goalDao.getById('giu'))!.isDeleted, isTrue);
    expect(await db.goalDao.getById('h32999'), isNotNull);
  });
}
