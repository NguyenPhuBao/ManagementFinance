// test/features/ai_edge/domain/chu_de_chan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/chu_de_chan.dart';

void main() {
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
}
