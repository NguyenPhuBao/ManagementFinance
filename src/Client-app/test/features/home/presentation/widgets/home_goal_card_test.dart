/// Thẻ mục tiêu tiết kiệm ở trang chủ: một mục tiêu, chọn cái **ưu tiên nhất**.
///
/// Vì sao cần: trước 2026-09-08 mục tiêu chỉ vào được qua **một dòng trong
/// drawer** — một tính năng làm kỹ tới mức có trích tự động, dự báo và cột mốc
/// mà bị chôn ba lớp, trong khi ngân sách thì có hẳn khối trên trang chủ.
///
/// Và trước hôm nay việc này còn vướng một câu hỏi không trả lời được: *hiện
/// mục tiêu nào?* Sắp theo hạn thì cái gấp nhất chưa chắc là cái người dùng
/// quan tâm. Cột `priority` (schema v19) trả lời đúng câu ấy.
///
/// ⚠️ Phép chọn **gọi `chiaMucTieu`**, không tự viết lại thứ tự. Đây là bài học
/// đã ghi hai lần trong dự án (mục 3.6 và 3.18 `GOAL_FEATURE.md`): hai nơi tự
/// tính cùng một thứ là hai bản sao chờ ngày lệch nhau.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/home/presentation/widgets/home_goal_card.dart';

void main() {
  GoalEntity mt({
    required String id,
    double target = 2000000,
    double current = 500000,
    int? uuTien,
    DateTime? han,
    bool xong = false,
    bool daXoa = false,
  }) {
    return GoalEntity(
      id: id,
      idaccount: 7,
      name: id,
      targetAmount: target,
      currentAmount: current,
      targetDate: han ?? DateTime(2027, 1, 1),
      priority: uuTien,
      isCompleted: xong,
      isDeleted: daXoa,
      updatedAt: DateTime(2026, 9, 8),
    );
  }

  group('chonMucTieuTrangChu', () {
    test('chọn mục tiêu có ưu tiên cao nhất, không phải hạn gần nhất', () {
      final chon = chonMucTieuTrangChu([
        mt(id: 'gap', han: DateTime(2026, 10, 1)),
        mt(id: 'quan-trong', han: DateTime(2030, 1, 1), uuTien: 100),
      ]);

      expect(chon?.id, 'quan-trong',
          reason: 'Cả cột `priority` sinh ra để người dùng nói được cái nào '
              'quan trọng hơn. Trang chủ mà vẫn khoe cái gấp nhất là bỏ qua '
              'đúng thứ họ vừa sắp.');
    });

    test('chưa ai sắp thì rơi về hạn gần nhất', () {
      final chon = chonMucTieuTrangChu([
        mt(id: 'xa', han: DateTime(2030, 1, 1)),
        mt(id: 'gan', han: DateTime(2026, 10, 1)),
      ]);

      expect(chon?.id, 'gan',
          reason: 'Quy tắc phụ của `chiaMucTieu`. Không có nó thì tài khoản '
              'chưa từng kéo thả sẽ thấy một mục tiêu tuỳ SQLite trả về.');
    });

    test('bỏ qua mục tiêu đã hoàn thành', () {
      final chon = chonMucTieuTrangChu([
        mt(id: 'xong', target: 1000, current: 1000, uuTien: 100),
        mt(id: 'dang-chay', uuTien: 900),
      ]);

      expect(chon?.id, 'dang-chay',
          reason: 'Trang chủ nói về việc đang làm dở. Một mục tiêu đã đạt nằm '
              'đó chiếm chỗ và không còn thao tác nào để mời.');
    });

    test('bỏ qua mục tiêu đã xoá mềm', () {
      final chon = chonMucTieuTrangChu([
        mt(id: 'da-xoa', uuTien: 100, daXoa: true),
        mt(id: 'con-song', uuTien: 900),
      ]);

      expect(chon?.id, 'con-song');
    });

    test('không có mục tiêu nào đang chạy thì trả null', () {
      expect(chonMucTieuTrangChu(const []), isNull);
      expect(
        chonMucTieuTrangChu([mt(id: 'xong', target: 1000, current: 1000)]),
        isNull,
      );
    });

    test('mục tiêu 0 đồng tính là đã xong nên không được chọn', () {
      expect(chonMucTieuTrangChu([mt(id: 'khong-dong', target: 0)]), isNull,
          reason: '`progress` trả thẳng 1.0 cho mục tiêu 0 đồng (mục 3.6), nên '
              '`daHoanThanh` là true. Trang chủ hiện nó là hiện một thẻ 100% '
              'mà người dùng không hiểu vì sao.');
    });
  });

  group('HomeGoalCard', () {
    Widget dung(List<GoalEntity> goals) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HomeGoalCard(goals: goals)),
          ),
        );

    testWidgets('hiện tên, số tiền và phần trăm của mục tiêu được chọn',
        (tester) async {
      await tester.pumpWidget(dung([
        mt(id: 'MuaXe', target: 2000000, current: 1100000, uuTien: 100),
      ]));

      expect(find.text('MuaXe'), findsOneWidget);
      expect(find.textContaining('55'), findsWidgets,
          reason: '1.100.000 / 2.000.000 = 55%. Con số này phải lấy từ '
              '`GoalEntity.progress` — định nghĩa DUY NHẤT của tỉ lệ (mục 3.6) '
              '— chứ không tự chia lại ở đây.');
    });

    testWidgets('chưa có mục tiêu nào thì mời tạo, không hiện thẻ rỗng',
        (tester) async {
      await tester.pumpWidget(dung(const []));

      expect(find.textContaining('mục tiêu'), findsWidgets);
      expect(find.textContaining('%'), findsNothing,
          reason: 'Không có dữ liệu thì đừng vẽ một thanh tiến độ 0% — nó '
              'trông y như một mục tiêu thật chưa tích được đồng nào.');
    });

    testWidgets('không tràn bố cục ở khổ 411dp', (tester) async {
      tester.view.physicalSize = const Size(411 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(dung([
        mt(
          id: 'Mục tiêu có cái tên rất dài để ép chữ xuống hàng',
          target: 123456789,
          current: 98765432,
          uuTien: 100,
        ),
      ]));

      expect(tester.takeException(), isNull,
          reason: 'Bộ test chạy Chrome 1280px còn điện thoại thật là 411dp. '
              'Flutter báo tràn qua `FlutterError.reportError` chứ KHÔNG ném ra '
              'chỗ gọi, nên một test chỉ `pumpWidget` + `expect(find...)` sẽ '
              'xanh ngay cả khi màn hình đầy sọc vàng.');
    });
  });
}
