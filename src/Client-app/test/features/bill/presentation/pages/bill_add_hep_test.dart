/// G77 (phần form hoá đơn) — form Thêm hoá đơn ở màn HẸP (Realme để cỡ hiển
/// thị lớn: mật độ 540 → 320 dp).
///
/// Quét 2026-10-07: tiêu đề *"Thêm Hóa Đơn …"* bị cắt (chung hàng với nút
/// *Lưu*); nút *"Tạo Hóa Đơn & Đăng Ký Nhắc Nhở"* trông như bị **xén mép
/// phải** — chữ đã co (`FittedBox`) nhưng nút **không có lề ngang**, nên chữ
/// chạm sát mép bo tròn.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_add_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bloc giữ một trạng thái cố định — cùng lối với `current_account_test.dart`.
class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());
  final AuthState _fixed;
  @override
  AuthState get state => _fixed;
}

class _StubBillRepository implements BillRepository {
  @override
  Stream<List<Bill>> watchBills(int idaccount) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    await napFontThat();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> dung(WidgetTester tester, double rong) async {
    tester.view.physicalSize = Size(rong, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    final bill = BillBloc(repository: _StubBillRepository());
    addTearDown(bill.close);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bill),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const BillAddPage()),
    ));
    await tester.pumpAndSettle();
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G77 · $rong dp: tiêu đề form hiện trọn, không cắt',
        (tester) async {
      await dung(tester, rong);
      expect(tester.takeException(), isNull);
      final o = find
          .descendant(of: find.byType(AppBar), matching: find.byType(Text))
          .first;
      final rp = tester.renderObject<RenderParagraph>(o);
      expect(rp.didExceedMaxLines, isFalse, reason: '$rong dp: tiêu đề bị cắt');
      expect(rp.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(rp.size.width + 0.5),
          reason:
              '$rong dp: tiêu đề "${rp.text.toPlainText()}" không vừa — bị cắt');
    });

    testWidgets('G77 · $rong dp: chữ nút Tạo cách mép nút ít nhất 12 dp',
        (tester) async {
      await dung(tester, rong);
      final chu = find.text('Tạo Hóa Đơn & Đăng Ký Nhắc Nhở');
      final nut = find.ancestor(of: chu, matching: find.byType(InkWell)).first;
      final hopNut = tester.getRect(nut);
      final hopChu = tester.getRect(chu);
      expect(hopChu.left - hopNut.left, greaterThanOrEqualTo(12),
          reason: '$rong dp: biểu tượng/chữ chạm mép trái nút');
      expect(hopNut.right - hopChu.right, greaterThanOrEqualTo(12),
          reason: '$rong dp: chữ chạm sát mép phải bo tròn — trông như bị xén');
    });
  }

  testWidgets('G77 · 411 dp: đủ chỗ thì tiêu đề giữ tên đầy đủ', (tester) async {
    await dung(tester, 411);
    expect(find.text('Thêm Hóa Đơn Định Kỳ'), findsOneWidget,
        reason: 'chỉ rút ngắn khi ĐO thấy không vừa');
  });
}
