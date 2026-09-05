import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/goal_deposit_wallets.dart';
import '../../domain/goal_deposit_warning.dart';
import '../../domain/goal_forecast.dart';
import '../../domain/goal_history_direction.dart';
import '../../domain/goal_wallet_shortfall.dart';
import '../widgets/goal_progress.dart';

class GoalDetailPage extends StatefulWidget {
  final String id;
  const GoalDetailPage({super.key, required this.id});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  late final GoalRepository _goalRepository;
  GoalEntity? _goal;
  bool _isLoading = true;

  /// Câu nhắc khi ví tích lũy không còn đủ tiền cho các mục tiêu trỏ vào nó.
  ///
  /// Tính ở đây chứ không trong `build`: nó cần đọc CSDL (số dư ví + tổng của
  /// mọi mục tiêu dùng chung ví ấy), mà `build` thì chạy lại rất nhiều lần.
  String? _canhBaoVi;


  @override
  void initState() {
    super.initState();
    _goalRepository = sl<GoalRepository>();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    setState(() => _isLoading = true);
    final goal = await _goalRepository.getGoalById(widget.id);
    final canhBao = goal == null ? null : await _tinhCanhBaoVi(goal);
    if (mounted) {
      setState(() {
        _goal = goal;
        _canhBaoVi = canhBao;
        _isLoading = false;
      });
    }
  }

  /// So số dư THẬT của ví tích lũy với TỔNG của mọi mục tiêu trỏ vào ví ấy.
  ///
  /// Phải cộng dồn chứ không so riêng mục tiêu đang mở: ba mục tiêu dùng chung
  /// một ví thì từng cái đều thấy "đủ tiền" trong khi cộng lại thì thiếu.
  Future<String?> _tinhCanhBaoVi(GoalEntity goal) async {
    final viId = goal.walletId;
    if (viId == null) return null;

    final db = sl<AppDatabase>();
    final vi = await db.walletDao.getById(viId);
    if (vi == null) return null;

    final tatCa = await db.goalDao.getAll(goal.idaccount);
    final tong = tatCa
        .where((g) => g.walletId == viId)
        .fold<double>(0.0, (t, g) => t + g.currentAmount);

    return canhBaoViKhongDu(
      tenVi: vi.name,
      soDuVi: vi.balance,
      tongMucTieuDangGiu: tong,
    );
  }

