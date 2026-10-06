/// Tool `danh_sach_muc_tieu` (bước 2): hàng theo TÊN, thứ tự trang Mục tiêu,
/// đủ số kèm NHỊP. Kỳ vọng tính bằng chính các hàm domain — tool chỉ chép.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_muc_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';
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

  group('chon theo trạng thái (E11 cổng E lần 1)', () {
    // MuaXe 1.101.000 / 2.000.000 → đúng kế hoạch; Cham 100.000 → chậm; Han hết hạn 20/09.
    final ba = [
      _mt(id: 'xe', ten: 'MuaXe'),
      _mt(id: 'cham', ten: 'Cham', current: 100000),
      _mt(id: 'han', ten: 'Han', den: DateTime(2026, 9, 20)),
    ];
    test('⭐ cham_ke_hoach → chỉ hàng chậm; Số mục tiêu khớp; boLoc; Đang theo đuổi vẫn đếm cả ba', () {
      expect(_mt(id: 'cham', current: 100000).isBehindSchedule(now), isTrue, reason: 'fixture phải chậm thật');
      final kq = hangMucTieu(ba, now: now, chon: 'cham_ke_hoach');
      expect(kq.hang.map((h) => h.ten).toList(), ['Cham']);
      expect(kq.hang.single.trangThai, 'chậm kế hoạch');
      expect(kq.json['Số mục tiêu khớp'], '1');
      expect(kq.json['Đang theo đuổi'], '3');
      expect(kq.boLoc, ['chậm kế hoạch']);
      expect(kq.rongTheoBoLoc, isFalse);
    });
    test('qua_han thắng chậm; dung_ke_hoach', () {
      expect(hangMucTieu(ba, now: now, chon: 'qua_han').hang.single.ten, 'Han');
      expect(hangMucTieu(ba, now: now, chon: 'dung_ke_hoach').hang.single.ten, 'MuaXe');
    });
    test('⭐ E11: cả hai đúng kế hoạch mà hỏi chậm → 0 hàng, rongTheoBoLoc, mẫu câu "không có mục tiêu nào khớp"', () {
      final kq = hangMucTieu([_mt(id: 'a', ten: 'MuaXe'), _mt(id: 'b', ten: 'MuaDT', current: 1900000)],
          now: now, chon: 'cham_ke_hoach');
      expect(kq.hang, isEmpty);
      expect(kq.rongTheoBoLoc, isTrue);
      expect(kq.doiTuongRong, 'mục tiêu');
      final cau = (GoiSoTraCuu()..them('danh_sach_muc_tieu', kq)).mauCau().cau;
      expect(cau, 'Chậm kế hoạch — không có mục tiêu nào khớp.',
          reason: 'cổng E lần 1: mô hình chỉ MuaXe dù không mục tiêu nào chậm; mẫu câu phải nói KHÔNG CÓ');
    });
    test('không chon → như cũ: không Số mục tiêu khớp, không boLoc; chon lạ → từ chối', () {
      final kq = hangMucTieu(ba, now: now);
      expect(kq.json.containsKey('Số mục tiêu khớp'), isFalse);
      expect(kq.boLoc, isEmpty);
      expect(hangMucTieu(ba, now: now, chon: 'x').loi, contains('cham_ke_hoach'));
    });
  });

  group('trích tự động — kỳ trích tiếp, trích mỗi kỳ, ví nguồn (lát 3 Task 10, spec §5.2)', () {
    // Nhịp ngày 15 hàng tháng 08:00, đã trích kỳ 15/09 → kỳ tiếp 15/10.
    GoalEntity tr({
      String id = 'g1',
      String ten = 'MuaXe',
      double current = 1101000,
      double amount = 50000,
      String nguon = 'w-tm',
      String viTichLuy = 'w-tk',
      DateTime? den,
    }) =>
        GoalEntity(
          id: id,
          idaccount: 10,
          name: ten,
          targetAmount: 2000000,
          currentAmount: current,
          startDate: DateTime(2026, 9, 5),
          targetDate: den ?? DateTime(2027, 3, 1),
          walletId: viTichLuy,
          timeCycleTakeMoney: DateTime(2026, 9, 15, 8),
          autoDepositAmount: amount,
          autoDepositWalletId: nguon,
          autoDepositLastRun: DateTime(2026, 9, 15, 8),
          updatedAt: DateTime(2026, 9, 5),
        );
    ViNguon vi(double soDu, {String ten = 'Tiền mặt', bool hoatDong = true}) =>
        (ten: ten, soDu: soDu, trangThai: hoatDong ? 'active' : 'inactive');

    test('⭐ ví đủ: Kỳ trích tiếp = kyKeTiep, Trích mỗi tháng, hậu tố "trích từ ví …", kết luận đủ', () {
      final g = tr();
      final kq = hangMucTieu([g], now: now, viNguon: {'w-tm': vi(500000)});
      final h = kq.hang.single;
      expect(_so(h)['Kỳ trích tiếp'], '15/10');
      final ky = kyKeTiep(
          mocNeo: g.timeCycleTakeMoney, lanChayGanNhat: g.autoDepositLastRun, chuKy: g.cycleTakeMoney, now: now)!;
      expect((ky.day, ky.month), (15, 10), reason: 'kỳ vọng phải là đúng hàm domain của bộ trích');
      expect(_so(h)['Trích mỗi tháng'], '50.000 đ');
      expect(_so(h).containsKey('Số dư ví nguồn'), isFalse);
      expect(h.trangThai, endsWith(' · trích từ ví Tiền mặt'));
      expect(h.canhBao, isFalse);
      expect(kq.json['Không đủ tiền trích'], '0');
      expect(kq.chuThem['ket_qua'], 'ví nguồn đủ tiền cho kỳ trích tới');
      expect(kq.tenLienQuan, contains('Tiền mặt'),
          reason: 'mô hình được phép nêu tên ví nguồn — kiemTen phải biết tên ấy');
    });

    test('⭐ ví KHÔNG đủ: hậu tố, cảnh báo, Số dư ví nguồn, đếm, kết luận thiếu', () {
      final kq = hangMucTieu([tr()], now: now, viNguon: {'w-tm': vi(20000)});
      final h = kq.hang.single;
      expect(h.trangThai, 'đúng kế hoạch · ví Tiền mặt không đủ để trích');
      expect(h.canhBao, isTrue);
      expect(_so(h)['Số dư ví nguồn'], '20.000 đ');
      expect(_so(h)['Kỳ trích tiếp'], '15/10');
      expect(kq.json['Không đủ tiền trích'], '1');
      expect(kq.chuThem['ket_qua'], 'có ví nguồn không đủ tiền để trích');
    });

    test('⭐ đủ theo quyetDinhTrich: còn thiếu 30.000 < số cài 50.000, ví 40.000 → trích phần còn lại, ĐỦ', () {
      final kq = hangMucTieu([tr(current: 1970000)], now: now, viNguon: {'w-tm': vi(40000)});
      expect(kq.hang.single.trangThai, isNot(contains('không đủ')),
          reason: 'so số dư với số CÀI là sai — bộ trích kẹp ở phần còn thiếu');
      expect(kq.json['Không đủ tiền trích'], '0');
    });

    test('⭐ bộ trích KHÔNG chạy (ví nguồn đã xoá · lưu trữ · trùng ví tích luỹ) → nói thẳng, không hứa kỳ tiếp', () {
      for (final (nhan, g, bang) in [
        ('đã xoá', tr(), <String, ViNguon>{}),
        ('lưu trữ', tr(), {'w-tm': vi(500000, hoatDong: false)}),
        ('trùng ví tích luỹ', tr(viTichLuy: 'w-tm'), {'w-tm': vi(500000)}),
      ]) {
        final kq = hangMucTieu([g], now: now, viNguon: bang);
        final h = kq.hang.single;
        expect(h.trangThai, endsWith(' · trích tự động không chạy được'), reason: nhan);
        expect(h.canhBao, isTrue, reason: nhan);
        expect(_so(h).containsKey('Kỳ trích tiếp'), isFalse, reason: nhan);
        expect(kq.chuThem['ket_qua'], 'có trích tự động không chạy được', reason: nhan);
        expect(kq.json['Không đủ tiền trích'], '0', reason: nhan);
      }
    });

    test('không có thông tin ví (viNguon null) → không kết luận gì về ví, vẫn có lịch trích', () {
      final kq = hangMucTieu([tr()], now: now);
      final h = kq.hang.single;
      expect(h.trangThai, 'đúng kế hoạch');
      expect(_so(h)['Kỳ trích tiếp'], '15/10');
      expect(kq.json.containsKey('Không đủ tiền trích'), isFalse);
      expect(kq.chuThem.containsKey('ket_qua'), isFalse);
    });

    test('mục tiêu KHÔNG bật trích tự động: không hai mục ấy, không đếm, không kết luận', () {
      final kq = hangMucTieu([_mt()], now: now, viNguon: {'w-tm': vi(500000)});
      expect(_so(kq.hang.single).keys, isNot(contains('Kỳ trích tiếp')));
      expect(_so(kq.hang.single).keys, isNot(contains('Trích mỗi tháng')));
      expect(kq.json.containsKey('Không đủ tiền trích'), isFalse);
      expect(kq.chuThem, isEmpty);
    });

    test('⭐ chon=vi_khong_du lọc theo CỜ, không theo mã trạng thái: mục tiêu chậm mà thiếu tiền vẫn khớp cả hai', () {
      final cham = tr(id: 'c', ten: 'Cham', current: 100000);
      expect(cham.isBehindSchedule(now), isTrue, reason: 'fixture phải chậm thật');
      final bang = {'w-tm': vi(20000), 'w-2': vi(900000, ten: 'Ngân hàng')};
      final ds = [cham, tr(id: 'x', ten: 'MuaXe', nguon: 'w-2')];
      final kq = hangMucTieu(ds, now: now, viNguon: bang, chon: 'vi_khong_du');
      expect(kq.hang.map((h) => h.ten).toList(), ['Cham']);
      expect(kq.hang.single.trangThai, 'chậm kế hoạch · ví Tiền mặt không đủ để trích');
      expect(kq.boLoc, ['ví không đủ để trích']);
      expect(kq.json['Số mục tiêu khớp'], '1');
      expect(hangMucTieu(ds, now: now, viNguon: bang, chon: 'cham_ke_hoach').hang.map((h) => h.ten), ['Cham']);
    });

    test('chon=vi_khong_du mà mọi ví đủ → rỗng theo bộ lọc, mẫu câu nói KHÔNG CÓ', () {
      final kq = hangMucTieu([tr()], now: now, viNguon: {'w-tm': vi(500000)}, chon: 'vi_khong_du');
      expect(kq.rongTheoBoLoc, isTrue);
      final cau = (GoiSoTraCuu()..them('danh_sach_muc_tieu', kq)).mauCau().cau;
      expect(cau, 'Ví không đủ để trích — không có mục tiêu nào khớp.');
    });

    test('chon theo trạng thái khác → không đếm, không kết luận trích (tiếng ồn)', () {
      final kq = hangMucTieu([tr()], now: now, viNguon: {'w-tm': vi(20000)}, chon: 'dung_ke_hoach');
      expect(kq.json.containsKey('Không đủ tiền trích'), isFalse);
      expect(kq.chuThem.containsKey('ket_qua'), isFalse);
    });

    test('⭐ G1 cổng F: noiTrich=false → KHÔNG một chữ trích nào (B1 "khi nào đạt" bị kéo sang ví nguồn)', () {
      final kq = hangMucTieu([tr()], now: now, viNguon: {'w-tm': vi(20000)}, noiTrich: false);
      final h = kq.hang.single;
      expect(h.trangThai, 'đúng kế hoạch', reason: 'không hậu tố ví');
      expect(h.canhBao, isFalse, reason: 'cảnh báo chỉ vì ví thiếu là chuyện trích');
      for (final nhan in ['Kỳ trích tiếp', 'Trích mỗi tháng', 'Số dư ví nguồn']) {
        expect(_so(h).containsKey(nhan), isFalse, reason: nhan);
      }
      expect(kq.json.containsKey('Không đủ tiền trích'), isFalse);
      expect(kq.chuThem, isEmpty, reason: 'ket_qua "có ví nguồn không đủ…" là câu DC1 lạc đề');
      expect(kq.tenLienQuan, isEmpty);
      expect(_so(h).containsKey('Theo nhịp hiện tại cần thêm'), isTrue,
          reason: 'số trả lời "khi nào đạt" vẫn còn');
    });

    test('⭐ G4 cổng F (F14): nêu tên mục tiêu → chỉ mục tiêu ấy; không bật trích → kết luận nói THẲNG', () {
      final muaDT = _mt(id: 'dt', ten: 'MuaDT', current: 500000);
      final kq = hangMucTieu([tr(), muaDT], now: now, viNguon: {'w-tm': vi(20000)}, ten: 'MuaDT');
      expect(kq.hang.map((h) => h.ten).toList(), ['MuaDT']);
      expect(kq.chuThem['ket_qua'], 'MuaDT không bật trích tự động');
      expect(kq.json.containsKey('Không đủ tiền trích'), isFalse,
          reason: 'đếm ví thiếu là của MuaXe — không thuộc câu hỏi về MuaDT');
      final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', kq);
      expect(kiemCauTraLoi('Kỳ trích tiếp theo cho mục tiêu MuaDT là ngày 15/10.', [g]), isFalse,
          reason: 'cổng F: mô hình viết đúng câu này với ngày trích của MuaXe — kiemSo từng chặn do may');
      expect(kiemCauTraLoi('Mục tiêu MuaDT không bật trích tự động.', [g]), isTrue);
      expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
      expect(g.mauCau().cau, contains('MuaDT không bật trích tự động'));
    });

    test('G4: nêu tên mục tiêu CÓ trích → hàng của nó kèm trích; câu không nói trích → không kết luận', () {
      final muaDT = _mt(id: 'dt', ten: 'MuaDT', current: 500000);
      final kq = hangMucTieu([tr(), muaDT], now: now, viNguon: {'w-tm': vi(20000)}, ten: 'MuaXe');
      expect(kq.hang.single.ten, 'MuaXe');
      expect(kq.chuThem['ket_qua'], 'có ví nguồn không đủ tiền để trích');
      final khongTrich = hangMucTieu([tr(), muaDT], now: now, ten: 'MuaDT', noiTrich: false);
      expect(khongTrich.hang.single.ten, 'MuaDT');
      expect(khongTrich.chuThem, isEmpty, reason: 'B1 "khi nào đạt MuaDT" — không nói trích');
    });

    test('⭐ mẫu câu tự qua sáu lớp chắn — đủ, thiếu, không chạy', () {
      for (final bang in [
        {'w-tm': vi(500000)},
        {'w-tm': vi(20000)},
        <String, ViNguon>{},
      ]) {
        final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', hangMucTieu([tr()], now: now, viNguon: bang));
        final cau = g.mauCau().cau;
        expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
      }
    });

    test('câu tự nhiên của mô hình: qua khi đúng, bị chặn khi sai ngày / sai số dư', () {
      final g = GoiSoTraCuu()
        ..them('danh_sach_muc_tieu', hangMucTieu([tr()], now: now, viNguon: {'w-tm': vi(20000)}));
      expect(kiemCauTraLoi('Kỳ trích tiếp theo của MuaXe là 15/10.', [g]), isTrue);
      expect(kiemCauTraLoi('Ví Tiền mặt không đủ tiền để trích cho MuaXe, ví nguồn chỉ còn 20.000 đ.', [g]), isTrue);
      expect(kiemCauTraLoi('Mỗi tháng MuaXe được trích 50.000 đ từ ví Tiền mặt.', [g]), isTrue);
      expect(kiemCauTraLoi('Có 1 mục tiêu mà ví nguồn không đủ tiền trích.', [g]), isTrue);
      expect(kiemCauTraLoi('Kỳ trích tiếp theo của MuaXe là 20/10.', [g]), isFalse);
      expect(kiemCauTraLoi('Ví nguồn của MuaXe chỉ còn 30.000 đ.', [g]), isFalse, reason: 'số dư bịa');
    });
  });

  group('H1 cổng F lần 2 — nhóm số theo câu hỏi, chỉ mẫu câu', () {
    final hai = [_mt(), _mt(id: 'g2', ten: 'MuaDT', target: 3000000, current: 500000)];

    test('⭐ B1 "khi nào đạt": chỉ Còn thiếu · Còn · cần thêm, và chiMauCau', () {
      final r = hangMucTieu(hai, now: now, noiTrich: false, ten: 'MuaXe', nhomSo: kNhomMucTieuKhiNao);
      expect(_so(r.hang.single).keys.toList(), ['Còn thiếu', 'Còn', 'Theo nhịp hiện tại cần thêm']);
      expect(r.chiMauCau, isTrue,
          reason: 'Realme 2026-09-28: mô hình có hàng đúng mà viết "Bạn có thể đặt mục tiêu MuaXe khi…" — '
              'không số nào sai nên sáu lớp chắn im');
      final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', r);
      final cau = g.mauCau().cau;
      expect(cau, contains('cần thêm'));
      expect(cau, isNot(contains('Tiến độ')));
      expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
    });

    test('⭐ B2 "mỗi tháng cần để dành": chỉ Còn thiếu · Cần tích · Đang tích', () {
      final r = hangMucTieu(hai, now: now, noiTrich: false, ten: 'MuaXe', nhomSo: kNhomMucTieuMoiKy);
      expect(_so(r.hang.single).keys.toList(),
          ['Còn thiếu', 'Cần tích mỗi tháng', 'Đang tích mỗi tháng']);
      expect(r.chiMauCau, isTrue);
      final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', r);
      expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
    });

    test('⭐ F14: hỏi trích của mục tiêu KHÔNG bật trích → chiMauCau, mẫu câu nói thẳng', () {
      final r = hangMucTieu(hai, now: now, viNguon: const {}, ten: 'MuaDT');
      expect(r.chuThem['ket_qua'], 'MuaDT không bật trích tự động');
      expect(r.chiMauCau, isTrue,
          reason: 'Realme 2026-09-28: mô hình bỏ qua ket_qua, đáp "cần thêm 115 ngày"');
      final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', r);
      expect(g.mauCau().cau, contains('MuaDT không bật trích tự động'));
      expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
    });

    test('⚠️ không nhóm, không hỏi trích → đủ số và chữ mô hình vẫn được hiện', () {
      final r = hangMucTieu(hai, now: now, noiTrich: false);
      expect(r.chiMauCau, isFalse);
      expect(_so(r.hang.first).containsKey('Tiến độ'), isTrue);
    });

    test('⭐ câu về MỘT mục tiêu (nêu tên, hoặc một số đích) → không đếm cả nhóm', () {
      // Cổng F lần 3 (Realme 2026-09-28): B1, B2, F14 đúng nhưng mẫu câu kết bằng
      // "Đang theo đuổi: 2; Đã hoàn thành: 0" — số của các mục tiêu KHÁC.
      for (final r in [
        hangMucTieu(hai, now: now, noiTrich: false, ten: 'MuaXe', nhomSo: kNhomMucTieuKhiNao),
        hangMucTieu(hai, now: now, noiTrich: false, ten: 'MuaXe', nhomSo: kNhomMucTieuMoiKy),
        hangMucTieu(hai, now: now, viNguon: const {}, ten: 'MuaDT'),
        hangMucTieu(hai, now: now, noiTrich: false, nhomSo: kNhomMucTieuKhiNao),
      ]) {
        expect(r.json.containsKey('Đang theo đuổi'), isFalse);
        expect(r.json.containsKey('Đã hoàn thành'), isFalse);
        final g = GoiSoTraCuu()..them('danh_sach_muc_tieu', r);
        expect(g.mauCau().cau, isNot(contains('theo đuổi')), reason: g.mauCau().cau);
        expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
      }
      final chung = hangMucTieu(hai, now: now, noiTrich: false);
      expect(chung.json['Đang theo đuổi'], '2', reason: 'câu về cả nhóm vẫn đếm');
    });
  });

  test('mẫu câu của gói tra cứu chứa hàng này tự qua kiemSo và kiemNhan', () {
    final goi = GoiSoTraCuu()..them('danh_sach_muc_tieu', hangMucTieu([_mt()], now: now));
    final cau = goi.mauCau().cau;
    expect(kiemSo(cau, goi), isTrue, reason: cau);
    expect(kiemNhan(cau, [goi]), isTrue, reason: cau);
  });
}
