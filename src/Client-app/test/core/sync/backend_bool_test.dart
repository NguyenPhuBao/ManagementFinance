/// Đọc giá trị đúng/sai từ JSON của backend.
///
/// Backend không nhất quán: `goal.status_complete` là **chuỗi** `'True'`/
/// `'False'` (`VarChar(20)`), còn `goal.recurrence` là **boolean thật**. Nhánh
/// kéo về từng so khớp cứng từng kiểu một, nên chỉ cần một bên đổi cách tuần tự
/// hoá là giá trị lặng lẽ thành `false` — không exception, không log, chỉ là
/// một mục tiêu bỗng dưng "chưa hoàn thành".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/sync/backend_bool.dart';

void main() {
  group('doiSangBool — những giá trị phải cho ĐÚNG', () {
    test('boolean thật', () {
      expect(doiSangBool(true), isTrue);
    });

    test('chuỗi "True" viết hoa chữ đầu — kiểu backend đang dùng', () {
      expect(doiSangBool('True'), isTrue);
    });

    test('chuỗi "true" viết thường', () {
      expect(doiSangBool('true'), isTrue,
          reason: 'Cột `Status_complete` là VarChar(20) với mặc định "False". '
              'Không có ràng buộc nào ép viết hoa chữ đầu, nên một lần ghi từ '
              'Admin-web hay một migration là đủ để giá trị thành "true" — và '
              'phép so `== "True"` biến nó thành CHƯA hoàn thành, im lặng.');
    });

    test('chuỗi "TRUE" viết hoa hết', () {
      expect(doiSangBool('TRUE'), isTrue);
    });

    test('chuỗi có khoảng trắng thừa', () {
      expect(doiSangBool(' true '), isTrue,
          reason: 'VarChar giữ nguyên khoảng trắng. Một khoảng trắng lọt vào '
              'lúc nhập liệu không nên đổi nghĩa của dữ liệu.');
    });

    test('số 1 và chuỗi "1"', () {
      expect(doiSangBool(1), isTrue);
      expect(doiSangBool('1'), isTrue,
          reason: 'SQLite và vài trình điều khiển tuần tự hoá boolean thành '
              '0/1. Chấp nhận chúng ở NHÁNH ĐỌC không nới lỏng gì cả — nó chỉ '
              'khiến chỗ này bớt phụ thuộc vào một chi tiết của tầng vận '
              'chuyển.');
    });
  });

  group('doiSangBool — những giá trị phải cho SAI', () {
    test('boolean false và chuỗi "False"', () {
      expect(doiSangBool(false), isFalse);
      expect(doiSangBool('False'), isFalse);
      expect(doiSangBool('false'), isFalse);
    });

    test('null là sai, không phải ném', () {
      expect(doiSangBool(null), isFalse,
          reason: 'Cột nullable, và một trường vắng mặt trong JSON cũng ra '
              '`null`. Ném ở đây là một bản ghi hỏng giết cả lượt kéo về.');
    });

    test('số 0 và chuỗi rỗng', () {
      expect(doiSangBool(0), isFalse);
      expect(doiSangBool(''), isFalse);
    });

    test('chuỗi rác KHÔNG được đoán bừa thành đúng', () {
      expect(doiSangBool('có'), isFalse);
      expect(doiSangBool('yes'), isFalse,
          reason: 'Chỉ nhận đúng bốn dạng đã biết. Nhận thêm "yes"/"y"/"on" là '
              'bắt đầu đoán ý một backend chưa từng gửi chúng — và mỗi dạng '
              'đoán thêm là một chỗ để giá trị rác trở thành "đã hoàn thành".');
    });

    test('kiểu lạ hoàn toàn', () {
      expect(doiSangBool([1, 2, 3]), isFalse);
      expect(doiSangBool({'a': 1}), isFalse);
    });
  });
}
