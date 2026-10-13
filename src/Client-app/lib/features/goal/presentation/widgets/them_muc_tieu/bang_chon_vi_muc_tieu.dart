/// Bảng chọn ví (đáy màn) của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`) — dùng cho ví tích luỹ và ví nguồn trích; dời nguyên văn từ `_showWalletPickerBottomSheet` của trang (G88 gạch 2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../auth/presentation/bloc/current_account.dart';
import '../../../../wallet/data/models/wallet_entity.dart';
import '../../../../wallet/domain/wallet_type.dart';
import '../../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../../../../wallet/presentation/widgets/wallet_type_icon.dart';

/// [loaiTruViId] bỏ hẳn một ví khỏi danh sách thay vì chỉ báo lỗi khi lưu:
/// ví nguồn trích không được trùng ví tích luỹ, và lựa chọn sai thì tốt nhất
/// là người dùng không nhìn thấy nó. Phép kiểm lúc lưu vẫn giữ làm lưới chắn
/// cuối cho những đường vào khác.
///
/// [thongDiepRong] nói ra lý do khi việc loại trừ ấy làm danh sách cạn sạch
/// — tài khoản vẫn có ví, nên câu "chưa có ví nào" sẽ là một lời nói dối.
void moBangChonViMucTieu({
  required BuildContext mainContext,
  required String title,
  required List<WalletEntity> wallets,
  required WalletEntity? selectedWallet,
  required ValueChanged<WalletEntity> onWalletSelected,
  String? loaiTruViId,
  String? thongDiepRong,
}) {
  final danhSach = loaiTruViId == null
      ? wallets
      : wallets.where((w) => w.id != loaiTruViId).toList();

  showModalBottomSheet(
    context: mainContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white,
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(mainContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await mainContext.push('/wallets/add');
                    if (mainContext.mounted) {
                      final idaccount =
                          currentAccountIdOrNull(mainContext) ?? 0;
                      mainContext.read<WalletCubit>().loadWallets(idaccount);
                    }
                  },
                  icon:
                      const Icon(Icons.add, size: 18, color: AppColors.income),
                  label: const Text(
                    'Tạo ví mới',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.income,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (danhSach.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        wallets.isEmpty
                            ? 'Chưa có ví nào trong hệ thống.'
                            : (thongDiepRong ??
                                'Không còn ví nào dùng được ở đây.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await mainContext.push('/wallets/add');
                          if (mainContext.mounted) {
                            final idaccount =
                                currentAccountIdOrNull(mainContext) ?? 0;
                            mainContext
                                .read<WalletCubit>()
                                .loadWallets(idaccount);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm Ví Mới Ngay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.income,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: danhSach.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    if (index == danhSach.length) {
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.income.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: AppColors.income),
                        ),
                        title: const Text(
                          '+ Thêm ví mới ngay',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.income,
                          ),
                        ),
                        subtitle: const Text(
                          'Tạo ví mới để liên kết tích lũy',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await mainContext.push('/wallets/add');
                          if (mainContext.mounted) {
                            final idaccount =
                                currentAccountIdOrNull(mainContext) ?? 0;
                            mainContext
                                .read<WalletCubit>()
                                .loadWallets(idaccount);
                          }
                        },
                      );
                    }

                    final wallet = danhSach[index];
                    final isSelected = selectedWallet?.id == wallet.id;
                    Color itemColor;
                    try {
                      itemColor = Color(
                          int.parse(wallet.colour.replaceAll('#', '0xFF')));
                    } catch (_) {
                      itemColor = AppColors.primary;
                    }

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          WalletType.tuKhoa(wallet.type).icon,
                          color: itemColor,
                        ),
                      ),
                      title: Text(
                        wallet.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: Text(
                        '${wallet.typeLabel} • Số dư: ${CurrencyFormatter.format(wallet.balance)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.income)
                          : null,
                      onTap: () {
                        onWalletSelected(wallet);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
