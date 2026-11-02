import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> them(
    String id, {
    int idaccount = 10,
    int? nha,
    String? vi,
    bool xoa = false,
    String sync = 'synced',
    DateTime? luc,
  }) async {
    await db.goalDao.insert(GoalsCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: id,
      targetAmount: 1000,
      targetDate: DateTime(2027, 1, 1),
      idhousehold: Value(nha),
      walletId: Value(vi),
      isDeleted: Value(xoa),
      deletedAt: Value(xoa ? DateTime(2026, 11, 2) : null),
      syncStatus: Value(sync),
      updatedAt: luc ?? DateTime(2026, 11, 1),
    ));
  }

  test('getAll và watchAll bỏ hàng của nhà dù idaccount trùng', () async {
    await them('rieng');
    await them('chung', nha: 5);
    expect((await db.goalDao.getAll(10)).map((g) => g.id), ['rieng'],
        reason: 'Bộ trích tự động và /goals đọc getAll: hàng của nhà lọt vào là rút tiền ví riêng nuôi quỹ chung');
    expect((await db.goalDao.watchAll(10).first).map((g) => g.id), ['rieng']);
  });

  test('getCuaNha nhận hàng tài khoản khác ghi, bỏ hàng đã xoá', () async {
    await them('a', idaccount: 10, nha: 5);
    await them('b', idaccount: 11, nha: 5);
    await them('c', idaccount: 10, nha: 5, xoa: true);
    await them('d', idaccount: 10, nha: 6);
    await them('e');
    expect((await db.goalDao.getCuaNha(5)).map((g) => g.id).toSet(), {'a', 'b'});
    expect((await db.goalDao.watchCuaNha(5).first).map((g) => g.id).toSet(), {'a', 'b'});
  });

  test('getSongTheoVi bỏ hàng đã xoá và hàng riêng cùng ví; hai hàng thì lấy mới nhất', () async {
    await them('xoa', nha: 5, vi: 'v', xoa: true);
    await them('rieng', vi: 'v');
    expect(await db.goalDao.getSongTheoVi('v'), isNull);
    await them('cu', nha: 5, vi: 'v', luc: DateTime(2026, 1, 1));
    await them('moi', nha: 5, vi: 'v', luc: DateTime(2026, 2, 1));
    expect((await db.goalDao.getSongTheoVi('v'))!.id, 'moi');
  });

  test('getXoaChuaDayTheoVi chỉ nhận hàng nhà đã xoá mà còn pending', () async {
    await them('sach', nha: 5, vi: 'v', xoa: true, sync: 'synced');
    await them('song', nha: 5, vi: 'v', sync: 'pending');
    await them('riengXoa', vi: 'v', xoa: true, sync: 'pending');
    expect(await db.goalDao.getXoaChuaDayTheoVi('v'), isNull);
    await them('can', nha: 5, vi: 'v', xoa: true, sync: 'pending');
    expect((await db.goalDao.getXoaChuaDayTheoVi('v'))!.id, 'can');
    await them('canMoi', nha: 5, vi: 'v', xoa: true, sync: 'pending', luc: DateTime(2026, 12, 1));
    expect((await db.goalDao.getXoaChuaDayTheoVi('v'))!.id, 'canMoi',
        reason: 'Hai hàng xoá chưa đẩy: hồi sinh hàng mới hơn');
  });

  test('GoalEntity giữ idhousehold qua fromDrift, toCompanion và copyWith', () async {
    await them('g', nha: 5, vi: 'v');
    final e = GoalEntity.fromDrift((await db.goalDao.getById('g'))!);
    expect(e.idhousehold, 5);
    expect(e.copyWith(name: 'x').idhousehold, 5);
    await db.goalDao.insert(e.toCompanion());
    expect((await db.goalDao.getById('g'))!.idhousehold, 5,
        reason: 'insert là insertOrReplace, thay nguyên hàng: toCompanion làm rơi idhousehold thì mục tiêu chung hoá riêng');
  });
}
