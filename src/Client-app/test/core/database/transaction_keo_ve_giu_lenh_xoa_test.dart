/// `TransactionDao.upsertKeoVe` — ghi giao dịch kéo về mà GIỮ lệnh xoá còn chờ đẩy (gia đình 1A, đợt sửa sau review toàn nhánh).
/// Ba chốt, mỗi chốt hỏng im lặng: (1) đọc "hàng đã xoá còn pending" và ghi phải CÙNG một giao tác — lệnh xoá ghi xen vào
/// giữa là bị bản sống server đè, hàng sống lại với `synced`; (2) chỉ giữ khi bản server CÒN SỐNG — bản server đã xoá thì cho
/// qua để hàng thoát hàng đợi (giữ cả bản đã xoá ở hai phía là hàng pending mãi); (3) không dùng `isIn` theo lô — lô kéo về
/// dài hơn trần tham số của SQLite thì ném.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final ngay = DateTime(2026, 11, 1, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'v', idaccount: 10, name: 'Ví', balance: const Value(1000), updatedAt: DateTime(2026, 10, 1)));
  });
  tearDown(() => db.close());

  Future<void> themGd(String id, {required bool xoa, required String trangThai}) =>
      db.transactionDao.insert(TransactionsCompanion(
        id: Value(id),
        idaccount: const Value(10),
        walletId: const Value('v'),
        amount: const Value(500),
        type: const Value('chi'),
        date: Value(ngay),
        isDeleted: Value(xoa),
        deletedAt: Value(xoa ? ngay : null),
        syncStatus: Value(trangThai),
        updatedAt: Value(ngay),
      ));

  /// Bản kéo về của hàng [id]: sống hoặc đã xoá ở server.
  TransactionsCompanion tuServer(String id, {required bool daXoa}) => TransactionsCompanion(
        id: Value(id),
        idaccount: const Value(10),
        walletId: const Value('v'),
        amount: const Value(500),
        type: const Value('chi'),
        date: Value(ngay),
        isDeleted: Value(daXoa),
        deletedAt: Value(daXoa ? ngay : null),
        syncStatus: const Value('synced'),
        updatedAt: Value(ngay),
      );

  test('lệnh xoá ghi XEN KẼ lúc đang ghi kéo về không bị bản sống đè (đọc + ghi cùng giao tác)', () async {
    await themGd('c', xoa: false, trangThai: 'synced');
    final ghi = db.transactionDao.upsertKeoVe([tuServer('c', daXoa: false)]);
    // Không `await` giữa hai lệnh: lệnh xoá xếp hàng NGAY sau lượt đọc. Không có giao tác thì nó lọt vào khe giữa đọc và ghi.
    final xoa = db.transactionDao.softDelete('c');
    await Future.wait([ghi, xoa]);
    final c = (await db.transactionDao.getById('c'))!;
    expect(c.isDeleted, isTrue,
        reason: 'lệnh xoá của người dùng đến sau phải thắng: không giao tác thì bản sống server ghi đè, hàng sống lại với '
            '`synced` và lệnh xoá không bao giờ lên server');
    expect(c.syncStatus, 'pending', reason: 'còn pending để lượt đẩy sau mang lệnh xoá đi');
  });

  test('hàng xoá-chưa-đẩy mà bản server còn SỐNG: giữ lệnh xoá', () async {
    await themGd('a', xoa: true, trangThai: 'pending');
    await db.transactionDao.upsertKeoVe([tuServer('a', daXoa: false)]);
    final a = (await db.transactionDao.getById('a'))!;
    expect(a.isDeleted, isTrue);
    expect(a.syncStatus, 'pending');
  });

  test('hàng xoá-chưa-đẩy mà bản server cũng ĐÃ XOÁ: cho qua, hàng thoát hàng đợi', () async {
    await themGd('a', xoa: true, trangThai: 'pending');
    await db.transactionDao.upsertKeoVe([tuServer('a', daXoa: true)]);
    final a = (await db.transactionDao.getById('a'))!;
    expect(a.isDeleted, isTrue);
    expect(a.syncStatus, 'synced',
        reason: 'đã xoá ở cả hai phía: không giữ pending mãi (đẩy lệnh xoá cho hàng server đã xoá là việc thừa)');
  });

  test('hàng xoá đã đẩy (synced) hay hàng sống: bản server ghi đè như cũ', () async {
    await themGd('b', xoa: true, trangThai: 'synced');
    await db.transactionDao.upsertKeoVe([tuServer('b', daXoa: false), tuServer('moi', daXoa: false)]);
    expect((await db.transactionDao.getById('b'))!.isDeleted, isFalse);
    expect(await db.transactionDao.getById('moi'), isNotNull);
  });

  test('lô kéo về dài hơn trần tham số SQLite: không ném, hàng xoá-chưa-đẩy vẫn được giữ', () async {
    await themGd('giu', xoa: true, trangThai: 'pending');
    final lo = [
      tuServer('giu', daXoa: false),
      for (var i = 0; i < 33000; i++) tuServer('h$i', daXoa: false),
    ];
    await db.transactionDao.upsertKeoVe(lo);
    expect((await db.transactionDao.getById('giu'))!.isDeleted, isTrue);
    expect(await db.transactionDao.getById('h32999'), isNotNull);
  });
}
