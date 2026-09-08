/// Khối "Cấu hình" trên trang chi tiết mục tiêu.
///
/// Vì sao cần: người dùng báo trang chi tiết **thiếu nội dung** (2026-09-08).
/// Đo lại thì trang không thiếu *dữ liệu* — nó thiếu chỗ **hiển thị**. Bốn thứ
/// dưới đây đều đã nằm sẵn trên `GoalEntity` mà không dòng nào trên trang nói
/// tới:
///
/// | Thiếu | Đã có sẵn |
/// |---|---|
/// | Trích tự động đang bật hay tắt | `autoDepositEnabled` + ba cột cấu hình |
/// | Hạn chót và số ngày còn lại | `targetDate`, `daysLeft` |
/// | Ví tích luỹ | `walletId` — trước chỉ dùng cho hộp thoại |
/// | Đúng nhịp hay chậm | `isBehindSchedule` — trước chỉ dùng cho thông báo |
///
/// Chỗ nghiêm trọng nhất là dòng đầu: app tự chuyển tiền của người dùng mỗi kỳ
/// mà **trang chính của mục tiêu không nói gì**, phải mở trang Sửa mới biết.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_config_card.dart';

void main() {
  final now = DateTime(2026, 9, 8);

  GoalEntity mt({
    double target = 2000000,
    double current = 500000,
    DateTime? batDau,
    DateTime? han,
    String? chuKy = 'Month',
    double? trichSoTien,
    String? trichVi,
    DateTime? trichMoc,
    bool xong = false,
  }) {
    return GoalEntity(
      id: 'g1',
      idaccount: 7,
      name: 'MuaXe',
      targetAmount: target,
      currentAmount: current,
      startDate: batDau ?? DateTime(2026, 1, 1),
      targetDate: han ?? DateTime(2028, 4, 27),
      walletId: 'w-tiet-kiem',
      cycleTakeMoney: chuKy,
      autoDepositAmount: trichSoTien,
      autoDepositWalletId: trichVi,
      autoDepositLastRun: trichMoc,
      isCompleted: xong,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  group('moTaHanChot', () {
    test('còn hạn thì đếm ngược theo NGÀY', () {
      expect(moTaHanChot(mt(han: DateTime(2026, 9, 18)), now), 'Còn 10 ngày');
    });

    test('đúng hôm nay là hạn chót', () {
      expect(moTaHanChot(mt(han: DateTime(2026, 9, 8)), now), 'Hôm nay là hạn');
    });

    test('quá hạn thì nói rõ quá bao lâu, không hiện số âm', () {
      expect(moTaHanChot(mt(han: DateTime(2026, 9, 1)), now), 'Quá hạn 7 ngày',
          reason: '"Còn -7 ngày" là con số đúng nhưng đọc lên thì vô nghĩa. '
              'Đây cũng là ca hay gặp nhất với mục tiêu cũ bỏ dở.');
    });

    test('mục tiêu đã đạt thì không đếm ngược nữa', () {
      final g = mt(target: 1000, current: 1000, han: DateTime(2026, 9, 1));
      expect(moTaHanChot(g, now), 'Đã đạt mục tiêu',
          reason: 'Một mục tiêu đã xong mà màn hình vẫn hô "Quá hạn 7 ngày" là '
              'trách người dùng vì một việc họ đã làm được.');
    });
  });

  group('moTaTrichTuDong', () {
    test('chưa bật thì nói TẮT', () {
      expect(moTaTrichTuDong(mt(), tenViNguon: null), 'Đang tắt');
    });

    test('đã bật thì nêu đủ số tiền, nhịp và ví nguồn', () {
      final g = mt(
        trichSoTien: 500000,
        trichVi: 'w-tien-mat',
        trichMoc: DateTime(2026, 9, 1),
      );

      final ra = moTaTrichTuDong(g, tenViNguon: 'Tiền mặt');
      expect(ra, contains('500.000'));
      expect(ra, contains('mỗi tháng'));
      expect(ra, contains('Tiền mặt'),
          reason: 'Ví NGUỒN là thứ bị trừ tiền. Nêu số tiền mà giấu ví là câu '
              'nửa vời — người dùng vẫn phải đi tìm xem tiền ra từ đâu.');
    });

    test('bật nhưng chưa tra được tên ví thì vẫn nói phần biết chắc', () {
      final g = mt(
        trichSoTien: 500000,
        trichVi: 'w-da-xoa',
        trichMoc: DateTime(2026, 9, 1),
      );

      final ra = moTaTrichTuDong(g, tenViNguon: null);
      expect(ra, contains('500.000'),
          reason: 'Ví nguồn có thể đã bị xoá mềm. Trả chuỗi rỗng khi ấy là '
              'giấu luôn việc app đang trừ tiền mỗi kỳ.');
    });

    test('thiếu một mảnh cấu hình thì coi như TẮT', () {
      final g = mt(trichSoTien: 500000, trichVi: 'w-tien-mat', trichMoc: null);
      expect(moTaTrichTuDong(g, tenViNguon: 'Tiền mặt'), 'Đang tắt',
          reason: 'Dùng chung `autoDepositEnabled` — định nghĩa duy nhất của '
              '"đang bật", vốn đòi CẢ BA mảnh. Tự viết lại phép kiểm ở đây là '
              'màn hình nói đang bật trong khi bộ chạy không chạy.');
    });
  });

  group('GoalConfigCard', () {
    Widget dung(GoalEntity g, {String? viTichLuy, String? viNguon}) =>
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalConfigCard(
                goal: g,
                tenViTichLuy: viTichLuy,
                tenViNguonTrich: viNguon,
                now: now,
              ),
            ),
          ),
        );

    testWidgets('hiện đủ bốn dòng', (tester) async {
      await tester.pumpWidget(dung(mt(), viTichLuy: 'Tiết kiệm'));

      expect(find.text('Hạn chót'), findsOneWidget);
      expect(find.text('Tiến độ'), findsOneWidget);
      expect(find.text('Ví tích lũy'), findsOneWidget);
      expect(find.text('Trích tự động'), findsOneWidget);
      expect(find.text('Tiết kiệm'), findsOneWidget);
    });

    testWidgets('chậm tiến độ thì nói ra', (tester) async {
      // Đi 8/12 quãng thời gian mà mới tích 5% → chắc chắn chậm.
      final g = mt(
        target: 2000000,
        current: 100000,
        batDau: DateTime(2026, 1, 1),
        han: DateTime(2026, 10, 1),
      );

      await tester.pumpWidget(dung(g, viTichLuy: 'Tiết kiệm'));
      expect(find.textContaining('Chậm'), findsOneWidget);
    });

    testWidgets('chưa gán ví thì nói chưa gán, không để trống', (tester) async {
      await tester.pumpWidget(dung(mt(), viTichLuy: null));

      expect(find.textContaining('Chưa gán'), findsOneWidget,
          reason: 'Ô trống trông y hệt một lỗi tải dữ liệu. Mục tiêu do bản '
              'app cũ tạo có thể thật sự chưa có ví.');
    });

    testWidgets('không tràn bố cục ở khổ 411dp', (tester) async {
      tester.view.physicalSize = const Size(411 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final g = mt(
        trichSoTien: 12345678,
        trichVi: 'w-tien-mat',
        trichMoc: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(dung(
        g,
        viTichLuy: 'Ví tiết kiệm dài tên để ép xuống hàng',
        viNguon: 'Ví tiền mặt cũng dài không kém',
      ));

      expect(tester.takeException(), isNull,
          reason: 'Tên ví là dữ liệu người dùng nhập, dài bao nhiêu cũng được. '
              'Khổ thật là 411dp chứ không phải 1280px của bộ test.');
    });
  });
}