  /// Trỏ mục tiêu sang một ví nhận khác.
  ///
  /// Cố ý KHÔNG có lựa chọn "bỏ ví": mục tiêu luôn phải có ví nhận, nếu không
  /// lần nạp sau không biết chuyển tiền đi đâu. Đây cũng là đường thoát cho bế
  /// tắc xoá ví — ví còn liên kết thì không xoá được, nên chuyển mục tiêu sang
  /// ví khác trước rồi xoá.
  void _xacNhanDoiViNhan() async {
    final accountId = currentAccountIdOrNull(context);
    final wallets = accountId == null
        ? <Wallet>[]
        : await sl<AppDatabase>().walletDao.getAll(accountId);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (wallets.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa có ví nào để chọn.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Đổi ví nhận tiền tích lũy'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Tiền gửi vào "${_goal!.name}" từ nay sẽ chuyển vào ví bạn chọn. '
              'Số tiền đã tích được giữ nguyên.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
          ),
          for (final w in wallets)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (w.id == _goal!.walletId) return;
                await _goalRepository.changeWallet(widget.id, w.id);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Ví tích lũy nay là "${w.name}".')),
                );
                _loadGoal();
              },
              child: Row(
                children: [
                  Icon(
                    w.id == _goal!.walletId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: w.id == _goal!.walletId
                        ? const Color(0xFF2E6B27)
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(w.name)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _xacNhanXoaMucTieu() {
    // Cầm sẵn router: sau khoảng chờ `deleteGoal`, `context` của `build` không
    // còn được `mounted` của State bảo chứng theo cách analyzer nhận ra.
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa mục tiêu'),
        content:
            Text('Bạn có chắc chắn muốn xóa mục tiêu "${_goal!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _goalRepository.deleteGoal(widget.id);
              if (!mounted) return;
              router.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  /// Rút tiền khỏi mục tiêu, chuyển về một ví khác.
  ///
  /// Ngược chiều phiếu nạp: ví tích lũy là **nguồn** và cố định, người dùng chỉ
  /// chọn ví **nhận**.
  void _showWithdrawDialog() async {
    if (_goal == null) return;
    final db = sl<AppDatabase>();
    final accountId = currentAccountIdOrNull(context);
    final wallets = accountId == null
        ? <Wallet>[]
        : await db.walletDao.getAll(accountId);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final viTichLuy =
        wallets.where((w) => w.id == _goal!.walletId).firstOrNull;
    if (accountId == null || viTichLuy == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Mục tiêu này chưa có ví tích lũy để rút.')),
      );
      return;
    }

    final idNhanMacDinh = viNguonMacDinh(
      viCoSan: wallets.map((w) => w.id).toList(),
      viNhan: viTichLuy.id,
    );
    if (idNhanMacDinh == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cần thêm một ví khác "${viTichLuy.name}" để nhận '
              'tiền rút ra.'),
        ),
      );
      return;
    }

    final tien =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final amountController = TextEditingController();
    final viNhanKhaDung =
        wallets.where((w) => w.id != viTichLuy.id).toList();
    Wallet selectedTargetWallet =
        viNhanKhaDung.firstWhere((w) => w.id == idNhanMacDinh);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text(
                'Rút khỏi ${_goal!.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mục tiêu đang giữ ${tien.format(_goal!.currentAmount)} '
                'trong ví "${viTichLuy.name}".',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                decoration: InputDecoration(
                  labelText: 'Số tiền muốn rút (VNĐ)',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chuyển về ví nào',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Wallet>(
                    value: selectedTargetWallet,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more,
                        color: AppColors.primary),
                    items: viNhanKhaDung
                        .map((w) => DropdownMenuItem<Wallet>(
                              value: w,
                              child: Text(
                                '${w.name} (Số dư: ${tien.format(w.balance)})',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() => selectedTargetWallet = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final raw =
                      amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                  final soTien = double.tryParse(raw) ?? 0.0;
                  if (soTien <= 0) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Vui lòng nhập số tiền hợp lệ')));
                    return;
                  }
                  if (soTien > _goal!.currentAmount) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('Mục tiêu chỉ đang giữ '
                          '${tien.format(_goal!.currentAmount)}.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }

                  try {
                    await _goalRepository.withdrawFromGoal(
                      goalId: widget.id,
                      goalName: _goal!.name,
                      amount: soTien,
                      walletId: selectedTargetWallet.id,
                      idaccount: accountId,
                    );
                  } catch (e) {
                    // Repository còn một trần nữa mà giao diện không thấy: số
                    // dư THẬT của ví tích lũy, vốn có thể thấp hơn tiến độ.
                    messenger.showSnackBar(SnackBar(
                      content: Text(e is StateError ? e.message : '$e'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(
                    content: Text('Đã rút ${tien.format(soTien)} khỏi mục '
                        'tiêu về "${selectedTargetWallet.name}".'),
                  ));
                  _loadGoal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xác nhận rút tiền',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDepositDialog() async {
    if (_goal == null) return;
    final db = sl<AppDatabase>();
    final accountId = currentAccountIdOrNull(context);
    final wallets = accountId == null
        ? <Wallet>[]
        : await db.walletDao.getAll(accountId);

    if (!mounted) return;
    if (accountId == null || wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ít nhất 1 ví trước khi gửi tiết kiệm.')),
      );
      return;
    }

    // Ví nhận là thuộc tính của mục tiêu, không hỏi lại ở đây. Chỉ mục tiêu do
    // bản app cũ tạo mới có thể thiếu — chặn lại và chỉ đúng chỗ sửa.
    final viNhan = wallets
        .where((w) => w.id == _goal!.walletId)
        .firstOrNull;
    if (viNhan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mục tiêu này chưa có ví nhận tiền tích lũy. '
              'Bấm biểu tượng đổi ví ở góc trên để chọn.'),
        ),
      );
      return;
    }

    // Ví nguồn không được trùng ví nhận. Tài khoản chỉ có đúng ví nhận thì
    // không có gì để chuyển đi — chặn ở đây thay vì mở phiếu rồi để nút xác
    // nhận nổ.
    final idNguonMacDinh = viNguonMacDinh(
      viCoSan: wallets.map((w) => w.id).toList(),
      viNhan: viNhan.id,
    );
    if (idNguonMacDinh == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cần thêm một ví khác "${viNhan.name}" để làm ví '
              'nguồn chuyển tiền.'),
        ),
      );
      return;
    }

    // Giữ sẵn messenger TRƯỚC khi mở phiếu.
    //
    // Bên trong phiếu, `context` của `StatefulBuilder` là context của tấm
    // phiếu, còn `mounted` lại là của trang. Sau `Navigator.pop(ctx)` thì phiếu
    // đã bị huỷ nhưng `mounted` của trang vẫn `true`, nên phép kiểm `if
    // (!mounted) return` KHÔNG canh được việc dùng context ấy — đúng hai cảnh
    // báo `use_build_context_synchronously` mà analyzer chỉ ra. Cầm sẵn
    // messenger thì không còn cần context nào sau khoảng chờ nữa.
    final messenger = ScaffoldMessenger.of(context);

    final amountController = TextEditingController();
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    // Chỉ còn MỘT ô chọn: ví nguồn. Ví nhận đã cố định ở trên.
    final viNguonKhaDung =
        wallets.where((w) => w.id != viNhan.id).toList();
    Wallet selectedSourceWallet =
        viNguonKhaDung.firstWhere((w) => w.id == idNguonMacDinh);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(
                    'Gửi thêm tiền vào ${_goal!.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Số tiền hiện tại: ${currencyFormatter.format(_goal!.currentAmount)} / ${currencyFormatter.format(_goal!.targetAmount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Còn thiếu ${currencyFormatter.format(_goal!.remainingAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E6B27),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    onChanged: (_) => setModalState(() {}),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.income,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nhập số tiền muốn tích lũy thêm (VNĐ)',
                      hintText: 'e.g. 1.000.000',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn ví nguồn thanh toán (Trừ tiền)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Wallet>(
                        value: selectedSourceWallet,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more, color: AppColors.primary),
                        items: viNguonKhaDung.map((w) {
                          return DropdownMenuItem<Wallet>(
                            value: w,
                            child: Text(
                              '${w.name} (Số dư: ${currencyFormatter.format(w.balance)})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() => selectedSourceWallet = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ví nhận CHỈ để xem — nó là thuộc tính của mục tiêu, đổi qua
                  // nút "Đổi ví nhận" ở thanh trên chứ không phải mỗi lần nạp.
                  Row(
                    children: [
                      const Icon(Icons.arrow_downward,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chuyển vào ví tích lũy: ${viNhan.name}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E6B27),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (canhBaoNapVuot(
                        _goal!,
                        double.tryParse(amountController.text
                                .replaceAll(RegExp(r'[^\d]'), '')) ??
                            0.0,
                      ) !=
                      null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            canhBaoNapVuot(
                                  _goal!,
                                  double.tryParse(amountController.text
                                          .replaceAll(RegExp(r'[^\d]'), '')) ??
                                      0.0,
                                ) ??
                                '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final raw = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                      final deposit = double.tryParse(raw) ?? 0.0;
                      if (deposit <= 0) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                        );
                        return;
                      }

                      // Kiểm tra số dư ví nguồn
                      if (deposit > selectedSourceWallet.balance) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Số dư ví "${selectedSourceWallet.name}" không đủ. '
                              'Hiện có: ${currencyFormatter.format(selectedSourceWallet.balance)}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Nạp vượt mục tiêu KHÔNG bị chặn — tiết kiệm dư là
                      // chuyện bình thường. Câu nhắc đã hiện ngay dưới ô nhập
                      // từ trước khi bấm.
                      await _goalRepository.depositToGoal(
                        goalId: widget.id,
                        goalName: _goal!.name,
                        depositAmount: deposit,
                        walletId: selectedSourceWallet.id,
                        idaccount: accountId,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      // KHÔNG gọi `context.read<WalletCubit>().loadWallets()`
                      // ở đây. Route `/goals/:id` không có provider nào cho
                      // `WalletCubit`, nên lệnh ấy ném
                      // `ProviderNotFoundError`. Mã cũ đặt nó SAU khi nạp
                      // xong nên sự cố chỉ nổ ở đường thành công và không lộ
                      // ra trong bộ test.
                      //
                      // Và kể cả khi có provider thì nó cũng vô nghĩa:
                      // `WalletCubit` đăng ký kiểu **factory**, mỗi nơi gọi
                      // nhận một instance riêng. Trang danh sách ví tự tạo
                      // cubit của nó và `loadWallets` ngay khi dựng, nên số dư
                      // vẫn đúng khi người dùng mở lại trang ấy.
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Đã gửi thêm ${currencyFormatter.format(deposit)} vào mục tiêu!'),
                          backgroundColor: AppColors.income,
                        ),
                      );
                      _loadGoal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Xác nhận gửi tiết kiệm',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_goal == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Không tìm thấy mục tiêu')),
      );
    }

    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final remaining = (_goal!.targetAmount - _goal!.currentAmount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _goal!.name,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Chỉ đổi được khi mục tiêu CHƯA tích đồng nào — tiền đã tích đang
          // nằm thật trong ví hiện tại, đổi mà không chuyển tiền theo là làm nó
          // phân mảnh không lần lại được. Vẫn hiện khi mục tiêu chưa có ví:
          // mục tiêu do bản app cũ tạo cần đúng nút này để gắn ví lần đầu.
          if (_goal!.walletId == null || _goal!.currentAmount <= 0)
            IconButton(
              tooltip: 'Đổi ví nhận tiền tích lũy',
              icon: const Icon(Icons.swap_horiz, color: AppColors.primary),
              onPressed: _xacNhanDoiViNhan,
            )
          else
            IconButton(
              tooltip: 'Đã tích tiền nên không đổi được ví',
              icon: Icon(Icons.swap_horiz,
                  color: AppColors.onSurfaceVariant.withValues(alpha: .4)),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mục tiêu đã tích được tiền trong ví hiện tại '
                      'nên không đổi ví được. Tiền đang nằm thật trong ví đó.'),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _xacNhanXoaMucTieu,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GoalProgressRing(goal: _goal!),
                    const SizedBox(height: 32),
                    _buildAmountInfo(currencyFormatter, remaining),
                    if (_goal!.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildGhiChu(_goal!.note.trim()),
                    ],
                    const SizedBox(height: 24),
                    _buildInsightBox(),
                    if (_canhBaoVi != null) ...[
                      const SizedBox(height: 12),
                      _buildCanhBaoVi(_canhBaoVi!),
                    ],
                    const SizedBox(height: 32),
                    _buildHistorySection(currencyFormatter),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInfo(NumberFormat currencyFormatter, double remaining) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currencyFormatter.format(_goal!.currentAmount),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -1,
              ),
            ),
            Text(
              ' / ${currencyFormatter.format(_goal!.targetAmount)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            children: [
              const TextSpan(text: 'Còn lại '),
              TextSpan(
                text: currencyFormatter.format(remaining),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' để đạt mục tiêu'),
            ],
          ),
        ),
      ],
    );
  }

  /// Ghi chú của người dùng — cái **lý do** đằng sau mục tiêu.
  ///
  /// Đặt ngay dưới con số, trước hộp dự báo: khi mở mục tiêu ra để cân nhắc có
  /// nên tiêu vào tiền tích luỹ hay không, câu tự mình viết ra là thứ đáng đọc
  /// trước cả tốc độ tiết kiệm.
  ///
  /// Không có khung viền, không có nhãn "GHI CHÚ": nó là chữ của người dùng
  /// chứ không phải một trường dữ liệu cần gắn mác.
  Widget _buildGhiChu(String noiDung) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.format_quote_rounded,
            size: 18, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            noiDung,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanhBaoVi(String noiDung) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              noiDung,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBox() {
    final now = DateTime.now();
    final duBao = duBaoHoanThanh(_goal!, now);
    final thucTe = tocDoThucTe(_goal!, now);
    final keHoach = tocDoKeHoach(_goal!, now: now);
    final tien = NumberFormat.currency(
        locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    // Dòng đầu: dự báo THẬT thay cho câu lặp lại hạn chót.
    //
    // `targetDate` được tính một lần lúc tạo từ chu kỳ người dùng nhập, rồi
    // đóng băng. Không có bộ lập lịch nào trích tiền, nên nhịp thật do chính
    // các lần nạp tay quyết định — và đó mới là thứ đáng hiển thị.
    final String tieuDe;
    if (_goal!.isCompleted || _goal!.remainingAmount <= 0) {
      tieuDe = 'ĐÃ ĐẠT MỤC TIÊU';
    } else if (duBao == null) {
      tieuDe = 'CHƯA ĐỦ DỮ LIỆU ĐỂ DỰ BÁO';
    } else {
      tieuDe =
          'DỰ BÁO HOÀN THÀNH: THÁNG ${DateFormat('MM/yyyy').format(duBao)}';
    }

    final nhipLabel = switch (_goal!.cycleTakeMoney) {
      'Day' => 'mỗi ngày',
      'Week' => 'mỗi tuần',
      'Quarter' => 'mỗi quý',
      'Year' => 'mỗi năm',
      _ => 'mỗi tháng',
    };

    final String mota;
    if (_goal!.isCompleted || _goal!.remainingAmount <= 0) {
      mota = 'Không cần tích thêm đồng nào.';
    } else if (thucTe == null) {
      mota = 'Gửi thêm vài lần để app ước lượng được nhịp tích lũy của bạn.';
    } else if (duBao == null) {
      mota = 'Chưa tích được đồng nào $nhipLabel, nên chưa ước lượng được '
          'ngày đạt mục tiêu.';
    } else {
      final canThem = keHoach == null
          ? ''
          : ' · cần ${tien.format(keHoach)} để kịp hạn '
              '${DateFormat('MM/yyyy').format(_goal!.targetDate)}';
      mota = 'Đang tích ${tien.format(thucTe)} $nhipLabel$canThem.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC3EBBB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Color(0xFF2E6B27),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mota,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(NumberFormat currencyFormatter) {
    final accountId = currentAccountIdOrNull(context);
    // Không có phiên thì không có lịch sử nào thuộc về ai để hiển thị. Trước
    // đây chỗ này rơi về 1 và lấy giao dịch của tài khoản admin.
    if (accountId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nút "Xem tất cả" từng đứng bên phải nhãn này với `onPressed: () {}`.
        // Danh sách bên dưới vốn đã hiện TOÀN BỘ lịch sử (`itemCount:
        // txs.length`, không cắt bớt), nên ngoài việc không làm gì, nó còn ngụ
        // ý sai rằng đang có phần bị giấu đi.
        const Text(
          'LỊCH SỬ TÍCH LŨY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<dynamic>(
          stream: _goalRepository.watchGoalTransactions(
              accountId, widget.id, _goal?.name ?? ''),
          builder: (context, snapshot) {
            // Dòng dữ liệu được dựng LẠI mỗi khi `_goal` đổi, vì tên mục tiêu
            // là tham số của nó. Sau khi trang sửa đóng, `_loadGoal()` đổi
            // `_goal` và StreamBuilder quay về trạng thái chưa có dữ liệu —
            // trộn ca ấy với "rỗng thật" làm lịch sử nháy thành "Chưa có khoản
            // tích lũy nào" rồi hiện lại. Trông y như vừa mất dữ liệu.
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final txs = (snapshot.data as List<dynamic>?) ?? [];
            if (txs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Chưa có khoản tích lũy nào.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final tx = txs[index];
                final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.date as DateTime);
                final amount = (tx.amount as double);
                // Chiều tiền đọc từ tiền tố ghi chú do chính app sinh ra, KHÔNG
                // từ vị trí ví — so ví là diễn giải hàng cũ bằng cấu hình hiện
                // tại của mục tiêu, nên đổi ví một lần là lịch sử đọc sai hết.
                // Xem `goal_history_direction.dart`.
                final laKhoanRut = laKhoanRutKhoiMucTieu(
                  ghiChu: (tx.note as String?) ?? '',
                  viCuaHang: tx.walletId as String,
                  viTichLuy: _goal!.walletId,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: laKhoanRut
                            ? const Color(0xFFFBEDEC)
                            : const Color(0xFFF0F5EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.savings_outlined,
                        color: Color(0xFF2E6B27),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.note.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${laKhoanRut ? '−' : '+'}'
                      '${currencyFormatter.format(amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: laKhoanRut
                            ? AppColors.error
                            : const Color(0xFF2E6B27),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Hỏi lại trước khi đặt lại mục tiêu.
  ///
  /// Đây là thao tác **xoá tiến độ** và không hoàn tác được, nên nó phải có
  /// một bước xác nhận — cùng lối với nút xoá mục tiêu. Hộp thoại nói rõ hai
  /// điều người dùng cần biết trước khi bấm: tiến độ về 0, và **tiền không đi
  /// đâu cả**.
  Future<void> _xacNhanVongMoi() async {
    final goal = _goal!;
    final tien = NumberFormat.currency(
        locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bắt đầu vòng mới?'),
        content: Text(
          'Tiến độ của "${goal.name}" sẽ về 0 và hạn định dời sang kỳ tiếp '
          'theo.\n\n'
          '${tien.format(goal.currentAmount)} đã tích được vẫn nằm nguyên '
          'trong ví — không đồng nào bị chuyển đi. Muốn tiêu số ấy thì dùng '
          '"Rút khỏi mục tiêu".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );

    if (dongY != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _goalRepository.batDauVongMoi(goal.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã bắt đầu vòng tích luỹ mới.'),
          backgroundColor: AppColors.income,
        ),
      );
      _loadGoal();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút vòng mới chỉ hiện khi mục tiêu ĐÃ XONG và CÓ bật lặp lại — và
          // nó đứng đầu, trên cả "Gửi thêm tiết kiệm": với một mục tiêu đã
          // hoàn thành thì nạp thêm không còn là việc muốn làm nhất.
          //
          // Ẩn nút không phải là phép chặn. `batDauVongMoi` kiểm lại cả hai
          // điều kiện ở tầng repository, vì đặt lại một mục tiêu đang dở là
          // xoá tiến độ và không có gì hoàn tác.
          if (_goal!.daHoanThanh && _goal!.recurrence) ...[
            ElevatedButton.icon(
              onPressed: _xacNhanVongMoi,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.income,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text(
                'Bắt đầu vòng mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _showDepositDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Gửi thêm tiết kiệm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Chỉ hiện khi có gì để rút. Nút mờ suốt đời với mục tiêu chưa nạp
          // đồng nào chỉ làm rối chỗ.
          if (_goal!.currentAmount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _showWithdrawDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: .8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Rút khỏi mục tiêu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            // Trang này không nghe dòng dữ liệu (bẫy 4.5) nên phải tự nạp lại
            // sau khi trang sửa đóng, nếu không tên và số tiền vừa đổi vẫn là
            // số cũ trên màn hình.
            onPressed: () async {
              await context.push('/goals/${widget.id}/edit');
              if (mounted) _loadGoal();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: .8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Chỉnh sửa mục tiêu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
