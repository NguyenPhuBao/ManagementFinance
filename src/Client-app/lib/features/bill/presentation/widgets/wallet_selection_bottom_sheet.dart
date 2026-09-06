import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';

class WalletSelectionBottomSheet extends StatelessWidget {
  final List<Wallet> wallets;
  final Function(Wallet) onSelected;

  /// Ví đã lưu sẵn trên hoá đơn. Được đưa lên đầu và đánh dấu.
  ///
  /// Vì sao: hoá đơn **bắt buộc** có ví (`bill.Idwallet` NOT NULL phía
  /// backend) nhưng luồng trả trước đây bày ra một danh sách không gợi ý gì,
  /// nên mỗi lần trả người dùng phải nhớ lại mình đã chọn ví nào lúc tạo.
  final String? preferredWalletId;

  const WalletSelectionBottomSheet({
    super.key,
    required this.wallets,
    required this.onSelected,
    this.preferredWalletId,
  });

  /// Ví của hoá đơn lên đầu, thứ tự còn lại giữ nguyên.
  List<Wallet> get _xepLai {
    final uu = wallets.where((w) => w.id == preferredWalletId);
    if (uu.isEmpty) return wallets;
    return [...uu, ...wallets.where((w) => w.id != preferredWalletId)];
  }

  @override
  Widget build(BuildContext context) {
    final danhSach = _xepLai;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn ví thanh toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (wallets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Không tìm thấy ví nào khả dụng.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              itemCount: danhSach.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final wallet = danhSach[index];
                final laViCuaHoaDon = wallet.id == preferredWalletId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                  ),
                  title: Text(
                    wallet.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Số dư: ${wallet.balance.toStringAsFixed(0)}đ',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: laViCuaHoaDon
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ví của hoá đơn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(wallet);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
