import '../../../wallet/data/repositories/wallet_repository.dart';
import 'dart:async';
import '../../../../core/utils/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/goal_deposit_wallets.dart';
import '../../domain/goal_history_direction.dart';
import '../../domain/goal_wallet_shortfall.dart';
import '../../domain/goal_history_filter.dart';
import '../widgets/goal_config_card.dart';
import '../widgets/goal_history_sheet.dart';
import '../widgets/goal_progress.dart';
import '../widgets/chi_tiet_muc_tieu/ghi_chu_muc_tieu.dart';
import '../widgets/chi_tiet_muc_tieu/khoi_lich_su_muc_tieu.dart';
import '../widgets/chi_tiet_muc_tieu/khoi_nhan_dinh_muc_tieu.dart';
import '../widgets/chi_tiet_muc_tieu/khoi_so_tien_muc_tieu.dart';
import '../widgets/chi_tiet_muc_tieu/nut_duoi_muc_tieu.dart';
import '../widgets/chi_tiet_muc_tieu/phieu_nap_tien.dart';
import '../widgets/chi_tiet_muc_tieu/phieu_rut_tien.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

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

  /// Tên hai ví, tra sẵn cho `GoalConfigCard`.
  ///
  /// `null` nghĩa là chưa gán hoặc ví đã bị xoá mềm — widget nói "Chưa gán ví"
  /// chứ không để ô trống, vì ô trống trông y hệt một lỗi tải dữ liệu.
  String? _tenViTichLuy;
  String? _tenViNguonTrich;

  /// Toàn bộ lịch sử đã rút gọn, giữ lại để mở bảng đầy đủ mà không phải mở
  /// một dòng dữ liệu thứ hai.
  List<KhoanTichLuy> _khoanLichSu = const [];

  /// Đăng ký với dòng dữ liệu mục tiêu — **bẫy 4.5 đã đóng 2026-09-08**.
  ///
  /// Bản trước chỉ gọi `getGoalById` một lần trong `initState` rồi tự giữ
  /// `_goal` trong `State`. Đồng bộ kéo về một thay đổi của chính mục tiêu
  /// **đang mở** thì màn hình vẫn hiện số cũ — không lỗi, không log, người
  /// dùng chỉ phát hiện khi thoát ra vào lại.
  StreamSubscription<List<GoalEntity>>? _dongDuLieu;

  @override
  void initState() {
    super.initState();
    _goalRepository = sl<GoalRepository>();
    _loadGoal();
  }

  @override
  void dispose() {
    _dongDuLieu?.cancel();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    setState(() => _isLoading = true);
    final goal = await _goalRepository.getGoalById(widget.id);
    final canhBao = goal == null ? null : await _tinhCanhBaoVi(goal);
    final ten = goal == null ? (null, null) : await _tenCacVi(goal);
    if (mounted) {
      setState(() {
        _goal = goal;
        _canhBaoVi = canhBao;
        _tenViTichLuy = ten.$1;
        _tenViNguonTrich = ten.$2;
        _isLoading = false;
      });
    }
    if (goal != null) _dangKyDongDuLieu(goal.idaccount);
  }

  /// Nghe `watchGoals` của **cả tài khoản**, không phải riêng mục tiêu này.
  ///
  /// Hai lý do, và cần cả hai:
  ///
  /// 1. `GoalRepository` không có `watchGoalById`, và thêm một hàm mới chỉ để
  ///    một trang dùng thì đắt hơn phần nó tiết kiệm được.
  /// 2. `_canhBaoVi` cộng dồn **mọi** mục tiêu trỏ vào cùng ví, nên một mục
  ///    tiêu *khác* nạp tiền cũng làm câu cảnh báo ở đây đổi. Nghe hẹp lại
  ///    đúng một hàng là bỏ sót vế ấy.
  ///
  /// Mã tài khoản lấy từ **chính mục tiêu vừa đọc**, không từ `AuthBloc`: hàm
  /// này chạy sau một `await` nên `context` có thể đã tháo, và đọc phiên ở đây
  /// là mở lại đúng cửa mà G17 vừa đóng.
  void _dangKyDongDuLieu(int idaccount) {
    if (_dongDuLieu != null) return;
    _dongDuLieu = _goalRepository.watchGoals(idaccount).listen((danhSach) async {
      if (!mounted) return;

      // `firstWhereOrNull` viết tay: hàng có thể đã biến mất khỏi danh sách vì
      // vừa bị xoá mềm ở máy khác. Khi ấy giữ nguyên những gì đang hiện —
      // `orElse: () => throw` là màn đỏ ngay giữa một lượt đồng bộ nền.
      GoalEntity? moi;
      for (final g in danhSach) {
        if (g.id == widget.id) {
          moi = g;
          break;
        }
      }
      if (moi == null) return;

      final canhBao = await _tinhCanhBaoVi(moi);
      final ten = await _tenCacVi(moi);
      if (!mounted) return;
      setState(() {
        _goal = moi;
        _canhBaoVi = canhBao;
        _tenViTichLuy = ten.$1;
        _tenViNguonTrich = ten.$2;
        // KHÔNG đụng `_isLoading`. Đường này là cập nhật nền, không phải một
        // lần tải do người dùng gây ra; bật cờ tải ở đây làm cả trang nháy về
        // vòng quay mỗi lần đồng bộ chạy xong.
      });
    });
  }

  /// Đổi hàng Drift sang dạng rút gọn cho tầng lọc.
  ///
  /// Chiều tiền đọc từ **tiền tố ghi chú** qua `laKhoanRutKhoiMucTieu` — đúng
  /// một nơi quyết định, cùng hàm mà dòng trên trang đang dùng. Tự so ví ở đây
  /// là bản sao thứ hai của bẫy 4.2.
  ///
  /// Nhãn "tự động" đọc từ **hậu tố** cùng ghi chú ấy, qua `laKhoanTuDong` —
  /// cùng lối, cùng lý do.
  List<KhoanTichLuy> _doiSangKhoan(List<dynamic> txs) => [
        for (final tx in txs)
          for (final ghiChu in [(tx.note as String?) ?? ''])
            KhoanTichLuy(
              ngay: tx.date as DateTime,
              soTien: tx.amount as double,
              laKhoanRut: laKhoanRutKhoiMucTieu(
                ghiChu: ghiChu,
                viCuaHang: tx.walletId as String,
                viTichLuy: _goal?.walletId,
              ),
              laTuDong: laKhoanTuDong(ghiChu),
            ),
      ];

  /// Mở bảng lịch sử đầy đủ kèm bộ lọc.
  void _moBangLichSu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => GoalHistorySheet(
        tenMucTieu: _goal?.name ?? '',
        khoan: _khoanLichSu,
      ),
    );
  }

  /// Tên ví tích luỹ và ví nguồn trích, tra một lượt.
  ///
  /// Trả `null` cho ví không tìm thấy thay vì ném: ví có thể đã bị xoá mềm sau
  /// khi mục tiêu trỏ vào nó, và `autoDepositWalletId` **không có khoá ngoại**
  /// (cùng lý do với `walletTransfer`, bẫy 4.1) nên không có gì ở tầng CSDL
  /// bảo đảm nó còn tồn tại.
  Future<(String?, String?)> _tenCacVi(GoalEntity goal) async {
    Future<String?> ten(String? id) async {
      if (id == null || id.isEmpty) return null;
      final w = await sl<WalletRepository>().getRowById(id);
      return w?.name;
    }

    return (await ten(goal.walletId), await ten(goal.autoDepositWalletId));
  }

  /// So số dư THẬT của ví tích lũy với TỔNG của mọi mục tiêu trỏ vào ví ấy.
  ///
  /// Phải cộng dồn chứ không so riêng mục tiêu đang mở: ba mục tiêu dùng chung
  /// một ví thì từng cái đều thấy "đủ tiền" trong khi cộng lại thì thiếu.
  Future<String?> _tinhCanhBaoVi(GoalEntity goal) async {
    final viId = goal.walletId;
    if (viId == null) return null;

    final vi = await sl<WalletRepository>().getRowById(viId);
    if (vi == null) return null;

    final tatCa = await _goalRepository.getGoals(goal.idaccount);
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
        : await sl<WalletRepository>().getActiveRows(accountId);
    if (!mounted) return;

    if (wallets.isEmpty) {
      baoNhanh('Chưa có ví nào để chọn.', loai: LoaiThongBao.loi);
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
                baoNhanh('Ví tích lũy nay là "${w.name}".', loai: LoaiThongBao.xong);
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
    final accountId = currentAccountIdOrNull(context);
    final wallets = accountId == null
        ? <Wallet>[]
        : await sl<WalletRepository>().getActiveRows(accountId);
    if (!mounted) return;

    final viTichLuy =
        wallets.where((w) => w.id == _goal!.walletId).firstOrNull;
    if (accountId == null || viTichLuy == null) {
      baoNhanh('Mục tiêu này chưa có ví tích lũy để rút.', loai: LoaiThongBao.loi);
      return;
    }

    final idNhanMacDinh = viNguonMacDinh(
      viCoSan: wallets.map((w) => w.id).toList(),
      viNhan: viTichLuy.id,
    );
    if (idNhanMacDinh == null) {
      baoNhanh('Cần thêm một ví khác "${viTichLuy.name}" để nhận '
              'tiền rút ra.', loai: LoaiThongBao.loi);
      return;
    }

    moPhieuRutTien(
      context: context,
      layMucTieu: () => _goal!,
      wallets: wallets,
      viTichLuy: viTichLuy,
      idNhanMacDinh: idNhanMacDinh,
      onXacNhan: (ctx, soTien, vi) => _rutTien(ctx, soTien, vi, accountId),
    );
  }

  Future<void> _rutTien(
      BuildContext ctx, double soTien, Wallet vi, int accountId) async {
    try {
      await _goalRepository.withdrawFromGoal(
        goalId: widget.id,
        goalName: _goal!.name,
        amount: soTien,
        walletId: vi.id,
        idaccount: accountId,
      );
    } catch (e) {
      // Repository còn một trần nữa mà giao diện không thấy: số
      // dư THẬT của ví tích lũy, vốn có thể thấp hơn tiến độ.
      baoNhanh(e is StateError ? e.message : '$e', loai: LoaiThongBao.loi);
      return;
    }

    if (ctx.mounted) Navigator.pop(ctx);
    if (!mounted) return;
    baoNhanh('Đã rút ${CurrencyFormatter.format(soTien)} khỏi mục '
          'tiêu về "${vi.name}".', loai: LoaiThongBao.xong);
    _loadGoal();
  }

  void _showDepositDialog() async {
    if (_goal == null) return;
    final accountId = currentAccountIdOrNull(context);
    final wallets = accountId == null
        ? <Wallet>[]
        : await sl<WalletRepository>().getActiveRows(accountId);

    if (!mounted) return;
    if (accountId == null || wallets.isEmpty) {
      baoNhanh('Vui lòng tạo ít nhất 1 ví trước khi gửi tiết kiệm.', loai: LoaiThongBao.loi);
      return;
    }

    // Ví nhận là thuộc tính của mục tiêu, không hỏi lại ở đây. Chỉ mục tiêu do
    // bản app cũ tạo mới có thể thiếu — chặn lại và chỉ đúng chỗ sửa.
    final viNhan = wallets
        .where((w) => w.id == _goal!.walletId)
        .firstOrNull;
    if (viNhan == null) {
      baoNhanh('Mục tiêu này chưa có ví nhận tiền tích lũy. '
              'Bấm biểu tượng đổi ví ở góc trên để chọn.', loai: LoaiThongBao.loi);
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
      baoNhanh('Cần thêm một ví khác "${viNhan.name}" để làm ví '
              'nguồn chuyển tiền.', loai: LoaiThongBao.loi);
      return;
    }

    moPhieuNapTien(
      context: context,
      layMucTieu: () => _goal!,
      wallets: wallets,
      viNhan: viNhan,
      idNguonMacDinh: idNguonMacDinh,
      onXacNhan: (ctx, soTien, vi) => _napTien(ctx, soTien, vi, accountId),
    );
  }

  Future<void> _napTien(
      BuildContext ctx, double deposit, Wallet vi, int accountId) async {
    // Nạp vượt mục tiêu KHÔNG bị chặn — tiết kiệm dư là
    // chuyện bình thường. Câu nhắc đã hiện ngay dưới ô nhập
    // từ trước khi bấm.
    await _goalRepository.depositToGoal(
      goalId: widget.id,
      goalName: _goal!.name,
      depositAmount: deposit,
      walletId: vi.id,
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
    baoNhanh('Đã gửi thêm ${CurrencyFormatter.format(deposit)} vào mục tiêu!', loai: LoaiThongBao.xong);
    _loadGoal();
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
          tooltip: 'Quay lại',
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
              onPressed: () => baoNhanh('Mục tiêu đã tích được tiền trong ví hiện tại '
                      'nên không đổi ví được. Tiền đang nằm thật trong ví đó.', loai: LoaiThongBao.loi),
            ),
          IconButton(
            tooltip: 'Xoá',
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
                    KhoiSoTienMucTieu(goal: _goal!, remaining: remaining),
                    if (_goal!.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GhiChuMucTieu(_goal!.note.trim()),
                    ],
                    const SizedBox(height: 24),
                    KhoiNhanDinhMucTieu(goal: _goal!),
                    if (_canhBaoVi != null) ...[
                      const SizedBox(height: 12),
                      CanhBaoViMucTieu(_canhBaoVi!),
                    ],
                    // Khối "Cấu hình" — thêm 2026-09-08 sau khi người dùng
                    // báo trang này thiếu nội dung. Cả bốn dòng của nó đều là
                    // dữ liệu đã nằm sẵn trên `GoalEntity`; chỗ thiếu là chỗ
                    // hiển thị, không phải dữ liệu.
                    //
                    // Đặt SAU hộp dự báo và cảnh báo ví: hai khối kia nói về
                    // việc *cần làm gì*, khối này nói về *đang cài đặt thế
                    // nào* — thứ người dùng tra lại chứ không đọc mỗi lần mở.
                    const SizedBox(height: 12),
                    GoalConfigCard(
                      goal: _goal!,
                      tenViTichLuy: _tenViTichLuy,
                      tenViNguonTrich: _tenViNguonTrich,
                    ),
                    const SizedBox(height: 32),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
            NutDuoiMucTieu(
              goal: _goal!,
              onVongMoi: _xacNhanVongMoi,
              onNap: _showDepositDialog,
              onRut: _showWithdrawDialog,
              // Trang này không nghe dòng dữ liệu (bẫy 4.5) nên phải tự nạp lại
              // sau khi trang sửa đóng, nếu không tên và số tiền vừa đổi vẫn là
              // số cũ trên màn hình.
              onSua: () async {
                await context.push('/goals/${widget.id}/edit');
                if (mounted) _loadGoal();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final accountId = currentAccountIdOrNull(context);
    // Không có phiên thì không có lịch sử nào thuộc về ai để hiển thị. Trước
    // đây chỗ này rơi về 1 và lấy giao dịch của tài khoản admin.
    if (accountId == null) return const SizedBox.shrink();

    return StreamBuilder<dynamic>(
      stream: _goalRepository.watchGoalTransactions(
          accountId, widget.id, _goal?.name ?? ''),
      builder: (context, snapshot) {
        // MỘT dòng dữ liệu nuôi cả biểu đồ lẫn danh sách. Mở dòng thứ hai cho
        // biểu đồ là chạy đúng câu truy vấn ấy hai lần, và mở cửa cho hai bản
        // dữ liệu lệch nhau trên cùng một màn hình.
        //
        // Dòng dữ liệu được dựng LẠI mỗi khi `_goal` đổi, vì tên mục tiêu là
        // tham số của nó. Sau khi trang sửa đóng, `_loadGoal()` đổi `_goal` và
        // StreamBuilder quay về trạng thái chưa có dữ liệu — trộn ca ấy với
        // "rỗng thật" làm lịch sử nháy thành "Chưa có khoản tích lũy nào" rồi
        // hiện lại. Trông y như vừa mất dữ liệu.
        final dangTai = !snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting;
        final txs = (snapshot.data as List<dynamic>?) ?? [];
        // Ghi lại để nhãn phía dưới biết có nên hiện nút "Xem tất cả" không,
        // và để bảng đầy đủ có sẵn dữ liệu mà không phải mở một dòng dữ liệu
        // thứ hai.
        if (!dangTai) _khoanLichSu = _doiSangKhoan(txs);

        return KhoiLichSuMucTieu(
          goal: _goal!,
          dangTai: dangTai,
          txs: txs,
          khoan: _khoanLichSu,
          onXemTatCa: _moBangLichSu,
        );
      },
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
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bắt đầu vòng mới?'),
        content: Text(
          'Tiến độ của "${goal.name}" sẽ về 0 và hạn định dời sang kỳ tiếp '
          'theo.\n\n'
          '${CurrencyFormatter.format(goal.currentAmount)} đã tích được vẫn nằm nguyên '
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

    try {
      await _goalRepository.batDauVongMoi(goal.id);
      if (!mounted) return;
      baoNhanh('Đã bắt đầu vòng tích luỹ mới.', loai: LoaiThongBao.xong);
      _loadGoal();
    } catch (e) {
      if (!mounted) return;
      baoNhanh(e.toString(), loai: LoaiThongBao.loi);
    }
  }
}
