import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/models/category_suggestion.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

class AddTransactionPage extends StatefulWidget {
  final int idaccount;
  final CategoryManagementRepository? categoryRepository;
  final List<Wallet>? wallets;
  final CategorySuggestionEngine suggestionEngine;
  final TransactionBloc? transactionBloc;

  const AddTransactionPage({
    super.key,
    this.idaccount = 1,
    this.categoryRepository,
    this.wallets,
    this.suggestionEngine = const CategorySuggestionEngine(),
    this.transactionBloc,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  int _selectedSegment = 0; // 0: Chi tiêu, 1: Thu nhập, 2: Chuyển khoản
  String _amountString = "0";

  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;
  Wallet? _destinationWallet;
  Category? _selectedCategory;
  CategorySuggestion? _suggestion;

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoadingWallets = true;

  CategoryManagementRepository get _categoryRepository =>
      widget.categoryRepository ?? sl<CategoryManagementRepository>();

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
    _loadWallets();
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
        _selectedWallet = _wallets.isEmpty ? null : _wallets.first;
        _destinationWallet =
            _wallets.length > 1 ? _wallets[1] : _selectedWallet;
        _isLoadingWallets = false;
      });
      return;
    }
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final userIdAccount = int.tryParse(user?.id ?? '') ?? widget.idaccount;

    final db = sl<AppDatabase>();
    final list = await db.walletDao.getAll(userIdAccount);

    if (mounted) {
      setState(() {
        _wallets = list;
        if (_wallets.isNotEmpty) {
          _selectedWallet = _wallets.first;
          if (_wallets.length > 1) {
            _destinationWallet = _wallets[1];
          } else {
            _destinationWallet = _wallets.first;
          }
        } else {
          _selectedWallet = null;
          _destinationWallet = null;
        }
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

  String get _classify => _selectedSegment == 0 ? 'chi' : 'thu';

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
    if (note.isEmpty || _selectedSegment == 2 || _selectedCategory != null) {
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
    final requestedClassify = _classify;
    final categories = await _categoryRepository.selectableChildren(
      accountId: _accountId(),
      classify: requestedClassify,
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
        _classify != requestedClassify ||
        _selectedSegment == 2 ||
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
                            "${NumberFormat('#,###', 'vi_VN').format(wallet.balance)}đ",
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
      final formatter = NumberFormat('#,###', 'vi_VN');
      return "${formatter.format(number)}đ";
    } catch (_) {
      return "$_amountStringđ";
    }
  }

  Color _getAmountColor() {
    if (_selectedSegment == 0) return AppColors.primary;
    if (_selectedSegment == 1) return AppColors.income;
    return AppColors.primary;
  }

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

  void _saveTransaction(BuildContext context) {
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
    if (_selectedSegment != 2 && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }
    if (_selectedSegment == 2 && _destinationWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví đích')),
      );
      return;
    }

    final type = _selectedSegment == 0
        ? 'chi'
        : (_selectedSegment == 1 ? 'thu' : 'transfer');

    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final userIdAccount = int.tryParse(user?.id ?? '') ?? widget.idaccount;

    final tx = TransactionEntity(
      id: const Uuid().v4(),
      walletId: _selectedWallet!.id,
      idaccount: userIdAccount,
      categoryId:
          _selectedSegment == 2 ? 'cat_transfer' : _selectedCategory!.id,
      amount: amount,
      type: type,
      note: _noteController.text.trim(),
      date: _selectedDate,
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    context.read<TransactionBloc>().add(
          AddTransactionEvent(
            transaction: tx,
            destinationWalletId:
                _selectedSegment == 2 ? _destinationWallet?.id : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocConsumer<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionLoadedState) {
          if (state.actionSuccess == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thêm giao dịch thành công!')),
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
            title: const Text(
              'Thêm giao dịch',
              style: TextStyle(
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
          Expanded(child: _buildSegmentButton(0, 'Chi tiêu')),
          Expanded(child: _buildSegmentButton(1, 'Thu nhập')),
          Expanded(child: _buildSegmentButton(2, 'Chuyển khoản')),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title) {
    bool isSelected = _selectedSegment == index;
    Color bgColor = Colors.transparent;
    Color textColor = AppColors.textSecondary;

    if (isSelected) {
      if (index == 0) {
        bgColor = AppColors.expense;
        textColor = Colors.white;
      } else if (index == 1) {
        bgColor = AppColors.income;
        textColor = Colors.white;
      } else {
        bgColor = AppColors.primary;
        textColor = Colors.white;
      }
    }

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
    bool isTransfer = _selectedSegment == 2;
    final walletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_selectedWallet != null
            ? '${_selectedWallet!.name} • ${NumberFormat('#,###', 'vi_VN').format(_selectedWallet!.balance)}đ'
            : 'Chọn ví');

    final destWalletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_destinationWallet != null
            ? '${_destinationWallet!.name} • ${NumberFormat('#,###', 'vi_VN').format(_destinationWallet!.balance)}đ'
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
                final selected = await context.push<Category>(
                  '/add/category',
                  extra: _classify,
                );
                if (selected != null) {
                  setState(() {
                    _selectedCategory = selected;
                    _suggestion = null;
                  });
                }
              },
            ),
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
                  onPressed: () => setState(() {
                    _selectedCategory = suggestion.category;
                    _suggestion = null;
                  }),
                  child: const Text('Chọn danh mục này'),
                ),
              ],
            ),
          ],
        ),
      );

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
