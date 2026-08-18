import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cài đặt & Bảo mật tài khoản',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUserSummaryCard(),
            const SizedBox(height: 24),
            _buildSecurityPreferencesCard(context),
            const SizedBox(height: 24),
            _buildDangerZoneCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSummaryCard() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = (state is AuthSuccess) ? state.user : null;
        final name = (user?.name != null && user!.name.isNotEmpty)
            ? user.name
            : ((user?.username != null && user!.username.isNotEmpty)
                ? user.username
                : 'Người dùng');
        final email = user?.email ?? '';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDEE1F8), width: 2),
                ),
                child: CircleAvatar(
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
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF96F592),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, size: 14, color: Color(0xFF0A7320)),
                          SizedBox(width: 4),
                          Text(
                            'Tài khoản Premium',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A7320)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurityPreferencesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'BẢO MẬT & TÙY CHỌN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildActionItem(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {},
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          _buildActionItem(
            icon: Icons.lock_outline,
            title: 'Đổi mật khẩu',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () => context.push('/settings/change-password'),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          _buildActionItem(
            icon: Icons.verified_user_outlined,
            title: 'Bảo mật 2 yếu tố (MFA)',
            trailing: Switch(
              value: true,
              onChanged: (val) {},
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF006E1C),
            ),
            onTap: () {},
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          _buildActionItem(
            icon: Icons.cloud_sync_outlined,
            title: 'Đồng bộ dữ liệu Cloud',
            trailing: const Icon(Icons.check_circle, color: Color(0xFF006E1C)),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A)),
              SizedBox(width: 8),
              Text(
                'Vùng nguy hiểm (Danger Zone)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBA1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Khi gửi yêu cầu xóa tài khoản, tất cả lịch sử giao dịch, ví tiền và mục tiêu sẽ bị đóng vĩnh viễn sau 30 ngày khôi phục.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/settings/delete-account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF1453B),
              side: const BorderSide(color: Color(0xFFF1453B), width: 2),
              minimumSize: const Size(double.infinity, 50),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Yêu cầu xóa tài khoản',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

