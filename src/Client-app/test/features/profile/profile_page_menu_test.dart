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

  testWidgets('tab Cá nhân bỏ nhóm QUẢN LÝ TÀI KHOẢN (nhóm D)', (tester) async {
    await moTrang(tester);

    expect(find.text('QUẢN LÝ TÀI KHOẢN'), findsNothing,
        reason: 'Bốn mục ấy lặp lại đúng drawer. Lối B cho drawer giữ module, '
            'tab Cá nhân giữ hồ sơ và cài đặt.');
    for (final nhan in [
      'Hóa đơn',
      'Mục tiêu tiết kiệm',
      'Ví',
      'Danh mục tùy chỉnh'
    ]) {
      expect(find.text(nhan), findsNothing, reason: '"$nhan" sống ở drawer.');
    }
  });

  testWidgets('tab Cá nhân mang luôn nội dung trang Cài đặt', (tester) async {
    await moTrang(tester);

    expect(find.text('BẢO MẬT & TÙY CHỌN'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Cài đặt thông báo'), findsOneWidget,
        reason: 'D7: tên cũ "Thông báo" lẫn với trung tâm thông báo, thứ vào '
            'bằng chuông ở Trang chủ — hai chỗ khác hẳn nhau.');
    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('Thông tin và bảo mật'), findsNothing,
        reason: 'Mục ấy chỉ là lối nhảy sang /settings — một trang vẽ ĐÚNG '
            'cái avatar này lần nữa. Nay nội dung nằm ngay đây.');
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
    // Mục còn lại của nhóm CÀI ĐẶT vẫn nguyên. ⚠️ Nhãn là "Cài đặt thông
    // báo" chứ không "Thông báo" từ 2026-09-19 (D7) — tên cũ lẫn với TRUNG
    // TÂM thông báo, thứ vào bằng chuông ở Trang chủ.
    expect(find.text('Cài đặt thông báo'), findsOneWidget);
  });
}
