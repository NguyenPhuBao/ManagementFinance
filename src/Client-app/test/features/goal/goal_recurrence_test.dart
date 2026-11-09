/// Hạn định của **vòng mới** khi người dùng lặp lại một mục tiêu đã hoàn thành.
///
/// Hàm thuần, không đồng hồ hệ thống: `now` tiêm vào. Phần dễ sai ở đây là phép
/// cộng tháng — cùng cái bẫy mà `mocKeTiep` đã dựng sẵn hàng rào, nên hàm này
/// gọi lại nó thay vì tự cộng.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_recurrence.dart';

void main() {
  group('hanVongMoi — vòng mới dài bằng vòng trước (có mốc bắt đầu)', () {
    test('hạn = ngày bấm + số ngày của vòng trước, KHÔNG phải hạn cũ + chu kỳ',
        () {
      // Tạo 01/11, hạn 12/12 → 41 ngày; đạt đích và bấm vòng mới 01/12.
      final han = hanVongMoi(
        hanCu: DateTime(2026, 12, 12),
        batDauCu: DateTime(2026, 11, 1, 9, 30),
        chuKy: 'Week',
        now: DateTime(2026, 12, 1, 20, 15),
      );

      expect(han, DateTime(2027, 1, 11),
          reason: 'Người dùng chốt 2026-11-04: vòng mới dài ĐÚNG số ngày họ '
              'đặt cho vòng đầu (41), tính từ lúc bấm. Bản cũ cộng chu kỳ vào '
              'hạn cũ (12/12 + 7 = 19/12 → vòng 18 ngày), không liên quan gì '
              'tới kế hoạch đã đặt — và chu kỳ cũ phải bị bỏ qua ở đây.');
    });

    test('bấm muộn vẫn được trọn số ngày, tính từ hôm bấm', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 12, 12),
        batDauCu: DateTime(2026, 11, 1),
        chuKy: null,
        now: DateTime(2026, 12, 25),
      );

      expect(han, DateTime(2027, 2, 4));
    });

    test('giữ giờ phút của hạn cũ, đếm theo NGÀY LỊCH', () {
      // Hạn 08:00 sớm hơn giờ bắt đầu 21:00: hiệu `Duration` là 29 ngày 11
      // giờ, `inDays` hụt thành 29. Đếm ngày lịch thì đúng 30.
      final han = hanVongMoi(
        hanCu: DateTime(2026, 12, 1, 8),
        batDauCu: DateTime(2026, 11, 1, 21),
        chuKy: 'Month',
        now: DateTime(2026, 11, 20, 22),
      );

      expect(han, DateTime(2026, 12, 20, 8));
    });

    test('vòng một ngày vẫn ra hạn ở tương lai', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 11, 2, 0, 0),
        batDauCu: DateTime(2026, 11, 1, 23, 0),
        chuKy: null,
        now: DateTime(2026, 11, 1, 23, 30),
      );

      expect(han!.isAfter(DateTime(2026, 11, 1, 23, 30)), isTrue);
      expect(han, DateTime(2026, 11, 2));
    });

    test('mốc bắt đầu không trước hạn thì rơi về chu kỳ cũ', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 3, 10),
        batDauCu: DateTime(2026, 3, 10, 12),
        chuKy: 'Month',
        now: DateTime(2026, 3, 15),
      );

      expect(han, DateTime(2026, 4, 10),
          reason: 'Dữ liệu hỏng (hạn trùng / trước ngày bắt đầu) không cho ra '
              'độ dài vòng dùng được — giữ luật dự phòng thay vì vòng 0 ngày.');
    });
  });

  group('soNgayMotVong', () {
    test('đếm ngày lịch, null khi dưới một ngày', () {
      expect(soNgayMotVong(DateTime(2026, 11, 1), DateTime(2026, 12, 12)), 41);
      expect(soNgayMotVong(DateTime(2026, 12, 12, 23), DateTime(2026, 12, 12)),
          isNull);
      expect(soNgayMotVong(DateTime(2027, 2, 1), DateTime(2027, 1, 1)), isNull);
    });
  });

  group('hanVongMoi — dự phòng khi thiếu mốc bắt đầu', () {
    test('hạn cũ đã qua thì nhảy tới mốc đầu tiên SAU hôm nay', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 3, 10),
        chuKy: 'Month',
        now: DateTime(2026, 9, 5),
      );

      expect(han, DateTime(2026, 9, 10),
          reason: 'Mục tiêu hoàn thành muộn thì hạn cũ đã lùi lại phía sau. '
              'Đặt vòng mới vào một mốc đã qua là nó quá hạn ngay giây đầu '
              'tiên, và bộ dự báo báo "chậm tiến độ" trước khi người dùng kịp '
              'nạp đồng nào.');
    });

    test('hạn cũ còn ở tương lai vẫn bước ĐÚNG MỘT kỳ', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 12, 31),
        chuKy: 'Month',
        now: DateTime(2026, 9, 5),
      );

      expect(han, DateTime(2027, 1, 31),
          reason: 'Đạt mục tiêu SỚM là chuyện thường. Giữ nguyên hạn cũ thì '
              'vòng mới thừa hưởng phần thời gian còn lại của vòng trước — '
              'người dùng càng về đích sớm thì vòng sau càng ngắn, ngược hẳn '
              'với ý nghĩa của một chu kỳ.');
    });

    test('giữ nguyên giờ và phút của mốc cũ', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 3, 10, 21, 45),
        chuKy: 'Month',
        now: DateTime(2026, 9, 5),
      );

      expect(han, DateTime(2026, 9, 10, 21, 45));
    });

    test('31/01 + 1 tháng trong NĂM NHUẬN kẹp về 29/02', () {
      final han = hanVongMoi(
        hanCu: DateTime(2028, 1, 31),
        chuKy: 'Month',
        now: DateTime(2028, 2, 1),
      );

      expect(han, DateTime(2028, 2, 29),
          reason: '2028 là năm nhuận. `DateTime(2028, 2, 31)` KHÔNG ném lỗi — '
              'Dart tự chuẩn hoá thành 02/03 — nên cộng tháng kiểu thô sẽ đẩy '
              'mốc trôi sang tháng sau mà không có gì báo. Hàng rào ấy nằm '
              'trong `mocKeTiep`, và hàm này phải đi qua nó.');
    });

    test('31/01 + 1 tháng trong năm THƯỜNG kẹp về 28/02', () {
      final han = hanVongMoi(
        hanCu: DateTime(2027, 1, 31),
        chuKy: 'Month',
        now: DateTime(2027, 2, 1),
      );

      expect(han, DateTime(2027, 2, 28));
    });

    test('chu kỳ trống quy về hàng tháng', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 3, 10),
        chuKy: null,
        now: DateTime(2026, 3, 15),
      );

      expect(han, DateTime(2026, 4, 10),
          reason: 'Cùng lựa chọn với `mocKeTiep`: chu kỳ trống hoặc lạ (giá '
              'trị từ Admin-web hay bản app cũ) quy về hàng tháng, để hai nơi '
              'không nói hai điều khác nhau về cùng một mục tiêu.');
    });

    test('chu kỳ ngày bù được quãng dài mà không treo', () {
      final han = hanVongMoi(
        hanCu: DateTime(2026, 1, 1),
        chuKy: 'Day',
        now: DateTime(2026, 9, 5),
      );

      expect(han, DateTime(2026, 9, 6));
    });

    test('mốc rác xa quá trần thì trả null thay vì lặp vô tận', () {
      final han = hanVongMoi(
        hanCu: DateTime(1900, 1, 1),
        chuKy: 'Day',
        now: DateTime(2026, 9, 5),
        toiDa: 50,
      );

      expect(han, isNull,
          reason: 'Dữ liệu hỏng phải dừng ở một con số hữu hạn. Vòng `while` '
              'không trần trong một hàm được gọi từ giao diện là cách treo app '
              'mà không có lấy một dòng log.');
    });
  });
}
