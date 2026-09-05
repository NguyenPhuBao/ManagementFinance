import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_deposit_warning.dart';

GoalEntity _mucTieu({required double target, required double current}) {
  return GoalEntity(
    id: 'g1',
    idaccount: 1,
    name: 'Mua xe',
    targetAmount: target,
    currentAmount: current,
    targetDate: DateTime(2026, 12, 31),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('remainingAmount', () {
    test('phần còn thiếu là hiệu của mục tiêu và số đã tích', () {
      expect(_mucTieu(target: 1000, current: 250).remainingAmount, 750);
    });

    test('đã vượt mục tiêu thì còn thiếu 0, KHÔNG âm', () {
      expect(_mucTieu(target: 1000, current: 1500).remainingAmount, 0.0,
          reason: 'Số âm chảy thẳng vào câu "Còn lại -500.000đ để đạt mục '
              'tiêu" trên trang chi tiết.');
    });

    test('mục tiêu 0 đồng thì không còn thiếu gì', () {
      expect(_mucTieu(target: 0, current: 0).remainingAmount, 0.0);
    });
  });

  group('canhBaoNapVuot', () {
    test('nạp vừa đủ phần còn thiếu thì không nhắc gì', () {
      expect(canhBaoNapVuot(_mucTieu(target: 1000000, current: 400000), 600000),
          isNull);
    });

    test('nạp ít hơn phần còn thiếu thì không nhắc gì', () {
      expect(canhBaoNapVuot(_mucTieu(target: 1000000, current: 400000), 100000),
          isNull);
    });

    test('nạp vượt thì nhắc, kèm số tiền vượt', () {
      final msg =
          canhBaoNapVuot(_mucTieu(target: 1000000, current: 400000), 900000);
      expect(msg, isA<String>());
      expect(msg, contains('300.000'),
          reason: 'Nhắc mà không nói vượt bao nhiêu thì người dùng phải tự '
              'tính. 900.000 nạp vào khi còn thiếu 600.000 là vượt 300.000.');
    });

    test('mục tiêu đã đạt thì mọi khoản nạp đều là vượt', () {
      expect(canhBaoNapVuot(_mucTieu(target: 1000000, current: 1000000), 50000),
          isA<String>());
    });

    test('số tiền không hợp lệ thì im lặng, để nơi khác lo', () {
      expect(canhBaoNapVuot(_mucTieu(target: 1000000, current: 0), 0), isNull,
          reason: 'Ô nhập đã có phép kiểm "phải lớn hơn 0" riêng. Nhắc thêm ở '
              'đây chỉ chồng hai thông báo lên nhau.');
      expect(canhBaoNapVuot(_mucTieu(target: 1000000, current: 0), -5), isNull);
    });
  });
}
