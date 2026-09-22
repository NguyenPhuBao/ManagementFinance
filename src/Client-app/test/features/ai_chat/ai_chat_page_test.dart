/// Màn **Trợ lý AI** — nơi DUY NHẤT mô hình trên máy phục vụ (lối B, người
/// dùng chốt 2026-09-21). Mọi khối Nhận xét khác giữ mẫu câu.
///
/// Ba tham số `traLoiMau` / `theSoLieuMau` / `onHoi` là **khe tiêm cho test**,
/// mặc định `null` — màn thật đọc từ DI. Không có chúng thì mọi ca dưới đây
/// phải dựng cả chuỗi runtime + bốn gói số, tức một test giao diện hoá ra đi
/// kiểm tầng dữ liệu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  Widget boc(Widget w) => MaterialApp(theme: AppTheme.lightTheme, home: w);

  testWidgets('⚠️ KHÔNG còn số liệu bịa của bản mockup', (t) async {
    // Bản cũ in "35% so với tuần trước (chủ yếu là Cafe & ShopeeFood)" — chữ
    // tĩnh, không đến từ dữ liệu nào. Đó là hứa một tính năng không tồn tại,
    // đúng loại lỗi mà A6 (thẻ "Insight AI") đã phải gỡ.
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: false)));
    expect(find.textContaining('ShopeeFood'), findsNothing);
    expect(find.textContaining('35%'), findsNothing);
    expect(find.textContaining('3.200.000'), findsNothing);
  });

  testWidgets('chưa có mô hình: ô nhập BỊ KHOÁ và có lối tới Cài đặt AI',
      (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: false)));
    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.enabled, isFalse);
    expect(find.textContaining('Cài đặt AI'), findsWidgets);
  });

  testWidgets('có mô hình: ô nhập mở', (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('bốn chip gợi ý đúng tên spec', (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    for (final s in const [
      'Tình hình ngân sách',
      'Phân tích chi tiêu tháng này',
      'Dự báo tiết kiệm',
      'Gợi ý cắt giảm chi phí',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('KHÔNG còn nút ảnh và nút ghi âm', (t) async {
    // Spec mục 4.6: bỏ nút ảnh/mic. Mô hình đa phương thức thật, nhưng app
    // không có việc gì cho ảnh — một nút mở thư viện rồi không làm gì là nút
    // chết có thêm bước.
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('⚠️ câu trả lời hiện KÈM thẻ số liệu', (t) async {
    // Điều kiện 12 và guardrail cuối của đặc tả gốc (mục 3.3): "luôn hiển thị
    // kèm số liệu thô bên cạnh câu văn AI sinh ra — không để người dùng chỉ
    // thấy văn bản mà không thấy nguồn số". Một câu trôi chảy không có thẻ bên
    // cạnh là thứ người ta tin mà không kiểm được.
    await t.pumpWidget(boc(const AiChatPage(
      coMoHinh: true,
      traLoiMau: ['Ngân sách Giáo dục đã dùng 90,0%.'],
      theSoLieuMau: ['Tỉ lệ 90,0%', 'Còn 11 ngày'],
    )));
    await t.pumpAndSettle();
    expect(find.textContaining('90,0%'), findsWidgets);
    expect(find.textContaining('Còn 11 ngày'), findsOneWidget);
  });

  testWidgets('chủ đề bị chặn: trả câu cố định, KHÔNG gọi mô hình', (t) async {
    var soLanGoi = 0;
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: true,
      onHoi: (_) async {
        soLanGoi++;
        return 'không tới đây';
      },
    )));
    await t.enterText(find.byType(TextField), 'Tôi nên đầu tư vào đâu?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(find.textContaining('chỉ nhận xét được trên số liệu'), findsOneWidget);
    expect(soLanGoi, 0,
        reason: 'Chặn TRƯỚC khi gọi mô hình: 2,3 giây cho một câu chắc chắn '
            'bị vứt đi là lãng phí, và mô hình không nên thấy câu hỏi ấy.');
  });

  testWidgets('câu hỏi hợp lệ thì CÓ gọi mô hình và hiện câu trả lời',
      (t) async {
    // Mặt kia của ca trên: một phép chặn chặn sạch mọi thứ cũng làm ca kia
    // xanh, nên phải có ca đòi đường thường vẫn thông.
    var daHoi = '';
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: true,
      onHoi: (c) async {
        daHoi = c;
        return 'Tháng này bạn chi 1.200.000 đ.';
      },
    )));
    await t.enterText(find.byType(TextField), 'Tháng này tôi chi bao nhiêu?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(daHoi, 'Tháng này tôi chi bao nhiêu?');
    expect(find.textContaining('1.200.000'), findsOneWidget);
  });

  testWidgets('chạm chip cũng hỏi, và hỏi đúng chữ trên chip', (t) async {
    var daHoi = '';
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: true,
      onHoi: (c) async {
        daHoi = c;
        return 'xong';
      },
    )));
    await t.tap(find.text('Dự báo tiết kiệm'));
    await t.pumpAndSettle();
    expect(daHoi, 'Dự báo tiết kiệm');
  });

  testWidgets('chưa có mô hình thì chip KHÔNG hỏi gì', (t) async {
    var soLanGoi = 0;
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: false,
      onHoi: (_) async {
        soLanGoi++;
        return '';
      },
    )));
    await t.tap(find.text('Dự báo tiết kiệm'));
    await t.pumpAndSettle();
    expect(soLanGoi, 0,
        reason: 'Ô nhập đã khoá thì chip cũng phải khoá — nếu không thì có một '
            'đường vòng quanh chính cái khoá ấy.');
  });

  testWidgets('411dp không tràn', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
