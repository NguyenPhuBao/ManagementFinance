import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/goal_entity.dart';
import '../../domain/goal_history_filter.dart';
import '../../domain/goal_stats.dart';

/// Thẻ ba con số của mục tiêu: số lần nạp, trung bình mỗi lần, chuỗi liên tiếp.
///
/// Ba con số đều đọc từ lịch sử đã có — không cột mới, không truy vấn mới. Thẻ
/// đứng giữa biểu đồ và danh sách lịch sử vì nó tóm tắt đúng chuỗi mà biểu đồ
/// vẽ ra và danh sách liệt kê.
///
/// Mọi phép tính nằm ở `goal_stats.dart` và được test ở đó; tệp này chỉ vẽ.
class GoalStatsCard extends StatelessWidget {
  final GoalEntity goal;

  /// Lịch sử tích luỹ, thứ tự nào cũng được — tầng thuần tự sắp lại.
  final List<KhoanTichLuy> khoan;

  /// `null` = đồng hồ máy; test truyền mốc cố định.
  final DateTime? now;

  const GoalStatsCard({
    super.key,
    required this.goal,
    required this.khoan,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final tk = thongKeMucTieu(
      khoan: khoan,
      ngayBatDau: goal.startDate,
      chuKy: goal.cycleTakeMoney,
      now: now ?? DateTime.now(),
    );
    // Chưa có khoản nạp nào thì cả ba con số đều vô nghĩa.
    if (tk == null) return const SizedBox.shrink();

    final tien = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final chuoi = tk.chuoiKy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _O(soLieu: '${tk.soLanNap}', nhan: 'lần nạp'),
            const _VachDoc(),
            _O(
              soLieu: tien.format(tk.trungBinhMoiLan),
              nhan: 'trung bình mỗi lần',
            ),
            // Không có mốc gốc thì không cắt được kỳ. Một ô trống mang nhãn
            // "liên tiếp" vẫn hứa một con số mà app không có.
            if (chuoi != null) ...[
              const _VachDoc(),
              _O(
                soLieu: '$chuoi',
                nhan: '${tenDonViKy(goal.cycleTakeMoney)} liên tiếp',
                mauSoLieu: AppColors.income,
                // Ngọn lửa chỉ có nghĩa khi chuỗi đang cháy thật. Gắn nó vào
                // một số 0 là chúc mừng người dùng vì đã bỏ dở.
                icon: chuoi > 0 ? Icons.local_fire_department_rounded : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một ô: con số ở trên, nhãn ở dưới, căn giữa.
class _O extends StatelessWidget {
  final String soLieu;
  final String nhan;
  final Color? mauSoLieu;
  final IconData? icon;

  const _O({
    required this.soLieu,
    required this.nhan,
    this.mauSoLieu,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final mau = mauSoLieu ?? AppColors.textPrimary;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: mau),
                const SizedBox(width: 4),
              ],
              // `Flexible`, không phải `Text` trần: số tiền bảy chữ số trong
              // một ô rộng một phần ba màn 411dp là chỗ tràn thật, và font của
              // bộ test còn rộng gấp đôi ngoài đời.
              Flexible(
                child: Text(
                  soLieu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mau,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            nhan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vạch dọc ngăn hai ô, cao bằng ô cao nhất nhờ `IntrinsicHeight` ở ngoài.
class _VachDoc extends StatelessWidget {
  const _VachDoc();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.outlineVariant.withValues(alpha: 0.6),
      );
}
