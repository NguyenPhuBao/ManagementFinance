import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../bloc/goal_cubit.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/goal_edit_form.dart';
import '../widgets/goal_appearance.dart';
import '../../../../core/auth/current_account.dart';

/// Trang tạo mục tiêu, và — khi có [goalId] — cũng là trang **sửa**.
///
/// Một biểu mẫu cho cả hai chế độ, theo đúng lối mà thiết kế Stitch đặt ra cho
/// danh mục ("Thêm / Chỉnh sửa danh mục con"). Tách thành hai trang thì hai bản
/// sao của cùng một biểu mẫu sẽ trôi xa nhau: sửa nhãn ở một bên, quên bên kia.
///
/// Chế độ sửa **không** động tới ví tích luỹ. Ô ấy hiện ở dạng chỉ đọc và trỏ
/// người dùng về nút đổi ví ở trang chi tiết, nơi đặt phép khoá sau khoản nạp
/// đầu tiên. Nhân đôi luật khoá sang đây là tự chuốc hai luật lệch nhau.
class GoalAddPage extends StatelessWidget {
  const GoalAddPage({super.key, this.goalId});

  /// `null` là tạo mới; khác `null` là sửa mục tiêu đó.
  final String? goalId;

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context) ?? 0;

    return MultiBlocProvider(
      providers: [
        BlocProvider<GoalCubit>(
          create: (_) => sl<GoalCubit>(),
        ),
        BlocProvider<WalletCubit>(
          create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
        ),
      ],
      child: _GoalAddPageContent(goalId: goalId),
    );
  }
}

enum DepositFrequency { daily, weekly, monthly }

class _GoalAddPageContent extends StatefulWidget {
  const _GoalAddPageContent({this.goalId});

  final String? goalId;

  @override
  State<_GoalAddPageContent> createState() => _GoalAddPageContentState();
}

