import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Chuông thông báo dùng chung cho cả ba trang có nó (home, goal, profile).
///
/// Chấm đỏ **suy từ dữ liệu thật**. Bản trước vẽ cứng nó ở `home_page.dart`
/// nên nó luôn sáng, và một chấm đỏ luôn sáng dạy người dùng bỏ qua nó.
///
/// [unreadCount] là `null` khi chưa có phiên đăng nhập — không có tài khoản nào
/// để đếm, nên không chấm và bấm không dẫn đi đâu. Cùng tinh thần với
/// `currentAccountIdOrNull`: thiếu danh tính thì hiển thị rỗng, không đoán.
class NotificationBell extends StatelessWidget {
  final Stream<int>? unreadCount;
  final VoidCallback? onTap;
  final Color color;

  const NotificationBell({
    super.key,
    required this.unreadCount,
    this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final stream = unreadCount;

    return InkWell(
      onTap: stream == null ? null : onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications, color: color),
            if (stream != null)
              Positioned(
                top: 12,
                right: 12,
                child: StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snapshot) {
                    final chuaDoc = snapshot.data ?? 0;
                    if (chuaDoc <= 0) return const SizedBox.shrink();
                    return Container(
                      key: const ValueKey('notification-bell-dot'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
