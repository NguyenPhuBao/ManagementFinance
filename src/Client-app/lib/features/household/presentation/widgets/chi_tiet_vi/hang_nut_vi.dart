import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Một nút tròn của hàng thao tác ở Chi tiết ví chung (Stitch `ac57e216…` 3.3). [khoa] là `Key` của nút (test và Task 8 tìm theo nó).
class NutVi {
  const NutVi({required this.khoa, required this.nhan, required this.icon, required this.onCham});

  final String khoa;
  final String nhan;
  final IconData icon;
  final VoidCallback onCham;
}

/// Hàng nút tròn: chia đều bề rộng theo SỐ nút (3–5 cột), nên Task 8 chèn *Góp · Rút* chỉ cần thêm phần tử vào [nut]. Danh sách
/// rỗng thì không dựng gì (Chỉ xem, ví lưu trữ).
class HangNutVi extends StatelessWidget {
  const HangNutVi({super.key, required this.nut});

  final List<NutVi> nut;

  @override
  Widget build(BuildContext context) {
    if (nut.isEmpty) return const SizedBox.shrink();
    final chu = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final n in nut)
          Expanded(
            child: InkWell(
              key: Key(n.khoa),
              borderRadius: BorderRadius.circular(12),
              onTap: n.onCham,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Icon(n.icon, size: 22, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(n.nhan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chu.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
