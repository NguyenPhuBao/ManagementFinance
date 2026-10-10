import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_localization.dart';
import 'core/constants/app_router.dart';
import 'core/di/injection_container.dart';
import 'core/network/connection_monitor.dart';
import 'core/auth/current_account.dart';
import 'core/notification/cham_hdh.dart';
import 'core/notification/nhat_ky_thong_bao.dart';
import 'core/notification/notification_deeplink.dart';
import 'core/notification/app_lifecycle_watcher.dart';
import 'core/notification/kenh_bien_dong.dart';
import 'core/notification/mo_tu_tom_tat_bien_dong.dart';
import 'core/notification/notification_tap_router.dart';
import 'core/notification/os/os_notifier.dart';
import 'core/realtime/realtime_channel.dart';
import 'core/realtime/realtime_wakeup.dart';
import 'core/sync/noi_bo_nghe_ket_qua_day.dart';
import 'core/sync/sync_engine.dart';
import 'core/nen/chay_nen.dart';
import 'core/nen/kenh_tu_chuyen_tien.dart';
import 'core/nen/mui_gio.dart';
import 'core/notification/notification_scanner.dart';
import 'core/ui/thong_bao_nhanh.dart';
import 'features/ai_edge/domain/canary_cong_cu.dart';
import 'features/premium/data/goi_repository.dart';
import 'features/premium/presentation/cubit/goi_cubit.dart';
import 'features/premium/presentation/phien_goi_tu_auth.dart';
import 'shared/widgets/app_toast.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// ignore_for_file: avoid_print

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  await khoiTaoMuiGio();
  await setupDependencies();
  // Bắt đầu theo dõi kết nối ngay: nó đọc trạng thái hiện tại trước để không
  // báo "đã kết nối lại" cho một sự cố chưa từng xảy ra.
  await sl<ConnectionMonitor>().start();

  // Sự kiện thời gian thực đánh thức đồng bộ ngay, thay vì chờ hết chu kỳ 15
  // phút. Đăng ký MỘT lần cho cả vòng đời app: `RealtimeChannel` là singleton
  // và luồng của nó là broadcast, nên nối lại ở mỗi lần đăng nhập chỉ tạo
  // thêm subscription trùng.
  noiRealtimeVaoDongBo(
    events: sl<RealtimeChannel>().events,
    dongBoNgay: () => sl<SyncEngine>().syncNow(),
  );

  // Gỡ khoản trả mà server từ chối (máy khác đã trả hoá đơn ấy trước) và đặt
  // cờ ví trùng tên (G63). Đăng ký MỘT lần cho cả vòng đời app, cùng lý do với
  // khối trên — và engine nền của WorkManager gọi CÙNG hàm này (`chay_nen.dart`).
  noiBoNgheKetQuaDay();

  // Kiểm tra token trước khi khởi động UI
  // → Có token  = đã đăng nhập → vào /home trực tiếp (offline OK)
  // → Không token = chưa đăng nhập hoặc đã đăng xuất → bắt buộc online login
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: AppConstants.accessTokenKey);
  final hasToken = token != null && token.isNotEmpty;
  final initialRoute = hasToken ? '/home' : '/login';

  // Tạo AuthBloc một lần trước khi runApp để có thể truyền vào GoRouter
  final authBloc = sl<AuthBloc>();
  // Nhật ký thông báo (B5a) đọc tài khoản từ ĐÚNG bloc của app — xem chú thích
  // đăng ký `NhatKyThongBao` ở `injection_container.dart`.
  sl<NhatKyThongBao>()
      .datNguonPhien(() => idaccountTuTrangThai(authBloc.state));

  // Premium (spec 2026-10-06 mục 6.4): gói đọc phiên từ ĐÚNG bloc của app
  // (AuthBloc là factory), làm mới khi app quay lại (giãn 5 phút) và khi socket
  // báo `account.upgraded` (tín hiệu, không đọc payload). Nối MỘT lần cho cả
  // vòng đời app, cùng lý do với ba khối trên.
  sl<GoiRepository>()
    ..noiPhien(authBloc.stream.map(phienGoiTu))
    ..noiVongDoi(sl<AppLifecycleWatcher>().stream)
    ..noiSuKien(sl<RealtimeChannel>().events);

  // Tự chuyển tiền chạy nền (spec 2026-10-10 mục 3.2): worker tới giờ mà app
  // đang mở → quét trong CHÍNH engine này (không mở kết nối SQLite thứ hai).
  // Kotlin chờ lời gọi trả về rồi mới kết thúc worker.
  const MethodChannel(kKenhTuChuyenTien).setMethodCallHandler((call) async {
    if (call.method != 'quetNgay') return null;
    final id = idaccountTuTrangThai(authBloc.state);
    if (id == null) return null;
    await sl<NotificationScanner>().scan(id);
    await sl<SyncEngine>().syncNow();
    return null;
  });

  // Restore auth state từ token đã lưu → GoRouter redirect guard hoạt động đúng ngay từ đầu
  if (hasToken) {
    authBloc.add(AuthCheckRequested());
  }

  runApp(FlowMoneyApp(initialRoute: initialRoute, authBloc: authBloc));

  // Canary phiên có tool (bước 1b): xét dấu sót của lần chạy trước NGAY lúc
  // mở app — lúc lịch sử lý do thoát của Android còn nguyên bản ghi của cú sập
  // (nếu có). Không chặn khởi động, không bao giờ ném. Chỉ Android: kênh lý do
  // thoát nằm ở `MainActivity`, và trên web không có tệp cục bộ nào để xét.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    unawaited(sl<CanaryCongCu>().xetDauSot());
  }
}

