/// Tool `danh_sach_hoa_don`: hàng theo TÊN kèm trạng thái của `billDisplayStatusOf`,
/// tổng hợp từ `summarizeBills` — CÙNG bộ lọc kỳ, để hàng và tổng nói về một
/// tập hoá đơn (bẫy của gói hoá đơn 1.3).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_hoa_don.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/bill/domain/bill_status.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
  bool isPaid = false,
  String payStatus = 'Pending',
  String ten = 'Tiền điện',
  bool tuTra = false,
  bool lap = true,
  String chuKy = kBillCycleMonth,
  String? sinhTu,
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: ten,
      amount: amount,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: tuTra,
      timeNotification: '3',
      isRecurrence: lap,
      timeRecurrence: chuKy,
      generatedFromBillId: sinhTu,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 9, 6, 10, 30);
  final kiem = _bill(id: 'k', ten: 'Kiem', amount: 45000, dueDate: DateTime(2026, 9, 1));
  final dien = _bill(id: 'd', ten: 'Tiền điện', amount: 110000, dueDate: DateTime(2026, 9, 20));
  final daTra = _bill(
      id: 'p',
      ten: 'Internet',
      amount: 200000,
      dueDate: DateTime(2026, 9, 3),
      isPaid: true,
      payStatus: 'Payed');
  final kySau = _bill(id: 's', ten: 'Nước', amount: 70000, dueDate: DateTime(2026, 10, 5));

  test('⭐ qua_han: chỉ hàng quá hạn — TÊN + trạng thái + số tiền, cờ cảnh báo', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now, trangThai: 'qua_han');
    expect(kq.hang.length, 1);
    final h = kq.hang.single;
    expect(h.ten, 'Kiem');
    expect(h.trangThai, 'đã quá hạn');
    expect(h.canhBao, isTrue);
    expect(h.soLieu.map((s) => s.nhan).toList(), ['Số tiền', 'Đến hạn']);
    expect(h.soLieu.first.chuoi, '45.000 đ');
    for (final s in h.soLieu) {
      expect(s.ten, 'Kiem',
          reason: 'kiemNhan đòi câu nêu tên: mọi SoLieu của hàng phải mang tên hàng');
    }
    expect(h.json, {
      'ten': 'Kiem',
      'trang_thai': 'đã quá hạn',
      'Số tiền': '45.000 đ',
      'Đến hạn': '01/09',
    });
  });

  test('⭐ hàng mang NGÀY ĐẾN HẠN dd/MM (lần đo 15 câu E8: "Netflix khi nào đến hạn?" '
      'chỉ được "sắp đến hạn" vì hàng không có ngày)', () {
    final kq = hangHoaDon([dien, kiem], now: now);
    final tienDien = kq.hang.firstWhere((h) => h.ten == 'Tiền điện');
    final denHan = tienDien.soLieu.firstWhere((s) => s.nhan == 'Đến hạn');
    expect(denHan.chuoi, '20/09');
    expect(denHan.loai, LoaiSo.ngayThang,
        reason: 'kiemSo bóc ngày/tháng từ soTho của loại này — câu "đến hạn 20/09" '
            'phải qua được lớp chắn');
    expect(denHan.ten, 'Tiền điện');
  });

  test('tổng hợp khớp summarizeBills: Còn phải trả, Quá hạn, Chưa trả', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now);
    final tom = summarizeBills([dien, kiem, daTra], now);
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(), [
      'Còn phải trả=155.000 đ',
      'Quá hạn=1',
      'Chưa trả=2',
      'Tự trả=0',
      'Cố định mỗi tháng=355.000 đ',
    ]);
    expect(kq.tongHop.first.soTho, tom.unpaidAmount);
  });

  test('mặc định chua_tra: quá hạn LẪN chưa trả, hạn sớm trước', () {
    final kq = hangHoaDon([dien, kiem], now: now);
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem', 'Tiền điện']);
    expect(kq.hang.map((h) => h.trangThai).toList(), ['đã quá hạn', 'chưa trả']);
    expect(kq.hang.map((h) => h.canhBao).toList(), [true, false]);
  });

  test('da_tra: chỉ hoá đơn đã trả', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now, trangThai: 'da_tra');
    expect(kq.hang.map((h) => h.ten).toList(), ['Internet']);
    expect(kq.hang.single.trangThai, 'đã trả');
  });

  test('kỳ SAU bị loại — cùng phép chặn cuối tháng với thẻ tổng', () {
    final kq = hangHoaDon([kiem, kySau], now: now, trangThai: 'tat_ca');
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem'],
        reason: 'Hàng liệt kê Nước trong khi tổng bên cạnh không tính Nước là '
            'hai vế của một câu đếm trên hai tập.');
    expect(kq.tongHop[2].chuoi, '1');
  });

  test('trần kToiDaMucMoiGoi hàng; số đếm vẫn đủ', () {
    final nhieu = [
      for (var i = 0; i < 6; i++)
        _bill(id: 'n$i', ten: 'HĐ $i', dueDate: DateTime(2026, 9, 10 + i)),
    ];
    final kq = hangHoaDon(nhieu, now: now);
    expect(kq.hang.length, 4);
    expect(kq.tongHop[2].chuoi, '6');
  });

  test('enum lạ → từ chối, không đoán', () {
    final kq = hangHoaDon([kiem], now: now, trangThai: 'sap_toi');
    expect(kq.hang, isEmpty);
    expect(kq.tongHop, isEmpty);
    expect(kq.loi, contains('sap_toi'));
    expect(kq.loi, contains('qua_han'), reason: 'nói mô hình còn được chọn gì');
    expect(kq.choNguoiDung, 'chưa hiểu trạng thái hoá đơn');
    expect(kq.thamSoGo, ['trang_thai']);
  });

  test('chuTrangThaiHoaDon phủ đủ năm trạng thái hiển thị', () {
    expect(chuTrangThaiHoaDon(BillDisplayStatus.overdue), 'đã quá hạn');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.dueSoon), 'sắp đến hạn');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.pending), 'chưa trả');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.paid), 'đã trả');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.skipped), 'bỏ qua');
  });
  group('ky — kỳ tới, mọi kỳ (spec mở rộng tool §5.1)', () {
    test('⭐ ky_toi: hàng THẬT của tháng tới + kỳ DỰ KIẾN chiếu từ hàng chưa trả cuối chuỗi', () {
      final kq = hangHoaDon([dien, kiem, daTra, kySau], now: now, ky: 'ky_toi');
      expect(kq.hang.map((h) => '${h.ten}|${h.trangThai}|${h.json['Đến hạn']}').toList(), [
        'Kiem|dự kiến|01/10',
        'Nước|chưa trả|05/10',
        'Tiền điện|dự kiến|20/10',
      ], reason: 'ngày dự kiến phải là đúng kyKeTiepCua — cùng luật payBill sinh hàng thật');
      expect(kq.hang.any((h) => h.canhBao), isFalse);
      expect(kq.json['Còn phải trả'], '225.000 đ');
      expect(kq.json['Chưa trả'], '3');
      expect(kq.json['Quá hạn'], '0');
      expect(kq.chuThem['ky'], 'kỳ tới');
      expect(kq.rongTheoBoLoc, isFalse);
    });

    test('⭐ hàng ĐÃ SINH kỳ sau thì không chiếu nữa — không đếm đôi', () {
      final a = _bill(id: 'a', ten: 'Net', dueDate: DateTime(2026, 9, 10));
      final b = _bill(id: 'b', ten: 'Net', dueDate: DateTime(2026, 10, 10), sinhTu: 'a');
      final kq = hangHoaDon([a, b], now: now, ky: 'ky_toi');
      expect(kq.hang, hasLength(1));
      expect(kq.hang.single.trangThai, 'chưa trả');
      expect(kq.json['Chưa trả'], '1');
    });

    test('ky_toi: hoá đơn KHÔNG lặp và hoá đơn đã trả không sinh kỳ dự kiến; kỳ này không lọt', () {
      final motLan = _bill(id: 'm', ten: 'Sửa xe', dueDate: DateTime(2026, 9, 12), lap: false);
      final kq = hangHoaDon([motLan, daTra], now: now, ky: 'ky_toi');
      expect(kq.hang, isEmpty);
      expect(kq.rongTheoBoLoc, isTrue);
      expect(kq.doiTuongRong, 'hoá đơn');
      // Bộ lọc mặc định chua_tra che mất hàng chiếu từ hoá đơn đã trả (bản sai 3
      // vẫn xanh) — phải hỏi MỌI trạng thái mới thấy.
      final moi = hangHoaDon([motLan, daTra], now: now, ky: 'ky_toi', trangThai: 'tat_ca');
      expect(moi.hang, isEmpty,
          reason: 'trả tiền là sinh luôn hàng kỳ sau; chiếu từ hàng đã trả là đếm đôi');
    });

    test('⭐ nợ cũ từ tháng 8: kỳ chiếu rơi vào THÁNG NÀY không phải kỳ tới — chỉ kỳ 01/10 được tính', () {
      final cu = _bill(id: 'c', ten: 'Nợ cũ', amount: 30000, dueDate: DateTime(2026, 8, 1));
      final kq = hangHoaDon([cu], now: now, ky: 'ky_toi');
      expect(kq.hang.map((h) => h.json['Đến hạn']).toList(), ['01/10'],
          reason: 'kỳ 01/09 cũng là kỳ chiếu nhưng thuộc tháng này');
      expect(kq.json['Còn phải trả'], '30.000 đ');
    });

    test('ky_toi qua biên năm: now tháng 12 → tháng 1 năm sau', () {
      final n = DateTime(2026, 12, 20);
      final b = _bill(id: 't', ten: 'Net', dueDate: DateTime(2026, 12, 31));
      final kq = hangHoaDon([b], now: n, ky: 'ky_toi');
      expect(kq.hang.single.json['Đến hạn'], '31/01/2027',
          reason: 'hạn sang NĂM KHÁC thì soNgayThang in kèm năm');
    });

    test('ky_toi, tháng 2 năm nhuận: hạn 31/01/2028 → dự kiến 29/02', () {
      final b = _bill(id: 't', ten: 'Net', dueDate: DateTime(2028, 1, 31));
      final kq = hangHoaDon([b], now: DateTime(2028, 1, 15), ky: 'ky_toi');
      expect(kq.hang.single.json['Đến hạn'], '29/02');
    });

    test('ky_toi, hoá đơn tuần: mọi kỳ dự kiến rơi trong tháng tới, trần 4 hàng, đếm đủ', () {
      final tuan = _bill(id: 'w', ten: 'Gửi xe', dueDate: DateTime(2026, 9, 28), chuKy: kBillCycleWeek);
      final kq = hangHoaDon([tuan], now: now, ky: 'ky_toi');
      expect(kq.hang.map((h) => h.json['Đến hạn']).toList(), ['05/10', '12/10', '19/10', '26/10']);
      expect(kq.json['Chưa trả'], '4');
    });

    test('tat_ca: mọi hoá đơn chưa đóng BẤT KỂ tháng — đúng tab Cần thanh toán; tổng trên cùng tập', () {
      final kq = hangHoaDon([dien, kiem, daTra, kySau], now: now, ky: 'tat_ca');
      expect(kq.hang.map((h) => h.ten).toList(), ['Kiem', 'Tiền điện', 'Nước']);
      expect(kq.json['Còn phải trả'], '225.000 đ');
      expect(kq.json['Chưa trả'], '3');
      expect(kq.json['Quá hạn'], '1');
      expect(kq.chuThem['ky'], 'mọi kỳ');
    });

    test('ky_nay (mặc định) không đổi: không chữ kỳ, không rongTheoBoLoc', () {
      final kq = hangHoaDon([kySau], now: now);
      expect(kq.hang, isEmpty);
      expect(kq.chuThem.containsKey('ky'), isFalse);
      expect(kq.rongTheoBoLoc, isFalse);
    });

    test('ky lạ → từ chối', () {
      final kq = hangHoaDon([kiem], now: now, ky: 'nam_sau');
      expect(kq.loi, contains('ky_toi'));
      expect(kq.thamSoGo, ['ky']);
    });
  });

  group('tự trả và cố định mỗi tháng', () {
    final net = _bill(id: 'n', ten: 'Netflix', amount: 260000, dueDate: DateTime(2026, 9, 28), tuTra: true);
    final netDaTra = _bill(
        id: 'n0', ten: 'Spotify', amount: 59000, dueDate: DateTime(2026, 9, 2),
        tuTra: true, isPaid: true, payStatus: 'Payed');
    final tuan = _bill(id: 'w', ten: 'Gửi xe', amount: 20000, dueDate: DateTime(2026, 9, 9), chuKy: kBillCycleWeek);
    final motLan = _bill(id: 'm', ten: 'Sửa xe', amount: 300000, dueDate: DateTime(2026, 9, 12), lap: false);
    final boQua = _bill(id: 's', ten: 'Gym', amount: 500000, dueDate: DateTime(2026, 9, 5), payStatus: 'Skipped');

    test('⭐ hậu tố " · tự trả" chỉ trên hàng CÒN PHẢI TRẢ có bật tự trả; đếm Tự trả cùng luật', () {
      final kq = hangHoaDon([net, netDaTra, kiem], now: now, trangThai: 'tat_ca');
      expect({for (final h in kq.hang) h.ten: h.trangThai}, {
        'Kiem': 'đã quá hạn',
        'Spotify': 'đã trả',
        'Netflix': 'chưa trả · tự trả',
      });
      expect(kq.json['Tự trả'], '1');
    });

    test('⭐ Cố định mỗi tháng = hoá đơn LẶP THÁNG của kỳ này, kể cả đã trả; bỏ tuần, một lần, bỏ qua', () {
      final kq = hangHoaDon([net, netDaTra, tuan, motLan, boQua, kySau], now: now);
      expect(kq.json['Cố định mỗi tháng'], '319.000 đ');
    });

    test('kỳ dự kiến của hoá đơn tự trả cũng mang hậu tố', () {
      final kq = hangHoaDon([net], now: now, ky: 'ky_toi');
      expect(kq.hang.single.trangThai, 'dự kiến · tự trả');
      expect(kq.json['Tự trả'], '1');
    });
  });

  group('mẫu câu tự qua năm lớp chắn', () {
    final net = _bill(id: 'n', ten: 'Netflix', amount: 260000, dueDate: DateTime(2026, 9, 28), tuTra: true);
    for (final ky in kKyHoaDon) {
      test('ky=$ky', () {
        final g = GoiSoTraCuu()
          ..them('danh_sach_hoa_don', hangHoaDon([dien, kiem, daTra, kySau, net], now: now, ky: ky));
        final cau = g.mauCau().cau;
        expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
      });
    }
    test('ky_toi rỗng: "Kỳ tới — không có hoá đơn nào khớp."', () {
      final g = GoiSoTraCuu()..them('danh_sach_hoa_don', hangHoaDon([daTra], now: now, ky: 'ky_toi'));
      expect(g.mauCau().cau, 'Kỳ tới — không có hoá đơn nào khớp.');
      expect(g.choHienChuMoHinh, isFalse);
    });
    test('câu tự nhiên của mô hình qua được: tháng tới, tự trả, cố định', () {
      final g = GoiSoTraCuu()
        ..them('danh_sach_hoa_don', hangHoaDon([dien, kiem, net], now: now, ky: 'ky_toi'));
      expect(kiemCauTraLoi('Tháng tới bạn dự kiến phải trả Netflix 260.000 đ, đến hạn 28/10.', [g]), isTrue);
      expect(kiemCauTraLoi('Có 1 hoá đơn tự trả là Netflix.', [g]), isTrue);
      expect(kiemCauTraLoi('Chi phí cố định mỗi tháng của bạn là 415.000 đ.', [g]), isTrue);
      expect(kiemCauTraLoi('Chi phí cố định mỗi tháng của bạn là 500.000 đ.', [g]), isFalse);
    });
  });

  group('G3 cổng F — hoá đơn nêu tên (E8) và hoá đơn tự trả (F12)', () {
    // Dữ liệu 28/09 của cổng F: Netflix tự trả đã trả sáng nay (kỳ 28/09) và đã
    // sinh kỳ sau; Kiem, di h0c quá hạn; Netflix tháng 8 đã trả từ lâu.
    final hom = DateTime(2026, 9, 28, 10);
    final netCu = _bill(id: 'n0', ten: 'Netflix', dueDate: DateTime(2026, 8, 28), tuTra: true,
        isPaid: true, payStatus: 'Payed');
    final netNay = _bill(id: 'n1', ten: 'Netflix', dueDate: DateTime(2026, 9, 28), tuTra: true,
        isPaid: true, payStatus: 'Payed', sinhTu: 'n0');
    final netSau = _bill(id: 'n2', ten: 'Netflix', dueDate: DateTime(2026, 10, 5), tuTra: true, sinhTu: 'n1');
    final kiemQh = _bill(id: 'k', ten: 'Kiem', amount: 45000, dueDate: DateTime(2026, 9, 18));
    final hoc = _bill(id: 'h', ten: 'di h0c', amount: 10000, dueDate: DateTime(2026, 9, 23));
    final tatCa = [netCu, netNay, netSau, kiemQh, hoc];

    test('⭐ E8: nêu tên → hàng của ĐÚNG hoá đơn ấy, mọi trạng thái, kỳ này + kỳ tới; tổng của riêng nó', () {
      final kq = hangHoaDon(tatCa, now: hom, ten: 'Netflix');
      expect(kq.hang.map((h) => h.ten).toSet(), {'Netflix'});
      expect(kq.hang.map((h) => h.json['Đến hạn']).toList(), ['28/09', '05/10'],
          reason: 'kỳ đã trả tháng 8 không phải câu trả lời "khi nào đến hạn"');
      expect(kq.hang.first.trangThai, 'đã trả');
      expect(kq.json['Quá hạn'], '0',
          reason: 'SAI E8: "Netflix có 2 hoá đơn đang quá hạn" — Quá hạn 2 là của Kiem và di h0c');
      expect(kq.json.containsKey('Cố định mỗi tháng'), isFalse, reason: 'số của mọi hoá đơn');
      final g = GoiSoTraCuu()..them('danh_sach_hoa_don', kq);
      expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
      expect(kiemCauTraLoi('Hoá đơn Netflix có 2 hoá đơn đang quá hạn.', [g]), isFalse);
      expect(kiemCauTraLoi('Hoá đơn Netflix kỳ tới đến hạn ngày 05/10.', [g]), isTrue);
    });

    test('E8: tên không có hàng nào mở hay gần → vẫn trả hàng MỚI NHẤT của nó, không "không có hoá đơn nào"', () {
      final kq = hangHoaDon([netCu, kiemQh], now: hom, ten: 'Netflix');
      expect(kq.hang.single.json['Đến hạn'], '28/08');
      expect(kq.rongTheoBoLoc, isFalse);
    });

    test('B1c không tụt: "hoá đơn di h0c còn phải trả bao nhiêu" — Còn phải trả CHỈ kỳ thật, không cộng kỳ dự kiến', () {
      final kq = hangHoaDon(tatCa, now: hom, ten: 'di h0c');
      expect(kq.hang.single.ten, 'di h0c');
      expect(kq.json['Còn phải trả'], '10.000 đ');
      expect(kq.json['Quá hạn'], '1');
    });

    test('⭐ F12: tuTra → chỉ hoá đơn tự trả còn phải trả; boLoc "tự trả"; tổng trên cùng tập', () {
      final kq = hangHoaDon(tatCa, now: hom, ky: 'tat_ca', tuTra: true);
      expect(kq.hang.map((h) => h.ten).toList(), ['Netflix']);
      expect(kq.hang.single.trangThai, endsWith('tự trả'));
      expect(kq.boLoc, ['tự trả']);
      expect(kq.json['Quá hạn'], '0');
      expect(kq.json.containsKey('Cố định mỗi tháng'), isFalse);
      final g = GoiSoTraCuu()..them('danh_sach_hoa_don', kq);
      expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
    });

    test('F12: không hoá đơn tự trả nào → rỗng theo bộ lọc, mẫu câu nói KHÔNG CÓ', () {
      final g = GoiSoTraCuu()
        ..them('danh_sach_hoa_don', hangHoaDon([kiemQh, hoc], now: hom, ky: 'tat_ca', tuTra: true));
      expect(g.mauCau().cau, 'Mọi kỳ, tự trả — không có hoá đơn nào khớp.');
    });
  });
}
