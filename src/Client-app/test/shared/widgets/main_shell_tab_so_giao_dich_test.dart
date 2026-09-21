/// Thanh dưới mang tab Sổ giao dịch, và `/budget` rời shell — nhóm D,
/// 2026-09-19.
///
/// ## Vì sao KHÔNG có ca dựng router thật rồi chạm vào từng trang
///
/// Đã thử: `AppRouter.createRouter` dựng trang **thật**, và chúng kéo theo cả
/// `GetIt` — `AppDatabase`, `WalletCubit`, `AnalyticsCubit`, `BudgetCubit`…
/// Một ca test phải dựng nửa cái app là ca test giòn, và nó đỏ vì những lý do
/// chẳng liên quan gì tới điều hướng. Khuôn của dự án cho vùng này là
/// `main_shell_back_test.dart`: dựng router **cùng hình dạng** với trang giả.
///
/// Nên phép canh chia làm ba lớp rẻ mà chặt, và lớp thứ tư là máy ảo:
///
/// 1. **Cấu hình** — `nhanhThanhTab` khớp đúng danh sách nhánh khai trong
///    `app_router.dart`. Đây là chỗ quyết định thông báo dùng `go` hay `push`.
/// 2. **Chỗ gọi** — bốn lời gọi điều hướng dùng đúng động từ. Đây là chỗ
///    quyết định app có chết màn đỏ hay không.
/// 3. **Thanh dưới** — nhãn và bề rộng, dựng `MainShell` thật trong một shell
///    cùng hình dạng.
/// 4. Nghiệm thu máy ảo (Task 5 của kế hoạch) — thứ duy nhất chứng minh được
///    app không chết thật.
///
/// ⚠️ `test/features/wallet/xem_giao_dich_cua_vi_test.dart` **không** thay
/// được lớp 2: router giả của nó khai `/transactions` là route **gốc**, nên nó
/// vẫn xanh kể cả khi bản thật đã chuyển route ấy vào shell và app chết màn
/// đỏ. Nó canh đường và query param, không canh an toàn shell.
library;

