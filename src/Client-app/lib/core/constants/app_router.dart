import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/analytics/presentation/pages/export_report_page.dart';
import '../../features/transaction/presentation/pages/add_transaction_page.dart';
import '../../features/transaction/presentation/pages/choose_category_page.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/budget/presentation/pages/budget_rules_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/wallet/presentation/pages/wallet_list_page.dart';
import '../../features/wallet/presentation/pages/wallet_add_page.dart';
import '../../features/wallet/presentation/pages/wallet_edit_page.dart';
import '../../features/wallet/presentation/pages/bank_link_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/category/presentation/pages/category_group_page.dart';
import '../../features/bill/presentation/pages/bill_page.dart';
import '../../features/bill/presentation/pages/bill_add_page.dart';
import '../../features/bill/presentation/pages/bill_edit_page.dart';
import '../../features/bill/presentation/pages/bill_delete_page.dart';
import '../../features/goal/presentation/pages/goal_page.dart';
import '../../features/goal/presentation/pages/goal_add_page.dart';
import '../../features/goal/presentation/pages/goal_detail_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';

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
const _publicRoutes = {'/login', '/register', '/forgot-password'};

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
          final authState = authBloc.state;
          final isGoingPublic = _publicRoutes.contains(state.matchedLocation);

          // AuthInitial = chưa xác định → không redirect, chờ state
          if (authState is AuthInitial || authState is AuthLoading) return null;

          final isAuthed = authState is AuthSuccess;

          // Chưa đăng nhập → bắt buộc về /login
          if (!isAuthed && !isGoingPublic) return '/login';

          // Đã đăng nhập → không cho vào lại trang login
          if (isAuthed && isGoingPublic) return '/home';

          return null; // Không cần redirect
        },

        routes: [
          // Auth routes (public)
          GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
          GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
          GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const ForgotPasswordPage()),

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
                GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
              ]),
            ],
          ),

          // Analytics & Report Export standalone routes
          GoRoute(
            path: '/export-report',
            builder: (_, __) => const ExportReportPage(),
          ),

          // Add transaction
          GoRoute(
            path: '/add',
            builder: (_, __) => const AddTransactionPage(),
            routes: [
              GoRoute(
                path: 'category',
                builder: (_, __) => const ChooseCategoryPage(),
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
          GoRoute(path: '/wallets/add', builder: (_, __) => const WalletAddPage()),
          GoRoute(path: '/bank-link', builder: (_, __) => const BankLinkPage()),
          GoRoute(
            path: '/wallets/:id/edit',
            builder: (_, s) =>
                WalletEditPage(id: s.pathParameters['id']!),
          ),

          // Budget rules
          GoRoute(
              path: '/budget/rules',
              builder: (_, __) => const BudgetRulesPage()),

          // Category
          GoRoute(path: '/categories', builder: (_, __) => const CategoryPage()),
          GoRoute(
              path: '/categories/group',
              builder: (_, __) => const CategoryGroupPage()),

          // Bill
          GoRoute(
            path: '/bills',
            builder: (_, __) => const BillPage(),
            routes: [
              GoRoute(
                path: 'delete',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const BillDeletePage(id: '1'),
              ),
            ],
          ),
          GoRoute(path: '/bills/add', builder: (_, __) => const BillAddPage()),
          GoRoute(
            path: '/bills/:id/edit',
            builder: (_, s) => BillEditPage(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/bills/:id/delete',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, s) => BillDeletePage(id: s.pathParameters['id']!),
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
        ],
      );
}
