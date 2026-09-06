import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cá nhân',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.primary),
          onPressed: () {},
        ),
        actions: [
          NotificationBell(
            unreadCount: currentAccountIdOrNull(context) == null
                ? null
                : sl<AppDatabase>().notificationDao.watchUnreadCount(
                    currentAccountIdOrNull(context)!),
            onTap: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildSection(
              title: 'QUẢN LÝ TÀI KHOẢN',
              items: [
                _ProfileItem(
                  icon: Icons.account_balance,
                  title: 'Hóa đơn',
                  onTap: () => context.push('/bills'),
                ),
                _ProfileItem(
                  icon: Icons.savings_outlined,
                  title: 'Mục tiêu tiết kiệm',
                  onTap: () => context.push('/goals'),
                ),
                _ProfileItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Ví',
                  onTap: () => context.push('/wallets'),
                ),
                _ProfileItem(
                  icon: Icons.category_outlined,
                  title: 'Danh mục tùy chỉnh',
                  onTap: () => context.push('/categories'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'CÀI ĐẶT',
              items: [
                _ProfileItem(
                  icon: Icons.notifications_none,
                  title: 'Thông báo',
                  // Mục này dẫn tới trang CÀI ĐẶT thông báo, không phải trung
                  // tâm thông báo — lối vào trung tâm là chuông ở trang chủ.
                  onTap: () => context.push('/settings/notifications'),
                ),
                _ProfileItem(
                  icon: Icons.dark_mode_outlined,
                  title: 'Giao diện',
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.light_mode, size: 14, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 40,
                          height: 24,
                          child: Center(
                            child: Icon(Icons.dark_mode_outlined, size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {},
                ),
                _ProfileItem(
                  icon: Icons.shield_outlined,
                  title: 'Thông tin và bảo mật',
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
            const SizedBox(height: 24),
            const Text(
              'FlowMoney v2.4.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = (state is AuthSuccess) ? state.user : null;
        final name = (user?.name != null && user!.name.isNotEmpty)
            ? user.name
            : ((user?.username != null && user!.username.isNotEmpty)
                ? user.username
                : 'Người dùng');
        final email = user?.email ?? '';

        return Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFFC4E0E5),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSection({required String title, required List<_ProfileItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: items[index].onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(items[index].icon, color: AppColors.textSecondary, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                items[index].title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            items[index].trailing ??
                                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, size: 20),
      onPressed: () async {
        // Hiện dialog xác nhận
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: const Text('Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
                'Bạn có chắc muốn đăng xuất không?\nBạn vẫn có thể đăng nhập offline sau khi đăng xuất.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          context.read<AuthBloc>().add(LogoutRequested());
          context.go('/login');
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error, width: 1),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      label: const Text(
        'Đăng xuất',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  _ProfileItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });
}
