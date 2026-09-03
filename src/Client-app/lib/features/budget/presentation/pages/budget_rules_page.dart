import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';
import '../bloc/budget_cubit.dart';
import '../widgets/budget_visuals.dart';

/// Tạo hoặc sửa một ngân sách.
///
/// `?id=<uuid>` trên đường dẫn nghĩa là sửa; không có thì là tạo mới.
///
/// ## Vì sao form này khác bản dựng hình ban đầu
///
/// Bản mockup có ba phần không có chỗ nào để lưu:
/// - **"Tên ngân sách"** — backend không có cột tên (`model budget` trong
///   `schema.prisma`). Danh tính của ngân sách là *danh mục + chu kỳ*.
/// - **"Danh mục áp dụng" nhiều danh mục** — cột `Idcategory` chỉ giữ được
///   MỘT. Muốn đặt hạn mức cho ba danh mục thì tạo ba ngân sách.
/// - **"Quy tắc phân bổ 50/30/20"** — không có bảng nào lưu, và nó nói về việc
///   chia *thu nhập* chứ không phải hạn mức của một ngân sách. Đây là một
///   feature riêng, không thuộc phạm vi lần này.
///
/// Giữ lại chúng dưới dạng giao diện không lưu được gì sẽ tái lập đúng vấn đề
/// cũ: người dùng bấm Lưu và tưởng đã lưu.
class BudgetRulesPage extends StatelessWidget {
  /// null = tạo mới.
  final String? budgetId;

  const BudgetRulesPage({super.key, this.budgetId});

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<BudgetCubit>(
      create: (_) =>
          sl<BudgetCubit>()..loadEditor(idaccount, budgetId: budgetId),
      child: _BudgetRulesContent(idaccount: idaccount),
    );
  }
}

class _BudgetRulesContent extends StatelessWidget {
  final int? idaccount;
  const _BudgetRulesContent({required this.idaccount});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BudgetCubit, BudgetState>(
      listenWhen: (_, s) => s is BudgetSaved,
      listener: (context, state) {
        if (state is! BudgetSaved) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message)));
        context.pop();
      },
      buildWhen: (_, s) =>
          s is BudgetEditorReady || s is BudgetLoading || s is BudgetError,
      builder: (context, state) => switch (state) {
        BudgetEditorReady() => _BudgetForm(state: state, idaccount: idaccount),
        BudgetError(:final message) => _ErrorScaffold(message: message),
        _ => const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      },
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── Form ────────────────────────────────────────────────────────────────────

class _BudgetForm extends StatefulWidget {
  final BudgetEditorReady state;
  final int? idaccount;

  const _BudgetForm({required this.state, required this.idaccount});

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _thresholdPercentController;
  late final TextEditingController _noteController;

  String? _categoryId;
  late String _timeRecurrence;
  late String _overSpending;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final b = widget.state.editing;
    _amountController = TextEditingController(
        text: b == null ? '' : b.amount.round().toString());
    _thresholdController = TextEditingController(
        text: b?.thresholdWarningAmount?.round().toString() ?? '');
    _thresholdPercentController = TextEditingController(
        text: b?.thresholdWarningPercent?.round().toString() ?? '');
    _noteController = TextEditingController(text: b?.note ?? '');
    _categoryId = b?.categoryId;
    _timeRecurrence = b?.timeRecurrence ?? BudgetRecurrence.month;
    _overSpending = b?.overSpending ?? BudgetOverSpending.over;
    final now = DateTime.now();
    _startDate = b?.startDate ?? DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _thresholdController.dispose();
    _thresholdPercentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<BudgetCubit>();
    final amount = CurrencyFormatter.parse(_amountController.text) ?? 0;
    final threshold = _thresholdController.text.trim().isEmpty
        ? null
        : CurrencyFormatter.parse(_thresholdController.text);
    final percentText = _thresholdPercentController.text.trim();
    // Lưu nguyên đơn vị phần trăm 0–100 để khớp cột backend; việc quy về tỉ lệ
    // nằm ở `BudgetEntity.warningRatio`.
    final thresholdPercent = percentText.isEmpty
        ? null
        : double.tryParse(percentText.replaceAll(',', '.'));
    final note = _noteController.text.trim();

