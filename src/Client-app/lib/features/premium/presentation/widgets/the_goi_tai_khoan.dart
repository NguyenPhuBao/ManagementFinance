import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/tran_goi.dart';
import '../../domain/trang_thai_goi.dart';
import '../cubit/goi_cubit.dart';
import 'nut_nang_cap.dart';

/// Thẻ "Gói của bạn" ngay dưới đầu tab Cá nhân — điểm vào có chủ ý DUY NHẤT của
/// `/premium` (spec Premium 2026-10-06 mục 10; drawer không thêm mục). Màn
/// Stitch *"Cá nhân - Thẻ gói Premium - FlowMoney"*
/// `6798f5bed0344ca0a854247db40703c7` (chờ người dùng xác nhận).
///
/// Không có `GoiCubit` trong cây (test cũ của trang Cá nhân) → không dựng gì.
class TheGoiTaiKhoan extends StatelessWidget {
  const TheGoiTaiKhoan({super.key, this.clock, this.onMo});

  final DateTime Function()? clock;

  /// Khe tiêm cho test. `null` → nút tự `push('/premium')`.
  final VoidCallback? onMo;

  @override
  Widget build(BuildContext context) {
    final TrangThaiGoi goi;
    try {
      goi = context.watch<GoiCubit>().state;
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final now = (clock ?? DateTime.now)();
    final premium = goi.laPremium(now);
    final hetHan = goi.hetHan;
    final conLai = goi.soNgayConLai(now);
    final dongPhu = premium
        ? (hetHan == null || conLai == null
            ? null
            : 'Còn $conLai ngày · đến ${DateFormat('dd/MM/yyyy').format(hetHan.toLocal())}')
        : tomTatTran(goi.tran);

    return Container(
      key: const Key('the-goi-tai-khoan'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      // Khối chữ `Expanded` để dòng hạn dài xuống dòng thay vì tràn ở 360 dp
      // (bản `Wrap` đầu tràn 47 px: con của Wrap không có biên ngang).
      child: Row(
        children: [
          Icon(
            premium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
            color: premium ? AppColors.warning : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium ? 'Premium' : 'Gói Basic',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                if (dongPhu != null)
                  Text(dongPhu,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NutNangCap(nhan: premium ? 'Gia hạn' : 'Nâng cấp', onMo: onMo),
        ],
      ),
    );
  }
}
