import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/xac_nhan_dang_xuat.dart';
import '../widgets/noi_dung_cai_dat.dart';

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
        // Không có hamburger: tab này không có drawer. Bản trước vẽ nút với
        // `onPressed: () {}` — vẽ như sống mà bấm không làm gì (UX 2026-09-19).
        automaticallyImplyLeading: false,
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
            // Nhóm "QUẢN LÝ TÀI KHOẢN" (Hóa đơn, Mục tiêu, Ví, Danh mục) đã
            // bỏ hẳn ngày 2026-09-19 (nhóm D): bốn mục ấy lặp lại đúng drawer,
            // và lối B cho drawer giữ module còn tab này giữ hồ sơ + cài đặt.
            // Cùng lúc, xung đột icon heo đất biến mất — `Icons.savings` là
            // Ngân sách ở drawer, `Icons.savings_outlined` từng là Mục tiêu
            // tiết kiệm ở đây (D8).
            //
            // Thân trang `/settings` nay nằm ngay tại đây thay vì sau một cú
            // nhảy tới một trang vẽ ĐÚNG cái avatar phía trên lần nữa.
            const NoiDungCaiDat(),
            const SizedBox(height: 24),
            _buildSection(
              title: 'CÀI ĐẶT',
              items: [
                _ProfileItem(
                  icon: Icons.notifications_none,
                  // D7: tên cũ "Thông báo" lẫn với TRUNG TÂM thông báo, thứ
                  // vào bằng chuông ở Trang chủ — hai chỗ khác hẳn nhau. Đây
                  // là trang CÀI ĐẶT thông báo.
                  title: 'Cài đặt thông báo',
                  onTap: () => context.push('/settings/notifications'),
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
        final confirmed = await xacNhanDangXuat(context);
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

  _ProfileItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
