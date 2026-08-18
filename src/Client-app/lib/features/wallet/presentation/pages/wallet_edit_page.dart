import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/wallet_entity.dart';
import '../../data/repositories/wallet_repository.dart';

class WalletEditPage extends StatefulWidget {
  final String id;
  const WalletEditPage({super.key, required this.id});

  @override
  State<WalletEditPage> createState() => _WalletEditPageState();
}

class _WalletEditPageState extends State<WalletEditPage> {
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  bool _isLoading = true;
  bool _isSaving = false;
  WalletEntity? _wallet;

  int _selectedTypeIndex = 0;
  final List<String> _walletTypes = ['Tiền mặt', 'Ngân hàng', 'Ví điện tử', 'Thẻ tín dụng'];
  final List<String> _walletTypeKeys = ['cash', 'bank', 'ewallet', 'debt'];

  int _selectedIconIndex = 0;
  final List<IconData> _iconOptions = [
    Icons.account_balance_wallet,
    Icons.payments,
    Icons.credit_card,
    Icons.savings,
    Icons.account_balance,
  ];
  final List<String> _iconKeys = ['wallet', 'payments', 'credit_card', 'savings', 'bank'];

  int _selectedColorIndex = 0;
  final List<Color> _colorOptions = [
    AppColors.secondary,
    const Color(0xFF1A73E8),
    const Color(0xFFF4B400),
    const Color(0xFFEA4335),
    const Color(0xFFA142F4),
    const Color(0xFF00ACC1),
  ];
  final List<String> _colorHexes = ['#4CAF50', '#1A73E8', '#F4B400', '#EA4335', '#A142F4', '#00ACC1'];

  bool _isDefault = false;
  bool _includeInTotal = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final repo = sl<WalletRepository>();
      final wallet = await repo.getById(widget.id);
      if (wallet != null && mounted) {
        setState(() {
          _wallet = wallet;
          _nameController.text = wallet.name;
          _balanceController.text = _currencyFormat.format(wallet.balance.toInt());

          final typeIdx = _walletTypeKeys.indexOf(wallet.type);
          if (typeIdx != -1) _selectedTypeIndex = typeIdx;

          final iconIdx = _iconKeys.indexOf(wallet.icon);
          if (iconIdx != -1) _selectedIconIndex = iconIdx;

          final colorIdx = _colorHexes.indexOf(wallet.colour);
          if (colorIdx != -1) _selectedColorIndex = colorIdx;

          _isDefault = wallet.isDefault;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveWallet() async {
    if (_wallet == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên ví'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rawBalance = _balanceController.text.replaceAll(',', '').replaceAll('.', '');
    final balance = double.tryParse(rawBalance) ?? 0.0;
    final colour = _colorHexes[_selectedColorIndex];
    final iconKey = _iconKeys[_selectedIconIndex];

    setState(() => _isSaving = true);
    try {
      final updatedWallet = _wallet!.copyWith(
        name: name,
        type: _walletTypeKeys[_selectedTypeIndex],
        balance: balance,
        icon: iconKey,
        colour: colour,
        isDefault: _isDefault,
        updatedAt: DateTime.now(),
      );

      await sl<WalletRepository>().updateWallet(updatedWallet);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật ví: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteWallet() async {
    if (_wallet == null) return;
    setState(() => _isSaving = true);
    try {
      await sl<WalletRepository>().deleteWallet(widget.id);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa ví: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              const SizedBox(height: 60.0),
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
        _isSaving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : TextButton(
                onPressed: _saveWallet,
                child: const Text(
                  'Cập nhật',
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
      builder: (ctx) => Container(
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
            Text(
              'Bạn có chắc muốn xóa ví "${_wallet?.name ?? ''}"?\nCác dữ liệu liên quan sẽ bị xóa.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
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
                      Navigator.pop(ctx);
                      _deleteWallet();
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
      onPressed: _isSaving ? null : _saveWallet,
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
      child: _isSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text(
              'Lưu & Cập Nhật Ví',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
