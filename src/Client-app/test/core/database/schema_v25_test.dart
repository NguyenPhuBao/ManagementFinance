/// Schema v25 (B1, spec 2026-09-28): bảng `goi_y_danh_muc_phan_hois` — phản hồi thẻ gợi ý danh mục, CỤC BỘ,
/// không đi qua đồng bộ (test quét 15 canh).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

GoiYDanhMucPhanHoisCompanion _dong({required int idaccount, String id = 'p'}) =>
    GoiYDanhMucPhanHoisCompanion.insert(
      id: '$id-$idaccount',
      idaccount: idaccount,
      createdAt: DateTime(2026, 9, 29),
      nguon: 'hoc',
      amTietChinh: 'grab',
      goiYCategoryId: 'move',
      ketQua: 'bo_qua',
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema từ v25 trở lên', () => expect(db.schemaVersion, greaterThanOrEqualTo(25),
      reason: 'ca này canh BẢNG của v25, không canh số phiên bản — v26 (B5a) thêm bảng nhật ký thông báo'));

  test('bảng goi_y_danh_muc_phan_hois đủ tám cột và KHÔNG có cột đồng bộ', () async {
    final cols = await db.customSelect("PRAGMA table_info('goi_y_danh_muc_phan_hois')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, {
      'id',
      'idaccount',
      'created_at',
      'nguon',
      'am_tiet_chinh',
      'goi_y_category_id',
      'ket_qua',
      'chon_category_id',
    });
    expect(ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}), isEmpty,
        reason: 'bảng cục bộ — vắng cột đồng bộ chính là tài liệu sống (quy tắc 9)');
  });

  test('chon_category_id được phép NULL (bỏ qua mà không lưu giao dịch)', () async {
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 7));
    expect((await db.goiYPhanHoiDao.getAll(7)).single.chonCategoryId, isNull);
  });

  test('DAO ghi và đọc theo tài khoản', () async {
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 7));
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 7, id: 'q'));
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 8));
    expect(await db.goiYPhanHoiDao.getAll(7), hasLength(2));
    expect(await db.goiYPhanHoiDao.getAll(8), hasLength(1));
    expect(await db.goiYPhanHoiDao.getAll(9), isEmpty);
  });

  test('purgeDataForOtherAccounts xoá phản hồi của tài khoản khác, giữ của mình', () async {
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 7));
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect(await db.goiYPhanHoiDao.getAll(8), isEmpty);
    expect(await db.goiYPhanHoiDao.getAll(7), hasLength(1));
  });

  test('purgeDataForAccount xoá phản hồi của chính tài khoản ấy', () async {
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 7));
    await db.goiYPhanHoiDao.ghi(_dong(idaccount: 8));
    await db.purgeDataForAccount(7);
    expect(await db.goiYPhanHoiDao.getAll(7), isEmpty);
    expect(await db.goiYPhanHoiDao.getAll(8), hasLength(1));
  });

  group('migration v24 → v25', () {
    late AppDatabase cu;
    setUp(() {
      cu = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          // Chỉ bảng v24 mà tệp này muốn thấy còn nguyên; chuỗi migration từ 24 chỉ chạy đúng bước v25.
          database.execute('''
            CREATE TABLE ai_rebalancing_feedbacks (
              id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, created_at INTEGER NOT NULL,
              deficit_budget_id TEXT NOT NULL, donor_budget_id TEXT NOT NULL, donor_category_id TEXT NOT NULL,
              suggested_amount REAL NOT NULL, actual_amount REAL NOT NULL, action TEXT NOT NULL,
              period_from INTEGER NOT NULL, period_to INTEGER NOT NULL
            )
          ''');
          database.execute('''
            INSERT INTO ai_rebalancing_feedbacks VALUES
              ('f-7', 7, 1758240000, 'an', 'ms', 'c-ms', 500000, 500000, 'accepted', 1756684800, 1759276800)
          ''');
          database.execute('PRAGMA user_version = 24');
        },
      ));
    });
    tearDown(() => cu.close());

    test('tạo bảng goi_y_danh_muc_phan_hois, hàng v24 còn nguyên', () async {
      await cu.goiYPhanHoiDao.ghi(_dong(idaccount: 7));
      expect(await cu.goiYPhanHoiDao.getAll(7), hasLength(1));
      expect(await cu.aiFeedbackDao.getAll(7), hasLength(1),
          reason: 'migration v25 chỉ TẠO bảng mới — không được đụng dữ liệu phản hồi tái phân bổ');
    });
  });
}
