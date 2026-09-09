/// Khối biểu đồ tiến độ mục tiêu theo thời gian — thêm 2026-09-09.
///
/// ⚠️ Phần **vẽ** không kiểm được ở đây (bẫy 4.9 `docs/ANALYTICS_FEATURE.md`):
/// vị trí tooltip, màu, nét và đường vọt dưới 0 chỉ thấy bằng mắt trên máy ảo.
/// Những gì test này canh là ba thứ *có* hỏng im lặng được: khối có biến mất
/// đúng lúc không, dòng chú thích có nói đúng không, và bố cục có tràn ở 411dp
/// không.
///
/// Khổ máy đặt bằng `tester.view.physicalSize`, **không** bằng `MediaQuery`:
/// bọc `MediaQuery` chỉ đổi con số mà widget đọc được, ràng buộc bố cục vẫn là
/// 800×600 của bộ test — tức test "411dp" chưa bao giờ chạy ở 411dp.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_progress_chart.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 9, 9);

  GoalEntity mt({double current = 20000000, DateTime? batDau}) => GoalEntity(
        id: 'g1',
        idaccount: 7,
        name: 'Mua MacBook Pro',
        targetAmount: 40000000,
        currentAmount: current,
        startDate: batDau,
        targetDate: DateTime(2026, 12, 1),
        walletId: 'w1',
        updatedAt: DateTime(2026, 9, 1),
      );

  final khoanMau = [
    KhoanTichLuy(
      ngay: DateTime(2026, 5, 1),
      soTien: 20000000,
      laKhoanRut: false,
      laTuDong: false,
    ),
  ];

  Future<void> dung(
    WidgetTester t, {
    required GoalEntity goal,
    required List<KhoanTichLuy> khoan,
  }) async {
    t.view.physicalSize = const Size(411 * 3, 900 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        // Theme thật: nó ép mọi `ElevatedButton` rộng vô hạn, và đó là thứ
        // chỉ nổ ở chỗ không chặn bề ngang (bẫy 4.11).
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GoalProgressChart(goal: goal, khoan: khoan, now: now),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('chưa có khoản nào thì khối biến mất hẳn', (t) async {
    await dung(t, goal: mt(batDau: DateTime(2026, 3, 1)), khoan: const []);

    expect(
      find.textContaining('TIẾN ĐỘ THEO THỜI GIAN'),
      findsNothing,
      reason: 'Một thẻ trống mang tiêu đề vẫn chiếm chỗ và vẫn hứa có nội '
          'dung. Mục tiêu vừa tạo thì chưa có gì để vẽ.',
    );
  });

  testWidgets('ở khổ 411dp thì khối không tràn bố cục', (t) async {
    await dung(t, goal: mt(batDau: DateTime(2026, 3, 1)), khoan: khoanMau);

    expect(
      t.takeException(),
      isNull,
      reason: 'Flutter báo tràn qua FlutterError.reportError chứ KHÔNG ném ra '
          'chỗ gọi, nên một test chỉ pumpWidget + find vẫn xanh trong khi màn '
          'hình đầy sọc vàng. Phải hỏi takeException.',
    );
  });

  testWidgets('chậm hơn kế hoạch thì chú thích nói rõ thiếu bao nhiêu tiền',
      (t) async {
    await dung(t, goal: mt(batDau: DateTime(2026, 3, 1)), khoan: khoanMau);

    // 40tr × 192/275 ≈ 27,93tr là mốc kế hoạch hôm nay; đang giữ 20tr.
    expect(
      find.textContaining('Chậm hơn kế hoạch', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('7.927.273', findRichText: true),
      findsOneWidget,
      reason: 'Nói "chậm" mà không nói thiếu bao nhiêu thì người dùng không '
          'biết phải nạp bù bao nhiêu — đúng câu hỏi họ mở trang này để hỏi.',
    );
  });

  testWidgets('trong biên dung sai thì chú thích nói đang bám sát kế hoạch',
      (t) async {
    await dung(
      t,
      goal: mt(current: 28000000, batDau: DateTime(2026, 3, 1)),
      khoan: [
        KhoanTichLuy(
          ngay: DateTime(2026, 5, 1),
          soTien: 28000000,
          laKhoanRut: false,
          laTuDong: false,
        ),
      ],
    );

    expect(
      find.textContaining('bám sát kế hoạch', findRichText: true),
      findsOneWidget,
      reason: 'Cùng biên 5% với thẻ "Cấu hình" ngay bên trên, vốn đang nói '
          '"Đang đúng nhịp". Hai câu ngược nhau trên một trang là lỗi người '
          'dùng đọc ra ngay.',
    );
  });

  testWidgets('không có ngày bắt đầu thì giấu kế hoạch nhưng vẫn vẽ thực tế',
      (t) async {
    await dung(t, goal: mt(batDau: null), khoan: khoanMau);

    expect(
      find.textContaining('TIẾN ĐỘ THEO THỜI GIAN'),
      findsOneWidget,
      reason: 'Đường thực tế là thứ app biết chắc; giấu cả khối là vứt luôn '
          'phần không nghi ngờ gì.',
    );
    expect(
      find.text('Kế hoạch'),
      findsNothing,
      reason: 'Không có mốc bắt đầu thì không có đường kế hoạch, nên một mục '
          'chú giải trỏ vào đường không tồn tại là chỉ vào chỗ trống.',
    );
    expect(
      find.textContaining('kế hoạch', findRichText: true),
      findsNothing,
      reason: 'Dòng chú thích cũng phải im: cùng kỷ luật với isBehindSchedule.',
    );
  });
}
