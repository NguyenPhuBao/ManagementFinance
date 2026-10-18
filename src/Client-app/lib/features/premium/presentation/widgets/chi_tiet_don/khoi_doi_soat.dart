import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';

/// Một dòng tiền của [KhoiDoiSoat]. [mauNoiBat] có thì dòng ấy là dòng kết luận (thừa / thiếu): kẻ ngăn phía trên, chữ
/// đậm tô màu ấy.
class DongTien {
  const DongTien(this.nhan, this.soTien, {this.mauNoiBat});

  final String nhan;
  final int soTien;
  final Color? mauNoiBat;
}

/// Khối đối soát của màn Chi tiết đơn (Stitch `408de0af…` *BẠN ĐÃ CHUYỂN THỪA*, `d3b59018…` *THIẾU* / *ĐÃ CHỌN HOÀN
/// TIỀN*): nhãn hoa cam, các dòng tiền, rồi một câu. [cauLaCauHoi] = câu hỏi người dùng (chữ thường, đậm hơn);
/// không thì là câu giải thích (nhỏ, xám).
class KhoiDoiSoat extends StatelessWidget {
  const KhoiDoiSoat({
    super.key,
    required this.bieuTuong,
    required this.nhan,
    required this.cau,
    this.dong = const [],
    this.cauLaCauHoi = false,
  });

  final IconData bieuTuong;
  final String nhan;
  final List<DongTien> dong;
  final String cau;
  final bool cauLaCauHoi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(bieuTuong, size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Flexible(
                child: Text(nhan,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final d in dong) ...[
            if (d.mauNoiBat != null) const Divider(height: 12, color: AppColors.outlineVariant),
            _dong(d),
            const SizedBox(height: 8),
          ],
          if (dong.isNotEmpty) const Divider(height: 16, color: AppColors.outlineVariant),
          Text(
            cau,
            style: cauLaCauHoi
                ? const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary)
                : const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Số tiền là `Flexible` + `FittedBox`: 13 chữ số (`numeric(15,2)` của server) co lại trên một dòng chứ không đẩy
  /// nhãn hay xuống dòng im lặng (bẫy *ô nhập TIỀN* — `Text` dài ngắt dòng không sọc vàng).
  Widget _dong(DongTien d) {
    final mau = d.mauNoiBat;
    return Row(
      children: [
        Text(d.nhan,
            style: mau == null
                ? const TextStyle(fontSize: 14, color: AppColors.textSecondary)
                : TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: mau)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.format(d.soTien.toDouble()),
                maxLines: 1,
                style: mau == null
                    ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)
                    : TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: mau),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
