import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/models/transaction_type_label.dart';
import '../../domain/transaction_lookup.dart';
import '../../domain/transaction_owner.dart';
import 'transaction_row_content.dart';

/// Bảng chi tiết mở khi bấm một dòng trong sổ giao dịch.
///
/// Đọc đủ: số tiền, danh mục, ví (hoặc ví nguồn → ví đích), ngày giờ; tiêu
/// đề là ghi chú (không có thì tên danh mục) nên không lặp lại hàng "Ghi chú".
/// Là nơi duy nhất có nút Sửa. Khoản thuộc mục tiêu/hoá đơn chỉ đọc — cùng
/// quy tắc với chặn xoá (`transactionOwnerOf`): sửa số tiền của khoản nạp mà
/// không qua mục tiêu là làm lệch `current_amount` y như xoá.
class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.lookup,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionEntity transaction;
  final TransactionLookup lookup;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final content = buildTransactionRowContent(tx, lookup);
    final lyDo = lyDoKhongXoaTaiSo(transactionOwnerOf(tx));
    final isTransfer = tx.type == 'transfer';
    final category = lookup.category(tx.categoryId);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: content.colour.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(content.icon, color: content.colour, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  content.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content.amountText,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: content.amountColor,
            ),
          ),
          const SizedBox(height: 16),
          if (!isTransfer) ...[
            _row('Loại', transactionTypeLabel(tx.type)),
            _row('Danh mục', category?.name ?? '—'),
            _row('Ví', lookup.walletName(tx.walletId)),
          ] else ...[
            _row('Từ ví', lookup.walletName(tx.walletId)),
            _row('Đến ví', lookup.walletName(tx.walletTransfer)),
          ],
          _row('Ngày', DateFormat('dd/MM/yyyy HH:mm').format(tx.date)),
          const SizedBox(height: 20),
          if (lyDo != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lyDo,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Xoá giao dịch'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Sửa giao dịch'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
}
