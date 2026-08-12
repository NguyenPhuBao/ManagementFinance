import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_router.dart';
import 'core/di/injection_container.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// ignore_for_file: avoid_print

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  await setupDependencies();

  // Kiểm tra token trước khi khởi động UI
  // → Có token  = đã đăng nhập → vào /home trực tiếp (offline OK)
  // → Không token = chưa đăng nhập hoặc đã đăng xuất → bắt buộc online login
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: AppConstants.accessTokenKey);
  final hasToken = token != null && token.isNotEmpty;
  final initialRoute = hasToken ? '/home' : '/login';

  // Tạo AuthBloc một lần trước khi runApp để có thể truyền vào GoRouter
  final authBloc = sl<AuthBloc>();

  // Restore auth state từ token đã lưu → GoRouter redirect guard hoạt động đúng ngay từ đầu
  if (hasToken) {
    authBloc.add(AuthCheckRequested());
  }

  runApp(FlowMoneyApp(initialRoute: initialRoute, authBloc: authBloc));
}

class FlowMoneyApp extends StatelessWidget {
  final String initialRoute;
  final AuthBloc authBloc;

  const FlowMoneyApp({
    super.key,
    required this.initialRoute,
    required this.authBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Dùng .value vì instance đã được tạo sẵn trong main()
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp.router(
        title: 'FlowMoney',
        theme: AppTheme.lightTheme,
        // Truyền cả initialRoute lẫn authBloc vào router
        routerConfig: AppRouter.createRouter(initialRoute, authBloc),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
