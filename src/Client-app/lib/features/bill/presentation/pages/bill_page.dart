import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../widgets/bill_status_header.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import '../../domain/bill_status.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/presentation/pages/add_transaction_page.dart'
    show EditTransactionArgs;
import '../../../transaction/presentation/widgets/transaction_detail_sheet.dart';
import '../../../../core/category/category_visuals.dart';
import '../widgets/bill_actions.dart';
import '../widgets/bill_status_visuals.dart';

class BillPage extends StatefulWidget {
  /// Thời điểm dùng để xếp trạng thái từng hoá đơn. Tiêm được để test không
  /// phụ thuộc ngày chạy — cùng lối với `BudgetTabsView`.
  final DateTime? now;

  const BillPage({super.key, this.now});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  /// Tra tên ví và danh mục cho từng dòng — dùng lại đúng lớp của sổ giao
  /// dịch. Hoá đơn chỉ lưu id; trước 2026-09-06 danh sách không hiện cái nào
  /// trong hai thứ đó.
  TransactionLookup _lookup = TransactionLookup.empty;

  /// Tài khoản đã nạp xong, để không nạp lại ở mỗi lần dựng.
  int? _daNapCho;

  /// Nạp đúng MỘT lần cho mỗi mã tài khoản.
  ///
  /// Trước đây việc này nằm trong `addPostFrameCallback` của `initState` kèm
  /// `if (accountId == null) return;`. `initState` chỉ chạy một lần, nên khi
  /// trang được dựng trước lúc `AuthBloc` khôi phục xong phiên thì nó bỏ qua
  /// và **không bao giờ thử lại** — trang hoá đơn trống cho tới khi người dùng
  /// thoát ra vào lại. Cùng họ với G17 ở trang Mục tiêu và Ngân sách, chỉ khác
  /// hình dạng: ở đây không có `BlocProvider` để gắn khoá, vì `BillBloc` do
  /// router cung cấp.
  ///
  /// Gọi từ `build` (nơi đã `watch` AuthBloc) nên nó chạy lại khi phiên tới.
  /// Việc gửi sự kiện hoãn sang `addPostFrameCallback`: phát một sự kiện bloc
  /// **trong lúc dựng** là lỗi khung.
  void _thuNap() {
    final accountId = currentAccountIdOrNull(context);
    if (accountId == null || _daNapCho == accountId) return;
    _daNapCho = accountId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BillBloc>().add(LoadBillsEvent(idaccount: accountId));
      _napTenGoi(accountId);
    });
  }

  /// Nạp tên ví và danh mục **một lần** khi mở trang.
  ///
  /// Cố ý không giữ hai `Stream` như `TransactionPage._ensureLookupStreams`:
  /// ở đó danh sách giao dịch đổi liên tục nên bảng tra phải sống theo, còn ở
  /// đây chỉ có tên ví và tên danh mục — hai thứ người dùng đổi ở màn khác,
  /// và quay lại trang này là nạp lại. Đổi lấy: không đăng ký nào phải huỷ,
  /// nên không có `dispose` nào để quên.
  Future<void> _napTenGoi(int accountId) async {
    final db = sl<AppDatabase>();
    final vi = await db.walletDao.getAll(accountId);
    final dm = await db.categoryDao.getAll(accountId);
    if (!mounted) return;
    setState(() => _lookup = TransactionLookup(wallets: vi, categories: dm));
  }

  @override
  Widget build(BuildContext context) {
    // ĐĂNG KÝ với AuthBloc: `currentAccountIdOrNull` dùng `context.read` bên
    // trong, mà `read` không đăng ký gì — thiếu dòng này thì `_thuNap()` bên
    // dưới không bao giờ được gọi lại khi phiên tới.
    context.watch<AuthBloc>();
    _thuNap();

    final dateFormatter = DateFormat('dd/MM/yyyy');
    final now = widget.now ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hóa đơn & Dịch vụ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.outlineVariant,
            height: 1.0,
          ),
        ),
      ),
      body: BlocConsumer<BillBloc, BillState>(
        // `BillOperationSuccess` và `BillError` là trạng thái THOÁNG QUA: chúng
        // chỉ để bắn snackbar. Dựng lại theo chúng thì builder rơi xuống
        // `SizedBox.shrink()` ở cuối và **xoá trắng cả trang** — rồi không có
        // gì dựng lại cho tới khi stream phát trạng thái mới, thứ không xảy ra
        // khi thao tác thất bại. Thấy trên máy ảo 2026-09-06 khi hoàn tác một
        // khoản trả cũ bị từ chối.
        buildWhen: (_, state) =>
            state is! BillOperationSuccess && state is! BillError,
        listener: (context, state) {
          if (state is BillOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is BillError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is BillLoading || state is BillInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BillLoaded) {
            // Hai nhóm thay cho một danh sách phẳng: mỗi kỳ của hoá đơn lặp là
            // một hàng mới, nên lịch sử đã trả trôi lẫn vào giữa những hoá đơn
            // đang chờ — hoá đơn tuần sinh 52 hàng mỗi năm.
            final sections = splitBills(state.bills);

            return DefaultTabController(
              length: 2,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: _buildSummaryCard(
                          totalAmountStr: CurrencyFormatter.format(
                              state.summary.unpaidAmount),
                          unpaidCount: state.summary.unpaidCount,
                          progress: state.summary.progress,
                        ),
                      ),
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(
                              text:
                                  'Cần thanh toán (${sections.chuaDong.length})'),
                          Tab(text: 'Đã thanh toán (${sections.daDong.length})'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _danhSach(
                              context,
                              sections.chuaDong,
                              now: now,
                                                            dateFormatter: dateFormatter,
                              khiTrong: 'Không còn hoá đơn nào phải trả.',
                              payments: state.payments,
                            ),
                            _danhSach(
                              context,
                              sections.daDong,
                              now: now,
                                                            dateFormatter: dateFormatter,
                              khiTrong: 'Chưa có hoá đơn nào được thanh toán.',
                              payments: state.payments,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildAddButton(context),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Một tab của danh sách.
  Widget _danhSach(
    BuildContext context,
    List<Bill> bills, {
    required DateTime now,
    required DateFormat dateFormatter,
    required String khiTrong,
    required Map<String, Transaction> payments,
  }) {
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Text(
              khiTrong,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildDecorativeIllustration(),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: bills.length,
      itemBuilder: (_, i) {
        final bill = bills[i];
        // Bốn trạng thái, một định nghĩa duy nhất ở `domain/bill_status.dart`.
        // Trước đây trang này tự suy ra hai trạng thái ngay trong `build` và
        // gán nhãn "SẮP ĐẾN HẠN" cho đúng nhánh ĐÃ QUÁ HẠN.
        final status = billDisplayStatusOf(bill, now);
        final danhMuc = _lookup.category(bill.categoryId);
        // Khoản chi của lần trả — chỉ có với khoản ghi từ v16 trên máy này.
        // Không có thì KHÔNG đoán ngày trả; chỉ ghi hạn như cũ.
        final khoanChi = payments[bill.id];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildBillItem(
            context: context,
            bill: bill,
            title: bill.name,
            // Hai dòng chứ không nối bằng " • ": cạnh nhãn "ĐÃ THANH TOÁN" ở
            // 411dp chỉ còn chỗ cho ~18 ký tự, một dòng bị cắt thành "Hạn
            // 06/09/2026 • T…" (thấy trên máy ảo 06/09).
            subtitle: khoanChi == null
                ? 'Hạn ${dateFormatter.format(bill.dueDate)}'
                : 'Hạn ${dateFormatter.format(bill.dueDate)}\n'
                    'Trả ${dateFormatter.format(khoanChi.date)}',
            // Dòng đã trả mở khoản chi; dòng chưa trả mở trang chi tiết (mang
            // theo hàng đang giữ để trang vẽ ngay, rồi tự đọc lại CSDL).
            onTap: khoanChi != null
                ? () => _moKhoanChi(context, khoanChi)
                : () => context.push('/bills/${bill.id}', extra: bill),
            // Ba trạng thái khác nhau, đừng gộp: chưa gán danh mục bao giờ /
            // đã gán nhưng hàng ấy bị xoá mềm (đợt gộp danh mục 05/09 để lại
            // đúng tình trạng này) / có danh mục thật.
            meta: [
              bill.categoryId == null
                  ? 'Chưa có danh mục'
                  : (danhMuc?.name ?? 'Danh mục đã xoá'),
              _lookup.walletName(bill.walletId),
              // Dấu hiệu duy nhất trên danh sách cho biết hoá đơn nào app sẽ
              // tự trừ tiền — không có nó thì phải mở từng hoá đơn.
              if (bill.autoPayEnabled) 'Tự trả',
            ].join(' • '),
            icon: categoryIconFor(danhMuc?.icon),
            iconColor:
                categoryColorFrom(danhMuc?.colour, fallback: AppColors.primary),
            amount: CurrencyFormatter.format(bill.amount),
            status: nhanTrangThaiHoaDon(status),
            statusColor: mauChuTrangThaiHoaDon(status),
            statusBg: mauNenTrangThaiHoaDon(status),
            accentColor: mauVachTrangThaiHoaDon(status),
            isPaid: status == BillDisplayStatus.paid,
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String totalAmountStr,
    required int unpaidCount,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DB)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.account_balance_wallet,
                  size: 64, color: AppColors.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng tiền cần thanh toán',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalAmountStr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  key: const ValueKey('bill-progress'),
                  alignment: Alignment.centerLeft,
                  // Trước đây là hằng số `0.66`, tức chỉ có hai trạng thái
                  // 66% hoặc 0%. Nay là tỉ lệ tiền đã trả trong kỳ.
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$unpaidCount hóa đơn chưa thanh toán',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillItem({
    required BuildContext context,
    required Bill bill,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required Color accentColor,
    bool isPaid = false,
    String? meta,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: ValueKey('bill-row-${bill.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isPaid
              ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPaid
              ? Border.all(
                  color: AppColors.outlineVariant, style: BorderStyle.solid)
              : Border.all(color: const Color(0xFFE0E0DB)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: ValueKey('bill-accent-${bill.id}'),
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      BillStatusHeader(
                        title: title,
                        subtitle: subtitle,
                        meta: meta,
                        icon: icon,
                        iconColor: iconColor,
                        status: status,
                        statusColor: statusColor,
                        statusBg: statusBg,
                        titleColor: isPaid
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        isPaid: isPaid,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // `Flexible` + ellipsis: số tiền lớn (hoặc cỡ chữ hệ
                          // thống to) đẩy nút "Thanh toán" ra ngoài mép thẻ.
                          // `BillStatusHeader` đã được vá cùng lỗi này từ trước,
                          // hàng dưới thì chưa ai để ý.
                          Flexible(
                            child: Text(
                              amount,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isPaid
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => context.push('/bills/${bill.id}/edit',
                                extra: bill),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: isPaid
                                  ? AppColors.textSecondary
                                      .withValues(alpha: 0.5)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => hoiXoaHoaDon(context, bill.id),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: isPaid
                                  ? const Color(0xFFF1453B)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFF1453B),
                            ),
                          ),
                          const Spacer(),
                          if (isPaid)
                            TextButton.icon(
                              key: ValueKey('bill-undo-${bill.id}'),
                              onPressed: () => hoiHoanTacHoaDon(context, bill),
                              icon: const Icon(Icons.undo, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Hoàn tác'),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                          if (!isPaid)
                            ElevatedButton(
                              onPressed: () =>
                                  moBangThanhToanHoaDon(context, bill),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Thanh toán',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mở khoản chi mà lần trả đã sinh ra, ngay tại trang hoá đơn.
  ///
  /// Trước đây phải sang sổ giao dịch tự tìm, dù hoá đơn đã cầm sẵn id của
  /// khoản chi. Dùng đúng bảng chi tiết của sổ để hai nơi không kể hai
  /// chuyện khác nhau về cùng một giao dịch. Xoá ở đây bị từ chối như ở sổ
  /// (khoản của hoá đơn) — đường đúng là nút Hoàn tác trên dòng.
  void _moKhoanChi(BuildContext context, Transaction tx) {
    final entity = TransactionEntity.fromDrift(tx);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => TransactionDetailSheet(
        transaction: entity,
        lookup: _lookup,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          context.push(
            '/add',
            extra: EditTransactionArgs(
              transaction: entity,
              category: _lookup.category(entity.categoryId),
            ),
          );
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Khoản chi của hoá đơn không xoá tay được. Dùng nút Hoàn tác '
                  'trên hoá đơn.'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDecorativeIllustration() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: const Center(
            child: Icon(Icons.receipt_long, size: 64, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Mọi thứ đều trong tầm kiểm soát.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.push('/bills/add'),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Tạo hóa đơn lặp lại mới',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A19),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
}
