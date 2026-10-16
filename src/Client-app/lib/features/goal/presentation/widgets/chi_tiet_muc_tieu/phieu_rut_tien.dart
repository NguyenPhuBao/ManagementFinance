/// Phiếu "Rút khỏi mục tiêu" của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn khỏi
/// `_showWithdrawDialog` (đợt tách bốn trang lớn, spec 2026-10-13 mục 5.2). Phiếu tự kiểm số tiền như cũ; phần ghi
/// xuống CSDL, đóng phiếu, báo và nạp lại nằm ở [onXacNhan] của trang.
library;

import 'package:flutter/material.dart';

import '../../../../wallet/data/models/wallet_entity.dart';
import '../../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/goal_entity.dart';

/// Mở phiếu rút. [layMucTieu] là getter (không phải giá trị) để thân phiếu đọc mục tiêu **sống** như cũ.
void moPhieuRutTien({
  required BuildContext context,
  required GoalEntity Function() layMucTieu,
  required List<WalletEntity> wallets,
  required WalletEntity viTichLuy,
  required String idNhanMacDinh,
  required Future<void> Function(BuildContext ctx, double soTien, WalletEntity viNhan)
      onXacNhan,
}) {
  final amountController = TextEditingController();
  final viNhanKhaDung = wallets.where((w) => w.id != viTichLuy.id).toList();
  WalletEntity selectedTargetWallet =
      viNhanKhaDung.firstWhere((w) => w.id == idNhanMacDinh);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rút khỏi ${layMucTieu().name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mục tiêu đang giữ ${CurrencyFormatter.format(layMucTieu().currentAmount)} '
              'trong ví "${viTichLuy.name}".',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: const [GioiHanSoChuSo(kSoChuSoToiDaSoTien)],
              autofocus: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
              decoration: InputDecoration(
                labelText: 'Số tiền muốn rút (VNĐ)',
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chuyển về ví nào',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<WalletEntity>(
                  value: selectedTargetWallet,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more, color: AppColors.primary),
                  items: viNhanKhaDung
                      .map((w) => DropdownMenuItem<WalletEntity>(
                            value: w,
                            child: Text(
                              '${w.name} (Số dư: ${CurrencyFormatter.format(w.balance)})',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setModalState(() => selectedTargetWallet = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final raw =
                    amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                final soTien = double.tryParse(raw) ?? 0.0;
                if (soTien <= 0) {
                  baoNhanh('Vui lòng nhập số tiền hợp lệ',
                      loai: LoaiThongBao.loi);
                  return;
                }
                if (soTien > layMucTieu().currentAmount) {
                  baoNhanh(
                      'Mục tiêu chỉ đang giữ '
                      '${CurrencyFormatter.format(layMucTieu().currentAmount)}.',
                      loai: LoaiThongBao.loi);
                  return;
                }

                await onXacNhan(ctx, soTien, selectedTargetWallet);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Xác nhận rút tiền',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );
}
