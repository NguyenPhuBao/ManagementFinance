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
        expect(l.query, {'name': 'Netflix', 'amount': '100000', 'cycle': kBillCycleMonth, 'anchor': '5'});
        expect(l.duongDan, '/bills/add?name=Netflix&amount=100000&cycle=Month&anchor=5');
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
      test('query dùng đúng khoá của B2 (dienSanTuQuery), không có start', () {
        final l = doc('tạo hoá đơn gym 300k ngày 5 danh mục giải trí ví tiền mặt') as LenhTaoHoaDon;
        expect(l.query.keys.toSet(), {'name', 'amount', 'cycle', 'anchor', 'category', 'wallet'});
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
}
