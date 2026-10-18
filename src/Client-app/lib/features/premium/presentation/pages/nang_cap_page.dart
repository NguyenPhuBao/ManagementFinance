import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/dong_lich_su.dart';
import '../../domain/cau_loi_thanh_toan.dart';
import '../../domain/don_can_xu_ly.dart';
import '../../data/repositories/don_thanh_toan_repository.dart';
import '../../domain/quyen_tinh_nang.dart';
import '../../domain/tran_goi.dart';
import '../../data/models/tran_goi.dart';
import '../../domain/hang_goi.dart';
import '../../data/models/trang_thai_goi.dart';
import '../bloc/goi_cubit.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

/// Câu mở đầu khi đến từ cửa chặn (`/premium?tran=`): *"Bạn đã dùng 3/3 ví của
/// gói Basic."* — số lấy từ trần đang có hiệu lực, không ghi cứng.
String cauMoDau(LoaiTran tran, TranGoi tranGoi) {
  final n = tranGoi.cua(tran);
  return 'Bạn đã dùng $n/$n ${tenTran(tran)} của gói Basic.';
}

/// Câu mở đầu khi đến từ một tính năng bị khoá (`/premium?quyen=`) — spec phân quyền 2026-10-08 mục 4.4.
String cauMoDauQuyen(MaQuyen ma) => '${ma.ten} là tính năng Premium.';

/// Màn Nâng cấp `/premium` — ngoài shell, `push` từ mọi nơi (spec 9.1). Màn
/// Stitch *"Nâng cấp Premium - FlowMoney"* `c999da970da94cb4ab4331fc44230884`
/// (lượt gọi 2026-10-06 trả `timeout` nhưng màn vẫn được tạo — chờ người dùng
/// xác nhận).
///
/// Thẻ đơn cần xử lý ở đầu màn (spec G94 2026-10-18 mục 5.7; Stitch *"Nâng cấp
/// Premium - Có đơn cần xử lý (khoá Thanh toán)"* `5c629d0af67e4c6fbda1c85de896fa8d`):
/// đơn chờ xác nhận chuyển thừa → thẻ nổi + KHOÁ *Thanh toán* / *Gia hạn* (tránh
/// trả lần hai khi khoản thừa còn chờ dùng); đơn chờ hoàn tiền → thẻ nhỏ, không
/// khoá (người chuyển thiếu vẫn mua lại được). Đọc lịch sử khi mở màn, khi quay
/// về từ màn khác, khi có tín hiệu `payment.*`; đọc hỏng → không thẻ, nút mở
/// (không chặn mua vì mạng — KIEN_TRUC mục 7) — đã đọc được thì giữ kết quả cũ.
/// Lệch Stitch có chủ ý: không chép dòng *"Tự động gia hạn · Hủy bất cứ lúc
/// nào"* (gói không tự gia hạn — lời hứa sai), không đổi thẻ gói hiện tại.
class NangCapPage extends StatefulWidget {
  const NangCapPage(
      {super.key,
      this.tran,
      this.quyen,
      this.repo,
      this.goi,
      this.suKien,
      this.clock});

  /// Loại trần vừa chạm (từ query `?tran=`); `null` = mở từ thẻ Cá nhân / băng khoá.
  final LoaiTran? tran;

  /// Tính năng bị khoá vừa chạm (query `?quyen=`); `tran` khác `null` thì câu trần thắng.
  final MaQuyen? quyen;

  /// `null` → `sl<DonThanhToanRepository>()`; test tiêm bản giả.
  final DonThanhToanRepository? repo;

  /// `null` → `context.watch<GoiCubit>()`.
  final GoiCubit? goi;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;
  final DateTime Function()? clock;

  @override
  State<NangCapPage> createState() => _NangCapPageState();
}

class _NangCapPageState extends State<NangCapPage> {
  bool _dangTao = false;

  /// Lịch sử trang 1 — nguồn của hai thẻ đơn cần xử lý. Rỗng tới khi đọc được.
  List<DongLichSu> _dsDon = const [];
  StreamSubscription<RealtimeEvent>? _subSuKien;

