/// Nguồn dữ liệu của thẻ "Có vẻ là khoản lặp" (B2): đọc giao dịch 120 ngày, hoá
/// đơn và phản hồi của MỘT tài khoản rồi gọi hai hàm thuần; ghi bo_qua / da_tao.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/de_xuat_hoa_don_nguon.dart';
import 'package:flowmoney/features/bill/domain/de_xuat_hoa_don.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 20, 9);
  var soId = 0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final id in [10, 11]) {
      await db.into(db.wallets).insert(
          WalletsCompanion.insert(id: 'v$id', idaccount: id, name: 'Vi $id', updatedAt: now));
    }
  });
  tearDown(() => db.close());

  Future<void> gd(int idaccount, DateTime ngay, {String note = 'Tiền nhà T9', double tien = 3000000}) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 't${soId++}',
            walletId: 'v$idaccount',
            idaccount: idaccount,
            categoryId: const Value('c-nha'),
            amount: tien,
            type: 'chi',
            note: Value(note),
            date: ngay,
            updatedAt: ngay,
          ));

  Future<void> baThang(int idaccount) async {
    await gd(idaccount, DateTime(2026, 9, 5));
    await gd(idaccount, DateTime(2026, 10, 5), note: 'tiền nhà tháng 10');
    await gd(idaccount, DateTime(2026, 11, 5), note: 'Tiền nhà T11');
  }

  DeXuatHoaDonNguon nguon() => DeXuatHoaDonNguon(db: db, clock: () => now);

  test('ba lần Tiền nhà cách tháng → tai trả đúng một khoản của đúng tài khoản', () async {
    await baThang(10);
    final r = await nguon().tai(10);
    expect(r, hasLength(1));
    expect(r!.single.khoaNhom, 'tien nha|c-nha');
    expect(r.single.ten, 'Tiền nhà');
    expect(await nguon().tai(11), isNull, reason: 'tài khoản khác không có gì — không lẫn dữ liệu');
  });

  test('boQua → tai trả null, và hàng bo_qua ghi đúng tài khoản', () async {
    await baThang(10);
    final n = nguon();
    await n.boQua(10, 'tien nha|c-nha');
    expect(await n.tai(10), isNull);
    final ph = await db.goiYHoaDonDao.getAll(10);
    expect(ph.single.ketQua, kGoiYBoQua);
    expect(ph.single.createdAt, now);
  });

  test('daTao → tai trả null', () async {
    await baThang(10);
    final n = nguon();
    await n.daTao(10, 'tien nha|c-nha');
    expect(await n.tai(10), isNull);
    expect((await db.goiYHoaDonDao.getAll(10)).single.ketQua, kGoiYDaTao);
  });

  test('đã có hoá đơn đang sống tên "Tiền nhà" → tai trả null', () async {
    await baThang(10);
    await db.into(db.bills).insert(BillsCompanion.insert(
          id: 'b1',
          idaccount: 10,
          name: 'Tiền nhà',
          amount: 3000000,
          dueDate: DateTime(2026, 12, 5),
          updatedAt: now,
        ));
    expect(await nguon().tai(10), isNull);
  });

  test('giao dịch cũ hơn 120 ngày không được đọc', () async {
    // Ba lần cách tháng nhưng lần cuối ngày 5/7 → quá 45 ngày; nếu cửa sổ đọc
    // rộng hơn cũng không ra gì. Ca canh là đối chứng: cùng dữ liệu, now sớm hơn.
    await gd(10, DateTime(2026, 5, 5));
    await gd(10, DateTime(2026, 6, 5));
    await gd(10, DateTime(2026, 7, 5));
    expect(await nguon().tai(10), isNull);
    expect(await DeXuatHoaDonNguon(db: db, clock: () => DateTime(2026, 7, 20)).tai(10), hasLength(1));
  });

  test('idaccount không hợp lệ → null, không đọc gì (quy tắc 2)', () async {
    await baThang(10);
    expect(await nguon().tai(0), isNull);
  });

  test('bangDanhMuc gồm danh mục của tài khoản VÀ danh mục mặc định toàn cục (G41)', () async {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c-nha', idaccount: 10, name: 'Nhà cửa', classify: 'chi', updatedAt: now,
        icon: const Value('home')));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c-mac-dinh', idaccount: 0, name: 'Ăn uống', classify: 'chi', updatedAt: now,
        isDefault: const Value(true)));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c-khac', idaccount: 11, name: 'Của người khác', classify: 'chi', updatedAt: now));
    final bang = await nguon().bangDanhMuc(10);
    expect(bang.keys, containsAll(['c-nha', 'c-mac-dinh']),
        reason: 'thiếu hàng mặc định là dòng trỏ vào danh mục mặc định mất biểu tượng');
    expect(bang.containsKey('c-khac'), isFalse);
    expect(bang['c-nha']!.icon, 'home');
  });

  test('lỗi khi nạp → null, không ném', () async {
    final hong = DeXuatHoaDonNguon(db: db, clock: () => throw StateError('hong'));
    expect(await hong.tai(10), isNull);
  });
}
