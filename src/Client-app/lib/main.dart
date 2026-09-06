import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'core/constants/app_constants.dart';
import 'core/constants/app_router.dart';
import 'core/di/injection_container.dart';
import 'core/network/connection_monitor.dart';
import 'core/notification/notification_deeplink.dart';
import 'core/notification/notification_tap_router.dart';
import 'core/notification/os/os_notifier.dart';
import 'core/sync/sync_engine.dart';
import 'shared/widgets/connection_banner.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// ignore_for_file: avoid_print

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  await _khoiTaoMuiGio();
  await setupDependencies();
  // Bắt đầu theo dõi kết nối ngay: nó đọc trạng thái hiện tại trước để không
  // báo "đã kết nối lại" cho một sự cố chưa từng xảy ra.
  await sl<ConnectionMonitor>().start();

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

/// Nạp bảng múi giờ và đặt múi giờ địa phương.
///
/// **Phải chạy TRƯỚC `setupDependencies()`** vì `ReminderScheduler` dựng
/// `TZDateTime` ngay khi đặt lịch. Thiếu bước này thì `zonedSchedule` neo vào
/// UTC và nhắc hoá đơn lệch 7 tiếng ở Việt Nam — **không có lỗi nào báo ra**
/// (bẫy 7.3 của `docs/NOTIFICATION_FEATURE.md`).
///
/// Nuốt lỗi và lùi về UTC: không đọc được múi giờ của máy thì nhắc sai giờ,
/// còn ném ở đây thì app không khởi động được. Hỏng nhẹ hơn hẳn.
Future<void> _khoiTaoMuiGio() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    // Giữ nguyên mặc định của gói (UTC).
  }
}

/// ⚠️ **StatefulWidget có lý do**, đừng đổi ngược lại.
///
/// `AppRouter.createRouter()` trước đây được gọi ngay trong `build()`, tức là
/// mỗi lần widget gốc dựng lại là một `GoRouter` hoàn toàn mới — mất cả stack
/// điều hướng. Nay nó được tạo **một lần** trong `initState`, và nhờ giữ được
/// tham chiếu ấy mà `NotificationTapRouter` điều hướng được từ ngoài cây
/// widget: cú chạm vào thông báo cấp hệ điều hành đến từ nền tảng, không có
/// `BuildContext` nào cả.
class FlowMoneyApp extends StatefulWidget {
  final String initialRoute;
  final AuthBloc authBloc;

  const FlowMoneyApp({
    super.key,
    required this.initialRoute,
    required this.authBloc,
  });

  @override
  State<FlowMoneyApp> createState() => _FlowMoneyAppState();
}

class _FlowMoneyAppState extends State<FlowMoneyApp> {
  late final GoRouter _router;
  late final NotificationTapRouter _chamThongBao;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.initialRoute, widget.authBloc);

    _chamThongBao = NotificationTapRouter(
      osNotifier: sl<OsNotifier>(),
      // `go` hay `push` là quyết định bắt buộc, không phải thẩm mĩ: `push` một
      // route nằm trong StatefulShellRoute khi đang ở ngoài shell làm app chết
      // màn đỏ (bẫy 7.8 của docs/NOTIFICATION_FEATURE.md).
      dieuHuong: (route) =>
          thuocThanhTab(route) ? _router.go(route) : _router.push(route),
      dangDangNhap: () => widget.authBloc.state is AuthSuccess,
      phienDoi: widget.authBloc.stream,
    );
    // Nuốt lỗi: một cú chạm không dịch được không được phép chặn khởi động.
    unawaited(_chamThongBao.start().catchError((_) {}));
  }

  @override
  void dispose() {
    unawaited(_chamThongBao.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Dùng .value vì instance đã được tạo sẵn trong main()
        BlocProvider<AuthBloc>.value(value: widget.authBloc),
      ],
      child: MaterialApp.router(
        title: 'FlowMoney',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // Dải báo kết nối bọc NGOÀI router nên phủ mọi trang mà không trang
        // nào phải biết đến nó.
        builder: (context, child) => ConnectionBanner(
          connectionEvents: sl<ConnectionMonitor>().events,
          pushResults: sl<SyncEngine>().pushResultStream,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
