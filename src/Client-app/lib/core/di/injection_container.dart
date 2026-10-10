import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/interceptors/auth_interceptor.dart';
import '../../core/api/dio_client.dart';
import '../../core/database/app_database.dart';
import '../../core/realtime/realtime_channel.dart';
import '../../core/sync/sync_checkpoint_store.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/analytics/data/analytics_repository.dart';
import '../../features/analytics/data/analytics_repository_impl.dart';
import '../../features/analytics/data/thu_tu_khoi_nguon.dart';
import '../../features/analytics/data/bao_cao_repository.dart';
import '../../features/analytics/data/bao_cao_repository_impl.dart';
import '../../features/analytics/data/xuat_tep_service.dart';
import '../../features/analytics/data/xuat_tep_service_impl.dart';
import '../../features/analytics/presentation/bloc/analytics_cubit.dart';
import '../../features/analytics/presentation/bloc/thu_tu_khoi_cubit.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/an_the_cho_xoa.dart';
import '../../features/goal/data/datasources/goal_local_data_source.dart';
import '../../features/goal/data/models/goal_entity.dart';
import '../../features/goal/data/repositories/goal_repository.dart';
import '../../features/goal/domain/goal_auto_deposit_runner.dart';
import '../../features/bill/domain/bill_auto_pay_runner.dart';
import '../../features/goal/data/repositories/goal_repository_impl.dart';
import '../../features/goal/presentation/bloc/goal_cubit.dart';
import '../../features/budget/data/datasources/budget_local_data_source.dart';
import '../../features/budget/data/repositories/budget_repository.dart';
import '../../features/ai_edge/domain/canary_gpu.dart';
import '../../features/ai_edge/domain/canary_cong_cu.dart';
import '../../features/ai_edge/data/cong_tac_ai.dart';
import '../../features/ai_edge/data/nguon_ly_do_thoat.dart';
import '../../features/transaction/data/vi_theo_nguon_store.dart';
import '../../features/transaction/domain/doc_tin_bien_dong.dart';
import '../../features/ai_edge/data/mo_hinh_tai_ve.dart';
import '../../features/ai_edge/data/slm_cache.dart';
import '../../features/ai_edge/data/nguon_goi_so.dart';
import '../../features/ai_edge/data/bo_cong_cu.dart';
import '../../features/ai_edge/data/slm_runtime.dart';
import '../../features/ai_edge/data/nguon_tai_nen.dart';
import '../../features/ai_edge/data/tai_nen_background_downloader.dart';
import '../../features/budget/data/tai_phan_bo_nguon.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/presentation/bloc/budget_cubit.dart';
import '../../features/budget/presentation/bloc/budget_detail_cubit.dart';
import '../../features/wallet/data/datasources/wallet_local_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository.dart';
import '../../features/wallet/data/services/dieu_chinh_so_du_service.dart';
import '../../features/wallet/data/services/so_du_vi_service.dart';
import '../../features/wallet/data/services/vi_trung_ten_resolver.dart';
import '../../features/wallet/data/services/gop_vi_service.dart';
import '../../features/wallet/data/vi_trung_ten_nguon.dart';
import '../../features/wallet/presentation/an_nhac_vi_trung_ten.dart';
import '../../features/premium/data/co_quyen_nen.dart';
import '../../features/premium/data/dem_dang_hoat_dong.dart';
import '../../features/premium/data/goi_repository.dart';
import '../../features/premium/data/goi_store.dart';
import '../../features/premium/data/payment_api.dart';
import '../../features/premium/domain/quyen_tinh_nang.dart';
import '../../features/premium/presentation/an_nhac_het_han.dart';
import '../../features/premium/presentation/cubit/goi_cubit.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/data/services/default_account_data_initializer.dart';
import '../../features/wallet/domain/dot_am.dart';
import '../../features/wallet/presentation/bloc/wallet_cubit.dart';
import '../../features/transaction/data/datasources/transaction_local_data_source.dart';
import '../../features/ai_chat/data/doc_lenh_bang_ai.dart';
import '../../features/transaction/data/doc_anh_bang_gemma.dart';
import '../../features/transaction/data/doc_danh_muc_bang_ai.dart';
import '../../features/transaction/data/doc_cau_bang_ai.dart';
import '../../features/transaction/data/repositories/transaction_repository.dart';
import '../../features/transaction/presentation/bloc/transaction_bloc.dart';
import '../../features/bill/data/datasources/bill_local_datasource.dart';
import '../../features/bill/data/repositories/bill_repository.dart';
import '../../features/bill/data/services/bill_payment_conflict_resolver.dart';
import '../../features/bill/data/repositories/bill_repository_impl.dart';
import '../../features/bill/presentation/bloc/bill_bloc.dart';
import '../../features/bill/data/de_xuat_hoa_don_nguon.dart';
import '../../features/category/data/repositories/category_management_repository.dart';
import '../../features/category/data/services/default_category_seeder.dart';
import '../../features/category/data/services/personal_default_categories.dart';
import '../../features/category/data/services/category_suggestion_engine.dart';
import '../../features/category/data/goi_y_phan_hoi_store.dart';
import '../network/connection_monitor.dart';
import '../ui/thong_bao_nhanh.dart';
import '../notification/reminder_scheduler.dart';
import '../notification/app_lifecycle_watcher.dart';
import '../notification/badge_updater.dart';
import '../notification/de_xuat_thong_bao_nguon.dart';
import '../notification/hang_cho_su_kien.dart';
import '../notification/kenh_bien_dong.dart';
import '../notification/kenh_phien_ngan_hang.dart';
import '../nen/co_chay_nen.dart';
import '../nen/kenh_tu_chuyen_tien.dart';
import '../nen/lich_nen.dart';
import '../notification/kho_bien_lai.dart';
import '../notification/moc_phien_store.dart';
import '../notification/nhap_bien_dong.dart';
import '../notification/nhap_bien_lai.dart';
import '../notification/nhap_phien_ngan_hang.dart';
import '../notification/nhat_ky_thong_bao.dart';
import '../notification/notification_scanner.dart';
import '../notification/os/os_notifier.dart';
import '../notification/os/os_notifier_factory.dart';
import '../notification/prefs/notification_prefs_store.dart';
import '../ocr/kho_anh_quet.dart';
import '../ocr/doc_chu_anh.dart';
import '../ocr/doc_chu_anh_mlkit.dart';

