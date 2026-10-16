/// Câu chào ở màn Trợ lý AI (2026-10-09, người dùng chọn *"mô hình đáp, không tra cứu"*).
///
/// Đo OnePlus 09/10: *"xin chao ban"* đi phiên sáu tool, mô hình gọi nhầm `truy_van_giao_dich` rồi đáp *"Tôi đã tìm
/// thấy các giao dịch trong kỳ tháng này."* sau 15 s. Câu chào nay được nhận ra TRƯỚC vòng lặp tool và Gemma đáp
/// trong một lượt sinh không tool.
library;

import 'package:flowmoney/features/ai_edge/domain/cau_chao.dart';
import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('laCauChao', () {
    for (final c in [
      'xin chào',
      'xin chao ban',
      'Chào bạn!',
      'hello',
      'hi',
      'alo',
      'cảm ơn bạn nhé',
      'cam on nhieu',
      'thanks',
      'tạm biệt',
      'bạn là ai?',
      'ban giup duoc gi',
      'chào buổi sáng',
    ]) {
      test('"$c" là câu chào', () => expect(laCauChao(c), isTrue));
    }

    for (final c in [
      'chào, tháng này tôi chi bao nhiêu',
      'xin chao, chi tieu thang nay',
      'cảm ơn, còn ngân sách ăn uống thì sao',
      'chi bao nhieu',
      'ví nào còn nhiều tiền nhất',
      'hoá đơn nào quá hạn',
      'ok',
      '',
    ]) {
      test('"$c" KHÔNG phải câu chào — có nội dung cần tra cứu', () => expect(laCauChao(c), isFalse));
    }
  });

  test('promptTroChuyen: dặn không nêu con số, gợi ý chủ đề, kết bằng "Trả lời:"', () {
    final p = promptTroChuyen('xin chào');
    expect(p, contains('Không nêu bất kỳ con số nào'));
    expect(p, contains('chi tiêu'));
    expect(p, contains('Câu của người dùng: xin chào'));
    expect(p.trimRight(), endsWith('Trả lời:'));
  });

  test('kiemCauChao chặn mọi câu có chữ số — câu chào không được bịa số liệu', () {
    expect(kiemCauChao('Chào bạn! Tháng này bạn đã chi 500.000 đ.'), isFalse);
    expect(kiemCauChao('Chào bạn! Mình có thể giúp bạn xem chi tiêu và ngân sách.'), isTrue);
  });

  test('⭐ câu gợi ý nêu "mục tiêu tiết kiệm", "ví của bạn" KHÔNG bị chặn oan (OnePlus 09/10)', () {
    const cau = 'Bạn có thể hỏi mình về chi tiêu, ngân sách, hóa đơn, mục tiêu tiết kiệm hoặc ví của bạn nhé!';
    expect(kiemCauChao(cau), isTrue);
    expect(kiemCauTraLoi(cau, const []), isFalse,
        reason: 'tiền đề: kiemTen đọc "mục tiêu tiết kiệm" là tên lạ — lý do câu chào có bộ kiểm riêng');
  });

  group('kemDuPhongChao', () {
    test('có câu qua → giữ nguyên, không thêm câu dự phòng', () async {
      final ra = await kemDuPhongChao(Stream.fromIterable(const [CauQua('Chào bạn!')])).toList();
      expect(ra, const [CauQua('Chào bạn!')]);
    });

    test('mọi câu bị chặn → câu dự phòng cố định (không để màn hiện "không chắc chắn")', () async {
      final ra = await kemDuPhongChao(Stream.fromIterable(const [BiChan('Bạn chi 5 đ.')])).toList();
      expect(ra, const [BiChan('Bạn chi 5 đ.'), CauQua(kCauChaoDuPhong)]);
    });
  });
}
