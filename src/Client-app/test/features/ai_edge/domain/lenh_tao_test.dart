/// C3 — nhận lệnh "tạo hoá đơn / mục tiêu / ngân sách" ở màn Trợ lý AI (spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md` §2).
///
/// Canh chừng điều gì: lệnh chạy TRƯỚC vòng tool, nên nhận nhầm một câu hỏi
/// thành lệnh là câu hỏi ấy mất câu trả lời — không lỗi, không log. Lưới là 72
/// câu cổng F đã đo trên máy thật.
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/features/ai_edge/domain/lenh_tao.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dinh_tuyen_72_cau_test.dart' show kBang72Cau;

void main() {
  group('loaiLenhTao — nhận lệnh', () {
    const lenh = {
      'tạo hoá đơn Netflix 100k ngày 5 hằng tháng': LoaiLenhTao.hoaDon,
      'tao hoa don tien nha 3tr moi thang': LoaiLenhTao.hoaDon,
      'giúp tôi thêm hoá đơn điện 500k': LoaiLenhTao.hoaDon,
      'lập hóa đơn internet 250 nghìn hàng tháng ngày 10': LoaiLenhTao.hoaDon,
      'tạo mục tiêu mua xe 50 triệu trước tháng 6 năm sau': LoaiLenhTao.mucTieu,
      'them muc tieu du lich 10tr trong 12 thang': LoaiLenhTao.mucTieu,
      'đặt ngân sách ăn uống 3 triệu mỗi tháng': LoaiLenhTao.nganSach,
      'hãy đặt ngân sách giải trí 500k': LoaiLenhTao.nganSach,
      'cho tôi tạo ngân sách di chuyển 1tr': LoaiLenhTao.nganSach,
      'làm ơn thêm mục tiêu quỹ khẩn cấp 20 triệu': LoaiLenhTao.mucTieu,
      'Tạo một hoá đơn Netflix 100k': LoaiLenhTao.hoaDon,
      'làm ơn giúp mình tạo mới hoá đơn nước': LoaiLenhTao.hoaDon,
    };
    for (final e in lenh.entries) {
      test('"${e.key}" → ${e.value.name}', () => expect(loaiLenhTao(e.key), e.value));
    }

    const khongPhaiLenh = [
      'nên đặt ngân sách ăn uống bao nhiêu',
      'hoá đơn nào tự trả',
      'mục tiêu nào đang chậm kế hoạch',
      'tạo hoá đơn thế nào?',
      'tôi có nên tạo mục tiêu không',
      'ngân sách ăn uống còn bao nhiêu',
      'đặt ngân sách là gì',
      'thêm hoá đơn có tốn phí không',
      'tạo mục tiêu ở đâu',
      'ngan sach nao sap het',
      'làm sao tạo hoá đơn',
      'tạo giao dịch ăn phở 45k',
      'đặt lịch nhắc hoá đơn',
    ];
    for (final c in khongPhaiLenh) {
      test('câu hỏi "$c" → null', () => expect(loaiLenhTao(c), isNull));
    }

    test('⭐ 72 câu cổng F — không câu nào là lệnh', () {
      final nham = [
        for (final e in kBang72Cau.entries)
          if (loaiLenhTao(e.value.$1) != null) '${e.key}: ${e.value.$1}',
      ];
      expect(nham, isEmpty, reason: 'nhận nhầm câu hỏi thành lệnh là câu hỏi ấy mất câu trả lời');
    });
  });

  group('lenhTaoTheoCauHoi — đọc ô', () {
    final now = DateTime(2026, 9, 28);
    const vi = [(id: 'cash', ten: 'Tiền mặt'), (id: 'tcb', ten: 'Techcombank')];
    const dmChi = [(id: 'food', ten: 'Ăn uống'), (id: 'ent', ten: 'Giải trí'), (id: 'move', ten: 'Di chuyển')];
    LenhTao? doc(String c, {DateTime? luc}) => lenhTaoTheoCauHoi(c, now: luc ?? now, vi: vi, danhMucChi: dmChi);

    test('câu không phải lệnh → null', () => expect(doc('ngân sách nào sắp hết'), isNull));

    group('hoá đơn', () {
      test('⭐ "tạo hoá đơn Netflix 100k ngày 5 hằng tháng"', () {
        final l = doc('tạo hoá đơn Netflix 100k ngày 5 hằng tháng') as LenhTaoHoaDon;
        expect((l.ten, l.soTien, l.chuKy, l.ngayGoc, l.nhacTuTra), ('Netflix', 100000.0, kBillCycleMonth, 5, false));
        // Người dùng chốt 2026-10-01: ngày nêu trong câu là NGÀY BẮT ĐẦU hoá đơn — ngày 5 SẮP TỚI (28/9 → 05/10).
        expect(l.batDau, DateTime(2026, 10, 5));
        expect(l.query,
            {'name': 'Netflix', 'amount': '100000', 'cycle': kBillCycleMonth, 'anchor': '5', 'start': '2026-10-05'});
        expect(l.duongDan, '/bills/add?name=Netflix&amount=100000&cycle=Month&anchor=5&start=2026-10-05');
      });
      test('⭐ ngayBatDauHoaDon — ngày N sắp tới: chưa qua → tháng này; đã qua → tháng sau; trùng hôm nay → hôm nay', () {
        expect(ngayBatDauHoaDon(5, DateTime(2026, 10, 1, 14, 30)), DateTime(2026, 10, 5));
        expect(ngayBatDauHoaDon(5, DateTime(2026, 10, 5, 23, 59)), DateTime(2026, 10, 5), reason: 'trùng hôm nay');
        expect(ngayBatDauHoaDon(5, DateTime(2026, 10, 10)), DateTime(2026, 11, 5), reason: 'ngày 5 tháng này đã qua');
        expect(ngayBatDauHoaDon(5, DateTime(2026, 12, 20)), DateTime(2027, 1, 5), reason: 'sang năm');
        expect(ngayBatDauHoaDon(null, DateTime(2026, 10, 1)), isNull);
        expect(ngayBatDauHoaDon(0, DateTime(2026, 10, 1)), isNull);
        expect(ngayBatDauHoaDon(32, DateTime(2026, 10, 1)), isNull);
      });
      test('⚠️ ngayBatDauHoaDon — tháng NGẮN và năm NHUẬN: kẹp về ngày cuối tháng (ngày gốc vẫn là số người dùng nói)', () {
        expect(ngayBatDauHoaDon(31, DateTime(2026, 9, 10)), DateTime(2026, 9, 30), reason: 'tháng 9 có 30 ngày');
        expect(ngayBatDauHoaDon(31, DateTime(2026, 9, 30)), DateTime(2026, 9, 30), reason: 'ngày kẹp trùng hôm nay');
        expect(ngayBatDauHoaDon(30, DateTime(2027, 2, 10)), DateTime(2027, 2, 28));
        expect(ngayBatDauHoaDon(30, DateTime(2028, 2, 10)), DateTime(2028, 2, 29), reason: 'năm nhuận');
        expect(ngayBatDauHoaDon(31, DateTime(2027, 1, 31, 8)), DateTime(2027, 1, 31));
        expect(ngayBatDauHoaDon(29, DateTime(2027, 1, 30)), DateTime(2027, 2, 28),
            reason: 'ngày 29 tháng 1 đã qua → tháng 2 (28 ngày) → kẹp');
        final l = doc('tạo hoá đơn thuê nhà 5tr ngày 31', luc: DateTime(2026, 9, 10)) as LenhTaoHoaDon;
        expect((l.ngayGoc, l.batDau), (31, DateTime(2026, 9, 30)), reason: 'anchor giữ 31 — chuỗi kỳ sau vẫn neo ngày 31');
        expect((l.query['anchor'], l.query['start']), ('31', '2026-09-30'));
      });
      test('không nêu ngày → không batDau, không khoá start (form lấy hôm nay)', () {
        final l = doc('thêm hoá đơn điện 500k') as LenhTaoHoaDon;
        expect((l.ngayGoc, l.batDau), (null, null));
        expect(l.query.containsKey('start'), isFalse);
      });
      test('không dấu, "3tr", "moi thang"', () {
        final l = doc('tao hoa don tien nha 3tr moi thang') as LenhTaoHoaDon;
        expect((l.ten, l.soTien, l.chuKy), ('tien nha', 3000000.0, kBillCycleMonth));
      });
      test('hằng tuần / hằng quý / hằng năm; ngày 31; không nêu chu kỳ → tháng', () {
        expect((doc('tạo hoá đơn gym 200k hằng tuần') as LenhTaoHoaDon).chuKy, kBillCycleWeek);
        expect((doc('tạo hoá đơn bảo hiểm 2 triệu hằng quý') as LenhTaoHoaDon).chuKy, kBillCycleQuarter);
        expect((doc('tạo hoá đơn tên miền 300k hằng năm') as LenhTaoHoaDon).chuKy, kBillCycleYear);
        expect((doc('tạo hoá đơn thuê nhà 5tr ngày 31') as LenhTaoHoaDon).ngayGoc, 31);
        expect((doc('thêm hoá đơn điện 500k') as LenhTaoHoaDon).chuKy, kBillCycleMonth);
      });
      test('ví và danh mục nêu trong câu → id; không nêu → vắng khỏi query', () {
        final l = doc('tạo hoá đơn gym 300k danh mục giải trí ví techcombank') as LenhTaoHoaDon;
        expect((l.ten, l.idVi, l.idDanhMuc), ('gym', 'tcb', 'ent'));
        expect((doc('thêm hoá đơn điện 500k') as LenhTaoHoaDon).query.keys, isNot(contains('wallet')));
      });
      test('không đọc được số tiền → soTien null, không khoá amount', () {
        final l = doc('tạo hoá đơn Netflix') as LenhTaoHoaDon;
        expect((l.ten, l.soTien), ('Netflix', null));
        expect(l.query.containsKey('amount'), isFalse);
      });
      test('⚠️ tầng 4: "tự trả" → nhacTuTra, và query KHÔNG mang tham số tự trả', () {
        final l = doc('tạo hoá đơn Netflix 100k tự trả') as LenhTaoHoaDon;
        expect(l.nhacTuTra, isTrue);
        expect(l.ten, 'Netflix', reason: '"tự trả" không phải một phần của tên');
        expect(l.query.keys.where((k) => k.contains('auto') || k.contains('tu_tra')), isEmpty,
            reason: 'tầng 4 — AI không bật tự trả, kể cả qua deeplink');
        expect((doc('tạo hoá đơn điện tự động thanh toán') as LenhTaoHoaDon).nhacTuTra, isTrue);
      });
      test('query dùng đúng khoá của B2 (dienSanTuQuery) — có start khi câu nêu ngày', () {
        final l = doc('tạo hoá đơn gym 300k ngày 5 danh mục giải trí ví tiền mặt') as LenhTaoHoaDon;
        expect(l.query.keys.toSet(), {'name', 'amount', 'cycle', 'anchor', 'start', 'category', 'wallet'});
      });
    });

    group('mục tiêu', () {
      test('⭐ "trước tháng 6 năm sau" (28/9/2026) → 30/6/2027', () {
        final l = doc('tạo mục tiêu mua xe 50 triệu trước tháng 6 năm sau') as LenhTaoMucTieu;
        expect((l.ten, l.soTienDich, l.han), ('mua xe', 50000000.0, DateTime(2027, 6, 30)));
        expect(l.duongDan, '/goals/add?name=mua+xe&target=50000000&deadline=2027-06-30');
      });
      test('"đến tháng 2" khi tháng 2 năm nay đã qua → năm sau', () {
        expect((doc('tạo mục tiêu du lịch 10tr đến tháng 2') as LenhTaoMucTieu).han, DateTime(2027, 2, 28));
      });
      test('⚠️ tháng 2 năm NHUẬN: từ 28/9/2027 "đến tháng 2" → 29/2/2028', () {
        expect((doc('tạo mục tiêu du lịch 10tr đến tháng 2', luc: DateTime(2027, 9, 28)) as LenhTaoMucTieu).han,
            DateTime(2028, 2, 29));
      });
      test('"trong 12 tháng" từ 31/1/2027 → 31/1/2028; "trong 1 tháng" từ 31/1 → cuối tháng 2 (kẹp)', () {
        expect((doc('them muc tieu du lich 10tr trong 12 thang', luc: DateTime(2027, 1, 31)) as LenhTaoMucTieu).han,
            DateTime(2028, 1, 31));
        expect((doc('tạo mục tiêu quỹ 5tr trong 1 tháng', luc: DateTime(2027, 1, 31)) as LenhTaoMucTieu).han,
            DateTime(2027, 2, 28));
      });
      test('"đến 31/12/2027"', () {
        final l = doc('tạo mục tiêu mua nhà 500 triệu đến 31/12/2027') as LenhTaoMucTieu;
        expect((l.ten, l.han), ('mua nhà', DateTime(2027, 12, 31)));
      });
      test('không nêu hạn → han null, không khoá deadline', () {
        final l = doc('làm ơn thêm mục tiêu quỹ khẩn cấp 20 triệu') as LenhTaoMucTieu;
        expect((l.ten, l.soTienDich, l.han), ('quỹ khẩn cấp', 20000000.0, null));
        expect(l.query.containsKey('deadline'), isFalse);
      });
    });

    group('ngân sách', () {
      test('⭐ danh mục khớp → id; hạn mức; query category + amount (route không nhận chu kỳ)', () {
        final l = doc('đặt ngân sách ăn uống 3 triệu mỗi tháng') as LenhTaoNganSach;
        expect((l.idDanhMuc, l.hanMuc), ('food', 3000000.0));
        expect(l.duongDan, '/budget/rules?category=food&amount=3000000');
      });
      test('không dấu, tiền tố lịch sự', () {
        expect((doc('hãy đặt ngân sách giải trí 500k') as LenhTaoNganSach).idDanhMuc, 'ent');
        expect((doc('cho toi tao ngan sach di chuyen 1tr') as LenhTaoNganSach).idDanhMuc, 'move');
      });
      test('danh mục không khớp → idDanhMuc null (thẻ nói "Chưa rõ danh mục")', () {
        final l = doc('đặt ngân sách xyz 1tr') as LenhTaoNganSach;
        expect((l.idDanhMuc, l.hanMuc), (null, 1000000.0));
        expect(l.query, {'amount': '1000000'});
      });
    });
  });

  group('tomTatLenhTao — nội dung thẻ', () {
    test('⭐ hoá đơn đủ ô', () {
      final t = tomTatLenhTao(
          LenhTaoHoaDon(ten: 'Netflix', soTien: 100000, ngayGoc: 5, batDau: DateTime(2026, 10, 5)));
      // Record chứa List so theo danh tính — tách List ra so riêng.
      expect((t.hanhDong, t.ten, t.thieu, t.nhacTuTra, t.nut), ('Tạo hoá đơn', 'Netflix', '', false, 'Mở form tạo hoá đơn'));
      expect(t.chiTiet, ['100.000 đ', 'hằng tháng, bắt đầu 05/10/2026'],
          reason: 'thẻ nói đúng thứ form sẽ điền: NGÀY BẮT ĐẦU, không phải "ngày 5" trống nghĩa');
    });
    test('ô thiếu gom một dòng; tầng 4 có dòng riêng', () {
      final t = tomTatLenhTao(const LenhTaoHoaDon(chuKy: kBillCycleWeek, nhacTuTra: true));
      expect(t.chiTiet, ['hằng tuần']);
      expect(t.thieu, 'Chưa rõ tên, số tiền — bạn điền trong form');
      expect(t.nhacTuTra, isTrue);
    });
    test('mục tiêu: hạn dd/MM/yyyy; thiếu hạn', () {
      expect(tomTatLenhTao(LenhTaoMucTieu(ten: 'mua xe', soTienDich: 50000000, han: DateTime(2027, 6, 30))).chiTiet,
          ['50.000.000 đ', 'hạn 30/06/2027']);
      final t = tomTatLenhTao(const LenhTaoMucTieu(ten: 'quỹ', soTienDich: 20000000));
      expect((t.hanhDong, t.thieu, t.nut), ('Tạo mục tiêu', 'Chưa rõ hạn — bạn điền trong form', 'Mở form tạo mục tiêu'));
    });
    test('ngân sách: tên là danh mục; không khớp → "Chưa rõ danh mục"', () {
      final t = tomTatLenhTao(const LenhTaoNganSach(idDanhMuc: 'food', tenDanhMuc: 'Ăn uống', hanMuc: 3000000));
      expect((t.hanhDong, t.ten, t.nut), ('Đặt ngân sách', 'Ăn uống', 'Mở form đặt ngân sách'));
      expect(t.chiTiet, ['3.000.000 đ']);
      expect(tomTatLenhTao(const LenhTaoNganSach(hanMuc: 1000000)).thieu, 'Chưa rõ danh mục — bạn điền trong form');
    });
  });

  group('coVeLenhTao — cổng rộng (§8.1)', () {
    final now = DateTime(2026, 9, 30);
    const lot = [
      'tôi muốn để dành 50 triệu mua xe trước hè năm sau',
      'mỗi tháng trả tiền nhà 3 triệu vào mùng 5',
      'để dành 20 triệu làm quỹ khẩn cấp',
      'tiết kiệm 2 triệu mỗi tháng cho chuyến du lịch',
      'ăn uống tối đa 3 triệu một tháng',
      'nhắc tôi đóng tiền điện hằng tháng',
      'lên kế hoạch dành dụm mua laptop 30 triệu',
      'hoá đơn internet 250k mỗi tháng ngày 10',
      'toi muon tiet kiem 10 trieu trong 6 thang',
      'tạo hoá đơn Netflix 100k', // câu theo mẫu §2 cũng lọt
    ];
    for (final c in lot) {
      test('lọt: "$c"', () => expect(coVeLenhTao(c, now: now), isTrue));
    }

    const khongLot = [
      'để dành mỗi tháng 2 triệu thì đủ không', // từ hỏi
      'tiết kiệm được bao nhiêu rồi',
      'hoá đơn nào sắp đến hạn',
      'mục tiêu mua xe còn thiếu bao nhiêu',
      'ngân sách ăn uống là gì',
      'tôi muốn mua xe', // không đối tượng tạo được
      'tháng này chi 3 triệu', // số tiền nhưng không đối tượng tạo được
      'hôm qua ăn phở 45k', // giao dịch — không phải lệnh tạo
      'đặt lịch nhắc hoá đơn?', // dấu hỏi
    ];
    for (final c in khongLot) {
      test('không lọt: "$c"', () => expect(coVeLenhTao(c, now: now), isFalse));
    }

    test('⭐ 72 câu cổng F — không câu nào lọt cổng', () {
      final nham = [
        for (final e in kBang72Cau.entries)
          if (coVeLenhTao(e.value.$1, now: now)) '${e.key}: ${e.value.$1}',
      ];
      expect(nham, isEmpty, reason: 'câu hỏi lọt cổng là mở phiên lệnh vô ích rồi mới về vòng hỏi đáp (thêm ~15 s)');
    });
  });

  group('KetQuaLenhAi.tuLoiGoi', () {
    test('tao_hoa_don: số dạng chuỗi, enum rỗng → null', () {
      final k = KetQuaLenhAi.tuLoiGoi(kTenCongCuTaoHoaDon,
          {'ten': 'gym', 'so_tien': '300000', 'chu_ky': 'thang', 'ngay_goc': 5, 'vi': '', 'danh_muc': 'Giải trí'})!;
      expect((k.loai, k.ten, k.soTien, k.chuKy, k.ngayGoc, k.vi, k.danhMuc),
          (LoaiLenhTao.hoaDon, 'gym', 300000.0, 'thang', 5, null, 'Giải trí'));
    });
    test('tao_muc_tieu / dat_ngan_sach: so_tien_dich / han_muc → soTien; 0 → null', () {
      expect(
          KetQuaLenhAi.tuLoiGoi(kTenCongCuTaoMucTieu, {'ten': 'mua xe', 'so_tien_dich': 50000000, 'han': '30/06/2027'})!
              .soTien,
          50000000);
      final n = KetQuaLenhAi.tuLoiGoi(kTenCongCuDatNganSach, {'danh_muc': 'Ăn uống', 'han_muc': 0})!;
      expect((n.loai, n.danhMuc, n.soTien), (LoaiLenhTao.nganSach, 'Ăn uống', null));
    });
    test('tên tool lạ → null (mô hình bịa tool)', () {
      expect(KetQuaLenhAi.tuLoiGoi('bay_gio_may_gio', {}), isNull);
    });
  });

  group('lenhTaoTuAi — lưới kiểm (§8.3)', () {
    final now = DateTime(2026, 9, 30);
    const vi = [(id: 'cash', ten: 'Tiền mặt'), (id: 'tcb', ten: 'Techcombank')];
    const dmChi = [(id: 'food', ten: 'Ăn uống'), (id: 'ent', ten: 'Giải trí')];
    KetQuaLenhAi ai({
      LoaiLenhTao loai = LoaiLenhTao.mucTieu,
      String? ten,
      double? soTien,
      String? han,
      String? chuKy,
      int? ngayGoc,
      String? vi,
      String? danhMuc,
    }) =>
        KetQuaLenhAi(
            loai: loai, ten: ten, soTien: soTien, han: han, chuKy: chuKy, ngayGoc: ngayGoc, vi: vi, danhMuc: danhMuc);
    LenhTao doc(String c, KetQuaLenhAi a) => lenhTaoTuAi(c, a, now: now, vi: vi, danhMucChi: dmChi);

    test('⭐ câu tự nhiên: AI điền tên (đoạn con của câu), hạn (câu nói thời gian); số do luật đọc → nguon ai', () {
      final l = doc('tôi muốn để dành 50 triệu mua xe trước hè năm sau',
          ai(ten: 'mua xe', soTien: 50000000, han: '30/06/2027')) as LenhTaoMucTieu;
      expect((l.ten, l.soTienDich, l.han, l.nguon), ('mua xe', 50000000.0, DateTime(2027, 6, 30), NguonLenh.ai));
    });
    test('AI bịa số không có trong câu → bỏ', () {
      final l = doc('tôi muốn để dành tiền mua xe', ai(ten: 'mua xe', soTien: 30000000)) as LenhTaoMucTieu;
      expect(l.soTienDich, isNull, reason: 'con số không đọc ra được từ câu là con số mô hình tự nghĩ');
    });
    test('luật đọc được số thì luật thắng, kể cả khi AI khác', () {
      final l = doc('để dành 50 triệu mua xe', ai(ten: 'mua xe', soTien: 5000000)) as LenhTaoMucTieu;
      expect(l.soTienDich, 50000000);
    });
    test('tên: câu theo mẫu → tên luật thắng; câu tự nhiên → tên AI phải là đoạn con của câu', () {
      expect((doc('tạo mục tiêu mua xe 50 triệu', ai(ten: 'Mua xe hơi')) as LenhTaoMucTieu).ten, 'mua xe');
      expect((doc('để dành 50 triệu', ai(ten: 'xe')) as LenhTaoMucTieu).ten, isNull);
      expect((doc('để dành 50 triệu MUA XE', ai(ten: 'mua xe')) as LenhTaoMucTieu).ten, 'mua xe',
          reason: 'so không phân biệt hoa thường, không dấu');
      expect((doc('để dành 50 triệu mua xe', ai(ten: 'xe 50 triệu')) as LenhTaoMucTieu).ten, isNull,
          reason: 'tên không được chứa chữ số');
    });
    test('⚠️ AI đổi loại của câu theo mẫu → giữ loại luật', () {
      expect(doc('tạo hoá đơn gym 300k', ai(loai: LoaiLenhTao.mucTieu, ten: 'gym', soTien: 300000)),
          isA<LenhTaoHoaDon>());
    });
    test('hạn: câu không nói thời gian / quá khứ / quá 50 năm / ngày không có thật → bỏ; luật thắng', () {
      expect((doc('để dành 10 triệu mua xe', ai(ten: 'mua xe', han: '30/06/2027')) as LenhTaoMucTieu).han, isNull);
      expect((doc('mua xe trước tết', ai(ten: 'mua xe', han: '01/01/2020')) as LenhTaoMucTieu).han, isNull);
      expect((doc('mua xe trước tết', ai(ten: 'mua xe', han: '01/01/2090')) as LenhTaoMucTieu).han, isNull);
      expect((doc('mua xe trước tết', ai(ten: 'mua xe', han: '30/02/2027')) as LenhTaoMucTieu).han, isNull);
      expect((doc('mua xe trước tết', ai(ten: 'mua xe', han: '10/02/2027')) as LenhTaoMucTieu).han,
          DateTime(2027, 2, 10));
      expect((doc('tạo mục tiêu mua xe trước tháng 6 năm sau', ai(han: '15/06/2027')) as LenhTaoMucTieu).han,
          DateTime(2027, 6, 30));
    });
    test('⚠️ hạn: "tôi" không phải "tới", "cưới" không phải "cuối" — câu có dấu thì so chữ CÓ DẤU', () {
      expect((doc('tôi muốn để dành 10 triệu mua xe', ai(ten: 'mua xe', han: '30/06/2027')) as LenhTaoMucTieu).han,
          isNull, reason: 'bỏ dấu thì "tôi" = "toi" = "tới" — mọi câu có chủ ngữ thành câu nói thời gian');
      expect((doc('để dành 100 triệu cho đám cưới', ai(ten: 'đám cưới', han: '30/06/2027')) as LenhTaoMucTieu).han,
          isNull);
      expect((doc('toi muon de danh 10 trieu mua xe', ai(ten: 'mua xe', han: '30/06/2027')) as LenhTaoMucTieu).han,
          isNull, reason: 'gõ không dấu: "toi" không nằm trong danh sách');
      expect((doc('de danh 10 trieu mua xe truoc tet', ai(ten: 'mua xe', han: '10/02/2027')) as LenhTaoMucTieu).han,
          DateTime(2027, 2, 10), reason: 'gõ không dấu vẫn nhận chữ thời gian');
    });
    test('⭐ hoá đơn tự nhiên: tên từ AI; chu kỳ / ngày gốc luật đọc được thì luật thắng', () {
      final l = doc('mỗi tháng trả tiền nhà 3 triệu vào mùng 5',
          ai(loai: LoaiLenhTao.hoaDon, ten: 'tiền nhà', soTien: 3000000, chuKy: 'thang', ngayGoc: 5)) as LenhTaoHoaDon;
      expect((l.ten, l.soTien, l.chuKy, l.ngayGoc, l.nguon), ('tiền nhà', 3000000.0, kBillCycleMonth, 5, NguonLenh.ai));
      expect(
          (doc('trả tiền nhà 3 triệu hằng tháng', ai(loai: LoaiLenhTao.hoaDon, chuKy: 'tuan')) as LenhTaoHoaDon).chuKy,
          kBillCycleMonth,
          reason: 'luật đọc được chu kỳ thì luật thắng');
      expect((doc('trả tiền nhà 3 triệu', ai(loai: LoaiLenhTao.hoaDon, chuKy: 'quy')) as LenhTaoHoaDon).chuKy,
          kBillCycleQuarter);
    });
    test('ngày gốc của AI: chữ số ấy phải có trong câu, NGOÀI đoạn số tiền', () {
      expect(
          (doc('trả tiền nhà 3 triệu hằng tháng', ai(loai: LoaiLenhTao.hoaDon, ngayGoc: 5)) as LenhTaoHoaDon).ngayGoc,
          isNull);
      expect((doc('trả tiền nhà 5 triệu hằng tháng', ai(loai: LoaiLenhTao.hoaDon, ngayGoc: 5)) as LenhTaoHoaDon).ngayGoc,
          isNull, reason: 'số 5 của "5 triệu" là tiền, không phải ngày');
      final coNgay =
          doc('trả tiền nhà 3 triệu hằng tháng vào hôm 5', ai(loai: LoaiLenhTao.hoaDon, ngayGoc: 5)) as LenhTaoHoaDon;
      expect((coNgay.ngayGoc, coNgay.batDau), (5, DateTime(2026, 10, 5)),
          reason: 'ngày do AI đọc cũng là NGÀY BẮT ĐẦU — không thì thẻ ghi "ngày 5" còn form bắt đầu hôm nay');
      expect(
          (doc('trả tiền nhà 3 triệu hằng tháng vào hôm 5', ai(loai: LoaiLenhTao.hoaDon, ngayGoc: 45)) as LenhTaoHoaDon)
              .ngayGoc,
          isNull);
    });
    test('danh mục: tên luật trong câu thắng; không thì enum AI khớp đúng một mục', () {
      final l = doc('trả gym 300k mỗi tháng', ai(loai: LoaiLenhTao.hoaDon, ten: 'gym', danhMuc: 'Giải trí'))
          as LenhTaoHoaDon;
      expect((l.idDanhMuc, l.nguon), ('ent', NguonLenh.ai));
      expect((doc('trả gym 300k', ai(loai: LoaiLenhTao.hoaDon, danhMuc: 'Không có')) as LenhTaoHoaDon).idDanhMuc,
          isNull);
    });
    test('⚠️ chữ "hoá đơn" của LỆNH không phải danh mục "Hóa đơn" (Realme 2026-10-01: nó che mất "Giải trí" AI đoán)', () {
      const dm = [(id: 'bill', ten: 'Hóa đơn'), (id: 'ent', ten: 'Giải trí')];
      LenhTaoHoaDon luat(String c) => lenhTaoTheoCauHoi(c, now: now, vi: vi, danhMucChi: dm)! as LenhTaoHoaDon;
      expect(luat('tạo hoá đơn gym 300k ngày 5 hằng tháng').idDanhMuc, isNull,
          reason: 'bộ danh mục mặc định CÓ mục tên "Hóa đơn" — danh từ của lệnh trùng tên nó ở mọi câu');
      expect(luat('tao hoa don gym 300k').idDanhMuc, isNull);
      expect(luat('tạo hoá đơn điện 500k danh mục hoá đơn').idDanhMuc, 'bill',
          reason: 'người dùng NÊU danh mục ấy (lần xuất hiện thứ hai) thì vẫn nhận');
      final l = lenhTaoTuAi(
        'tạo hoá đơn gym 300k ngày 5 hằng tháng',
        ai(loai: LoaiLenhTao.hoaDon, ten: 'gym', soTien: 300000, danhMuc: 'Giải trí'),
        now: now,
        vi: vi,
        danhMucChi: dm,
      ) as LenhTaoHoaDon;
      expect((l.idDanhMuc, l.tenDanhMuc, l.nguon), ('ent', 'Giải trí', NguonLenh.ai));
      expect(tomTatLenhTao(l).chiTiet, ['300.000 đ', 'hằng tháng, bắt đầu 05/10/2026', 'danh mục Giải trí'],
          reason: 'danh mục mô hình ĐOÁN phải hiện trên thẻ — không thì "Đọc bằng AI" mà không thấy AI đã điền gì');
      final tuNhien = lenhTaoTuAi(
        'hoá đơn internet 250k mỗi tháng ngày 10',
        ai(loai: LoaiLenhTao.hoaDon, ten: 'internet', danhMuc: ''),
        now: now,
        vi: vi,
        danhMucChi: dm,
      ) as LenhTaoHoaDon;
      expect(tuNhien.idDanhMuc, isNull, reason: 'câu tự nhiên cũng thế: "hoá đơn" là đối tượng tạo, không phải danh mục');
    });

    test('⚠️ ví của AI chỉ nhận khi CÂU NHẮC VÍ — mô hình hay tự điền ví mặc định (C2 đo 9/10 câu)', () {
      expect(
          (doc('trả gym 300k mỗi tháng', ai(loai: LoaiLenhTao.hoaDon, ten: 'gym', vi: 'Techcombank')) as LenhTaoHoaDon)
              .idVi,
          isNull,
          reason: 'câu không nói tới ví nào — ví điền sẵn sai là ô người dùng dễ bỏ sót nhất');
      final coVi =
          doc('trả gym 300k mỗi tháng bằng techcom', ai(loai: LoaiLenhTao.hoaDon, vi: 'Techcombank')) as LenhTaoHoaDon;
      expect((coVi.idVi, coVi.tenVi), ('tcb', 'Techcombank'), reason: 'viết tắt tên ví');
      expect(tomTatLenhTao(coVi).chiTiet.last, 'ví Techcombank', reason: 'ví điền sẵn phải thấy được trên thẻ');
      expect(
          (doc('trả gym 300k mỗi tháng ví tiền mặt', ai(loai: LoaiLenhTao.hoaDon, vi: 'Techcombank')) as LenhTaoHoaDon)
              .idVi,
          'cash',
          reason: 'tên ví luật tìm thấy trong câu thắng');
    });
    test('ngân sách tự nhiên: danh mục luật tìm trong câu; hạn mức AI phải có trong câu', () {
      final l = doc('ăn uống tối đa 3 triệu một tháng',
          ai(loai: LoaiLenhTao.nganSach, danhMuc: 'Ăn uống', soTien: 3000000)) as LenhTaoNganSach;
      expect((l.idDanhMuc, l.tenDanhMuc, l.hanMuc), ('food', 'Ăn uống', 3000000.0));
    });
    test('⚠️ tầng 4 chỉ luật: "tự trả" → nhacTuTra, và query không có tham số tự trả', () {
      final l = doc('mỗi tháng tự trả gym 300k', ai(loai: LoaiLenhTao.hoaDon, ten: 'gym', soTien: 300000))
          as LenhTaoHoaDon;
      expect(l.nhacTuTra, isTrue);
      expect(l.query.keys.where((k) => k.contains('auto') || k.contains('tu_tra')), isEmpty);
    });
    test('⚠️ câu có dấu hiệu NGÂN SÁCH (tối đa / hạn mức / giới hạn) → ngân sách, dù mô hình gọi tao_hoa_don', () {
      // Realme 2026-10-01, câu 8: mô hình gọi tao_hoa_don {ten: Ăn uống, so_tien: 3000000} — thẻ "Tạo hoá đơn Ăn uống".
      final l = doc('ăn uống tối đa 3 triệu một tháng',
          ai(loai: LoaiLenhTao.hoaDon, ten: 'Ăn uống', soTien: 3000000, chuKy: 'thang', danhMuc: 'Ăn uống'));
      expect(l, isA<LenhTaoNganSach>());
      expect(((l as LenhTaoNganSach).idDanhMuc, l.hanMuc), ('food', 3000000.0));
      expect(doc('han muc giai tri 500k', ai(loai: LoaiLenhTao.hoaDon, danhMuc: 'Giải trí')), isA<LenhTaoNganSach>());
      expect(doc('giới hạn chi ăn uống 2 triệu', ai(loai: LoaiLenhTao.mucTieu)), isA<LenhTaoNganSach>());
      expect(doc('tạo hoá đơn internet tối đa 300k', ai(loai: LoaiLenhTao.nganSach)), isA<LenhTaoHoaDon>(),
          reason: 'câu THEO MẪU thì loại của mẫu thắng mọi thứ');
      expect(doc('mỗi tháng trả tiền nhà 3 triệu', ai(loai: LoaiLenhTao.hoaDon)), isA<LenhTaoHoaDon>(),
          reason: 'không dấu hiệu ngân sách → theo tool mô hình gọi');
    });
    test('⚠️ câu có dấu hiệu TIẾT KIỆM (tiết kiệm / để dành / dành dụm) → mục tiêu, dù mô hình gọi tool khác', () {
      // Realme 2026-10-01, câu 10 lượt hai: mô hình gọi dat_ngan_sach {danh_muc: Di chuyển, han_muc: 2000000} — thẻ
      // "Đặt ngân sách Di chuyển · 2.000.000 đ" cho một câu nói về để dành tiền đi du lịch.
      const dm = [(id: 'food', ten: 'Ăn uống'), (id: 'move', ten: 'Di chuyển')];
      final l = lenhTaoTuAi(
        'tiết kiệm 2 triệu mỗi tháng cho chuyến du lịch',
        ai(loai: LoaiLenhTao.nganSach, danhMuc: 'Di chuyển', soTien: 2000000),
        now: now,
        vi: vi,
        danhMucChi: dm,
      );
      expect(l, isA<LenhTaoMucTieu>());
      expect((l as LenhTaoMucTieu).soTienDich, isNull, reason: 'và 2 triệu mỗi tháng vẫn không phải số tiền đích');
      expect(doc('toi muon de danh 50 trieu mua xe', ai(loai: LoaiLenhTao.hoaDon, ten: 'mua xe')), isA<LenhTaoMucTieu>());
      expect(doc('dành dụm 30 triệu mua laptop', ai(loai: LoaiLenhTao.nganSach)), isA<LenhTaoMucTieu>());
      expect(doc('hạn mức tiết kiệm 2 triệu', ai(loai: LoaiLenhTao.mucTieu)), isA<LenhTaoNganSach>(),
          reason: 'dấu hiệu ngân sách xét TRƯỚC');
      expect(doc('tạo hoá đơn gửi tiết kiệm 2 triệu', ai(loai: LoaiLenhTao.mucTieu)), isA<LenhTaoHoaDon>(),
          reason: 'câu theo mẫu: loại của mẫu thắng');
    });
    test('⚠️ mục tiêu: số tiền THEO KỲ ("2 triệu mỗi tháng") không phải số tiền ĐÍCH', () {
      // Realme 2026-10-01, câu 10: cả luật lẫn mô hình đều điền 2.000.000 làm đích — sai nghĩa câu, và form không có ô
      // "mỗi kỳ" điền được qua lệnh (trích tự động là tầng 4).
      final l = doc('tiết kiệm 2 triệu mỗi tháng cho chuyến du lịch',
          ai(ten: 'tiết kiệm du lịch', soTien: 2000000)) as LenhTaoMucTieu;
      expect(l.soTienDich, isNull);
      expect((doc('mỗi tháng để dành 2 triệu mua xe', ai(ten: 'mua xe', soTien: 2000000)) as LenhTaoMucTieu).soTienDich,
          isNull, reason: '"mỗi tháng" đứng TRƯỚC số tiền');
      expect((doc('để dành 500k/tháng mua xe', ai(ten: 'mua xe', soTien: 500000)) as LenhTaoMucTieu).soTienDich, isNull);
      expect((doc('để dành 50 triệu mua xe trong 12 tháng', ai(ten: 'mua xe')) as LenhTaoMucTieu).soTienDich, 50000000,
          reason: '"trong 12 tháng" là hạn, không phải theo kỳ');
      final mau = lenhTaoTheoCauHoi('tạo mục tiêu du lịch 2 triệu mỗi tháng', now: now, vi: vi, danhMucChi: dmChi)
          as LenhTaoMucTieu;
      expect((mau.ten, mau.soTienDich), ('du lịch', null), reason: 'đường luật cũng thế');
    });
    test('tên của AI: các chữ phải có trong câu ĐÚNG THỨ TỰ (không cần liền nhau)', () {
      final l = doc('tiết kiệm 2 triệu mỗi tháng cho chuyến du lịch', ai(ten: 'tiết kiệm du lịch')) as LenhTaoMucTieu;
      expect(l.ten, 'tiết kiệm du lịch', reason: 'mô hình gom chữ của chính câu — không chữ nào tự nghĩ ra');
      expect((doc('để dành 50 triệu mua xe', ai(ten: 'xe mua')) as LenhTaoMucTieu).ten, isNull, reason: 'sai thứ tự');
      // Realme 2026-10-01, câu 9: mô hình đặt tên "tiền điện hàng tháng" — thẻ in "tiền điện hàng tháng · hằng tháng".
      final hd = doc('nhắc tôi đóng tiền điện hằng tháng',
          ai(loai: LoaiLenhTao.hoaDon, ten: 'tiền điện hàng tháng')) as LenhTaoHoaDon;
      expect(hd.ten, 'tiền điện', reason: 'chữ chu kỳ không phải một phần của tên — chu kỳ đã có ô riêng');
      expect((doc('nhac toi dong tien dien moi thang', ai(loai: LoaiLenhTao.hoaDon, ten: 'moi thang')) as LenhTaoHoaDon)
          .ten, isNull, reason: 'gọt xong không còn gì → không có tên');
      expect((doc('để dành 50 triệu mua xe', ai(ten: 'mua xe hơi')) as LenhTaoMucTieu).ten, isNull,
          reason: '"hơi" không có trong câu');
    });
    test('không ô nào từ AI → nguon luat', () {
      final l = doc('tạo hoá đơn gym 300k ngày 5 hằng tháng',
          ai(loai: LoaiLenhTao.hoaDon, ten: 'gym', soTien: 300000, chuKy: 'thang', ngayGoc: 5)) as LenhTaoHoaDon;
      expect(l.nguon, NguonLenh.luat);
    });
  });
}
