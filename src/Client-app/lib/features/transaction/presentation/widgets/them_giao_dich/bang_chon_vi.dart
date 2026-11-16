/// Bảng chọn ví của màn Thêm giao dịch — tách từ `_showWalletPickerBottomSheet` ngày 2026-10-10 (spec bịt điểm rò mục 5.2).
/// Trang giữ ví đang chọn và lời gọi đổi trạng thái; bảng chỉ vẽ danh sách và báo ví được chạm qua [onChon].
library;

import 'package:flutter/material.dart';

import '../../../../wallet/data/models/wallet_entity.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../wallet/domain/wallet_type.dart';

void moBangChonVi(
  BuildContext context, {
  required bool isDestination,
  required List<WalletEntity> wallets,
  required String? idDangChon,
  required ValueChanged<WalletEntity> onChon,
  List<WalletEntity> viChung = const [],
  String? tenNha,
}) {
  // Nhóm VÍ CHUNG (spec 2026-11-16): chỉ bộ chọn ví NGUỒN; trang quyết khi nào truyền (tạo mới, không Chuyển khoản).
  final coViChung = viChung.isNotEmpty && !isDestination;
  // `isScrollControlled` + danh sách ví trong `Flexible` / `SingleChildScrollView`: bảng cao theo số ví và CUỘN khi
  // nhiều ví hơn chỗ trống. Bản cũ là `Column` không cuộn trong trần 9/16 màn — đo trên OnePlus 13R (2026-09-30,
  // nghiệm thu D1) tài khoản 5 ví tràn 13 px, ví cuối bị sọc vàng đè và không chạm được. Cùng họ G60.
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // `Expanded`: tiêu đề trần trong `Row` tràn khi cỡ chữ hệ thống lớn.
                Expanded(
                  child: Text(
                    isDestination ? 'Chọn ví đích' : 'Chọn ví thanh toán',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (wallets.isEmpty && !coViChung)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Chưa có ví nào', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...wallets.map((w) => _dongVi(ctx, w, idDangChon: idDangChon, onChon: onChon)),
                      if (coViChung) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'VÍ CHUNG · ${tenNha ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: Color(0xFF454743),
                              ),
                            ),
                          ),
                        ),
                        ...viChung.map((w) => _dongVi(ctx, w, idDangChon: idDangChon, onChon: onChon, laChung: true)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Một dòng ví của bảng chọn. [laChung] = ví chung của nhà (biểu tượng ngôi nhà).
Widget _dongVi(
  BuildContext ctx,
  WalletEntity wallet, {
  required String? idDangChon,
  required ValueChanged<WalletEntity> onChon,
  bool laChung = false,
}) {
  final isSelected = idDangChon == wallet.id;

  return InkWell(
    onTap: () {
      onChon(wallet);
      Navigator.pop(ctx);
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(laChung ? Icons.home : Icons.account_balance_wallet, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  laChung ? 'Ví chung' : WalletType.tuKhoa(wallet.type).nhan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(wallet.balance),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
          ]
        ],
      ),
    ),
  );
}