    final editing = widget.state.editing;
    if (editing == null) {
      cubit.addBudget(
        idaccount: widget.idaccount,
        amount: amount,
        categoryId: _categoryId,
        thresholdWarningAmount: threshold,
        thresholdWarningPercent: thresholdPercent,
        overSpending: _overSpending,
        startDate: _startDate,
        // Ngân sách luôn lặp lại: hạn mức tiêu dùng một lần rồi thôi gần như
        // không có nghĩa. Ai cần khoảng cố định thì đặt `endDate` — chưa có ô
        // nhập nên chưa mở ra ở form này.
        recurrence: true,
        timeRecurrence: _timeRecurrence,
        note: note,
      );
    } else {
      cubit.updateBudget(editing.copyWith(
        categoryId: () => _categoryId,
        amount: amount,
        thresholdWarningAmount: () => threshold,
        thresholdWarningPercent: () => thresholdPercent,
        overSpending: _overSpending,
        startDate: _startDate,
        timeRecurrence: _timeRecurrence,
        note: note,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.state.isCreating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          creating ? 'Tạo ngân sách' : 'Sửa ngân sách',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Lưu',
              style: TextStyle(
                  color: AppColors.income, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Thiết lập ngân sách'),
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Danh mục áp dụng'),
                    const SizedBox(height: 8),
                    _categoryPicker(),
                    const SizedBox(height: 16),
                    _label('Hạn mức chi tiêu'),
                    const SizedBox(height: 8),
                    _amountField(),
                    const SizedBox(height: 16),
                    _label('Chu kỳ'),
                    const SizedBox(height: 8),
                    _recurrencePicker(),
                    const SizedBox(height: 16),
                    _label('Bắt đầu từ'),
                    const SizedBox(height: 8),
                    _startDatePicker(),
                  ],
                )),
                const SizedBox(height: 32),
                _sectionTitle('Ngưỡng cảnh báo'),
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Đặt một trong hai, hoặc bỏ trống cả hai để dùng mặc '
                      'định 90%. Nếu điền cả hai thì ngưỡng theo số tiền được '
                      'ưu tiên, vì nó cụ thể hơn.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _label('Còn lại dưới (đồng)'),
                    const SizedBox(height: 8),
                    _thresholdField(),
                    const SizedBox(height: 16),
                    _label('Hoặc đã tiêu quá (%)'),
                    const SizedBox(height: 8),
                    _thresholdPercentField(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.surfaceContainerHigh),
                    ),
                    _label('Khi tiêu vượt hạn mức'),
                    const SizedBox(height: 8),
                    _overSpendingPicker(),
                  ],
                )),
                const SizedBox(height: 32),
                _sectionTitle('Ghi chú'),
                _card(TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: _inputDecoration('Không bắt buộc'),
                )),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: Text(
                    creating ? 'Tạo ngân sách' : 'Lưu thay đổi',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Các ô nhập ──────────────────────────────────────────────────────────────

  Widget _categoryPicker() {
    final categories = widget.state.categories;
    // Danh mục của ngân sách đang sửa có thể đã bị xoá — khi đó nó không nằm
    // trong danh sách và `DropdownButtonFormField` sẽ ném lỗi vì `value` không
    // khớp item nào. Rơi về "ngân sách tổng" thay vì làm trắng trang.
    final valid = _categoryId == null ||
        categories.any((c) => c.id == _categoryId);

    return DropdownButtonFormField<String?>(
      initialValue: valid ? _categoryId : null,
      isExpanded: true,
      decoration: _inputDecoration(null),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.all_inclusive, size: 20, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Ngân sách tổng (mọi khoản chi)'),
            ],
          ),
        ),
        ...categories.map((c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Row(
                children: [
                  Icon(budgetIconFor(c.icon),
                      size: 20, color: budgetColorFrom(c.colour)),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  Widget _amountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
      ),
      decoration: _inputDecoration('Ví dụ: 5000000'),
      validator: (value) {
        final parsed = CurrencyFormatter.parse(value ?? '');
        if (parsed == null) return 'Nhập số tiền';
        if (parsed <= 0) return 'Hạn mức phải lớn hơn 0';
        return null;
      },
    );
  }

  Widget _thresholdField() {
    return TextFormField(
      controller: _thresholdController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16, color: AppColors.primary),
      decoration: _inputDecoration('Ví dụ: 500000'),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = CurrencyFormatter.parse(text);
        if (parsed == null) return 'Nhập số tiền hoặc để trống';
        if (parsed < 0) return 'Không được âm';
        final amount = CurrencyFormatter.parse(_amountController.text);
        if (amount != null && parsed > amount) {
          return 'Ngưỡng lớn hơn hạn mức thì sẽ cảnh báo ngay từ đồng đầu tiên';
        }
        return null;
      },
    );
  }

  Widget _thresholdPercentField() {
    return TextFormField(
      controller: _thresholdPercentController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16, color: AppColors.primary),
      decoration: _inputDecoration('Ví dụ: 80'),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null) return 'Nhập số phần trăm hoặc để trống';
        // Chặn ở đây thay vì lặng lẽ bỏ qua như `BudgetEntity.warningRatio`:
        // getter đó phòng dữ liệu hỏng từ đồng bộ, còn ở form thì người dùng
        // cần biết mình gõ sai.
        if (parsed <= 0 || parsed > 100) return 'Phải trong khoảng 1–100';
        return null;
      },
    );
  }

  Widget _recurrencePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BudgetRecurrence.all.map((value) {
        final selected = _timeRecurrence == value;
        return GestureDetector(
          onTap: () => setState(() => _timeRecurrence = value),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color:
                    selected ? AppColors.primary : AppColors.outlineVariant,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              BudgetRecurrence.label(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _overSpendingPicker() {
    // Cố ý không dùng `RadioListTile`: `groupValue`/`onChanged` của nó đã bị
    // đánh dấu deprecated từ Flutter 3.32, dùng vào sẽ thêm cảnh báo mới vào
    // mức nền của `flutter analyze`.
    return Column(
      children: [
        _choiceRow(
          value: BudgetOverSpending.over,
          label: 'Chỉ cảnh báo, vẫn cho ghi thêm',
        ),
        const SizedBox(height: 8),
        _choiceRow(
          value: BudgetOverSpending.stop,
          label: 'Chặn không cho tiêu thêm',
        ),
      ],
    );
  }

  Widget _choiceRow({required String value, required String label}) {
    final selected = _overSpending == value;
    return InkWell(
      onTap: () => setState(() => _overSpending = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _startDate = picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(null),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              '${_startDate.day.toString().padLeft(2, '0')}/'
              '${_startDate.month.toString().padLeft(2, '0')}/'
              '${_startDate.year}',
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mảnh dùng lại ───────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.outline,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _card(Widget child) => Container(
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
        child: child,
      );

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
}

