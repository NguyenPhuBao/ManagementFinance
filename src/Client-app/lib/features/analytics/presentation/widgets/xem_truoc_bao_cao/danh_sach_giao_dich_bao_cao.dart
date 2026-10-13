/// Khối "Danh sách giao dịch" (nhóm theo ngày) trên tờ báo cáo ở trang Xem trước báo cáo (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../category/presentation/widgets/category_visuals.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class DanhSachGiaoDichBaoCao extends StatelessWidget {
  const DanhSachGiaoDichBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  /// Khoá để test tìm **trong phạm vi khối này**: cùng một ngày hay cùng một
  /// số tiền nay còn xuất hiện ở "Số liệu nhanh", "Top 5 khoản chi" và "Phân bổ
  /// theo ví", nên `find.text` toàn trang không còn phân biệt được khối nào.
  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: const Key('khoiGiaoDich'),
        child: TheBaoCao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: NhanMucBaoCao('DANH SÁCH GIAO DỊCH')),
                  Text(
                    '${baoCao.soGiaoDich} giao dịch',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              for (final n in baoCao.nhom) ...[
                const SizedBox(height: 16),
                Text(
                  DateFormatter.formatDate(n.ngay),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                for (final d in n.dong) _dongGiaoDich(d),
              ],
            ],
          ),
        ),
      );

  Widget _dongGiaoDich(DongGiaoDich d) {
    final laThu = d.loai == 'thu';
    final mau = d.categoryId == null
        ? AppColors.textSecondary
        : categoryColorFrom(d.mauHex, fallback: AppColors.outline);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIconFor(d.icon), size: 18, color: mau),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.tieuDe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d.tenVi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.formatCoDau(d.soTien, thu: laThu),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: laThu ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
