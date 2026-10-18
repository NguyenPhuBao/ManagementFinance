import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Thẻ kết quả căn giữa của màn Chi tiết đơn (Stitch `d3b59018…` *Đã hoàn …* / *Đã kích hoạt Premium*): vòng biểu tượng
/// tô [mau], dòng chính, dòng phụ tuỳ chọn.
class TheKetQuaDon extends StatelessWidget {
  const TheKetQuaDon({
    super.key,
    required this.bieuTuong,
    required this.mau,
    required this.tieuDe,
    this.phu,
  });

  final IconData bieuTuong;
  final Color mau;
  final String tieuDe;
  final String? phu;

  @override
  Widget build(BuildContext context) {
    final phu = this.phu;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: mau.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(bieuTuong, size: 30, color: mau),
          ),
          const SizedBox(height: 12),
          // Một dòng, co lại khi dài (số tiền 13 chữ số ở 320 dp) — không ngắt dòng im lặng.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tieuDe,
                maxLines: 1,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          if (phu != null) ...[
            const SizedBox(height: 4),
            Text(phu,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
