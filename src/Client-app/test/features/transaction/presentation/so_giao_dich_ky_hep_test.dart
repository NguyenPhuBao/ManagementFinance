/// G77 (phần Sổ giao dịch) — ô kỳ ở màn HẸP (Realme để cỡ hiển thị lớn: mật độ
/// 540 → 320 dp).
///
/// Quét 2026-10-07: *"Tháng này (T10 20…"* — **mất năm**. Ô dùng `nhanRong`
/// rồi cắt đuôi bằng ellipsis. Sửa (cùng lối header Phân tích G2): ĐO bề rộng,
/// không vừa thì lùi về `nhanNgan` (*"T10 2026"*) — bỏ chữ *"Tháng này"* chứ
/// không bỏ năm.
///
/// ⚠️ Roboto đậm của bộ test hẹp hơn Inter thật: Realme 320 dp cắt mà font
/// test ở 320 dp còn vừa — ca 320 dp phóng chữ ×1,1 để chừa biên.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../helpers/font_that.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());

  final AuthState _fixed;

  @override
  AuthState get state => _fixed;
}

class _RongRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(
          int idaccount, DateTime from, DateTime to) =>
      Stream.value(const <TransactionEntity>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    await napFontThat();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _RongRepository()),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ Gọi ở CUỐI thân mỗi ca (xem `so_giao_dich_chon_ky_test.dart`).
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester, double rong,
      {double chu = 1.0}) async {
    tester.view.physicalSize = Size(rong, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(chu)),
        child: child!,
      ),
      home: BlocProvider<AuthBloc>.value(
        value: auth,
        child: const TransactionPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  RenderParagraph nhanKy(WidgetTester tester) {
    final o = find.descendant(
      of: find.byKey(const Key('so-giao-dich-chon-ky')),
      matching: find.byType(Text),
    );
    expect(o, findsOneWidget, reason: 'ô kỳ có đúng một dòng chữ');
    return tester.renderObject<RenderParagraph>(o);
  }

  for (final (rong, coChu) in [(320.0, 1.1), (300.0, 1.0)]) {
    testWidgets('G77 · $rong dp ×$coChu: ô kỳ vẽ trọn và GIỮ NĂM',
        (tester) async {
      await moTrang(tester, rong, chu: coChu);
      expect(tester.takeException(), isNull);
      final rp = nhanKy(tester);
      final chu = rp.text.toPlainText();
      expect(rp.didExceedMaxLines, isFalse, reason: '$rong dp: "$chu" bị cắt');
      expect(rp.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(rp.size.width + 0.5),
          reason: '$rong dp: "$chu" không vừa ô — đuôi (năm) bị cắt');
      expect(chu, contains('${DateTime.now().year}'),
          reason:
              'năm là thông tin phải giữ — bỏ "Tháng này" chứ không bỏ năm');
      await dongTrang(tester);
    });
  }

  testWidgets('G77 · 411 dp: đủ chỗ thì vẫn "Tháng này (…)" như cũ',
      (tester) async {
    await moTrang(tester, 411);
    expect(nhanKy(tester).text.toPlainText(), startsWith('Tháng này ('));
    await dongTrang(tester);
  });
}
