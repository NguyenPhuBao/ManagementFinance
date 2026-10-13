/// Phiếu "Gửi thêm tiết kiệm" của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn khỏi
/// `_showDepositDialog` (đợt tách bốn trang lớn, spec 2026-10-13 mục 5.2). Phiếu tự kiểm số tiền và số dư ví nguồn như
/// cũ; phần ghi xuống CSDL, đóng phiếu, báo và nạp lại nằm ở [onXacNhan] của trang.
library;

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/goal_entity.dart';
import '../../../domain/goal_deposit_warning.dart';

/// Mở phiếu nạp. [layMucTieu] là getter (không phải giá trị) để thân phiếu đọc mục tiêu **sống** như cũ.
void moPhieuNapTien({
  required BuildContext context,
  required GoalEntity Function() layMucTieu,
  required List<Wallet> wallets,
  required Wallet viNhan,
  required String idNguonMacDinh,
  required Future<void> Function(
          BuildContext ctx, double soTien, Wallet viNguon)
      onXacNhan,
}) {
  final amountController = TextEditingController();
  // Chỉ còn MỘT ô chọn: ví nguồn. Ví nhận đã cố định ở trên.
  final viNguonKhaDung = wallets.where((w) => w.id != viNhan.id).toList();
  Wallet selectedSourceWallet =
      viNguonKhaDung.firstWhere((w) => w.id == idNguonMacDinh);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                  'Gửi thêm tiền vào ${layMucTieu().name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Số tiền hiện tại: ${CurrencyFormatter.format(layMucTieu().currentAmount)} / ${CurrencyFormatter.format(layMucTieu().targetAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Còn thiếu ${CurrencyFormatter.format(layMucTieu().remainingAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E6B27),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  onChanged: (_) => setModalState(() {}),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nhập số tiền muốn tích lũy thêm (VNĐ)',
                    hintText: 'e.g. 1.000.000',
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
                  'Chọn ví nguồn thanh toán (Trừ tiền)',
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
                    child: DropdownButton<Wallet>(
                      value: selectedSourceWallet,
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more,
                          color: AppColors.primary),
                      items: viNguonKhaDung.map((w) {
                        return DropdownMenuItem<Wallet>(
                          value: w,
                          child: Text(
                            '${w.name} (Số dư: ${CurrencyFormatter.format(w.balance)})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setModalState(() => selectedSourceWallet = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Ví nhận CHỈ để xem — nó là thuộc tính của mục tiêu, đổi qua
                // nút "Đổi ví nhận" ở thanh trên chứ không phải mỗi lần nạp.
                Row(
                  children: [
                    const Icon(Icons.arrow_downward,
                        size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chuyển vào ví tích lũy: ${viNhan.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E6B27),
                        ),
                      ),
                    ),
                  ],
                ),
                if (canhBaoNapVuot(
                      layMucTieu(),
                      double.tryParse(amountController.text
                              .replaceAll(RegExp(r'[^\d]'), '')) ??
                          0.0,
                    ) !=
                    null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          canhBaoNapVuot(
                                layMucTieu(),
                                double.tryParse(amountController.text
                                        .replaceAll(RegExp(r'[^\d]'), '')) ??
                                    0.0,
                              ) ??
                              '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final raw =
                        amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                    final deposit = double.tryParse(raw) ?? 0.0;
                    if (deposit <= 0) {
                      baoNhanh('Vui lòng nhập số tiền hợp lệ',
                          loai: LoaiThongBao.loi);
                      return;
                    }

                    // Kiểm tra số dư ví nguồn
                    if (deposit > selectedSourceWallet.balance) {
                      baoNhanh(
                          'Số dư ví "${selectedSourceWallet.name}" không đủ. '
                          'Hiện có: ${CurrencyFormatter.format(selectedSourceWallet.balance)}',
                          loai: LoaiThongBao.loi);
                      return;
                    }

                    await onXacNhan(ctx, deposit, selectedSourceWallet);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Xác nhận gửi tiết kiệm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
