import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';

class BillEditPage extends StatefulWidget {
  final String id;
  final Bill? bill;

  const BillEditPage({
    super.key,
    required this.id,
    this.bill,
  });

  @override
  State<BillEditPage> createState() => _BillEditPageState();
}

class _BillEditPageState extends State<BillEditPage> {
  int _getAccountId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess && authState.user != null) {
      return int.tryParse(authState.user!.id) ?? 1;
    }
    return 1;
  }
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDueDate;
  late String _selectedCycle;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bill?.name ?? '');
    _amountController = TextEditingController(
      text: widget.bill?.amount.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(text: widget.bill?.note ?? '');
    _selectedDueDate = widget.bill?.dueDate ?? DateTime.now();
    _selectedCycle = widget.bill?.recurrence ?? 'monthly';
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
        const SnackBar(content: Text('Vui lòng nhập tên dịch vụ/hóa đơn')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ (> 0)')),
      );
      return;
    }

    final now = DateTime.now();

    final updatedBill = BillsCompanion(
      id: drift.Value(widget.id),
      idaccount: drift.Value(_getAccountId(context)),
      name: drift.Value(name),
      amount: drift.Value(amount),
      dueDate: drift.Value(_selectedDueDate),
      recurrence: drift.Value(_selectedCycle),
      note: drift.Value(_noteController.text.trim()),
      syncStatus: const drift.Value('pending'),
      updatedAt: drift.Value(now),
    );

    context.read<BillBloc>().add(EditBillEvent(bill: updatedBill));
    context.pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hóa đơn'),
        content: const Text('Bạn có chắc chắn muốn xóa hóa đơn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BillBloc>().add(DeleteBillEvent(id: widget.id));
              context.pop();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Chỉnh Sửa Hóa Đơn',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0DB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên dịch vụ / Hóa đơn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền (VNĐ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ngày đến hạn thanh toán'),
                    subtitle: Text(dateFormatter.format(_selectedDueDate)),
                    trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
                    onTap: _pickDueDate,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCycle,
                    decoration: const InputDecoration(
                      labelText: 'Chu kỳ lặp lại',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Không lặp lại')),
                      DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
                      DropdownMenuItem(value: 'monthly', child: Text('Hàng tháng')),
                      DropdownMenuItem(value: 'yearly', child: Text('Hàng năm')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCycle = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Xóa hóa đơn'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Cập nhật',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
