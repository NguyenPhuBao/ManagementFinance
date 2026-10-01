/// C1 — thẻ *"Có N giao dịch chưa có danh mục"* trên trang Sổ giao dịch (spec
/// `2026-09-28-c1-gan-danh-muc-hang-loat-design.md` §3, màn Stitch `a829606a…`).
///
/// Số N đếm bằng `demChuaGan` trên **toàn bộ** sổ, không theo kỳ đang xem: thẻ nói về việc dọn sổ. Nguồn là **stream**
/// (`transactionDao.watchAll`), nên thẻ tự đổi sau lần áp dụng, lần pull đồng bộ và lần thêm giao dịch từ nút `+`.
library;

import 'package:drift/drift.dart' show Value;
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
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

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

class _KyRongRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) =>
      Stream.value(const <TransactionEntity>[]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('vi'));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _KyRongRepository()),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ BẮT BUỘC ở cuối MỖI ca, trong thân ca — xem `so_giao_dich_chon_ky_test.dart`.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester, {Stream<int> Function(int idaccount)? nguon}) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = GoRouter(
      initialLocation: '/transactions',
      routes: [
        GoRoute(
          path: '/transactions',
          builder: (_, __) => TransactionPage(nguonChuaGan: nguon),
          routes: [
            GoRoute(
              path: 'gan-danh-muc',
              builder: (_, __) => const Scaffold(body: Text('MÀN GẮN DANH MỤC')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('N > 0 → thẻ nói đúng N và có nút Gắn nhanh', (tester) async {
    await moTrang(tester, nguon: (_) => Stream.value(3));

    expect(find.text('Có 3 giao dịch chưa có danh mục'), findsOneWidget);
    expect(find.text('Gắn nhanh'), findsOneWidget);

    await dongTrang(tester);
  });

  testWidgets('N = 0 → không dựng thẻ', (tester) async {
    await moTrang(tester, nguon: (_) => Stream.value(0));

    expect(find.textContaining('chưa có danh mục'), findsNothing);
    expect(find.text('Gắn nhanh'), findsNothing,
        reason: 'không có gì để gắn thì thẻ là tiếng ồn');
    expect(find.text('Thu nhập'), findsOneWidget,
        reason: 'ĐÒI KẾT QUẢ: trang vẫn dựng đủ — một bản sai làm cả trang trắng cũng làm hai kỳ vọng trên xanh');

    await dongTrang(tester);
  });

  testWidgets('thẻ đổi theo stream — sổ đổi thì số đổi, về 0 thì thẻ biến mất', (tester) async {
    final ctl = StreamController<int>();
    addTearDown(ctl.close);
    await moTrang(tester, nguon: (_) => ctl.stream);

    ctl.add(3);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Có 3 giao dịch chưa có danh mục'), findsOneWidget);

    ctl.add(1);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Có 1 giao dịch chưa có danh mục'), findsOneWidget,
        reason: 'áp dụng xong quay về, hay đồng bộ kéo về thêm khoản trống danh mục — thẻ phải nói số MỚI');

    ctl.add(0);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Gắn nhanh'), findsNothing);

    await dongTrang(tester);
  });

  testWidgets('bấm Gắn nhanh → push màn Gắn danh mục nhanh', (tester) async {
    await moTrang(tester, nguon: (_) => Stream.value(2));

    await tester.tap(find.text('Gắn nhanh'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('MÀN GẮN DANH MỤC'), findsOneWidget);

    await dongTrang(tester);
  });

  testWidgets('nguồn mặc định đếm trên sổ thật, cùng luật demChuaGan, chỉ tài khoản đang đăng nhập', (tester) async {
    await tester.runAsync(() async {
      for (final acc in [7, 99]) {
        await db.walletDao.insert(WalletsCompanion.insert(
          id: 'w-$acc',
          idaccount: acc,
          name: 'Tiền mặt',
          updatedAt: DateTime(2026, 9, 1),
        ));
      }
      Future<void> them(String id, String note, {int acc = 7}) => db.transactionDao.insert(
            TransactionsCompanion.insert(
              id: id,
              walletId: 'w-$acc',
              idaccount: acc,
              amount: 10000,
              type: 'chi',
              note: Value(note),
              date: DateTime(2026, 9, 10),
              updatedAt: DateTime(2026, 9, 10),
            ),
          );
      await them('a', 'grab');
      await them('b', 'com trua');
      await them('c', '$tienToDieuChinh (đối soát)');
      await them('d', 'grab', acc: 99);
    });

    await moTrang(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Có 2 giao dịch chưa có danh mục'), findsOneWidget,
        reason: 'khoản điều chỉnh số dư do máy ghi (loại), khoản của tài khoản 99 không thuộc sổ này');

    await dongTrang(tester);
  });

  testWidgets('360 × 640: thẻ không làm tràn bố cục', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await moTrang(tester, nguon: (_) => Stream.value(12));

    expect(tester.takeException(), isNull);
    expect(find.text('Gắn nhanh'), findsOneWidget);

    await dongTrang(tester);
  });
}
