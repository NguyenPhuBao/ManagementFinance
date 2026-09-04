import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/auth/current_account.dart';
import '../../domain/bill_draft.dart';
import '../../domain/bill_schedule.dart';
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
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  /// Chu kỳ + ngày bắt đầu; ngày đến hạn suy ra. Xem `BillSchedule`.
  late BillSchedule _lich;

  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;
  List<Category> _categories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    _nameController = TextEditingController(text: bill?.name ?? '');
    _amountController = TextEditingController(
      text: bill?.amount.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(text: bill?.note ?? '');
    // `fromBill` phát hiện hoá đơn cũ có hạn trả không khớp chu kỳ và dựng
    // sẵn lời cảnh báo — nay hạn luôn suy từ chu kỳ nên lưu lại là đổi hạn
    // của người dùng, không được đổi ngầm.
    _lich = bill != null
        ? BillSchedule.fromBill(bill)
        : BillSchedule(
            startDate: DateTime.now(),
            timeRecurrence: kBillCycleMonth,
            repeat: true,
          );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPickers());
  }

  Future<void> _loadPickers() async {
    final accountId = currentAccountIdOrNull(context);
    if (accountId == null) return;
    final db = sl<AppDatabase>();
    final wallets = await db.walletDao.getAll(accountId);
    final categories = await db.categoryDao.getCategoryRows(accountId, 'chi');
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _categories = categories;
      // Giữ lựa chọn cũ của hoá đơn nếu nó còn tồn tại; nếu không (hoá đơn do
      // bản client cũ tạo ra, walletId/categoryId = null) thì để người dùng
      // chọn — đây là đường duy nhất trong app để vá những hàng đang kẹt.
      _selectedWallet = _firstWhereOrNull(wallets, widget.bill?.walletId);
      _selectedCategory =
          _firstWhereOrNull(categories, widget.bill?.categoryId);
    });
  }

  static T? _firstWhereOrNull<T>(List<T> items, String? id) {
    if (id == null) return null;
    for (final item in items) {
      if ((item as dynamic).id == id) return item;
    }
    return null;
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

    // Sửa hoá đơn cũng ghi lại idaccount. Trước đây chỗ này rơi về 1 khi trạng
    // thái đăng nhập chưa sẵn sàng, tức chuyển hoá đơn sang tài khoản admin.
    final accountId = currentAccountIdOrNull(context);
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác định được tài khoản đăng nhập. '
              'Vui lòng đăng nhập lại trước khi sửa hoá đơn.'),
        ),
      );
      return;
    }

    // Ví và danh mục NOT NULL phía backend — không cho lưu về trạng thái
    // thiếu, vì đó chính là thứ khiến hoá đơn kẹt vĩnh viễn trong hàng đợi đẩy.
    final wallet = _selectedWallet;
    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví thanh toán.')),
      );
      return;
    }
    final category = _selectedCategory;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục cho hoá đơn.')),
      );
      return;
    }

    final loiNgay = _lich.dateError;
    if (loiNgay != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loiNgay)));
      return;
    }

    final draft = BillDraft(
      name: name,
      amount: amount,
      startDate: _lich.startDate,
      dueDate: _lich.dueDate,
      walletId: wallet.id,
      categoryId: category.id,
      isRecurring: _lich.isRecurring,
      timeRecurrence: _lich.storedTimeRecurrence,
      note: _noteController.text.trim(),
    );

    context.read<BillBloc>().add(
          EditBillEvent(
            bill: draft.toUpdateCompanion(
              id: widget.id,
              idaccount: accountId,
              now: DateTime.now(),
            ),
          ),
        );
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lich.startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => _lich = _lich.copyWith(startDate: picked));
  }

  Widget _canhBaoHanCuWidget() {
    final loi = _lich.canhBaoHanCu;
    if (loi == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        loi,
        key: const ValueKey('bill-due-date-warning'),
        style: const TextStyle(fontSize: 13, color: AppColors.error),
      ),
    );
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
                    title: const Text('Ngày bắt đầu hóa đơn'),
                    subtitle: Text(dateFormatter.format(_lich.startDate)),
                    trailing: const Icon(Icons.calendar_today,
                        color: AppColors.primary),
                    onTap: _pickStartDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    title: const Text('Ngày đến hạn thanh toán'),
                    subtitle: Text(dateFormatter.format(_lich.dueDate)),
                    trailing: const Icon(Icons.lock_outline,
                        color: AppColors.primary),
                  ),
                  _canhBaoHanCuWidget(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _lich.timeRecurrence,
                    decoration: const InputDecoration(
                      labelText: 'Chu kỳ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: kBillCycleWeek, child: Text('Hàng tuần')),
                      DropdownMenuItem(
                          value: kBillCycleMonth, child: Text('Hàng tháng')),
                      DropdownMenuItem(
                          value: kBillCycleQuarter, child: Text('Hàng quý')),
                      DropdownMenuItem(
                          value: kBillCycleYear, child: Text('Hàng năm')),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _lich = _lich.copyWith(timeRecurrence: val));
                    },
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Lặp lại theo chu kỳ')),
                      Switch(
                        key: const ValueKey('bill-recurrence-switch'),
                        value: _lich.repeat,
                        onChanged: (v) =>
                            setState(() => _lich = _lich.copyWith(repeat: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Wallet>(
                    initialValue: _selectedWallet,
                    decoration: const InputDecoration(
                      labelText: 'Ví thanh toán',
                      border: OutlineInputBorder(),
                    ),
                    items: _wallets
                        .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWallet = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Category>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
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
