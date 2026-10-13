/// Ba thẻ tổng thu / chi / còn lại và khối "không có giao dịch" của trang Xem trước báo cáo (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class BaTheBaoCao extends StatelessWidget {
  const BaTheBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  // `IntrinsicHeight` cho ba thẻ cao bằng nhau. Không có nó thì
  // `CrossAxisAlignment.stretch` trong `ListView` nhận chiều cao vô hạn và cả
  // trang chết — chiều dọc của ListView không bị chặn.
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _TheTong('TỔNG THU', baoCao.tong.thu, AppColors.income,
                  phanTram: baoCao.thuSoVoiTruoc, tangLaTot: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TheTong('TỔNG CHI', baoCao.tong.chi, AppColors.expense,
                  phanTram: baoCao.chiSoVoiTruoc, tangLaTot: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TheTong(
                  'CÒN LẠI', baoCao.tong.conLai, AppColors.textPrimary),
            ),
          ],
        ),
      );
}

/// [phanTram] là mức đổi so với **kỳ liền trước**; `null` khi kỳ trước bằng 0
/// — khi ấy hiện dấu gạch chứ không hiện "100%" (một con số bịa, và người
/// đọc sẽ tưởng kỳ trước có một nửa).
///
/// [tangLaTot] quyết định màu chứ không quyết định mũi tên: thu tăng là tin
/// tốt, chi tăng thì không.
class _TheTong extends StatelessWidget {
  const _TheTong(
    this.nhan,
    this.soTien,
    this.mau, {
    this.phanTram,
    this.tangLaTot = true,
  });

  final String nhan;
  final double soTien;
  final Color mau;
  final double? phanTram;
  final bool tangLaTot;

  @override
  Widget build(BuildContext context) {
    // Trường `final` không tự thăng kiểu sau phép kiểm null trong thân dời nguyên văn.
    final phanTram = this.phanTram;
    return TheBaoCao(
      padding: const EdgeInsets.all(12),
      child: Column(
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
          const SizedBox(height: 6),
          // Số hàng trăm triệu không vừa một phần ba màn 411dp — co lại chứ
          // đừng để tràn.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(soTien),
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              phanTram == null
                  ? '—'
                  : '${phanTram >= 0 ? '▲' : '▼'} '
                      '${phanTram.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: phanTram == null
                    ? AppColors.textSecondary
                    : ((phanTram >= 0) == tangLaTot
                        ? AppColors.income
                        : AppColors.expense),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KhiRongBaoCao extends StatelessWidget {
  const KhiRongBaoCao({super.key});

  @override
  Widget build(BuildContext context) => const TheBaoCao(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Không có giao dịch nào trong khoảng đã chọn',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
