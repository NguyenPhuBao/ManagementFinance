/// Schema v26 (B5a): bảng `app_notification_events` — nhật ký phản ứng với thông
/// báo, CỤC BỘ, chỉ thêm hàng. Spec 2026-09-28-b5a-nhat-ky-thong-bao-design.md.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotificationEventsCompanion _sk({
  required String id,
  int idaccount = 7,
  String dedupeKey = 'billDue:b1:2026-10-01:1',
  String suKien = 'cham_hdh',
  DateTime? luc,
  int? osId,
}) =>
    AppNotificationEventsCompanion.insert(
      id: id,
      idaccount: idaccount,
      dedupeKey: dedupeKey,
      suKien: suKien,
      luc: luc ?? DateTime(2026, 9, 28, 8),
      osId: Value(osId),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema là v26', () => expect(db.schemaVersion, 26));

  test('bảng app_notification_events có đủ cột và KHÔNG có cột đồng bộ', () async {
    final cols = await db.customSelect("PRAGMA table_info('app_notification_events')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, containsAll(['id', 'idaccount', 'dedupe_key', 'su_kien', 'luc', 'os_id']));
    expect(ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}), isEmpty,
        reason: 'bảng cục bộ — vắng cột đồng bộ chính là tài liệu sống (quy tắc 9)');
  });

  test('ghi và đọc theo tài khoản, xếp theo lúc', () async {
    final dao = db.notificationEventDao;
    await dao.ghi(_sk(id: 'b', luc: DateTime(2026, 9, 28, 9)));
    await dao.ghi(_sk(id: 'a', luc: DateTime(2026, 9, 28, 8)));
    await dao.ghi(_sk(id: 'c', idaccount: 8));
    final cua7 = await dao.getAll(7);
    expect(cua7.map((e) => e.id), ['a', 'b']);
    expect(await dao.getAll(8), hasLength(1));
  });

  test('datLichGanNhat trả dat_lich MỚI NHẤT của đúng osId, bỏ sự kiện khác', () async {
    final dao = db.notificationEventDao;
    await dao.ghiNhieu([
      _sk(id: '1', suKien: 'dat_lich', osId: 42, luc: DateTime(2026, 10, 1, 8)),
      _sk(id: '2', suKien: 'dat_lich', osId: 42, luc: DateTime(2026, 10, 5, 8)),
      _sk(id: '3', suKien: 'cham_hdh', osId: 42, luc: DateTime(2026, 10, 9)),
      _sk(id: '4', suKien: 'dat_lich', osId: 43, luc: DateTime(2026, 10, 9)),
    ]);
    final r = await dao.datLichGanNhat(7, 42);
    expect(r?.id, '2');
    expect(await dao.datLichGanNhat(8, 42), isNull, reason: 'khác tài khoản');
  });

  test('datLichSau chỉ trả dat_lich có mốc SAU mốc cho trước', () async {
    final dao = db.notificationEventDao;
    await dao.ghiNhieu([
      _sk(id: 'qua', suKien: 'dat_lich', osId: 1, luc: DateTime(2026, 9, 27)),
      _sk(id: 'toi', suKien: 'dat_lich', osId: 2, luc: DateTime(2026, 9, 30)),
      _sk(id: 'khac', suKien: 'hoan', luc: DateTime(2026, 9, 30)),
    ]);
    final r = await dao.datLichSau(7, DateTime(2026, 9, 28));
    expect(r.map((e) => e.id), ['toi']);
  });

  test('coDatLich theo dedupeKey và tài khoản', () async {
    final dao = db.notificationEventDao;
    await dao.ghi(_sk(id: '1', suKien: 'dat_lich', osId: 1));
    expect(await dao.coDatLich(7, 'billDue:b1:2026-10-01:1'), isTrue);
    expect(await dao.coDatLich(8, 'billDue:b1:2026-10-01:1'), isFalse);
    expect(await dao.coDatLich(7, 'khac'), isFalse);
  });

  test('purgeOlderThan xoá hàng cũ hơn mốc, giữ hàng đúng mốc trở đi', () async {
    final dao = db.notificationEventDao;
    final moc = DateTime(2026, 3, 1);
    await dao.ghiNhieu([
      _sk(id: 'cu', luc: moc.subtract(const Duration(seconds: 1))),
      _sk(id: 'dung', luc: moc),
    ]);
    expect(await dao.purgeOlderThan(moc), 1);
    expect((await dao.getAll(7)).map((e) => e.id), ['dung']);
  });

  test('purgeDataForOtherAccounts xoá nhật ký của tài khoản khác, giữ của mình', () async {
    final dao = db.notificationEventDao;
    await dao.ghi(_sk(id: 'cua-7'));
    await dao.ghi(_sk(id: 'cua-8', idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect(await dao.getAll(8), isEmpty);
    expect(await dao.getAll(7), hasLength(1));
  });

  test('purgeDataForAccount xoá nhật ký của chính tài khoản ấy', () async {
    final dao = db.notificationEventDao;
    await dao.ghi(_sk(id: 'cua-7'));
    await dao.ghi(_sk(id: 'cua-8', idaccount: 8));
    await db.purgeDataForAccount(7);
    expect(await dao.getAll(7), isEmpty);
    expect(await dao.getAll(8), hasLength(1));
  });

  group('migration v25 → v26', () {
    late AppDatabase cu;
    setUp(() {
      cu = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          // Chỉ bảng v25 mà tệp này muốn thấy còn nguyên; chuỗi migration từ 25 chỉ chạy đúng bước v26.
          database.execute('''
            CREATE TABLE goi_y_danh_muc_phan_hois (
              id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, created_at INTEGER NOT NULL,
              nguon TEXT NOT NULL, am_tiet_chinh TEXT NOT NULL, goi_y_category_id TEXT NOT NULL,
              ket_qua TEXT NOT NULL, chon_category_id TEXT NULL
            )
          ''');
          database.execute('''
            INSERT INTO goi_y_danh_muc_phan_hois VALUES
              ('p-7', 7, 1790656434, 'hoc', 'grab', 'move', 'bo_qua', NULL)
          ''');
          database.execute('PRAGMA user_version = 25');
        },
      ));
    });
    tearDown(() => cu.close());

    test('tạo bảng app_notification_events, hàng v25 còn nguyên', () async {
      await cu.notificationEventDao.ghi(_sk(id: 'moi'));
      expect(await cu.notificationEventDao.getAll(7), hasLength(1));
      expect(await cu.goiYPhanHoiDao.getAll(7), hasLength(1),
          reason: 'migration v26 chỉ TẠO bảng mới — không được đụng phản hồi gợi ý danh mục của B1');
    });
  });
}
