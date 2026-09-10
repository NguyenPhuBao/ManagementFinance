import 'dart:async';
import '../../../../core/utils/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/data/repositories/budget_repository.dart';
import '../../../budget/domain/budget_impact.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/models/category_suggestion.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/vi_chon_san.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

/// Dữ liệu mở trang ở chế độ SỬA: giao dịch gốc và danh mục của nó (đã tra
/// sẵn ở nơi gọi, vì entity chỉ giữ `categoryId`). Đi qua `extra` của route
/// `/add`.
/// Xem [AddTransactionPage.budgetLookup].
typedef BudgetLookup = Future<BudgetView?> Function(
  int idaccount,
  String categoryId,
);

class EditTransactionArgs {
  const EditTransactionArgs({required this.transaction, this.category});

  final TransactionEntity transaction;
  final Category? category;
}

class AddTransactionPage extends StatefulWidget {
  final int idaccount;
  final CategoryManagementRepository? categoryRepository;
  final List<Wallet>? wallets;
  final CategorySuggestionEngine suggestionEngine;
  final TransactionBloc? transactionBloc;

  /// Có giá trị → trang là "Sửa giao dịch": điền sẵn, lưu bằng
  /// `UpdateTransactionEvent` (cùng `id`), không tạo hàng mới.
  final EditTransactionArgs? initial;

  /// Tra ngân sách đang chạy của một danh mục, để hỏi/báo trước khi ghi khoản
  /// chi. `null` = lấy từ `sl<BudgetRepository>()`; test tiêm thẳng để không
  /// phải dựng DI.
  final BudgetLookup? budgetLookup;

