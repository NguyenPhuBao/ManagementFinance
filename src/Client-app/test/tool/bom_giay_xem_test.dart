/// Bơm 5 ngày giây xem vào bản CSDL chép từ máy — nghiệm thu dự án C việc ba
/// (thứ tự khối trang Phân tích). **KHÔNG phải test** — chạy tay, mặc định bỏ qua:
///
/// ```bash
/// FLOWMONEY_DB=/đường/flowmoney.db FLOWMONEY_IDACCOUNT=10 FLOWMONEY_CUM=co_cau \
///   flutter test test/tool/bom_giay_xem_test.dart --run-skipped
/// ```
///
/// Cụm [FLOWMONEY_CUM] được 30 giây/ngày, `dong_tien` + `tong` mỗi ngày 5 giây
/// (dưới `kGiayToiThieuNgay` nên không tranh), ngày 1..5 trước hôm nay — vừa đủ
/// `kNgayToiThieuDeXuat` để luật đề xuất lên tiếng.
///
/// ⚠️ Mở tệp `.db` bằng SQLite là **checkpoint và xoá `-wal`** — chép ra bản
/// sao rồi chạy trên bản sao, giữ bản gốc.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/data/thu_tu_khoi_nguon.dart';
import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bơm giây xem', () async {
    final duong = Platform.environment['FLOWMONEY_DB']!;
    final id = int.parse(Platform.environment['FLOWMONEY_IDACCOUNT']!);
    final cum = cumTuMa(Platform.environment['FLOWMONEY_CUM'] ?? 'co_cau')!;
    final db = AppDatabase.forTesting(NativeDatabase(File(duong)));
    final nguon = ThuTuKhoiNguonDrift(dao: db.thuTuKhoiDao);
    final now = DateTime.now();
    for (var d = 1; d <= 5; d++) {
      await nguon.congGiay(id, DateTime(now.year, now.month, now.day - d),
          {CumKhoi.dongTien: 5, CumKhoi.tong: 5, cum: 30});
    }
    final kq = await nguon.doc(id, now);
    // ignore: avoid_print
    print('ĐỀ XUẤT: ${kq.deXuat?.ma} · thứ tự: '
        '${kq.thuTu.map((c) => c.ma).join(",")}');
    await db.close();
  }, skip: 'công cụ chạy tay — xem docstring');
}
