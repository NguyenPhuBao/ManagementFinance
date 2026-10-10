/// Khối "khoi_top_chi" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'chung.dart';

/// Năm khoản chi lớn nhất của kỳ.
class KhoiTopChi extends StatelessWidget {
  final List<DongGiaoDich> ds;
  const KhoiTopChi({super.key, required this.ds});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: theTrang(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tieuDeKhoi('Top 5 khoản chi'),
            for (var i = 0; i < ds.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ds[i].tieuDe,
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
                            '${ds[i].tenDanhMuc} · '
                            '${DateFormatter.formatDate(ds[i].ngay)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        child: Text(
                          CurrencyFormatter.formatCoDau(-ds[i].soTien,
                              thu: false),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
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

// ── Hai biểu đồ vay/nợ — A8 #4 và #5 (2026-09-15) ─────────────────────────
//
// Mỗi kỳ một **cặp cột chồng nhau**: cột sau rộng và mờ, cột trước hẹp và đậm
// vẽ đè lên chính giữa. Người dùng chốt hình dạng này ngày 2026-09-15.
//
// ⚠️ **Màu theo CHIỀU TIỀN, không theo vị trí**: xanh luôn là tiền vào, đỏ luôn
// là tiền ra — cùng quy ước với mọi chỗ khác trong app. Nên khối "Cho vay & Thu
// nợ" có cột sau đỏ, còn khối "Đi vay & Trả nợ" có cột sau XANH. Đảo lại cho
// "hai khối trông giống nhau" là dạy người đọc một quy ước thứ hai.
