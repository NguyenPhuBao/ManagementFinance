import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(),
              const SizedBox(height: 24),
              _buildCategoryHeader(context),
              const SizedBox(height: 16),
              _buildCategoryList(),
              const SizedBox(height: 24),
              _buildCreateButton(context),
              const SizedBox(height: 48),
              _buildDecorativeImage(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CÒN LẠI THÁNG NÀY',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '12.000.000đ',
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.income,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '60% ngân sách còn lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '8.000.000đ / 20.000.000đ đã dùng',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.income,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Danh mục chi tiêu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/budget/rules'),
          child: const Text(
            'CHI TIẾT',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.income,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    return Column(
      children: [
        _buildCategoryItem(
          icon: Icons.restaurant,
          title: 'Ăn uống',
          subtitle: 'Còn 2.900.000đ',
          amount: '2.100.000đ',
          totalAmount: '/ 5.000.000đ',
          percent: 0.42,
          isWarning: false,
        ),
        _buildCategoryItem(
          icon: Icons.shopping_bag,
          title: 'Mua sắm',
          subtitle: 'Còn 500.000đ',
          amount: '1.500.000đ',
          totalAmount: '/ 2.000.000đ',
          percent: 0.75,
          isWarning: false,
        ),
        _buildCategoryItem(
          icon: Icons.directions_car,
          title: 'Di chuyển',
          subtitle: 'Vượt ngưỡng 90%',
          amount: '900.000đ',
          totalAmount: '/ 1.000.000đ',
          percent: 0.90,
          isWarning: true,
        ),
      ],
    );
  }

  Widget _buildCategoryItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required String totalAmount,
    required double percent,
    required bool isWarning,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isWarning ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isWarning ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalAmount,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: isWarning ? AppColors.error : AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.push('/budget/rules'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 24),
          SizedBox(width: 8),
          Text(
            'Tạo ngân sách mới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeImage() {
    return Opacity(
      opacity: 0.3,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBJYniBjGS0dwwyxbFnMi2bmX_WxVidYLsVszQitTh15-98h_vpEkulLHbqBPYE-ZaSv_EkWxfqmttlCDz1bG9v05QSDDYn1endcQDCXw9LMoWXxGB3nwUbrs_BVKQyOrw3IhBG8oMob4GthzMhbbeM03tMAMQ4aKcxVOFomEMfQQHi2L8YfuIfO-OTf0we2yvvwhIku5B7PYqIKi8MVXo_Qy3b8H9Y52BK3TSMdA1pGtzOSCSc-47UEKN79_xv4khZAs5DuYxHkCQ'
              ),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