  const AddTransactionPage({
    super.key,
    this.idaccount = 1,
    this.categoryRepository,
    this.wallets,
    this.suggestionEngine = const CategorySuggestionEngine(),
    this.transactionBloc,
    this.initial,
    this.budgetLookup,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  /// Hai loại giao dịch (từ 2026-09-05): 0 = Giao dịch (biến động số dư, có
  /// danh mục), 1 = Chuyển khoản (giữa hai ví, không danh mục). Chiều tiền
  /// không còn là một segment — nó suy từ danh mục, xem [_resolvedType].
  int _selectedSegment = 0;
  String _amountString = "0";

  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;
  Wallet? _destinationWallet;
  Category? _selectedCategory;
  CategorySuggestion? _suggestion;

  /// Chiều tiền người dùng chọn khi danh mục là vay/nợ: `'chi'` (tiền ra) hoặc
  /// `'thu'` (tiền vào). `null` với mọi danh mục khác. Được gợi sẵn theo tên
  /// danh mục lúc chọn ([_chonDanhMuc]) và đổi bằng công tắc trên form.
  String? _debtDirection;

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoadingWallets = true;

  /// Tác động lên ngân sách của khoản vừa gửi đi, để listener chọn lời nhắn
  /// sau khi lưu xong. Đặt ngay trước khi gửi event, xoá ngay khi đã dùng.
  BudgetImpact? _pendingImpact;

  CategoryManagementRepository get _categoryRepository =>
      widget.categoryRepository ?? sl<CategoryManagementRepository>();

  TransactionEntity? get _editing => widget.initial?.transaction;
  bool get _isEditing => _editing != null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    if (editing != null) {
      // Điền sẵn TRƯỚC khi gắn listener ghi chú, để lần gán text đầu không
      // kích hoạt tra cứu gợi ý.
      _selectedSegment = editing.type == 'transfer' ? 1 : 0;
      _amountString = editing.amount == editing.amount.roundToDouble()
          ? editing.amount.toInt().toString()
          : editing.amount.toString();
      _selectedDate = editing.date;
      _noteController.text = editing.note;
      final category = widget.initial?.category;
      if (category != null) {
        _selectedCategory = category;
        // Chiều tiền đã chọn lúc tạo nằm ở `type`; không gợi lại theo tên.
        _debtDirection =
            isDebtClassify(category.classify) ? editing.type : null;
      }
    }
    _noteController.addListener(_onNoteChanged);
    _loadWallets();
  }

  /// Chọn sẵn ví nguồn và ví đích theo cờ "Ví mặc định".
  ///
  /// Luật nằm ở `vi_chon_san.dart` để test được không cần dựng cả trang này.
  void _apDungViChonSan() {
    final chon = chonViChonSan<Wallet>(
      _wallets,
      laMacDinh: (w) => w.isDefault,
    );
    _selectedWallet = chon.nguon;
    _destinationWallet = chon.dich;
  }

  /// Ở chế độ sửa, ví của giao dịch phải thắng ví đầu danh sách.
  void _apDungViDangSua() {
    final editing = _editing;
    if (editing == null) return;
    Wallet? find(String? id) {
      if (id == null) return null;
      for (final w in _wallets) {
        if (w.id == id) return w;
      }
      return null;
    }

    _selectedWallet = find(editing.walletId) ?? _selectedWallet;
    _destinationWallet = find(editing.walletTransfer) ?? _destinationWallet;
  }

  @override
  void dispose() {
    _hoanGoiY?.cancel();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    final configuredWallets = widget.wallets;
    if (configuredWallets != null) {
      setState(() {
        _wallets = configuredWallets;
        _apDungViChonSan();
        _apDungViDangSua();
        _isLoadingWallets = false;
      });
      return;
    }
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final userIdAccount = int.tryParse(user?.id ?? '') ?? widget.idaccount;

    final db = sl<AppDatabase>();
    final list = await db.walletDao.getActive(userIdAccount);

    if (mounted) {
      setState(() {
        _wallets = list;
        _apDungViChonSan();
        _apDungViDangSua();
        _isLoadingWallets = false;
      });
    }
  }

  int _accountId() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess) {
        return int.tryParse(authState.user?.id ?? '') ?? widget.idaccount;
      }
    } catch (_) {
      // The isolated picker test does not provide an auth bloc.
    }
    return widget.idaccount;
  }

  bool get _isTransfer => _selectedSegment == 1;

  /// Giá trị `type` sẽ ghi xuống SQLite (`chi` | `thu` | `transfer`), suy từ
  /// loại giao dịch và danh mục đã chọn. `null` khi chưa đủ dữ kiện.
  ///
  /// Backend chỉ có hai loại (`Transaction` ± amount, `Transfer`); bộ giá trị
  /// nội bộ này được `SyncPayloadNormalizer` quy đổi, nên giữ nguyên nó là
  /// giữ nguyên hợp đồng đồng bộ, DAO và mọi chỗ thống kê đọc `type`.
  String? get _resolvedType {
    if (_isTransfer) return 'transfer';
    final category = _selectedCategory;
    if (category == null) return null;
    if (isDebtClassify(category.classify)) return _debtDirection;
    return category.classify == 'thu' ? 'thu' : 'chi';
  }

  /// Đường DUY NHẤT để đặt danh mục — cả bảng chọn lẫn thẻ gợi ý đều qua đây,
  /// để chiều tiền vay/nợ luôn được gợi sẵn kèm theo.
  void _chonDanhMuc(Category category) {
    setState(() {
      _selectedCategory = category;
      _suggestion = null;
      _debtDirection = isDebtClassify(category.classify)
          ? suggestDebtDirection(category.name)
          : null;
    });
  }

  /// Hoãn việc tra cứu gợi ý cho tới khi người dùng ngừng gõ.
  ///
  /// `TextEditingController` phát tín hiệu ở MỖI ký tự. Không hoãn thì một ghi
  /// chú 30 ký tự sinh 30 lượt đọc CSDL, mỗi lượt lại đọc thêm từ khoá — và
  /// mọi kết quả trừ cái cuối đều bị vứt đi.
  Timer? _hoanGoiY;
  static const Duration _doTreGoiY = Duration(milliseconds: 300);

  void _onNoteChanged() {
    _hoanGoiY?.cancel();
    final note = _noteController.text.trim();
    if (note.isEmpty || _isTransfer || _selectedCategory != null) {
      if (_suggestion != null && mounted) {
        setState(() => _suggestion = null);
      }
      return;
    }
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (!mounted) return;
      // Đọc lại từ controller thay vì dùng `note` đã bắt ở trên: trong lúc chờ
      // người dùng có thể đã gõ tiếp, và thứ đáng gợi ý là văn bản HIỆN TẠI.
      final hienTai = _noteController.text.trim();
      if (hienTai.isEmpty) return;
      _loadSuggestion(hienTai);
    });
  }

  Future<void> _loadSuggestion(String note) async {
    final requestedSegment = _selectedSegment;
    // Không còn segment chi/thu để khoanh vùng, nên tìm trên cả ba phân loại:
    // chiều tiền suy từ danh mục được chọn, không phải ngược lại.
    final categories = await _categoryRepository.selectableChildrenAll(
      accountId: _accountId(),
    );
    // MỘT truy vấn cho cả tài khoản. Trước đây chỗ này gọi `loadKeywords` một
    // lần cho mỗi danh mục, nên tài khoản có 20 danh mục là 20 truy vấn — nhân
    // với mỗi lần ghi chú thay đổi.
    final keywordsByCategory = await _categoryRepository.loadAllKeywords(
      accountId: _accountId(),
    );
    final candidates = <CategoryKeywordCandidate>[];
    for (final category in categories) {
      for (final keyword in keywordsByCategory[category.id] ?? const <String>[]) {
        candidates.add(
          CategoryKeywordCandidate(category: category, keyword: keyword),
        );
      }
    }
    final suggestion = widget.suggestionEngine.suggest(
      rawText: note,
      candidates: candidates,
    );
    if (!mounted ||
        _selectedSegment != requestedSegment ||
        _isTransfer ||
        _selectedCategory != null ||
        _noteController.text.trim() != note) {
      return;
    }
    setState(() => _suggestion = suggestion);
  }

  void _showWalletPickerBottomSheet(BuildContext context,
      {required bool isDestination}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                    icon:
                        const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_wallets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Chưa có ví nào',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ..._wallets.map((wallet) {
                  final isSelected = isDestination
                      ? _destinationWallet?.id == wallet.id
                      : _selectedWallet?.id == wallet.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isDestination) {
                          _destinationWallet = wallet;
                        } else {
                          _selectedWallet = wallet;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceContainerHigh
                            : Colors.transparent,
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
                            child: const Icon(Icons.account_balance_wallet,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wallet.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  wallet.type,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${CurrencyFormatter.formatSoThoi(wallet.balance)}đ",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle,
                                color: AppColors.secondary, size: 20),
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
        if (!_amountString.contains('.')) {
          _amountString += '.';
        }
      } else if (key == 'done' || key == '+' || key == '-') {
        // Handled or ignorable
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
    if (_amountString.contains('.')) return "$_amountStringđ";
    try {
      final number = int.parse(_amountString);
      return "${CurrencyFormatter.formatSoThoi(number)}đ";
    } catch (_) {
      return "$_amountStringđ";
    }
  }

  Color _getAmountColor() =>
      _resolvedType == 'thu' ? AppColors.income : AppColors.primary;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction(BuildContext context) async {
    final amount = double.tryParse(_amountString.replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }
    if (_selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví thanh toán')),
      );
      return;
    }
    if (!_isTransfer && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }
    if (_isTransfer && _destinationWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví đích')),
      );
      return;
    }
    final type = _resolvedType;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chiều tiền')),
      );
      return;
    }

    final editing = _editing;
    final tx = TransactionEntity(
      // Sửa thì giữ nguyên id (và những gì form không đụng tới) — tạo id mới
      // là nhân đôi giao dịch.
      id: editing?.id ?? const Uuid().v4(),
      walletId: _selectedWallet!.id,
      idaccount: editing?.idaccount ?? _accountId(),
      // Khoản chuyển KHÔNG có danh mục. Trước đây chỗ này gán 'cat_transfer' —
      // một id chưa từng được seed — và SyncEngine hoãn đẩy hàng ấy vĩnh viễn
      // vì không phân giải được danh mục.
      categoryId: _isTransfer ? null : _selectedCategory!.id,
      walletTransfer: _isTransfer ? _destinationWallet!.id : null,
      goalId: editing?.goalId,
      amount: amount,
      type: type,
      note: _noteController.text.trim(),
      date: _selectedDate,
      images: editing?.images ?? const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    final bloc = context.read<TransactionBloc>();

    // Ngân sách của danh mục: "Chặn" thì hỏi trước khi ghi khoản làm vượt,
    // "Cảnh báo" thì ghi luôn rồi báo. Đây là nơi DUY NHẤT đọc `OverSpending`.
    final impact = await _budgetImpactFor(tx, editing);
    if (!context.mounted) return;
    if (impact != null && impact.requiresConfirmation) {
      final ok = await _confirmOverBudget(context, impact);
      if (ok != true || !context.mounted) return;
    }
    _pendingImpact = impact;

    if (editing != null) {
      bloc.add(UpdateTransactionEvent(before: editing, after: tx));
      return;
    }
    bloc.add(AddTransactionEvent(
      transaction: tx,
      destinationWalletId: tx.walletTransfer,
    ));
  }

  Future<BudgetImpact?> _budgetImpactFor(
    TransactionEntity tx,
    TransactionEntity? editing,
  ) async {
    final categoryId = tx.categoryId;
    if (tx.type != 'chi' || categoryId == null) return null;

    BudgetView? view;
    try {
      view = await _lookupBudget(tx.idaccount, categoryId);
    } catch (_) {
      // Tra ngân sách hỏng không được chặn việc ghi giao dịch.
      return null;
    }
    if (view == null) return null;

    final now = DateTime.now();
    // Sửa: số cũ đã nằm trong "đã chi" nếu nó cùng danh mục và cùng kỳ —
    // phải trừ ra, không thì báo vượt oan.
    var previous = 0.0;
    if (editing != null &&
        editing.type == 'chi' &&
        editing.categoryId == categoryId &&
        budgetPeriodContains(view.budget, editing.date, now)) {
      previous = editing.amount;
    }
    return budgetImpactOf(
      view: view,
      amount: tx.amount,
      previousAmount: previous,
      date: tx.date,
      now: now,
    );
  }

  Future<BudgetView?> _lookupBudget(int idaccount, String categoryId) {
    final custom = widget.budgetLookup;
    if (custom != null) return custom(idaccount, categoryId);
    if (!sl.isRegistered<BudgetRepository>()) return Future.value(null);
    return sl<BudgetRepository>().activeBudgetForCategory(idaccount, categoryId);
  }

  Future<bool?> _confirmOverBudget(BuildContext context, BudgetImpact impact) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vượt ngân sách'),
        content: Text(budgetImpactDialogText(impact)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Vẫn ghi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocConsumer<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionLoadedState) {
          if (state.actionSuccess == true) {
            // Lời nhắn về ngân sách thay lời nhắn mặc định — chung chung,
            // không con số (banner tạm thời tối giản theo ý người dùng).
            final impactText = budgetImpactSnackText(_pendingImpact);
            _pendingImpact = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(impactText ??
                    (_isEditing
                        ? 'Đã lưu thay đổi'
                        : 'Thêm giao dịch thành công!')),
              ),
            );
            context.pop(true);
          } else if (state.actionSuccess == false &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${state.errorMessage}')),
            );
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 28),
              onPressed: () => context.pop(),
            ),
            title: Text(
              _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
              style: const TextStyle(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        _buildSegmentControl(),
                        const SizedBox(height: 32),
                        _buildAmountDisplay(),
                        const SizedBox(height: 32),
                        _buildFormCard(context),
                        const SizedBox(height: 16),
                        _buildNumericKeyboard(),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(context, state),
              ],
            ),
          ),
        );
      },
    );
    final transactionBloc = widget.transactionBloc;
    return transactionBloc == null
        ? BlocProvider<TransactionBloc>(
            create: (context) => sl<TransactionBloc>(),
            child: content,
          )
        : BlocProvider<TransactionBloc>.value(
            value: transactionBloc,
            child: content,
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
          Expanded(child: _buildSegmentButton(0, 'Giao dịch')),
          Expanded(child: _buildSegmentButton(1, 'Chuyển khoản')),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title) {
    final isSelected = _selectedSegment == index;
    // Cả hai loại đều tô `primary` khi chọn: màu xanh/đỏ của thu/chi nay theo
    // danh mục (ô số tiền), không còn gắn vào segment.
    final bgColor = isSelected ? AppColors.primary : Colors.transparent;
    final textColor = isSelected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      key: Key('transaction-type-$index'),
      onTap: () {
        setState(() {
          _selectedSegment = index;
          _suggestion = null;
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

  Widget _buildFormCard(BuildContext context) {
    final isTransfer = _isTransfer;
    final selectedCategory = _selectedCategory;
    final showDebtDirection =
        selectedCategory != null && isDebtClassify(selectedCategory.classify);
    final walletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_selectedWallet != null
            ? '${_selectedWallet!.name} • ${CurrencyFormatter.formatSoThoi(_selectedWallet!.balance)}đ'
            : 'Chọn ví');

    final destWalletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_destinationWallet != null
            ? '${_destinationWallet!.name} • ${CurrencyFormatter.formatSoThoi(_destinationWallet!.balance)}đ'
            : 'Chọn ví đích');

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
                walletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(
                height: 1,
                indent: 64,
                color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.category,
              label: 'Danh mục',
              valueWidget: Text(
                _selectedCategory != null
                    ? _selectedCategory!.name
                    : 'Chọn danh mục',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedCategory != null
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  fontWeight: _selectedCategory != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
              showArrow: true,
              onTap: () async {
                // Mở đúng tab của danh mục đang chọn; lần đầu thì tab chi.
                final selected = await context.push<Category>(
                  '/add/category',
                  extra: selectedCategory?.classify ?? kCategoryClassifies.first,
                );
                if (selected != null) _chonDanhMuc(selected);
              },
            ),
            if (showDebtDirection) ...[
              Divider(
                  height: 1,
                  indent: 64,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              _buildDebtDirectionRow(),
            ],
            if (_suggestion != null) ...[
              Divider(
                  height: 1,
                  indent: 64,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              _buildSuggestionCard(_suggestion!),
            ],
          ] else ...[
            _buildFormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví nguồn (Từ ví)',
              valueWidget: Text(
                walletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(
                height: 1,
                indent: 64,
                color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.account_balance_wallet,
              label: 'Ví đích (Đến ví)',
              valueWidget: Text(
                destWalletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: true),
            ),
          ],
          Divider(
              height: 1,
              indent: 64,
              color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notes,
                      color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Thêm ghi chú cho giao dịch...',
                      hintStyle: TextStyle(
                          fontSize: 14, color: AppColors.outlineVariant),
                      border: InputBorder.none,
                    ),
                    style:
                        const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              indent: 64,
              color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          _buildFormRow(
            icon: Icons.calendar_today,
            label: 'Ngày',
            valueWidget: Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
            ),
            trailingIcon: Icons.calendar_month,
            onTap: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(CategorySuggestion suggestion) => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gợi ý danh mục',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.category.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Khớp với “${suggestion.matchedKeyword}” trong ghi chú.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _suggestion = null),
                  child: const Text('Bỏ qua'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _chonDanhMuc(suggestion.category),
                  child: const Text('Chọn danh mục này'),
                ),
              ],
            ),
          ],
        ),
      );

  /// Công tắc chiều tiền — chỉ hiện khi danh mục là vay/nợ, vì đó là phân loại
  /// duy nhất gom cả tiền vào lẫn tiền ra (Cho vay/Trả nợ ↔ Đi vay/Thu nợ).
  Widget _buildDebtDirectionRow() => _buildFormRow(
        icon: Icons.swap_vert,
        label: 'Chiều tiền',
        valueWidget: Wrap(
          spacing: 8,
          children: [
            _directionChip('chi', 'Tiền ra'),
            _directionChip('thu', 'Tiền vào'),
          ],
        ),
      );

  Widget _directionChip(String direction, String label) {
    final selected = _debtDirection == direction;
    return ChoiceChip(
      key: Key('debt-direction-$direction'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.outlineVariant),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.primary,
      ),
      onSelected: (_) => setState(() => _debtDirection = direction),
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
      '7',
      '8',
      '9',
      'backspace',
      '4',
      '5',
      '6',
      '+',
      '1',
      '2',
      '3',
      '-',
      '.',
      '0',
      '000',
      'done'
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final keyStr = keys[index];
        bool isOperator =
            keyStr == 'backspace' || keyStr == '+' || keyStr == '-';
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
      return const Icon(Icons.backspace_outlined,
          size: 24, color: AppColors.primary);
    }
    if (keyStr == 'done') {
      return const Icon(Icons.check, size: 28, color: Colors.white);
    }
    if (keyStr == '+' || keyStr == '-') {
      return Text(
        keyStr,
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.normal,
            color: AppColors.primary),
      );
    }
    return Text(
      keyStr,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
    );
  }

  Widget _buildSaveButton(BuildContext context, TransactionState state) {
    final isSubmitting = state is TransactionLoadedState && state.isSubmitting;

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
        ],
      ),
      child: ElevatedButton(
        onPressed: isSubmitting ? null : () => _saveTransaction(context),
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
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
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
