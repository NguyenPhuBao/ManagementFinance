/// Tab Cá nhân không được vẽ nút hamburger — nó không có drawer để mở.
///
/// Lượt đánh giá UX 2026-09-19 đo trên máy ảo: hamburger ở tab Cá nhân là
/// `onPressed: () {}`, bấm không xảy ra gì, trong khi cùng icon ấy ở Trang chủ
/// thì mở drawer. Một icon, hai hành vi — người dùng học được ở Trang chủ rồi
/// bấm ở đây thì thấy app "đơ".
library;

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/profile/presentation/pages/profile_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> moTrang(WidgetTester tester) async {
    // Bloc ở trạng thái đầu: chưa có tài khoản nên trang không hỏi CSDL.
    final bloc = AuthBloc(authRepository: _RepoGia());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const ProfilePage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('tab Cá nhân không có icon menu chết', (tester) async {
    await moTrang(tester);

    expect(find.byIcon(Icons.menu), findsNothing,
        reason: 'Hamburger ở đây từng là `onPressed: () {}` — nút vẽ như sống '
            'mà bấm không làm gì. Tab này không có drawer, nên không vẽ nút.');
  });

  testWidgets('không còn mục "Giao diện" sáng/tối (A3)', (tester) async {
    await moTrang(tester);

    expect(find.text('Giao diện'), findsNothing,
        reason: 'Mục ấy vẽ một công tắc hai ô sáng/tối trông như đang chọn '
            'được, nhưng `onTap` rỗng và `AppTheme` chỉ có `lightTheme` — '
            'không có `darkTheme` nào để chuyển sang. Người dùng chốt GỠ '
            '(2026-09-19, A3) thay vì làm dark mode.');
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing,
        reason: 'Cả hai ô của công tắc phải đi cùng mục, không để lại icon '
            'mồ côi.');
    // Hai mục còn lại của nhóm CÀI ĐẶT vẫn nguyên.
    expect(find.text('Thông báo'), findsOneWidget);
  });
}
