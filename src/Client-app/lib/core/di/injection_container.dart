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
import '../../features/goal/data/models/goal_entity.dart';
import '../../features/goal/data/repositories/goal_repository.dart';
import '../../features/goal/domain/goal_auto_deposit_runner.dart';
import '../../features/goal/data/repositories/goal_repository_impl.dart';
import '../../features/goal/presentation/bloc/goal_cubit.dart';
import '../../features/budget/data/datasources/budget_local_data_source.dart';
import '../../features/budget/data/repositories/budget_repository.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/presentation/bloc/budget_cubit.dart';
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
import '../network/connection_monitor.dart';
import '../notification/reminder_scheduler.dart';
import '../notification/notification_scanner.dart';
import '../notification/os/os_notifier.dart';
import '../notification/os/os_notifier_factory.dart';
import '../notification/prefs/notification_prefs_store.dart';

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

  // ── 10. Features — Budget ─────────────────────────────────────────────────
  sl.registerLazySingleton<BudgetLocalDataSource>(
    () => BudgetLocalDataSourceImpl(db: sl<AppDatabase>()),
  );
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
      localDataSource: sl<BudgetLocalDataSource>(),
      syncEngine: sl<SyncEngine>(),
    ),
  );
  // Factory: mỗi trang một cubit, tự huỷ khi trang đóng.
  sl.registerFactory<BudgetCubit>(
    () => BudgetCubit(repository: sl<BudgetRepository>()),
  );

  // ── 11. Thông báo ────────────────────────────────────────────────────────
  // Cửa ra hệ điều hành. `createOsNotifier()` trả bản không làm gì trên web,
  // nên phần còn lại của app không cần biết mình đang chạy ở đâu. Đây là nơi
  // gọi DUY NHẤT của factory ấy — xem chú thích trong file đó.
  // Theo dõi kết nối cho dải báo trên giao diện. Tách khỏi SyncEngine vì hai
  // bên hỏi hai câu khác nhau: SyncEngine hỏi "đã đồng bộ được chưa" và phải
  // phản ứng ngay với cú nhấp nháy đầu tiên; dải báo hỏi "có đáng nói với
  // người dùng không" và phải chờ trạng thái ổn định.
  sl.registerLazySingleton<ConnectionMonitor>(() => ConnectionMonitor());

  sl.registerLazySingleton<OsNotifier>(createOsNotifier);

  // Tuỳ chọn thông báo. Dùng chung `FlutterSecureStorage` với token và
  // checkpoint đồng bộ — cùng mẫu `SecureStorageSyncCheckpointStore`.
  sl.registerLazySingleton<NotificationPrefsStore>(
    () => const SecureStorageNotificationPrefsStore(FlutterSecureStorage()),
  );

  // Lịch nhắc đặt trước với hệ điều hành — cách DUY NHẤT để thông báo nổ khi
  // app đóng hoàn toàn mà không cần tác vụ nền.
  sl.registerLazySingleton<ReminderScheduler>(
    () => ReminderScheduler(
      osNotifier: sl<OsNotifier>(),
      // Lịch nhắc kỳ trích tự động đi CHUNG bộ đặt lịch với hoá đơn. Tách
      // riêng là hai bên cùng gọi `pendingIds()` rồi huỷ sạch lịch của nhau ở
      // mỗi lượt — im lặng, và chỉ lộ ra khi người dùng phàn nàn rằng nhắc
      // hoá đơn đã ngừng hoạt động.
      loadGoals: (idaccount, now) async => [
        for (final g in await sl<AppDatabase>().goalDao.getAll(idaccount))
          GoalEntity.fromDrift(g),
      ],
      // Cùng cửa sổ với scanner, để hai đường không nói hai chuyện khác nhau
      // về việc "còn đáng nhắc hay chưa".
      loadBills: (idaccount, now) => sl<AppDatabase>().billDao.getUpcoming(
            idaccount,
            days: ReminderScheduler.cuaSo.inDays,
            now: now,
          ),
      prefsStore: sl<NotificationPrefsStore>(),
    ),
  );

  // Đăng ký SAU BudgetRepository vì scanner đọc qua nó. Là singleton: mỗi
  // listener thừa trên statusStream là thêm một lượt quét cho mỗi sự kiện.
  sl.registerLazySingleton<NotificationScanner>(
    () => NotificationScanner(
      dao: sl<AppDatabase>().notificationDao,
      loadBudgets: (idaccount, now) =>
          sl<BudgetRepository>().getBudgets(idaccount, now: now),
      // Cửa sổ 30 ngày khớp `NotificationScanner.cuaSoSuKien`: nạp rộng hơn là
      // đọc thừa, hẹp hơn là bỏ sót hoá đơn quá hạn còn đáng nhắc.
      loadBills: (idaccount, now) => sl<AppDatabase>().billDao.getUpcoming(
            idaccount,
            days: NotificationScanner.cuaSoSuKien.inDays,
            now: now,
          ),
      // Trích tiền tự động chạy trong chính vòng quét, không phải một bộ lập
      // lịch nền riêng. Xem chú thích ở `GoalAutoDepositRunner`.
      runAutoDeposits: (idaccount, now) => GoalAutoDepositRunner(
        db: sl<AppDatabase>(),
        repository: sl<GoalRepository>(),
      ).chay(idaccount, now: now),
      // Mục tiêu và ví đọc thẳng từ DAO chứ không qua repository: scanner chỉ
      // cần đúng một phép đọc mỗi loại, và thu hẹp phụ thuộc thì vòng quét
      // không kéo theo cả chuỗi cubit/repository không liên quan.
      loadGoals: (idaccount, now) async => [
        for (final g in await sl<AppDatabase>().goalDao.getAll(idaccount))
          GoalEntity.fromDrift(g),
      ],
      loadWallets: (idaccount, now) =>
          sl<AppDatabase>().walletDao.getAll(idaccount),
      markOverdue: (idaccount, now) =>
          sl<AppDatabase>().billDao.markOverdue(idaccount, now),
      syncStatus: sl<SyncEngine>().statusStream,
      osNotifier: sl<OsNotifier>(),
      prefsStore: sl<NotificationPrefsStore>(),
      // Lịch phải theo kịp dữ liệu: hoá đơn vừa thanh toán mà lịch cũ còn
      // nguyên là điện thoại vẫn kêu nhắc trả một hoá đơn đã trả.
      resyncLich: (idaccount) =>
          sl<ReminderScheduler>().resync(idaccount),
    ),
  );

  await sl.allReady();
}
