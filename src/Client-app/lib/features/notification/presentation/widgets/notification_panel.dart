import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/theme/app_colors.dart';

/// Panel thông báo rút gọn trên trang chủ — bám thiết kế Stitch: tiêu đề
/// "Thông báo", ba mục mới nhất, liên kết "Xem tất cả".
///
/// Danh sách rỗng thì **ẩn cả panel** thay vì hiện khung trống: một khung trống
/// chiếm chỗ trên màn hình chính mà không nói gì thì tệ hơn là không có.
class NotificationPanel extends StatelessWidget {
  final int? idaccount;

  /// Cho phép test bơm dữ liệu mà không cần dựng DI.
  final Stream<List<AppNotification>>? feed;

  const NotificationPanel({super.key, required this.idaccount, this.feed});

  static const int _soMucHienThi = 3;

  @override
  Widget build(BuildContext context) {
    final id = idaccount;
    final stream = feed ??
        (id == null
            ? null
            : sl<AppDatabase>()
                .notificationDao
                .watchFeed(id, limit: _soMucHienThi));
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<AppNotification>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <AppNotification>[])
            .take(_soMucHienThi)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          key: const ValueKey('notification-panel'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in items) _Muc(item: item),
            ],
          ),
        );
      },
    );
  }
}

class _Muc extends StatelessWidget {
  final AppNotification item;
  const _Muc({required this.item});

  Color get _mau => switch (item.severity) {
        'critical' => AppColors.error,
        'warning' => AppColors.expense,
        _ => AppColors.income,
      };

  IconData get _bieuTuong => switch (item.subjectType) {
        'budget' => Icons.pie_chart_outline,
        'bill' => Icons.receipt_long,
        'goal' => Icons.savings_outlined,
        'sync' => Icons.sync_problem,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _mau.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_bieuTuong, size: 16, color: _mau),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  relativeTimeVi(item.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