  DonThanhToanRepository get _repo => widget.repo ?? sl<DonThanhToanRepository>();
  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _subSuKien = (widget.suKien ?? sl<RealtimeChannel>().events).listen((e) {
      if (e == RealtimeEvent.donThanhToanDoi) unawaited(_napDon());
    });
    unawaited(_napDon());
  }

  @override
  void dispose() {
    unawaited(_subSuKien?.cancel());
    super.dispose();
  }

  Future<void> _napDon() async {
    try {
      final ds = await _repo.lichSu();
      if (mounted) setState(() => _dsDon = ds);
    } catch (_) {
      // Không chặn mua vì mạng: chưa đọc được thì không thẻ, nút mở; đã đọc được thì giữ kết quả cũ.
    }
  }

  /// Mở một màn rồi đọc lại đơn khi quay về — người dùng vừa xác nhận / từ chối / trả ở đó.
  Future<void> _moRoiNapLai(String duong, {Object? extra}) async {
    await context.push(duong, extra: extra);
    if (mounted) unawaited(_napDon());
  }

  /// Tạo đơn rồi sang màn Đang chờ. Nút khoá trong lúc chờ: bấm đôi là hai đơn
  /// (spec 9.2). Hỏng → SnackBar câu ngắn, ở lại màn.
  Future<void> _thanhToan() async {
    if (_dangTao) return;
    setState(() => _dangTao = true);
    try {
      final don = await _repo.taoDon();
      if (!mounted) return;
      await _moRoiNapLai('/premium/cho-thanh-toan', extra: don);
    } catch (e) {
      if (!mounted) return;
      baoNhanh(cauLoiThanhToan(loaiLoiCua(e)), loai: LoaiThongBao.loi);
    } finally {
      if (mounted) setState(() => _dangTao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goi = widget.goi?.state ?? context.watch<GoiCubit>().state;
    final now = _now();
    final premium = goi.laPremium(now);
    final choXacNhan = donChoXacNhan(_dsDon);
    final choHoan = donChoHoanTien(_dsDon);
    final khoa = choXacNhan.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Nâng cấp Premium',
          style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (choXacNhan.isNotEmpty) ...[
                _theChoXacNhan(choXacNhan),
                const SizedBox(height: 12),
              ],
              if (choHoan.isNotEmpty) ...[
                _theChoHoanTien(choHoan),
                const SizedBox(height: 12),
              ],
              premium ? _theGoiPremium(goi, now) : _theGoiBasic(),
              if (!premium && widget.tran != null) ...[
                const SizedBox(height: 12),
                _dongTran(cauMoDau(widget.tran!, goi.tran)),
              ] else if (!premium && widget.quyen != null) ...[
                const SizedBox(height: 12),
                _dongTran(cauMoDauQuyen(widget.quyen!),
                    key: const Key('nang-cap-cau-quyen')),
              ],
              const SizedBox(height: 24),
              const Text(
                'ĐẶC QUYỀN PREMIUM',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _theDacQuyen(goi),
              const SizedBox(height: 24),
              Text(
                '${CurrencyFormatter.format(goi.gia.toDouble())} / ${goi.soNgayGoi} ngày',
                key: const Key('nang-cap-gia'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('nang-cap-thanh-toan'),
                onPressed: _dangTao || khoa ? null : _thanhToan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.outlineVariant,
                  disabledForegroundColor: AppColors.textSecondary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _dangTao
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(premium
                        ? 'Gia hạn thêm ${goi.soNgayGoi} ngày'
                        : 'Thanh toán'),
              ),
              if (khoa) ...[
                const SizedBox(height: 8),
                const Row(
                  key: Key('nang-cap-ly-do-khoa'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('Xác nhận đơn chuyển thừa trước khi tạo đơn mới',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                key: const Key('nang-cap-lich-su'),
                onPressed: () => unawaited(_moRoiNapLai('/premium/lich-su')),
                child: const Text('Lịch sử mua'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _the({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: child,
      );

  Widget _theGoiBasic() => _the(
        child: const Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                color: AppColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gói hiện tại: Basic',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );

  Widget _theGoiPremium(TrangThaiGoi goi, DateTime now) {
    final hetHan = goi.hetHan;
    final conLai = goi.soNgayConLai(now);
    // Chưa biết hạn (type của phiên, `/payment/*` chưa trả) → chỉ "Premium".
    final dongHan = hetHan == null || conLai == null
        ? null
        : 'còn $conLai ngày (đến ${DateFormat('dd/MM/yyyy').format(hetHan.toLocal())})';
    return _the(
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                if (dongHan != null)
                  Text(
                    dongHan,
                    key: const Key('nang-cap-han'),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dongTran(String cau, {Key key = const Key('nang-cap-cau-tran')}) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cau,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  /// Một đơn → Chi tiết đơn; nhiều đơn → Lịch sử mua (người dùng chọn đơn ở đó).
  void _moDonCanXuLy(List<DongLichSu> ds) => unawaited(_moRoiNapLai(
      ds.length == 1 ? '/premium/don/${ds.first.orderCode}' : '/premium/lich-su'));

  /// Thẻ nổi: viền trái 4 px cam (Stitch `5c629d0a…`). Viền không đều không đi được
  /// cùng `borderRadius` của `BoxDecoration` (assertion) → thanh màu là một ô con
  /// trong `Material` bo góc, `IntrinsicHeight` cho nó cao bằng nội dung.
  Widget _theChoXacNhan(List<DongLichSu> ds) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('nang-cap-the-cho-xac-nhan'),
          onTap: () => _moDonCanXuLy(ds),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: AppColors.warning),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_active,
                              size: 22, color: AppColors.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ds.length == 1
                                    ? 'Bạn đã chuyển thừa cho đơn #${ds.first.orderCode}'
                                    : 'Bạn có ${ds.length} đơn chuyển thừa chờ xác nhận',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Xác nhận để kích hoạt gói hoặc yêu cầu hoàn tiền',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _theChoHoanTien(List<DongLichSu> ds) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('nang-cap-the-cho-hoan-tien'),
          onTap: () => _moDonCanXuLy(ds),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.currency_exchange,
                      size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ds.length == 1
                        ? 'Đơn #${ds.first.orderCode} đang chờ hoàn tiền'
                        : '${ds.length} đơn đang chờ hoàn tiền',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );

  /// Đặc quyền theo bảng của server (`dacQuyenPremium`, 2026-10-08) — thôi danh sách cố định 4 dòng của 06/10. Cố ý
  /// KHÔNG có "đồng bộ đa thiết bị tức thì": đồng bộ không tách theo gói (spec Premium câu 4).
  Widget _theDacQuyen(TrangThaiGoi goi) => _the(
        child: Column(
          children: [
            for (final d in dacQuyenPremium(goi))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 20, color: AppColors.income),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
