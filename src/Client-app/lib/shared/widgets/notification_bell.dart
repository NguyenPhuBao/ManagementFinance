import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nhãn số trên chuông (`docs/Notification/Notification_Client-app.md` §3.5 A): `null` khi không có gì chưa đọc (ẩn),
/// đúng số từ 1 tới 99, `99+` khi lớn hơn.
String? nhanSoChuaDoc(int soChuaDoc) {
  if (soChuaDoc <= 0) return null;
  return soChuaDoc > 99 ? '99+' : '$soChuaDoc';
}

/// Chuông thông báo dùng chung cho cả ba trang có nó (home, goal, profile).
///
/// Số đếm **suy từ dữ liệu thật** (`NotificationDao.watchUnreadCount`: chưa đọc và chưa gạt). Bản đầu vẽ cứng một chấm
/// đỏ ở `home_page.dart` nên nó luôn sáng, và một dấu luôn sáng dạy người dùng bỏ qua nó. Từ 2026-09-30 chấm đỏ thành
/// **số** (việc duy nhất client nhận từ tài liệu thông báo của backend).
///
/// [unreadCount] là `null` khi chưa có phiên đăng nhập — không có tài khoản nào để đếm, nên không số và bấm không dẫn đi
/// đâu. Cùng tinh thần với `currentAccountIdOrNull`: thiếu danh tính thì hiển thị rỗng, không đoán.
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
    if (stream == null) return _nut(null);
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) => _nut(nhanSoChuaDoc(snapshot.data ?? 0)),
    );
  }

  Widget _nut(String? so) {
    final bam = unreadCount == null ? null : onTap;
    return Semantics(
      button: true,
      label: so == null ? 'Thông báo' : 'Thông báo, $so chưa đọc',
      onTap: bam,
      excludeSemantics: true,
      child: InkWell(
        onTap: bam,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.notifications, color: color),
              if (so != null)
                // Neo MÉP PHẢI: số dài (`99+`) mọc sang trái đè lên chuông, không tràn khỏi nút 48 × 48 — Stack cắt
                // phần tràn, và nút phình ra là đẩy các nút khác trên thanh tiêu đề.
                Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    key: const ValueKey('notification-bell-so'),
                    height: 18,
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      so,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
