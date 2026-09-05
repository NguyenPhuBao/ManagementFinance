import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_wallet_shortfall.dart';

/// Canh chừng điều gì: tiến độ mục tiêu và số dư ví là **hai con số độc lập**,
/// và chúng lệch nhau được. Tiêu tiền từ ví tích lũy bằng một giao dịch thường
/// không mang `goalId`, nên tiến độ không giảm — mục tiêu báo "đã tích 2 triệu"
/// trong khi ví chỉ còn 300 nghìn.
///
/// App **không tự hoà giải** hai số ấy: một ví có thể phục vụ nhiều mục tiêu và
/// cũng chứa tiền không thuộc mục tiêu nào, nên chỉ người dùng biết khoản chi
/// vừa rồi ăn vào đâu. Việc của app là **phơi ra sự lệch**.
void main() {
  group('canhBaoViKhongDu', () {
    test('ví còn dư hơn số các mục tiêu đang giữ thì im lặng', () {
      expect(
        canhBaoViKhongDu(
          tenVi: 'Tiết kiệm',
          soDuVi: 5000000,
          tongMucTieuDangGiu: 2000000,
        ),
        isNull,
      );
    });

    test('vừa khít cũng im lặng', () {
      expect(
        canhBaoViKhongDu(
          tenVi: 'Tiết kiệm',
          soDuVi: 2000000,
          tongMucTieuDangGiu: 2000000,
        ),
        isNull,
        reason: 'Đủ đúng bằng thì không có gì bất thường để báo.',
      );
    });

    test('thiếu thì nêu CẢ HAI con số và tên ví', () {
      final msg = canhBaoViKhongDu(
        tenVi: 'Tiết kiệm',
        soDuVi: 300000,
        tongMucTieuDangGiu: 2000000,
      );
      expect(msg, isA<String>());
      expect(msg, contains('Tiết kiệm'));
      expect(msg, contains('300.000'),
          reason: 'Không nêu số dư thật thì người dùng không biết còn bao '
              'nhiêu để xoay xở.');
      expect(msg, contains('2.000.000'),
          reason: 'Không nêu số mục tiêu đang ghi nhận thì họ không thấy được '
              'độ lệch là bao nhiêu.');
    });

    test('ví âm cũng phải báo', () {
      expect(
        canhBaoViKhongDu(
          tenVi: 'Tiết kiệm',
          soDuVi: -50000,
          tongMucTieuDangGiu: 1000000,
        ),
        isA<String>(),
      );
    });

    test('chưa mục tiêu nào tích được gì thì không có gì để lệch', () {
      expect(
        canhBaoViKhongDu(
          tenVi: 'Tiết kiệm',
          soDuVi: -50000,
          tongMucTieuDangGiu: 0,
        ),
        isNull,
        reason: 'Ví âm là chuyện của ví, đã có quy tắc thông báo riêng lo. Ở '
            'đây chỉ nói về phần tiền mà MỤC TIÊU đang trông cậy vào.',
      );
    });

    test('cộng dồn nhiều mục tiêu dùng chung một ví', () {
      // Ba mục tiêu cùng trỏ vào ví Tiết kiệm, tổng 4,5 triệu; ví còn 4 triệu.
      final msg = canhBaoViKhongDu(
        tenVi: 'Tiết kiệm',
        soDuVi: 4000000,
        tongMucTieuDangGiu: 1500000 + 2000000 + 1000000,
      );
      expect(msg, isA<String>(),
          reason: 'Phải so với TỔNG của mọi mục tiêu trỏ vào ví, không phải '
              'riêng mục tiêu đang mở. So lẻ từng cái thì ba mục tiêu đều thấy '
              '"đủ tiền" trong khi cộng lại thì thiếu.');
      expect(msg, contains('4.500.000'));
    });
  });
}
