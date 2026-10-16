/// Khối "Số liệu nhanh" (chi mỗi ngày, số giao dịch, ngày chi nhiều nhất, khoản chi lớn nhất) trên tờ báo cáo ở trang Xem
/// trước báo cáo (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

class KhoiSoLieuNhanhBaoCao extends StatelessWidget {
  const KhoiSoLieuNhanhBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  @override
  Widget build(BuildContext context) {
    final s = baoCao.soLieu;
    return TheBaoCao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NhanMucBaoCao('SỐ LIỆU NHANH'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _oSoLieu(
                    'CHI MỖI NGÀY', CurrencyFormatter.format(s.chiMoiNgay)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _oSoLieu('SỐ GIAO DỊCH', '${baoCao.soGiaoDich}'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _oSoLieu(
                  'NGÀY CHI NHIỀU NHẤT',
                  s.ngayChiNhieuNhat == null
                      ? '—'
                      : DateFormatter.formatDate(s.ngayChiNhieuNhat!),
                  phu: s.ngayChiNhieuNhat == null
                      ? null
                      : CurrencyFormatter.format(s.chiNgayNhieuNhat),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _oSoLieu(
                  'KHOẢN CHI LỚN NHẤT',
                  s.khoanChiLonNhat?.tieuDe ?? '—',
                  chu: true,
                  phu: s.khoanChiLonNhat == null
                      ? null
                      : CurrencyFormatter.format(s.khoanChiLonNhat!.soTien),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _oSoLieu(String nhan, String giaTri,
          {String? phu, bool chu = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Ô mang CHỮ (tiêu đề giao dịch) thì xuống dòng: co một dòng dài ~80 ký tự cho vừa là chữ tí hon không đọc
          // được (ảnh người dùng gửi 2026-10-05). Ô mang SỐ thì giữ một dòng, co lại khi chật.
          if (chu)
            Text(
              giaTri,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                giaTri,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          if (phu != null) ...[
            const SizedBox(height: 2),
            Text(
              phu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      );
}
