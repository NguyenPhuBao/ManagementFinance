/// Bảng chi / thu theo danh mục và khối ngân sách kỳ này trên tờ báo cáo ở trang Xem trước báo cáo
/// (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../category/presentation/widgets/category_visuals.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class BangDanhMucBaoCao extends StatelessWidget {
  const BangDanhMucBaoCao(this.tieuDe, this.ds, {super.key});

  final String tieuDe;
  final List<DongDanhMucBaoCao> ds;

  @override
  Widget build(BuildContext context) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: NhanMucBaoCao(tieuDe)),
                Text(
                  '${ds.length} danh mục',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final d in ds) _dongDanhMuc(d),
          ],
        ),
      );

  Widget _dongDanhMuc(DongDanhMucBaoCao d) {
    final mau = d.categoryId == null
        ? AppColors.textSecondary
        : categoryColorFrom(d.mauHex, fallback: AppColors.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIconFor(d.icon), size: 18, color: mau),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Text(
                        CurrencyFormatter.format(d.soTien),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phanTramBaoCao(d.tiLe),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: d.tiLe.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(mau),
            ),
          ),
        ],
      ),
    );
  }
}

class KhoiNganSachBaoCao extends StatelessWidget {
  const KhoiNganSachBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  @override
  Widget build(BuildContext context) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('NGÂN SÁCH KỲ NÀY'),
            const SizedBox(height: 14),
            for (final n in baoCao.nganSach)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.ten,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${CurrencyFormatter.format(n.daChi)} / '
                              '${CurrencyFormatter.format(n.hanMuc)}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: n.tiLe.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerLow,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          n.vuot ? AppColors.expense : AppColors.income,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        n.vuot
                            ? 'Vượt ${CurrencyFormatter.format(-n.conLai)}'
                            : 'Còn ${CurrencyFormatter.format(n.conLai)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: n.vuot ? AppColors.expense : AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
