import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/noi_dung_cai_dat.dart';

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
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        // Nút "hỗ trợ" đã gỡ 2026-09-19: `onPressed: () {}`, và dự án chưa có
        // kênh hỗ trợ nào để trỏ tới.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUserSummaryCard(),
            const SizedBox(height: 24),
            // Thân trang nay là widget dùng chung với tab Cá nhân (nhóm D,
            // 2026-09-19). Route này GIỮ NGUYÊN vì bốn route con khai báo
            // bên trong nó — xem `NoiDungCaiDat`.
            const NoiDungCaiDat(),
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
                tooltip: 'Sửa',
                icon: const Icon(Icons.edit, color: AppColors.textSecondary),
                onPressed: () => context.push('/settings/edit-profile'),
              ),
            ],
          ),
        );
      },
    );
  }

}
