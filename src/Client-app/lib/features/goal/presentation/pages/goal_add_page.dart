import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../bloc/goal_cubit.dart';

class GoalAddPage extends StatelessWidget {
  const GoalAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final idaccount = (authState is AuthSuccess && authState.user != null)
        ? (int.tryParse(authState.user!.id) ?? 1)
        : 1;

    return MultiBlocProvider(
      providers: [
        BlocProvider<GoalCubit>(
          create: (_) => sl<GoalCubit>(),
        ),
        BlocProvider<WalletCubit>(
          create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
        ),
      ],
      child: const _GoalAddPageContent(),
    );
  }
}

class _GoalAddPageContent extends StatefulWidget {
  const _GoalAddPageContent();

  @override
  State<_GoalAddPageContent> createState() => _GoalAddPageContentState();
}

class _GoalAddPageContentState extends State<_GoalAddPageContent> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _autoDeposit = true;
  bool _isMonthly = true;

  WalletEntity? _selectedSavingsWallet;
  WalletEntity? _selectedSourceWallet;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submitForm() {
    final name = _nameController.text.trim();
    final rawAmount = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawAmount) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên mục tiêu')),
      );
      return;
    }
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền mục tiêu hợp lệ')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final idaccount = (authState is AuthSuccess && authState.user != null)
        ? (int.tryParse(authState.user!.id) ?? 1)
        : 1;

    context.read<GoalCubit>().addGoal(
          idaccount: idaccount,
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
        );
  }

  void _showWalletPickerBottomSheet({
    required BuildContext context,
    required String title,
    required List<WalletEntity> wallets,
    required WalletEntity? selectedWallet,
    required ValueChanged<WalletEntity> onWalletSelected,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (wallets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Chưa có ví nào. Hãy tạo ví trong mục Quản lý Ví.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final wallet = wallets[index];
                      final isSelected = selectedWallet?.id == wallet.id;
                      Color itemColor;
                      try {
                        itemColor = Color(int.parse(wallet.colour.replaceAll('#', '0xFF')));
                      } catch (_) {
                        itemColor = AppColors.primary;
                      }

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            wallet.type == 'bank'
                                ? Icons.account_balance
                                : (wallet.type == 'ewallet'
                                    ? Icons.account_balance_wallet
                                    : Icons.wallet),
                            color: itemColor,
                          ),
                        ),
                        title: Text(
                          wallet.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: AppColors.primary,
                          ),
                        ),
                        subtitle: Text(
                          '${wallet.typeLabel} • Số dư: ${currencyFormatter.format(wallet.balance)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.income)
                            : null,
                        onTap: () {
                          onWalletSelected(wallet);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return BlocListener<GoalCubit, GoalState>(
      listener: (context, state) {
        if (state is GoalOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.income,
            ),
          );
          context.pop();
        } else if (state is GoalError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, walletState) {
          final wallets = (walletState is WalletLoaded) ? walletState.wallets : <WalletEntity>[];

          // Auto-select initial wallets if available
          if (wallets.isNotEmpty) {
            _selectedSavingsWallet ??= wallets.firstWhere(
              (w) => w.type == 'investment' || w.type == 'bank',
              orElse: () => wallets.first,
            );
            _selectedSourceWallet ??= wallets.firstWhere(
              (w) => w.isDefault,
              orElse: () => wallets.length > 1 ? wallets[1] : wallets.first,
            );
          }

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
                  onPressed: _submitForm,
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
                          _buildTextField(
                            controller: _nameController,
                            hint: 'e.g. Mua Laptop MacBook Pro',
                          ),
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
                                      controller: _targetAmountController,
                                      hint: '40.000.000đ',
                                      textColor: AppColors.income,
                                      isBold: true,
                                      keyboardType: TextInputType.number,
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
                                    GestureDetector(
                                      onTap: _selectDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(_targetDate),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const Icon(Icons.calendar_today, color: AppColors.outlineVariant, size: 18),
                                          ],
                                        ),
                                      ),
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
                            title: _selectedSavingsWallet?.name ?? 'Chọn ví tích lũy',
                            subtitle: _selectedSavingsWallet != null
                                ? '${_selectedSavingsWallet!.typeLabel} • ${currencyFormatter.format(_selectedSavingsWallet!.balance)}'
                                : 'Bấm để chọn ví tích lũy',
                            iconColor: AppColors.income,
                            onTap: () {
                              _showWalletPickerBottomSheet(
                                context: context,
                                title: 'Chọn Ví Tích Lũy Liên Kết',
                                wallets: wallets,
                                selectedWallet: _selectedSavingsWallet,
                                onWalletSelected: (w) {
                                  setState(() => _selectedSavingsWallet = w);
                                },
                              );
                            },
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
                              title: _selectedSourceWallet?.name ?? 'Chọn ví nguồn trích',
                              subtitle: _selectedSourceWallet != null
                                  ? '${_selectedSourceWallet!.typeLabel} • ${currencyFormatter.format(_selectedSourceWallet!.balance)}'
                                  : 'Bấm để chọn ví trích tiền',
                              iconColor: AppColors.primary,
                              onTap: () {
                                _showWalletPickerBottomSheet(
                                  context: context,
                                  title: 'Chọn Ví Nguồn Trích Tiền',
                                  wallets: wallets,
                                  selectedWallet: _selectedSourceWallet,
                                  onWalletSelected: (w) {
                                    setState(() => _selectedSourceWallet = w);
                                  },
                                );
                              },
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
                        color: const Color(0xFFDEE1F8).withValues(alpha: 0.2),
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
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF424658),
                                  height: 1.5,
                                  fontFamily: 'Inter',
                                ),
                                children: [
                                  const TextSpan(text: 'AI Dự đoán: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: 'Bạn sẽ đạt mục tiêu đúng hạn chót vào '),
                                  TextSpan(
                                      text: DateFormat('MM/yyyy').format(_targetDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
                                  const TextSpan(text: ' dựa trên chu kỳ trích tiền tự động.'),
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
                      onPressed: _submitForm,
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
        },
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
    required TextEditingController controller,
    required String hint,
    Color textColor = AppColors.primary,
    bool isBold = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
