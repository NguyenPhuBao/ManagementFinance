import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/payment_api.dart';
import '../../domain/cau_loi_thanh_toan.dart';
import '../../domain/don_thanh_toan.dart';
import '../../domain/dong_lich_su.dart';

/// Màn Lịch sử mua `/premium/lich-su` (spec Premium 9.4) — chỉ đọc, trang 1
/// (20 dòng, không phân trang vô hạn). Màn Stitch *"Lịch sử mua Premium -
/// FlowMoney"* `e7d6609536224c4fbd2e2a94f4623e36` (chờ người dùng xác nhận).
class LichSuMuaPage extends StatefulWidget {
  const LichSuMuaPage({super.key, this.api});

  /// `null` → `sl<PaymentApi>()`.
  final PaymentApi? api;

  @override
  State<LichSuMuaPage> createState() => _LichSuMuaPageState();
}

class _LichSuMuaPageState extends State<LichSuMuaPage> {
  List<DongLichSu>? _dong;
  String? _loi;
  bool _dangNap = true;

  PaymentApi get _api => widget.api ?? sl<PaymentApi>();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangNap = true;
      _loi = null;
    });
    try {
      final ds = dongLichSuTu(await _api.lichSu());
      if (!mounted) return;
      setState(() {
        _dong = ds;
        _dangNap = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = cauLoiThanhToan(e);
        _dangNap = false;
      });
    }
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
          style: TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
            Text('Chưa có lượt mua nào',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    // `Material` bọc danh sách: ListTile trong Container có màu mà không có
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gói Premium 30 ngày',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(
                  luc == null
                      ? 'Mã đơn #${d.orderCode}'
                      : DateFormat('dd/MM/yyyy').format(luc.toLocal()),
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(chuTrangThaiDon(d.trangThai),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: switch (d.trangThai) {
                        TrangThaiDon.paid => AppColors.income,
                        TrangThaiDon.pending => AppColors.warning,
                        TrangThaiDon.cancelled || TrangThaiDon.expired => AppColors.textSecondary,
                      })),
            ],
          ),
        ],
      ),
    );
  }
}