/// Entrypoint của engine NỀN — `TuChuyenTienWorker.kt` chạy theo tên ([kEntrypointNen]). Phải nằm ở thư viện gốc
/// (`main.dart`) và mang `@pragma` để bản release không bỏ nó (spec tự chuyển tiền chạy nền mục 3.3).
@pragma('vm:entry-point')
Future<void> chayNenTuChuyenTien() => chayNen();

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
  late final MoTuTomTatBienDong _moTomTat;

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
      // Nhật ký B5a: router gọi hook này đúng một lần mỗi cú chạm, sau khi khử
      // trùng và khi đã có phiên — nên NhatKyThongBao tự đọc tài khoản phiên.
      ghiCham: (c) =>
          unawaited(sl<NhatKyThongBao>().ghi(c.payload, suKienTuCham(c))),
    );
    // Nuốt lỗi: một cú chạm không dịch được không được phép chặn khởi động.
    unawaited(_chamThongBao.start().catchError((_) {}));

    // D1: thông báo tóm tắt "Có N biến động số dư mới" do Kotlin bắn — cú chạm
    // không đi qua `NotificationTapRouter`. Đích ở ngoài shell nên `push`.
    _moTomTat = MoTuTomTatBienDong(
      kenh: sl<KenhBienDong>(),
      dieuHuong: (route) => _router.push(route),
      dangDangNhap: () => widget.authBloc.state is AuthSuccess,
      phienDoi: widget.authBloc.stream,
      vongDoi: sl<AppLifecycleWatcher>().stream,
    );
    unawaited(_moTomTat.start().catchError((_) {}));
  }

  @override
  void dispose() {
    unawaited(_chamThongBao.stop());
    unawaited(_moTomTat.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Dùng .value vì instance đã được tạo sẵn trong main()
        BlocProvider<AuthBloc>.value(value: widget.authBloc),
        // Trạng thái gói Premium — singleton của DI, một cho cả app.
        BlocProvider<GoiCubit>.value(value: sl<GoiCubit>()),
      ],
      child: MaterialApp.router(
        title: 'FlowMoney',
        theme: AppTheme.lightTheme,
        // Ba hằng ở `core/constants/app_localization.dart`; thiếu một là hộp
        // chọn ngày lại "Select date" (có test canh).
        locale: kNgonNguApp,
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // Toast bọc NGOÀI router nên phủ mọi trang mà không trang nào phải
        // biết đến nó.
        builder: (context, child) => AppToast(
          connectionEvents: sl<ConnectionMonitor>().events,
          pushResults: sl<SyncEngine>().pushResultStream,
          realtimeEvents: sl<RealtimeChannel>().events,
          thongBaoNhanh: sl<ThongBaoNhanh>().stream,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
