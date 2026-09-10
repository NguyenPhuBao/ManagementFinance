import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_forecast.dart';

/// Canh chừng điều gì: hạn chót của mục tiêu được tính MỘT LẦN lúc tạo, từ chu
/// kỳ trích tiền mà người dùng chọn, rồi đóng băng. Sau đó người dùng nạp tay,
/// số bất kỳ, lúc bất kỳ — kế hoạch và thực tế trôi xa nhau mà không có gì đối
/// chiếu. Các hàm ở đây dựng lại nhịp THẬT từ số tiền đã tích được.
GoalEntity _mucTieu({
  required double target,
  required double current,
  DateTime? start,
  required DateTime han,
  String? chuKy,
}) {
  return GoalEntity(
    id: 'g1',
    idaccount: 1,
    name: 'Mua xe',
    targetAmount: target,
    currentAmount: current,
    startDate: start,
    targetDate: han,
    cycleTakeMoney: chuKy,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('soNgayChuKy', () {
    test('quy đổi các giá trị backend dùng', () {
      expect(soNgayChuKy('Day'), 1);
      expect(soNgayChuKy('Week'), 7);
      expect(soNgayChuKy('Month'), 30);
      expect(soNgayChuKy('Quarter'), 90);
      expect(soNgayChuKy('Year'), 365);
    });

    test('giá trị lạ hoặc trống thì coi như hàng tháng', () {
      expect(soNgayChuKy(null), 30);
      expect(soNgayChuKy('Fortnight'), 30,
          reason: 'Đoán bừa một chu kỳ khác làm mọi con số hiển thị sai lệch '
              'mà không ai biết vì sao. Hàng tháng là mặc định của cả app.');
    });
  });

  group('tocDoThucTe — tiền tích được mỗi chu kỳ', () {
    test('tích 3 triệu trong 30 ngày là 3 triệu mỗi tháng', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        start: DateTime(2026, 6, 1),
        han: DateTime(2026, 12, 31),
      );
      expect(tocDoThucTe(g, DateTime(2026, 7, 1)), closeTo(3000000, 1));
    });

    test('chu kỳ tuần thì chia theo tuần', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        start: DateTime(2026, 6, 1),
        han: DateTime(2026, 12, 31),
        chuKy: 'Week',
      );
      expect(tocDoThucTe(g, DateTime(2026, 7, 1)), closeTo(700000, 1),
          reason: '3 triệu trong 30 ngày = 100k/ngày = 700k/tuần. Hiển thị '
              'theo đúng nhịp người dùng đã chọn thì họ đối chiếu được ngay.');
    });

    test('chưa có ngày bắt đầu thì KHÔNG đoán', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        han: DateTime(2026, 12, 31),
      );
      expect(tocDoThucTe(g, DateTime(2026, 7, 1)), isNull,
          reason: 'Cùng lý do như isBehindSchedule: im lặng đúng hơn là báo '
              'bừa. Mục tiêu tạo bởi bản app cũ không có mốc này.');
    });

    test('cùng ngày tạo thì chưa có nhịp nào để đo', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        start: DateTime(2026, 6, 1),
        han: DateTime(2026, 12, 31),
      );
      expect(tocDoThucTe(g, DateTime(2026, 6, 1)), isNull,
          reason: 'Chia cho 0 ngày ra Infinity chứ không ném — giá trị hỏng '
              'sẽ trôi thẳng lên màn hình.');
    });

    test('chưa nạp đồng nào thì tốc độ là 0, không phải null', () {
      final g = _mucTieu(
        target: 30000000,
        current: 0,
        start: DateTime(2026, 6, 1),
        han: DateTime(2026, 12, 31),
      );
      expect(tocDoThucTe(g, DateTime(2026, 7, 1)), 0.0,
          reason: '"Chưa tích được gì" là một câu trả lời có nghĩa, khác hẳn '
              '"không đủ căn cứ để nói".');
    });
  });

  group('tocDoKeHoach — cần bao nhiêu mỗi chu kỳ để kịp hạn', () {
    test('30 triệu trong 300 ngày là 3 triệu mỗi tháng', () {
      final g = _mucTieu(
        target: 30000000,
        current: 0,
        start: DateTime(2026, 1, 1),
        han: DateTime(2026, 10, 28),
      );
      expect(tocDoKeHoach(g), closeTo(3000000, 50000));
    });

    test('lấy phần CÒN THIẾU chứ không phải toàn bộ mục tiêu', () {
      final g = _mucTieu(
        target: 30000000,
        current: 15000000,
        start: DateTime(2026, 1, 1),
        han: DateTime(2026, 10, 28),
      );
      expect(tocDoKeHoach(g), closeTo(1500000, 50000),
          reason: 'Đã tích được một nửa thì nhịp cần thiết cho phần còn lại '
              'chỉ bằng một nửa. Vẫn đọc theo mục tiêu gốc thì câu "cần 3 '
              'triệu mỗi tháng" không bao giờ giảm dù người dùng đã tích được '
              'gần đủ.');
    });

    test('đã đạt mục tiêu thì không cần thêm gì', () {
      final g = _mucTieu(
        target: 30000000,
        current: 30000000,
        start: DateTime(2026, 1, 1),
        han: DateTime(2026, 10, 28),
      );
      expect(tocDoKeHoach(g), 0.0);
    });

    test('quá hạn mà chưa đạt thì không còn nhịp nào cứu được', () {
      final g = _mucTieu(
        target: 30000000,
        current: 1000000,
        start: DateTime(2026, 1, 1),
        han: DateTime(2026, 3, 1),
      );
      expect(tocDoKeHoach(g, now: DateTime(2026, 6, 1)), isNull,
          reason: 'Chia cho số ngày âm ra một con số âm vô nghĩa.');
    });
  });

  group('duBaoHoanThanh', () {
    test('giữ đúng nhịp hiện tại thì đạt vào ngày nào', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        start: DateTime(2026, 6, 1),
        han: DateTime(2027, 6, 1),
      );
      // 3tr/30 ngày = 100k/ngày; còn thiếu 27tr → 270 ngày nữa.
      final duBao = duBaoHoanThanh(g, DateTime(2026, 7, 1));
      expect(duBao, isA<DateTime>());
      expect(duBao!.difference(DateTime(2026, 7, 1)).inDays, closeTo(270, 2));
    });

    test('chưa nạp đồng nào thì KHÔNG có dự báo', () {
      final g = _mucTieu(
        target: 30000000,
        current: 0,
        start: DateTime(2026, 6, 1),
        han: DateTime(2027, 6, 1),
      );
      expect(duBaoHoanThanh(g, DateTime(2026, 7, 1)), isNull,
          reason: 'Tốc độ 0 cho ra ngày ở vô cực. Nơi gọi phải nói "chưa đạt '
              'được với tốc độ hiện tại" chứ không hiện một ngày bịa.');
    });

    test('đã đạt rồi thì dự báo là hôm nay', () {
      final g = _mucTieu(
        target: 30000000,
        current: 30000000,
        start: DateTime(2026, 6, 1),
        han: DateTime(2027, 6, 1),
      );
      final nay = DateTime(2026, 7, 1);
      expect(duBaoHoanThanh(g, nay), nay);
    });

    test('thiếu ngày bắt đầu thì KHÔNG đoán', () {
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        han: DateTime(2027, 6, 1),
      );
      expect(duBaoHoanThanh(g, DateTime(2026, 7, 1)), isNull);
    });

    test('dự báo trễ hơn hạn chót khớp với isBehindSchedule', () {
      // Nửa kỳ mà mới tích được 10% → chắc chắn trễ.
      final g = _mucTieu(
        target: 30000000,
        current: 3000000,
        start: DateTime(2026, 1, 1),
        han: DateTime(2026, 7, 1),
      );
      final nay = DateTime(2026, 4, 1);
      final duBao = duBaoHoanThanh(g, nay)!;
      expect(duBao.isAfter(g.targetDate), isTrue);
      expect(g.isBehindSchedule(nay), isTrue,
          reason: 'Hai phép tính phải nói cùng một điều. Lệch nhau là thẻ mục '
              'tiêu nói "đúng tiến độ" trong khi dự báo nói quá hạn.');
    });
  });

  /// Cửa sổ tối thiểu — thêm 2026-09-08 sau khi đo trên máy thật.
  ///
  /// Mục tiêu `MuaXe` tạo ngày 05/09, xem ngày 08/09, đã tích 1.101.000 đ,
  /// chu kỳ tháng. Trang chi tiết hiện **"đang tích 11.010.000 đ mỗi tháng"**
  /// — gấp mười lần tổng đã tích được cả đời mục tiêu — và dự báo hoàn thành
  /// ngay **tháng này** cho một mục tiêu hạn 2028.
  ///
  /// Số học không sai: `1.101.000 / 3 ngày × 30 = 11.010.000`. Cái sai là
  /// **ngoại suy**: ba ngày dữ liệu nhân lên thành nhịp tháng thì hệ số phóng
  /// đại là 10. Phép chặn cũ chỉ có `soNgayDaQua <= 0`, tức nó chỉ chặn đúng
  /// phép chia cho 0 chứ không chặn việc bịa ra một nhịp.
  group('cửa sổ tối thiểu — không ngoại suy từ vài ngày', () {
    test('chu kỳ tháng mà mới 3 ngày thì KHÔNG nói nhịp', () {
      final g = _mucTieu(
        target: 2000000,
        current: 1101000,
        start: DateTime(2026, 9, 5),
        han: DateTime(2028, 4, 27),
        chuKy: 'Month',
      );

      expect(tocDoThucTe(g, DateTime(2026, 9, 8)), isNull,
          reason: 'Đây là ca THẬT đo trên máy ảo. Trả một con số ở đây là nói '
              'với người dùng rằng họ đang tích 11 triệu mỗi tháng trong khi '
              'tổng cộng mới có 1,1 triệu.');
      expect(duBaoHoanThanh(g, DateTime(2026, 9, 8)), isNull,
          reason: 'Cùng phép ngoại suy, cùng hệ số phóng đại — chặn một chỗ mà '
              'để chỗ kia nói tiếp là hộp dự báo vẫn sai, chỉ sai gọn hơn.');
    });

    test('đủ NỬA chu kỳ thì bắt đầu nói', () {
      final g = _mucTieu(
        target: 2000000,
        current: 500000,
        start: DateTime(2026, 9, 1),
        han: DateTime(2027, 9, 1),
        chuKy: 'Month',
      );

      expect(tocDoThucTe(g, DateTime(2026, 9, 16)), isNotNull,
          reason: 'Nửa chu kỳ là ngưỡng: hệ số phóng đại tối đa còn 2, mức '
              'sai lệch chấp nhận được cho một câu ước lượng. Đợi trọn một '
              'chu kỳ thì mục tiêu hàng tháng câm suốt tháng đầu — mà tháng '
              'đầu mới là lúc người dùng mở ra xem nhiều nhất.');
    });

    test('chu kỳ NGÀY thì một ngày đã đủ', () {
      final g = _mucTieu(
        target: 1000000,
        current: 50000,
        start: DateTime(2026, 9, 1),
        han: DateTime(2026, 12, 1),
        chuKy: 'Day',
      );

      expect(tocDoThucTe(g, DateTime(2026, 9, 2)), isNotNull,
          reason: 'Chu kỳ ngày thì phép nhân là 1 — không có ngoại suy nào để '
              'chặn. Một ngưỡng cứng tính bằng ngày sẽ bắt nhịp này im lặng '
              'vô cớ; ngưỡng phải tính THEO chu kỳ.');
    });

    test('chu kỳ NĂM thì vài tháng vẫn chưa đủ', () {
      final g = _mucTieu(
        target: 100000000,
        current: 5000000,
        start: DateTime(2026, 1, 1),
        han: DateTime(2030, 1, 1),
        chuKy: 'Year',
      );

      expect(tocDoThucTe(g, DateTime(2026, 3, 1)), isNull,
          reason: 'Hai tháng nhân lên thành nhịp năm là hệ số 6. Cùng một lỗi '
              'với ca ba ngày, chỉ khác thang.');
      expect(tocDoThucTe(g, DateTime(2026, 8, 1)), isNotNull,
          reason: 'Quá nửa năm thì nói được.');
    });

    test('chưa nạp đồng nào nhưng đã đủ cửa sổ thì vẫn trả 0', () {
      final g = _mucTieu(
        target: 2000000,
        current: 0,
        start: DateTime(2026, 9, 1),
        han: DateTime(2027, 9, 1),
        chuKy: 'Month',
      );

      expect(tocDoThucTe(g, DateTime(2026, 9, 20)), 0.0,
          reason: 'Cửa sổ tối thiểu nói về việc CÓ ĐỦ THỜI GIAN để đo hay '
              'chưa, không phải về việc có tiền hay không. Gộp hai câu ấy làm '
              'một là mất đi câu "bạn chưa tích được gì" — thứ đáng nói nhất '
              'với một mục tiêu đứng yên.');
    });
  });
}
