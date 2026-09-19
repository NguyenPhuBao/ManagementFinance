/// Ba thẻ Thu nhập / Chi tiêu / Thu net ở Trang chủ phải hiện ĐỦ con số.
///
/// Lượt đánh giá UX 2026-09-19 đo trên máy ảo 411dp với dữ liệu thật: ba thẻ
/// hiện "14.635.0…", "1.045.00…", "+13.590…" — `TextOverflow.ellipsis` cắt
/// đúng con số chính của trang ngay từ 8 chữ số. Chưa test nào bắt được vì
/// `find.text` so `data` chứ không so thứ vẽ ra (bẫy 4.4 `ANALYTICS_FEATURE.md`);
/// ở đây đo `RenderParagraph.didExceedMaxLines`, tức thứ **thật sự bị cắt**.
///
/// Cùng lượt, con số đi qua `CurrencyFormatter.format` ("14.635.000 đ") thay
/// vì nối `'đ'` tay như bản cũ — Trang chủ từng là chỗ duy nhất viết "13.590.000đ"
/// không cách trong khi mọi màn khác viết có cách.
library;

import 'package:flowmoney/core/utils/currency_formatter.dart';
import 'package:flowmoney/features/home/presentation/widgets/the_so_lieu_thang.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Khổ máy thật: 411dp trừ 24dp lề mỗi bên của Trang chủ.
  const rongThan = 411.0 - 48;

  Future<void> bom(WidgetTester tester, {required double thu, required double chi}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: rongThan,
            child: TheSoLieuThang(thu: thu, chi: chi),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  bool biCat(WidgetTester tester, String chu) {
    final rp = tester.renderObject<RenderParagraph>(find.text(chu));
    return rp.didExceedMaxLines;
  }

  testWidgets('số 8 chữ số không bị cắt "…" ở 411dp', (tester) async {
    await bom(tester, thu: 14635000, chi: 1045000);

    final thu = CurrencyFormatter.format(14635000);
    expect(find.text(thu), findsOneWidget,
        reason: 'Con số phải đi qua CurrencyFormatter — "14.635.000 đ".');
    expect(biCat(tester, thu), isFalse,
        reason: 'Máy ảo hiện "14.635.0…": con số chính của Trang chủ không '
            'đọc được. `find.text` không bắt được, phải đo RenderParagraph.');
    expect(biCat(tester, CurrencyFormatter.format(1045000)), isFalse);
    expect(biCat(tester, CurrencyFormatter.formatCoDau(13590000, thu: true)),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('số 13 chữ số (trần của numeric(15,2)) vẫn không cắt, không tràn',
      (tester) async {
    await bom(tester, thu: 9999999999999, chi: 0);

    expect(biCat(tester, CurrencyFormatter.format(9999999999999)), isFalse,
        reason: 'Trần G45/G46 biến con số này thành hợp lệ đạt tới được; mỗi '
            'lần đặt trần phải thử bố cục với giá trị lớn nhất.');
    expect(tester.takeException(), isNull, reason: 'Không sọc vàng tràn.');
  });

  testWidgets('thu net âm mang dấu trừ, thu net 0 không mang dấu', (tester) async {
    await bom(tester, thu: 100000, chi: 300000);
    expect(find.text(CurrencyFormatter.formatCoDau(200000, thu: false)),
        findsOneWidget);

    await bom(tester, thu: 0, chi: 0);
    expect(find.text(CurrencyFormatter.format(0)), findsNWidgets(3),
        reason: 'Số 0 không mang dấu (`formatCoDau`), ba thẻ cùng "0 đ".');
  });
}
