/// Tool `danh_sach_muc_tieu` (bước 2): hàng theo TÊN, thứ tự trang Mục tiêu,
/// đủ số kèm NHỊP. Kỳ vọng tính bằng chính các hàm domain — tool chỉ chép.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_muc_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

GoalEntity _mt({
  String id = 'g1',
  String ten = 'MuaXe',
  double target = 2000000,
  double current = 1101000,
  DateTime? start,
  DateTime? den,
  String? chuKy,
  bool xong = false,
  bool moc = true,
}) =>
    GoalEntity(
      id: id,
      idaccount: 10,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      startDate: moc ? (start ?? DateTime(2026, 9, 5)) : null,
      targetDate: den ?? DateTime(2027, 3, 1),
      cycleTakeMoney: chuKy,
      isCompleted: xong,
      updatedAt: DateTime(2026, 9, 5),
    );

Map<String, String> _so(HangSoLieu h) => {for (final s in h.soLieu) s.nhan: s.chuoi};

void main() {
  final now = DateTime(2026, 9, 23, 10);

  test('⭐ hàng có TÊN, trạng thái, đủ số; mọi số mang tên hàng', () {
    final g = _mt();
    final kq = hangMucTieu([g], now: now);
    final h = kq.hang.single;
    expect(h.ten, 'MuaXe');
    expect(h.trangThai, g.isBehindSchedule(now) ? 'chậm kế hoạch' : 'đúng kế hoạch');
    expect(_so(h).keys.toList(), [
      'Tiến độ', 'Đã tích', 'Mục tiêu', 'Còn thiếu', 'Còn',
      'Theo nhịp hiện tại cần thêm', 'Cần tích mỗi tháng', 'Đang tích mỗi tháng',
    ]);
    expect(_so(h)['Đã tích'], '1.101.000 đ');
    expect(_so(h)['Mục tiêu'], '2.000.000 đ');
    expect(_so(h)['Còn thiếu'], '899.000 đ');
    expect(_so(h)['Theo nhịp hiện tại cần thêm'],
        '${duBaoHoanThanh(g, now)!.difference(now).inDays} ngày');
    expect(h.soLieu.every((s) => s.ten == 'MuaXe'), isTrue,
        reason: 'kiemNhan đòi câu nêu tên mục tiêu');
  });

  test('KHÁC khối Nhận xét: mục tiêu ĐÚNG kế hoạch vẫn mang "cần thêm N ngày"', () {
    final g = _mt(current: 1900000); // tích nhanh → đúng kế hoạch
    expect(g.isBehindSchedule(now), isFalse);
    final h = hangMucTieu([g], now: now).hang.single;
    expect(h.trangThai, 'đúng kế hoạch');
    expect(h.canhBao, isFalse);
    expect(_so(h).containsKey('Theo nhịp hiện tại cần thêm'), isTrue,
        reason: 'tool trả lời câu hỏi THẲNG "bao giờ đạt" — GoiSoMucTieu mới giấu vế này');
  });

  test('quá hạn: trạng thái + cảnh báo, BỎ "Còn N ngày"', () {
    final h = hangMucTieu([_mt(den: DateTime(2026, 9, 20))], now: now).hang.single;
    expect(h.trangThai, 'đã quá hạn');
    expect(h.canhBao, isTrue);
    expect(_so(h).containsKey('Còn'), isFalse);
  });

  test('⭐ số null BỎ HẲN — không bịa 0 (mục tiêu cũ không có mốc gốc)', () {
    final h = hangMucTieu([_mt(moc: false)], now: now).hang.single;
    expect(_so(h).containsKey('Theo nhịp hiện tại cần thêm'), isFalse);
    expect(_so(h).containsKey('Đang tích mỗi tháng'), isFalse);
    expect(_so(h).values.any((v) => v == '0 ngày' || v == '0 đ'), isFalse);
  });

  test('đơn vị kỳ theo cycleTakeMoney', () {
    final h = hangMucTieu([_mt(chuKy: 'Week')], now: now).hang.single;
    expect(_so(h).containsKey('Cần tích mỗi tuần'), isTrue);
  });

  test('thứ tự chiaMucTieu, trần kToiDaMucMoiGoi, tổng hợp đếm cả hai nhóm', () {
    final goals = [
      for (var i = 0; i < 5; i++) _mt(id: 'g$i', ten: 'MT$i'),
      _mt(id: 'xong', ten: 'Xong', xong: true),
    ];
    final kq = hangMucTieu(goals, now: now);
    expect(kq.hang.length, 4);
    expect(kq.hang.any((h) => h.ten == 'Xong'), isFalse);
    expect({for (final s in kq.tongHop) s.nhan: s.chuoi},
        {'Đang theo đuổi': '5', 'Đã hoàn thành': '1'});
  });

  test('mẫu câu của gói tra cứu chứa hàng này tự qua kiemSo và kiemNhan', () {
    final goi = GoiSoTraCuu()..them('danh_sach_muc_tieu', hangMucTieu([_mt()], now: now));
    final cau = goi.mauCau().cau;
    expect(kiemSo(cau, goi), isTrue, reason: cau);
    expect(kiemNhan(cau, [goi]), isTrue, reason: cau);
  });
}
