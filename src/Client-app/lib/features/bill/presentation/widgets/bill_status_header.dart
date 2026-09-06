import 'package:flutter/material.dart';

/// Hàng đầu của thẻ hoá đơn: tên + hạn trả bên trái, chip trạng thái bên phải.
///
/// Tách khỏi `bill_page.dart` để **test được ở nhiều bề rộng màn hình**. Nó
/// từng tràn khi tên hoá đơn dài: một `Text` không co được đặt cạnh chip bề
/// rộng cố định thì chữ dài bao nhiêu cũng chiếm bấy nhiêu, và chip bị đẩy ra
/// ngoài. Chrome 1280px không bao giờ thấy — chỉ lộ ra ở màn điện thoại thật.
class BillStatusHeader extends StatelessWidget {
  const BillStatusHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.titleColor,
    this.isPaid = false,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final Color titleColor;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `Expanded` là thứ chặn tràn: phần chữ nhận đúng chỗ còn lại sau khi
        // chip lấy phần của nó, và `ellipsis` cắt gọn thay vì đẩy chip ra rìa.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF46464C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            // Chip chỉ rộng bằng nội dung của nó; không có dòng này thì trong
            // một Row cha đã chật, chip lại đòi chiếm hết chỗ còn lại.
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPaid) ...[
                Icon(Icons.check_circle, color: statusColor, size: 14),
                const SizedBox(width: 4),
              ],
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
