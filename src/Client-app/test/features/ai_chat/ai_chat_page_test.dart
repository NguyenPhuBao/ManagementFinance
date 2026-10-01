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

import 'package:flowmoney/features/ai_chat/data/doc_lenh_bang_ai.dart';
import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
import 'package:flowmoney/features/ai_edge/domain/lenh_tao.dart';
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

  testWidgets('chưa có mô hình: ô nhập MỞ (lệnh tạo C3 không cần mô hình), vẫn có lối tới Cài đặt AI',
      (t) async {
    // Người dùng chốt 2026-09-30 (soát C3 lần hai): trước đó ô nhập khoá khi chưa có mô hình, nên lệnh tạo — chỉ luật —
    // không gõ được trên đúng máy mà spec C3 §1 hứa nó chạy.
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: false)));
    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.enabled, isTrue);
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
        reason: 'Chip là câu HỎI (không phải lệnh tạo) — chưa có mô hình thì không có gì trả lời chúng.');
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

  group('bậc tool (chặng 4b)', () {
    Future<void> hoi(WidgetTester t) async {
      await t.enterText(find.byType(TextField), 'Hoá đơn nào quá hạn?');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pump();
    }

    testWidgets('DangTraCuu đổi dòng chỉ báo theo tool; null trả về "Đang nghĩ…"', (t) async {
      final c = StreamController<SuKienGac>();
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, onHoi: (_) => c.stream)));
      await hoi(t);
      expect(find.text('Đang nghĩ…'), findsOneWidget);

      c.add(const DangTraCuu('danh_sach_hoa_don'));
      await t.pump();
      expect(find.text('Đang tra cứu hoá đơn…'), findsOneWidget,
          reason: '20 giây trên CPU mà dòng chỉ báo vẫn nói "Đang nghĩ" là không nói gì');
      expect(find.text('Đang nghĩ…'), findsNothing);

      c.add(const DangTraCuu(null));
      await t.pump();
      expect(find.text('Đang nghĩ…'), findsOneWidget);

      c.add(const CauQua('Kiem đã quá hạn 45.000 đ.'));
      await c.close();
      await t.pumpAndSettle();
      expect(find.text('Kiem đã quá hạn 45.000 đ.'), findsOneWidget);
    });

    testWidgets('⭐ KhongTraCuu → hỏi lại BẬC 1 với CÙNG câu hỏi, hiện câu của bậc 1', (t) async {
      String? cauBac1;
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.value(const KhongTraCuu()),
        onHoiBac1: (c) {
          cauBac1 = c;
          return Stream.value(const CauQua('Tổng chi 1.200.000 đ.'));
        },
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(cauBac1, 'Hoá đơn nào quá hạn?');
      expect(find.text('Tổng chi 1.200.000 đ.'), findsOneWidget);
      expect(find.textContaining('chưa chắc'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('câu markdown hiện KHÔNG còn dấu `*` (bẫy 4.36)', (t) async {
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.fromIterable(const [
          DangTraCuu('danh_sach_ngan_sach'),
          DangTraCuu(null),
          CauQua('*   Giáo dục: Còn lại 5.000 đ.'),
        ]),
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(find.text('Giáo dục: Còn lại 5.000 đ.'), findsOneWidget);
      expect(find.textContaining('*'), findsNothing);
    });

    testWidgets('KhongTraCuu mà bậc 1 cũng bị chặn → câu lùi "chưa chắc", một lần', (t) async {
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        onHoi: (_) => Stream.value(const KhongTraCuu()),
        onHoiBac1: (_) => Stream.value(const BiChan('Tỉ lệ phân bổ 85,4%.')),
      )));
      await hoi(t);
      await t.pumpAndSettle();
      expect(find.textContaining('chưa chắc'), findsOneWidget);
      expect(find.textContaining('85,4'), findsNothing);
    });

    testWidgets('bước 2: ba tool mới có dòng chỉ báo riêng trên màn', (t) async {
      final c = StreamController<SuKienGac>();
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, onHoi: (_) => c.stream)));
      await hoi(t);
      for (final (ten, chu) in [
        ('danh_sach_muc_tieu', 'Đang tra cứu mục tiêu…'),
        ('goi_y_han_muc', 'Đang tính gợi ý hạn mức…'),
        ('truy_van_giao_dich', 'Đang tra cứu giao dịch…'),
      ]) {
        c.add(DangTraCuu(ten));
        await t.pump();
        expect(find.text(chu), findsOneWidget, reason: ten);
      }
      c.add(const CauQua('Xong.'));
      await c.close();
      await t.pumpAndSettle();
    });
  });

  group('C3 — lệnh tạo trả thẻ mở form, KHÔNG gọi mô hình', () {
    Future<NguonLenhTao> nguon() async => (
          vi: const [(id: 'cash', ten: 'Tiền mặt')],
          danhMucChi: const [(id: 'food', ten: 'Ăn uống')],
        );

    Future<void> go(WidgetTester t, String cau) async {
      await t.enterText(find.byType(TextField), cau);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pumpAndSettle();
    }

    testWidgets('⭐ có mô hình: câu lệnh → thẻ tóm tắt + nút, 0 lần gọi mô hình', (t) async {
      var soLanGoi = 0;
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        onHoi: (_) {
          soLanGoi++;
          return Stream.value(const CauQua('không tới đây'));
        },
      )));
      await go(t, 'tạo hoá đơn Netflix 100k ngày 5 hằng tháng');
      expect(find.textContaining('Mình hiểu là'), findsOneWidget);
      expect(find.textContaining('Netflix'), findsWidgets);
      // Ngày nêu trong câu là NGÀY BẮT ĐẦU (người dùng chốt 2026-10-01). Màn dùng `DateTime.now()` nên chỉ canh phần
      // không phụ thuộc hôm chạy test: ngày 5 có ở mọi tháng, tháng / năm thì đổi.
      expect(find.textContaining('100.000 đ · hằng tháng, bắt đầu 05/'), findsOneWidget);
      expect(find.text('Mở form tạo hoá đơn'), findsOneWidget);
      expect(soLanGoi, 0, reason: 'lệnh chỉ luật — mở phiên mô hình là 15–40 s chờ vô ích');
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue, reason: 'lượt đã xong');
    });

    testWidgets('chưa có mô hình: câu lệnh VẪN ra thẻ', (t) async {
      await t.pumpWidget(boc(AiChatPage(coMoHinh: false, nguonLenhTao: nguon)));
      await go(t, 'đặt ngân sách ăn uống 3 triệu');
      expect(find.text('Mở form đặt ngân sách'), findsOneWidget);
    });

    testWidgets('chưa có mô hình: câu HỎI → câu cố định, 0 lần gọi mô hình', (t) async {
      var soLanGoi = 0;
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: false,
        nguonLenhTao: nguon,
        onHoi: (_) {
          soLanGoi++;
          return const Stream<SuKienGac>.empty();
        },
      )));
      await go(t, 'tháng này tôi chi bao nhiêu');
      expect(find.text(cauKhoaHoiDap(coTep: false)), findsWidgets);
      expect(soLanGoi, 0);
    });

    testWidgets('lệnh nhắc tự trả → dòng "Tự trả phải bật trong form"', (t) async {
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, nguonLenhTao: nguon)));
      await go(t, 'tạo hoá đơn Netflix 100k tự trả');
      expect(find.text('Tự trả phải bật trong form'), findsOneWidget);
    });

    testWidgets('⭐ bấm nút → push đúng đường dẫn form điền sẵn, quay về giữ lịch sử', (t) async {
      String? moi;
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => AiChatPage(coMoHinh: true, nguonLenhTao: nguon)),
        GoRoute(
          path: '/goals/add',
          builder: (_, s) {
            moi = s.uri.toString();
            return const Scaffold(body: Text('form mục tiêu'));
          },
        ),
      ]);
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
      await t.pumpAndSettle();
      await go(t, 'tạo mục tiêu mua xe 50 triệu');
      await t.tap(find.text('Mở form tạo mục tiêu'));
      await t.pumpAndSettle();
      expect(moi, '/goals/add?name=mua+xe&target=50000000');
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('Mở form tạo mục tiêu'), findsOneWidget, reason: 'push, không go — lịch sử chat còn');
    });
  });

  group('C3 §8 — lệnh tạo bằng AI', () {
    Future<NguonLenhTao> nguon() async => (
          vi: const [(id: 'cash', ten: 'Tiền mặt')],
          danhMucChi: const [(id: 'food', ten: 'Ăn uống')],
        );
    Future<void> go(WidgetTester t, String cau) async {
      await t.enterText(find.byType(TextField), cau);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pumpAndSettle();
    }

    /// Gửi mà KHÔNG chờ lắng — lượt đang treo có vòng xoay, `pumpAndSettle` sẽ quá hạn.
    Future<void> goDangCho(WidgetTester t, String cau) async {
      await t.enterText(find.byType(TextField), cau);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pump();
      await t.pump();
    }

    const cauTuNhien = 'tôi muốn để dành 50 triệu mua xe trước hè năm sau';
    const kqAi = KetQuaLenhAi(loai: LoaiLenhTao.mucTieu, ten: 'mua xe', soTien: 50000000, han: '30/06/2027');

    testWidgets('⭐ có mô hình + câu tự nhiên → AI đọc, thẻ "Đọc bằng AI", 0 lần gọi vòng hỏi đáp', (t) async {
      var soLanHoi = 0;
      final doc = _DocLenhGia(kqAi);
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        docLenh: doc,
        onHoi: (_) {
          soLanHoi++;
          return const Stream<SuKienGac>.empty();
        },
      )));
      await go(t, cauTuNhien);
      expect(doc.soLanDoc, 1);
      expect(doc.tenDanhMucNhan, ['Ăn uống'], reason: 'enum của tool là tên danh mục CHI do màn lọc');
      expect(find.textContaining('Tạo mục tiêu'), findsOneWidget);
      expect(find.textContaining('50.000.000 đ · hạn 30/06/2027'), findsOneWidget);
      expect(find.text('Đọc bằng AI'), findsOneWidget);
      expect(find.text('Mở form tạo mục tiêu'), findsOneWidget);
      expect(soLanHoi, 0);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue, reason: 'lượt đã xong');
    });

    testWidgets('có mô hình + AI null + câu theo mẫu → thẻ luật "Đọc bằng luật"', (t) async {
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, nguonLenhTao: nguon, docLenh: _DocLenhGia(null))));
      await go(t, 'tạo hoá đơn gym 300k ngày 5 hằng tháng');
      expect(find.text('Đọc bằng luật'), findsOneWidget);
      expect(find.text('Mở form tạo hoá đơn'), findsOneWidget);
    });

    testWidgets('có mô hình + AI đọc nhưng KHÔNG lấp ô nào (luật đã đủ) → vẫn ghi "Đọc bằng luật"', (t) async {
      const thua = KetQuaLenhAi(loai: LoaiLenhTao.hoaDon, ten: 'gym', soTien: 300000, chuKy: 'thang', ngayGoc: 5);
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, nguonLenhTao: nguon, docLenh: _DocLenhGia(thua))));
      await go(t, 'tạo hoá đơn gym 300k ngày 5 hằng tháng');
      expect(find.text('Đọc bằng luật'), findsOneWidget, reason: 'dòng nguồn nói thứ ĐÃ XẢY RA, không nói thứ đã thử');
    });

    testWidgets('có mô hình + AI null + câu tự nhiên → vòng hỏi đáp như cũ (1 lần gọi)', (t) async {
      var soLanHoi = 0;
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        docLenh: _DocLenhGia(null),
        onHoi: (_) {
          soLanHoi++;
          return Stream.value(const CauQua('Bạn đang tiết kiệm tốt.'));
        },
      )));
      await go(t, cauTuNhien);
      expect(soLanHoi, 1);
      expect(find.byKey(const Key('the-lenh-tao')), findsNothing);
    });

    testWidgets('chưa có mô hình + câu theo mẫu → thẻ luật, KHÔNG gọi AI', (t) async {
      final doc = _DocLenhGia(kqAi);
      await t.pumpWidget(boc(AiChatPage(coMoHinh: false, nguonLenhTao: nguon, docLenh: doc)));
      await go(t, 'đặt ngân sách ăn uống 3 triệu');
      expect(doc.soLanDoc, 0);
      expect(find.text('Đọc bằng luật'), findsOneWidget);
    });

    testWidgets('chưa có mô hình + câu tự nhiên lọt cổng → câu cố định, không thẻ, KHÔNG gọi AI', (t) async {
      final doc = _DocLenhGia(kqAi);
      await t.pumpWidget(boc(AiChatPage(coMoHinh: false, nguonLenhTao: nguon, docLenh: doc)));
      await go(t, cauTuNhien);
      expect(doc.soLanDoc, 0);
      expect(find.text(cauKhoaHoiDap(coTep: false)), findsWidgets);
      expect(find.byKey(const Key('the-lenh-tao')), findsNothing);
    });

    testWidgets('câu không lọt cổng → không gọi AI lệnh, đi vòng hỏi đáp', (t) async {
      var soLanHoi = 0;
      final doc = _DocLenhGia(kqAi);
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        docLenh: doc,
        onHoi: (_) {
          soLanHoi++;
          return Stream.value(const CauQua('Tháng này bạn chi nhiều cho ăn uống.'));
        },
      )));
      await go(t, 'tháng này tôi chi bao nhiêu');
      expect((doc.soLanDoc, soLanHoi), (0, 1));
    });

    testWidgets('⭐ đang đọc: chỉ báo + Huỷ; bấm Huỷ với câu tự nhiên → "Đã huỷ.", KHÔNG đi vòng hỏi đáp', (t) async {
      var soLanHoi = 0;
      final doc = _DocLenhGia(kqAi, treo: true);
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        docLenh: doc,
        onHoi: (_) {
          soLanHoi++;
          return const Stream<SuKienGac>.empty();
        },
      )));
      await goDangCho(t, cauTuNhien);
      expect(find.text(kDangDocLenh), findsOneWidget);
      await t.tap(find.byKey(const Key('huy-doc-lenh')));
      await t.pumpAndSettle();
      expect(doc.soLanHuy, 1);
      expect(find.text(kDaHuyLenh), findsOneWidget);
      expect(find.byKey(const Key('the-lenh-tao')), findsNothing);
      expect(soLanHoi, 0, reason: 'vừa huỷ một lượt chờ mà bị đẩy sang lượt chờ khác là ngược ý người bấm');
      expect(find.byKey(const Key('huy-doc-lenh')), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue, reason: 'lượt đã xong');
    });

    testWidgets('bấm Huỷ với câu theo mẫu → thẻ luật (luật vốn không cần chờ)', (t) async {
      final doc = _DocLenhGia(kqAi, treo: true);
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, nguonLenhTao: nguon, docLenh: doc)));
      await goDangCho(t, 'tạo hoá đơn gym 300k');
      await t.tap(find.byKey(const Key('huy-doc-lenh')));
      await t.pumpAndSettle();
      expect(find.text('Đọc bằng luật'), findsOneWidget);
      expect(find.text('Mở form tạo hoá đơn'), findsOneWidget);
    });

    testWidgets('nút Huỷ CHỈ có ở lượt đọc lệnh — lượt hỏi đáp thường không vẽ nó', (t) async {
      final treo = StreamController<SuKienGac>();
      addTearDown(treo.close);
      await t.pumpWidget(boc(AiChatPage(
        coMoHinh: true,
        nguonLenhTao: nguon,
        docLenh: _DocLenhGia(kqAi),
        onHoi: (_) => treo.stream,
      )));
      await goDangCho(t, 'tháng này tôi chi bao nhiêu');
      expect(find.text('Đang nghĩ…'), findsOneWidget);
      expect(find.byKey(const Key('huy-doc-lenh')), findsNothing);
    });

    testWidgets('thẻ ở khổ 360 dp: không tràn, ô thiếu có dòng riêng', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const thieu = KetQuaLenhAi(loai: LoaiLenhTao.hoaDon, ten: 'tiền điện');
      await t.pumpWidget(boc(AiChatPage(coMoHinh: true, nguonLenhTao: nguon, docLenh: _DocLenhGia(thieu))));
      await go(t, 'nhắc tôi đóng tiền điện hằng tháng');
      expect(t.takeException(), isNull);
      expect(find.text('Đọc bằng AI'), findsOneWidget);
      expect(find.text('Chưa rõ số tiền — bạn điền trong form'), findsOneWidget);
    });
  });
}

/// Bản giả của phiên AI lệnh tạo. [treo]: lượt không tự xong — chỉ `huy()` mới thả, và khi ấy trả `null` như bản thật.
class _DocLenhGia implements DocLenh {
  _DocLenhGia(this.kq, {this.treo = false});
  final KetQuaLenhAi? kq;
  final bool treo;
  int soLanDoc = 0, soLanHuy = 0;
  List<String>? tenDanhMucNhan;
  Completer<void>? _cho;
  bool _daHuy = false;

  @override
  Future<KetQuaLenhAi?> doc(
    String cau, {
    required DateTime now,
    required List<String> tenVi,
    required List<String> tenDanhMuc,
  }) async {
    soLanDoc++;
    tenDanhMucNhan = tenDanhMuc;
    if (treo) await (_cho = Completer<void>()).future;
    return _daHuy ? null : kq;
  }

  @override
  Future<void> huy() async {
    soLanHuy++;
    _daHuy = true;
    if (!(_cho?.isCompleted ?? true)) _cho!.complete();
  }
}
