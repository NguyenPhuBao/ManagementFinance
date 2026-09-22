/// Màn **Trợ lý AI** — nơi DUY NHẤT mô hình trên máy phục vụ (lối B, người
/// dùng chốt 2026-09-21). Mọi khối Nhận xét khác giữ mẫu câu.
///
/// Ba tham số `traLoiMau` / `theSoLieuMau` / `onHoi` là **khe tiêm cho test**,
/// mặc định `null` — màn thật đọc từ DI. Không có chúng thì mọi ca dưới đây
/// phải dựng cả chuỗi runtime + bốn gói số, tức một test giao diện hoá ra đi
/// kiểm tầng dữ liệu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
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
      'Chi tiêu tháng này',
      'Tình hình ngân sách',
      'Tiến độ mục tiêu',
      'Hoá đơn sắp tới',
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
      onHoi: (_) {
        soLanGoi++;
        return Stream.value(const CauQua('không tới đây'));
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
      onHoi: (c) {
        daHoi = c;
        return Stream.value(const CauQua('Tháng này bạn chi 1.200.000 đ.'));
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
      onHoi: (c) {
        daHoi = c;
        return Stream.value(const CauQua('xong'));
      },
    )));
    await t.tap(find.text('Tiến độ mục tiêu'));
    await t.pumpAndSettle();
    expect(daHoi, 'Tiến độ mục tiêu');
  });

  testWidgets('chưa có mô hình thì chip KHÔNG hỏi gì', (t) async {
    var soLanGoi = 0;
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: false,
      onHoi: (_) {
        soLanGoi++;
        return const Stream<SuKienGac>.empty();
      },
    )));
    await t.tap(find.text('Tiến độ mục tiêu'));
    await t.pumpAndSettle();
    expect(soLanGoi, 0,
        reason: 'Ô nhập đã khoá thì chip cũng phải khoá — nếu không thì có một '
            'đường vòng quanh chính cái khoá ấy.');
  });

  group('streaming CHẶN THEO CÂU (việc số 1, người dùng chốt 2026-09-22)', () {
    // Điểm 2 cổng A đòi chữ hiện dần; `kiemSo` chỉ chạy trên câu đầy đủ. Lối
    // chọn: mỗi câu qua kiểm thì hiện ngay, câu trượt thì không bao giờ hiện.
    // Gác theo câu đã có test riêng (`gac_cau_test`); ở đây canh màn phản ứng
    // đúng với từng sự kiện.
    Future<void> hoi(WidgetTester t) async {
      await t.enterText(find.byType(TextField), 'Tháng này sao?');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pump();
    }

    testWidgets('câu qua kiểm hiện NGAY, khi luồng còn mở', (t) async {
      final c = StreamController<SuKienGac>();
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => c.stream,
      )));
      await hoi(t);

      c.add(const CauQua('Tổng chi 1.200.000 đ.'));
      await t.pump();
      expect(find.textContaining('1.200.000'), findsOneWidget,
          reason: 'Câu đầu phải hiện trong khi mô hình còn viết — đó mới là '
              '"chữ hiện dần", không phải bật ra nguyên khối lúc xong.');

      c.add(const CauQua('Để dành 86,7%.'));
      await t.pump();
      expect(find.text('Tổng chi 1.200.000 đ. Để dành 86,7%.'), findsOneWidget);

      await c.close();
      await t.pumpAndSettle();
      expect(find.text('Tổng chi 1.200.000 đ. Để dành 86,7%.'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue,
          reason: 'luồng đóng thì hỏi tiếp được');
    });

    testWidgets('bị chặn khi CHƯA câu nào hiện → câu lùi, không lộ câu hỏng',
        (t) async {
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.value(const BiChan('Tỉ lệ phân bổ 85,4%.')),
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(find.textContaining('85,4'), findsNothing,
          reason: 'câu trượt bộ kiểm không được hiện dưới bất kỳ dạng nào');
      expect(find.textContaining('chưa chắc'), findsOneWidget);
    });

    testWidgets('bị chặn SAU một câu → giữ câu ấy, không câu lùi, không câu hỏng',
        (t) async {
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.fromIterable(const [
          CauQua('Tổng chi 2.141.000 đ.'),
          BiChan('Tỉ lệ phân bổ 85,4%.'),
        ]),
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(find.text('Tổng chi 2.141.000 đ.'), findsOneWidget,
          reason: 'câu đã qua kiểm là câu đúng — thay nó bằng câu lùi là vứt '
              'một câu trả lời đúng vì một câu sau nó');
      expect(find.textContaining('85,4'), findsNothing);
      expect(find.textContaining('chưa chắc'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('luồng lỗi giữa chừng → câu "không chạy được", ô nhập mở lại',
        (t) async {
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.error(Exception('engine chết')),
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(find.textContaining('không chạy được'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });
  });

  testWidgets('411dp không tràn', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  group('Vì sao ô nhập bị khoá — hai lý do, hai câu', () {
    // ⚠️ Lỗi này chỉ lộ khi nhìn màn thật: băng nhắc nói "Chưa có mô hình trên
    // máy" cho CẢ trường hợp người dùng đã tải xong 2,41 GB rồi tự tắt công
    // tắc — họ sẽ đi tải lại một thứ đang nằm sẵn trong máy. `flutter test`
    // mù với nó vì widget test chỉ dựng được một nhánh.
    test('chưa có tệp → nói chưa tải', () {
      expect(cauKhoaHoiDap(coTep: false), kChuaCoMoHinh);
      expect(cauKhoaHoiDap(coTep: false), contains('tải'));
    });

    test('có tệp mà vẫn khoá → nói công tắc đang tắt, KHÔNG rủ tải lại', () {
      expect(cauKhoaHoiDap(coTep: true), kCongTacDangTat);
      expect(cauKhoaHoiDap(coTep: true), isNot(contains('2,41 GB')),
          reason: 'Rủ tải lại một tệp đã có là đẩy người dùng đi mất 2,41 GB '
              'cho đúng thứ họ đang có sẵn.');
    });
  });

  testWidgets('⚠️ quay lại từ Cài đặt AI thì ĐỌC LẠI trạng thái', (t) async {
    // Đo được trên máy ảo 2026-09-22: tắt công tắc ở màn Cài đặt AI rồi quay
    // về, chip vẫn xanh và ô nhập vẫn mở — vì `initState` chỉ chạy một lần còn
    // `pop` thì không dựng lại State. Người dùng chỉ biết khi bấm vào và không
    // có gì xảy ra. Cùng họ với G48.
    //
    // Phải dựng `GoRouter` THẬT: `push` rồi `pop` là chính thứ cần tái hiện,
    // và `MaterialApp` trần không có `context.push`.
    var soLanDo = 0;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => AiChatPage(
          doTrangThai: () async {
            soLanDo++;
            return (true, true);
          },
        ),
      ),
      GoRoute(
        path: '/ai-settings',
        builder: (_, __) => const Scaffold(body: Text('màn cài đặt')),
      ),
    ]);
    addTearDown(router.dispose);

    await t.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await t.pumpAndSettle();
    expect(soLanDo, 1, reason: 'Lần đầu dựng thì phải đọc một lần.');

    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    expect(find.text('màn cài đặt'), findsOneWidget,
        reason: 'Nút bánh răng là lối vào DUY NHẤT của /ai-settings.');

    router.pop();
    await t.pumpAndSettle();
    expect(soLanDo, 2,
        reason: 'Quay về mà không đọc lại thì màn này nói một đằng còn công '
            'tắc ở màn kia đã một nẻo.');
  });

  // Nghiệm thu máy thật 2026-09-22 (P3 Task 9): mở app trong điều kiện backend
  // không tới được rồi hỏi ngay → màn trả lời *"Mô hình trên máy không chạy
  // được lúc này"*. Mô hình **hoàn toàn bình thường** — chờ 45 giây rồi hỏi
  // lại cùng câu ấy thì nó nạp trong 4.103 ms và trả lời. Thứ thiếu là
  // `AuthBloc` chưa kịp vào `AuthSuccess`, vì `verifySession()` là lời gọi
  // MẠNG và phải đợi hết timeout 30 s trước khi giữ lại phiên cũ.
  //
  // ⚠️ Ca dưới đây canh **hằng câu**, không dựng cả `AuthBloc` — nhánh ấy nằm
  // sau `context.read<AuthBloc>()` nên muốn chạm tới phải dựng đủ chuỗi phụ
  // thuộc của bloc, tức một test giao diện hoá ra đi kiểm tầng xác thực. Cái
  // sai thật sự là **hai nguyên nhân khác hẳn nhau dùng chung một câu**, và
  // chừng đó thì kiểm được thẳng.
  group('câu "phiên chưa sẵn sàng" tách khỏi câu "mô hình hỏng"', () {
    test('không đổ lỗi cho mô hình', () {
      expect(kChuaSanSangPhien.toLowerCase(), isNot(contains('mô hình')),
          reason: 'Mô hình vẫn chạy tốt; nói nó hỏng là chỉ sai hướng hẳn — '
              'người dùng sẽ đi tải lại 2,41 GB cho một việc chỉ cần đợi.');
    });

    test('nói đúng việc cần làm: đợi rồi hỏi lại', () {
      final c = kChuaSanSangPhien.toLowerCase();
      expect(c, contains('phiên'));
      expect(c.contains('đợi') || c.contains('chờ'), isTrue,
          reason: 'Trạng thái này tự hết sau vài giây — câu phải nói ra điều '
              'đó, kẻo người dùng tưởng hỏng vĩnh viễn.');
    });
  });
}
