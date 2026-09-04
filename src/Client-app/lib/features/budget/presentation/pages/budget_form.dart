import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';
import '../../data/models/budget_period.dart';
import '../widgets/budget_visuals.dart';

/// Dữ liệu form đã chuẩn hoá, sẵn sàng ghi xuống.
///
/// Tách khỏi [BudgetEntity] vì form không biết `id`, `idaccount` hay trạng thái
/// đồng bộ — đó là việc của repository. Dựng thẳng entity ở đây sẽ dụ người
/// viết mã sau đặt `syncStatus` từ giao diện.
class BudgetDraft {
  final String categoryId;
  final double amount;
  final double? thresholdWarningAmount;
  final double? thresholdWarningPercent;
  final String overSpending;
  final DateTime startDate;
  final DateTime? endDate;
  final bool recurrence;

  /// null = không theo chu kỳ nào ("Ngày cụ thể").
  final String? timeRecurrence;
  final String note;

  const BudgetDraft({
    required this.categoryId,
    required this.amount,
    this.thresholdWarningAmount,
    this.thresholdWarningPercent,
    required this.overSpending,
    required this.startDate,
    this.endDate,
    required this.recurrence,
    required this.timeRecurrence,
    required this.note,
  });
}

/// Form tạo/sửa ngân sách.
///
/// Cố ý **không** đọc `BudgetCubit`: kết quả đi ra ngoài qua [onSubmit]. Nhờ vậy
/// đường đi của mốc neo — thứ hỏng trong im lặng nếu tính sai — kiểm được bằng
/// widget test thuần.
class BudgetForm extends StatefulWidget {
  final List<Category> categories;

  /// null = đang tạo mới.
  final BudgetEntity? editing;

  final void Function(BudgetDraft) onSubmit;

  const BudgetForm({
    super.key,
    required this.categories,
    required this.editing,
    required this.onSubmit,
  });

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _thresholdPercentController;
  late final TextEditingController _noteController;

  String? _categoryId;
  String? _timeRecurrence;
  late String _overSpending;
  late bool _recurrence;
  late DateTime _startDate;
  DateTime? _endDate;

  /// Ngân sách này có theo một chu kỳ không.
  ///
  /// false = người dùng chọn "Ngày cụ thể": tự đặt ngày kết thúc, không lặp.
  bool get _theoChuKy => _timeRecurrence != null;

  /// Lời nhắn hiện dưới ô ngày kết thúc khi thứ tự hai ngày bị sai.
  ///
  /// PostgreSQL có ràng buộc `chk_budget_end_after_start`
  /// (`"End" IS NULL OR "End" > "Start"`) — **bằng nhau cũng vi phạm**. Để lọt
  /// thì backend từ chối bằng lỗi 23514, client xếp vào `transient` và đẩy lại
  /// vĩnh viễn, kéo chậm cả hàng đợi đồng bộ.
  String? _endDateError;

  /// Ngày kết thúc do người dùng tự đặt ở chế độ "Ngày cụ thể", đang bị một
  /// chu kỳ ghi đè.
  ///
  /// Khi đã chọn chu kỳ thì ô "Ngày kết thúc" là chỉ đọc và luôn hiển thị cuối
  /// kỳ đầu, nên ngày người dùng đặt trước đó biến mất khỏi màn hình mà không
  /// có dấu hiệu gì. Giữ lại ở đây để cảnh báo được, và để họ đổi ý quay về
  /// "Ngày cụ thể" thì lấy lại nguyên vẹn.
  DateTime? _ngayKetThucBiGhiDe;

