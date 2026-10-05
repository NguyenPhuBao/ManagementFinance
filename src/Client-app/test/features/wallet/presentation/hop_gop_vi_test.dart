/// Hộp xác nhận Gộp (G63, spec mục 5.3; màn Stitch `303d12a1d16340bb8096ab6abc373c69`) — in ĐÚNG các dòng của kế
/// hoạch (bẫy 4).
library;

import 'package:flowmoney/features/wallet/domain/gop_vi.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/hop_gop_vi.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

KeHoachGop khMau() => keHoachGop(
      viBo: const ViChoGop(id: 'r', loai: 'bank', soDu: 1250000, tongSo: 1250000),
      viGiu: const ViChoGop(id: 'p', loai: 'bank', soDu: 3400000, tongSo: 3400000),
      giaoDich: [
        (id: idKhoanMoSo('r'), walletId: 'r', viNhan: null, loai: 'thu', soTien: 1000000),
        (id: 'tx1', walletId: 'r', viNhan: null, loai: 'thu', soTien: 500000),
        (id: 'tx2', walletId: 'r', viNhan: null, loai: 'chi', soTien: 250000),
      ],
      hoaDon: const [],
      mucTieu: const [],
    );

void main() {
  bool? ketQua;

  Future<void> mo(WidgetTester tester, {Size kho = const Size(411, 900)}) async {
    tester.view.physicalSize = kho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    ketQua = null;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => ketQua = await hoiGopVi(ctx, tenVi: 'Ví MB Bank', keHoach: khMau()),
              child: const Text('MO'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('MO'));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ tiêu đề + in đúng mọi dòng của cacDongXacNhanGop', (tester) async {
    await mo(tester);
    expect(find.text('Gộp hai ví "Ví MB Bank"?'), findsOneWidget);
    final dong = cacDongXacNhanGop(khMau());
    for (final d in dong) {
      expect(find.text(d), findsOneWidget, reason: d);
    }
    expect(find.text('•'), findsNWidgets(dong.length));
  });

  testWidgets('dòng "Số dư sau gộp" đậm, dòng "Không hoàn tác được." màu lỗi (Stitch)', (tester) async {
    await mo(tester);
    final soDu = tester.widget<Text>(find.textContaining('Số dư sau gộp'));
    expect(soDu.style?.fontWeight, FontWeight.w700);
    final canhBao = tester.widget<Text>(find.text('Không hoàn tác được.'));
    expect(canhBao.style?.color, AppColors.error);
  });

  testWidgets('Gộp → true; Hủy → false', (tester) async {
    await mo(tester);
    await tester.tap(find.byKey(const ValueKey('nut-xac-nhan-gop')));
    await tester.pumpAndSettle();
    expect(ketQua, isTrue);

    await mo(tester);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(ketQua, isFalse);
  });

  testWidgets('360 × 640 → không tràn', (tester) async {
    await mo(tester, kho: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
