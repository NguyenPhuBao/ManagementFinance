import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';

class BillPage extends StatelessWidget {
  const BillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hóa đơn & Dịch vụ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.outlineVariant,
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100), // Bottom padding for CTA
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildBillItem(
                context: context,
                title: 'Netflix Premium',
                subtitle: 'Đến hạn 20/07',
                amount: '260.000đ',
                status: 'SẮP ĐẾN HẠN',
                statusColor: const Color(0xFF93000A), // on-error-container
                statusBg: const Color(0xFFFFDAD6),
                accentColor: AppColors.income,
                actionText: 'Thanh toán',
                actionFilled: true,
              ),
              const SizedBox(height: 16),
              _buildBillItem(
                context: context,
                title: 'Tiền điện tháng 7',
                subtitle: 'Hạn 25/07',
                amount: '1.200.000đ',
                status: 'CHƯA THANH TOÁN',
                statusColor: AppColors.textSecondary,
                statusBg: AppColors.surfaceContainerHigh,
                accentColor: AppColors.primary,
                actionText: 'Chi tiết',
                actionFilled: false,
              ),
              const SizedBox(height: 16),
              _buildBillItem(
                context: context,
                title: 'Tiền thuê nhà',
                subtitle: 'Hạn 01/08',
                amount: '5.000.000đ',
                status: 'ĐÃ THANH TOÁN',
                statusColor: const Color(0xFF217128), // on-secondary-container
                statusBg: const Color(0xFFA0F399), // secondary-container
                accentColor: AppColors.outlineVariant,
                actionText: '',
                isPaid: true,
                timeText: 'Cập nhật lúc 08:30',
              ),
              const SizedBox(height: 32),
              _buildDecorativeIllustration(),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildAddButton(context),
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DB)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.account_balance_wallet, size: 64, color: AppColors.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng tiền cần thanh toán',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1.460.000đ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.66,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '2 hóa đơn chưa thanh toán trong tháng này',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required Color accentColor,
    required String actionText,
    bool actionFilled = false,
    bool isPaid = false,
    String? timeText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPaid ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPaid 
            ? Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid) 
            : Border.all(color: const Color(0xFFE0E0DB)),
        boxShadow: [
          if (!isPaid)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isPaid ? AppColors.textSecondary : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (isPaid) ...[
                                Icon(Icons.check_circle, color: statusColor, size: 14),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2, // tracking-wider
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          amount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => context.push('/bills/1/edit'),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: isPaid ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {},
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: isPaid ? const Color(0xFFF1453B).withValues(alpha: 0.5) : const Color(0xFFF1453B),
                          ),
                        ),
                        const Spacer(),
                        if (!isPaid)
                          ElevatedButton(
                            onPressed: () {
                              if (!actionFilled) {
                                // Detailed view routing
                                context.push('/bills/1/edit');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: actionFilled ? AppColors.primary : Colors.white,
                              foregroundColor: actionFilled ? Colors.white : AppColors.primary,
                              elevation: 0,
                              minimumSize: const Size(0, 36), // Override global infinite minimumSize
                              side: actionFilled ? null : const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              actionText,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        else if (timeText != null)
                          Text(
                            timeText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeIllustration() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 192,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outlineVariant),
            image: const DecorationImage(
              image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuB49IskligtA70EtoTSo5p6LmoOg2F7dLA0jnHmcwLjzmwzH2zZF-fu1UiTUzTdIB18gWNVJq_U85Osey0UHotvXEp0gpzg4eJhaB6zfyIJ1El-koV8p5a0IiU-ENL8i6bnggdm4BYQnlxmUnn5qWA8ia_pQM367Wl38euVBP2svBa0_lzyZjuPTU0j3-k5DjHLFqeJVJRMtgn8WRswl0l35qKuuomQLaD_xicw-Jg1R1tVF5gWis87zzJbfl9cpAtgER2lwXeKA3E'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Mọi thứ đều trong tầm kiểm soát. Bạn không có hóa đơn nào quá hạn.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.push('/bills/add'),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Tạo hóa đơn lặp lại mới',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A19),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
}
