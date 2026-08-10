import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/wallet_cubit.dart';

class WalletAddPage extends StatelessWidget {
  const WalletAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final idaccount = int.tryParse(user?.id ?? '') ?? 0;
    return BlocProvider<WalletCubit>(
      create: (_) => sl<WalletCubit>(),
      child: _WalletAddForm(idaccount: idaccount),
    );
  }
}

class _WalletAddForm extends StatefulWidget {
  final int idaccount;
  const _WalletAddForm({required this.idaccount});

  @override
  State<_WalletAddForm> createState() => _WalletAddFormState();
}

class _WalletAddFormState extends State<_WalletAddForm> {
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');
  bool _isSaving = false;

  int _selectedTypeIndex = 0;
  final List<String> _walletTypes = ['Tiền mặt', 'Ngân hàng', 'Ví điện tử', 'Thẻ tín dụng'];

  int _selectedIconIndex = 0;
  final List<IconData> _iconOptions = [
    Icons.account_balance_wallet,
    Icons.payments,
    Icons.credit_card,
    Icons.savings,
    Icons.account_balance,
  ];

  int _selectedColorIndex = 0;
  final List<Color> _colorOptions = [
    AppColors.secondary,
    const Color(0xFF1A73E8),
    const Color(0xFFF4B400),
    const Color(0xFFEA4335),
    const Color(0xFFA142F4),
    const Color(0xFF00ACC1),
  ];

  bool _isDefault = true;
  bool _includeInTotal = true;
  bool _isActive = true;

  // Map type index sang type key
  final List<String> _walletTypeKeys = ['cash', 'bank', 'ewallet', 'debt'];

  @override
  void dispose() {
    _balanceController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveWallet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên ví'),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Parse số dư — bỏ dấu phẩy
    final rawBalance = _balanceController.text.replaceAll(',', '').replaceAll('.', '');
    final balance = double.tryParse(rawBalance) ?? 0.0;
    final colour = ['#4CAF50', '#1A73E8', '#F4B400', '#EA4335', '#A142F4', '#00ACC1'][_selectedColorIndex];
    final iconKey = ['wallet', 'payments', 'credit_card', 'savings', 'bank'][_selectedIconIndex];

    setState(() => _isSaving = true);
    try {
      await context.read<WalletCubit>().addWallet(
        idaccount: widget.idaccount,
        name:      name,
        type:      _walletTypeKeys[_selectedTypeIndex],
        balance:   balance,
        icon:      iconKey,
        colour:    colour,
        isDefault: _isDefault,
      );
      if (mounted) context.pop(true); // true = có thay đổi
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              const SizedBox(height: 100.0), // Space for bottom button
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Thêm Ví Mới',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onBackground,
        ),
      ),
      actions: [
        _isSaving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : TextButton(
                onPressed: _saveWallet,
                child: const Text(
                  'Lưu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'SỐ DƯ BAN ĐẦU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              IntrinsicWidth(
                child: TextField(
                  controller: _balanceController,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: AppColors.outlineVariant),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
              const SizedBox(width: 4),
              const Text(
                'đ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'TÊN VÍ TÀI CHÍNH',
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ví Tiền Mặt, Techcombank...',
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryContainer, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'LOẠI VÍ',
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 3.5,
              ),
              itemCount: _walletTypes.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedTypeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTypeIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _walletTypes[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24.0),
          _buildFormSection(
            title: 'CHỌN BIỂU TƯỢNG',
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconOptions[_selectedIconIndex],
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: List.generate(_iconOptions.length, (index) {
                        return index == _selectedIconIndex 
                          ? const SizedBox.shrink()
                          : GestureDetector(
                            onTap: () => setState(() => _selectedIconIndex = index),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(left: 12.0),
                              child: Icon(
                                _iconOptions[index],
                                color: AppColors.outlineVariant,
                              ),
                            ),
                          );
                      }),
                    ),
                ],
              ),
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
                          ? Border.all(color: AppColors.background, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [
                              const BoxShadow(
                                color: AppColors.primary,
                                blurRadius: 0,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
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
            color: AppColors.outline,
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
            title: 'Đặt làm Ví mặc định',
            subtitle: 'Tự động chọn khi ghi chép giao dịch',
            value: _isDefault,
            onChanged: (val) => setState(() => _isDefault = val),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle, indent: 20, endIndent: 20),
          _buildSwitchTile(
            title: 'Tính vào tổng số dư tài sản',
            value: _includeInTotal,
            onChanged: (val) => setState(() => _includeInTotal = val),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle, indent: 20, endIndent: 20),
          _buildSwitchTile(
            title: 'Trạng thái hoạt động',
            value: _isActive,
            onChanged: (val) => setState(() => _isActive = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
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

  Widget _buildFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveWallet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
          ),
          child: _isSaving
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text(
                  'Hoàn tất & Lưu ví',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
