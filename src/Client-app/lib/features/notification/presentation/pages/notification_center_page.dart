import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/notification/notification_deeplink.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/theme/app_colors.dart';

/// Trung tâm thông báo — màn "Xem tất cả" từ panel trên trang chủ.
///
/// Thiết kế Stitch chưa vẽ màn này (chỉ có panel rút gọn trên Home), nên bố cục
/// bám hệ màu và kiểu thẻ đang dùng thật trong `AppColors`.
class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context);
    final dao = sl<AppDatabase>().notificationDao;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (idaccount != null)
            StreamBuilder<int>(
              stream: dao.watchUnreadCount(idaccount),
              builder: (context, snapshot) {
                final chuaDoc = snapshot.data ?? 0;
                return TextButton(
                  onPressed:
                      chuaDoc == 0 ? null : () => dao.markAllRead(idaccount),
                  child: Text(
                    'Đọc tất cả',
                    style: TextStyle(
                      color: chuaDoc == 0
                          ? AppColors.outlineVariant
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: idaccount == null
          ? const _Rong(loi: 'Vui lòng đăng nhập để xem thông báo.')
          : StreamBuilder<List<AppNotification>>(
              stream: dao.watchFeed(idaccount),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _Rong(loi: 'Chưa có thông báo nào.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ThongBaoTile(
                    item: items[i],
                    onTap: () {
                      dao.markRead(items[i].id);
                      final route = items[i].deeplink;
                      if (route == null) return;
                      // `go` chứ không `push` cho route thuộc thanh tab: push
                      // dựng thêm một bản shell thứ hai chồng lên bản đang có,
                      // hai bản trùng page key và Navigator ném assertion —
                      // app chết màn đỏ. Xem `notification_deeplink.dart`.
                      if (thuocThanhTab(route)) {
                        context.go(route);
                      } else {
                        context.push(route);
                      }
                    },
                    onDismiss: () => dao.dismiss(items[i].id),
                  ),
                );
              },
            ),
    );
  }
}

class _ThongBaoTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ThongBaoTile({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

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
    final daDoc = item.readAt != null;

    return Dismissible(
      key: ValueKey('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: daDoc ? AppColors.surfaceContainerLow : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0DB)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dải màu chỉ vẽ cho mục CHƯA đọc: đã đọc rồi thì nó chỉ còn là
                // nhiễu thị giác.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: daDoc ? Colors.transparent : _mau,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _mau.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_bieuTuong, size: 18, color: _mau),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: daDoc
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                relativeTimeVi(item.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rong extends StatelessWidget {
  final String loi;
  const _Rong({required this.loi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 56, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Text(loi,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
