/// B14 (đường nhanh, 2026-10-05) — câu hỏi so hai kỳ thì câu Gemma viết phải nói đúng HƯỚNG mà tool đã rút sẵn
/// (`chuThem['so_sanh_*']`). Đo Realme 2026-10-05: *"tháng này tiêu nhiều hơn tháng trước không"* → *"Tổng chi tháng này
/// là 10.000 đ, tổng chi tháng trước là 6.841.000 đ."* — đúng số, thiếu kết luận; mọi lớp chắn im.
library;

import 'package:flowmoney/features/ai_edge/domain/ket_luan_so_sanh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('huongCanNoi — hướng tool đã rút sẵn', () {
    test('lấy từ các khoá so_sanh_*, bỏ khoá khác', () {
      expect(huongCanNoi({'ky': 'tháng này', 'so_sanh_chi': 'chi ít hơn tháng trước'}), {HuongSoSanh.itHon});
      expect(huongCanNoi({'so_sanh_thu': 'thu nhiều hơn tháng trước'}), {HuongSoSanh.nhieuHon});
      expect(huongCanNoi({'so_sanh_chi': 'chi bằng tháng trước'}), {HuongSoSanh.bang});
      expect(huongCanNoi({'so_sanh_chi': 'không có dữ liệu tháng trước'}), {HuongSoSanh.khongDuLieu});
      expect(huongCanNoi({'ky': 'tháng này'}), isEmpty, reason: 'không phải câu so sánh → không xét');
    });
  });

  group('cauNoiDungHuong', () {
    test('⭐ B14: câu chỉ đưa hai con số, không kết luận → KHÔNG đạt', () {
      expect(
          cauNoiDungHuong('Tổng chi tháng này là 10.000 đ, tổng chi tháng trước là 6.841.000 đ.', {HuongSoSanh.itHon}),
          isFalse);
    });

    test('nói đúng hướng, kể cả bằng từ đồng nghĩa và không dấu → đạt', () {
      for (final c in [
        'Tháng này bạn chi ít hơn tháng trước 6.831.000 đ.',
        'Chi tháng này giảm 6.831.000 đ so với tháng trước.',
        'Tổng chi tháng này là 10.000 đ, thấp hơn tháng trước.',
        'Khong, thang nay chi it hon.',
      ]) {
        expect(cauNoiDungHuong(c, {HuongSoSanh.itHon}), isTrue, reason: c);
      }
      expect(cauNoiDungHuong('Thu tháng này tăng 2.000.000 đ.', {HuongSoSanh.nhieuHon}), isTrue);
      expect(cauNoiDungHuong('Chi tháng này bằng tháng trước.', {HuongSoSanh.bang}), isTrue);
      expect(cauNoiDungHuong('Không có dữ liệu tháng trước để so.', {HuongSoSanh.khongDuLieu}), isTrue);
    });

    test('⭐ nói NGƯỢC hướng → không đạt, dù có chữ của hướng đúng', () {
      expect(cauNoiDungHuong('Tháng này bạn chi nhiều hơn tháng trước.', {HuongSoSanh.itHon}), isFalse);
      expect(cauNoiDungHuong('Chi không ít hơn mà nhiều hơn tháng trước.', {HuongSoSanh.itHon}), isFalse,
          reason: 'câu nêu cả hai hướng là câu mơ hồ — mẫu câu chắc hơn');
    });

    test('hai hướng cần nói (chi và thu) → phải nêu cả hai', () {
      final can = {HuongSoSanh.itHon, HuongSoSanh.nhieuHon};
      expect(cauNoiDungHuong('Chi ít hơn, thu nhiều hơn tháng trước.', can), isTrue);
      expect(cauNoiDungHuong('Chi ít hơn tháng trước.', can), isFalse);
    });

    test('không có hướng nào cần nói → luôn đạt', () {
      expect(cauNoiDungHuong('bất kỳ', const {}), isTrue);
    });
  });
}
