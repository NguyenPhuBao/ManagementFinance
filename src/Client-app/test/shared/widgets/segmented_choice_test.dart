/// Thanh chọn phân đoạn dùng chung cho chu kỳ của hoá đơn, ngân sách, mục tiêu.
///
/// Vì sao cần: ba form từng có ba bộ chọn chu kỳ viết tay, mỗi nơi một kiểu —
/// hoá đơn là thanh ngang, ngân sách là `Wrap` hai ô mỗi hàng, mục tiêu là thanh
/// ngang nhưng không khoá chiều cao. Một widget duy nhất để ba nơi cùng một
/// hình dạng, và để lỗi "ô giãn hết bề ngang rồi xếp dọc" chỉ có một chỗ để
/// tái phát.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/shared/widgets/segmented_choice.dart';

void main() {
  const luaChon = [
    SegmentedOption('Week', 'Hàng tuần'),
    SegmentedOption('Month', 'Hàng tháng'),
    SegmentedOption('Quarter', 'Hàng quý'),
    SegmentedOption('Year', 'Hàng năm'),
    SegmentedOption('Custom', 'Ngày cụ thể'),
  ];

  Future<void> dung(
    WidgetTester tester, {
    required String? selected,
    required ValueChanged<String?> onChanged,
    double width = 411,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedChoice<String?>(
            keyPrefix: 'thu',
            options: luaChon,
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ));
  }

  testWidgets('năm ô nằm trên MỘT hàng ngang, chia đều, không tràn ở 411dp',
      (tester) async {
    await dung(tester, selected: 'Month', onChanged: (_) {});

    final o = luaChon
        .map((e) => tester.getRect(find.byKey(ValueKey('thu-${e.value}'))))
        .toList();

    expect(o.map((r) => r.top).toSet(), hasLength(1),
        reason: 'Các ô phải cùng một hàng và cùng mốc trên. Xếp dọc là lỗi '
            '`Container` có `alignment` mà không có kích thước nên giãn hết '
            'ràng buộc — đã vấp ở form hoá đơn 2026-09-06.');
    expect(o.map((r) => r.height.round()).toSet(), hasLength(1),
        reason: 'Nhãn dài ngắn khác nhau nên phải khoá chiều cao chung, nếu '
            'không các viên thuốc lệch nhau vài pixel.');
    expect(o.map((r) => r.width.round()).toSet(), hasLength(1),
        reason: 'Chia đều bề ngang như một thanh chọn phân đoạn.');
    for (var i = 1; i < o.length; i++) {
      expect(o[i].left, greaterThanOrEqualTo(o[i - 1].right),
          reason: 'Đúng thứ tự khai báo, không chồng nhau.');
    }
    expect(o.last.right, lessThanOrEqualTo(411 - 16),
        reason: 'Không tràn ra ngoài mép phải.');
    expect(tester.takeException(), isNull,
        reason: 'Flutter báo tràn qua reportError chứ không ném ra chỗ gọi.');
  });

  testWidgets('chạm một ô thì gọi onChanged với đúng giá trị', (tester) async {
    String? nhan;
    await dung(tester, selected: 'Month', onChanged: (v) => nhan = v);

    await tester.tap(find.byKey(const ValueKey('thu-Quarter')));
    await tester.pump();

    expect(nhan, 'Quarter');
  });

  testWidgets('nhãn vẫn là Text thật để test cũ tìm theo chữ được',
      (tester) async {
    await dung(tester, selected: 'Month', onChanged: (_) {});

    expect(find.text('Ngày cụ thể'), findsOneWidget,
        reason: 'Bộ test của form ngân sách chạm theo `find.text(...)`. Widget '
            'dùng chung không được đổi sang RichText hay vẽ tay.');
  });

  testWidgets('giá trị null cũng có key riêng', (tester) async {
    const coNull = [
      SegmentedOption<String?>('Month', 'Hàng tháng'),
      SegmentedOption<String?>(null, 'Ngày cụ thể'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SegmentedChoice<String?>(
          keyPrefix: 'ns',
          options: coNull,
          selected: null,
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('ns-null')), findsOneWidget,
        reason: 'Ngân sách dùng `null` cho "Ngày cụ thể". Key phải suy được '
            'từ giá trị null thay vì ném lỗi.');
  });
}
