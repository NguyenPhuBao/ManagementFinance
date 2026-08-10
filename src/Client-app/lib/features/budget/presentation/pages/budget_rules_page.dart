import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';

class BudgetRulesPage extends StatefulWidget {
  const BudgetRulesPage({super.key});

  @override
  State<BudgetRulesPage> createState() => _BudgetRulesPageState();
}

class _BudgetRulesPageState extends State<BudgetRulesPage> {
  bool _isMonthly = true;
  bool _sendNotifications = true;
  
  final List<String> _selectedCategories = [
    'Ăn uống',
    'Mua sắm',
    'Giải trí',
  ];

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Cấu hình Ngân sách',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: AppColors.income,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Thiết lập Ngân sách
              _buildSectionTitle('Thiết lập Ngân sách'),
              Container(
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
                    // Tên ngân sách
                    const Text(
                      'Tên ngân sách',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: 'Ngân sách Chi tiêu Tháng 7',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Hạn mức
                    const Text(
                      'Hạn mức chi tiêu',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: '10.000.000đ',
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Chu kỳ
                    const Text(
                      'Chu kỳ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isMonthly = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isMonthly ? AppColors.primary : Colors.transparent,
                                border: Border.all(
                                  color: _isMonthly ? AppColors.primary : AppColors.outlineVariant,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Hàng tháng',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isMonthly ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isMonthly = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isMonthly ? AppColors.primary : Colors.transparent,
                                border: Border.all(
                                  color: !_isMonthly ? AppColors.primary : AppColors.outlineVariant,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Hàng tuần',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !_isMonthly ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Danh mục
                    const Text(
                      'Danh mục áp dụng',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._selectedCategories.map((item) => Chip(
                          label: Text(item),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          backgroundColor: AppColors.primary,
                          deleteIconColor: Colors.white,
                          onDeleted: () {
                            setState(() {
                              _selectedCategories.remove(item);
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                        )),
                        ActionChip(
                          label: const Text('Thêm'),
                          avatar: const Icon(Icons.add, size: 16, color: AppColors.outline),
                          labelStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: AppColors.outlineVariant, style: BorderStyle.none), // We use dashed in html, but solid here for simplicity or customize later
                          ),
                          onPressed: () {
                            // Add logic
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Section 2: Ngưỡng cảnh báo chi tiêu
              _buildSectionTitle('Ngưỡng cảnh báo chi tiêu'),
              Container(
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
                  children: [
                    _buildAlertThresholdRow('80% (Cảnh báo sớm)', Icons.check_circle, AppColors.income),
                    const SizedBox(height: 12),
                    _buildAlertThresholdRow('90% (Báo động)', Icons.error, AppColors.expense),
                    const SizedBox(height: 12),
                    _buildAlertThresholdRow('100% (Vượt ngưỡng)', Icons.gavel, AppColors.primary),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.surfaceContainerHigh),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Gửi thông báo đẩy khi chạm ngưỡng',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _sendNotifications,
                          onChanged: (val) {
                            setState(() {
                              _sendNotifications = val;
                            });
                          },
                          activeThumbColor: AppColors.income,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Section 3: Quy tắc phân bổ
              _buildSectionTitle('Quy tắc phân bổ thu nhập (50/30/20)'),
              Container(
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
                  children: [
                    _buildAllocationRow(
                      icon: Icons.home_repair_service,
                      title: 'Nhu cầu Thiết yếu (Needs)',
                      percent: '50%',
                      amount: '~ 5.000.000đ',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    _buildAllocationRow(
                      icon: Icons.shopping_bag,
                      title: 'Linh hoạt & Giải trí (Wants)',
                      percent: '30%',
                      amount: '~ 3.000.000đ',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 24),
                    _buildAllocationRow(
                      icon: Icons.savings,
                      title: 'Tích lũy & Đầu tư (Savings)',
                      percent: '20%',
                      amount: '~ 2.000.000đ',
                      color: Colors.teal, // Emerald replacement
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, color: AppColors.income, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '✓ Tổng tỷ lệ: 100% (Đạt yêu cầu)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Lưu & Áp dụng Ngân sách',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertThresholdRow(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildAllocationRow({
    required IconData icon,
    required String title,
    required String percent,
    required String amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    percent,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
