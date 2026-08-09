import 'package:get_it/get_it.dart';

/// Service locator instance — sử dụng `sl<T>()` để resolve dependencies
final GetIt sl = GetIt.instance;

/// Khởi động toàn bộ dependency injection graph.
/// Gọi một lần trong `main()` trước khi `runApp()`.
Future<void> setupDependencies() async {
  // -------------------------------------------------------
  // Core — sẽ đăng ký ở đây khi các lớp được tạo ra
  // -------------------------------------------------------

  // Ví dụ cấu trúc (uncomment khi có implementation):
  //
  // --- Database ---
  // sl.registerSingletonAsync<AppDatabase>(() async {
  //   final db = AppDatabase();
  //   return db;
  // });
  //
  // --- HTTP Client ---
  // sl.registerLazySingleton<Dio>(() {
  //   final dio = Dio(BaseOptions(
  //     baseUrl: AppConstants.baseUrl,
  //     connectTimeout: AppConstants.connectionTimeout,
  //     receiveTimeout: AppConstants.receiveTimeout,
  //   ));
  //   dio.interceptors.add(AuthInterceptor(sl<FlutterSecureStorage>()));
  //   return dio;
  // });
  //
  // --- Repositories ---
  // sl.registerLazySingleton<AuthRepository>(
  //   () => AuthRepositoryImpl(sl(), sl()),
  // );
  //
  // --- BLoCs / Cubits ---
  // sl.registerFactory<AuthBloc>(() => AuthBloc(sl()));

  // Đảm bảo tất cả singleton async đã sẵn sàng
  await sl.allReady();
}
