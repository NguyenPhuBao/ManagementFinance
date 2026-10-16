/// Khối "Phân bổ theo ví" trên tờ báo cáo ở trang Xem trước báo cáo (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class KhoiTheoViBaoCao extends StatelessWidget {
  const KhoiTheoViBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  @override
  Widget build(BuildContext context) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('PHÂN BỔ THEO VÍ'),
            const SizedBox(height: 8),
            for (final v in baoCao.theoVi)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.ten,
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
                            '${v.soGiaoDich} giao dịch',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              coDauBaoCao(v.thu, thu: true),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                            Text(
                              coDauBaoCao(v.chi, thu: false),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
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
