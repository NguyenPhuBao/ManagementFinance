import 'package:go_router/go_router.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/profile/presentation/pages/home_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/transaction/presentation/pages/add_transaction_page.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/budget/presentation/pages/budget_rules_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/wallet/presentation/pages/wallet_list_page.dart';
import '../../features/wallet/presentation/pages/wallet_add_page.dart';
import '../../features/wallet/presentation/pages/wallet_edit_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/category/presentation/pages/category_group_page.dart';
import '../../features/bill/presentation/pages/bill_page.dart';
import '../../features/bill/presentation/pages/bill_add_page.dart';
import '../../features/bill/presentation/pages/bill_edit_page.dart';
import '../../features/goal/presentation/pages/goal_page.dart';
import '../../features/goal/presentation/pages/goal_add_page.dart';
import '../../features/goal/presentation/pages/goal_detail_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      // Auth routes (public)
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage()),

      // Main app với Bottom Navigation (5 tabs)
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/analytics',
                builder: (_, __) => const AnalyticsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/add', builder: (_, __) => const AddTransactionPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),

      // Wallet
      GoRoute(path: '/wallets', builder: (_, __) => const WalletListPage()),
      GoRoute(path: '/wallets/add', builder: (_, __) => const WalletAddPage()),
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
      GoRoute(path: '/bills', builder: (_, __) => const BillPage()),
      GoRoute(path: '/bills/add', builder: (_, __) => const BillAddPage()),
      GoRoute(
        path: '/bills/:id/edit',
        builder: (_, s) => BillEditPage(id: s.pathParameters['id']!),
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
