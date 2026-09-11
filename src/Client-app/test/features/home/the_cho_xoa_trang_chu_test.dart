/// Thẻ nhắc tài khoản chờ xoá ở Trang chủ — sửa G33 (spec cưỡng chế đăng xuất §5.2).
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/an_the_cho_xoa.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/home/presentation/widgets/the_cho_xoa_trang_chu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements AuthRepository {
  int huyCalls = 0;
  Object? loiHuy;

  @override
  Future<void> cancelDelete() async {
    huyCalls++;
    if (loiHuy != null) throw loiHuy!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ghi lại sự kiện thay vì chạy luồng thật.
class _BlocGhiSuKien extends AuthBloc {
  _BlocGhiSuKien() : super(authRepository: _RepoGia());

  final suKien = <AuthEvent>[];

  @override
  void add(AuthEvent event) => suKien.add(event);
}

UserModel _choXoa({int? countdown = 30}) => UserModel(
      id: '11',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
      status: 'PendingDelete',
      countdown: countdown,
      countdownNhanLuc: countdown == null ? null : DateTime.utc(2026, 9, 11, 3),
    );

void main() {
  late _RepoGia repo;
  late _BlocGhiSuKien bloc;
  late AnTheChoXoa anThe;

  setUp(() {
    repo = _RepoGia();
    bloc = _BlocGhiSuKien();
    anThe = AnTheChoXoa();
  });
  tearDown(() => bloc.close());

  Future<void> dung(WidgetTester tester, UserModel user) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            // Trang chủ đệm ngang 24.
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TheChoXoaTrangChu(
              user: user,
              authRepository: repo,
              anThe: anThe,
              now: () => DateTime.utc(2026, 9, 13, 3),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('có số ngày: "Còn 28 ngày", không tràn ở 411dp', (tester) async {
    await dung(tester, _choXoa());
    expect(find.text('Tài khoản đang chờ xoá'), findsOneWidget);
    expect(find.textContaining('Còn 28 ngày', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('không có số ngày: câu chung', (tester) async {
    await dung(tester, _choXoa(countdown: null));
    expect(
        find.text('Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ.'),
        findsOneWidget);
    expect(find.textContaining('Còn ', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tài khoản Active: không hiện gì', (tester) async {
    await dung(tester,
        UserModel(id: '11', username: 'dat', name: 'Đạt', email: 'dat@example.com'));
    expect(find.byKey(const Key('the-cho-xoa-trang-chu')), findsNothing);
  });

  testWidgets('"Để sau" ẩn thẻ và bật cờ trong bộ nhớ', (tester) async {
    await dung(tester, _choXoa());
    await tester.tap(find.text('Để sau'));
    await tester.pump();
    expect(anThe.value, isTrue);
    expect(find.byKey(const Key('the-cho-xoa-trang-chu')), findsNothing);
  });

  testWidgets('"Huỷ xoá" thành công: gọi huỷ, đọc lại trạng thái, không SnackBar', (tester) async {
    await dung(tester, _choXoa());
    await tester.tap(find.text('Huỷ xoá'));
    await tester.pumpAndSettle();
    expect(repo.huyCalls, 1);
    expect(bloc.suKien.whereType<ThongTinTaiKhoanThayDoi>(), hasLength(1));
    expect(find.byType(SnackBar), findsNothing,
        reason: 'Thẻ biến mất chính là phản hồi (spec §5.2).');
  });

  testWidgets('"Huỷ xoá" lỗi: SnackBar mang lời lỗi, vẫn đọc lại trạng thái', (tester) async {
    repo.loiHuy = Exception('Không có kết nối mạng');
    await dung(tester, _choXoa());
    await tester.tap(find.text('Huỷ xoá'));
    await tester.pumpAndSettle();
    expect(find.text('Không có kết nối mạng'), findsOneWidget);
    expect(bloc.suKien.whereType<ThongTinTaiKhoanThayDoi>(), hasLength(1));
  });
}
