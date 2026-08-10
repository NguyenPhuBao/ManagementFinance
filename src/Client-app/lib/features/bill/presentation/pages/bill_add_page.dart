import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';

class BillAddPage extends StatefulWidget {
  const BillAddPage({super.key});

  @override
  State<BillAddPage> createState() => _BillAddPageState();
}

class _BillAddPageState extends State<BillAddPage> {
  String _selectedCycle = 'monthly';
  bool _pushNotificationsEnabled = true;
  bool _autoPayEnabled = true;
  String _selectedReminderDay = '1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thêm Hóa Đơn Định Kỳ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                minimumSize: const Size(0, 32),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Lưu',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFormCard(),
            const SizedBox(height: 24),
            _buildAutomationCard(),
            const SizedBox(height: 32),
            _buildMainActionButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('TÊN DỊCH VỤ / HÓA ĐƠN'),
          const SizedBox(height: 8),
          _buildTextField(
            icon: Icons.payments_outlined,
            placeholder: 'e.g. Netflix Premium',
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel('SỐ TIỀN ĐỊNH KỲ'),
          const SizedBox(height: 8),
          _buildTextField(
            icon: Icons.monetization_on_outlined,
            placeholder: '0đ',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 16),
          
          _buildInputLabel('NGÀY ĐẾN HẠN THANH TOÁN'),
          const SizedBox(height: 8),
          _buildTextField(
            icon: Icons.calendar_month_outlined,
            placeholder: 'Ngày 25 hàng tháng',
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel('CHU KỲ'),
          const SizedBox(height: 8),
          _buildCycleSelector(),
          const SizedBox(height: 16),
          
          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 16),
          
          _buildInputLabel('VÍ THANH TOÁN NGUỒN'),
          const SizedBox(height: 8),
          _buildDropdownField(
            icon: Icons.account_balance_wallet_outlined,
            value: 'Techcombank - 35.000.000đ',
            items: [
              'Techcombank - 35.000.000đ',
              'Momo Wallet - 2.500.000đ',
              'Cash - 1.200.000đ',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Row(
                children: [
                  Icon(Icons.notifications_active, color: AppColors.secondary),
                  SizedBox(width: 12),
                  Text(
                    'Bật nhắc nhở thông báo đẩy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _pushNotificationsEnabled,
                onChanged: (val) => setState(() => _pushNotificationsEnabled = val),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildReminderDayChip('Trước 1 ngày', '1'),
              const SizedBox(width: 8),
              _buildReminderDayChip('Trước 3 ngày', '3'),
              const SizedBox(width: 8),
              _buildReminderDayChip('Trước 5 ngày', '5'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy, color: AppColors.primary),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tự động tạo giao dịch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Thanh toán khi đến hạn',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _autoPayEnabled,
                onChanged: (val) => setState(() => _autoPayEnabled = val),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.outline, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: AppColors.outlineVariant, fontSize: 16),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required IconData icon,
    required String value,
    required List<String> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.outline, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.expand_more, color: AppColors.outline),
                isExpanded: true,
                style: const TextStyle(fontSize: 16, color: AppColors.primary),
                dropdownColor: Colors.white,
                onChanged: (String? newValue) {
                  // Handle change
                },
                items: items.map<DropdownMenuItem<String>>((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCycle = 'monthly'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedCycle == 'monthly'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _selectedCycle == 'monthly'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Hàng tháng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedCycle == 'monthly'
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCycle = 'yearly'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedCycle == 'yearly'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _selectedCycle == 'yearly'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Hàng năm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedCycle == 'yearly'
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDayChip(String label, String value) {
    final isSelected = _selectedReminderDay == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedReminderDay = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.secondary : AppColors.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_task, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Tạo Hóa Đơn & Đăng Ký Nhắc Nhở',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
