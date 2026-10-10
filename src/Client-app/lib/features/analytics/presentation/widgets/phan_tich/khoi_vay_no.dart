/// Khối "khoi_vay_no" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
// ignore_for_file: use_key_in_widget_constructors
library;

import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import '../../../domain/vai_vay_no.dart';
import '../../../domain/thong_ke_thang.dart';
import 'chung.dart';
import 'khoi_co_cau.dart';

enum CotVayNo { choVay, thuNo, diVay, traNo }

extension _CotVayNoX on CotVayNo {
  String get nhan => switch (this) {
        CotVayNo.choVay => 'Cho vay',
        CotVayNo.thuNo => 'Thu nợ',
        CotVayNo.diVay => 'Đi vay',
        CotVayNo.traNo => 'Trả nợ',
      };

  /// Tiền vào thì xanh, tiền ra thì đỏ — không phụ thuộc cột nằm trước hay sau.
  Color get mau => switch (this) {
        CotVayNo.choVay || CotVayNo.traNo => AppColors.expense,
        CotVayNo.thuNo || CotVayNo.diVay => AppColors.income,
      };

  double soTien(DiemVayNo d) => switch (this) {
        CotVayNo.choVay => d.choVay,
        CotVayNo.thuNo => d.thuNo,
        CotVayNo.diVay => d.diVay,
        CotVayNo.traNo => d.traNo,
      };
}

class KhoiVayNo extends StatelessWidget {
  final String tieuDe;
  final List<DiemVayNo> ds;

  /// Cột **rộng, mờ**, vẽ trước nên nằm dưới.
  final CotVayNo sau;

  /// Cột **hẹp, đậm**, vẽ sau nên đè lên trên.
  final CotVayNo truoc;

  const KhoiVayNo({
    required this.tieuDe,
    required this.ds,
    required this.sau,
    required this.truoc,
  });

  /// Bề rộng hai cột. Cột trước phải hẹp hơn hẳn thì mắt mới thấy nó nằm
  /// **trong lòng** cột sau chứ không phải một cột thứ hai đứng cạnh.
  static const double _rongSau = 22;
  static const double _rongTruoc = 12;

  @override
  Widget build(BuildContext context) {
    var dinh = 0.0;
    for (final d in ds) {
      final a = sau.soTien(d);
      final b = truoc.soTien(d);
      if (a > dinh) dinh = a;
      if (b > dinh) dinh = b;
    }
    // Cùng cách chống nhãn trục tung in đè của G39 (bẫy 4.18): tính `buoc`
    // trước rồi đặt trần bằng `buoc * 3`, đừng chia một số rồi dùng lại chính
    // nó làm trần — `3 * (maxY / 3)` lệch `maxY` chừng 1e-14 và `rutGon` cho ra
    // hai chuỗi khác nhau ở cùng một vị trí.
    final buoc = (dinh <= 0 ? 1.0 : dinh * 1.15) / 3;
    final maxY = buoc * 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tieuDeKhoi(tieuDe),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              ChuGiaiDonut(mau: sau.mau, nhan: sau.nhan),
              ChuGiaiDonut(mau: truoc.mau, nhan: truoc.nhan),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                // `fitInside*` là hai chốt đã học ở khối Xu hướng (mục 3.11):
                // không có chúng thì tooltip của cột đầu và cột cuối tràn ra
                // ngoài thẻ.
                barTouchData: const BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buoc,
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= ds.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ds[i].ky.nhanTruc,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < ds.length; i++)
                    BarChartGroupData(
                      x: i,
                      // `barsSpace` ÂM là thứ làm hai cột chồng nhau.
                      // `-(rộng1 + rộng2) / 2` đặt tâm hai cột trùng khít —
                      // lệch đi là cột trước trồi ra một bên, trông như lỗi vẽ.
                      barsSpace: -(_rongSau + _rongTruoc) / 2,
                      barRods: [
                        // Thứ tự trong danh sách LÀ thứ tự vẽ: cột sau phải
                        // đứng trước để cột trước đè lên nó.
                        BarChartRodData(
                          toY: sau.soTien(ds[i]),
                          width: _rongSau,
                          color: sau.mau.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: truoc.soTien(ds[i]),
                          width: _rongTruoc,
                          color: truoc.mau,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khoản thuộc nhóm Vay/nợ mà **không đoán được vai** — chỉ hiện khi có.
///
/// Vì sao không nhét vào hai khối trên: một khoản tiền ra không rõ tên có thể là
/// *cho vay* **hoặc** *trả nợ*. Xếp vào một khối là chọn bừa, xếp vào cả hai là
/// đếm hai lần. Khối riêng là chỗ duy nhất không phải bịa — và giấu nó đi thì
/// tổng trên hai biểu đồ nhỏ hơn tiền thật mà không ai biết vì sao.
class KhoiVayNoKhac extends StatelessWidget {
  final List<DiemVayNo> ds;
  const KhoiVayNoKhac({required this.ds});

  @override
  Widget build(BuildContext context) {
    final ra = ds.fold<double>(0, (s, d) => s + d.khacRa);
    final vao = ds.fold<double>(0, (s, d) => s + d.khacVao);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tieuDeKhoi('Vay/nợ chưa xếp được vai'),
          const SizedBox(height: 8),
          const Text(
            'Danh mục vay/nợ do bạn tự đặt tên — app chỉ biết chiều tiền, '
            'không biết là cho vay hay trả nợ.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _o('TIỀN RA', ra, AppColors.expense)),
              const SizedBox(width: 12),
              Expanded(child: _o('TIỀN VÀO', vao, AppColors.income)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _o(String nhan, double soTien, Color mau) => Column(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(soTien),
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ),
        ],
      );
}
