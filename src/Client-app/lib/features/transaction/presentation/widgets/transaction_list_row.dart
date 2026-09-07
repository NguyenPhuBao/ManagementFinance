import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../../domain/transaction_lookup.dart';
import '../../domain/transaction_owner.dart';
import 'transaction_row_content.dart';

/// Một dòng trong sổ giao dịch: vuốt trái để xoá.
///
/// Khoản thuộc mục tiêu hay hoá đơn thì `confirmDismiss` trả `false` — hàng
/// bật lại và một SnackBar chỉ đường tới nơi xoá đúng — vì xoá ở đây chỉ hoàn
/// ví, không đụng tới bộ đếm/cờ của thực thể kia (xem `transactionOwnerOf`).
/// Nội dung hiển thị do [buildTransactionRowContent] tính. Tách khỏi
/// `TransactionPage` để test được mà không cần `sl` lẫn `AuthBloc`.
class TransactionListRow extends StatelessWidget {
  const TransactionListRow({
    super.key,
    required this.transaction,
    required this.onDelete,
    this.lookup,
    this.onTap,
  });

  final TransactionEntity transaction;
  final VoidCallback onDelete;

  /// Bấm vào dòng — trang mở bảng chi tiết. `null` thì dòng không phản ứng.
  final VoidCallback? onTap;

  /// Tra tên ví/danh mục; `null` thì mọi ví hiện là "Ví đã xoá" và không có
  /// danh mục — chỉ dành cho test dựng dòng đơn lẻ.
  final TransactionLookup? lookup;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final content =
        buildTransactionRowContent(tx, lookup ?? TransactionLookup.empty);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final lyDo = lyDoKhongXoaTaiSo(transactionOwnerOf(tx));
        if (lyDo == null) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lyDo)),
        );
        return false;
      },
      onDismissed: (_) {
        onDelete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa giao dịch')),
        );
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.surfaceContainer,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Vòng tròn nền màu danh mục ở 12% — cùng ý "chip 10% màu danh
            // mục, chữ 100%" trong design system Kinetic Finance.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: content.colour.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(content.icon, color: content.colour, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              content.amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: content.amountColor,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
