/// Thời gian tương đối tiếng Việt cho danh sách thông báo.
///
/// Thiết kế Stitch viết "10 phút trước" / "2 giờ trước" / "Hôm qua". Chỗ dễ sai
/// nhất là **biên ngày**: 23:59 hôm qua nhìn từ 00:01 hôm nay chỉ cách 2 phút
/// theo phép trừ, nhưng người dùng đọc "2 phút trước" cho một việc xảy ra
/// *hôm qua* sẽ thấy sai. Phải so theo NGÀY LỊCH, không theo hiệu số.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/relative_time.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10, 30);

  String moc(DateTime when) => relativeTimeVi(when, now: now);

  group('trong vòng một giờ', () {
    test('dưới một phút là "Vừa xong"', () {
      expect(moc(now.subtract(const Duration(seconds: 59))), 'Vừa xong');
    });

    test('đúng một phút bắt đầu đếm phút', () {
      expect(moc(now.subtract(const Duration(minutes: 1))), '1 phút trước');
    });

    test('59 phút vẫn là phút', () {
      expect(moc(now.subtract(const Duration(minutes: 59))), '59 phút trước');
    });
  });

  group('trong ngày', () {
    test('đúng 60 phút chuyển sang giờ', () {
      expect(moc(now.subtract(const Duration(minutes: 60))), '1 giờ trước');
    });

    test('vài giờ trước, đúng như thiết kế', () {
      expect(moc(now.subtract(const Duration(hours: 2))), '2 giờ trước');
    });
  });

  group('biên ngày lịch', () {
    test('23:59 hôm qua nhìn từ 00:01 hôm nay là "Hôm qua"', () {
      expect(
        relativeTimeVi(DateTime(2026, 9, 14, 23, 59),
            now: DateTime(2026, 9, 15, 0, 1)),
        'Hôm qua',
        reason: 'Chỉ cách 2 phút theo phép trừ. Trả "2 phút trước" cho một việc '
            'xảy ra hôm qua là đọc sai — phải so theo ngày lịch.',
      );
    });

    test('00:05 hôm nay nhìn từ 10:30 cùng ngày vẫn tính theo giờ', () {
      expect(
        relativeTimeVi(DateTime(2026, 9, 15, 0, 5), now: now),
        '10 giờ trước',
        reason: 'Cùng ngày thì không được nhảy sang "Hôm qua" chỉ vì đã hơn '
            'mười tiếng.',
      );
    });

    test('hai ngày trước hiện ngày tháng đầy đủ', () {
      expect(moc(DateTime(2026, 9, 13, 8)), '13/09/2026');
    });
  });

  group('mốc ở tương lai', () {
    test('không trả số âm', () {
      expect(moc(now.add(const Duration(hours: 3))), 'Vừa xong',
          reason: 'Lệch đồng hồ giữa máy và server có thật. "-3 giờ trước" là '
              'thứ không ai đọc được.');
    });
  });
}
