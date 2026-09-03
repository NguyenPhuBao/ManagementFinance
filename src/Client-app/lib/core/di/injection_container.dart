import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/interceptors/auth_interceptor.dart';
import '../../core/api/dio_client.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_checkpoint_store.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/goal/data/datasources/goal_local_data_source.dart';
import '../../features/goal/data/repositories/goal_repository.dart';
import '../../features/goal/data/repositories/goal_repository_impl.dart';
import '../../features/goal/presentation/bloc/goal_cubit.dart';
import '../../features/wallet/data/datasources/wallet_local_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/data/services/default_account_data_initializer.dart';
import '../../features/wallet/presentation/bloc/wallet_cubit.dart';
import '../../features/transaction/data/datasources/transaction_local_data_source.dart';
import '../../features/transaction/data/repositories/transaction_repository.dart';
import '../../features/transaction/presentation/bloc/transaction_bloc.dart';
import '../../features/bill/data/datasources/bill_local_datasource.dart';
import '../../features/bill/data/repositories/bill_repository.dart';
import '../../features/bill/data/repositories/bill_repository_impl.dart';
import '../../features/bill/presentation/bloc/bill_bloc.dart';
import '../../features/category/data/repositories/category_management_repository.dart';
import '../../features/category/data/services/personal_default_categories.dart';
import '../../features/category/data/services/category_suggestion_engine.dart';

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
  // AuthInterceptor đăng ký riêng: AuthBloc cần nghe `sessionExpiredStream`
  // của ĐÚNG instance đang nằm trên đường request.
  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(secureStorage: sl()),
  );
  sl.registerLazySingleton<DioClient>(
    () => DioClient(secureStorage: sl(), authInterceptor: sl()),
  );

  // ── 4. Core: SyncEngine (offline-first sync) ────────────────────────────
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      dioClient: sl(),
      db: sl(),
      checkpointStore: const SecureStorageSyncCheckpointStore(
        FlutterSecureStorage(),
      ),
    ),
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
      localDataSource: sl(),
      secureStorage: sl(),
    ),
  );

  // BLoC (factory → tạo mới mỗi lần gọi sl<AuthBloc>())
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: sl(),
      defaultAccountDataInitializer: sl(),
    ),
  );

  // ── 5. Features — Wallet ──────────────────────────────────────────────────
  sl.registerLazySingleton<WalletLocalDataSource>(
    () => WalletLocalDataSourceImpl(db: sl()),
  );
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(localDataSource: sl(), syncEngine: sl()),
  );
  // Năm danh mục mà bộ mặc định của backend không có được tạo riêng cho từng
  // tài khoản (xem PersonalDefaultCategories) — danh mục người dùng thì đồng bộ
  // được, còn danh mục mặc định thì không.
  sl.registerLazySingleton<PersonalDefaultCategories>(
    () => PersonalDefaultCategories(db: sl()),
  );
  sl.registerLazySingleton<DefaultAccountDataInitializer>(
    () => DefaultAccountDataInitializer(sl()),
  );
  // Factory: tạo WalletCubit mới cho mỗi trang, tự hủy khi trang đóng
  sl.registerFactory<WalletCubit>(
    () => WalletCubit(repository: sl()),
  );

  // ── 6. Features — Goal ────────────────────────────────────────────────────
  sl.registerLazySingleton<GoalLocalDataSource>(
    () => GoalLocalDataSourceImpl(db: sl()),
  );
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepositoryImpl(
      localDataSource: sl(),
      db: sl<AppDatabase>(),
      syncEngine: sl(),
    ),
  );
  sl.registerFactory<GoalCubit>(
    () => GoalCubit(repository: sl()),
  );

  // ── 7. Features — Transaction ─────────────────────────────────────────────
  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      localDataSource: sl(),
      walletDao: sl<AppDatabase>().walletDao,
      syncEngine: sl(),
    ),
  );
  sl.registerFactory<TransactionBloc>(
    () => TransactionBloc(
      transactionRepository: sl(),
      syncEngine: sl<SyncEngine>(),
    ),
  );
  // ── 8. Features — Bill ───────────────────────────────────────────────────
  sl.registerLazySingleton<BillLocalDataSource>(
    () => BillLocalDataSource(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<BillRepository>(
    () => BillRepositoryImpl(
      dataSource: sl<BillLocalDataSource>(),
      db: sl<AppDatabase>(),
      syncEngine: sl<SyncEngine>(),
    ),
  );
  sl.registerFactory<BillBloc>(
    () => BillBloc(repository: sl<BillRepository>()),
  );

  // ── 9. Features — Category management (local-only) ───────────────────────
  sl.registerLazySingleton<CategoryManagementRepository>(
    () => CategoryManagementRepositoryImpl(
      db: sl<AppDatabase>(),
      syncEngine: sl<SyncEngine>(),
    ),
  );
  sl.registerLazySingleton<CategorySuggestionEngine>(
    () => const CategorySuggestionEngine(),
  );

  await sl.allReady();
}
