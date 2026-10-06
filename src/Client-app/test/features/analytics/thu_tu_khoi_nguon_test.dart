/// Nguồn thứ tự khối — ghép DAO với luật thuần; hỏng thì về mặc định.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/data/thu_tu_khoi_nguon.dart';
import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ThuTuKhoiNguonDrift nguon;
  var dem = 0;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nguon = ThuTuKhoiNguonDrift(dao: db.thuTuKhoiDao, taoId: () => 'id-${dem++}');
  });
  tearDown(() => db.close());

  final now = DateTime(2026, 10, 20, 9);

  test('đủ 5 ngày cụm Cơ cấu thắng → đề xuất Cơ cấu', () async {
    for (var d = 1; d <= 5; d++) {
      await nguon.congGiay(7, DateTime(2026, 10, 20 - d), {CumKhoi.dongTien: 5, CumKhoi.coCau: 30});
    }
    final kq = await nguon.doc(7, now);
    expect(kq.thuTu, kThuTuCumMacDinh);
    expect(kq.deXuat, CumKhoi.coCau);
  });

  test('đưa lên rồi đọc: thứ tự đổi, không còn đề xuất cụm ấy', () async {
    for (var d = 1; d <= 5; d++) {
      await nguon.congGiay(7, DateTime(2026, 10, 20 - d), {CumKhoi.dongTien: 5, CumKhoi.coCau: 30});
    }
    await nguon.ghiPhanHoi(7, kThuTuDuaLen, CumKhoi.coCau, now);
    final kq = await nguon.doc(7, now);
    expect(kq.thuTu.first, CumKhoi.coCau);
    expect(kq.deXuat, isNull);
  });

  test('mã cụm lạ trong CSDL bị bỏ qua, không ném', () async {
    await db.thuTuKhoiDao.congGiay(7, '2026-10-19', {'khoi_la': 50}, xoaTruoc: '2026-01-01');
    final kq = await nguon.doc(7, now);
    expect(kq.thuTu, kThuTuCumMacDinh);
  });

  test('⚠️ CSDL hỏng → mặc định + không đề xuất, không ném (phần phụ)', () async {
    await db.close();
    final kq = await nguon.doc(7, now);
    expect(kq.thuTu, kThuTuCumMacDinh);
    expect(kq.deXuat, isNull);
    await nguon.congGiay(7, now, {CumKhoi.tong: 1}); // không ném
    await nguon.ghiPhanHoi(7, kThuTuBoQua, CumKhoi.tong, now); // không ném
    db = AppDatabase.forTesting(NativeDatabase.memory()); // cho tearDown
  });
}
