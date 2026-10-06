/// G63 — `ViTrungTenNguon` đọc MỌI ví chưa xoá (kể cả lưu trữ) rồi gọi `capViTrungTen`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/vi_trung_ten_nguon.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc = 7;
  late AppDatabase db;
  late ViTrungTenNguonImpl nguon;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nguon = ViTrungTenNguonImpl(db: db);
  });
  tearDown(() => db.close());

  Future<void> vi(String id, String ten, {String status = 'active', int idaccount = acc}) =>
      db.walletDao.insert(WalletsCompanion.insert(
          id: id, idaccount: idaccount, name: ten, status: Value(status), updatedAt: DateTime(2026, 10, 5)));

  test('⭐ R bị từ chối + P cùng tên → {R}', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), {'r'});
  });

  test('P đang LƯU TRỮ vẫn giữ R', () async {
    await vi('p', 'Ví MB Bank', status: 'inactive');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), {'r'});
  });

  test('P đã xoá mềm → không giữ', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    await db.walletDao.softDelete('p');
    expect(await nguon.viDangBiGiu(acc), isEmpty);
  });

  test('ví của tài khoản khác không làm thành cặp', () async {
    await vi('p', 'Ví MB Bank', idaccount: 8);
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    expect(await nguon.viDangBiGiu(acc), isEmpty);
  });

  test('⭐ theoDoi: số dư hai ví + số giao dịch của ví máy này KHÔNG tính khoản mở sổ', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');
    final ngay = DateTime(2026, 10, 5);
    for (final (id, loai, tien) in [
      (idKhoanMoSo('r'), 'thu', 1000000.0),
      ('t1', 'thu', 500000.0),
      ('t2', 'chi', 250000.0),
    ]) {
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: id, walletId: 'r', idaccount: acc, amount: tien, type: loai, date: ngay, updatedAt: ngay));
    }
    // Chỉ test dựng số dư thẳng qua DAO — test quét `so_du_mot_noi_ghi_test` chỉ quét `lib/`.
    await db.walletDao.updateBalance('r', 1250000);
    await db.walletDao.updateBalance('p', 3400000);

    final cap = (await nguon.theoDoi(acc).first).single;

    expect(cap.idViMayNay, 'r');
    expect(cap.idViDaDongBo, 'p');
    expect(cap.ten, 'Ví MB Bank');
    expect(cap.soDuMayNay, 1250000);
    expect(cap.soDuDaDongBo, 3400000);
    expect(cap.soGiaoDich, 2, reason: 'Khoản "Số dư ban đầu" không phải giao dịch người dùng ghi.');
    expect(cap.coTheGop, isTrue);
  });

  test('theoDoi: ví đã đồng bộ là ví liên kết ngân hàng → lý do không gộp', () async {
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'p', idaccount: acc, name: 'Ví MB Bank', type: const Value('banking'), updatedAt: DateTime(2026, 10, 5)));
    await vi('r', 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen('r');

    final cap = (await nguon.theoDoi(acc).first).single;

    expect(cap.coTheGop, isFalse);
    expect(cap.lyDoKhongGop, isNotNull);
  });

  test('theoDoi: phát lại khi cờ được đặt trong lúc đang nghe', () async {
    await vi('p', 'Ví MB Bank');
    await vi('r', 'Ví MB Bank');
    final ds = nguon.theoDoi(acc).map((c) => c.length);
    final thay = <int>[];
    final sub = ds.listen(thay.add);
    await pumpEventQueue();
    await db.walletDao.danhDauTrungTen('r');
    await pumpEventQueue();
    await sub.cancel();
    expect(thay, [0, 1]);
  });
}
