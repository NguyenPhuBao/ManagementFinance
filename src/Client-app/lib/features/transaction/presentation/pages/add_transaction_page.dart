import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_colors.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  int _selectedSegment = 0; // 0: Chi tiêu, 1: Thu nhập, 2: Chuyển khoản
  String _amountString = "0";
  String _selectedWalletName = 'Ví chính • 15.000.000đ';
  String _destinationWalletName = 'Tài khoản Tiết kiệm • 50.000.000đ';

  void _showWalletPickerBottomSheet(BuildContext context, {required bool isDestination}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final wallets = [
          {'name': 'Ví chính', 'balance': '15.000.000đ', 'type': 'Ví tiền mặt', 'icon': Icons.account_balance_wallet},
          {'name': 'Techcombank', 'balance': '35.250.000đ', 'type': 'Tài khoản ngân hàng', 'icon': Icons.account_balance},
          {'name': 'Tài khoản Tiết kiệm', 'balance': '50.000.000đ', 'type': 'Sổ tiết kiệm', 'icon': Icons.savings},
          {'name': 'Momo Wallet', 'balance': '2.500.000đ', 'type': 'Ví điện tử', 'icon': Icons.account_balance_wallet_outlined},
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDestination ? 'Chọn ví đích' : 'Chọn ví thanh toán',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...wallets.map((wallet) {
                final walletStr = "${wallet['name']} • ${wallet['balance']}";
                final isSelected = isDestination
                    ? _destinationWalletName == walletStr
                    : _selectedWalletName == walletStr;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isDestination) {
                        _destinationWalletName = walletStr;
                      } else {
                        _selectedWalletName = walletStr;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.surfaceContainerHigh : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(wallet['icon'] as IconData, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet['name'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                wallet['type'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          wallet['balance'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                        ]
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = "0";
        }
      } else if (key == '000') {
        if (_amountString != "0") {
          _amountString += '000';
        }
      } else if (key == '.') {
        // Just for demo, avoid multiple dots
        if (!_amountString.contains('.')) {
          _amountString += '.';
        }
      } else if (key == 'done' || key == '+' || key == '-') {
        // Operators or done action
      } else {
        if (_amountString == "0") {
          _amountString = key;
        } else {
          _amountString += key;
        }
      }
    });
  }

  String _getFormattedAmount() {
    if (_amountString == "0") return "0đ";
    // Avoid formatting if it has dot
    if (_amountString.contains('.')) return "$_amountStringđ";
    try {
      final number = int.parse(_amountString);
      final formatter = NumberFormat('#,###', 'vi_VN');
      return "${formatter.format(number)}đ";
    } catch (_) {
      return "$_amountStringđ";
    }
  }

  Color _getAmountColor() {
    if (_selectedSegment == 0) return AppColors.primary; // Wait, in stitch it's primary for expense
    if (_selectedSegment == 1) return AppColors.income;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thêm giao dịch',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    _buildSegmentControl(),
                    const SizedBox(height: 32),
                    _buildAmountDisplay(),
                    const SizedBox(height: 32),
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildNumericKeyboard(),
                  ],
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegmentButton(0, 'Chi tiêu')),
          Expanded(child: _buildSegmentButton(1, 'Thu nhập')),
          Expanded(child: _buildSegmentButton(2, 'Chuyển khoản')),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title) {
    bool isSelected = _selectedSegment == index;
    Color bgColor = Colors.transparent;
    Color textColor = AppColors.textSecondary;

    if (isSelected) {
      if (index == 0) {
        bgColor = AppColors.expense;
        textColor = Colors.white;
      } else if (index == 1) {
        bgColor = AppColors.income;
        textColor = Colors.white;
      } else {
        bgColor = AppColors.primary;
        textColor = Colors.white;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSegment = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Column(
      children: [
        Text(
          _getFormattedAmount(),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
            color: _getAmountColor(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'VNĐ - VIỆT NAM ĐỒNG',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    bool isTransfer = _selectedSegment == 2;

    return Container(
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
          if (!isTransfer) ...[
            _buildFormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví thanh toán',
              valueWidget: Text(
                _selectedWalletName,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () => _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.category,
              label: 'Danh mục',
              valueWidget: const Text(
                'Chọn danh mục',
                style: TextStyle(fontSize: 16, color: AppColors.primary),
              ),
              showArrow: true,
              onTap: () => context.push('/add/category'),
            ),
          ] else ...[
            _buildFormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví nguồn (Từ ví)',
              valueWidget: Text(
                _selectedWalletName,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () => _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.account_balance_wallet,
              label: 'Ví đích (Đến ví)',
              valueWidget: Text(
                _destinationWalletName,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () => _showWalletPickerBottomSheet(context, isDestination: true),
            ),
          ],
          Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          _buildFormRow(
            icon: Icons.notes,
            label: 'Ghi chú',
            valueWidget: const Text(
              'Thêm ghi chú cho giao dịch...',
              style: TextStyle(fontSize: 16, color: AppColors.outlineVariant),
            ),
            showArrow: false,
          ),
          Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          _buildFormRow(
            icon: Icons.calendar_today,
            label: 'Ngày',
            valueWidget: const Text(
              'Hôm nay, 30/06',
              style: TextStyle(fontSize: 16, color: AppColors.primary),
            ),
            trailingIcon: Icons.calendar_month,
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
    bool showArrow = false,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                valueWidget,
              ],
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: AppColors.outline)
          else if (showArrow)
            const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    ),
    );
  }

  Widget _buildNumericKeyboard() {
    final keys = [
      '7', '8', '9', 'backspace',
      '4', '5', '6', '+',
      '1', '2', '3', '-',
      '.', '0', '000', 'done'
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2, // slightly wider than 1:1 for numeric keys
      ),
      itemBuilder: (context, index) {
        final keyStr = keys[index];
        bool isOperator = keyStr == 'backspace' || keyStr == '+' || keyStr == '-';
        bool isDone = keyStr == 'done';

        return Material(
          color: isDone
              ? AppColors.primary
              : isOperator
                  ? AppColors.surfaceContainer
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _onKeyPress(keyStr),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isOperator && !isDone)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: _buildKeyContent(keyStr, isDone),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyContent(String keyStr, bool isDone) {
    if (keyStr == 'backspace') {
      return const Icon(Icons.backspace_outlined, size: 24, color: AppColors.primary);
    }
    if (keyStr == 'done') {
      return const Icon(Icons.check, size: 28, color: Colors.white);
    }
    if (keyStr == '+' || keyStr == '-') {
      return Text(
        keyStr,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.normal, color: AppColors.primary),
      );
    }
    return Text(
      keyStr,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.9),
            blurRadius: 20,
            spreadRadius: 10,
            offset: const Offset(0, -20),
          )
        ]
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        ),
        child: const Text(
          'Lưu giao dịch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
