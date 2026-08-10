import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_colors.dart';

class WalletEditPage extends StatefulWidget {
  final String id;
  const WalletEditPage({super.key, required this.id});

  @override
  State<WalletEditPage> createState() => _WalletEditPageState();
}

class _WalletEditPageState extends State<WalletEditPage> {
  final TextEditingController _balanceController = TextEditingController(text: '35.000.000');
  final TextEditingController _nameController = TextEditingController(text: 'Techcombank Chính');
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  int _selectedTypeIndex = 0;
  final List<String> _walletTypes = ['Ngân hàng', 'Tiền mặt', 'Ví điện tử', 'Thẻ tín dụng'];

  int _selectedIconIndex = 0;
  final List<IconData> _iconOptions = [
    Icons.account_balance,
    Icons.account_balance_wallet,
    Icons.credit_card,
    Icons.savings,
    Icons.payments,
  ];

  int _selectedColorIndex = 0;
  final List<Color> _colorOptions = [
    const Color(0xFF006E1C),
    Colors.blue.shade600,
    Colors.yellow.shade500,
    Colors.red.shade600,
    Colors.purple.shade600,
    Colors.teal.shade500,
  ];

  bool _isDefault = true;
  bool _includeInTotal = true;
  bool _isActive = true;

  @override
  void dispose() {
    _balanceController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormCard(),
              const SizedBox(height: 16.0),
              _buildWalletOptionsCard(),
              const SizedBox(height: 16.0),
              _buildDeleteButton(),
              const SizedBox(height: 24.0),
              _buildSaveButton(),
              const SizedBox(height: 60.0), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Chỉnh Sửa Ví',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: const Text(
            'Cập nhật',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormSection(
            title: 'TÊN VÍ TÀI CHÍNH',
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'LOẠI VÍ',
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List.generate(_walletTypes.length, (index) {
                final isSelected = index == _selectedTypeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTypeIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.secondary : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppColors.outlineVariant,
                      ),
                    ),
                    child: Text(
                      _walletTypes[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isSelected ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'SỐ DƯ VÍ HIỆN TẠI',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _balanceController,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: -0.02,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final number = int.parse(value);
                          final formatted = _currencyFormat.format(number);
                          _balanceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                    ),
                  ),
                  const Text(
                    'đ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'BIỂU TƯỢNG',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_iconOptions.length, (index) {
                final isSelected = index == _selectedIconIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconIndex = index),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF96f592) : AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.secondary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      _iconOptions[index],
                      color: isSelected ? const Color(0xFF0a7320) : AppColors.onSurfaceVariant,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'MÀU SẮC CHỦ ĐẠO',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_colorOptions.length, (index) {
                final isSelected = index == _selectedColorIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _colorOptions[index],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12.0),
        child,
      ],
    );
  }

  Widget _buildWalletOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Ví mặc định',
            value: _isDefault,
            onChanged: (val) => setState(() => _isDefault = val),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          _buildSwitchTile(
            title: 'Tính vào tổng tài sản',
            value: _includeInTotal,
            onChanged: (val) => setState(() => _includeInTotal = val),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          _buildSwitchTile(
            title: 'Kích hoạt hoạt động',
            value: _isActive,
            onChanged: (val) => setState(() => _isActive = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.onSurface,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.secondary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return OutlinedButton(
      onPressed: _showDeleteConfirmationDialog,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFBA1A1A),
        side: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, size: 24),
          SizedBox(width: 8.0),
          Text(
            'Xóa ví này',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Xác nhận xóa ví?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tất cả giao dịch, mục tiêu và dữ liệu liên quan đến ví này sẽ bị xóa vĩnh viễn và không thể khôi phục.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.pop(); // Giả lập xóa thành công & quay về list
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBA1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Xóa ví', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
      child: const Text(
        'Lưu & Cập Nhật Ví',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
