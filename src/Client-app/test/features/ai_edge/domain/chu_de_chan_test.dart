// test/features/ai_edge/domain/chu_de_chan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/chu_de_chan.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';

import '../../../tool/dinh_tuyen/du_lieu.dart';
import 'dinh_tuyen_72_cau_test.dart' show kBang72Cau;

void main() {
  // Họ D (2026-10-04, người dùng chốt: từ chối lịch sự như chủ đề ngoài phạm vi).
  // Đo Realme: "dòng tiền tự do là gì" không tool nào nhận → mô hình không gọi tool
  // → bậc 1 trả lời LẠC ĐỀ (kể số dư ví) sau 45 s. App không có nguồn nào cho
  // định nghĩa / cách tính chung.
  group('họ D: câu định nghĩa CHUNG thì chặn', () {
    for (final c in [
      'dong tien tu do la gi',
      'Dòng tiền tự do là gì?',
      'Dòng tiền tự do là gì vậy?',
      'lam phat la gi',
      'ngan sach la gi',
      'Hạn mức nghĩa là gì',
      'muc tieu tiet kiem la gi',
      // "thue" không dấu lọt danh sách có dấu — nay chặn vì là câu cách tính.
      'thue thu nhap ca nhan tinh the nao',
      'tỉ lệ tiết kiệm tính như thế nào',
      // Chữ số của một quy tắc chung không phải dấu hiệu số liệu riêng.
      'quy tac 50 30 20 la gi',
    ]) {
      test('chặn: "$c"', () => expect(chuDeBiChan(c), isTrue));
    }
  });

  group('họ D: câu "là gì" mang dấu hiệu số liệu RIÊNG thì lọt', () {
    for (final c in [
      // C18 bảng 72 và bộ huấn luyện: câu số liệu kết thúc bằng "là gì".
      'khoan chi lon nhat thang nay la gi',
      'Khoản thu lớn nhất năm nay là gì?',
      'khoan 500k hom qua la gi',
      'cac hang muc chi tieu cua toi la gi',
      'Hoá đơn sắp tới của tôi là gì',
      'giao dich gan day nhat la gi',
      'ví nào của mình là gì',
      'ngân sách tháng này tính thế nào',
    ]) {
      test('lọt: "$c"', () => expect(chuDeBiChan(c), isFalse));
    }
  });

  test('bảng 72 câu: chỉ DC1 · E22 · F16 bị chặn', () {
    // Đổi luật chặn là đổi ĐƯỜNG của câu đã đo — câu bị chặn không tới mô hình.
    final biChan = [
      for (final e in kBang72Cau.entries)
        if (chuDeBiChan(e.value.$1)) e.key,
    ];
    expect(biChan, ['DC1', 'E22', 'F16']);
  });

  test('bộ huấn luyện: không câu nào mang nhãn tool bị chặn', () {
    final mau = docTsv(docTep(kDuongBoHuanLuyen));
    expect(mau.length, greaterThan(500), reason: 'tiền đề: đọc được bộ huấn luyện');
    final oan = [
      for (final m in mau)
        if (m.nhan != kNhanKhongDinhTuyen && chuDeBiChan(m.cau)) m.toString(),
    ];
    expect(oan, isEmpty, reason: 'câu tool trả lời được mà bị từ chối');
  });

  group('chặn chủ đề ngoài phạm vi', () {
    for (final c in [
      'Tôi nên đầu tư vào đâu?',
      'Mua chứng khoán gì bây giờ',
      'Bitcoin có nên mua không',
      'Vay ngân hàng nào lãi thấp',
      'Cách né thuế thu nhập cá nhân',
    ]) {
      test('chặn: "$c"', () => expect(chuDeBiChan(c), isTrue));
    }
  });

  group('không chặn câu hỏi về số liệu của chính người dùng', () {
    for (final c in [
      'Tháng này tôi tiêu nhiều không?',
      'Ngân sách nào sắp vượt?',
      'Tôi còn thiếu bao nhiêu để đạt mục tiêu',
      'Vì sao tiền của tôi hết nhanh vậy',
    ]) {
      test('lọt: "$c"', () => expect(chuDeBiChan(c), isFalse));
    }
  });

  test('⚠️ KHÔNG bỏ dấu khi so — "đầu tư" khác "dau tu"', () {
    // Quy tắc 7 `CLAUDE.md`: bỏ dấu là phép so MẤT thông tin. Ở đây nó còn
    // nguy hiểm hơn chỗ khác: "đấu tố", "đầu tuần", "dấu tích" đều về cùng một
    // chuỗi với "đầu tư" nếu bỏ dấu, và người dùng bị từ chối một câu hỏi
    // hoàn toàn hợp lệ mà không hiểu vì sao.
    // ⚠️ Câu thử phải là câu mà việc bỏ dấu THỬC SỰ làm nó trùng từ khoá:
    // "đầu tuần" → "dau tuan", chứa "dau tu". Câu "Tuần đầu tháng" →
    // "tuan dau thang" KHÔNG chứa "dau tu", nên nó xanh cả trên bản bỏ dấu
    // — tức không canh được gì (đo bằng bản sai 2026-09-22).
    expect(chuDeBiChan('Đầu tuần này tôi tiêu bao nhiêu'), isFalse);
  });

  test('chặn không phân biệt hoa thường', () {
    expect(chuDeBiChan('ĐẦU TƯ gì bây giờ'), isTrue);
  });

  test('câu rỗng thì không chặn', () => expect(chuDeBiChan('  '), isFalse));

  group('lát 2 spec mở rộng tool: chủ đề ngoài phạm vi (E22)', () {
    for (final c in [
      'Giá vàng hôm nay bao nhiêu?',
      'gia vang hom nay bao nhieu',
      'Tỷ giá đô la hôm nay',
      'thoi tiet ngay mai the nao',
      'Kết quả xổ số hôm nay',
      'gia xang hom nay',
      // H2 cổng F lần 2 (DC1): app không lưu lãi suất ở đâu — mô hình từng gọi tool mục
      // tiêu rồi kể tiến độ MuaXe / MuaDT cho câu này.
      'Lai suat tiet kiem cua toi la bao nhieu?',
      'Lãi suất tiết kiệm của tôi là bao nhiêu?',
    ]) {
      test('chặn: "$c"', () => expect(chuDeBiChan(c), isTrue));
    }
    for (final c in [
      'hom nay ngay bao nhieu',
      'gia ve xe buyt toi da tra bao nhieu',
      'toi chi bao nhieu cho xang xe',
      'Tháng này tôi mua vàng hết bao nhiêu',
    ]) {
      test('lọt: "$c"', () => expect(chuDeBiChan(c), isFalse));
    }
  });

  group('chuDeBiChanOnline — chỉ nhóm DỮ LIỆU SỐNG (spec trợ lý online 2026-10-11 §0 q2, §3.1)', () {
    for (final c in [
      'giá vàng hôm nay bao nhiêu',
      'gia vang hom nay',
      'giá xăng tuần này',
      'tỷ giá usd',
      'ti gia hom nay',
      'lãi suất ngân hàng nào cao nhất',
      'Lãi suất hôm nay bao nhiêu?',
      'lai suat hien nay la bao nhieu',
      'Lãi suất ngân hàng hôm nay?',
      'thời tiết mai thế nào',
      'tin tức tài chính hôm nay',
      'kết quả xổ số',
      'bóng đá tối nay',
      // Câu hỏi GIÁ của tài sản: Gemini không có dữ liệu sống, sẽ bịa số cũ.
      'giá bitcoin hiện tại',
      'bitcoin gia bao nhieu',
      'cổ phiếu VNM giá bao nhiêu tiền',
      'giá đô hôm nay',
    ]) {
      test('online vẫn chặn: "$c"', () => expect(chuDeBiChanOnline(c), isTrue));
    }
    for (final c in [
      'quỹ khẩn cấp là gì',
      'quy tac 50 30 20 la gi',
      'bitcoin là gì',
      'nên đầu tư thế nào với 10 triệu',
      'chứng khoán có rủi ro gì',
      'thuế thu nhập cá nhân tính thế nào',
      'tôi có nên vay ngân hàng mua xe không',
      'tháng này tôi chi nhiều nhất cho gì',
      // Người dùng chốt 2026-10-17 khuya: chỉ lãi suất ngân hàng / hôm nay / hiện nay là dữ liệu sống.
      'Lãi suất kép là gì?',
      'Vay trả góp lãi suất 10%/năm thì mỗi tháng trả bao nhiêu?',
      'lai suat kep la gi',
    ]) {
      test('online MỞ: "$c"', () => expect(chuDeBiChanOnline(c), isFalse));
    }

    for (final c in [
      'Vậy đó là bao nhiêu tiền?',
      'còn tháng trước, đó là bao nhiêu tiền',
      'Đó là giá bao nhiêu?',
      'giá trị giao dịch lớn nhất, đó là giao dịch nào',
      'Tôi chi bao nhiêu tiền cho xăng, đó là nhiều hay ít?',
      'Vâng, vậy tháng trước tôi tiêu hết bao nhiêu tiền?',
      'Dạ vâng, ăn uống hết bao nhiêu tiền',
      'tháng vắng nhà tôi tiêu bao nhiêu tiền',
      'tôi chi bao nhiêu tiền cho rượu vang',
      'tiền áo khoác hết bao nhiêu tiền',
      'tôi có phiếu giảm giá không',
    ]) {
      test('online MỞ (bẫy bỏ dấu gộp nghĩa): "$c"',
          () => expect(chuDeBiChanOnline(c), isFalse,
              reason: 'đó là/vâng/vắng/vang/tiền áo/có phiếu bỏ dấu trùng tên tài sản'));
    }

    for (final c in [
      'giáo viên dạy về vàng có tốn tiền không',
      'học phí giáo dục của tôi bao nhiêu',
      'mua đôi giày hết giá bao nhiêu',
      'giá vé xe đôi hôm nay',
    ]) {
      test('online MỞ (ranh giới từ): "$c"',
          () => expect(chuDeBiChanOnline(c), isFalse,
              reason: 'canh ranh giới từ của RegExp có dấu: giá/đô nằm TRONG từ khác (giáo, đôi)'));
    }
    for (final c in ['giá vàng?', 'mua vàng, giá bao nhiêu tiền?', '(giá) usd.']) {
      test('online chặn (dấu câu dính): "$c"',
          () => expect(chuDeBiChanOnline(c), isTrue,
              reason: 'canh ranh giới từ của RegExp có dấu: dấu câu là ranh giới, không phải chữ/số'));
    }

    test('ranh giới cố ý: số liệu của chính người dùng — online chặn, trên máy mở', () {
      for (final c in ['tháng này tôi mua vàng hết bao nhiêu tiền', 'ví USD còn bao nhiêu tiền']) {
        expect(chuDeBiChanOnline(c), isTrue,
            reason: 'chặn oan chỉ tốn một nhãn nguồn (đi trên máy, tool trả lời từ sổ); '
                'lọt oan là Gemini bịa giá — đúng thứ cần chặn: $c');
        expect(chuDeBiChan(c), isFalse, reason: 'trên máy tool trả lời từ sổ: $c');
      }
    });

    test('bộ huấn luyện: online không chặn oan câu mang nhãn tool', () {
      final mau = docTsv(docTep(kDuongBoHuanLuyen));
      expect(mau.length, greaterThan(500), reason: 'tiền đề: đọc được bộ huấn luyện');
      final oan = [
        for (final m in mau)
          if (m.nhan != kNhanKhongDinhTuyen && chuDeBiChanOnline(m.cau)) m.toString(),
      ];
      expect(oan, isEmpty, reason: 'câu tool trả lời được mà bị chặn online');
    });

    test('chuDeBiChan (trên máy) vẫn chặn "lãi suất" trần — đổi online không được đổi đường máy', () {
      expect(chuDeBiChan('Lãi suất kép là gì?'), isTrue, reason: 'cổng F: H2 lần 2 đã đo');
    });

    test('ca canh: chuDeBiChan (trên máy) KHÔNG đổi — nhóm tư vấn và định nghĩa vẫn chặn', () {
      for (final c in ['bitcoin là gì', 'nên đầu tư thế nào', 'thuế thu nhập cá nhân tính thế nào', 'giá vàng hôm nay']) {
        expect(chuDeBiChan(c), isTrue, reason: c);
      }
      expect(chuDeBiChan('tháng này tôi chi nhiều nhất cho gì'), isFalse);
    });
  });
}
