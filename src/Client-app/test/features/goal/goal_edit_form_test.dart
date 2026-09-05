import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_edit_form.dart';

void main() {
  group('ngayNhoNhatChoLich', () {
    test('mục tiêu còn hạn thì lịch vẫn bắt đầu từ hôm nay', () {
      final homNay = DateTime(2026, 9, 5);
      final han = DateTime(2026, 12, 31);

      expect(ngayNhoNhatChoLich(han, homNay), DateTime(2026, 9, 5),
          reason: 'Không có lý do gì cho người dùng đặt hạn định lùi về quá '
              'khứ khi hạn hiện tại vẫn còn ở tương lai.');
    });

    test('mục tiêu ĐÃ QUÁ HẠN thì lịch lùi về đúng ngày hạn cũ', () {
      final homNay = DateTime(2026, 9, 5);
      final hanCu = DateTime(2026, 3, 1);

      expect(ngayNhoNhatChoLich(hanCu, homNay), DateTime(2026, 3, 1),
          reason: 'showDatePicker ném assertion khi initialDate nằm trước '
              'firstDate, và assertion đó là MÀN ĐỎ ngay khi bấm vào ô hạn '
              'định — không phải một thông báo lỗi. Mọi mục tiêu quá hạn đều '
              'rơi vào ca này, tức chính những mục tiêu người dùng cần sửa '
              'nhất.');
    });

    test('hạn định đúng hôm nay thì không lùi', () {
      final homNay = DateTime(2026, 9, 5, 14, 30);
      final han = DateTime(2026, 9, 5, 8, 0);

      expect(ngayNhoNhatChoLich(han, homNay), DateTime(2026, 9, 5),
          reason: 'So theo NGÀY, không theo thời điểm. Hạn định lưu lúc 8 giờ '
              'sáng mà giờ đã 14 giờ 30 thì vẫn là hôm nay, không phải quá '
              'khứ — so DateTime thô sẽ lùi lịch một cách vô cớ.');
    });

    test('giờ phút của hạn cũ bị cắt bỏ', () {
      final homNay = DateTime(2026, 9, 5);
      final hanCu = DateTime(2026, 3, 1, 23, 59, 59);

      expect(ngayNhoNhatChoLich(hanCu, homNay), DateTime(2026, 3, 1),
          reason: 'firstDate của showDatePicker được so ở mức ngày. Trả về một '
              'mốc có giờ phút làm phép so biên trở nên khó đoán.');
    });
  });
}