  @override
  void initState() {
    super.initState();
    final b = widget.editing;
    _amountController = TextEditingController(
        text: b == null ? '' : b.amount.round().toString());
    _thresholdController = TextEditingController(
        text: b?.thresholdWarningAmount?.round().toString() ?? '');
    _thresholdPercentController = TextEditingController(
        text: b?.thresholdWarningPercent?.round().toString() ?? '');
    _noteController = TextEditingController(text: b?.note ?? '');
    _categoryId = b?.categoryId;
    // Ngân sách đang sửa giữ nguyên chu kỳ đã lưu, kể cả khi nó là null
    // ("Ngày cụ thể"). Chỉ khi tạo mới mới rơi về mặc định hàng tháng.
    _timeRecurrence = b == null ? BudgetRecurrence.month : b.timeRecurrence;
    _overSpending = b?.overSpending ?? BudgetOverSpending.over;
    _recurrence = b?.recurrence ?? true;
    final now = DateTime.now();
    _startDate = b?.startDate ?? DateTime(now.year, now.month, 1);
    _endDate = b?.endDate;
  }

  /// Ngày kết thúc của kỳ đầu tiên, suy từ ngày bắt đầu và chu kỳ.
  ///
  /// Không dùng cho "Ngày cụ thể" — ở đó ngày kết thúc do người dùng chọn.
  DateTime get _cuoiKyDau =>
      advancePeriod(_startDate, _timeRecurrence ?? BudgetRecurrence.month);

  /// Ngày hiện trong ô "Ngày kết thúc".
  ///
  /// Theo chu kỳ thì đây là cuối kỳ đầu, tính lại ngay khi đổi chu kỳ hoặc đổi
  /// ngày bắt đầu. "Ngày cụ thể" thì là ngày người dùng chọn.
  DateTime? get _ngayKetThucHienThi =>
      _theoChuKy ? _cuoiKyDau : _endDate;

  /// Ngày kết thúc thật sự **ghi xuống**.
  ///
  /// Bật lặp lại thì để trống: ngân sách tự sang kỳ mới, không có hạn dừng.
  /// Ghi cuối kỳ đầu vào đây sẽ làm công tắc lặp lại thành vô nghĩa — ngân
  /// sách nào cũng chết sau đúng một kỳ.
  DateTime? get _ngayKetThucLuu {
    if (!_theoChuKy) return _endDate;
    return _recurrence ? null : _cuoiKyDau;
  }

