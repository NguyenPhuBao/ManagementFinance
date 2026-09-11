import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../shared/theme/app_colors.dart';
import '../widgets/home_action_buttons.dart';
import '../widgets/home_budget_card.dart';
import '../widgets/home_goal_card.dart';
import '../widgets/the_cho_xoa_trang_chu.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/data/repositories/budget_repository.dart';
import '../../../goal/data/models/goal_entity.dart';
import '../../../goal/data/repositories/goal_repository.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../../transaction/presentation/widgets/transaction_row_content.dart';
import '../../../wallet/domain/vi_tinh_vao_tong.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = sl<AppDatabase>();
    final authState = context.watch<AuthBloc>().state;
    int? currentUserId;
    if (authState is AuthSuccess && authState.user != null) {
      currentUserId = int.tryParse(authState.user!.id);
      if (currentUserId != null && sl.isRegistered<SyncEngine>()) {
        sl<SyncEngine>().start(idaccount: currentUserId);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, currentUserId),
              // Thẻ nhắc tài khoản đang chờ xoá (G33) — spec cưỡng chế đăng xuất §5.2.
              if (authState is AuthSuccess &&
                  authState.user != null &&
                  authState.user!.dangChoXoa) ...[
                const SizedBox(height: 24),
                TheChoXoaTrangChu(user: authState.user!),
              ],
              const SizedBox(height: 32),
              _buildHeroSection(context),
              const SizedBox(height: 32),

              // Khối thông báo đã được GỠ khỏi trang chủ ngày 2026-09-08 theo
              // yêu cầu người dùng: thông báo chỉ xem khi bấm vào chức năng đó,
              // tức cái chuông ở `_buildHeader` (dẫn tới `/notifications`).
              //
              // ⚠️ Đây là chỗ **đi lệch thiết kế Stitch** màn Home, nơi khối
              // thông báo nằm ngay đầu trang. Ghi ra để lần sau đối chiếu với
              // Stitch thì biết đây là lệch có chủ ý, không phải bỏ sót.
              //
              // `NotificationPanel` vẫn còn trong mã nguồn dù nay không nơi nào
              // dựng nó: hai trang thông báo trích dẫn nó làm **mẫu** cho lối
              // "trang không tự đi hỏi `AuthBloc`", và test của nó canh đúng
              // lối ấy.

              // Reactive Total Asset Balance from SQLite Wallets
              Builder(
                builder: (context) {
                  final authState = context.watch<AuthBloc>().state;
                  int? currentUserId;
                  if (authState is AuthSuccess && authState.user != null) {
                    currentUserId = int.tryParse(authState.user!.id);
                  }

                  final walletStream = (currentUserId != null)
                      ? db.walletDao.watchAll(currentUserId)
                      : Stream<List<Wallet>>.value([]);

                  return StreamBuilder<List<Wallet>>(
                    stream: walletStream,
                    builder: (context, snapshot) {
                      final wallets = snapshot.data ?? [];
                      // Phép lọc nằm ở `viTinhVaoTong`, định nghĩa DUY NHẤT của
                      // "ví nào được cộng vào tổng tài sản". Bản trước ở đây là
                      // `fold` trần trên mọi ví: nó cộng cả ví người dùng đã cố ý
                      // tắt "Tính vào tổng tài sản", nên con số trang chủ lệch
                      // với chính con số trên màn Quản lý ví — im lặng, không màn
                      // nào nói ra. Cùng loại lỗi đã đóng ở `6fd2ce9`.
                      final totalBalance = wallets
                          .where((w) => viTinhVaoTong(
                              includeInTotal: w.includeInTotal, status: w.status))
                          .fold<double>(0.0, (sum, w) => sum + w.balance);
                      if (snapshot.hasData) {
                        debugPrint('📊 [SQLite DB Log] Wallets count: ${wallets.length} | Total balance: ${CurrencyFormatter.formatSoThoi(totalBalance)}đ');
                        for (final w in wallets) {
                          debugPrint('   • Ví "${w.name}" (Account ${w.idaccount}): ${CurrencyFormatter.formatSoThoi(w.balance)}đ');
                        }
                      }
                      return _buildAssetCard(totalBalance);
                    },
                  );
                },
              ),
              const SizedBox(height: 32),

              _buildQuickActions(context),
              const SizedBox(height: 32),

              // Reactive Monthly Stats & Recent Transactions from SQLite Transactions (Filtered by User)
              Builder(
                builder: (context) {
                  final authState = context.watch<AuthBloc>().state;
                  int? currentUserId;
                  if (authState is AuthSuccess && authState.user != null) {
                    currentUserId = int.tryParse(authState.user!.id);
                  }

                  final txStream = (currentUserId != null)
                      ? db.transactionDao.watchAll(currentUserId)
                      : Stream<List<Transaction>>.value([]);
                  // Tên ví/danh mục cho "Giao dịch gần đây" — cùng nội dung
                  // dòng với sổ giao dịch (`buildTransactionRowContent`).
                  final walletStream = (currentUserId != null)
                      ? db.walletDao.watchAll(currentUserId)
                      : Stream<List<Wallet>>.value(const []);
                  final categoryStream = (currentUserId != null)
                      ? db.categoryDao.watchAll(currentUserId)
                      : Stream<List<Category>>.value(const []);

                  return StreamBuilder<List<Transaction>>(
                    stream: txStream,
                    builder: (context, snapshot) {
                      final transactions = snapshot.data ?? [];
                      final now = DateTime.now();

                      if (snapshot.hasData) {
                        debugPrint('💳 [SQLite DB Log] Transactions count: ${transactions.length}');
                        for (final t in transactions.take(5)) {
                          debugPrint('   • Giao dịch: [${t.type.toUpperCase()}] ${CurrencyFormatter.formatSoThoi(t.amount)}đ | Ghi chú: ${t.note} | Account: ${t.idaccount}');
                        }
                      }

                      double monthlyIncome = 0;
                      double monthlyExpense = 0;

                      for (final t in transactions) {
                        if (t.date.year == now.year && t.date.month == now.month) {
                          if (t.type == 'thu') monthlyIncome += t.amount;
                          if (t.type == 'chi') monthlyExpense += t.amount;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsGrid(monthlyIncome, monthlyExpense),
                          const SizedBox(height: 32),
                          StreamBuilder<List<Wallet>>(
                            stream: walletStream,
                            builder: (_, wallets) =>
                                StreamBuilder<List<Category>>(
                              stream: categoryStream,
                              builder: (_, categories) =>
                                  _buildRecentTransactions(
                                context,
                                transactions.take(5).toList(),
                                TransactionLookup(
                                  wallets: wallets.data ?? const [],
                                  categories: categories.data ?? const [],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 32),
              _buildGoalSection(context, currentUserId),
              const SizedBox(height: 32),
              _buildBudgetSection(context, currentUserId),
              const SizedBox(height: 32),
              _buildInsightCard(),
              const SizedBox(height: 100), // padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int? idaccount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primary, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'FlowMoney',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        // Chấm đỏ trước đây vẽ CỨNG ở đây — luôn sáng dù chẳng có thông báo
        // nào. Nay đếm thật từ bảng thông báo cục bộ.
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: NotificationBell(
            unreadCount: idaccount == null
                ? null
                : sl<AppDatabase>().notificationDao.watchUnreadCount(idaccount),
            onTap: () => context.push('/notifications'),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final user = (state is AuthSuccess) ? state.user : null;
                final name = (user?.name != null && user!.name.isNotEmpty)
                    ? user.name
                    : ((user?.username != null && user!.username.isNotEmpty)
                        ? user.username
                        : 'Người dùng');
                final email = user?.email ?? '';

                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: AppColors.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildDrawerItem(context, 'Quản lý ví', Icons.account_balance_wallet, '/wallets'),
                  _buildDrawerItem(context, 'Mục tiêu tiết kiệm', Icons.track_changes, '/goals'),
                  _buildDrawerItem(context, 'Ngân sách', Icons.savings, '/budget'),
                  _buildDrawerItem(context, 'Hóa đơn & Dịch vụ', Icons.receipt_long, '/bills'),
                  _buildDrawerItem(context, 'Thống kê', Icons.analytics, '/analytics'),
                  _buildDrawerItem(context, 'Xuất báo cáo', Icons.description, '/reports'),
                  _buildDrawerItem(context, 'Trợ lý AI', Icons.smart_toy, '/ai-chat'),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.outlineVariant),
                  const SizedBox(height: 16),
                  _buildDrawerItem(context, 'Cá nhân', Icons.person, '/profile'),
                  _buildDrawerItem(context, 'Cài đặt', Icons.settings, '/settings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        context.pop(); // close drawer
        if (route == '/reports') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng Xuất báo cáo đang phát triển')));
        } else {
          context.push(route);
        }
      },
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF111827), Color(0xFF4B5563)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: const Text(
            'Kiểm soát tiền bạc.\nLàm chủ tương lai.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
              color: Colors.white, // required for ShaderMask
            ),
          ),
        ),
        const SizedBox(height: 24),
        HomeActionButtons(
          onAdd: () => context.push('/add'),
          onReport: () => context.go('/analytics'),
        ),
      ],
    );
  }

  Widget _buildAssetCard(double totalBalance) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng số dư ví',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Số dư thực tế',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.income,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${CurrencyFormatter.formatSoThoi(totalBalance)}đ',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(
          context: context,
          icon: Icons.account_balance_wallet_outlined,
          label: 'Thêm thu',
          isDark: true,
          onTap: () => context.push('/add'),
        ),
        _buildActionItem(
          context: context,
          icon: Icons.payments_outlined,
          label: 'Thêm chi',
          isDark: true,
          onTap: () => context.push('/add'),
        ),
        _buildActionItem(
          context: context,
          icon: Icons.sync_alt,
          label: 'Chuyển',
          isDark: false,
          onTap: () => context.push('/add'),
        ),
        _buildActionItem(
          context: context,
          icon: Icons.qr_code_scanner,
          label: 'Quét',
          isDark: false,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng Quét QR đang phát triển')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.primary : Colors.white,
              border: isDark ? null : Border.all(color: Colors.black12),
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF1A1A19), Color(0xFF374151)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(double income, double expense) {
    final net = income - expense;
    return Row(
      children: [
        Expanded(child: _buildStatCard('Thu nhập', '${CurrencyFormatter.formatSoThoi(income)}đ', income > 0 ? 0.8 : 0.0, AppColors.income)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Chi tiêu', '${CurrencyFormatter.formatSoThoi(expense)}đ', expense > 0 ? 0.4 : 0.0, AppColors.error)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('Thu net', '${net >= 0 ? '+' : ''}${CurrencyFormatter.formatSoThoi(net)}đ', net != 0 ? 0.6 : 0.0, const Color(0xFF3B82F6))),
      ],
    );
  }

  Widget _buildStatCard(String label, String amount, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    List<Transaction> transactions,
    TransactionLookup lookup,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GIAO DỊCH GẦN ĐÂY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/transactions'),
              child: const Text('Xem tất cả',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long, color: AppColors.outline, size: 36),
                SizedBox(height: 8),
                Text(
                  'Chưa có giao dịch nào',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...transactions.map((tx) {
            // Cùng nội dung dòng với sổ giao dịch: danh mục, ví, icon/màu.
            final content = buildTransactionRowContent(
              TransactionEntity.fromDrift(tx),
              lookup,
            );
            return _buildTransactionItem(
              content,
              '${content.subtitle} • ${DateFormat('dd/MM').format(tx.date)}',
            );
          }),
      ],
    );
  }

  Widget _buildTransactionItem(TransactionRowContent content, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: content.colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(content.icon, color: content.colour, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(content.amountText,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: content.amountColor)),
        ],
      ),
    );
  }

  /// Thẻ ngân sách — dữ liệu thật qua `watchBudgets` (phát lại cả khi có giao
  /// dịch mới), thay placeholder cứng tồn tại tới 2026-09-06. Bấm thẻ nhảy
  /// sang tab Ngân sách bằng `go`: trang chủ và tab ấy cùng nằm trong shell.
  /// Khối "Mục tiêu tiết kiệm" — cùng khuôn với [_buildBudgetSection].
  ///
  /// Trước 2026-09-08 mục tiêu chỉ vào được qua **một dòng trong drawer**,
  /// trong khi ngân sách đã có hẳn một khối ở đây.
  ///
  /// Chạm vào đi tới `/goals` bằng **`push`**, không phải `go`: `/goals` nằm
  /// NGOÀI `StatefulShellRoute`, và `go` từ trong shell sẽ thay cả stack thay
  /// vì chồng lên — người dùng mất nút quay lại. Cùng bẫy 7.8
  /// `NOTIFICATION_FEATURE.md`, chỗ `_buildBudgetSection` dùng `go` vì
  /// `/budget` thì ngược lại, nó **thuộc** shell.
  Widget _buildGoalSection(BuildContext context, int? idaccount) {
    final stream = idaccount != null
        ? sl<GoalRepository>().watchGoals(idaccount)
        : Stream<List<GoalEntity>>.value(const []);
    return StreamBuilder<List<GoalEntity>>(
      stream: stream,
      builder: (_, snapshot) => HomeGoalCard(
        goals: snapshot.data ?? const [],
        onTap: () => context.push('/goals'),
      ),
    );
  }

  Widget _buildBudgetSection(BuildContext context, int? idaccount) {
    final stream = idaccount != null
        ? sl<BudgetRepository>().watchBudgets(idaccount)
        : Stream<List<BudgetView>>.value(const []);
    return StreamBuilder<List<BudgetView>>(
      stream: stream,
      builder: (_, snapshot) => HomeBudgetCard(
        budgets: snapshot.data ?? const [],
        onTap: () => context.go('/budget'),
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1b),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFFDE047), size: 24),
              const SizedBox(width: 12),
              const Text('Insight AI',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    const Text('Mới', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Thêm thêm giao dịch thu/chi hàng ngày để trợ lý AI phân tích và đưa ra lời khuyên tài chính cá nhân hóa.',
            style: TextStyle(
                fontSize: 14, color: Colors.white70, height: 1.5, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}
