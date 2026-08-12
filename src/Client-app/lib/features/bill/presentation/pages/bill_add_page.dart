import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';

class BillAddPage extends StatefulWidget {
  const BillAddPage({super.key});

  @override
  State<BillAddPage> createState() => _BillAddPageState();
}

class _BillAddPageState extends State<BillAddPage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 7));
  String _selectedCycle = 'monthly'; // 'weekly' | 'monthly' | 'yearly' | 'once'
  bool _pushNotificationsEnabled = true;
  bool _autoPayEnabled = true;
  String _selectedReminderDay = '1';

  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final db = context.read<AppDatabase>();
    final wallets = await db.walletDao.getAll(1);
    if (mounted) {
      setState(() {
        _wallets = wallets;
        if (wallets.isNotEmpty) {
          _selectedWallet = wallets.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên dịch vụ / hóa đơn')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ (> 0)')),
      );
      return;
    }

    final billId = const Uuid().v4();
    final now = DateTime.now();

    final newBill = BillsCompanion.insert(
      id: billId,
      idaccount: 1,
      name: name,
      amount: amount,
      dueDate: _selectedDueDate,
      isPaid: const drift.Value(false),
      recurrence: drift.Value(_selectedCycle),
      note: drift.Value(_noteController.text.trim()),
      syncStatus: const drift.Value('pending'),
      updatedAt: now,
    );

    context.read<BillBloc>().add(AddBillEvent(bill: newBill));
    context.pop();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

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
              onPressed: _submit,
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
    final dateFormatter = DateFormat('dd/MM/yyyy');

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
            controller: _nameController,
            icon: Icons.payments_outlined,
            placeholder: 'e.g. Netflix Premium',
          ),
          const SizedBox(height: 16),

          _buildInputLabel('SỐ TIỀN ĐỊNH KỲ'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _amountController,
            icon: Icons.monetization_on_outlined,
            placeholder: '0đ',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 16),

          _buildInputLabel('NGÀY ĐẾN HẠN THANH TOÁN'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDueDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.outline, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Ngày ${dateFormatter.format(_selectedDueDate)}',
                    style: const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_calendar, color: AppColors.outline, size: 20),
                ],
              ),
            ),
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
          _buildWalletDropdownField(),

          const SizedBox(height: 16),
          _buildInputLabel('GHI CHÚ'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _noteController,
            icon: Icons.notes_outlined,
            placeholder: 'Thêm ghi chú (tùy chọn)...',
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
                      fontSize: 14,
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
          if (_pushNotificationsEnabled) ...[
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
          ],
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
                          fontSize: 14,
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
    required TextEditingController controller,
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
              controller: controller,
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

  Widget _buildWalletDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: AppColors.outline, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Wallet>(
                value: _selectedWallet,
                icon: const Icon(Icons.expand_more, color: AppColors.outline),
                isExpanded: true,
                style: const TextStyle(fontSize: 16, color: AppColors.primary),
                dropdownColor: Colors.white,
                onChanged: (Wallet? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedWallet = newValue;
                    });
                  }
                },
                items: _wallets.map<DropdownMenuItem<Wallet>>((Wallet wallet) {
                  return DropdownMenuItem<Wallet>(
                    value: wallet,
                    child: Text('${wallet.name} - ${wallet.balance.toStringAsFixed(0)}đ'),
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
          _buildCycleOption('Hàng tuần', 'weekly'),
          _buildCycleOption('Hàng tháng', 'monthly'),
          _buildCycleOption('Hàng năm', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildCycleOption(String label, String value) {
    final isSelected = _selectedCycle == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCycle = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
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
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
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
          onTap: _submit,
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
