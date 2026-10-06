/// Schema v29 (dự án C việc ba): hai bảng CỤC BỘ của thứ tự khối trang Phân
/// tích. Spec 2026-10-05-du-an-c-thu-tu-khoi-phan-tich-design.md mục 4.2.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

PhanTichThuTuPhanHoisCompanion _ph(String id, {int idaccount = 7, String cum = 'co_cau', String ketQua = 'dua_len'}) =>
    PhanTichThuTuPhanHoisCompanion.insert(
      id: id, idaccount: idaccount, cum: cum, ketQua: ketQua, createdAt: DateTime(2026, 10, 5, 8));

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema là v29', () => expect(db.schemaVersion, 29));

  test('hai bảng KHÔNG có cột đồng bộ', () async {
    for (final bang in ['phan_tich_giay_xems', 'phan_tich_thu_tu_phan_hois']) {
      final cols = await db.customSelect("PRAGMA table_info('$bang')").get();
      final ten = cols.map((r) => r.read<String>('name')).toSet();
      expect(ten, isNotEmpty, reason: '$bang phải tồn tại');
      expect(ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}), isEmpty,
          reason: 'bảng cục bộ — quy tắc 9');
    }
  });

  test('congGiay CỘNG DỒN theo (tài khoản, ngày, cụm)', () async {
    final dao = db.thuTuKhoiDao;
    await dao.congGiay(7, '2026-10-05', {'co_cau': 10, 'tong': 3}, xoaTruoc: '2026-07-07');
    await dao.congGiay(7, '2026-10-05', {'co_cau': 5}, xoaTruoc: '2026-07-07');
    await dao.congGiay(8, '2026-10-05', {'co_cau': 99}, xoaTruoc: '2026-07-07');
    final h = await dao.giayXemTu(7, '2026-10-01');
    expect({for (final r in h) r.cum: r.giay}, {'co_cau': 15, 'tong': 3});
  });

  test('giayXemTu lọc theo ngày; congGiay dọn hàng cũ hơn mốc', () async {
    final dao = db.thuTuKhoiDao;
    await dao.congGiay(7, '2026-06-01', {'tong': 4}, xoaTruoc: '2026-01-01');
    await dao.congGiay(7, '2026-09-30', {'tong': 4}, xoaTruoc: '2026-01-01');
    expect(await dao.giayXemTu(7, '2026-09-01'), hasLength(1));
    await dao.congGiay(7, '2026-10-05', {'tong': 1}, xoaTruoc: '2026-07-07');
    expect(await dao.giayXemTu(7, '2000-01-01'), hasLength(2), reason: 'hàng 01/06 đã bị dọn');
  });

  test('phanHoi theo tài khoản, xếp theo lúc bấm', () async {
    final dao = db.thuTuKhoiDao;
    await dao.ghiPhanHoi(_ph('b').copyWith(createdAt: Value(DateTime(2026, 10, 5, 9))));
    await dao.ghiPhanHoi(_ph('a'));
    await dao.ghiPhanHoi(_ph('c', idaccount: 8));
    expect((await dao.phanHoi(7)).map((e) => e.id), ['a', 'b']);
  });

  test('purge: tài khoản khác bị dọn ở cả hai bảng, của mình còn', () async {
    final dao = db.thuTuKhoiDao;
    await dao.congGiay(7, '2026-10-05', {'tong': 1}, xoaTruoc: '2026-07-07');
    await dao.congGiay(8, '2026-10-05', {'tong': 1}, xoaTruoc: '2026-07-07');
    await dao.ghiPhanHoi(_ph('a'));
    await dao.ghiPhanHoi(_ph('b', idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect(await dao.giayXemTu(8, '2000-01-01'), isEmpty);
    expect(await dao.phanHoi(8), isEmpty);
    expect(await dao.giayXemTu(7, '2000-01-01'), hasLength(1));
    await db.purgeDataForAccount(7);
    expect(await dao.giayXemTu(7, '2000-01-01'), isEmpty);
    expect(await dao.phanHoi(7), isEmpty);
  });

  test('migration v28 → v29 chỉ TẠO hai bảng', () async {
    final cu = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) {
      // Fixture tối thiểu: bước v29 chỉ createTable; giữ một bảng cũ để
      // chứng minh nó còn nguyên.
      d.execute('CREATE TABLE wallets (id TEXT NOT NULL PRIMARY KEY)');
      d.execute("INSERT INTO wallets VALUES ('w1')");
      d.execute('PRAGMA user_version = 28');
    }));
    addTearDown(cu.close);
    await cu.thuTuKhoiDao.congGiay(7, '2026-10-05', {'tong': 1}, xoaTruoc: '2026-07-07');
    expect(await cu.thuTuKhoiDao.giayXemTu(7, '2000-01-01'), hasLength(1));
    final w = await cu.customSelect('SELECT id FROM wallets').get();
    expect(w.single.read<String>('id'), 'w1');
  });
}
