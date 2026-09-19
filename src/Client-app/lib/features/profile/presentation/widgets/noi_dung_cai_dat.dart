import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'vung_nguy_hiem_card.dart';

/// Thân trang Cài đặt — **định nghĩa duy nhất**, dùng chung bởi tab Cá nhân và
/// route `/settings`.
///
/// ## Vì sao là widget dùng chung chứ không phải hai bản
///
/// Hai bản chép tay của cùng một khối là đúng thứ đã sinh ra **G41** và
/// **G47** trong dự án này — cả hai lần đều là một truy vấn được chép sang chỗ
/// thứ hai rồi hai bên trôi lệch, im lặng, hàng tháng trời. Nhóm D gộp tab Cá
/// nhân với trang Cài đặt (hai trang vẽ **đúng cùng** avatar + tên + email +
/// nút sửa), nên nguy cơ ấy quay lại ngay tại đây.
///
/// ## Vì sao route `/settings` vẫn giữ
///
/// Bốn route con khai báo **bên trong** nó — `/settings/change-password`,
/// `/settings/delete-account`, `/settings/edit-profile`
/// (`app_router.dart:353`–`:359`) cộng `/settings/notifications` khai riêng ở
/// `:329`. Xoá `/settings` là xoá luôn ba đường con, mà
/// `vung_nguy_hiem_card.dart:106` và chính widget này đang `push` chúng.
///
/// Cả bốn nằm **ngoài** shell, nên tab Cá nhân (trong shell) `push` chúng là
/// an toàn — bẫy `!keyReservation.contains(key)` chỉ nổ theo chiều ngược lại.
class NoiDungCaiDat extends StatelessWidget {
  const NoiDungCaiDat({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _theBaoMat(context),
        const SizedBox(height: 24),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => VungNguyHiemCard(
            user: state is AuthSuccess ? state.user : null,
          ),
        ),
      ],
    );
  }

  Widget _theBaoMat(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
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
          _mucHanhDong(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            onTap: () => context.push('/settings/edit-profile'),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          _mucHanhDong(
            icon: Icons.lock_outline,
            title: 'Đổi mật khẩu',
            onTap: () => context.push('/settings/change-password'),
          ),
          // Hai mục "Bảo mật 2 yếu tố (MFA)" và "Đồng bộ dữ liệu Cloud" đã gỡ
          // 2026-09-19: cả hai là `onTap: () {}` với công tắc luôn bật và dấu
          // tick luôn xanh — hứa hai tính năng không tồn tại. Đồng bộ thì app
          // vẫn làm, nhưng tự động và không có gì để cài đặt ở đây.
        ],
      ),
    );
  }

  Widget _mucHanhDong({
    required IconData icon,
    required String title,
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
                style: const TextStyle(fontSize: 16, color: AppColors.primary),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
