import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Màu ô biểu tượng của hàng form Góp / Rút (Stitch `f77f5bc0…` 5.3, `c39ac4f7…` 10.3): hai cặp không trùng token nào của
/// `AppColors`. Các hàng trung tính (ngày, ghi chú, công tắc) dùng token.
typedef MauODong = ({Color nen, Color chu});

/// Một hàng của thẻ form: ô biểu tượng 36 × 36, nhãn nhỏ trên, giá trị dưới, [chevron] khi chạm được để đổi.
class DongFormGopRut extends StatelessWidget {
  const DongFormGopRut({
    super.key,
    required this.icon,
    required this.nhan,
    required this.giaTri,
    this.mau,
    this.onCham,
    this.chevron = false,
    this.cuoi,
    this.nen,
  });

  final IconData icon;
  final String nhan;
  final Widget giaTri;

  /// `null` → ô trung tính.
  final MauODong? mau;
  final VoidCallback? onCham;
  final bool chevron;

  /// Phần tử cuối hàng thay cho chevron (công tắc).
  final Widget? cuoi;

  /// Nền cả hàng (hàng công tắc nhạt hơn thẻ).
  final Color? nen;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final m = mau ?? (nen: AppColors.surfaceContainerLow, chu: AppColors.textSecondary);
    return Material(
      color: nen ?? Colors.transparent,
      child: InkWell(
        onTap: onCham,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: m.nen, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: m.chu),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nhan, style: chu.labelSmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    giaTri,
                  ],
                ),
              ),
              if (cuoi != null)
                cuoi!
              else if (chevron)
                const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giá trị một ví: tên đậm, số dư nhạt sau dấu chấm giữa (`Ví MB · 5.420.000 đ`). [soDu] `null` thì chỉ tên.
class GiaTriVi extends StatelessWidget {
  const GiaTriVi({super.key, required this.ten, this.soDu});

  final String ten;
  final String? soDu;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme.bodyMedium;
    return Text.rich(
      TextSpan(
        text: ten,
        style: chu?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        children: [
          if (soDu != null)
            TextSpan(text: ' · $soDu', style: chu?.copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
