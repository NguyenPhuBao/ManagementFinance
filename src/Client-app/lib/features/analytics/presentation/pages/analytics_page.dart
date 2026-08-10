import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';

import 'package:go_router/go_router.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildSummarySection(),
              const SizedBox(height: 24),
              _buildChartSection(),
              const SizedBox(height: 24),
              _buildCategoryList(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.menu, color: AppColors.textSecondary, size: 28),
            SizedBox(width: 12),
            Text(
              'Thống kê',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.download, color: AppColors.primary),
              onPressed: () => context.push('/analytics/export'),
              tooltip: 'Xuất Báo cáo',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text(
                    'Tháng này (T6 2026)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Tổng thu',
                amount: '+25.000.000đ',
                diff: 'Tăng 12% so với T5',
                icon: Icons.arrow_upward,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                title: 'Tổng chi',
                amount: '-6.500.000đ',
                diff: 'Giảm 5% so với T5',
                icon: Icons.arrow_downward,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBalanceCard(),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required String diff,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diff,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số dư còn lại',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '18.500.000đ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.74,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF94F990), // secondary-fixed matching stitch
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
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
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chi tiêu theo hạng mục',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Icon(Icons.more_horiz, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 32,
              runSpacing: 24,
              children: [
                _buildDonutChart(),
                _buildChartLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart() {
    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                stops: [0.0, 0.32, 0.32, 0.55, 0.55, 0.69, 0.69, 0.78, 0.78, 1.0],
                colors: [
                  AppColors.primary, AppColors.primary, 
                  AppColors.income, AppColors.income, 
                  AppColors.error, AppColors.error, 
                  Color(0xFF586062), Color(0xFF586062), // Surface tint
                  Color(0xFFEEEEEA), Color(0xFFEEEEEA), // Empty/surface-container
                ],
              ),
            ),
          ),
          Container(
            width: 154,
            height: 154,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TỔNG CHI',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '6.5M',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildLegendItem(AppColors.primary, 'Ăn uống')),
              Expanded(child: _buildLegendItem(AppColors.income, 'Mua sắm')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLegendItem(AppColors.error, 'Di chuyển')),
              Expanded(child: _buildLegendItem(const Color(0xFF586062), 'Giải trí')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CHI TIẾT DANH MỤC',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Xem tất cả', 
                style: TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 13)
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCategoryItem(
          icon: Icons.restaurant,
          iconColor: AppColors.primary,
          title: 'Ăn uống',
          percent: '32% ngân sách',
          amount: '2.100.000đ',
          barColor: AppColors.primary,
          barFactor: 0.32,
        ),
        _buildCategoryItem(
          icon: Icons.shopping_bag,
          iconColor: AppColors.income,
          title: 'Mua sắm',
          percent: '23% ngân sách',
          amount: '1.500.000đ',
          barColor: AppColors.income,
          barFactor: 0.23,
        ),
        _buildCategoryItem(
          icon: Icons.directions_car,
          iconColor: AppColors.error,
          title: 'Di chuyển',
          percent: '14% ngân sách',
          amount: '900.000đ',
          barColor: AppColors.error,
          barFactor: 0.14,
        ),
        _buildCategoryItem(
          icon: Icons.movie,
          iconColor: const Color(0xFF586062),
          title: 'Giải trí',
          percent: '9% ngân sách',
          amount: '600.000đ',
          barColor: const Color(0xFF586062),
          barFactor: 0.09,
        ),
      ],
    );
  }

  Widget _buildCategoryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String percent,
    required String amount,
    required Color barColor,
    required double barFactor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    percent,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: barFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
