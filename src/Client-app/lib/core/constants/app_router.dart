import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/current_account.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/register_otp_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/analytics/presentation/pages/export_report_page.dart';
import '../../features/transaction/presentation/pages/add_transaction_page.dart';
import '../../features/transaction/presentation/pages/choose_category_page.dart';
import '../../features/transaction/presentation/pages/transaction_page.dart';
import '../../features/budget/presentation/pages/budget_detail_page.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/budget/presentation/pages/budget_rules_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/profile/presentation/pages/delete_account_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/wallet/presentation/pages/wallet_list_page.dart';
import '../../features/wallet/presentation/pages/wallet_add_page.dart';
import '../../features/wallet/presentation/pages/wallet_edit_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/category/presentation/pages/category_group_page.dart';
import '../../features/category/presentation/pages/category_add_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../di/injection_container.dart';
import '../database/app_database.dart';
import '../../features/bill/presentation/bloc/bill_bloc.dart';
import '../../features/bill/presentation/pages/bill_page.dart';
import '../../features/bill/presentation/pages/bill_add_page.dart';
import '../../features/bill/presentation/pages/bill_edit_page.dart';
import '../../features/bill/presentation/pages/bill_detail_page.dart';
import '../../features/goal/presentation/pages/goal_page.dart';
import '../../features/goal/presentation/pages/goal_add_page.dart';
import '../../features/goal/presentation/pages/goal_detail_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';
import '../../features/ai_edge/presentation/pages/cai_dat_ai_page.dart';
import '../../features/notification/presentation/pages/notification_center_page.dart';
import '../../features/notification/presentation/pages/notification_settings_page.dart';

// ─── GoRouterRefreshStream ───────────────────────────────────────────────────
// Wrap AuthBloc stream thành ChangeNotifier để GoRouter tự refresh
// khi AuthState thay đổi (login/logout).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

// Routes công khai — không cần đăng nhập
const _publicRoutes = {
  '/login',
  '/register',
  '/register/verify-otp',
  '/forgot-password',
  '/otp',
  '/reset-password'
};

class AppRouter {
  /// Tạo GoRouter với:
  /// - [initialLocation]: route ban đầu (dựa trên token check trong main.dart)
  /// - [authBloc]: dùng để redirect guard tập trung
  static GoRouter createRouter(String initialLocation, AuthBloc authBloc) =>
      GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: initialLocation,

        // Refresh GoRouter mỗi khi AuthBloc emit state mới
        refreshListenable: GoRouterRefreshStream(authBloc.stream),

        // ─── Redirect guard tập trung ─────────────────────────────────────
        redirect: (BuildContext context, GoRouterState state) {
          return authRedirect(
            authState: authBloc.state,
            matchedLocation: state.matchedLocation,
          );
        },

        routes: [
          // Auth routes (public)
          GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
          GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
          GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const ForgotPasswordPage()),
          GoRoute(
            path: '/otp',
            builder: (_, state) {
              final email = state.extra as String? ?? '';
              return OtpPage(email: email);
            },
          ),
          GoRoute(
            path: '/register/verify-otp',
            redirect: (_, state) =>
                _registerOtpState(state, authBloc.state) == null
                    ? '/register'
                    : null,
            builder: (_, state) {
              final registerState = _registerOtpState(state, authBloc.state);
              return registerState != null
                  ? RegisterOtpPage(registerState: registerState)
                  : const RegisterPage();
            },
          ),
          GoRoute(
            path: '/reset-password',
            builder: (_, state) {
              final resetToken = state.extra as String? ?? '';
              return ResetPasswordPage(resetToken: resetToken);
            },
          ),

