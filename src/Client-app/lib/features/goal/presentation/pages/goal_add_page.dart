import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';

class GoalAddPage extends StatefulWidget {
  const GoalAddPage({super.key});

  @override
  State<GoalAddPage> createState() => _GoalAddPageState();
}

class _GoalAddPageState extends State<GoalAddPage> {
  bool _autoDeposit = true;
  bool _isMonthly = true;

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
          'Thêm Mục Tiêu Tiết Kiệm',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
              // Header Image
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: NetworkImage(
                        'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&q=80&w=800'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: const Text(
                    'Lập kế hoạch tương lai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Goal Information Card
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
                    _buildLabel('TÊN MỤC TIÊU TIẾT KIỆM'),
                    const SizedBox(height: 4),
                    _buildTextField(hint: 'e.g. Mua Laptop MacBook Pro'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('SỐ TIỀN MỤC TIÊU'),
                              const SizedBox(height: 4),
                              _buildTextField(
                                hint: '40.000.000đ',
                                textColor: AppColors.income,
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('HẠN ĐỊNH'),
                              const SizedBox(height: 4),
                              _buildTextField(
                                hint: '31/12/2026',
                                suffixIcon: Icons.calendar_today,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('VÍ TÍCH LŨY LIÊN KẾT'),
                    const SizedBox(height: 4),
                    _buildDropdownButton(
                      icon: Icons.account_balance_wallet,
                      title: 'Ví Tiết kiệm VCB',
                      iconColor: AppColors.income,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Auto-Deposit Schedule Card
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
                              'Tiết kiệm kỷ luật mỗi kỳ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _autoDeposit,
                          onChanged: (val) {
                            setState(() => _autoDeposit = val);
                          },
                          activeThumbColor: AppColors.income,
                        ),
                      ],
                    ),
                    if (_autoDeposit) ...[
                      const SizedBox(height: 16),
                      _buildLabel('SỐ TIỀN TRÍCH MỖI KỲ'),
                      const SizedBox(height: 4),
                      _buildTextField(hint: '2.000.000đ', isBold: true),
                      const SizedBox(height: 16),
                      _buildLabel('CHU KỲ TRÍCH'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isMonthly = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isMonthly ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !_isMonthly
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Hàng tuần',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_isMonthly ? FontWeight.bold : FontWeight.normal,
                                      color: !_isMonthly ? AppColors.income : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isMonthly = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isMonthly ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _isMonthly
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Hàng tháng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _isMonthly ? FontWeight.bold : FontWeight.normal,
                                      color: _isMonthly ? AppColors.income : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('VÍ NGUỒN TRÍCH TIỀN'),
                      const SizedBox(height: 4),
                      _buildDropdownButton(
                        icon: Icons.account_balance,
                        title: 'Techcombank',
                        subtitle: 'Dư: 35.000.000đ',
                        iconColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Prediction Insight Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDEE1F8).withValues(alpha: 0.2), // primary-fixed/20
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDEE1F8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, color: Color(0xFFC2C5DB), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF424658),
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                          children: [
                            TextSpan(text: 'AI Dự đoán: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: 'Bạn sẽ đạt mục tiêu đúng hạn chót vào '),
                            TextSpan(
                                text: 'Tháng 12/2026',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
                            TextSpan(text: ' dựa trên chu kỳ trích tiền tự động.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Tạo Mục Tiêu & Bật Lập Lịch Tự Động',
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    Color textColor = AppColors.primary,
    bool isBold = false,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      style: TextStyle(
        fontSize: 16,
        color: textColor,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: AppColors.outlineVariant, size: 20)
            : null,
      ),
    );
  }

  Widget _buildDropdownButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
