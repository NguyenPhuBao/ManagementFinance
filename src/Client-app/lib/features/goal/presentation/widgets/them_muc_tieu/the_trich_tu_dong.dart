/// Thẻ "Tự động trích tiền định kỳ" của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`): công tắc, số tiền, chu kỳ,
/// mốc, giờ và ví nguồn trích — dời nguyên văn từ khối `// Auto-Deposit Schedule Card` của `build` (G88 gạch 2).
library;

import 'package:flutter/material.dart';

import '../../../../../core/nen/co_chay_nen.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../shared/widgets/segmented_choice.dart';
import '../../../../premium/domain/quyen_tinh_nang.dart';
import '../../../../premium/presentation/bloc/co_quyen.dart';
import '../../../../premium/presentation/widgets/the_khoa_quyen.dart';
import '../../../../wallet/data/models/wallet_entity.dart';
import '../../../domain/chu_ky_muc_tieu.dart';
import '../../../domain/goal_auto_deposit.dart';
import 'o_nhap_muc_tieu.dart';

class TheTrichTuDong extends StatelessWidget {
  const TheTrichTuDong({
    super.key,
    required this.autoDeposit,
    required this.onDoiTrich,
    required this.depositAmountController,
    required this.frequency,
    required this.onDoiChuKy,
    required this.chuKyHienTai,
    required this.mocNeo,
    required this.gioTrich,
    required this.onChonNgayTrich,
    required this.onChonGioTrich,
    required this.selectedSourceWallet,
    required this.onChonViNguon,
  });

  final bool autoDeposit;
  final ValueChanged<bool> onDoiTrich;
  final TextEditingController depositAmountController;
  final DepositFrequency frequency;
  final ValueChanged<DepositFrequency> onDoiChuKy;
  final String chuKyHienTai;
  final DateTime mocNeo;
  final TimeOfDay gioTrich;
  final VoidCallback onChonNgayTrich;
  final VoidCallback onChonGioTrich;
  final WalletEntity? selectedSourceWallet;
  final VoidCallback onChonViNguon;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tự động trích tiền định kỳ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'App tự chuyển tiền vào mục tiêu mỗi kỳ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              CongTacTheoQuyen(
                value: autoDeposit,
                // Quyền `goal_auto_deposit` (spec phân quyền 2026-10-08).
                onChanged: onDoiTrich,
                biKhoa: !context.coQuyen(MaQuyen.goalAutoDeposit),
                activeThumbColor: AppColors.income,
              ),
            ],
          ),
          if (!context.coQuyen(MaQuyen.goalAutoDeposit))
            DongKhoaCongTac(ma: MaQuyen.goalAutoDeposit, dangBat: autoDeposit),
          if (autoDeposit) ...[
            const SizedBox(height: 16),
            const NhanMucTieu('SỐ TIỀN TRÍCH MỖI KỲ (VNĐ)'),
            const SizedBox(height: 4),
            ONhapMucTieu(
              controller: depositAmountController,
              hint: CurrencyFormatter.format(5000000),
              textColor: AppColors.income,
              isBold: true,
              keyboardType: TextInputType.number,
              // numeric(15,2) — xem kSoChuSoToiDaSoTien.
              inputFormatters: const [GioiHanSoChuSo(kSoChuSoToiDaSoTien)],
            ),
            const SizedBox(height: 16),
            const NhanMucTieu('CHU KỲ TRÍCH'),
            const SizedBox(height: 4),
            // Thanh chọn dùng chung với hoá đơn và ngân sách
            // (2026-09-06). Màu thu cho ô chọn theo Stitch
            // (`text-secondary`).
            SegmentedChoice<DepositFrequency>(
              keyPrefix: 'goal-deposit-cycle',
              options: const [
                SegmentedOption(DepositFrequency.daily, 'Hàng ngày'),
                SegmentedOption(DepositFrequency.weekly, 'Hàng tuần'),
                SegmentedOption(DepositFrequency.monthly, 'Hàng tháng'),
              ],
              selected: frequency,
              accent: AppColors.income,
              onChanged: (freq) {
                onDoiChuKy(freq);
              },
            ),
            const SizedBox(height: 16),
            const NhanMucTieu('MỐC TRÍCH'),
            const SizedBox(height: 4),
            // Hàng ngày thì không có "ngày trong chu kỳ" để
            // chọn — chỉ còn giờ.
            if (frequency != DepositFrequency.daily) ...[
              ODropdownMucTieu(
                icon: Icons.event_repeat,
                title: nhanMocNeo(chuKyHienTai, mocNeo).split(',').first,
                subtitle: 'Bấm để đổi ngày trong chu kỳ',
                iconColor: AppColors.primary,
                onTap: onChonNgayTrich,
              ),
              const SizedBox(height: 8),
            ],
            ODropdownMucTieu(
              icon: Icons.schedule,
              title: '${gioTrich.hour.toString().padLeft(2, '0')}'
                  ':${gioTrich.minute.toString().padLeft(2, '0')}',
              // Nói thẳng giới hạn thay vì để người dùng tự
              // phát hiện. Android có lượt nền (spec 2026-10-10)
              // nên tiền chuyển gần giờ này kể cả khi app đóng;
              // nơi khác bộ trích chạy khi app mở — giờ chỉ giữ
              // được MỘT chiều (G22).
              subtitle: coChayNen
                  ? 'Tiền được chuyển gần giờ này; máy đang ngủ '
                      'sâu thì có thể muộn hơn'
                  : 'Không trích trước giờ này. App chưa mở '
                      'thì trích ở lần mở kế tiếp',
              iconColor: AppColors.primary,
              onTap: onChonGioTrich,
            ),
            const SizedBox(height: 16),
            const NhanMucTieu('VÍ NGUỒN TRÍCH TIỀN'),
            const SizedBox(height: 4),
            ODropdownMucTieu(
              icon: Icons.account_balance,
              title: selectedSourceWallet?.name ?? 'Chọn ví nguồn trích',
              subtitle: selectedSourceWallet != null
                  ? '${selectedSourceWallet!.typeLabel} • ${CurrencyFormatter.format(selectedSourceWallet!.balance)}'
                  : 'Bấm để chọn ví trích tiền',
              iconColor: AppColors.primary,
              onTap: onChonViNguon,
            ),
          ],
        ],
      ),
    );
  }
}