          // Main app với Bottom Navigation (4 tabs)
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => MainShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/home', builder: (_, __) => const HomePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/analytics',
                  builder: (_, __) => const AnalyticsPage(),
                  routes: [
                    GoRoute(
                      path: 'export',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, __) => const ExportReportPage(),
                    ),
                  ],
                ),
              ]),
              StatefulShellBranch(routes: [
                // ⚠️ Nhánh này từng là `/budget`. Đổi sang Sổ giao dịch ngày
                // 2026-09-19 (nhóm D): sổ là thứ mở nhiều lần mỗi ngày mà
                // trước đó không có lối vào cố định, còn ngân sách là thứ đặt
                // một lần rồi xem lại thỉnh thoảng — đúng chỗ cho drawer.
                //
                // Đổi ở đây thì PHẢI đổi `nhanhThanhTab` cùng lúc
                // (`core/notification/notification_deeplink.dart`), nếu không
                // thông báo chọn nhầm `go`/`push` và một chiều là màn đỏ.
                GoRoute(
                  // `?wallet=<id>` lọc sẵn theo một ví — đường tắt từ màn Quản
                  // lý ví. Query param chứ không `extra`: `extra` mất khi
                  // GoRouter dựng lại route, còn tham số trên URL thì sống sót.
                  path: '/transactions',
                  builder: (_, state) => TransactionPage(
                    initialWalletId: state.uri.queryParameters['wallet'],
                  ),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                    path: '/profile', builder: (_, __) => const ProfilePage()),
              ]),
            ],
          ),

          // Analytics & Report Export standalone routes
          GoRoute(
            path: '/export-report',
            // `?from=&to=` đặt sẵn phạm vi — đường mà thông báo Tổng kết tuần
            // đi vào. Tham số qua QUERY STRING chứ không qua `extra`: cú chạm
            // vào thông báo có thể xảy ra ở **cold start**, và `extra` không
            // sống qua một tiến trình mới.
            //
            // Ngày hỏng hoặc thiếu thì trang tự lùi về "tháng này" — mở đúng
            // trang mà không đặt phạm vi vẫn tốt hơn là không mở gì.
            builder: (_, state) => ExportReportPage(
              tuNgay: DateTime.tryParse(state.uri.queryParameters['from'] ?? ''),
              denNgay: DateTime.tryParse(state.uri.queryParameters['to'] ?? ''),
            ),
          ),

          // `/transactions` đã chuyển vào nhánh shell thứ ba ngày 2026-09-19
          // (nhóm D) — xem khối `StatefulShellRoute` phía trên.
          GoRoute(
            path: '/add',
            // `extra` là EditTransactionArgs → trang mở ở chế độ sửa.
            builder: (_, state) => AddTransactionPage(
              initial: state.extra is EditTransactionArgs
                  ? state.extra as EditTransactionArgs
                  : null,
              // `extra` là `String` 'chi' | 'thu' | 'transfer' → chiều đặt
              // sẵn cho ba nút tắt ở Trang chủ (UX 2026-09-19, C4).
              huongBanDau: state.extra is String ? state.extra as String : null,
            ),
            routes: [
              GoRoute(
                path: 'category',
                builder: (_, state) => ChooseCategoryPage(
                  classify: state.extra as String? ?? 'chi',
                ),
              ),
            ],
          ),

          // Wallet
          GoRoute(
            path: '/wallets',
            builder: (_, __) => const WalletListPage(),
          ),
          GoRoute(
              path: '/wallets/add', builder: (_, __) => const WalletAddPage()),
          GoRoute(
            path: '/wallets/:id/edit',
            builder: (_, s) => WalletEditPage(id: s.pathParameters['id']!),
          ),

          // Ngân sách rời `StatefulShellRoute` ngày 2026-09-19 (nhóm D): nó
          // nhường chỗ ở thanh dưới cho Sổ giao dịch và về sống trong drawer.
          // Chỗ này chỉ là đưa cha về đứng cùng hai con — `/budget/rules` và
          // `/budget/detail/:id` vốn đã là route gốc từ trước.
          //
          // ⚠️ Chỗ gọi phải dùng `push` chứ không `go`, nếu không nó thay cả
          // stack và thanh tab biến mất.
          GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),

          // Budget rules
          // `?id=<uuid>` = sửa ngân sách đã có; không có tham số = tạo mới.
          // `?category=<id>&amount=<số>` = tạo mới đã điền sẵn, từ thẻ "Chưa
          // đặt ngân sách". `amount` hỏng thì `tryParse` trả `null` và ô hạn mức
          // để trống — một đường dẫn bị sửa tay không được làm đổ cả trang.
          GoRoute(
              path: '/budget/rules',
              builder: (_, state) => BudgetRulesPage(
                    budgetId: state.uri.queryParameters['id'],
                    danhMucChonSan: state.uri.queryParameters['category'],
                    soTienChonSan: double.tryParse(
                        state.uri.queryParameters['amount'] ?? ''),
                  )),
          // Chi tiết một ngân sách. Đặt dưới `/budget/detail/` chứ không phải
          // `/budget/:id` vì `/budget/rules` đã tồn tại và sẽ bị tham số nuốt.
          // Ngoài shell như trang cấu hình, để `push` từ tab Ngân sách không
          // dính bẫy `StatefulShellRoute` (7.8 NOTIFICATION_FEATURE.md).
          GoRoute(
            path: '/budget/detail/:id',
            builder: (_, state) =>
                BudgetDetailPage(budgetId: state.pathParameters['id']!),
          ),

          // Category
          GoRoute(
              path: '/categories', builder: (_, __) => const CategoryPage()),
          GoRoute(
              path: '/categories/add',
              redirect: (_, __) => '/categories/child/new'),
          GoRoute(
              path: '/categories/group',
              redirect: (_, __) => '/categories/group/new'),
          GoRoute(
            path: '/categories/child/new',
            builder: (_, __) => const CategoryAddPage(),
          ),
          GoRoute(
            path: '/categories/child/:id/edit',
            builder: (_, state) => CategoryAddPage(
              categoryId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/categories/group/new',
            builder: (_, __) => const CategoryGroupPage(),
          ),
          GoRoute(
            path: '/categories/group/:id/edit',
            builder: (_, state) => CategoryGroupPage(
              groupId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/categories/:id/keywords',
            builder: (_, state) => CategoryAddPage(
              categoryId: state.pathParameters['id']!,
              keywordOnly: true,
            ),
          ),

          // Bill
          GoRoute(
            path: '/bills',
            builder: (_, __) => BlocProvider<BillBloc>(
              create: (_) => sl<BillBloc>(),
              child: const BillPage(),
            ),
          ),
          GoRoute(
            path: '/bills/add',
            builder: (_, __) => BlocProvider<BillBloc>(
              create: (_) => sl<BillBloc>(),
              child: const BillAddPage(),
            ),
          ),
          GoRoute(
            path: '/bills/:id/edit',
            builder: (_, s) => BlocProvider<BillBloc>(
              create: (_) => sl<BillBloc>(),
              child: BillEditPage(
                id: s.pathParameters['id']!,
                bill: s.extra as Bill?,
              ),
            ),
          ),
          // Chi tiết một hoá đơn. Ngoài shell như các route hoá đơn khác, nên
          // `push` từ danh sách không dính bẫy `StatefulShellRoute`. Đặt SAU
          // '/bills/add' và '/bills/:id/edit' — đường cụ thể trước đường có
          // tham số, cùng lý do với '/goals/:id'.
          GoRoute(
            path: '/bills/:id',
            builder: (_, s) => BlocProvider<BillBloc>(
              create: (_) => sl<BillBloc>(),
              child: BillDetailPage(
                id: s.pathParameters['id']!,
                bill: s.extra as Bill?,
              ),
            ),
          ),

          // Notification
          GoRoute(
            path: '/notifications',
            // Route đọc idaccount rồi truyền xuống; trang không hỏi AuthBloc —
            // cùng mẫu với NotificationSettingsPage ngay bên dưới.
            builder: (ctx, __) => NotificationCenterPage(
              idaccount: currentAccountIdOrNull(ctx),
            ),
          ),
          // Trang cài đặt tự đọc `idaccount` được truyền vào chứ không hỏi
          // AuthBloc — xem chú thích trong NotificationSettingsPage.
          GoRoute(
            path: '/settings/notifications',
            builder: (ctx, __) => NotificationSettingsPage(
              idaccount: currentAccountIdOrNull(ctx),
            ),
          ),

          // Goal
          GoRoute(path: '/goals', builder: (_, __) => const GoalPage()),
          GoRoute(path: '/goals/add', builder: (_, __) => const GoalAddPage()),
          // Đặt TRƯỚC '/goals/:id' cho khớp với thứ tự của '/goals/add': đường
          // cụ thể đứng trước đường có tham số.
          GoRoute(
            path: '/goals/:id/edit',
            builder: (_, s) => GoalAddPage(goalId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/goals/:id',
            builder: (_, s) => GoalDetailPage(id: s.pathParameters['id']!),
          ),

          // Other
          GoRoute(path: '/ai-chat', builder: (_, __) => const AiChatPage()),

          // Cài đặt của mảng AI trên máy: tải / xoá mô hình, công tắc dùng nó.
          //
          // ⚠️ NGOÀI `StatefulShellRoute`, và **không** có mặt trong
          // `nhanhThanhTab` (`core/notification/notification_deeplink.dart`):
          // lối vào duy nhất là nút ở màn Trợ lý AI, nên nó phải `push` để có
          // nút Back. Kéo nó vào một nhánh tab là làm mọi deeplink tới nó chết
          // màn đỏ (bẫy 7.8 `NOTIFICATION_FEATURE.md`).
          GoRoute(
            path: '/ai-settings',
            builder: (_, __) => const CaiDatAiPage(),
          ),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
          GoRoute(
              path: '/settings/change-password',
              builder: (_, __) => const ChangePasswordPage()),
          GoRoute(
              path: '/settings/delete-account',
              builder: (_, __) => const DeleteAccountPage()),
          GoRoute(
              path: '/settings/edit-profile',
              builder: (_, __) => const EditProfilePage()),
        ],
      );

  static String? authRedirect({
    required AuthState authState,
    required String matchedLocation,
  }) {
    final isGoingPublic = _publicRoutes.contains(matchedLocation);

    // Startup restoration may keep the requested route while token state is
    // unresolved. Other loading states come from user-initiated auth actions.
    if (authState is AuthInitial || authState is AuthChecking) return null;
    if (authState is AuthLoading) {
      return isGoingPublic ? null : '/login';
    }

    final isAuthed = authState is AuthSuccess;
    if (!isAuthed && !isGoingPublic) return '/login';
    if (isAuthed && isGoingPublic) return '/home';

    return null;
  }

  static RegisterOtpSent? _registerOtpState(
    GoRouterState routerState,
    AuthState authState,
  ) {
    final extra = routerState.extra;
    if (extra is RegisterOtpSent) return extra;
    if (authState is RegisterOtpFlowState) return authState.registration;
    return null;
  }
}
