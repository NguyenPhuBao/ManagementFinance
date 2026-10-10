/// Schema v30: bảng CỤC BỘ `khoa_tu_chuyen_tiens` — khoá thuê chặn hai lượt tự chuyển tiền chạy chồng (engine của app
/// + engine nền của WorkManager cùng tiến trình). Spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.4.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema là v30', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 30);
  });

  test('bảng KHÔNG có cột đồng bộ', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('khoa_tu_chuyen_tiens')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, {'ten', 'chu_so_huu', 'het_han_ms'}, reason: 'bảng cục bộ — quy tắc 9');
  });

  group('khoá thuê', () {
    late AppDatabase db;
    final t0 = DateTime(2026, 10, 10, 8);
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('lượt đầu lấy được, lượt hai bị từ chối khi khoá còn hạn', () async {
      expect(await db.khoaTuChuyenTienDao.lay('app', t0), isTrue);
      expect(await db.khoaTuChuyenTienDao.lay('nen', t0.add(const Duration(seconds: 30))), isFalse,
          reason: 'hai lượt cùng chạy bộ tự chuyển tiền là trừ tiền hai lần');
    });

    test('khoá hết hạn thì lượt khác lấy được (lượt trước chết giữa chừng)', () async {
      await db.khoaTuChuyenTienDao.lay('app', t0);
      expect(await db.khoaTuChuyenTienDao.lay('nen', t0.add(const Duration(minutes: 3))), isTrue);
    });

    test('nhả đúng chủ; chủ khác nhả không có tác dụng', () async {
      await db.khoaTuChuyenTienDao.lay('app', t0);
      await db.khoaTuChuyenTienDao.nha('nen');
      expect(await db.khoaTuChuyenTienDao.lay('nen', t0), isFalse);
      await db.khoaTuChuyenTienDao.nha('app');
      expect(await db.khoaTuChuyenTienDao.lay('nen', t0), isTrue);
    });
  });

  test('⭐ HAI KẾT NỐI THẬT tới cùng tệp: chỉ một bên lấy được', () async {
    final dir = await Directory.systemTemp.createTemp('khoa_');
    final tep = File('${dir.path}/k.db');
    final a = AppDatabase.forTesting(NativeDatabase(tep));
    await a.customSelect('SELECT 1').get(); // tạo + di trú bằng kết nối A trước
    final b = AppDatabase.forTesting(NativeDatabase(tep));
    addTearDown(() async {
      await a.close();
      await b.close();
      await dir.delete(recursive: true);
    });
    final t0 = DateTime(2026, 10, 10, 8);
    final kq = await Future.wait([
      a.khoaTuChuyenTienDao.lay('app', t0),
      b.khoaTuChuyenTienDao.lay('nen', t0),
    ]);
    expect(kq.where((x) => x), hasLength(1),
        reason: 'khoá tệp (fcntl) không chặn hai isolate cùng tiến trình — chốt phải nằm ở một câu UPDATE nguyên tử');
  });

  test('migration v29 → v30 chỉ TẠO bảng', () async {
    final cu = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) {
      d.execute('CREATE TABLE wallets (id TEXT NOT NULL PRIMARY KEY)');
      d.execute("INSERT INTO wallets VALUES ('w1')");
      d.execute('PRAGMA user_version = 29');
    }));
    addTearDown(cu.close);
    expect(await cu.khoaTuChuyenTienDao.lay('app', DateTime(2026, 10, 10)), isTrue);
    final w = await cu.customSelect('SELECT id FROM wallets').get();
    expect(w.single.read<String>('id'), 'w1');
  });

  test('kết nối native đặt busy_timeout (hai kết nối cùng sống — lần đầu của dự án)', () {
    final src = File('lib/core/database/connection/native.dart').readAsStringSync();
    expect(src, contains('PRAGMA busy_timeout = 5000'),
        reason: 'mặc định 0: UI ghi thông báo đúng lúc engine nền commit là SQLITE_BUSY ngay');
  });
}
