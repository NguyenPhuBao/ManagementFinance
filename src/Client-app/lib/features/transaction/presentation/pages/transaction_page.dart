import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/category/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../analytics/domain/pham_vi_ky.dart';
import '../../../analytics/presentation/widgets/chon_pham_vi_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/transaction_entity.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_lookup.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transaction_filter_bar.dart';
import '../widgets/transaction_list_row.dart';
import 'add_transaction_page.dart';

class TransactionPage extends StatefulWidget {
  /// Mã tài khoản **tiêm vào** — chỉ widget test dùng. Đường chạy thật để
  /// `null`: route dựng `const TransactionPage()` và trang tự suy từ phiên.
  final int? idaccount;

  /// Lọc sẵn theo một ví khi mở trang — đường tắt từ màn Quản lý ví.
  ///
  /// Bộ lọc theo ví vốn đã có ở `TransactionFilterBar`; đây chỉ là giá trị
  /// khởi tạo. Chíp "Ví" của thanh lọc đổi nhãn thành tên ví khi nó khác
  /// `null`, nên bộ lọc đang áp luôn **nhìn thấy được** — một bộ lọc âm thầm
  /// là người dùng tưởng ví trống.
  final String? initialWalletId;

  const TransactionPage({
    super.key,
    this.idaccount,
    this.initialWalletId,
  });

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  /// Kỳ đang xem. Thay `_selectedMonthDate` ngày 2026-09-21: trang này không
  /// còn khoá theo tháng, nó xem được tuần / tháng / quý / năm / khoảng tuỳ
  /// chọn bằng chính `Ky` mà trang Phân tích và Xuất báo cáo dùng.
  late Ky _ky;

  /// Điều kiện lọc hiện tại; giữ nguyên khi đổi tháng — người dùng đang xem
  /// "chi ở ví Tiết kiệm" thì lật sang tháng trước vẫn muốn xem đúng thứ đó.
  ///
  /// Khởi tạo từ [TransactionPage.initialWalletId] khi trang được mở bằng
  /// đường tắt từ màn Quản lý ví. Đặt ở `initState` chứ không ở `build`: gán
  /// trong `build` là mỗi lần dựng lại sẽ giật bộ lọc về ví ban đầu, nên người
  /// dùng không bỏ lọc ra được.
  late TransactionFilter _filter =
      TransactionFilter(walletId: widget.initialWalletId);

  // Hai stream tra tên ví/danh mục cho từng dòng. Tạo MỘT lần cho mỗi tài
  // khoản và giữ lại: tạo trong build là mỗi lần đổi tháng lại đăng ký lại,
  // danh sách chớp trắng một nhịp.
  int? _lookupAccount;
  Stream<List<Wallet>>? _wallets;
  Stream<List<Category>>? _categories;

  @override
  void initState() {
    super.initState();
    // Mở trang ở tháng hiện tại — giữ đúng nếp cũ, và khớp với kỳ mà bloc tự
    // đăng ký ở `LoadTransactionsEvent`.
    final now = DateTime.now();
    _ky = Ky.thang(now.year, now.month);
  }

