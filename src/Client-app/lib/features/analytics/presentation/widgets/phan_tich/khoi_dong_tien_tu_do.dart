/// Khối "khoi_dong_tien_tu_do" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../domain/bao_cao_xuat.dart';
import '../../../domain/dong_tien_tu_do.dart';
import '../../../domain/du_bao_dong_tien.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../../../../core/ui/bieu_do_cham.dart';
import 'chung.dart';

/// Xu hướng **dòng tiền tự do** — A8 #8 (2026-09-15).
///
/// Phép tính nằm trọn ở `dongTienTuDo()` (tầng thuần, có test); ở đây chỉ vẽ.
///
/// ⚠️ **Dòng giải nghĩa dưới tiêu đề là bắt buộc**, cùng lý do khối Dòng tiền
/// luôn kèm câu "Suy ngược từ số dư hiện tại": "thu nhập" ở đây **không phải**
/// tổng thu của khối trên — nó đã trừ tiền đi vay và tiền thu nợ. Hai khối kề
/// nhau nói hai con số khác nhau mà không nói vì sao là cách chắc chắn để người
/// đọc tưởng một trong hai bị sai.
///
/// Khối **luôn hiện** khi kỳ có giao dịch (người dùng chốt 2026-09-15), kể cả
/// khi không ai nợ ai — khi ấy đường này trùng khít đường "Thu" của khối trên.
class KhoiDongTienTuDo extends StatelessWidget {
  final ThongKeKy tk;
  const KhoiDongTienTuDo({super.key, required this.tk});

  @override
  Widget build(BuildContext context) {
    final ds = dongTienTuDo(tk.chuoi, tk.chuoiVayNo);
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (ds.isEmpty) return const SizedBox.shrink();

    var dinh = 0.0, day = 0.0;
    for (final d in ds) {
      if (d.tuDo > dinh) dinh = d.tuDo;
      if (d.tuDo < day) day = d.tuDo;
    }
    final coAm = day < 0;
    // Sàn và trần là BỘI của bước tròn — phép ở `daiTrucCot` (đường có vạch 0
    // nên trục chứa 0 là đúng; sáu kỳ phẳng bằng 0 thì hàm tự trả dải 0 … 1).
    // ⚠️ Bản cũ đặt sàn = đáy × 1,15: kỳ âm NHỎ (trả nợ vượt thu nhập một
    // chút) cho sàn âm lẻ, và fl_chart vẽ nhãn ở biên CỘNG các bội của
    // `interval` tính từ 0 — "-115K" in đè "0" (cùng cơ chế G53, bẫy 4.18).
    // Nới ×1,05 trước khi làm tròn để chấm ở cực trị không nằm đúng mép khung,
    // nơi `FlClipData.all()` cắt mất nửa chấm.
    final (san: san, tran: maxY, buoc: buoc) =
        daiTrucCot(day * 1.05, dinh * 1.05);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text đứng trong Row không co được — cùng lý do với tiêu đề donut.
          SizedBox(
            width: double.infinity,
            child: Text(
              tieuDeDongTienTuDo(tk.ky.donVi),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thu nhập sau khi trả nợ; không tính tiền đi vay và thu hồi nợ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              chuoiTien(ds.last.tuDo),
              maxLines: 1,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ds.last.tuDo < 0 ? AppColors.expense : AppColors.income,
              ),
            ),
          ),
          Text(
            tk.ky.nhanNgan,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                // Nới hai đầu để chấm kỳ đầu/cuối nằm trọn trong vùng vẽ (G79).
                minX: trucNgangCoCham(0, (ds.length - 1).toDouble()).min,
                maxX: trucNgangCoCham(0, (ds.length - 1).toDouble()).max,
                minY: san,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                // Vạch 0 chỉ có nghĩa khi dải có phần âm; khi mọi kỳ đều dương
                // thì `san` đã bằng 0 và vạch trùng đúng mép dưới.
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (coAm)
                      HorizontalLine(
                        y: 0,
                        color: AppColors.textSecondary,
                        strokeWidth: 1,
                        dashArray: const [6, 4],
                      ),
                  ],
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buoc,
                      // "-123.5M" là chuỗi dài nhất ở đây — dài hơn khối Xu
                      // hướng đúng một dấu trừ, vì dải này đi xuống dưới 0.
                      reservedSize: 50,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
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
                        // fl_chart hỏi cả mốc ngoài dải khi vẽ lưới, và hai
                        // biên đã nới (số lẻ) — bỏ cả hai (G79).
                        if (!laMocChiSo(v) || i < 0 || i >= ds.length) {
                          return const SizedBox.shrink();
                        }
                        final cuoi = i == ds.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ds[i].ky.nhanTruc,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  cuoi ? FontWeight.bold : FontWeight.normal,
                              color: cuoi
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    // Bắt buộc: mặc định hộp tooltip tràn ra ngoài màn hình ở
                    // điểm cuối, sát mép phải — thấy trên máy ảo 411dp.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          rutGon(s.y),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Điểm ngoài dải vẫn được VẼ nếu không cắt — mặc định của
                // fl_chart là `FlClipData.none()` (bẫy 4.17). Cắt cả bốn mép;
                // chấm kỳ đầu/cuối không mất nửa nhờ trục ngang đã nới (G79).
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < ds.length; i++)
                        FlSpot(i.toDouble(), ds[i].tuDo),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    // Đường cong nội suy có thể vọt qua mốc 0 giữa hai điểm,
                    // vẽ ra một kỳ âm không có thật.
                    preventCurveOverShooting: true,
                    color: AppColors.income,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      // Kỳ âm đổi màu chấm: đó là thứ người đọc phải thấy ngay.
                      // Đổi màu theo từng ĐIỂM thì chính xác — đổi màu cả đoạn
                      // đường phải dựa vào hộp bao của đường, thứ không trùng
                      // với dải của biểu đồ.
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color:
                            spot.y < 0 ? AppColors.expense : AppColors.income,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    // Tô phần DƯƠNG (từ đường xuống mốc 0) …
                    belowBarData: BarAreaData(
                      show: true,
                      applyCutOffY: true,
                      cutOffY: 0,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.income.withValues(alpha: 0.25),
                          AppColors.income.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    // … và phần ÂM (từ mốc 0 xuống đường) bằng màu chi. Thiếu
                    // vế này thì vùng tô đổ suốt xuống đáy biểu đồ và kỳ âm
                    // trông y hệt kỳ dương.
                    aboveBarData: BarAreaData(
                      show: coAm,
                      applyCutOffY: true,
                      cutOffY: 0,
                      color: AppColors.expense.withValues(alpha: 0.18),
                    ),
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

// ── Dự báo 30 ngày tới ────────────────────────────────────────────────────
