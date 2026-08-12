import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';

class WalletSelectionBottomSheet extends StatelessWidget {
  final List<Wallet> wallets;
  final Function(Wallet) onSelected;

  const WalletSelectionBottomSheet({
    super.key,
    required this.wallets,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
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
              itemCount: wallets.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final wallet = wallets[index];
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
