/// Màn **Cài đặt AI** — nơi duy nhất người dùng bật/tắt và tải mô hình trên máy.
///
/// Màn này dựng được **không cần DI**: tham số `daCoMoHinh` ép sẵn trạng thái,
/// nên mọi ca dưới đây chạy trọn vẹn trong `flutter test`. Cái `flutter test`
/// **không** thấy là tràn bố cục ở 411dp — ca cuối canh đúng chỗ ấy, và nghiệm
/// thu máy ảo vẫn bắt buộc.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_edge/data/cong_tac_ai.dart';
import 'package:flowmoney/features/ai_edge/presentation/pages/cai_dat_ai_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  // ⚠️ Theme thật, không `MaterialApp` trần: theme của app ép mọi
  // `ElevatedButton` rộng vô hạn, và nút trần trong `Row` làm trắng cả trang
  // mà không một dòng log nào (bẫy 4.11 `ANALYTICS_FEATURE.md`).
  Widget boc(Widget w) => MaterialApp(theme: AppTheme.lightTheme, home: w);

  testWidgets('chưa tải: hiện dung lượng và nút Tải, KHÔNG có nút Xoá',
      (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('2,41 GB'), findsWidgets);
    expect(find.text('Tải mô hình'), findsOneWidget);
    expect(find.text('Xoá mô hình'), findsNothing);
  });

  testWidgets('đã tải: hiện nút Xoá, KHÔNG còn nút Tải', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    expect(find.text('Xoá mô hình'), findsOneWidget);
    expect(find.text('Tải mô hình'), findsNothing);
  });

  testWidgets('⚠️ luôn nói rõ số liệu KHÔNG rời khỏi máy — ở CẢ HAI trạng thái',
      (t) async {
    // Đây là lời hứa trung tâm của cả mảng (F1 đặc tả gốc, Nghị định 13). Người
    // dùng sắp tải 2,41 GB về máy mình — họ cần biết đổi lại được gì.
    //
    // ⚠️ Kế hoạch viết `find.textContaining('không')`; `textContaining` phân
    // biệt hoa thường còn câu bắt đầu bằng "Không", nên vế ấy đỏ trên cả bản
    // đúng. Ca này đòi thẳng **câu hứa**, không đòi một chữ rời.
    for (final co in [false, true]) {
      await t.pumpWidget(boc(CaiDatAiPage(daCoMoHinh: co)));
      expect(find.textContaining('rời khỏi thiết bị'), findsOneWidget,
          reason: 'daCoMoHinh=$co — lời hứa riêng tư không được biến mất ở '
              'trạng thái nào');
      expect(find.textContaining(RegExp('[Kk]hông')), findsWidgets,
          reason: 'daCoMoHinh=$co');
    }
  });

  testWidgets('công tắc "Dùng AI trên máy" có mặt và nói rõ tắt thì sao',
      (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    expect(find.text('Dùng AI trên máy'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Tắt công tắc không làm app mất tính năng — nó lùi về mẫu câu. Không nói
    // ra thì người dùng đọc cái tắt ấy là "mất khối Nhận xét".
    expect(find.textContaining('câu mẫu'), findsOneWidget);
  });

  testWidgets('chưa tải thì nhắc Wi-Fi kèm dung lượng', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('Wi-Fi'), findsOneWidget);
  });

  testWidgets('411dp: không tràn bố cục ở cả hai trạng thái', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    for (final co in [false, true]) {
      await t.pumpWidget(boc(CaiDatAiPage(daCoMoHinh: co)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'daCoMoHinh=$co');
    }
  });

  testWidgets('⚠️ chip trạng thái theo CÔNG TẮC, không chỉ theo tệp',
      (t) async {
    // Đã tải mà công tắc tắt thì chip xanh "Hoạt động" là một lời khẳng định
    // đặt ngay trên chính cái công tắc đang nói ngược lại — và người dùng tin
    // cái chip. Thấy được khi nhìn màn thật, `flutter test` thì không.
    await t.pumpWidget(boc(const CaiDatAiPage(
      daCoMoHinh: true,
      congTac: _CongTacTat(),
    )));
    await t.pumpAndSettle();
    expect(find.text('Đang tắt'), findsOneWidget);
    expect(find.text('Hoạt động'), findsNothing);
  });

  testWidgets('công tắc bật thì chip nói Hoạt động', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    await t.pumpAndSettle();
    expect(find.text('Hoạt động'), findsOneWidget);
  });
}

/// Kho tuỳ chọn giả: luôn tắt. `FlutterSecureStorage` thật ném trong
/// `flutter test` (không có kênh nền tảng) và `CongTacAi` nuốt lỗi rồi trả
/// mặc định **bật** — nên không có lớp này thì nhánh "tắt" không dựng được.
class _CongTacTat extends CongTacAi {
  const _CongTacTat();
  @override
  Future<bool> doc() async => false;
}
