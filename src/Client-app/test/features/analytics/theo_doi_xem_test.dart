/// Widget đo giây xem của trang Phân tích — spec 3.1, 5.1.
library;

import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/theo_doi_xem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime gio;
  late List<Map<CumKhoi, int>> ghi;
  late int hienLai;

  setUp(() {
    gio = DateTime(2026, 10, 20, 9);
    ghi = [];
    hienLai = 0;
  });

  Map<CumKhoi, int> tong() {
    final t = <CumKhoi, int>{};
    for (final m in ghi) {
      m.forEach((k, v) => t[k] = (t[k] ?? 0) + v);
    }
    return t;
  }

  Widget trang({bool dangDo = true, bool ticker = true}) => MaterialApp(
        home: TickerMode(
          enabled: ticker,
          child: Scaffold(
            body: TheoDoiXem(
              dangDo: dangDo,
              clock: () => gio,
              onHienLai: () => hienLai++,
              onGhi: (_, g) => ghi.add(g),
              builder: (context, scroll, khoa) => SingleChildScrollView(
                controller: scroll,
                // Bề rộng hết màn như khối thật — SizedBox chỉ có chiều cao thì
                // vùng cuộn rộng 0 px và mọi cú chạm/kéo rơi ra ngoài.
                child: Column(children: [
                  KeyedSubtree(key: khoa(CumKhoi.tong), child: const SizedBox(height: 900, width: double.infinity)),
                  KeyedSubtree(key: khoa(CumKhoi.coCau), child: const SizedBox(height: 900, width: double.infinity)),
                ]),
              ),
            ),
          ),
        ),
      );

  Future<void> troi(WidgetTester tester, int giay) async {
    for (var i = 0; i < giay; i++) {
      gio = gio.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('đứng yên 20 giây ở cụm đầu → ghi ~19 giây cho cụm ấy khi gỡ', (tester) async {
    await tester.pumpWidget(trang());
    await troi(tester, 20);
    await tester.pumpWidget(const SizedBox());
    expect(tong(), {CumKhoi.tong: 19});
  });

  testWidgets('cuộn xuống cụm hai rồi đứng yên → giây sang cụm hai', (tester) async {
    await tester.pumpWidget(trang());
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await troi(tester, 10);
    await tester.pumpWidget(const SizedBox());
    expect(tong()[CumKhoi.coCau], greaterThanOrEqualTo(8));
    expect(tong()[CumKhoi.tong] ?? 0, 0);
  });

  testWidgets('⚠️ TickerMode tắt (tab khác của shell) → không cộng giây nào', (tester) async {
    await tester.pumpWidget(trang(ticker: false));
    await troi(tester, 20);
    await tester.pumpWidget(const SizedBox());
    expect(tong(), isEmpty);
  });

  testWidgets('dangDo = false (kỳ rỗng / đang nạp) → không cộng', (tester) async {
    await tester.pumpWidget(trang(dangDo: false));
    await troi(tester, 20);
    await tester.pumpWidget(const SizedBox());
    expect(tong(), isEmpty);
  });

  testWidgets('tắt rồi bật TickerMode: ghi phần cũ, gọi onHienLai một lần', (tester) async {
    await tester.pumpWidget(trang());
    await troi(tester, 5);
    await tester.pumpWidget(trang(ticker: false));
    expect(tong(), {CumKhoi.tong: 4}, reason: 'rời trang thì ghi ngay');
    expect(hienLai, 0, reason: 'lần hiện đầu không gọi — cubit đã nap lúc tạo');
    await troi(tester, 30);
    await tester.pumpWidget(trang());
    expect(hienLai, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quá 60 giây không chạm thì thôi cộng; chạm thì cộng lại', (tester) async {
    await tester.pumpWidget(trang());
    await troi(tester, 90);
    await tester.tapAt(const Offset(200, 300));
    await troi(tester, 5);
    await tester.pumpWidget(const SizedBox());
    expect(tong(), {CumKhoi.tong: 59 + 5});
  });

  testWidgets('bottom sheet đè lên (route không còn current) → không cộng', (tester) async {
    await tester.pumpWidget(trang());
    await troi(tester, 3);
    final ctx = tester.element(find.byType(SingleChildScrollView));
    showModalBottomSheet<void>(context: ctx, builder: (_) => const SizedBox(height: 200));
    await tester.pumpAndSettle();
    await troi(tester, 20);
    await tester.pumpWidget(const SizedBox());
    // Nhịp 2..3 trước khi sheet mở; 20 giây bị che không cộng gì. (Đếm sau
    // khi gỡ: phần chờ ghi được xả lúc trang bị che, không trước đó.)
    expect(tong(), {CumKhoi.tong: 2}, reason: 'đang bị che');
  });
}
