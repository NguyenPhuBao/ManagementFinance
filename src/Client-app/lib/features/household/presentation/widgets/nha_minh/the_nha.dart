import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import '../khung_the_nha.dart';

class TheNha extends StatelessWidget {
  const TheNha({super.key, required this.trangThai});

  final NhaCuaToi trangThai;

  @override
  Widget build(BuildContext context) {
    final n = trangThai.nha!;
    final chu = Theme.of(context).textTheme;
    final vai = trangThai.vai == null ? '' : 'Bạn là ${tenVai(trangThai.vai!)} · ';
    return KhungTheNha(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.home_outlined, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.ten, style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$vai${trangThai.thanhVien.length}/${n.toiDaThanhVien} thành viên',
                    style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chấm trạng thái bên phải thẻ (Stitch `56739d19…`): xanh khi nhà dùng được, vàng khi chỉ xem.
          Container(
            key: const Key('cham-trang-thai-nha'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: n.trangThai == TrangThaiNha.chiXem ? AppColors.warning : AppColors.income,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải vàng khi nhà `ReadOnly` (spec 5.6). Câu là câu của `cauLoiNha(nhaChiXem)` bỏ dấu chấm cuối: giữ đúng chữ Stitch.
class DaiNhaChiXem extends StatelessWidget {
  const DaiNhaChiXem({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.khoaCanNen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.khoaCanVien),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.khoaCanIcon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhà đang ở chế độ chỉ xem — chủ nhà cần gia hạn Premium',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.khoaCanChu),
              ),
            ),
          ],
        ),
      );
}