  /// Đường tắt "Xem giao dịch" của màn Quản lý ví phải lọc sẵn ví **kể cả khi
  /// trang đã sống từ trước** — G48.
  ///
  /// `/transactions` nằm trong một `StatefulShellBranch`, và Navigator của
  /// nhánh **giữ State sống**. Lần `go('/transactions?wallet=…')` thứ hai dựng
  /// một `TransactionPage` mới cùng kiểu ở cùng vị trí, nên Flutter **cập nhật**
  /// State cũ thay vì tạo State mới: `initState` không chạy lại và
  /// [TransactionPage.initialWalletId] mới bị bỏ qua **im lặng**. Người dùng
  /// thấy sổ đầy đủ và tưởng chừng ấy khoản đều thuộc ví họ vừa bấm.
  ///
  /// Hai chốt, phá cái nào cũng hỏng im lặng:
  ///
  /// - Chỉ đổi khi ví **thật sự khác lần trước**. Áp lại ở mọi lần dựng lại là
  ///   quay về đúng cái bẫy mà chú thích của [_filter] cảnh báo: người dùng bỏ
  ///   lọc ra rồi nó tự giành lại.
  /// - `null` **không** có nghĩa "hãy xem mọi ví". Trang được dựng lại mà không
  ///   nêu ví nào thì giữ nguyên thứ đang xem; coi `null` là lệnh bỏ lọc thì bộ
  ///   lọc tự bay mất mỗi lần cây widget dựng lại.
  ///
  /// Phép này **không** trả lời câu hỏi rộng hơn — bộ lọc có nên sống sót qua
  /// một lần ghé tab hay không; nó chỉ chốt một điều hẹp và rõ: **một lệnh điều
  /// hướng có nêu đích danh ví thì thắng bộ lọc đang có**.
  @override
  void didUpdateWidget(TransactionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final viMoi = widget.initialWalletId;
    if (viMoi != null && viMoi != oldWidget.initialWalletId) {
      setState(() => _filter = _filter.copyWith(walletId: viMoi));
    }
  }

  void _ensureLookupStreams(int idaccount) {
    if (_lookupAccount == idaccount) return;
    _lookupAccount = idaccount;
    final db = sl<AppDatabase>();
    _wallets = db.walletDao.watchAll(idaccount);
    _categories = db.categoryDao.watchAll(idaccount);
  }

  /// Đổi kỳ đang xem. [soKy] **dương là lùi**, âm là tiến — cùng chiều với
  /// `lui()`, để không đẻ ra quy ước dấu thứ hai.
  ///
  /// `lui` lùi theo **đơn vị lịch** chứ không trừ số ngày, và với kỳ tuỳ chọn
  /// thì lùi đúng bằng độ dài khoảng.
  void _doiKy(int soKy, BuildContext blocContext) {
    setState(() => _ky = lui(_ky, soKy));
    blocContext.read<TransactionBloc>().add(ChonKyEvent(_ky));
  }

  /// Mở bộ chọn phạm vi — **cùng** sheet hai tầng mà trang Phân tích và trang
  /// Xuất báo cáo dùng.
  ///
  /// Không dựng bộ chọn riêng ở đây: `moChonPhamVi` đã mang sẵn năm đơn vị và
  /// luật "12 kỳ / 8 quý / 5 năm", và một bản thứ hai là hai luật phải giữ đồng
  /// bộ bằng tay.
  Future<void> _chonKy(BuildContext blocContext) async {
    final chon = await moChonPhamVi(
      context,
      kyHienTai: _ky,
      moc: DateTime.now(),
    );
    // ⚠️ Sau `await`, widget có thể đã rời cây — dùng context khi ấy là lỗi.
    if (chon == null || !mounted) return;
    setState(() => _ky = chon);
    if (blocContext.mounted) {
      blocContext.read<TransactionBloc>().add(ChonKyEvent(chon));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    // ⚠️ Trước 2026-09-14 khối này rơi về `widget.idaccount`, vốn mặc định `1`
    // — **tài khoản admin thật**. Route dựng `const TransactionPage()` nên giá
    // trị thật sự dùng khi phiên chưa sẵn sàng chính là 1, và trang mở stream
    // đọc ví + danh mục của admin. Đúng lỗ hổng G4/G35, lọt lưới quét `?? 1`
    // vì biểu thức viết là `?? widget.idaccount`.
    int? currentUserId = widget.idaccount;
    if (authState is AuthSuccess && authState.user != null) {
      final parsed = int.tryParse(authState.user!.id);
      if (parsed != null && parsed > 0) currentUserId = parsed;
    }

    if (currentUserId == null) {
      // Chưa có phiên dùng được: không mở stream, không nạp gì. Trang này chỉ
      // tới được từ trong shell đã đăng nhập, nên đây là trạng thái thoáng qua
      // — nó tự đầy ngay khi `AuthBloc` phát `AuthSuccess`.
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Chưa xác định được tài khoản đăng nhập'),
        ),
      );
    }
    // Biến `final` riêng: phép thu hẹp `int?` → `int` ở nhánh trên KHÔNG theo
    // được vào closure `create:` bên dưới.
    final int accountId = currentUserId;
    _ensureLookupStreams(accountId);