/// Service locator — dùng `sl<T>()` để resolve dependencies
final GetIt sl = GetIt.instance;

/// Chủ khoá thuê tự chuyển tiền của engine này — `'app'`, hoặc `'nen'` ở engine
/// nền của WorkManager (`setupDependencies(cheDoNen: true)`).
String _chuKhoa = 'app';

/// Khởi động toàn bộ dependency injection graph.
/// Gọi một lần trong `main()` trước khi `runApp()`.
/// [cheDoNen] — engine nền của WorkManager (spec tự chuyển tiền chạy nền mục
/// 3.3): chủ khoá thuê là `'nen'`, `AuthInterceptor` không làm mới token, và
/// vòng quét không tự hẹn lượt nền (lượt nền trả mốc qua `nenXong`).
Future<void> setupDependencies({bool cheDoNen = false}) async {
  _chuKhoa = cheDoNen ? 'nen' : 'app';
  // ── 1. External packages ──────────────────────────────────────────────────
  const secureStorage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // ── 2. Core: AppDatabase (Drift SQLite) ───────────────────────────────────
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // ── 3. Core: DioClient ─────────────────────────────────────────────────────
  // AuthInterceptor đăng ký riêng: AuthBloc cần nghe `sessionExpiredStream`
  // của ĐÚNG instance đang nằm trên đường request.
  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(secureStorage: sl(), cheDoNen: cheDoNen),
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

  // Cờ "Để sau" của thẻ nhắc tài khoản chờ xoá — trong bộ nhớ, sống theo phiên app.
  sl.registerLazySingleton<AnTheChoXoa>(AnTheChoXoa.new);

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
    () => WalletRepositoryImpl(
        localDataSource: sl(), syncEngine: sl(), soDuVi: sl()),
  );
  // Năm danh mục mà bộ mặc định của backend không có được tạo riêng cho từng
  // tài khoản (xem PersonalDefaultCategories) — danh mục người dùng thì đồng bộ
  // được, còn danh mục mặc định thì không.
  // Nơi DUY NHẤT ghi `wallets.balance`: số dư nay là cache của tổng sổ giao
  // dịch, không còn là giá trị tuyệt đối đồng bộ theo LWW (G37).
  sl.registerLazySingleton<SoDuViService>(() => SoDuViService(db: sl()));
  // G63: đặt cờ cho ví bị server từ chối vì trùng tên. Chỉ ĐĂNG KÝ ở đây;
  // `batDauNghe` gọi MỘT lần ở `main.dart`, cùng lý do với bộ nghe hoá đơn.
  sl.registerLazySingleton<ViTrungTenResolver>(
    () => ViTrungTenResolver(db: sl()),
  );
  // G63: gộp ví trùng tên (spec 2026-10-05 mục 6). `ViTheoNguonStore` đăng ký
  // ở khối D1 phía dưới — lazy nên chỉ cần có mặt lúc gọi lần đầu.
  sl.registerLazySingleton<GopViService>(
    () => GopViService(
      db: sl(),
      soDuVi: sl(),
      viTheoNguon: sl<ViTheoNguonStore>(),
      henDongBo: () => sl<SyncEngine>().scheduleSync(),
    ),
  );
  // G63: chỗ đọc ví trùng tên cho thẻ ở Quản lý ví và dòng nhắc ở Trang chủ.
  // (SyncEngine tự dựng bản của nó — lớp này không giữ trạng thái.)
  sl.registerLazySingleton<ViTrungTenNguon>(
    () => ViTrungTenNguonImpl(db: sl()),
  );
  // ✕ của dòng nhắc ví trùng tên ở Trang chủ — trong bộ nhớ, sống theo phiên
  // app; AuthBloc đặt lại khi đăng nhập.
  sl.registerLazySingleton<AnNhacViTrungTen>(AnNhacViTrungTen.new);
  sl.registerLazySingleton<DefaultCategorySeeder>(
    () => DefaultCategorySeeder(db: sl()),
  );
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
      soDuVi: sl(),
    ),
  );
  // Điều chỉnh số dư ví (đối soát). Đăng ký SAU TransactionRepository vì nó
  // ghi khoản bù qua đó — cố ý, để phép cộng trừ số dư và phép hoàn lại khi
  // xoá đều dùng lại `_applyBalances` thay vì ghi thẳng `updateBalance`.
  sl.registerLazySingleton<DieuChinhSoDuService>(
    () => DieuChinhSoDuService(db: sl(), transactionRepository: sl()),
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
  // Gỡ khoản trả mà server từ chối bằng `BILL_ALREADY_PAID` — máy khác đã trả
  // hoá đơn ấy trước. Chỉ ĐĂNG KÝ ở đây; `batDauNghe` được gọi một lần lúc app
  // khởi động (`main.dart`), vì lớp phải sống suốt vòng đời chứ không theo màn.
  sl.registerLazySingleton<BillPaymentConflictResolver>(
    () => BillPaymentConflictResolver(
      db: sl<AppDatabase>(),
      bills: sl<BillRepository>(),
    ),
  );
  sl.registerFactory<BillBloc>(
    () => BillBloc(repository: sl<BillRepository>()),
  );
  // Thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn (B2) — trang tự lấy nguồn này
  // khi đã đăng ký, không thì không dựng thẻ.
  sl.registerLazySingleton<DeXuatHoaDonNguon>(
    () => DeXuatHoaDonNguon(db: sl<AppDatabase>()),
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
  // B1: phản hồi thẻ gợi ý danh mục — bảng cục bộ v25, không đồng bộ.
  sl.registerLazySingleton<GoiYPhanHoiStore>(
    () => GoiYPhanHoiStoreDrift(sl<AppDatabase>()),
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
  // Nguồn dữ liệu Tầng 2 tái phân bổ (Edge-SLM P2) — trang Ngân sách và bộ quét
  // thông báo dùng chung, để thẻ trên màn và thông báo không nói hai chuyện.
  sl.registerLazySingleton<TaiPhanBoNguon>(
    () => TaiPhanBoNguonImpl(
      db: sl<AppDatabase>(),
      budgets: sl<BudgetRepository>(),
    ),
  );
  sl.registerFactory<BudgetCubit>(
    () => BudgetCubit(
      repository: sl<BudgetRepository>(),
      taiPhanBoNguon: sl<TaiPhanBoNguon>(),
    ),
  );
  sl.registerFactory<BudgetDetailCubit>(
    () => BudgetDetailCubit(repository: sl<BudgetRepository>()),
  );

  // ── 10b. Features — Phân tích ──────────────────────────────────────────────
  // Đọc thẳng Drift cho giao dịch/danh mục, và mượn BudgetRepository cho cột
  // "% ngân sách" thay vì tính lại số đã chi lần thứ hai.
  sl.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(
      db: sl<AppDatabase>(),
      budgetRepository: sl<BudgetRepository>(),
    ),
  );
  sl.registerFactory<AnalyticsCubit>(
    () => AnalyticsCubit(repository: sl<AnalyticsRepository>()),
  );
  // Thứ tự khối trang Phân tích theo thói quen xem (dự án C việc ba) — hai
  // bảng cục bộ v29. Không đăng ký thì trang y hệt trước (thứ tự mặc định).
  sl.registerLazySingleton<ThuTuKhoiNguon>(
    () => ThuTuKhoiNguonDrift(dao: sl<AppDatabase>().thuTuKhoiDao),
  );
  sl.registerFactory<ThuTuKhoiCubit>(
    () => ThuTuKhoiCubit(nguon: sl<ThuTuKhoiNguon>()),
  );
  // Trang Xuất báo cáo đọc thẳng repository (không cubit): màn Xem trước là
  // một ảnh chụp theo bộ lọc, không phải luồng dữ liệu sống.
  sl.registerLazySingleton<XuatTepService>(() => XuatTepServiceImpl());
  sl.registerLazySingleton<BaoCaoRepository>(
    () => BaoCaoRepositoryImpl(
      db: sl<AppDatabase>(),
      budgetRepository: sl<BudgetRepository>(),
    ),
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

  // Kênh thông báo tự do một dòng cho AppToast (2026-09-19, E3 của lượt UX).
  sl.registerLazySingleton<ThongBaoNhanh>(() => ThongBaoNhanh());

  // Kênh thời gian thực. Cũng tách khỏi SyncEngine, và cũng vì hai câu hỏi
  // khác nhau: SyncEngine hỏi "khi nào thì đồng bộ", kênh này chỉ thuật lại
  // "server vừa nói gì". Thiết kế đầy đủ ở
  // docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md
  sl.registerLazySingleton<RealtimeChannel>(
    () => RealtimeChannel(secureStorage: sl<FlutterSecureStorage>()),
  );

  // ── Features — Premium (spec 2026-10-06) ─────────────────────────────────
  // Trạng thái gói là MỘT cho cả app → GoiCubit singleton, cung cấp ở gốc cây
  // (`main.dart`). Ba nguồn làm mới (phiên, vòng đời, socket) nối ở `main.dart`
  // vì AuthBloc là factory. Đếm đăng ký theo mặt cắt để router tiêm bản giả.
  sl.registerLazySingleton<PaymentApi>(
      () => DioPaymentApi(sl<DioClient>().dio));
  sl.registerLazySingleton<GoiStore>(
      () => SecureStorageGoiStore(sl<FlutterSecureStorage>()));
  sl.registerLazySingleton<GoiRepository>(
      () => GoiRepository(api: sl(), kho: sl()));
  sl.registerLazySingleton<NguonDemDangHoatDong>(
      () => DemDangHoatDong(db: sl()));
  sl.registerLazySingleton<GoiCubit>(() => GoiCubit(sl()));
  sl.registerLazySingleton<AnNhacHetHan>(AnNhacHetHan.new);

  sl.registerLazySingleton<OsNotifier>(createOsNotifier);

  // Nhật ký thông báo (B5a) — cửa ghi duy nhất. Nguồn phiên để RỖNG ở đây và
  // `main.dart` gán lại (`datNguonPhien`): `AuthBloc` đăng ký dạng FACTORY, nên
  // `sl<AuthBloc>()` ở đây là một bloc MỚI luôn chưa đăng nhập — đọc nó là nhật
  // ký không bao giờ ghi được gì, im lặng.
  sl.registerLazySingleton<NhatKyThongBao>(
    () => NhatKyThongBao(
      dao: sl<AppDatabase>().notificationEventDao,
      idaccountPhien: () => null,
    ),
  );

  // Tuỳ chọn thông báo. Dùng chung `FlutterSecureStorage` với token và
  // checkpoint đồng bộ — cùng mẫu `SecureStorageSyncCheckpointStore`.
  sl.registerLazySingleton<NotificationPrefsStore>(
    () => const SecureStorageNotificationPrefsStore(FlutterSecureStorage()),
  );

  // D1: ví chọn sẵn cho form điền từ tin biến động số dư — bảng nguồn + đuôi TK → ví,
  // cục bộ theo tài khoản, cùng khuôn kho tuỳ chọn thông báo.
  sl.registerLazySingleton<ViTheoNguonStore>(
    () => const SecureStorageViTheoNguonStore(FlutterSecureStorage()),
  );
  // Nhắc ghi sau khi dùng app ngân hàng (2026-10-03): mốc "đã xét đến" theo tài khoản.
  sl.registerLazySingleton<MocPhienStore>(
    () => const SecureStorageMocPhienStore(FlutterSecureStorage()),
  );

  // Đề xuất giờ nhắc / tắt nhóm bị lờ (B5b) — đọc nhật ký B5a, chỉ đề xuất.
  sl.registerLazySingleton<DeXuatThongBaoNguon>(
    () => DeXuatThongBaoNguon(
      db: sl<AppDatabase>(),
      store: sl<NotificationPrefsStore>(),
      os: sl<OsNotifier>(),
      nhatKy: sl<NhatKyThongBao>(),
    ),
  );

  // Lịch nhắc đặt trước với hệ điều hành — cách DUY NHẤT để thông báo nổ khi
  // app đóng hoàn toàn mà không cần tác vụ nền.
  sl.registerLazySingleton<ReminderScheduler>(
    () => ReminderScheduler(
      osNotifier: sl<OsNotifier>(),
      // Android có lượt nền tự chuyển tiền: không nhắc kỳ trích, câu tự trả
      // thôi bảo "Mở app" (spec tự chuyển tiền chạy nền mục 6).
      chayNen: coChayNen,
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
      // Nguồn thứ ba: lời nhắc ghi chép hằng ngày. Đi chung bộ đặt lịch vì
      // cùng lý do như mục tiêu — `resync()` huỷ mọi lịch chờ không nằm trong
      // tập nó muốn, nên một bộ đặt lịch riêng sẽ xoá sạch lịch của bộ kia.
      loadLastTransactionAt: (idaccount) =>
          sl<AppDatabase>().transactionDao.getLastTransactionDate(idaccount),
      prefsStore: sl<NotificationPrefsStore>(),
      // Nhật ký B5a: `dat_lich` / `huy_lich` — B5b suy "đã tới máy" từ chúng.
      nhatKy: sl<NhatKyThongBao>(),
      eventDao: sl<AppDatabase>().notificationEventDao,
    ),
  );

  // Vòng đời app — mốc kích hoạt quét KHÔNG phụ thuộc mạng. Là singleton vì
  // mỗi bản là một observer nữa gắn vào WidgetsBinding.
  sl.registerLazySingleton<AppLifecycleWatcher>(AppLifecycleWatcher.new);

  // D1: kênh tới tầng Kotlin đọc biến động số dư — chỉ Android có; nơi khác là
  // bản trống (không quyền, không làm gì) để mọi chỗ gọi khỏi rẽ nhánh nền tảng.
  sl.registerLazySingleton<KenhBienDong>(() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const KenhBienDongAndroid()
          : const KenhBienDongTrong());

  // Nhắc ghi sau khi dùng app ngân hàng (2026-10-03): kênh tới `PhienNganHang.kt` — chỉ Android; nơi khác bản trống.
  sl.registerLazySingleton<KenhPhienNganHang>(() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const KenhPhienNganHangAndroid()
          : const KenhPhienNganHangTrong());

  // Tự chuyển tiền chạy nền (spec 2026-10-10): kênh tới `TuChuyenTien.kt` — chỉ
  // Android; nơi khác bản trống.
  sl.registerLazySingleton<KenhTuChuyenTien>(() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const KenhTuChuyenTienAndroid()
          : const KenhTuChuyenTienTrong());
  // Lịch lượt nền: hoá đơn đọc TOÀN BỘ (không cửa sổ 30 ngày như lịch nhắc —
  // hạn xa hơn vẫn là thứ phải giữ lượt định kỳ), gác bằng quyền gói.
  sl.registerLazySingleton<LichNen>(
    () => LichNen(
      kenh: sl<KenhTuChuyenTien>(),
      tinh: (idaccount, now) async {
        final prefs = await sl<NotificationPrefsStore>().read(idaccount);
        return lichNenKeTiep(
          bills: await sl<AppDatabase>().billDao.getAll(idaccount),
          goals: [
            for (final g in await sl<AppDatabase>().goalDao.getAll(idaccount))
              GoalEntity.fromDrift(g),
          ],
          now: now,
          gioNhac: prefs.gioNhac,
          phutNhac: prefs.phutNhac,
          traDuoc: coQuyenNen(MaQuyen.billAutoPay),
          trichDuoc: coQuyenNen(MaQuyen.goalAutoDeposit),
        );
      },
    ),
  );

  // Chia sẻ biên lai: đọc chữ trên ảnh bằng ML Kit, trên máy. Lazy — không dựng gì cho tới khi có biên lai chờ.
  sl.registerLazySingleton<DocChuAnh>(() => const DocChuAnhMlKit());
  // Thư mục ảnh biên lai (`filesDir/bien_lai/` phía Kotlin) — form Thêm giao dịch cũng dùng để hiện và xoá ảnh.
  sl.registerLazySingleton<KhoBienLai>(() => KhoBienLai(thuMuc: getApplicationSupportDirectory));
  // A5 — ảnh người dùng QUÉT (nút Quét Trang chủ): thư mục RIÊNG `anh_quet/`, tách khỏi `bien_lai/` vì
  // `KhoBienLai.donMoCoi` xoá ảnh không có hàng loại 20 trỏ tới (spec A5 mục 5.5).
  sl.registerLazySingleton<KhoAnhQuet>(() => KhoAnhQuet(thuMuc: getApplicationSupportDirectory));

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
      //
      // Quyền `goal_auto_deposit` / `bill_auto_pay` (spec phân quyền 2026-10-08): không có thì BỎ LƯỢT — không trích,
      // không đổi mốc, công tắc người dùng giữ nguyên; lên lại Premium thì lượt kế chạy như cũ.
      runAutoDeposits: (idaccount, now) async =>
          coQuyenNen(MaQuyen.goalAutoDeposit)
              ? GoalAutoDepositRunner(
                  db: sl<AppDatabase>(),
                  repository: sl<GoalRepository>(),
                ).chay(idaccount, now: now)
              : const <GoalAutoDepositEvent>[],
      // Tự động thanh toán hoá đơn, cùng khuôn: chạy trong vòng quét, đi qua
      // `payBill` hiện có. Xem chú thích ở `BillAutoPayRunner`.
      // G87: gỡ kỳ hoá đơn trùng trước bộ tự trả — không gác quyền (vệ sinh dữ liệu).
      gopKyTrung: (idaccount) => sl<BillRepository>().gopKyTrung(idaccount),
      soLanKeoVe: () => sl<SyncEngine>().soLanKeoVeXong,
      runAutoPays: (idaccount, now) async => coQuyenNen(MaQuyen.billAutoPay)
          ? BillAutoPayRunner(
              db: sl<AppDatabase>(),
              repository: sl<BillRepository>(),
            ).chay(idaccount, now: now)
          : const <BillAutoPayEvent>[],
      // Khoá thuê (spec tự chuyển tiền chạy nền mục 3.4) — engine nền và engine
      // app có thể quét cùng lúc trong một tiến trình.
      layKhoa: () =>
          sl<AppDatabase>().khoaTuChuyenTienDao.lay(_chuKhoa, DateTime.now()),
      nhaKhoa: () => sl<AppDatabase>().khoaTuChuyenTienDao.nha(_chuKhoa),
      // Lịch lượt nền (spec tự chuyển tiền chạy nền mục 3.1).
      // Engine nền KHÔNG tự hẹn: `REPLACE` lên chính công việc đang chạy là
      // WorkManager huỷ nó giữa chừng — mốc kế đi trong `nenXong`.
      henLichNen: cheDoNen ? null : (id) => sl<LichNen>().henNeuDoi(id),
      huyLichNen: cheDoNen ? null : () => sl<LichNen>().huy(),
      // Mục tiêu và ví đọc thẳng từ DAO chứ không qua repository: scanner chỉ
      // cần đúng một phép đọc mỗi loại, và thu hẹp phụ thuộc thì vòng quét
      // không kéo theo cả chuỗi cubit/repository không liên quan.
      loadGoals: (idaccount, now) async => [
        for (final g in await sl<AppDatabase>().goalDao.getAll(idaccount))
          GoalEntity.fromDrift(g),
      ],
      loadWallets: (idaccount, now) =>
          sl<AppDatabase>().walletDao.getAll(idaccount),
      // Luật "sắp cạn" im với ví chưa từng dùng (tạo mới 0 đ) — chỉ gọi khi ngưỡng > 0.
      loadViDaDung: (idaccount) =>
          sl<AppDatabase>().transactionDao.viDaDung(idaccount),
      // G71: thông báo số dư của ví đã xoá tự gỡ.
      loadViDaXoa: (idaccount) => sl<AppDatabase>().walletDao.idDaXoa(idaccount),
      // E6: "ví âm" báo mỗi ĐỢT một lần — mốc là giao dịch làm ví tụt dưới 0.
      loadDotAm: (idaccount, viAm) async {
        final dao = sl<AppDatabase>().transactionDao;
        return {
          for (final id in viAm)
            if (giaoDichMoDotAm(await dao.bienDongTheoVi(id)) case final moc?) id: moc,
        };
      },
      // Tổng kết tuần chỉ cần biết tuần vừa khép CÓ giao dịch hay không —
      // không tổng, không gom danh mục. Câu chữ đã chốt không nêu số nào.
      loadWeekActivity: (idaccount, from, to) => sl<AppDatabase>()
          .transactionDao
          .coGiaoDichTrongKhoang(idaccount, from, to),
      // Khoản chi lớn (#7). Tên danh mục tra bằng `getBangTraTen` — bảng tra
      // dùng chung, GIỮ cả hàng đã xoá mềm và hàng mặc định toàn cục
      // (`idaccount = 0`). Viết truy vấn riêng ở đây là bản chép tay thứ ba của
      // cùng một luật, và thiếu vế `isDefault` thì mọi khoản trỏ vào danh mục
      // mặc định mất tên — đúng G41.
      loadChiLon: (idaccount, from) async {
        final db = sl<AppDatabase>();
        final rows = await db.transactionDao.getChiTuNgay(idaccount, from);
        if (rows.isEmpty) return const [];
        final ten = {
          for (final c in await db.categoryDao.getBangTraTen(idaccount))
            c.id: c.name,
        };
        return [
          for (final t in rows)
            (
              id: t.id,
              soTien: t.amount,
              ngay: t.date,
              loai: t.type,
              categoryId: t.categoryId,
              ghiChu: t.note,
              walletId: t.walletId,
              tenDanhMuc: t.categoryId == null ? null : ten[t.categoryId],
            ),
        ];
      },
      // Đề xuất cân đối ngân sách (Edge-SLM P2). Dùng **đúng** `TaiPhanBoNguon`
      // + `taiPhanBoCua` mà `BudgetCubit` dùng — một định nghĩa duy nhất. Một
      // phép tính riêng ở đây là bản thứ hai của luật 39 điều, và hai bản sẽ nói
      // hai chuyện khác nhau: thông báo bảo "Ăn uống dự kiến vượt" còn thẻ trên
      // trang lại nói về "Mua sắm", im lặng.
      //
      // `budgets` đến từ chính lượt quét đang chạy chứ không đọc lại — xem
      // `KeHoachTaiPhanBoLoader`.
      loadKeHoach: (idaccount, budgets, now) async {
        // Quyền `smart_budget_rebalancing`: không có → không dựng kế hoạch, không sinh thông báo (và không trả giá
        // một lượt đọc toàn bộ sổ).
        if (!coQuyenNen(MaQuyen.smartBudgetRebalancing)) return null;
        final dangChay = [
          for (final v in budgets)
            if (!v.budget.isExpired(now)) v,
        ];
        if (dangChay.isEmpty) return null;
        return keHoachTaiPhanBoTu(
            sl<TaiPhanBoNguon>(), idaccount, dangChay, now);
      },
      markOverdue: (idaccount, now) =>
          sl<AppDatabase>().billDao.markOverdue(idaccount, now),
      syncStatus: sl<SyncEngine>().statusStream,
      // Mốc thứ hai, và là mốc duy nhất không cần mạng: app quay lại từ nền.
      // Thiếu nó thì một phiên offline không có lượt quét nào — kể cả hai bộ
      // tự chuyển tiền chạy bên trong `scan()`.
      appLifecycle: sl<AppLifecycleWatcher>().stream,
      osNotifier: sl<OsNotifier>(),
      // Scanner sở hữu vòng đời của nó — xem chú thích ở trường `badgeUpdater`.
      badgeUpdater: BadgeUpdater(
        dao: sl<AppDatabase>().notificationDao,
        osNotifier: sl<OsNotifier>(),
      ),
      prefsStore: sl<NotificationPrefsStore>(),
      // Lịch phải theo kịp dữ liệu: hoá đơn vừa thanh toán mà lịch cũ còn
      // nguyên là điện thoại vẫn kêu nhắc trả một hoá đơn đã trả.
      resyncLich: (idaccount) =>
          sl<ReminderScheduler>().resync(idaccount),
      // Nhật ký B5a: cú Hoãn nằm trong tệp hàng chờ (isolate nền không có CSDL).
      // Một dòng thuộc tài khoản khi khoá khớp một `dat_lich` HOẶC một thông báo
      // của chính tài khoản ấy — không khớp thì bỏ, không đoán (quy tắc 2).
      nhapHangCho: NhapHangCho(
        thuMuc: getApplicationDocumentsDirectory,
        nhatKy: sl<NhatKyThongBao>(),
        thuocTaiKhoan: (id, k) async =>
            await sl<AppDatabase>().notificationEventDao.coDatLich(id, k) ||
            await sl<AppDatabase>().notificationDao.coDedupeKey(id, k),
      ),
      // D1: tệp hàng chờ tin biến động do Kotlin ghi vào `filesDir` — chính là
      // `getApplicationSupportDirectory()` (KHÔNG phải documents dir của B5a).
      // Hàng chờ gắn máy, nhập vào tài khoản đang đăng nhập; công tắc là cờ
      // `docBienDong` của tài khoản ấy.
      nhapBienDong: NhapBienDong(
        thuMuc: getApplicationSupportDirectory,
        dao: sl<AppDatabase>().notificationDao,
        nguonCuaGoi: nguonCuaGoi,
        // Công tắc của tài khoản VÀ quyền `bank_notification_parser` của gói.
        batBienDong: (id) async =>
            (await sl<NotificationPrefsStore>().read(id)).docBienDong &&
            coQuyenNen(MaQuyen.bankNotificationParser),
        huyTomTat: () => sl<KenhBienDong>().huyTomTat(),
        datBat: (bat) => sl<KenhBienDong>().datBat(bat),
      ),
      // Chia sẻ biên lai: cờ "máy đang có phiên" phía native — xem `NhanBienLaiActivity`.
      datCoPhien: (co) => sl<KenhBienDong>().datCoPhien(co),
      // Chia sẻ biên lai: hàng chờ + ảnh do `NhanBienLaiActivity` ghi vào `filesDir`; nhập vào tài khoản đang đăng
      // nhập, cùng tên nguồn với D1 (`nguonCuaGoi`). Không đọc cờ `docBienDong` — mỗi biên lai là người dùng tự đưa.
      nhapBienLai: NhapBienLai(
        thuMuc: getApplicationSupportDirectory,
        dao: sl<AppDatabase>().notificationDao,
        docChu: sl<DocChuAnh>(),
        kho: sl<KhoBienLai>(),
        nguonCuaGoi: nguonCuaGoi,
        coQuyen: () => coQuyenNen(MaQuyen.ocrReceipt),
        huyTomTat: () => sl<KenhBienDong>().huyTomTat(),
        // Chế độ thu mẫu — CHỈ bản debug: in hình dạng đã che của chữ trên biên lai đang chờ (§13.6).
        thuMau: kDebugMode
            ? () => thuMauBienLai(thuMuc: getApplicationSupportDirectory, docChu: sl<DocChuAnh>())
            : null,
      ),
      // Nhắc ghi sau khi dùng app ngân hàng (2026-10-03): sự kiện sử dụng từ `PhienNganHang.kt`, bằng chứng từ hàng loại
      // 20 và sổ giao dịch, ví theo nguồn của D1. Công tắc là cờ `nhacSauNganHang` của tài khoản.
      nhapPhien: NhapPhienNganHang(
        kenh: sl<KenhPhienNganHang>(),
        dao: sl<AppDatabase>().notificationDao,
        moc: sl<MocPhienStore>(),
        batNhac: (id) async => (await sl<NotificationPrefsStore>().read(id)).nhacSauNganHang,
        nguonCuaGoi: nguonCuaGoi,
        giaoDichTrongKhoang: (id, tu, den) async => [
          for (final t in await sl<AppDatabase>().transactionDao.getByDateRange(id, tu, den))
            (ngay: t.date, walletId: t.walletId, walletTransfer: t.walletTransfer),
        ],
        viCuaNguon: (id, nguon) => sl<ViTheoNguonStore>().docTheoNguon(id, nguon),
      ),
      // Nhật ký B5a: `huy_lich` lúc đăng xuất, dọn 180 ngày lúc start.
      nhatKy: sl<NhatKyThongBao>(),
      eventDao: sl<AppDatabase>().notificationEventDao,
    ),
  );

  // ── AI trên máy (Edge AI P3) ───────────────────────────────────────────────
  // Cả ba đều `registerLazySingleton`: không cái nào được dựng cho tới khi màn
  // Cài đặt AI hoặc màn Trợ lý AI chạm vào. Quan trọng với `SlmRuntime` —
  // dựng nó là nạp engine native, thứ không được xảy ra lúc mở app.
  // Canary GPU: Mali (Dimensity 1100) sập native khi gắn delegate OpenCL —
  // xem `domain/canary_gpu.dart`. Dấu nằm cùng thư mục với tệp mô hình.
  // Canary phiên có tool (bước 1b): đăng ký RIÊNG vì `main.dart` xét dấu sót
  // của nó lúc khởi động, khi `SlmRuntime` chưa được dựng — dựng lớp này chỉ
  // là giữ hai hàm, không chạm engine. Nguồn lý do thoát là kênh Android thật.
  sl.registerLazySingleton<CanaryCongCu>(
    () => CanaryCongCu(
      thuMuc: getApplicationSupportDirectory,
      nguon: const NguonLyDoThoatAndroid(),
    ),
  );
  sl.registerLazySingleton<SlmRuntime>(
    () => SlmRuntimeThat(
      canary: const CanaryGpu(thuMuc: getApplicationSupportDirectory),
      canaryCongCu: sl<CanaryCongCu>(),
    ),
  );

  // Lượt tải mô hình sống lâu hơn tiến trình (tải nền + resume, 2026-09-22).
  // ⚠️ `registerSingleton` chứ không lazy: `chuanBi()` phải chạy TRƯỚC khi màn
  // nào hỏi `luotDangSong()` — lazy nghĩa là nó chỉ chạy lúc ai đó hỏi lần
  // đầu, tức sau khi màn đã dựng xong và đã kết luận "không có lượt nào".
  // ⚠️ Bọc `kIsWeb`: app còn chạy được trên Chrome (`flutter run -d chrome`),
  // mà `background_downloader` ở đó không có service nền — dựng nó là ném
  // ngay lúc mở app. Trên web bản giả đứng thay, coi như "không có lượt".
  if (kIsWeb) {
    sl.registerSingleton<NguonTaiNen>(NguonTaiNenGia());
  } else {
    final taiNen = BackgroundDownloaderTaiNen();
    await taiNen.chuanBi();
    sl.registerSingleton<NguonTaiNen>(taiNen);
  }

  sl.registerLazySingleton<MoHinhTaiVe>(
    () => MoHinhTaiVe(
      thuMuc: getApplicationSupportDirectory,
      nguon: sl<NguonTaiNen>(),
    ),
  );

  sl.registerLazySingleton<SlmCache>(
    () => SlmCache(thuMuc: getApplicationSupportDirectory),
  );

  sl.registerLazySingleton<CongTacAi>(CongTacAi.new);

  // Ô Nhập nhanh của màn Thêm giao dịch đọc câu bằng mô hình (C2 §2.8, người dùng chọn "AI đọc mọi câu" 2026-09-30) —
  // chỗ THỨ HAI dùng mô hình sau màn Trợ lý AI (lối B mở rộng). Cùng hai điều kiện của màn ấy: tệp đủ và công tắc bật.
  sl.registerLazySingleton<DocCauBangAi>(
    () => DocCauBangAi(
      runtime: sl<SlmRuntime>(),
      sanSang: () async => await sl<MoHinhTaiVe>().daCo() && await sl<CongTacAi>().doc(),
      duongTep: () => sl<MoHinhTaiVe>().duongTep(),
    ),
  );

  // A5 mục 13 — ảnh quét hoá đơn: Gemma NHÌN ẢNH đọc món + tổng. Điều kiện Premium nằm ở màn /quet; ở đây là tệp đủ +
  // công tắc. CÙNG một runtime với đường chữ (một mô hình mỗi lúc — `docAnh` đóng nó sau khi đọc).
  sl.registerLazySingleton<SlmDocAnh>(() => sl<SlmRuntime>() as SlmDocAnh);
  // A5 mục 13 — Gemma lần hai chọn danh mục chi từ cửa hàng + các món (người dùng chốt "AI chọn danh mục").
  sl.registerLazySingleton<DocDanhMucBangAi>(
    () => DocDanhMucBangAi(
      runtime: sl<SlmRuntime>(),
      sanSang: () async => await sl<MoHinhTaiVe>().daCo() && await sl<CongTacAi>().doc(),
      duongTep: () => sl<MoHinhTaiVe>().duongTep(),
    ),
  );
  sl.registerLazySingleton<DocAnhBangGemma>(
    () => DocAnhBangGemma(
      moHinh: sl<SlmDocAnh>(),
      sanSang: () async => await sl<MoHinhTaiVe>().daCo() && await sl<CongTacAi>().doc(),
      duongTep: () => sl<MoHinhTaiVe>().duongTep(),
    ),
  );

  // C3 §8 — lệnh tạo hoá đơn / mục tiêu / ngân sách ở màn Trợ lý AI đọc bằng mô hình (người dùng chốt 2026-09-30):
  // phiên RIÊNG ba tool. Cùng hai điều kiện sẵn sàng với ô Nhập nhanh.
  sl.registerLazySingleton<DocLenhBangAi>(
    () => DocLenhBangAi(
      runtime: sl<SlmRuntime>(),
      sanSang: () async => await sl<MoHinhTaiVe>().daCo() && await sl<CongTacAi>().doc(),
      duongTep: () => sl<MoHinhTaiVe>().duongTep(),
    ),
  );

  // Nguồn sáu gói số cho BẬC 1 của màn Trợ lý AI — nhánh lùi L1 khi mô hình
  // không gọi tool nào. Sáu khối Nhận xét đều lấy gói từ trang của chúng; màn
  // Trợ lý AI không thuộc trang nào nên phải tự hỏi dữ liệu — qua lớp này, hoặc
  // (từ chặng 4b) qua các tool đọc của `BoCongCu` ngay dưới — bốn từ chặng 4b,
  // bảy từ bước 2.
  sl.registerLazySingleton<NguonGoiSo>(
    () => NguonGoiSo(
      phanTich: sl<AnalyticsRepository>(),
      nganSach: sl<BudgetRepository>(),
      mucTieu: sl<GoalRepository>(),
      vi: sl<WalletRepository>(),
      hoaDon: sl<BillRepository>(),
    ),
  );

  // Bộ tool của bậc tool — mọi tool đều ĐỌC, không tool ghi (bất biến ④). Lazy
  // như `NguonGoiSo`: chỉ dựng khi màn Trợ lý AI hỏi lần đầu. Danh sách tool và
  // thứ tự của chúng nằm ở `BoCongCu.macDinh`, không chép lại ở đây.
  sl.registerLazySingleton<BoCongCu>(
    () => BoCongCu.macDinh(
      nganSach: sl<BudgetRepository>(),
      vi: sl<WalletRepository>(),
      hoaDon: sl<BillRepository>(),
      mucTieu: sl<GoalRepository>(),
      giaoDich: sl<TransactionRepository>(),
      baoCao: sl<BaoCaoRepository>(),
      phanTich: sl<AnalyticsRepository>(),
      danhMuc: sl<CategoryManagementRepository>(),
      taiPhanBo: sl<TaiPhanBoNguon>(),
    ),
  );

  // 🛑 CỐ Ý KHÔNG đăng ký `BoDienGiai` — người dùng chốt LỐI B ngày 2026-09-21.
  //
  // Không đăng ký thì `KhoiNhanXet` tự dùng `const MauCau()`, nên sáu khối Nhận
  // xét (Ngân sách · Phân tích · Mục tiêu · Trang chủ · Hoá đơn · Quản lý ví)
  // **giữ mẫu câu**: hiện tức thì, không chờ 2,3 giây, không "nhảy" từ mẫu
  // sang câu mô hình.
  //
  // Vì sao: P1 đo được câu mô hình ở khối Nhận xét **gần bằng mẫu câu** — khác
  // nhau ở giọng văn, không ở thông tin, và mẫu câu còn gọn hơn. Cái giá là
  // 2,3 s mỗi khối cộng 2,41 GB tải. Mô hình chỉ hơn hẳn ở **hỏi đáp tự do**,
  // nên nó phục vụ **một chỗ duy nhất**: màn Trợ lý AI (Task 8) — ⚠️ từ 2026-09-30 thêm ô Nhập nhanh
  // (`DocCauBangAi`, C2, người dùng chọn "AI đọc mọi câu"), nơi tự dựng
  // đường sinh câu của mình từ `sl<SlmRuntime>()` và `sl<MoHinhTaiVe>()`.
  //
  // ⚠️ Màn ấy **KHÔNG** đi qua `SlmDienGiai`, và **không** qua `SlmCache` —
  // nó gọi thẳng `SlmRuntime.sinh`. Hệ quả: `SlmCache` dưới đây được đăng ký
  // nhưng hôm nay **không nằm trên đường chạy nào**; nó vẫn được dọn khi đổi
  // tài khoản (`AuthBloc`), và sống lại nguyên vẹn nếu ai bật lối A. Câu cũ ở
  // đây nói màn Trợ lý AI "tự dựng `SlmDienGiai`" — sai, và cái sai ấy lộ ra
  // khi P3 Task 9 đi đo ô *"câu thứ hai phải 0 ms nhờ cache"* rồi phát hiện
  // không có cache nào trên đường ấy cả (mục 9.4 `docs/AI_EDGE_FEATURE.md`).
  //
  // ⚠️ Đổi sang LỐI A (mô hình viết câu ở cả sáu khối) chỉ là bỏ dấu chú thích
  // của khối dưới — một commit, không sửa màn nào. Đừng làm nếu người dùng chưa
  // đổi ý. Công tắc "Dùng AI trên máy" ở lối B do chính màn Trợ lý AI đọc
  // (`CongTacAi`), không để DI gác hộ.
  //
  // if (await sl<CongTacAi>().doc()) {
  //   sl.registerLazySingleton<BoDienGiai>(() => SlmDienGiai(
  //         runtime: sl<SlmRuntime>(),
  //         cache: sl<SlmCache>(),
  //         moHinh: sl<MoHinhTaiVe>(),
  //       ));
  // }

  await sl.allReady();
}
