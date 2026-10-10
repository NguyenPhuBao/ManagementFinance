/// Khối "khoi_so_lieu_nhanh" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
// ignore_for_file: use_key_in_widget_constructors
library;

import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../../../core/utils/date_formatter.dart';
import 'chung.dart';

/// Ba con số người dùng hỏi ngay, kiểu Money Lover / MISA.
class KhoiSoLieuNhanh extends StatelessWidget {
  final ThongKeKy tk;
  const KhoiSoLieuNhanh({required this.tk});

  @override
  Widget build(BuildContext context) {
    final s = tk.soLieu;

    // Cả BA chỉ số của khối này đều nói về **chi**, nên một kỳ không có khoản
    // chi nào cho ra một thẻ gồm `0 đ` và hai dấu `—`: chiếm chỗ, không mang
    // tin nào. Kỳ như thế **không** rơi vào nhánh `thongKe.rong` — nhánh ấy đòi
    // `thu == 0` **và** `chi == 0` — nên nó đi thẳng vào thân trang.
    //
    // ⚠️ Phải đòi **cả ba** cùng rỗng, không chỉ hai trường `null`:
    // `chiMoiNgay` khác 0 là một con số có thật và đáng nói, kể cả khi kỳ không
    // xác định được ngày chi nhiều nhất.
    //
    // ⚠️ Và phép chốt đọc đúng `s` — chính thứ đang được vẽ — chứ không đọc
    // `tk.tong.chi`: hai vế của cùng một câu mà lấy từ hai chỗ khác nhau thì có
    // ngày chúng nói ngược nhau, im lặng.
    if (s.chiMoiNgay == 0 &&
        s.ngayChiNhieuNhat == null &&
        s.khoanChiLonNhat == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tieuDeKhoi('Số liệu nhanh'),
          const SizedBox(height: 16),
          // Canh MÉP TRÊN: nhãn "NGÀY CHI NHIỀU NHẤT" xuống hai dòng ở màn hẹp
          // (G78) thì ô bên cạnh không bị đẩy xuống giữa.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    _o('CHI MỖI NGÀY', CurrencyFormatter.format(s.chiMoiNgay)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _o(
                  'NGÀY CHI NHIỀU NHẤT',
                  s.ngayChiNhieuNhat == null
                      ? '—'
                      : DateFormatter.formatDate(s.ngayChiNhieuNhat!),
                  phu: s.ngayChiNhieuNhat == null
                      ? null
                      : CurrencyFormatter.format(s.chiNgayNhieuNhat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _o(
            'KHOẢN CHI LỚN NHẤT',
            s.khoanChiLonNhat?.tieuDe ?? '—',
            chu: true,
            phu: s.khoanChiLonNhat == null
                ? null
                : CurrencyFormatter.format(s.khoanChiLonNhat!.soTien),
          ),
        ],
      ),
    );
  }

  Widget _o(String nhan, String giaTri, {String? phu, bool chu = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            // G78 (2026-10-07): ở màn hẹp (320 dp) chữ phụ này từng cụt "…" — nay xuống tối đa hai dòng.
            maxLines: 2,
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
