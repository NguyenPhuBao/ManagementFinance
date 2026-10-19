import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_formatter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/dong_lich_su.dart';
import '../../data/repositories/don_thanh_toan_repository.dart';
import '../../domain/cau_loi_thanh_toan.dart';
import '../widgets/nhan_trang_thai_don.dart';

/// Màn Lịch sử mua `/premium/lich-su` (spec Premium 9.4; spec G94 2026-10-18 mục 5.6) — trang 1 (20 dòng, không phân
/// trang vô hạn). Màn Stitch *"Lịch sử mua Premium - Dòng bấm được (có Chờ xác nhận)"* `04c4aa7dda504cc4922290ea79ef3e63`
/// (thay `e7d6609536224c4fbd2e2a94f4623e36`; dòng chân *"Giao dịch thanh toán bảo mật FlowMoney"* của Stitch là trang
/// trí — không chép, lệch có chủ ý).
///
/// MỌI dòng bấm được → Chi tiết đơn `/premium/don/:orderCode` — lối xác nhận chuyển thừa khi người dùng đã rời màn Chờ
/// (người dùng chốt 2026-10-18). Quay về thì nạp lại; tín hiệu `payment.*` cũng nạp lại.
class LichSuMuaPage extends StatefulWidget {
  const LichSuMuaPage({super.key, this.repo, this.suKien});

  /// `null` → `sl<DonThanhToanRepository>()`.
  final DonThanhToanRepository? repo;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;

  @override
  State<LichSuMuaPage> createState() => _LichSuMuaPageState();
}

class _LichSuMuaPageState extends State<LichSuMuaPage> {
  List<DongLichSu>? _dong;
  String? _loi;
  bool _dangNap = true;
  StreamSubscription<RealtimeEvent>? _subSuKien;

  DonThanhToanRepository get _repo => widget.repo ?? sl<DonThanhToanRepository>();

  @override
  void initState() {
    super.initState();
    _subSuKien = (widget.suKien ?? sl<RealtimeChannel>().events).listen((e) {
      if (e == RealtimeEvent.donThanhToanDoi) unawaited(_nap());
    });
    unawaited(_nap());
  }

  @override
  void dispose() {
    unawaited(_subSuKien?.cancel());
    super.dispose();
  }

  /// Đã có danh sách thì nạp lại NGẦM — giữ dòng trên màn, không chớp vòng xoay mỗi lần quay về / có tín hiệu.
  Future<void> _nap() async {
    setState(() {
      _dangNap = _dong == null;
      _loi = null;
    });
    try {
      final ds = await _repo.lichSu();
      if (!mounted) return;
      setState(() {
        _dong = ds;
        _dangNap = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = cauLoiThanhToan(loaiLoiCua(e), cauTuChoi: 'Không tải được lịch sử mua. Thử lại sau.');
        _dangNap = false;
      });
    }
  }

  Future<void> _moDon(int ma) async {
    await context.push('/premium/don/$ma');
    if (mounted) unawaited(_nap());
  }

  @override
  Widget build(BuildContext context) {
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
          'Lịch sử mua',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(child: _than()),
    );
  }

  Widget _than() {
    if (_dangNap) return const Center(child: CircularProgressIndicator());
    final loi = _loi;
    if (loi != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loi,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(onPressed: _nap, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final dong = _dong ?? const [];
    if (dong.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.outlineVariant),
            SizedBox(height: 12),
            Text('Chưa có lượt mua nào', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    // `Material` bọc danh sách: InkWell trong Container có màu mà không có
    // Material riêng là assertion "ink splashes may be invisible" (Flutter 3.47).
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dong.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _dongWidget(dong[i]),
      ),
    );
  }

  Widget _dongWidget(DongLichSu d) {
    final luc = d.luc;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('lich-su-dong-${d.orderCode}'),
        onTap: () => unawaited(_moDon(d.orderCode)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium, size: 22, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gói Premium 30 ngày',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(
                      luc == null ? 'Mã đơn #${d.orderCode}' : DateFormatter.formatDate(luc.toLocal()),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(d.soTien.toDouble()),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  NhanTrangThaiDon(d.trangThai),
                ],
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
