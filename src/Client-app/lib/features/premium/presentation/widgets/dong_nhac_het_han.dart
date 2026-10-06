import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/nhac_het_han.dart';
import '../../domain/trang_thai_goi.dart';
import '../an_nhac_het_han.dart';
import '../cubit/goi_cubit.dart';

/// Dòng nhắc "Premium còn N ngày" ở Trang chủ (spec Premium 2026-10-06 mục 9.5)
/// — khuôn `DongNhacViTrungTen`: khoảng 24 phía trên nằm TRONG widget, không có
/// gì để nhắc thì không dựng gì. ✕ ẩn tới hết ngày ([AnNhacHetHan]). Backend
/// chỉ phát `payment.expiring_soon` lên EventBus nên con số tính từ hạn cache.
/// Màn Stitch *"Trang chủ - Dòng nhắc Premium sắp hết hạn - FlowMoney"*
/// `f21e76fa25b14515bbda35def51b9313` (chờ người dùng xác nhận).
class DongNhacHetHan extends StatelessWidget {
  const DongNhacHetHan({
    super.key,
    required this.idaccount,
    this.an,
    this.clock,
    this.onGiaHan,
  });

  final int idaccount;

  /// `null` → `sl` nếu đã đăng ký; chưa đăng ký (test cũ của Trang chủ) thì
  /// không dựng gì.
  final AnNhacHetHan? an;
  final DateTime Function()? clock;

  /// Mặc định `context.push('/premium')`.
  final VoidCallback? onGiaHan;

  AnNhacHetHan? get _an =>
      an ?? (sl.isRegistered<AnNhacHetHan>() ? sl<AnNhacHetHan>() : null);

  @override
  Widget build(BuildContext context) {
    final an = _an;
    if (an == null) return const SizedBox.shrink();
    final TrangThaiGoi goi;
    try {
      goi = context.watch<GoiCubit>().state;
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final now = (clock ?? DateTime.now)();
    final n = canNhacHetHan(goi, now);
    if (n == null) return const SizedBox.shrink();

    return ValueListenableBuilder<({int idaccount, DateTime ngay})?>(
      valueListenable: an,
      builder: (context, _, __) {
        if (an.daAn(idaccount, now)) return const SizedBox.shrink();
        final cau = n == 0 ? 'Premium hết hạn hôm nay' : 'Premium còn $n ngày';
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Material(
            key: const ValueKey('dong-nhac-het-han'),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, size: 20, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cau,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: onGiaHan ?? () => context.push('/premium'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Gia hạn'),
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.only(left: 4),
                      color: AppColors.outlineVariant,
                    ),
                    IconButton(
                      tooltip: 'Ẩn lời nhắc',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                      onPressed: () => an.an(idaccount, now),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
