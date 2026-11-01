import 'package:flowmoney/features/household/presentation/widgets/avatar_chu_cai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mauAvatarTheoId: cùng id cùng màu (một hàm thuần), chữ luôn khác nền', () {
    for (var id = 0; id < 40; id++) {
      final a = mauAvatarTheoId(id);
      expect(mauAvatarTheoId(id), a, reason: 'id $id');
      expect(a.chu, isNot(a.nen), reason: 'quét 13: chữ cùng màu nền là vòng tròn trống');
    }
  });

  test('mauAvatarTheoId: id khác nhau cho nhiều hơn một màu; id null → màu trung tính cố định', () {
    expect({for (var id = 1; id <= 12; id++) mauAvatarTheoId(id).nen}.length, greaterThan(3));
    expect(mauAvatarTheoId(null), mauAvatarTheoId(null));
    expect(mauAvatarTheoId(-7), mauAvatarTheoId(-7), reason: 'id âm không được ném (RangeError)');
  });

  testWidgets('AvatarChuCai: chữ cái đầu viết hoa, nền theo idaccount, tên trống → "?"', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: Column(children: [
      AvatarChuCai(ten: 'đạt', idaccount: 5),
      AvatarChuCai(ten: '  ', idaccount: 6),
    ]))));
    expect(find.text('Đ'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    final nen = ((t.widget<Container>(find.descendant(of: find.byType(AvatarChuCai).first, matching: find.byType(Container))))
            .decoration! as BoxDecoration)
        .color;
    expect(nen, mauAvatarTheoId(5).nen);
  });
}
