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
import '../../features/wallet/presentation/pages/bank_link_page.dart';
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
import '../../features/goal/presentation/pages/goal_page.dart';
import '../../features/goal/presentation/pages/goal_add_page.dart';
import '../../features/goal/presentation/pages/goal_detail_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';
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
                GoRoute(
                    path: '/budget', builder: (_, __) => const BudgetPage()),
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
            builder: (_, __) => const ExportReportPage(),
          ),

          // Transactions
          GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionPage(),
          ),
          GoRoute(
            path: '/add',
            builder: (_, __) => const AddTransactionPage(),
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
            routes: [
              GoRoute(
                path: 'bank-link',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const BankLinkPage(),
              ),
            ],
          ),
          GoRoute(
              path: '/wallets/add', builder: (_, __) => const WalletAddPage()),
          GoRoute(path: '/bank-link', builder: (_, __) => const BankLinkPage()),
          GoRoute(
            path: '/wallets/:id/edit',
            builder: (_, s) => WalletEditPage(id: s.pathParameters['id']!),
          ),

          // Budget rules
          // `?id=<uuid>` = sửa ngân sách đã có; không có tham số = tạo mới.
          GoRoute(
              path: '/budget/rules',
              builder: (_, state) => BudgetRulesPage(
                    budgetId: state.uri.queryParameters['id'],
                  )),

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

          // Notification
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationCenterPage(),
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
          GoRoute(
            path: '/goals/:id',
            builder: (_, s) => GoalDetailPage(id: s.pathParameters['id']!),
          ),

          // Other
          GoRoute(path: '/ai-chat', builder: (_, __) => const AiChatPage()),
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
