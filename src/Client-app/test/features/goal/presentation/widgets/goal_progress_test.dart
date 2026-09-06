import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_progress.dart';

/// Canh chừng điều gì: giao diện và bộ luật thông báo phải đọc **cùng một** tỉ
/// lệ tiến độ. Trước đây hai trang mục tiêu tự tính lại bằng công thức riêng và
/// lệch với `GoalEntity.progress` đúng ở mục tiêu 0 đồng — thông báo chúc mừng
/// "đã hoàn thành" trong khi màn hình hiện 0%.
GoalEntity _mucTieu({
  required double target,
  required double current,
}) {
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

Widget _dung(Widget con) => MaterialApp(home: Scaffold(body: Center(child: con)));

void main() {
  group('goalPercentLabel', () {
    test('tỉ lệ thường', () {
      expect(goalPercentLabel(_mucTieu(target: 1000, current: 250)), '25.0%');
    });

    test('mục tiêu 0 đồng hiện 100.0%, KHỚP với GoalEntity.progress', () {
      final g = _mucTieu(target: 0, current: 500);
      expect(goalPercentLabel(g), '100.0%',
          reason: 'GoalEntity.progress trả 1.0 cho mục tiêu 0 đồng, và bộ luật '
              'thông báo bắn "Đã đạt mục tiêu" dựa trên đúng giá trị đó. Nhãn '
              'hiện 0.0% nghĩa là màn hình và thông báo nói hai điều trái '
              'ngược về cùng một mục tiêu.');
      expect(goalPercentLabel(g), '${(g.progress * 100).toStringAsFixed(1)}%',
          reason: 'Nhãn phải suy ra từ chính GoalEntity.progress, không phải '
              'từ một công thức chép lại.');
    });

    test('vượt mục tiêu vẫn kẹp ở 100.0%', () {
      expect(goalPercentLabel(_mucTieu(target: 1000, current: 1500)), '100.0%');
    });
  });

  group('GoalProgressBar', () {
    testWidgets('lấy value thẳng từ GoalEntity.progress', (tester) async {
      final g = _mucTieu(target: 1000, current: 250);
      await tester.pumpWidget(_dung(GoalProgressBar(goal: g)));

      final thanh = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(thanh.value, g.progress);
    });

    testWidgets('mục tiêu 0 đồng vẽ thanh đầy, không phải thanh rỗng',
        (tester) async {
      final g = _mucTieu(target: 0, current: 500);
      await tester.pumpWidget(_dung(GoalProgressBar(goal: g)));

      final thanh = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(thanh.value, 1.0,
          reason: 'Cùng lý do như nhãn phần trăm: thanh rỗng trong khi thông '
              'báo nói đã hoàn thành là mâu thuẫn thấy được bằng mắt.');
    });
  });

  group('GoalProgressRing', () {
    testWidgets('hiện phần trăm của entity', (tester) async {
      await tester
          .pumpWidget(_dung(GoalProgressRing(goal: _mucTieu(target: 1000, current: 250))));
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('mục tiêu 0 đồng hiện 100.0%', (tester) async {
      await tester.pumpWidget(
          _dung(GoalProgressRing(goal: _mucTieu(target: 0, current: 500))));
      expect(find.text('100.0%'), findsOneWidget,
          reason: 'Trang chi tiết từng tự tính lại tỉ lệ và cho ra 0.0% ở '
              'trường hợp này.');
    });
  });
}
