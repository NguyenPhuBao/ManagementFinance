/// G35 — ba màn quản lý danh mục từng lấy mã tài khoản bằng
/// `int.tryParse(...) ?? 1`.
///
/// `idaccount = 1` là tài khoản **admin THẬT**, không phải giá trị "chưa biết"
/// (quy tắc 2 `CLAUDE.md`). Nên khi phiên đăng nhập chưa cho ra id, ba màn này
/// đọc cây danh mục của admin và ghi danh mục mới dưới danh nghĩa admin — im
/// lặng, không một dòng báo lỗi. Khuôn đúng là khuôn G4
/// (`core/auth/current_account.dart`): chưa có phiên thì không đọc, không ghi,
/// và nói rõ lý do.
///
/// Đường đọc KHÔNG được dùng `?? 0` như trang ví: `idaccount = 0` là bộ khuôn
/// danh mục mặc định toàn cục (quy tắc 8), đọc nó là hiện bộ khuôn ra màn hình.
library;

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_group_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'category_test_fakes.dart';

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

void main() {
  /// Dựng một màn danh mục khi CHƯA đăng nhập và KHÔNG truyền `accountId` —
  /// đúng tình huống mà getter cũ rơi về 1.
  Future<FakeCategoryRepository> dungChuaDangNhap(
    WidgetTester tester,
    Widget Function(FakeCategoryRepository repository) trang,
  ) async {
    final auth = _FixedAuthBloc(AuthInitial());
    addTearDown(auth.close);
    final repository = FakeCategoryRepository();
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp(home: trang(repository)),
    ));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('màn Danh mục không đọc gì khi chưa có phiên đăng nhập',
      (tester) async {
    final repository = await dungChuaDangNhap(
        tester, (r) => CategoryPage(repository: r));

    expect(repository.accountIdsDoc, isEmpty,
        reason: 'Đọc tài khoản 1 là hiện danh mục của admin thật; đọc tài '
            'khoản 0 là hiện bộ khuôn toàn cục. Chưa có phiên thì không đọc.');
    expect(find.textContaining('Chưa xác định được tài khoản đăng nhập'),
        findsOneWidget,
        reason: 'Màn trống mà không nói vì sao thì người dùng tưởng mất hết '
            'danh mục.');
  });

  testWidgets('màn Thêm danh mục không ghi gì khi chưa có phiên đăng nhập',
      (tester) async {
    final repository = await dungChuaDangNhap(
        tester, (r) => CategoryAddPage(repository: r));

    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'e.g. Thuê nhà'),
        'Thuê nhà');
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();

    expect(repository.savedChild, isNull,
        reason: 'Getter cũ ghi danh mục này dưới `idaccount = 1` — tài khoản '
            'admin thật.');
    expect(find.textContaining('Chưa xác định được tài khoản đăng nhập'),
        findsOneWidget);
    expect(repository.accountIdsDoc, isEmpty,
        reason: 'Lượt nạp màn (cây danh mục để chọn nhóm cha) cũng là một '
            'đường đọc.');
  });

  testWidgets('màn Nhóm danh mục không ghi gì khi chưa có phiên đăng nhập',
      (tester) async {
    final repository = await dungChuaDangNhap(
        tester, (r) => CategoryGroupPage(repository: r));

    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'e.g. Chi tiêu Sinh hoạt'),
        'Chi tiêu hàng ngày');
    await tester.tap(find.text('Lưu Nhóm Danh Mục'));
    await tester.pump();

    expect(repository.savedGroup, isNull,
        reason: 'Getter cũ ghi nhóm này dưới `idaccount = 1` — tài khoản admin '
            'thật.');
    expect(find.textContaining('Chưa xác định được tài khoản đăng nhập'),
        findsOneWidget);
    expect(repository.accountIdsDoc, isEmpty,
        reason: 'Lượt nạp danh mục con để gộp vào nhóm cũng là một đường đọc.');
  });
}
