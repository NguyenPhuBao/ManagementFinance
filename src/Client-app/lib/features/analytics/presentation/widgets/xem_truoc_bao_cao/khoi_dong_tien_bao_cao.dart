/// Khối "Dòng tiền trong kỳ" của trang Xem trước báo cáo (`report_preview_page.dart`): số dư đầu / cuối kỳ và mức thay đổi.
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

/// Khối **dòng tiền** — thứ biến tờ báo cáo thành một bản kê thay vì một
/// đống số rời. Money Lover đặt nó ở trung tâm báo cáo của họ.
///
/// Chỉ hiện khi [BaoCao.dongTien] khác `null`, tức khi báo cáo gộp mọi ví.
class KhoiDongTienBaoCao extends StatelessWidget {
  const KhoiDongTienBaoCao(this.dt, {super.key});

  final DongTien dt;

  @override
  Widget build(BuildContext context) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('DÒNG TIỀN TRONG KỲ'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _oSoDu('SỐ DƯ ĐẦU KỲ', dt.dauKy)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: AppColors.textSecondary),
                ),
                Expanded(child: _oSoDu('SỐ DƯ CUỐI KỲ', dt.cuoiKy)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thay đổi trong kỳ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatCoDau(dt.thayDoi,
                            thu: dt.thayDoi >= 0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: dt.thayDoi >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // App không lưu lịch sử số dư nên hai con số này là **suy ra**, và
            // người đọc có quyền biết điều đó: ví tạo giữa kỳ mang theo số dư
            // ban đầu KHÔNG phải là giao dịch, nên nó bị tính vào số dư đầu kỳ.
            const Text(
              'Suy ngược từ số dư hiện tại của các ví',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

Widget _oSoDu(String nhan, double soTien) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nhan,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(soTien),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
