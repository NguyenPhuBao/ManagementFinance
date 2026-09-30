/// C3 — nhận lệnh "tạo hoá đơn / mục tiêu / ngân sách" ở màn Trợ lý AI (spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md` §2).
///
/// Canh chừng điều gì: lệnh chạy TRƯỚC vòng tool, nên nhận nhầm một câu hỏi
/// thành lệnh là câu hỏi ấy mất câu trả lời — không lỗi, không log. Lưới là 72
/// câu cổng F đã đo trên máy thật.
library;

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
}
