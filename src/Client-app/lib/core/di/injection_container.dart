import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/dio_client.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/wallet/data/datasources/wallet_local_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/presentation/bloc/wallet_cubit.dart';

/// Service locator — dùng `sl<T>()` để resolve dependencies
final GetIt sl = GetIt.instance;

/// Khởi động toàn bộ dependency injection graph.
/// Gọi một lần trong `main()` trước khi `runApp()`.
Future<void> setupDependencies() async {
  // ── 1. External packages ──────────────────────────────────────────────────
  const secureStorage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // ── 2. Core: AppDatabase (Drift SQLite) ───────────────────────────────────
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // ── 3. Core: DioClient ─────────────────────────────────────────────────────
  sl.registerLazySingleton<DioClient>(() => DioClient(secureStorage: sl()));

  // ── 4. Core: SyncEngine (offline-first sync) ────────────────────────────
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(dioClient: sl(), db: sl()),
  );

  // ── 3. Features — Auth ────────────────────────────────────────────────────

  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl<DioClient>().dio),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource:  sl(),
      secureStorage:    sl(),
    ),
  );

  // BLoC (factory → tạo mới mỗi lần gọi sl<AuthBloc>())
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl()),
  );

  // ── 5. Features — Wallet ──────────────────────────────────────────────────
  sl.registerLazySingleton<WalletLocalDataSource>(
    () => WalletLocalDataSourceImpl(db: sl()),
  );
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(localDataSource: sl(), syncEngine: sl()),
  );
  // Factory: tạo WalletCubit mới cho mỗi trang, tự hủy khi trang đóng
  sl.registerFactory<WalletCubit>(
    () => WalletCubit(repository: sl()),
  );

  // ── 6. Features — Transaction, Category (Plan 5-6) ───────────────────────
  // Thêm dần theo từng Plan

  await sl.allReady();
}