    return BlocProvider<TransactionBloc>(
      create: (context) => sl<TransactionBloc>()
        ..add(LoadTransactionsEvent(idaccount: accountId)),
      child: Builder(
        builder: (blocContext) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Sổ giao dịch',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
            // ⚠️ KHÔNG có FAB ở đây. Từ 2026-09-19 (nhóm D) trang này là một
            // **tab**, nên FAB tròn ở giữa thanh dưới luôn hiện trên nó — vẽ
            // thêm một cái nữa là hai nút cách nhau chừng 40px làm đúng một
            // việc (`push('/add')`). Máy ảo bắt được trong khi 2945 ca test
            // đều xanh.
            //
            // Gỡ an toàn vì danh sách là **stream** (`watchKhoang`):
            // `ChonKyEvent` mà FAB cũ phát sau khi quay lại chỉ đặt lại
            // đúng tháng đang xem, tức thừa.
            body: SafeArea(
              child: Column(
                children: [
                  _buildKySelector(blocContext),
                  Expanded(
                    child: BlocBuilder<TransactionBloc, TransactionState>(
                      builder: (context, state) {
                        if (state is TransactionLoadingState) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (state is TransactionLoadedState) {
                          // Bộ lọc chạy trên danh sách tháng đã có trong bloc;
                          // thẻ tổng và danh sách cùng tính trên tập đã lọc để
                          // hai thứ luôn nói cùng một chuyện.
                          final txs =
                              applyTransactionFilter(state.giaoDich, _filter);
                          final summary = summarizeTransactions(txs);

                          return StreamBuilder<List<Wallet>>(
                            stream: _wallets,
                            builder: (_, wallets) =>
                                StreamBuilder<List<Category>>(
                              stream: _categories,
                              builder: (_, categories) {
                                final walletList =
                                    wallets.data ?? const <Wallet>[];
                                final lookup = TransactionLookup(
                                  wallets: walletList,
                                  categories: categories.data ?? const [],
                                );
                                return Column(
                                  children: [
                                    TransactionFilterBar(
                                      filter: _filter,
                                      lookup: lookup,
                                      wallets: walletList,
                                      onChanged: (f) =>
                                          setState(() => _filter = f),
                                      pickCategory: () => context.push<Category>(
                                        '/add/category',
                                        extra: kCategoryClassifies.first,
                                      ),
                                    ),
                                    _buildMonthlySummaryCard(
                                      totalIncome: summary.income,
                                      totalExpense: summary.expense,
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: txs.isEmpty
                                          ? _buildEmptyState(
                                              filtered: _filter.isActive)
                                          : _buildGroupedTransactionList(
                                              txs, blocContext, lookup),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        }

                        if (state is TransactionErrorState) {
                          return Center(
                            child: Text(
                              'Lỗi: ${state.message}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bảng chi tiết của một dòng: Sửa → mở `/add` ở chế độ sửa rồi tải lại
  /// tháng; Xoá → hỏi xác nhận rồi đi cùng đường với vuốt xoá.
  Future<void> _showDetail(
    BuildContext blocContext,
    TransactionEntity tx,
    TransactionLookup lookup,
  ) async {
    await showModalBottomSheet<void>(
      context: blocContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => TransactionDetailSheet(
        transaction: tx,
        lookup: lookup,
        onEdit: () async {
          Navigator.of(sheetContext).pop();
          final result = await context.push(
            '/add',
            extra: EditTransactionArgs(
              transaction: tx,
              category: lookup.category(tx.categoryId),
            ),
          );
          if (result == true && blocContext.mounted) {
            blocContext.read<TransactionBloc>().add(ChonKyEvent(_ky));
          }
        },
        onDelete: () async {
          final ok = await ConfirmDialog.show(
            sheetContext,
            title: 'Xoá giao dịch?',
            message: 'Số dư ví sẽ được hoàn lại. Không hoàn tác được.',
          );
          if (!ok || !sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          blocContext.read<TransactionBloc>().add(DeleteTransactionEvent(tx));
          ScaffoldMessenger.of(blocContext).showSnackBar(
            const SnackBar(content: Text('Đã xóa giao dịch')),
          );
        },
      ),
    );
  }

  Widget _buildKySelector(BuildContext blocContext) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kỳ trước',
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => _doiKy(1, blocContext),
          ),
          // ⚠️ `Expanded` chứ không để `Row` tự co: nhãn kỳ tuỳ chọn
          // ("26/08 – 11/09") dài hơn hẳn nhãn tháng, và ở 411dp hai mũi tên đã
          // ăn mất chỗ hai bên. Cho nó chiếm trọn khoảng giữa thì phép căn giữa
          // mới có mốc, và chuỗi dài cắt bằng dấu ba chấm thay vì đẩy mũi tên
          // ra khỏi màn hình.
          Expanded(
            child: InkWell(
              key: const Key('so-giao-dich-chon-ky'),
              onTap: () => _chonKy(blocContext),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        nhanRong(_ky, DateTime.now()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kỳ sau',
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () => _doiKy(-1, blocContext),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard({
    required double totalIncome,
    required double totalExpense,
  }) {
    final net = totalIncome - totalExpense;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // `formatCoDau` chứ không `formatIncome`/`formatExpense`: kỳ rỗng là
          // ca THƯỜNG từ khi trang xem được năm đơn vị, và số 0 không mang dấu
          // (cột "Thu net" ngay bên cạnh vốn đã theo luật ấy).
          _buildSummaryColumn('Thu nhập', CurrencyFormatter.formatCoDau(totalIncome, thu: true), AppColors.income),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _buildSummaryColumn('Chi tiêu', CurrencyFormatter.formatCoDau(totalExpense, thu: false), AppColors.error),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _buildSummaryColumn(
            'Thu net',
            CurrencyFormatter.formatCoDau(net, thu: net >= 0),
            net >= 0 ? AppColors.income : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({bool filtered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtered ? Icons.filter_alt_off_outlined : Icons.receipt_long,
              size: 40,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'Không có giao dịch nào khớp bộ lọc'
                // "kỳ này" chứ không "tháng này": trang thôi khoá theo tháng từ
                // 2026-09-21, và header ngay trên đã nói kỳ nào.
                : 'Chưa có giao dịch nào trong kỳ này',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Đổi điều kiện hoặc bấm "Xoá lọc"'
                : 'Nhấn nút (+) để thêm giao dịch mới',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactionList(
    List<TransactionEntity> transactions,
    BuildContext blocContext,
    TransactionLookup lookup,
  ) {
    // Group transactions by Date (YYYY-MM-DD)
    final Map<String, List<TransactionEntity>> grouped = {};
    for (final tx in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateStr = sortedDates[dateIndex];
        final dayTxs = grouped[dateStr]!;
        final dateObj = DateTime.parse(dateStr);
        final formattedDateHeader = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(dateObj);

        // Day net balance calculation
        double dayNet = 0;
        for (final t in dayTxs) {
          if (t.type == 'thu') dayNet += t.amount;
          if (t.type == 'chi') dayNet -= t.amount;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Day Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDateHeader,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCoDau(dayNet, thu: dayNet >= 0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: dayNet >= 0 ? AppColors.income : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              // Day Items — vuốt xoá; khoản của mục tiêu/hoá đơn bị chặn
              // ngay trong widget (xem `TransactionListRow`).
              ...dayTxs.map((tx) => TransactionListRow(
                    transaction: tx,
                    lookup: lookup,
                    onTap: () => _showDetail(blocContext, tx, lookup),
                    onDelete: () => blocContext.read<TransactionBloc>().add(
                          DeleteTransactionEvent(tx),
                        ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
