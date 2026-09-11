/// Thẻ "Vùng nguy hiểm" ở Cài đặt, hai trạng thái — spec cưỡng chế đăng xuất §5.3.
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/profile/presentation/widgets/vung_nguy_hiem_card.dart';
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

class _BlocGhiSuKien extends AuthBloc {
  _BlocGhiSuKien() : super(authRepository: _RepoGia());

  final suKien = <AuthEvent>[];

  @override
  void add(AuthEvent event) => suKien.add(event);
}

UserModel _user({String status = 'Active', int? countdown}) => UserModel(
      id: '11',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
      status: status,
      countdown: countdown,
      countdownNhanLuc: countdown == null ? null : DateTime.utc(2026, 9, 11, 3),
    );

void main() {
  late _RepoGia repo;
  late _BlocGhiSuKien bloc;

  setUp(() {
    repo = _RepoGia();
    bloc = _BlocGhiSuKien();
  });
  tearDown(() => bloc.close());

  Future<void> dung(WidgetTester tester, UserModel? user) async {
    tester.view.physicalSize = const Size(411, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            // Trang Cài đặt đệm ngang 20.
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: VungNguyHiemCard(
              user: user,
              authRepository: repo,
              now: () => DateTime.utc(2026, 9, 13, 3),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('Active: như cũ — nút dẫn vào trang Xoá tài khoản', (tester) async {
    await dung(tester, _user());
    expect(find.text('Yêu cầu xóa tài khoản'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu xoá'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chờ xoá có số: hộp đếm 28 ngày, ngày xoá 11/10/2026, nút huỷ', (tester) async {
    await dung(tester, _user(status: 'PendingDelete', countdown: 30));
    expect(find.byKey(const Key('hop-dem-cho-xoa')), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('ngày còn lại'), findsOneWidget);
    expect(find.text('Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn vào 11/10/2026.'),
        findsOneWidget);
    expect(find.text('Trong thời gian này bạn vẫn dùng app bình thường. Huỷ yêu cầu để giữ lại tài khoản.'),
        findsOneWidget);
    expect(find.text('Huỷ yêu cầu xoá'), findsOneWidget);
    expect(find.text('Yêu cầu xóa tài khoản'), findsNothing,
        reason: 'Đang chờ xoá thì Cài đặt không dẫn vào trang gửi yêu cầu nữa (spec §5.4).');
    expect(tester.takeException(), isNull);
  });

  testWidgets('chờ xoá không số: bỏ hộp đếm, câu chung', (tester) async {
    await dung(tester, _user(status: 'PendingDelete'));
    expect(find.byKey(const Key('hop-dem-cho-xoa')), findsNothing);
    expect(
        find.text('Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ.'),
        findsOneWidget);
    expect(find.text('Huỷ yêu cầu xoá'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Huỷ yêu cầu xoá": gọi huỷ và đọc lại trạng thái; lỗi thì SnackBar', (tester) async {
    await dung(tester, _user(status: 'PendingDelete', countdown: 30));
    await tester.tap(find.text('Huỷ yêu cầu xoá'));
    await tester.pumpAndSettle();
    expect(repo.huyCalls, 1);
    expect(bloc.suKien.whereType<ThongTinTaiKhoanThayDoi>(), hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);

    repo.loiHuy = Exception('Không có kết nối mạng');
    await tester.tap(find.text('Huỷ yêu cầu xoá'));
    await tester.pumpAndSettle();
    expect(find.text('Không có kết nối mạng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
