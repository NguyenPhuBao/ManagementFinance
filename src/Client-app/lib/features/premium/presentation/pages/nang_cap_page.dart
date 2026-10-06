import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/payment_api.dart';
import '../../domain/cau_loi_thanh_toan.dart';
import '../../domain/don_thanh_toan.dart';
import '../../domain/tran_goi.dart';
import '../../domain/trang_thai_goi.dart';
import '../cubit/goi_cubit.dart';

/// Bốn đặc quyền người dùng chốt (spec Premium 2026-10-06 câu 1–4b). Cố ý KHÔNG
/// có "đồng bộ đa thiết bị tức thì": đồng bộ không tách theo gói (câu 4), không
/// hứa thứ không khác.
const List<String> kDacQuyen = [
  'Không giới hạn ví',
  'Không giới hạn ngân sách',
  'Không giới hạn mục tiêu tiết kiệm',
  'Trợ lý AI & Nhập nhanh bằng AI',
];

/// Câu mở đầu khi đến từ cửa chặn (`/premium?tran=`): *"Bạn đã dùng 3/3 ví của
/// gói Basic."* — số lấy từ trần đang có hiệu lực, không ghi cứng.
String cauMoDau(LoaiTran tran, TranGoi tranGoi) {
  final n = tranGoi.cua(tran);
  return 'Bạn đã dùng $n/$n ${tenTran(tran)} của gói Basic.';
}

/// Màn Nâng cấp `/premium` — ngoài shell, `push` từ mọi nơi (spec 9.1). Màn
/// Stitch *"Nâng cấp Premium - FlowMoney"* `c999da970da94cb4ab4331fc44230884`
/// (lượt gọi 2026-10-06 trả `timeout` nhưng màn vẫn được tạo — chờ người dùng
/// xác nhận).
class NangCapPage extends StatefulWidget {
  const NangCapPage({super.key, this.tran, this.api, this.goi, this.clock});

  /// Loại trần vừa chạm (từ query `?tran=`); `null` = mở từ thẻ Cá nhân / băng khoá.
  final LoaiTran? tran;

  /// `null` → `sl<PaymentApi>()`; test tiêm bản giả.
  final PaymentApi? api;

  /// `null` → `context.watch<GoiCubit>()`.
  final GoiCubit? goi;
  final DateTime Function()? clock;

  @override
  State<NangCapPage> createState() => _NangCapPageState();
}

class _NangCapPageState extends State<NangCapPage> {
  bool _dangTao = false;

  PaymentApi get _api => widget.api ?? sl<PaymentApi>();
  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// Tạo đơn rồi sang màn Đang chờ. Nút khoá trong lúc chờ: bấm đôi là hai đơn
  /// (spec 9.2). Hỏng → SnackBar câu ngắn, ở lại màn.
  Future<void> _thanhToan() async {
    if (_dangTao) return;
    setState(() => _dangTao = true);
    try {
      final don = donTuJson(await _api.taoDon(), now: _now());
      if (don == null) throw StateError('đơn thiếu orderCode / checkoutUrl');
      if (!mounted) return;
      await context.push('/premium/cho-thanh-toan', extra: don);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cauLoiThanhToan(e))),
      );
    } finally {
      if (mounted) setState(() => _dangTao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goi = widget.goi?.state ?? context.watch<GoiCubit>().state;
    final now = _now();
    final premium = goi.laPremium(now);
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
              premium ? _theGoiPremium(goi, now) : _theGoiBasic(),
              if (!premium && widget.tran != null) ...[
                const SizedBox(height: 12),
                _dongTran(cauMoDau(widget.tran!, goi.tran)),
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
              _theDacQuyen(),
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
                onPressed: _dangTao ? null : _thanhToan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
              const SizedBox(height: 12),
              TextButton(
                key: const Key('nang-cap-lich-su'),
                onPressed: () => context.push('/premium/lich-su'),
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

  Widget _dongTran(String cau) => Container(
        key: const Key('nang-cap-cau-tran'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFFE65100)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cau,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF5D4037))),
            ),
          ],
        ),
      );

  Widget _theDacQuyen() => _the(
        child: Column(
          children: [
            for (final d in kDacQuyen)
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
