/// Route mặc định của NỀN TẢNG không được thắng `initialLocation` của app (soát bảo mật, đo Realme 2026-10-24).
///
/// `MainActivity` phải `exported` (launcher), nên mọi app trên máy gửi được intent tường minh kèm extra `route`. Khi
/// khởi động lạnh, Flutter đưa extra ấy thành `PlatformDispatcher.defaultRouteName`, và go_router mặc định lấy nó làm
/// vị trí ban đầu nếu khác `/`. Cờ `flutter_deeplinking_enabled=false` (đợt 2) chỉ tắt deeplink qua *data URI* —
/// đo thật: `am start -n com.flowmoney.flowmoney/.MainActivity --es route /add` vẫn mở form Thêm giao dịch. App không
/// dùng lối ấy (bấm thông báo đi qua payload của plugin, thông báo tóm tắt D1 qua extra riêng), nên router đặt
/// `overridePlatformDefaultLocation: true`.
///
/// Ca đọc vị trí ban đầu của chính `GoRouter` chứ không dựng trang: lớp chặn đăng nhập (`authRedirect`) đẩy mọi route
/// về `/login` khi chưa đăng nhập, nên một ca dựng trang lúc chưa đăng nhập sẽ xanh cả khi lỗi còn đó.
library;

import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthCoDinh extends AuthBloc {
  _AuthCoDinh(this._s) : super(authRepository: _RepoGia());
  final AuthState _s;
  @override
  AuthState get state => _s;
}

String _viTriBanDau(WidgetTester tester, String routeNenTang, String initialLocation) {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = routeNenTang;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  final auth = _AuthCoDinh(AuthSuccess(
    user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
  ));
  addTearDown(auth.close);
  final router = AppRouter.createRouter(initialLocation, auth);
  addTearDown(router.dispose);
  return router.routeInformationProvider.value.uri.toString();
}

void main() {
  testWidgets('extra `route` của app khác (route mặc định nền tảng) KHÔNG mở được form điền sẵn', (tester) async {
    expect(_viTriBanDau(tester, '/add?noi=1', '/home'), '/home',
        reason: 'app lạ gửi `--es route "/add?noi=1"` lúc khởi động lạnh là mở form Thêm giao dịch và bật micro');
  });

  testWidgets('route nền tảng mang đường dẫn bất kỳ cũng không thắng', (tester) async {
    expect(_viTriBanDau(tester, '/premium/don/123', '/login'), '/login');
  });

  testWidgets('đối chứng: mở app bình thường (route nền tảng `/`) vẫn vào initialLocation', (tester) async {
    expect(_viTriBanDau(tester, '/', '/home'), '/home');
  });
}
