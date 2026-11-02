import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../khung_the_nha.dart';

/// Thẻ lối vào của Nhà mình (Stitch `d2a8c9bb…` 1.4): mỗi dòng một màn con. Dòng nào [onXxx] `null` thì không dựng — màn đích
/// chưa có route thì không có dòng trỏ vào nó (Danh mục của nhà do Task 11 bật).
class TheLoiVaoNha extends StatelessWidget {
  const TheLoiVaoNha({super.key, this.onHoatDong, this.onDanhMuc});

  final VoidCallback? onHoatDong;
  final VoidCallback? onDanhMuc;

  @override
  Widget build(BuildContext context) {
    final dong = <Widget>[
      if (onHoatDong != null)
        _Dong(
            khoa: 'loi-vao-hoat-dong',
            icon: Icons.schedule,
            tieuDe: 'Hoạt động',
            phu: 'Mọi khoản của nhà',
            onCham: onHoatDong!),
      if (onDanhMuc != null)
        _Dong(khoa: 'loi-vao-danh-muc', icon: Icons.category_outlined, tieuDe: 'Danh mục của nhà', onCham: onDanhMuc!),
    ];
    if (dong.isEmpty) return const SizedBox.shrink();
    return KhungTheNha(
      child: Column(
        children: [
          for (var i = 0; i < dong.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
            dong[i],
          ],
        ],
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.khoa, required this.icon, required this.tieuDe, required this.onCham, this.phu});

  final String khoa;
  final IconData icon;
  final String tieuDe;
  final String? phu;
  final VoidCallback onCham;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return InkWell(
      key: Key(khoa),
      onTap: onCham,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  if (phu != null)
                    Text(phu!, style: chu.labelSmall?.copyWith(color: const Color(0xFF454743))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
