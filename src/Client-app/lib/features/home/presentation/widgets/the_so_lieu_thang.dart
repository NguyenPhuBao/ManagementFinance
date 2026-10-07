import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/do_chu.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';

/// Ba thẻ Thu nhập / Chi tiêu / Thu net của tháng ở Trang chủ.
///
/// Tách khỏi `HomePage` ngày 2026-09-19 để test được ở khổ 411dp.
///
/// ⚠️ G72 (2026-10-07): ba thẻ dùng **CHUNG một cỡ chữ** cho số tiền và chung
/// một cỡ cho nhãn — cỡ lớn nhất mà cả ba vừa ô, đo bằng `doRongChu`. Bản trước
/// để mỗi số tiền tự co bằng `FittedBox` riêng và nhãn không giới hạn dòng: ở
/// 320 dp (Realme để cỡ hiển thị lớn) "Thu nhập" xuống hai dòng, ba con số co
/// theo ba tỉ lệ khác nhau, và ba thẻ lệch chiều cao. Màn đủ chỗ giữ cỡ cũ.
class TheSoLieuThang extends StatelessWidget {
  const TheSoLieuThang({super.key, required this.thu, required this.chi});

  final double thu;
  final double chi;

  static const _coSoToiDa = 16.0;
  static const _coNhanToiDa = 13.0;
  static const _khe = 12.0;

  /// Lề trong 16 × 2 của mỗi thẻ.
  static const _leTrong = 32.0;

  /// Cỡ lớn nhất (≤ [toiDa]) để MỌI chuỗi trong [chu] vừa [rong].
  ///
  /// Ước theo tỉ lệ rồi **đo lại** và lùi 0,1 cho tới khi vừa: bề rộng chữ
  /// không tỉ lệ thuận đúng với cỡ chữ (làm tròn của bộ dàn chữ), nên cỡ ước
  /// theo tỉ lệ có lúc vẫn dư vài phần điểm ảnh và chuỗi dài nhất bị cắt.
  static double _coChung(BuildContext context, List<String> chu,
      TextStyle kieu, double toiDa, double rong) {
    double rongNhat(double co) => chu
        .map((c) => doRongChu(context, c, kieu.copyWith(fontSize: co)))
        .reduce(math.max);
    final r = rongNhat(toiDa);
    if (r <= rong) return toiDa;
    var co = (toiDa * rong / r * 10).floorToDouble() / 10;
    while (co > 1 && rongNhat(co) > rong) {
      co -= 0.1;
    }
    return co;
  }

  @override
  Widget build(BuildContext context) {
    final net = thu - chi;
    final soTien = [
      CurrencyFormatter.format(thu),
      CurrencyFormatter.format(chi),
      // Số 0 không mang dấu — định nghĩa duy nhất ở `formatCoDau`.
      CurrencyFormatter.formatCoDau(net, thu: net >= 0),
    ];
    const nhan = ['Thu nhập', 'Chi tiêu', 'Thu net'];
    return LayoutBuilder(builder: (context, rang) {
      final oChu = (rang.maxWidth - 2 * _khe) / 3 - _leTrong;
      final coSo =
          _coChung(context, soTien, _The.kieuSoTien, _coSoToiDa, oChu);
      final coNhan =
          _coChung(context, nhan, _The.kieuNhan, _coNhanToiDa, oChu);
      return Row(
        children: [
          Expanded(
              child: _The(nhan[0], soTien[0], thu > 0 ? 0.8 : 0.0,
                  AppColors.income, coSo, coNhan)),
          const SizedBox(width: _khe),
          Expanded(
              child: _The(nhan[1], soTien[1], chi > 0 ? 0.4 : 0.0,
                  AppColors.error, coSo, coNhan)),
          const SizedBox(width: _khe),
          Expanded(
              child: _The(nhan[2], soTien[2], net != 0 ? 0.6 : 0.0,
                  const Color(0xFF3B82F6), coSo, coNhan)),
        ],
      );
    });
  }
}

class _The extends StatelessWidget {
  const _The(this.nhan, this.soTien, this.tienDo, this.mau, this.coSo,
      this.coNhan);

  final String nhan;
  final String soTien;
  final double tienDo;
  final Color mau;
  final double coSo;
  final double coNhan;

  static const kieuNhan = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
  static const kieuSoTien = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            maxLines: 1,
            style: kieuNhan.copyWith(fontSize: coNhan),
          ),
          const SizedBox(height: 4),
          // Một dòng, cỡ CHUNG cho cả ba thẻ (xem [TheSoLieuThang]). Thay cho
          // `FittedBox` riêng từng thẻ: UX 2026-09-19 (B2) từng dùng nó để
          // `ellipsis` thôi cắt "14.635.000 đ" thành "14.635.0…" — cỡ chung
          // giữ được điều ấy mà ba con số không co mỗi cái một kiểu.
          Text(
            soTien,
            maxLines: 1,
            style: kieuSoTien.copyWith(fontSize: coSo),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: tienDo,
            backgroundColor: mau.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(mau),
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}
