/// Đầu tờ báo cáo ở trang Xem trước báo cáo (`report_preview_page.dart`): tiêu đề, ngày lập, khoảng ngày và hai chip bộ lọc
/// ví / danh mục.
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class DauBaoCao extends StatelessWidget {
  const DauBaoCao({
    super.key,
    required this.baoCao,
    required this.nhanVi,
    required this.nhanDanhMuc,
    required this.lapNgay,
  });

  final BaoCao baoCao;
  final String nhanVi;
  final String nhanDanhMuc;
  final DateTime lapNgay;

  @override
  Widget build(BuildContext context) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                    child: NhanMucBaoCao('BÁO CÁO TỔNG QUAN THU CHI')),
                const SizedBox(width: 8),
                Text(
                  'Lập ngày ${DateFormatter.formatDate(lapNgay)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Biên `to` MỞ: ngày cuối cùng NẰM TRONG báo cáo là `to - 1 ngày`.
            // Hiện thẳng `to` là tờ báo cáo tự nhận có dữ liệu của một ngày mà
            // nó không hề đếm.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${DateFormatter.formatDate(baoCao.from)} – '
                '${DateFormatter.formatDate(baoCao.to.subtract(const Duration(days: 1)))}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipBaoCao(Icons.account_balance_wallet_outlined, nhanVi),
                _ChipBaoCao(Icons.category_outlined, nhanDanhMuc),
              ],
            ),
          ],
        ),
      );
}

class _ChipBaoCao extends StatelessWidget {
  const _ChipBaoCao(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3F46),
              ),
            ),
          ],
        ),
      );
}
