import '../../../category/data/repositories/category_management_repository.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/bill_recurrence.dart';
import '../../../category/domain/danh_muc_dang_gan.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../data/models/bill_entity.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/segmented_choice.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/nen/co_chay_nen.dart';
import '../../domain/bill_auto_pay.dart' show goiYTuTra;
import '../../domain/bill_draft.dart';
import '../../domain/bill_nhac_truoc.dart';
import '../../domain/bill_schedule.dart';
import '../bloc/bill_bloc.dart';
import '../widgets/bill_actions.dart';
import '../widgets/bill_grace_selector.dart';
import '../bloc/bill_event.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../../premium/presentation/widgets/the_khoa_quyen.dart';

class BillEditPage extends StatefulWidget {
  final String id;
  final BillEntity? bill;

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

  /// Số ngày nhắc trước hạn. `null` = tắt nhắc.
  String? _nhacTruoc;

  /// Form Sửa là đường DUY NHẤT để tắt tự động thanh toán.
  bool _tuTra = false;

  List<WalletEntity> _wallets = [];
  WalletEntity? _selectedWallet;
  List<CategoryEntity> _categories = [];
  CategoryEntity? _selectedCategory;

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
    _nhacTruoc = bill?.timeNotification;
    _tuTra = bill?.autoPayEnabled ?? false;
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
    final wallets = await sl<WalletRepository>().getActive(accountId);
    // Chỉ danh mục LÁ (người dùng chốt 2026-10-10). Hoá đơn cũ đang gắn vào nhóm
    // thì ô danh mục để trống và nút Lưu đòi chọn lại — không lưu lặng lẽ.
    final repoDanhMuc = sl<CategoryManagementRepository>();
    final chonDuoc = await repoDanhMuc.selectableChildren(accountId: accountId, classify: 'chi');
    // Danh mục đang gắn bị ẩn theo khuôn (admin ngừng danh mục hệ thống — spec 2026-10-27 mục 4) vẫn là giá trị hiện tại.
    final idDangGan = widget.bill?.categoryId;
    final categories = kemDanhMucDangGan(
      chonDuoc,
      idDangGan == null || chonDuoc.any((c) => c.id == idDangGan) ? null : await repoDanhMuc.getById(idDangGan),
      classify: 'chi',
    );
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
      baoNhanh('Vui lòng nhập tên dịch vụ/hóa đơn', loai: LoaiThongBao.loi);
      return;
    }

    if (amount == null || amount <= 0) {
      baoNhanh('Vui lòng nhập số tiền hợp lệ (> 0)', loai: LoaiThongBao.loi);
      return;
    }

    // Sửa hoá đơn cũng ghi lại idaccount. Trước đây chỗ này rơi về 1 khi trạng
    // thái đăng nhập chưa sẵn sàng, tức chuyển hoá đơn sang tài khoản admin.
    final accountId = currentAccountIdOrNull(context);
    if (accountId == null) {
      baoNhanh('Chưa xác định được tài khoản đăng nhập. '
              'Vui lòng đăng nhập lại trước khi sửa hoá đơn.', loai: LoaiThongBao.loi);
      return;
    }

    // Ví và danh mục NOT NULL phía backend — không cho lưu về trạng thái
    // thiếu, vì đó chính là thứ khiến hoá đơn kẹt vĩnh viễn trong hàng đợi đẩy.
    final wallet = _selectedWallet;
    if (wallet == null) {
      baoNhanh('Vui lòng chọn ví thanh toán.', loai: LoaiThongBao.loi);
      return;
    }
    final category = _selectedCategory;
    if (category == null) {
      baoNhanh('Vui lòng chọn danh mục cho hoá đơn.', loai: LoaiThongBao.loi);
      return;
    }

    final loiNgay = _lich.dateError;
    if (loiNgay != null) {
      baoNhanh(loiNgay, loai: LoaiThongBao.loi);
      return;
    }

    final draft = BillDraft(
      name: name,
      amount: amount,
      startDate: _lich.startDate,
      periodEnd: _lich.ketThucKy,
      dueDate: _lich.dueDate,
      walletId: wallet.id,
      categoryId: category.id,
      isRecurring: _lich.isRecurring,
      timeRecurrence: _lich.storedTimeRecurrence,
      // Ngày gốc đi cùng ngày bắt đầu — xem `Bills.anchorDay`.
      anchorDay: _lich.anchorDayHieuLuc,
      timeNotification: _nhacTruoc,
      note: _noteController.text.trim(),
      autoPayEnabled: _tuTra,
    );

    context.read<BillBloc>().add(
          EditBillEvent(draft: draft, id: widget.id, idaccount: accountId, now: DateTime.now()),
        );
    context.pop();
  }

  Future<void> _delete() async {
    final daGui = await xacNhanXoaHoaDon(context, widget.id, bill: widget.bill);
    if (daGui && mounted) context.pop();
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
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
              // Flutter 3.47 thêm assertion: ListTile nằm trong Container có màu mà không có
              // Material riêng thì ink splash bị che — báo qua FlutterError, widget test bắt
              // được (P0 nâng Flutter, 2026-09-19). Material trong suốt là lớp vẽ cho ListTile;
              // không đổi gì nhìn thấy được.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      inputFormatters: const [
                        GioiHanDoRong(DoRongCot.tenHoaDon),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tên dịch vụ / Hóa đơn',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      // `bill."Amount"` là `numeric(15,2)` — chữ số thứ 14 làm
                      // hoá đơn kẹt hàng đợi đẩy vĩnh viễn, im lặng. Xem
                      // `kSoChuSoToiDaSoTien`.
                      inputFormatters: const [
                        GioiHanSoChuSo(kSoChuSoToiDaSoTien),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Số tiền (VNĐ)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ngày bắt đầu hóa đơn'),
                      subtitle: Text(DateFormatter.formatDate(_lich.startDate)),
                      trailing: const Icon(Icons.calendar_today,
                          color: AppColors.primary),
                      onTap: _pickStartDate,
                    ),
                    // Ba mốc của kỳ (v21) — cùng khối với form Thêm: kết thúc
                    // kỳ suy từ chu kỳ, ân hạn theo số ngày, hạn = kết thúc +
                    // ân hạn. Xem `BillSchedule` và `bill_an_han.dart`.
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: false,
                      title: const Text('Ngày kết thúc kỳ'),
                      subtitle: Text(DateFormatter.formatDate(_lich.ketThucKy)),
                      trailing: const Icon(Icons.lock_outline,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text('Hạn trả sau khi kết thúc kỳ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BoChonAnHan(
                      giaTri: _lich.anHanNgay,
                      loi: _lich.dateError,
                      onChanged: (n) =>
                          setState(() => _lich = _lich.copyWith(anHanNgay: n)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: false,
                      title: const Text('Hạn thanh toán'),
                      subtitle: Text(DateFormatter.formatDate(_lich.dueDate)),
                      trailing: const Icon(Icons.lock_outline,
                          color: AppColors.primary),
                    ),
                    _canhBaoHanCuWidget(),
                    const SizedBox(height: 8),
                    const Text('Chu kỳ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    // Cùng thanh chọn với form Thêm (06/09). Trước là
                    // `DropdownButtonFormField` — cùng một ô chu kỳ mà hai form
                    // hai kiểu.
                    SegmentedChoice<String>(
                      keyPrefix: 'bill-cycle',
                      options: [for (final c in kChuKyHoaDon) SegmentedOption(c, tenChuKyHoaDon(c))],
                      selected: _lich.timeRecurrence,
                      onChanged: (val) => setState(
                          () => _lich = _lich.copyWith(timeRecurrence: val)),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('bill-reminder-dropdown'),
                      initialValue: _nhacTruoc,
                      decoration: const InputDecoration(
                        labelText: 'Nhắc trước hạn',
                        border: OutlineInputBorder(),
                      ),
                      // Giá trị nằm trong `items` thì ô khoá vẫn vẽ mục đang chọn; `disabledHint` chỉ hiện khi giá trị ngoài danh sách
                      // (hàng kéo về mang số nhắc lạ — bản release).
                      disabledHint: Text(_nhacTruoc == null ? 'Không nhắc' : '$_nhacTruoc ngày'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Không nhắc')),
                        for (final n in kMucNhacTruoc)
                          DropdownMenuItem(value: '$n', child: Text('$n ngày')),
                      ],
                      // Quyền `bill_reminder_notifications` (B1): khoá, Lưu giữ nguyên giá trị.
                      onChanged: context.coQuyen(MaQuyen.billReminderNotifications)
                          ? (v) => setState(() => _nhacTruoc = v)
                          : null,
                    ),
                    if (!context.coQuyen(MaQuyen.billReminderNotifications))
                      DongKhoaCongTac(ma: MaQuyen.billReminderNotifications, dangBat: _nhacTruoc != null),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.smart_toy, color: AppColors.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tự động thanh toán'),
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
                        CongTacTheoQuyen(
                          khoaCongTac: const ValueKey('bill-autopay-switch'),
                          value: _tuTra,
                          // Quyền `bill_auto_pay`: không có → khoá; giá trị đang lưu GIỮ NGUYÊN khi Lưu (chốt "dừng
                          // chạy, giữ công tắc").
                          onChanged: (v) => setState(() => _tuTra = v),
                          biKhoa: !context.coQuyen(MaQuyen.billAutoPay),
                        ),
                      ],
                    ),
                    if (!context.coQuyen(MaQuyen.billAutoPay))
                      DongKhoaCongTac(ma: MaQuyen.billAutoPay, dangBat: _tuTra),
                    if (_tuTra) ...[
                      const SizedBox(height: 4),
                      Text(
                        goiYTuTra(chayNen: coChayNen),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    DropdownButtonFormField<WalletEntity>(
                      initialValue: _selectedWallet,
                      decoration: const InputDecoration(
                        labelText: 'Ví thanh toán',
                        border: OutlineInputBorder(),
                      ),
                      items: _wallets
                          .map((w) =>
                              DropdownMenuItem(value: w, child: Text(w.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWallet = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<CategoryEntity>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
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
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
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