  /// Cập nhật [_endDateError]. Trả về true nếu hai ngày hợp lệ.
  ///
  /// Chạy ngay khi người dùng đổi ngày chứ không đợi tới lúc bấm Lưu: đổi ngày
  /// bắt đầu vượt qua ngày kết thúc là đường dễ rơi vào trạng thái sai nhất, và
  /// ô ngày bắt đầu không hề bị chặn trên.
  bool _kiemTraThuTuNgay() {
    final het = _ngayKetThucLuu;
    final hopLe = het == null || het.isAfter(_startDate);
    _endDateError = hopLe ? null : 'Ngày kết thúc phải sau ngày bắt đầu';
    return hopLe;
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
    final ngayHopLe = _kiemTraThuTuNgay();
    // setState trước khi thoát: lời nhắn phải hiện ra ngay cả khi các ô khác
    // đều hợp lệ, nếu không người dùng bấm Lưu mà chẳng thấy gì xảy ra.
    setState(() {});
    if (!ngayHopLe) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final percentText = _thresholdPercentController.text.trim();
    widget.onSubmit(BudgetDraft(
      categoryId: _categoryId!,
      amount: CurrencyFormatter.parse(_amountController.text) ?? 0,
      thresholdWarningAmount: _thresholdController.text.trim().isEmpty
          ? null
          : CurrencyFormatter.parse(_thresholdController.text),
      // Lưu nguyên đơn vị phần trăm 0–100 để khớp cột backend; việc quy về tỉ
      // lệ nằm ở `BudgetEntity.warningRatio`.
      thresholdWarningPercent: percentText.isEmpty
          ? null
          : double.tryParse(percentText.replaceAll(',', '.')),
      overSpending: _overSpending,
      startDate: _startDate,
      endDate: _ngayKetThucLuu,
      recurrence: _theoChuKy && _recurrence,
      timeRecurrence: _timeRecurrence,
      note: _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.editing == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
            child: const Text('Lưu',
                style: TextStyle(
                    color: AppColors.income, fontWeight: FontWeight.bold)),
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
                  ],
                )),
                const SizedBox(height: 32),
                _sectionTitle('Chu kỳ'),
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _recurrenceSwitch(),
                    const SizedBox(height: 8),
                    _label('Loại chu kỳ'),
                    const SizedBox(height: 8),
                    _recurrencePicker(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.surfaceContainerHigh),
                    ),
                    _label('Ngày bắt đầu'),
                    const SizedBox(height: 8),
                    _startDatePicker(),
                    _canhBaoGhiDeWidget('budget-start-date-warning'),
                    const SizedBox(height: 16),
                    _label('Ngày kết thúc'),
                    const SizedBox(height: 8),
                    _endDatePicker(),
                    _canhBaoGhiDeWidget('budget-end-date-warning'),
                    const SizedBox(height: 8),
                    Text(
                      _endDateError ?? _expiryHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: _endDateError == null
                            ? AppColors.textSecondary
                            : AppColors.error,
                      ),
                    ),
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
                  key: const ValueKey('budget-submit'),
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

  // ── Chu kỳ ──────────────────────────────────────────────────────────────────

  String get _expiryHint {
    if (!_theoChuKy) {
      final het = _endDate;
      return het == null
          ? 'Hãy chọn ngày kết thúc — không theo chu kỳ nào thì đó là thứ duy '
              'nhất cho biết ngân sách chạy tới bao giờ.'
          : 'Chạy một lần từ ${_formatDay(_startDate)} tới '
              '${_formatDay(het)}.';
    }
    final ky = _cuoiKyDau;
    final ten = BudgetRecurrence.label(_timeRecurrence).toLowerCase();
    return _recurrence
        ? 'Chốt sổ $ten, kỳ này tới ${_formatDay(ky)} rồi tự sang kỳ mới — '
            'không có hạn dừng.'
        : 'Chạy một kỳ $ten rồi hết hạn ngày ${_formatDay(ky)}.';
  }

  /// Lời cảnh báo khi một chu kỳ vừa ghi đè ngày kết thúc người dùng tự đặt.
  ///
  /// `null` nghĩa là không có gì để cảnh báo. Đây là **nhắc nhở, không phải
  /// lỗi**: bản ghi vẫn hợp lệ, chỉ là ngày người dùng chọn không còn được
  /// dùng nữa và họ cần biết điều đó.
  String? get _canhBaoGhiDe {
    final cu = _ngayKetThucBiGhiDe;
    if (!_theoChuKy || cu == null) return null;
    return 'Chu kỳ ${BudgetRecurrence.label(_timeRecurrence).toLowerCase()} '
        'quyết định độ dài kỳ, nên ngày kết thúc ${_formatDay(cu)} bạn tự chọn '
        'đã được thay bằng ${_formatDay(_cuoiKyDau)}. Chọn "Ngày cụ thể" để '
        'dùng lại ngày cũ.';
  }

  Widget _canhBaoGhiDeWidget(String key) {
    final loi = _canhBaoGhiDe;
    if (loi == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        loi,
        key: ValueKey(key),
        style: const TextStyle(fontSize: 13, color: AppColors.expense),
      ),
    );
  }

  /// Công tắc lặp lại — **chỉ có nghĩa khi ngân sách theo một chu kỳ**.
  ///
  /// "Ngày cụ thể" không có chu kỳ nào để lặp, nên ở chế độ đó công tắc biến
  /// mất hẳn thay vì bị làm mờ: để lại thì người dùng bật được "lặp lại" cho
  /// một ngân sách không lặp được, và bản ghi lưu xuống mâu thuẫn với chính nó.
  Widget _recurrenceSwitch() {
    if (!_theoChuKy) return const SizedBox.shrink();
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Lặp lại theo chu kỳ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Switch(
          key: const ValueKey('budget-recurrence-switch'),
          value: _recurrence,
          activeThumbColor: AppColors.income,
          onChanged: (v) => setState(() {
            _recurrence = v;
            _kiemTraThuTuNgay();
          }),
        ),
      ],
    );
  }

  Widget _recurrencePicker() {
    // `null` ở cuối dãy là "Ngày cụ thể": không theo chu kỳ nào, người dùng tự
    // chọn ngày kết thúc.
    final luaChon = <String?>[...BudgetRecurrence.all, null];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: luaChon.map((value) {
        final selected = _timeRecurrence == value;
        return GestureDetector(
          onTap: () => setState(() {
            final truocDoLaNgayCuThe = !_theoChuKy;
            _timeRecurrence = value;
            if (value == null) {
              // Quay lại "Ngày cụ thể": ngày tự chọn được dùng lại nên không
              // còn gì bị ghi đè.
              _ngayKetThucBiGhiDe = null;
            } else if (truocDoLaNgayCuThe && _endDate != null) {
              _ngayKetThucBiGhiDe = _endDate;
            }
            _kiemTraThuTuNgay();
          }),
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

  // ── Các ô nhập ──────────────────────────────────────────────────────────────

  Widget _categoryPicker() {
    final categories = widget.categories;
    // Danh mục của ngân sách đang sửa có thể đã bị xoá — khi đó nó không nằm
    // trong danh sách và `DropdownButtonFormField` sẽ ném lỗi vì `value` không
    // khớp item nào. Rơi về "chưa chọn" thay vì làm trắng trang.
    final valid =
        _categoryId != null && categories.any((c) => c.id == _categoryId);

    return DropdownButtonFormField<String>(
      key: const ValueKey('budget-category'),
      initialValue: valid ? _categoryId : null,
      isExpanded: true,
      decoration: _inputDecoration('Chọn danh mục'),
      items: categories
          .map((c) => DropdownMenuItem<String>(
                value: c.id,
                child: Row(
                  children: [
                    Icon(budgetIconFor(c.icon),
                        size: 20, color: budgetColorFrom(c.colour)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ))
          .toList(),
      // Một ngân sách thuộc về đúng MỘT danh mục — "Ngân sách tổng" đã bỏ ngày
      // 2026-09-04. Repository cũng chặn, nhưng để nó chặn thì người dùng chỉ
      // nhận một snackbar đỏ chứ không thấy ô nào còn thiếu.
      validator: (v) => v == null ? 'Hãy chọn danh mục cho ngân sách này' : null,
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  Widget _amountField() {
    return TextFormField(
      key: const ValueKey('budget-amount'),
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
        if (picked != null) {
          setState(() {
            _startDate = picked;
            _kiemTraThuTuNgay();
          });
        }
      },
      child: InputDecorator(
        decoration: _inputDecoration(null),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              _formatDay(_startDate),
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  /// Ô ngày kết thúc.
  ///
  /// Theo chu kỳ thì đây là **ô chỉ đọc**: ngày bám theo chu kỳ và ngày bắt
  /// đầu, đổi một trong hai là nó nhảy theo. Muốn một ngày tuỳ ý thì bấm "Ngày
  /// cụ thể" — để vừa chọn chu kỳ vừa sửa tay được thì hai thứ mâu thuẫn nhau
  /// và không có gì trên màn hình nói cái nào thắng.
  Widget _endDatePicker() {
    final value = _ngayKetThucHienThi;
    final chiDoc = _theoChuKy;

    return Opacity(
      opacity: chiDoc ? 0.6 : 1,
      child: InkWell(
        key: const ValueKey('budget-end-date'),
        onTap: chiDoc
            ? null
            : () async {
                // Sớm nhất là NGÀY HÔM SAU ngày bắt đầu: ràng buộc
                // `chk_budget_end_after_start` đòi `End > Start`, nên chọn
                // trùng ngày cũng bị PostgreSQL từ chối.
                final somNhat = _startDate.add(const Duration(days: 1));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: (value != null && value.isAfter(_startDate))
                      ? value
                      : somNhat,
                  firstDate: somNhat,
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _endDate = picked;
                    _kiemTraThuTuNgay();
                  });
                }
              },
        child: InputDecorator(
          decoration: _inputDecoration(null),
          child: Row(
            children: [
              Icon(chiDoc ? Icons.lock_outline : Icons.event_busy,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null ? 'Chưa chọn' : _formatDay(value),
                  style: TextStyle(
                    fontSize: 16,
                    color: value == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mảnh dùng lại ───────────────────────────────────────────────────────────

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

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
