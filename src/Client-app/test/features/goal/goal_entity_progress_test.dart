/// Thuộc tính suy ra của `GoalEntity`.
///
/// Đặt trong **chính entity** chứ không trong bộ luật thông báo: trang mục tiêu
/// cũng cần đúng những con số này, và hai nơi tự tính theo hai cách là thẻ mục
/// tiêu nói "đúng tiến độ" trong khi thông báo nói "đang trễ".
///
/// Vùng nguy hiểm là **phép chia**: mục tiêu có `targetAmount = 0` và mục tiêu
/// bắt đầu đúng ngày kết thúc đều làm mẫu số bằng 0. Cả hai đều tạo được từ
/// giao diện, và `double` chia 0 trong Dart cho ra `Infinity`/`NaN` chứ **không
/// ném** — nên nó lặng lẽ trôi tới tận thanh tiến độ trên màn hình.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';

void main() {
  GoalEntity mucTieu({
    double target = 10000000,
    double current = 2000000,
    DateTime? batDau,
    DateTime? ketThuc,
    bool xong = false,
  }) {
    return GoalEntity(
      id: 'mt1',
      idaccount: 7,
      name: 'MacBook',
      targetAmount: target,
      currentAmount: current,
      startDate: batDau ?? DateTime(2026, 1, 1),
      targetDate: ketThuc ?? DateTime(2026, 12, 31),
      isCompleted: xong,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  group('progress', () {
    test('tỉ lệ đã tích được', () {
      expect(mucTieu(target: 1000, current: 250).progress, 0.25);
    });

    test('vượt mục tiêu vẫn kẹp ở 1.0', () {
      expect(mucTieu(target: 1000, current: 1500).progress, 1.0,
          reason: 'Thanh tiến độ vẽ theo giá trị này. Trả 1.5 là thanh tràn ra '
              'ngoài khung.');
    });

    test('mục tiêu 0 đồng không cho ra Infinity', () {
      final p = mucTieu(target: 0, current: 500).progress;
      expect(p.isFinite, isTrue,
          reason: 'Dart chia cho 0 ra Infinity chứ KHÔNG ném, nên giá trị hỏng '
              'trôi thẳng tới thanh tiến độ trên màn hình.');
      expect(p, 1.0,
          reason: 'Không cần thêm đồng nào thì coi như đã đạt.');
    });

    test('số âm không kéo tiến độ xuống dưới 0', () {
      expect(mucTieu(target: 1000, current: -100).progress, 0.0);
    });
  });

  group('daysLeft', () {
    test('đếm theo NGÀY, không theo giờ', () {
      final mt = mucTieu(ketThuc: DateTime(2026, 9, 20));
      expect(mt.daysLeft(DateTime(2026, 9, 15, 23, 59)), 5,
          reason: 'Trừ DateTime thô thì cùng một mục tiêu ra 4 hay 5 ngày tuỳ '
              'giờ người dùng mở app — hỏng ngẫu nhiên và rất khó lần ra.');
    });

    test('đúng ngày kết thúc là 0, không phải âm', () {
      final mt = mucTieu(ketThuc: DateTime(2026, 9, 15));
      expect(mt.daysLeft(DateTime(2026, 9, 15, 8)), 0);
    });

    test('quá hạn cho số âm', () {
      final mt = mucTieu(ketThuc: DateTime(2026, 9, 10));
      expect(mt.daysLeft(DateTime(2026, 9, 15)), -5);
    });
  });

  group('isBehindSchedule', () {
    test('đi đúng nhịp thì không bị coi là trễ', () {
      // Kỳ 100 ngày, đã qua 50 ngày, đã tích được đúng một nửa.
      final mt = mucTieu(
        target: 1000,
        current: 500,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 4, 11),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 2, 20)), isFalse);
    });

    test('tích được ít hơn nhịp thời gian thì bị coi là trễ', () {
      final mt = mucTieu(
        target: 1000,
        current: 100,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 4, 11),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 2, 20)), isTrue);
    });

    test('lệch dưới biên dung sai thì chưa coi là trễ', () {
      // Kỳ 100 ngày, đã qua 50 ngày → nhịp kỳ vọng 50%. Đạt 47% là lệch 3%.
      final mt = mucTieu(
        target: 1000,
        current: 470,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 4, 11),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 2, 20)), isFalse,
          reason: 'Nhịp kỳ vọng là tuyến tính theo ngày, còn người dùng nhận '
              'lương theo tháng — tiến độ thật luôn dao động quanh đường ấy. '
              'Báo "chậm tiến độ" vì lệch vài phần trăm là dạy người dùng rằng '
              'thông báo của app không đáng tin.');
    });

    test('lệch quá biên dung sai thì là trễ', () {
      // Cùng kỳ như trên nhưng chỉ đạt 40% — lệch 10%.
      final mt = mucTieu(
        target: 1000,
        current: 400,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 4, 11),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 2, 20)), isTrue);
    });

    test('đã hoàn thành thì không bao giờ trễ', () {
      final mt = mucTieu(
        target: 1000,
        current: 1000,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 4, 11),
        xong: true,
      );
      expect(mt.isBehindSchedule(DateTime(2026, 4, 10)), isFalse);
    });

    test('chưa tới ngày bắt đầu thì chưa đánh giá', () {
      final mt = mucTieu(
        target: 1000,
        current: 0,
        batDau: DateTime(2026, 6, 1),
        ketThuc: DateTime(2026, 12, 31),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 5, 1)), isFalse,
          reason: 'Báo "trễ tiến độ" cho một mục tiêu chưa bắt đầu là vô nghĩa '
              'và làm người dùng mất tin vào mọi thông báo khác.');
    });

    test('thiếu ngày bắt đầu thì KHÔNG đoán bừa', () {
      final mt = GoalEntity(
        id: 'mt2',
        idaccount: 7,
        name: 'Không rõ mốc',
        targetAmount: 1000,
        currentAmount: 0,
        startDate: null,
        targetDate: DateTime(2026, 12, 31),
        updatedAt: DateTime(2026, 9, 1),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 9, 15)), isFalse,
          reason: 'startDate là cột nullable, và mục tiêu tạo bởi bản app cũ '
              'không có nó. Không có mốc bắt đầu thì không có nhịp để so — im '
              'lặng đúng hơn là báo bừa.');
    });

    test('bắt đầu và kết thúc cùng ngày không cho ra NaN', () {
      final mt = mucTieu(
        target: 1000,
        current: 0,
        batDau: DateTime(2026, 9, 15),
        ketThuc: DateTime(2026, 9, 15),
      );
      // Không đòi true hay false — chỉ đòi hàm không nổ và không trả rác.
      expect(() => mt.isBehindSchedule(DateTime(2026, 9, 15)), returnsNormally,
          reason: 'Mẫu số bằng 0. Giao diện cho phép tạo mục tiêu như thế này.');
    });

    test('quá hạn mà chưa đạt thì là trễ', () {
      final mt = mucTieu(
        target: 1000,
        current: 900,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 9, 10),
      );
      expect(mt.isBehindSchedule(DateTime(2026, 9, 15)), isTrue);
    });
  });

  test('startDate đi qua được vòng Drift mà không mất', () {
    final mt = mucTieu(batDau: DateTime(2026, 3, 15));
    final companion = mt.toCompanion();

    expect(companion.startDate.value, DateTime(2026, 3, 15),
        reason: 'toCompanion() trước đây bỏ qua cột này, nên mỗi lần ghi lại '
            'mục tiêu là mốc bắt đầu bị xoá — và isBehindSchedule mất căn cứ '
            'để so.');
  });
}