class _GoalAddPageContentState extends State<_GoalAddPageContent> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _depositAmountController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _autoDeposit = true;
  DepositFrequency _frequency = DepositFrequency.monthly;

  bool _isRecalculatingFromDeposit = false;
  bool _isRecalculatingFromDate = false;

  WalletEntity? _selectedSavingsWallet;
  WalletEntity? _selectedSourceWallet;

  /// Mặc định của CSDL là `'flag'`, nhưng bảng chọn cố ý không có lá cờ (nó là
  /// giá trị dự phòng của `bieuTuongMucTieu`). Mục tiêu mới vì thế mở ra với
  /// con heo đất — một lựa chọn hợp lệ, nằm trong bảng, và người dùng thấy
  /// ngay là đổi được.
  String _icon = 'savings';
  String _colour = kMauMucTieu.first;

  bool get _isEdit => widget.goalId != null;

  /// Mục tiêu đang sửa. `null` cho tới khi nạp xong, và ở chế độ tạo thì luôn
  /// `null`.
  GoalEntity? _goalDangSua;
  bool _dangNapGoal = false;
  String? _loiNapGoal;

  @override
  void initState() {
    super.initState();
    _targetAmountController.addListener(_onTargetAmountOrDateChanged);
    _depositAmountController.addListener(_onDepositAmountChanged);
    if (_isEdit) {
      _dangNapGoal = true;
      _napGoalDeSua();
    }
  }

  /// Đọc mục tiêu và điền sẵn biểu mẫu.
  ///
  /// Thứ tự ở đây quan trọng: `_targetDate` và `_frequency` phải được đặt
  /// **trước** khi gán `_targetAmountController.text`. Hai ô số tiền và hạn
  /// định nối với nhau bằng một cặp listener tính chéo — gán tiền trước thì
  /// listener sẽ tính ra một hạn định mới từ hạn mặc định "một năm nữa" và ghi
  /// đè lên hạn thật của mục tiêu, ngay trước mắt người dùng.
  Future<void> _napGoalDeSua() async {
    try {
      final goal = await sl<GoalRepository>().getGoalById(widget.goalId!);
      if (!mounted) return;
      if (goal == null) {
        setState(() {
          _dangNapGoal = false;
          _loiNapGoal = 'Không tìm thấy mục tiêu này. Có thể nó vừa bị xoá.';
        });
        return;
      }

      _targetDate = goal.targetDate;
      _frequency = switch (goal.cycleTakeMoney) {
        'Day' => DepositFrequency.daily,
        'Week' => DepositFrequency.weekly,
        _ => DepositFrequency.monthly,
      };
      // Chu kỳ trống nghĩa là mục tiêu này chưa từng đặt kế hoạch trích tiền —
      // để công tắc tắt thay vì bịa ra "hàng tháng".
      _autoDeposit = goal.cycleTakeMoney != null;
      _icon = goal.icon;
      _colour = goal.colour;
      _nameController.text = goal.name;

      final formatter =
          NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);
      _targetAmountController.text =
          formatter.format(goal.targetAmount).trim();

      // Gán SAU số tiền mục tiêu, và phải chặn cặp listener tính chéo lại.
      // Dòng trên vừa kích hoạt `_onTargetAmountOrDateChanged`, thứ đã ghi một
      // con số GỢI Ý vào ô này; đè lại bằng số thật mà không chặn thì
      // `_onDepositAmountChanged` sẽ tính ngược ra một hạn định mới và xoá mất
      // hạn thật của mục tiêu.
      if (goal.autoDepositAmount != null) {
        _isRecalculatingFromDate = true;
        _depositAmountController.text =
            formatter.format(goal.autoDepositAmount!).trim();
        _isRecalculatingFromDate = false;
      }

      setState(() {
        _goalDangSua = goal;
        _dangNapGoal = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangNapGoal = false;
        _loiNapGoal = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _depositAmountController.dispose();
    super.dispose();
  }

  int get _cycleDays {
    switch (_frequency) {
      case DepositFrequency.daily:
        return 1;
      case DepositFrequency.weekly:
        return 7;
      case DepositFrequency.monthly:
        return 30;
    }
  }

  String get _frequencyLabel {
    switch (_frequency) {
      case DepositFrequency.daily:
        return 'ngày';
      case DepositFrequency.weekly:
        return 'tuần';
      case DepositFrequency.monthly:
        return 'tháng';
    }
  }

  void _onTargetAmountOrDateChanged() {
    if (_isRecalculatingFromDeposit) return;
    _isRecalculatingFromDate = true;

    final rawAmount = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawAmount) ?? 0.0;
    if (targetAmount <= 0) {
      _isRecalculatingFromDate = false;
      return;
    }

    final totalDays = _targetDate.difference(DateTime.now()).inDays;
    final validDays = totalDays <= 0 ? _cycleDays : totalDays;
    final periods = (validDays / _cycleDays.toDouble()).ceil();
    if (periods <= 0) {
      _isRecalculatingFromDate = false;
      return;
    }

    final suggested = (targetAmount / periods).ceilToDouble();
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);

    final formattedStr = formatter.format(suggested).trim();
    if (_depositAmountController.text != formattedStr) {
      _depositAmountController.value = TextEditingValue(
        text: formattedStr,
        selection: TextSelection.collapsed(offset: formattedStr.length),
      );
    }

    _isRecalculatingFromDate = false;
    setState(() {});
  }

  void _onDepositAmountChanged() {
    if (_isRecalculatingFromDate) return;

    final rawTarget = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawTarget) ?? 0.0;

    final rawDeposit = _depositAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final depositAmount = double.tryParse(rawDeposit) ?? 0.0;

    if (targetAmount <= 0 || depositAmount <= 0) return;

    _isRecalculatingFromDeposit = true;
    final periodsNeeded = (targetAmount / depositAmount).ceil();
    final daysNeeded = (periodsNeeded * _cycleDays).clamp(1, 36500);

    try {
      _targetDate = DateTime.now().add(Duration(days: daysNeeded));
    } catch (_) {}

    _isRecalculatingFromDeposit = false;
    setState(() {});
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      // Mục tiêu đang sửa có thể đã quá hạn, và `showDatePicker` ném assertion
      // — MÀN ĐỎ, không phải thông báo lỗi — khi `initialDate` nằm trước
      // `firstDate`. Xem `ngayNhoNhatChoLich`.
      firstDate: ngayNhoNhatChoLich(_targetDate, DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
      _onTargetAmountOrDateChanged();
    }
  }

  void _submitForm() {
    final name = _nameController.text.trim();
    final rawAmount = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawAmount) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên mục tiêu')),
      );
      return;
    }
    if (targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền mục tiêu hợp lệ')),
      );
      return;
    }

    // Hai ô này trước đây chỉ dùng để tính ngược ra hạn định rồi bị vứt —
    // khối "Tự động trích tiền định kỳ" thu ba thông tin và lưu đúng một.
    final rawTrich =
        _depositAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final soTienTrich = double.tryParse(rawTrich) ?? 0.0;

    if (_autoDeposit) {
      if (soTienTrich <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nhập số tiền trích mỗi kỳ, hoặc tắt công tắc '
                '"Tự động trích tiền định kỳ".'),
          ),
        );
        return;
      }
      if (_selectedSourceWallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chọn ví nguồn để app biết trích tiền từ đâu.'),
          ),
        );
        return;
      }
      // Ví nguồn trùng ví tích luỹ thì tiền không đi đâu cả trong khi tiến độ
      // vẫn tăng. `depositToGoal` cũng chặn, nhưng ở đó nó ném ra giữa một kỳ
      // trích chạy nền — chặn ngay tại form thì người dùng còn sửa được.
      final viNhanId = _isEdit
          ? _goalDangSua?.walletId
          : _selectedSavingsWallet?.id;
      if (viNhanId != null && _selectedSourceWallet!.id == viNhanId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ví nguồn phải khác ví tích lũy — chuyển tiền sang '
                'chính nó không làm số dư đổi mà tiến độ vẫn tăng.'),
          ),
        );
        return;
      }
    }

    final chuKy = _autoDeposit
        ? switch (_frequency) {
            DepositFrequency.daily => 'Day',
            DepositFrequency.weekly => 'Week',
            DepositFrequency.monthly => 'Month',
          }
        : null;

    if (_isEdit) {
      // Đường sửa dừng ở đây: không đụng ví tích luỹ (ô ấy chỉ đọc), không
      // đụng tiến độ. Cũng không cần `idaccount` — mục tiêu đã có chủ rồi.
      context
          .read<GoalCubit>()
          .updateGoal(
            id: widget.goalId!,
            name: name,
            targetAmount: targetAmount,
            targetDate: _targetDate,
            cycleTakeMoney: chuKy,
            icon: _icon,
            colour: _colour,
            autoDepositAmount: _autoDeposit ? soTienTrich : null,
            autoDepositWalletId:
                _autoDeposit ? _selectedSourceWallet?.id : null,
          )
          .then((loi) {
        if (!mounted) return;
        if (loi != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loi), backgroundColor: Colors.red),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật mục tiêu.'),
            backgroundColor: AppColors.income,
          ),
        );
        context.pop();
      });
      return;
    }

    // Ví nhận là BẮT BUỘC: mỗi lần nạp tiền sau này sẽ chuyển thẳng vào ví
    // này, nên mục tiêu không có ví thì phiếu nạp không biết đưa tiền đi đâu.
    if (_selectedSavingsWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ví tích lũy — tiền gửi vào mục tiêu '
              'sẽ được chuyển vào ví này.'),
        ),
      );
      return;
    }

    // Đây là đường GHI: `?? 0` không dùng được ở đây (mục tiêu sẽ thuộc về
    // "không ai"), và `?? 1` thì còn tệ hơn — ghi vào tài khoản admin thật.
    final idaccount = currentAccountIdOrNull(context);
    if (idaccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác định được tài khoản đăng nhập. '
              'Vui lòng đăng nhập lại trước khi tạo mục tiêu.'),
        ),
      );
      return;
    }

    context.read<GoalCubit>().addGoal(
          idaccount: idaccount,
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
          walletId: _selectedSavingsWallet!.id,
          // Lưu nhịp người dùng vừa chọn. Trước đây lựa chọn này chỉ dùng để
          // tính ngược ra ngày hạn rồi bị vứt bỏ; giữ lại thì trang chi tiết
          // hiển thị được kế hoạch cạnh thực tế theo cùng một đơn vị.
          cycleTakeMoney: chuKy,
          icon: _icon,
          colour: _colour,
          autoDepositAmount: _autoDeposit ? soTienTrich : null,
          autoDepositWalletId: _autoDeposit ? _selectedSourceWallet?.id : null,
        ).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo mục tiêu tiết kiệm thành công!'),
            backgroundColor: AppColors.income,
          ),
        );
        context.pop();
      }
    });
  }

  DateTime _calculateEstimatedCompletionDate() {
    return _targetDate;
  }

  void _showWalletPickerBottomSheet({
    required BuildContext mainContext,
    required String title,
    required List<WalletEntity> wallets,
    required WalletEntity? selectedWallet,
    required ValueChanged<WalletEntity> onWalletSelected,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    showModalBottomSheet(
      context: mainContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(mainContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await mainContext.push('/wallets/add');
                      if (mainContext.mounted) {
                        final idaccount = currentAccountIdOrNull(mainContext) ?? 0;
                        mainContext.read<WalletCubit>().loadWallets(idaccount);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18, color: AppColors.income),
                    label: const Text(
                      'Tạo ví mới',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wallets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Chưa có ví nào trong hệ thống.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await mainContext.push('/wallets/add');
                            if (mainContext.mounted) {
                              final idaccount = currentAccountIdOrNull(mainContext) ?? 0;
                              mainContext.read<WalletCubit>().loadWallets(idaccount);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm Ví Mới Ngay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.income,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: wallets.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      if (index == wallets.length) {
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: AppColors.income),
                          ),
                          title: const Text(
                            '+ Thêm ví mới ngay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                          subtitle: const Text(
                            'Tạo ví mới để liên kết tích lũy',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await mainContext.push('/wallets/add');
                            if (mainContext.mounted) {
                              final idaccount = currentAccountIdOrNull(mainContext) ?? 0;
                              mainContext.read<WalletCubit>().loadWallets(idaccount);
                            }
                          },
                        );
                      }

                      final wallet = wallets[index];
                      final isSelected = selectedWallet?.id == wallet.id;
                      Color itemColor;
                      try {
                        itemColor = Color(int.parse(wallet.colour.replaceAll('#', '0xFF')));
                      } catch (_) {
                        itemColor = AppColors.primary;
                      }

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            wallet.type == 'bank'
                                ? Icons.account_balance
                                : (wallet.type == 'ewallet'
                                    ? Icons.account_balance_wallet
                                    : Icons.wallet),
                            color: itemColor,
                          ),
                        ),
                        title: Text(
                          wallet.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: AppColors.primary,
                          ),
                        ),
                        subtitle: Text(
                          '${wallet.typeLabel} • Số dư: ${currencyFormatter.format(wallet.balance)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.income)
                            : null,
                        onTap: () {
                          onWalletSelected(wallet);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final estimatedCompletionDate = _calculateEstimatedCompletionDate();

    return BlocListener<GoalCubit, GoalState>(
      listener: (context, state) {
        if (state is GoalError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, walletState) {
          final wallets = (walletState is WalletLoaded) ? walletState.wallets : <WalletEntity>[];

          if (_isEdit) {
            // Chế độ sửa chỉ HIỂN THỊ ví tích luỹ, không cho đổi ở đây — nên
            // nó được tra ra từ chính mục tiêu chứ không phải từ lựa chọn nào.
            final viId = _goalDangSua?.walletId;
            _selectedSavingsWallet = viId == null
                ? null
                : wallets.where((w) => w.id == viId).firstOrNull;
          }
          if (_isEdit && _goalDangSua?.autoDepositWalletId != null) {
            // Ví nguồn đã lưu thắng ví mặc định. Không có nhánh này thì mở
            // trang sửa rồi bấm Lưu là âm thầm đổi ví trích sang ví mặc định —
            // tiền kỳ sau ra khỏi một ví khác hẳn.
            _selectedSourceWallet ??= wallets
                .where((w) => w.id == _goalDangSua!.autoDepositWalletId)
                .firstOrNull;
          }
          if (wallets.isNotEmpty) {
            // KHÔNG chọn sẵn ví tích luỹ. Trước đây chỗ này tự lấy "ví
            // investment/bank đầu tiên, không có thì ví bất kỳ", nên mọi mục
            // tiêu đều ra đời đã gắn một ví người dùng chưa hề nhìn tới — và
            // ví ấy lập tức không xoá được nữa. Nay ô này bắt buộc và để trống
            // cho tới khi người dùng thật sự chọn.
            _selectedSourceWallet ??= wallets.firstWhere(
              (w) => w.isDefault,
              orElse: () => wallets.length > 1 ? wallets[1] : wallets.first,
            );
          }

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
                _isEdit ? 'Chỉnh sửa mục tiêu' : 'Thêm Mục Tiêu Tiết Kiệm',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _dangNapGoal ? null : _submitForm,
                  child: const Text(
                    'Lưu',
                    style: TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            body: _dangNapGoal
                ? const Center(child: CircularProgressIndicator())
                : _loiNapGoal != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _loiNapGoal!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Image
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: NetworkImage(
                              'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&q=80&w=800'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.bottomLeft,
                        child: const Text(
                          'Lập kế hoạch tương lai',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Goal Information Card
                    Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel('TÊN MỤC TIÊU TIẾT KIỆM'),
                          const SizedBox(height: 4),
                          _buildTextField(
                            controller: _nameController,
                            hint: 'e.g. Mua Laptop MacBook Pro',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('SỐ TIỀN MỤC TIÊU'),
                                    const SizedBox(height: 4),
                                    _buildTextField(
                                      controller: _targetAmountController,
                                      hint: '40.000.000đ',
                                      textColor: AppColors.income,
                                      isBold: true,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('HẠN ĐỊNH'),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: _selectDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(_targetDate),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const Icon(Icons.calendar_today, color: AppColors.outlineVariant, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('BIỂU TƯỢNG & MÀU'),
                          const SizedBox(height: 8),
                          _buildIconPicker(),
                          const SizedBox(height: 12),
                          _buildColourPicker(),
                          const SizedBox(height: 16),
                          _buildLabel('VÍ TÍCH LŨY LIÊN KẾT'),
                          const SizedBox(height: 4),
                          _buildDropdownButton(
                            icon: Icons.account_balance_wallet,
                            title: _selectedSavingsWallet?.name ??
                                (_isEdit
                                    ? 'Chưa gắn ví tích lũy'
                                    : 'Chọn ví tích lũy'),
                            subtitle: _isEdit
                                // Luật khoá ví sau khoản nạp đầu tiên nằm ở
                                // `changeWallet`, và nút gọi nó ở trang chi
                                // tiết. Chép luật ấy sang đây là tạo bản thứ
                                // hai để chúng lệch nhau về sau; câu này chỉ
                                // trỏ đúng chỗ, giống câu báo lỗi khi xoá ví.
                                ? 'Đổi ở trang chi tiết mục tiêu'
                                : _selectedSavingsWallet != null
                                    ? '${_selectedSavingsWallet!.typeLabel} • ${currencyFormatter.format(_selectedSavingsWallet!.balance)}'
                                    : 'Bấm để chọn ví tích lũy',
                            iconColor: AppColors.income,
                            showChevron: !_isEdit,
                            onTap: _isEdit
                                ? null
                                : () {
                              _showWalletPickerBottomSheet(
                                mainContext: context,
                                title: 'Chọn Ví Tích Lũy Liên Kết',
                                wallets: wallets,
                                selectedWallet: _selectedSavingsWallet,
                                onWalletSelected: (w) {
                                  setState(() => _selectedSavingsWallet = w);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Auto-Deposit Schedule Card
                    Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tự động trích tiền định kỳ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'App tự chuyển tiền vào mục tiêu mỗi kỳ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _autoDeposit,
                                onChanged: (val) {
                                  setState(() => _autoDeposit = val);
                                },
                                activeThumbColor: AppColors.income,
                              ),
                            ],
                          ),
                          if (_autoDeposit) ...[
                            const SizedBox(height: 16),
                            _buildLabel('SỐ TIỀN TRÍCH MỖI KỲ (VNĐ)'),
                            const SizedBox(height: 4),
                            _buildTextField(
                              controller: _depositAmountController,
                              hint: '5.000.000đ',
                              textColor: AppColors.income,
                              isBold: true,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('CHU KỲ TRÍCH'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: DepositFrequency.values.map((freq) {
                                  final isSelected = _frequency == freq;
                                  String label;
                                  switch (freq) {
                                    case DepositFrequency.daily:
                                      label = 'Hàng ngày';
                                      break;
                                    case DepositFrequency.weekly:
                                      label = 'Hàng tuần';
                                      break;
                                    case DepositFrequency.monthly:
                                      label = 'Hàng tháng';
                                      break;
                                  }
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _frequency = freq);
                                        _onTargetAmountOrDateChanged();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.05),
                                                    blurRadius: 2,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? AppColors.income : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('VÍ NGUỒN TRÍCH TIỀN'),
                            const SizedBox(height: 4),
                            _buildDropdownButton(
                              icon: Icons.account_balance,
                              title: _selectedSourceWallet?.name ?? 'Chọn ví nguồn trích',
                              subtitle: _selectedSourceWallet != null
                                  ? '${_selectedSourceWallet!.typeLabel} • ${currencyFormatter.format(_selectedSourceWallet!.balance)}'
                                  : 'Bấm để chọn ví trích tiền',
                              iconColor: AppColors.primary,
                              onTap: () {
                                _showWalletPickerBottomSheet(
                                  mainContext: context,
                                  title: 'Chọn Ví Nguồn Trích Tiền',
                                  wallets: wallets,
                                  selectedWallet: _selectedSourceWallet,
                                  onWalletSelected: (w) {
                                    setState(() => _selectedSourceWallet = w);
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Prediction Insight Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEE1F8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDEE1F8)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb, color: Color(0xFFC2C5DB), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF424658),
                                  height: 1.5,
                                  fontFamily: 'Inter',
                                ),
                                children: [
                                  const TextSpan(text: 'AI Dự đoán: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: 'Dự kiến bạn sẽ đạt mục tiêu vào ngày '),
                                  TextSpan(
                                      text: DateFormat('dd/MM/yyyy').format(estimatedCompletionDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
                                  TextSpan(
                                      text:
                                          ' với mức trích ${_depositAmountController.text.isNotEmpty ? _depositAmountController.text : "0"}đ / $_frequencyLabel.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        _isEdit
                            ? 'Lưu thay đổi'
                            : _autoDeposit
                                ? 'Tạo Mục Tiêu & Bật Trích Tự Động'
                                : 'Tạo Mục Tiêu',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bảng chọn biểu tượng.
  ///
  /// Cuộn ngang có chủ ý: điện thoại thật rộng 411dp chứ không phải 1280px như
  /// Chrome trong bộ test, và một `Wrap` mười ô ở đây từng là kiểu bố cục đã
  /// gây tràn ở những màn khác. Cuộn thì không bao giờ tràn dù thêm bao nhiêu
  /// lựa chọn.
  Widget _buildIconPicker() {
    final mau = mauMucTieu(_colour);
    // Danh sách phải chứa biểu tượng ĐANG lưu, kể cả khi nó ngoài bảng chọn —
    // xem `danhSachBieuTuong`.
    final danhSach = danhSachBieuTuong(_icon);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: danhSach.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final ten = danhSach[i];
          final chon = ten == _icon;
          return GestureDetector(
            onTap: () => setState(() => _icon = ten),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: chon
                    ? mau.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: chon ? Border.all(color: mau, width: 2) : null,
              ),
              child: Icon(
                bieuTuongMucTieu(ten),
                color: chon ? mau : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColourPicker() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kMauMucTieu.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final hex = kMauMucTieu[i];
          final mau = mauMucTieu(hex);
          final chon = hex == _colour;
          return GestureDetector(
            onTap: () => setState(() => _colour = hex),
            child: Container(
              width: 36,
              decoration: BoxDecoration(
                color: mau,
                shape: BoxShape.circle,
                border: chon
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: chon
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    Color textColor = AppColors.primary,
    bool isBold = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 16,
        color: textColor,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: AppColors.outlineVariant, size: 20)
            : null,
      ),
    );
  }

  Widget _buildDropdownButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    VoidCallback? onTap,
    /// Mũi tên xổ xuống là lời hứa "bấm được". Ô chỉ đọc phải bỏ nó đi, nếu
    /// không người dùng cứ bấm mãi vào một chỗ không phản hồi.
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.expand_more, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
