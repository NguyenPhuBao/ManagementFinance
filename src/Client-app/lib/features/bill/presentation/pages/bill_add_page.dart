import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/segmented_choice.dart';
import '../../domain/bill_auto_pay.dart' show kBillAutoPayHint;
import '../../domain/bill_draft.dart';
import '../../domain/bill_schedule.dart';
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

  /// Chu kỳ + ngày bắt đầu; ngày đến hạn suy ra. Xem `BillSchedule`.
  BillSchedule _lich = BillSchedule(
    startDate: DateTime.now(),
    timeRecurrence: kBillCycleMonth,
    repeat: true,
  );
  /// Bật/tắt nhắc trước hạn. Tắt thì ghi `timeNotification = null`.
  bool _pushNotificationsEnabled = true;
  String _selectedReminderDay = '3';

  /// TẮT sẵn. Bản trước có công tắc cùng tên bật sẵn mà không lưu ở đâu (gỡ
  /// 06/09); nay có cột và bộ chạy thật, nhưng bật sẵn vẫn là chuyển tiền
  /// dựa trên một lựa chọn người dùng chưa từng đưa ra.
  bool _autoPayEnabled = false;

  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;

  List<Category> _categories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPickers();
    });
  }

  Future<void> _loadPickers() async {
    final accountId = currentAccountIdOrNull(context);
    final db = sl<AppDatabase>();
    // KHÔNG còn nhánh `getAllNonDeleted()` khi danh sách rỗng: nhánh đó bỏ bộ
    // lọc tài khoản, nên một tài khoản chưa có ví lại nhìn thấy ví của tài
    // khoản khác từng đăng nhập trên cùng máy — và hoá đơn tạo ra sẽ trỏ vào
    // một ví không thuộc về mình.
    final wallets = accountId == null
        ? <Wallet>[]
        : await db.walletDao.getAll(accountId);
    // Hoá đơn luôn là khoản chi nên chỉ lấy danh mục 'chi', giống trang ngân
    // sách. `getCategoryRows` gồm cả danh mục mặc định (idaccount = 0).
    final categories = accountId == null
        ? <Category>[]
        : await db.categoryDao.getCategoryRows(accountId, 'chi');
    if (mounted) {
      setState(() {
        _wallets = wallets;
        if (wallets.isNotEmpty) {
          _selectedWallet = wallets.first;
        }
        _categories = categories;
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
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

    // Danh tính CHỈ đến từ phiên đăng nhập. Trước đây chỗ này rơi về 1 khi
    // trạng thái đăng nhập chưa sẵn sàng — tức ghi hoá đơn vào tài khoản admin.
    final accountId = currentAccountIdOrNull(context);
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác định được tài khoản đăng nhập. '
              'Vui lòng đăng nhập lại trước khi tạo hoá đơn.'),
        ),
      );
      return;
    }

    // Ví và danh mục là BẮT BUỘC: `bill.Idwallet` và `bill.Idcategory` đều
    // NOT NULL phía backend. Hoá đơn thiếu chúng ghi được xuống SQLite nhưng
    // bị /sync/push từ chối ở mọi chu kỳ và kẹt lại trong hàng đợi.
    final wallet = _selectedWallet;
    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo và chọn ví thanh toán.')),
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
      timeNotification:
          _pushNotificationsEnabled ? _selectedReminderDay : null,
      note: _noteController.text.trim(),
      autoPayEnabled: _autoPayEnabled,
    );

    context.read<BillBloc>().add(
          AddBillEvent(
            bill: draft.toInsertCompanion(
              id: const Uuid().v4(),
              idaccount: accountId,
              now: DateTime.now(),
            ),
          ),
        );
    context.pop();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lich.startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => _lich = _lich.copyWith(startDate: picked));
  }

  void _chonChuKy(String value) {
    setState(() => _lich = _lich.copyWith(timeRecurrence: value));
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

          _buildInputLabel('NGÀY BẮT ĐẦU HÓA ĐƠN'),
          const SizedBox(height: 8),
          _buildDateField(
            value: _lich.startDate,
            onTap: _pickStartDate,
            formatter: dateFormatter,
          ),
          const SizedBox(height: 16),

          _buildInputLabel('NGÀY ĐẾN HẠN THANH TOÁN'),
          const SizedBox(height: 8),
          _buildDateField(
            value: _lich.dueDate,
            onTap: null,
            formatter: dateFormatter,
            khoa: true,
          ),
          const SizedBox(height: 16),

          _buildInputLabel('CHU KỲ'),
          const SizedBox(height: 8),
          _buildCycleSelector(),
          const SizedBox(height: 12),
          _buildRecurrenceSwitch(),
          const SizedBox(height: 16),

          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 16),

          _buildInputLabel('VÍ THANH TOÁN NGUỒN'),
          const SizedBox(height: 8),
          _buildWalletDropdownField(),

          const SizedBox(height: 16),
          _buildInputLabel('DANH MỤC'),
          const SizedBox(height: 8),
          _buildCategoryDropdownField(),

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
              // `Expanded` ở cả hai tầng: nhãn dài + công tắc tràn 128px ở
              // 411dp. Bộ test chạy 1280px nên không ai thấy cho tới khi có
              // widget test dựng đúng bề rộng điện thoại.
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.notifications_active,
                        color: AppColors.secondary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bật nhắc nhở thông báo đẩy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
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
            // `Wrap` chứ không phải `Row`: bốn chip tràn 115px ở 411dp, và
            // chip thứ tư ('7 ngày') là chip mới thêm hôm 04/09 nên chỗ tràn
            // này chưa từng có ai nhìn thấy.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReminderDayChip('1 ngày', '1'),
                _buildReminderDayChip('3 ngày', '3'),
                _buildReminderDayChip('5 ngày', '5'),
                // Mốc '7' được CSDL cho phép ở cả hai đầu nhưng UI trước đây
                // thiếu — người dùng không đặt được nhắc trước một tuần.
                _buildReminderDayChip('7 ngày', '7'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildAutoPaySwitch(),
        ],
      ),
    );
  }

  /// Khối theo Stitch "Thêm Hóa Đơn Định Kỳ" (biểu tượng `smart_toy`, dưới
  /// các chip nhắc, sau vạch mỏng) — nhưng công tắc TẮT sẵn, và có dòng phụ
  /// nói rõ ba điều người dùng cần biết trước khi uỷ quyền: trừ ví nào, lúc
  /// nào, và vì sao chỉ nên bật trên một thiết bị (cột cục bộ, hai máy cùng
  /// bật là hai khoản chi).
  Widget _buildAutoPaySwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.smart_toy, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tự động thanh toán',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Trừ từ ví thanh toán khi đến hạn',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('bill-autopay-switch'),
              value: _autoPayEnabled,
              onChanged: (val) => setState(() => _autoPayEnabled = val),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
        if (_autoPayEnabled) ...[
          const SizedBox(height: 8),
          const Text(
            kBillAutoPayHint,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
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

  Widget _buildCategoryDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: AppColors.outline, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Category>(
                value: _selectedCategory,
                icon: const Icon(Icons.expand_more, color: AppColors.outline),
                isExpanded: true,
                style: const TextStyle(fontSize: 16, color: AppColors.primary),
                dropdownColor: Colors.white,
                hint: const Text('Chọn danh mục'),
                onChanged: (Category? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedCategory = newValue);
                  }
                },
                items: _categories.map<DropdownMenuItem<Category>>((category) {
                  return DropdownMenuItem<Category>(
                    value: category,
                    child: Text(category.name),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? value,
    required VoidCallback? onTap,
    required DateFormat formatter,
    bool khoa = false,
  }) {
    return Opacity(
      opacity: khoa ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(khoa ? Icons.lock_outline : Icons.calendar_month_outlined,
                  color: AppColors.outline, size: 24),
              const SizedBox(width: 12),
              Text(
                value == null ? 'Chưa chọn' : 'Ngày ${formatter.format(value)}',
                style: const TextStyle(fontSize: 16, color: AppColors.primary),
              ),
              const Spacer(),
              if (!khoa)
                const Icon(Icons.edit_calendar,
                    color: AppColors.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Công tắc "Lặp lại theo chu kỳ" — ghi vào `isRecurrence`.
  ///
  /// Tắt KHÔNG làm mất cách tính ngày đến hạn: hoá đơn vẫn chạy đúng một kỳ
  /// dài bằng chu kỳ đã chọn, chỉ là không sinh kỳ mới sau khi thanh toán.
  Widget _buildRecurrenceSwitch() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Lặp lại theo chu kỳ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
        Switch(
          key: const ValueKey('bill-recurrence-switch'),
          value: _lich.repeat,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.secondary,
          onChanged: (v) => setState(() => _lich = _lich.copyWith(repeat: v)),
        ),
      ],
    );
  }

  /// Bốn chu kỳ trên **một hàng ngang**, chia đều bề rộng.
  ///
  /// Từng là `Wrap` và xếp thành bốn hàng dọc — lý do và cách tránh nằm ở
  /// [SegmentedChoice], nay dùng chung với ngân sách và mục tiêu.
  Widget _buildCycleSelector() {
    const nhan = <String, String>{
      kBillCycleWeek: 'Hàng tuần',
      kBillCycleMonth: 'Hàng tháng',
      kBillCycleQuarter: 'Hàng quý',
      kBillCycleYear: 'Hàng năm',
    };
    return SegmentedChoice<String>(
      keyPrefix: 'bill-cycle',
      options: [
        for (final e in nhan.entries) SegmentedOption(e.key, e.value),
      ],
      selected: _lich.timeRecurrence,
      onChanged: _chonChuKy,
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
                // Nhãn dài tràn 141px ở 411dp. Co chữ thay vì tràn, cũng là
                // đường phòng khi người dùng đặt cỡ chữ hệ thống lớn.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tạo Hóa Đơn & Đăng Ký Nhắc Nhở',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
