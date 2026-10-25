/// Thẻ thông tin của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`): tên, số tiền, hạn định, biểu tượng và màu,
/// ví tích luỹ liên kết, ghi chú — dời nguyên văn từ khối `// Goal Information Card` của `build` (G88 gạch 2).
library;

import 'package:flutter/material.dart';
import '../../../../../core/utils/date_formatter.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../wallet/data/models/wallet_entity.dart';
import 'o_nhap_muc_tieu.dart';

class TheThongTinMucTieu extends StatelessWidget {
  const TheThongTinMucTieu({
    super.key,
    required this.isEdit,
    required this.nameController,
    required this.targetAmountController,
    required this.noteController,
    required this.targetDate,
    required this.onChonHan,
    required this.icon,
    required this.colour,
    required this.onChonIcon,
    required this.onChonMau,
    required this.selectedSavingsWallet,
    required this.onChonViTichLuy,
  });

  final bool isEdit;
  final TextEditingController nameController;
  final TextEditingController targetAmountController;
  final TextEditingController noteController;
  final DateTime targetDate;
  final VoidCallback onChonHan;
  final String icon;
  final String colour;
  final ValueChanged<String> onChonIcon;
  final ValueChanged<String> onChonMau;
  final WalletEntity? selectedSavingsWallet;

  /// `null` ở chế độ sửa.
  final VoidCallback? onChonViTichLuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NhanMucTieu('TÊN MỤC TIÊU TIẾT KIỆM'),
          const SizedBox(height: 4),
          ONhapMucTieu(
            controller: nameController,
            hint: 'e.g. Mua Laptop MacBook Pro',
            inputFormatters: const [
              GioiHanDoRong(DoRongCot.tenMucTieu),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NhanMucTieu('SỐ TIỀN MỤC TIÊU'),
                    const SizedBox(height: 4),
                    ONhapMucTieu(
                      controller: targetAmountController,
                      hint: CurrencyFormatter.format(40000000),
                      textColor: AppColors.income,
                      isBold: true,
                      keyboardType: TextInputType.number,
                      // numeric(15,2) — xem kSoChuSoToiDaSoTien.
                      inputFormatters: const [
                        GioiHanSoChuSo(kSoChuSoToiDaSoTien)
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NhanMucTieu('HẠN ĐỊNH'),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onChonHan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormatter.formatDate(targetDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(Icons.calendar_today,
                                color: AppColors.outlineVariant, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const NhanMucTieu('BIỂU TƯỢNG & MÀU'),
          const SizedBox(height: 8),
          ChonBieuTuongMucTieu(
            icon: icon,
            colour: colour,
            onChon: (v) => onChonIcon(v),
          ),
          const SizedBox(height: 12),
          ChonMauMucTieu(
            colour: colour,
            onChon: (v) => onChonMau(v),
          ),
          const SizedBox(height: 16),
          const NhanMucTieu('VÍ TÍCH LŨY LIÊN KẾT'),
          const SizedBox(height: 4),
          ODropdownMucTieu(
            icon: Icons.account_balance_wallet,
            title: selectedSavingsWallet?.name ??
                (isEdit ? 'Chưa gắn ví tích lũy' : 'Chọn ví tích lũy'),
            subtitle: isEdit
                // Luật khoá ví sau khoản nạp đầu tiên nằm ở
                // `changeWallet`, và nút gọi nó ở trang chi
                // tiết. Chép luật ấy sang đây là tạo bản thứ
                // hai để chúng lệch nhau về sau; câu này chỉ
                // trỏ đúng chỗ, giống câu báo lỗi khi xoá ví.
                ? 'Đổi ở trang chi tiết mục tiêu'
                : selectedSavingsWallet != null
                    ? '${selectedSavingsWallet!.typeLabel} • ${CurrencyFormatter.format(selectedSavingsWallet!.balance)}'
                    : 'Bấm để chọn ví tích lũy',
            iconColor: AppColors.income,
            showChevron: !isEdit,
            onTap: onChonViTichLuy,
          ),
          const SizedBox(height: 16),
          // Ghi chú nằm CUỐI thẻ, cùng lối với biểu mẫu thêm
          // giao dịch: nó là trường tuỳ chọn, đặt trên đầu sẽ
          // đẩy số tiền và hạn định — hai thứ bắt buộc — xuống
          // dưới nếp gấp màn hình.
          const NhanMucTieu('GHI CHÚ (TUỲ CHỌN)'),
          const SizedBox(height: 4),
          ONhapMucTieu(
            controller: noteController,
            hint: 'Vì sao bạn muốn đạt mục tiêu này?',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
