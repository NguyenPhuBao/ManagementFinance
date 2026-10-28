/// B1 (spec 2026-10-27 mục 3) — quyền `goal_deposit_withdraw` khoá nút Nạp / Rút ở Chi tiết mục tiêu (lối vào DUY NHẤT
/// của hai phiếu — `goal_detail_page.dart`); tự trích theo `goal_auto_deposit`, không đổi.
library;

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/presentation/widgets/chi_tiet_muc_tieu/nut_duoi_muc_tieu.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/goi_gia.dart';

void main() {
  GoalEntity mt() => GoalEntity(
        id: 'g1',
        idaccount: 7,
        name: 'Mua MacBook Pro',
        targetAmount: 40000000,
        currentAmount: 20000000,
        targetDate: DateTime(2026, 12, 1),
        walletId: 'w1',
        updatedAt: DateTime(2026, 9, 1),
      );

  Future<int> dung(WidgetTester t, {GoiCubit? goi}) async {
    var bam = 0;
    final app = MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: NutDuoiMucTieu(
          goal: mt(),
          onVongMoi: () {},
          onNap: () => bam++,
          onRut: () => bam++,
          onSua: () {},
        ),
      ),
    );
    await t.pumpWidget(goi == null ? app : BlocProvider<GoiCubit>.value(value: goi, child: app));
    await t.pump();
    await t.tap(find.text('Gửi thêm tiết kiệm'));
    await t.tap(find.text('Rút khỏi mục tiêu'));
    await t.pump();
    return bam;
  }

  testWidgets('tiền đề: không GoiCubit → Nạp / Rút bấm được', (t) async {
    expect(await dung(t), 2);
  });

  testWidgets('⭐ goal_deposit_withdraw tắt → Nạp / Rút không bấm được + dòng khoá; Chỉnh sửa vẫn có', (t) async {
    expect(await dung(t, goi: goiBasic(const {'goal_deposit_withdraw': false})), 0);
    expect(find.byKey(const Key('dong-khoa-goal_deposit_withdraw')), findsOneWidget);
    expect(find.text('Chỉnh sửa mục tiêu'), findsOneWidget);
  });
}
