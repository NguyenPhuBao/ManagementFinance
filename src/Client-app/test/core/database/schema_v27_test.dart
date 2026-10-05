/// Schema v27 (B2): bảng `goi_y_hoa_don_phan_hois` — phản hồi của người dùng với
/// thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn, CỤC BỘ. Spec
/// 2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md mục 3.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

GoiYHoaDonPhanHoisCompanion _ph({
  required String id,
  int idaccount = 7,
  String khoaNhom = 'tien nha|c-nha',
  String ketQua = 'bo_qua',
  DateTime? luc,
}) =>
    GoiYHoaDonPhanHoisCompanion.insert(
      id: id,
      idaccount: idaccount,
      khoaNhom: khoaNhom,
      ketQua: ketQua,
      createdAt: luc ?? DateTime(2026, 9, 29, 8),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema từ v27 trở lên', () => expect(db.schemaVersion, greaterThanOrEqualTo(27)));

  test('bảng goi_y_hoa_don_phan_hois có đủ cột và KHÔNG có cột đồng bộ', () async {
    final cols = await db.customSelect("PRAGMA table_info('goi_y_hoa_don_phan_hois')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, containsAll(['id', 'idaccount', 'khoa_nhom', 'ket_qua', 'created_at']));
    expect(ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}), isEmpty,
        reason: 'bảng cục bộ — vắng cột đồng bộ chính là tài liệu sống (quy tắc 9)');
  });

  test('ghi và đọc theo tài khoản, xếp theo lúc bấm', () async {
    final dao = db.goiYHoaDonDao;
    await dao.ghi(_ph(id: 'b', luc: DateTime(2026, 9, 29, 9)));
    await dao.ghi(_ph(id: 'a', luc: DateTime(2026, 9, 29, 8), ketQua: 'da_tao'));
    await dao.ghi(_ph(id: 'c', idaccount: 8));
    final cua7 = await dao.getAll(7);
    expect(cua7.map((e) => e.id), ['a', 'b']);
    expect(cua7.first.ketQua, 'da_tao');
    expect(cua7.first.khoaNhom, 'tien nha|c-nha');
    expect(await dao.getAll(8), hasLength(1));
  });

  test('purgeDataForOtherAccounts xoá phản hồi của tài khoản khác, giữ của mình', () async {
    final dao = db.goiYHoaDonDao;
    await dao.ghi(_ph(id: 'cua-7'));
    await dao.ghi(_ph(id: 'cua-8', idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect(await dao.getAll(8), isEmpty);
    expect(await dao.getAll(7), hasLength(1));
  });

  test('purgeDataForAccount xoá phản hồi của chính tài khoản ấy', () async {
    final dao = db.goiYHoaDonDao;
    await dao.ghi(_ph(id: 'cua-7'));
    await dao.ghi(_ph(id: 'cua-8', idaccount: 8));
    await db.purgeDataForAccount(7);
    expect(await dao.getAll(7), isEmpty);
    expect(await dao.getAll(8), hasLength(1));
  });

  group('migration v26 → v27', () {
    late AppDatabase cu;
    setUp(() {
      cu = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          // Chỉ bảng v26 mà tệp này muốn thấy còn nguyên; chuỗi migration từ 26 chỉ chạy đúng bước v27.
          database.execute('''
            CREATE TABLE app_notification_events (
              id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, dedupe_key TEXT NOT NULL,
              su_kien TEXT NOT NULL, luc INTEGER NOT NULL, os_id INTEGER NULL
            )
          ''');
          database.execute('''
            INSERT INTO app_notification_events VALUES
              ('e-7', 7, 'billDue:b1:2026-10-06:1', 'dat_lich', 1791219600, 1102803428)
          ''');
          // Bước v28 (G63) thêm một cột vào `wallets` — CSDL thật luôn có bảng ấy
          // (từ v1), nên fixture tối thiểu cũng phải có.
          database.execute('CREATE TABLE wallets (id TEXT NOT NULL PRIMARY KEY)');
          database.execute('PRAGMA user_version = 26');
        },
      ));
    });
    tearDown(() => cu.close());

    test('tạo bảng goi_y_hoa_don_phan_hois, hàng v26 còn nguyên', () async {
      await cu.goiYHoaDonDao.ghi(_ph(id: 'moi'));
      expect(await cu.goiYHoaDonDao.getAll(7), hasLength(1));
      expect(await cu.notificationEventDao.getAll(7), hasLength(1),
          reason: 'migration v27 chỉ TẠO bảng mới — không được đụng nhật ký thông báo của B5a');
    });
  });
}
