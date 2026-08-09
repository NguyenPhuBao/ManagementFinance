import 'package:get_it/get_it.dart';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../core/constants/app_constants.dart';

/// Service locator instance — sử dụng `sl<T>()` để resolve dependencies
final GetIt sl = GetIt.instance;

/// Khởi động toàn bộ dependency injection graph.
/// Gọi một lần trong `main()` trước khi `runApp()`.
Future<void> setupDependencies() async {
  // -------------------------------------------------------
  // Ext packages
  // -------------------------------------------------------
  const secureStorage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectionTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
  ));
  sl.registerLazySingleton<Dio>(() => dio);

  // -------------------------------------------------------
  // Features - Auth
  // -------------------------------------------------------
  
  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // BLoC
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl()),
  );

  // Đảm bảo tất cả singleton async đã sẵn sàng
  await sl.allReady();
}