import 'dart:io';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/notification/notification_deeplink.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flowmoney/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  String doc(String duong) => File(duong).readAsStringSync();

  group('lớp 1 — cấu hình', () {
    test('⚠️ `nhanhThanhTab` khớp ĐÚNG danh sách nhánh khai trong router', () {
      // Hai nơi giữ tay là chỗ trôi lệch kinh điển của dự án. Ca này đọc thẳng
      // tệp router thay vì chép lại danh sách, nên thêm hoặc bớt một nhánh mà
      // quên hằng là đỏ ngay — và sai lệch ở đó làm thông báo chọn nhầm
      // `go`/`push`: một chiều chết màn đỏ, một chiều làm thanh tab biến mất.
      final nguon = doc('lib/core/constants/app_router.dart');
      final dau = nguon.indexOf('StatefulShellRoute.indexedStack');
      final cuoi =
          nguon.indexOf('// Analytics & Report Export standalone routes');
      expect(dau, greaterThan(0), reason: 'Chạy từ src/Client-app.');
      expect(cuoi, greaterThan(dau));

      final duongTrongShell = RegExp(r"path: '(/[a-z-]+)'")
          .allMatches(nguon.substring(dau, cuoi))
          .map((m) => m.group(1)!)
          .toSet();
      expect(duongTrongShell, nhanhThanhTab);
    });

    test('`/budget` khai NGOÀI shell, cạnh hai route con của nó', () {
      final nguon = doc('lib/core/constants/app_router.dart');
      final cuoiShell =
          nguon.indexOf('// Analytics & Report Export standalone routes');
      expect(nguon.indexOf("path: '/budget'"), greaterThan(cuoiShell),
          reason: 'Ngân sách nhường chỗ ở thanh dưới cho Sổ giao dịch. Để nó '
              'trong shell thì `push` từ Trang chủ dựng bản shell thứ hai.');
    });
  });

  group('lớp 2 — chỗ gọi dùng đúng động từ', () {
    test('⚠️ màn Quản lý ví mở sổ bằng `go`, KHÔNG `push`', () {
      final nguon =
          doc('lib/features/wallet/presentation/pages/wallet_list_page.dart');
      expect(nguon.contains("push('/transactions"), isFalse,
          reason: 'Màn Ví nằm NGOÀI shell (drawer push nó), còn '
              '`/transactions` nay nằm TRONG shell. `push` một route trong '
              'shell từ ngoài shell bắt go_router dựng bản shell thứ hai và '
              'Navigator ném `!keyReservation.contains(key)` — app chết màn '
              'đỏ. Đây là quả mìn chính của cả hạng mục.');
      expect("go('/transactions?wallet=".allMatches(nguon).length, 2,
          reason: 'Hai chỗ gọi — thẻ ví thường và thẻ ví đã lưu trữ. Sửa một '
              'chỗ quên chỗ kia là app chỉ chết ở nửa số ví.');
    });

    test('⚠️ trang Sổ giao dịch KHÔNG tự vẽ FAB — shell đã có một cái', () {
      // Máy ảo bắt được ngày 2026-09-19, trong khi 2945 ca test đều xanh:
      // `/transactions` vào shell thì FAB tròn ở giữa thanh dưới luôn hiện
      // trên trang này, mà trang lại có FAB vuông riêng ở góc phải — HAI nút
      // cách nhau chừng 40px làm đúng một việc (`push('/add')`).
      //
      // Gỡ FAB của trang an toàn vì danh sách là **stream**
      // (`watchKhoang`): phép `ChonKyEvent` mà FAB ấy phát sau khi quay lại chỉ
      // đặt lại đúng kỳ đang xem, tức thừa.
      final nguon =
          doc('lib/features/transaction/presentation/pages/transaction_page.dart');
      expect(nguon.contains('floatingActionButton'), isFalse,
          reason: 'Trang này nay là một tab. FAB của shell là nút "thêm giao '
              'dịch" của cả app — vẽ thêm một cái nữa là hai nút giống hệt '
              'nhau trên cùng một màn.');
    });

    test('Trang chủ mở sổ bằng `go` và mở ngân sách bằng `push`', () {
      final nguon =
          doc('lib/features/home/presentation/pages/home_page.dart');
      expect(nguon.contains("go('/transactions')"), isTrue,
          reason: '"Xem tất cả" phải CHUYỂN tab, không chồng trang mới lên '
              'tab Trang chủ.');
      expect(nguon.contains("push('/budget')"), isTrue,
          reason: '`/budget` rời shell nên nó chồng lên Trang chủ và cần nút '
              'Back. `go` ở đây là thay cả stack — thanh tab biến mất.');
      expect(nguon.contains("go('/budget')"), isFalse);
    });
  });

  group('lớp 3 — thanh dưới', () {
    setUp(() => sl.registerSingleton<ThongBaoNhanh>(ThongBaoNhanh()));
    tearDown(() async => sl.reset());

    /// Shell **cùng hình dạng** với bản thật (bốn nhánh) nhưng trang giả —
    /// đúng khuôn `main_shell_back_test.dart`, vì trang thật kéo theo cả DI.
    Future<void> bom(WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => MainShell(navigationShell: shell),
            branches: [
              for (final d in ['/home', '/analytics', '/transactions',
                  '/profile'])
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: d,
                      builder: (_, __) => Scaffold(body: Text('TRANG $d'))),
                ]),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          theme: AppTheme.lightTheme, routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('nhãn thứ tư là "Giao dịch", không còn "Ngân sách"',
        (tester) async {
      await bom(tester);

      expect(find.text('Giao dịch'), findsOneWidget);
      expect(find.text('Ngân sách'), findsNothing,
          reason: 'Ngân sách rời thanh dưới về drawer.');
      for (final n in ['Trang chủ', 'Phân tích', 'Cá nhân']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('⚠️ nhãn mới KHÔNG dài hơn nhãn dài nhất đang chạy được',
        (tester) async {
      await bom(tester);

      // ⚠️ Đây là phép canh ở **tầng thuần**, cố ý không đo pixel — bẫy 4.4:
      // font "Ahem" của bộ test rộng gấp đôi ngoài đời, nên ở 411dp *mọi*
      // nhãn đều ngắt hai dòng, kể cả "Trang chủ" đang chạy tốt trên máy thật
      // (đo được: cao 34px trong test). Bản đầu của ca này đo `size.height`
      // và đỏ ngay ở "Trang chủ" — một phép đo vô nghĩa ở khổ test.
      //
      // Cùng lối mà nhãn quý `Q3 2026` đã dùng: ô nhãn rộng CỐ ĐỊNH 72dp, và
      // ba nhãn 9 ký tự đã chứng minh vừa trên máy thật, nên luật là **không
      // nhãn nào được dài hơn 9 ký tự**. "Sổ giao dịch" là 12 — trượt.
      const daiNhatVuaDuoc = 9; // 'Trang chủ', 'Phân tích', 'Ngân sách'
      for (final n in ['Trang chủ', 'Phân tích', 'Giao dịch', 'Cá nhân']) {
        expect(find.text(n), findsOneWidget);
        expect(n.length, lessThanOrEqualTo(daiNhatVuaDuoc),
            reason: 'Nhãn "$n" dài ${n.length} ký tự. Ô rộng cố định 72dp và '
                'chỉ 9 ký tự đã được chứng minh vừa trên máy 411dp; dài hơn '
                'thì nhãn ngắt hai dòng — IM LẶNG, không sọc vàng, '
                '`takeException()` trả null.');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('chạm tab Giao dịch thì chuyển sang nhánh thứ ba',
        (tester) async {
      await bom(tester);
      expect(find.text('TRANG /home'), findsOneWidget);

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();

      expect(find.text('TRANG /transactions'), findsOneWidget,
          reason: 'Chỉ số UI lệch một để chừa chỗ FAB; mục thứ tư phải trỏ '
              'nhánh 2 chứ không nhánh 3.');
      expect(tester.takeException(), isNull);
    });
  });
}
