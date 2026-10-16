/// Biểu đồ thu / chi trong kỳ của trang Xem trước báo cáo (`report_preview_page.dart`) — tệp duy nhất của trang dùng `fl_chart`.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import 'the_bao_cao.dart';

/// Biểu đồ thu/chi trong kỳ. Cùng khuôn với khối "Xu hướng 6 tháng" của
/// trang Phân tích (mục 3.11) — kể cả hai chốt chặn đã học được ở đó:
/// `fitInside*` cho tooltip và `preventCurveOverShooting`.
class BieuDoBaoCao extends StatelessWidget {
  const BieuDoBaoCao({super.key, required this.baoCao});

  final BaoCao baoCao;

  @override
  Widget build(BuildContext context) {
    var dinh = 0.0;
    for (final d in baoCao.chuoi) {
      if (d.thu > dinh) dinh = d.thu;
      if (d.chi > dinh) dinh = d.chi;
    }
    final maxY = dinh <= 0 ? 1.0 : dinh * 1.15;
    final buoc = maxY / 3;
    // Nhiều nhất sáu nhãn trên trục: 30 cột × nhãn "01/09" là một vệt chữ đè
    // lên nhau ở khổ 411dp.
    final buocNhan = (baoCao.chuoi.length / 6).ceil();

    return TheBaoCao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NhanMucBaoCao('THU CHI TRONG KỲ'),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ChuGiai(mau: AppColors.income, ten: 'Thu'),
              _ChuGiai(mau: AppColors.expense, ten: 'Chi'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (baoCao.chuoi.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
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
                        // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới.
                        if (i < 0 || i >= baoCao.chuoi.length) {
                          return const SizedBox.shrink();
                        }
                        if (i % buocNhan != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            baoCao.chuoi[i].nhan,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    // Bẫy 4.9: mặc định thư viện để hộp tooltip lòi ra ngoài.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${s.barIndex == 0 ? 'Thu' : 'Chi'} ${rutGon(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  _duong([
                    for (var i = 0; i < baoCao.chuoi.length; i++)
                      FlSpot(i.toDouble(), baoCao.chuoi[i].thu),
                  ], AppColors.income),
                  _duong([
                    for (var i = 0; i < baoCao.chuoi.length; i++)
                      FlSpot(i.toDouble(), baoCao.chuoi[i].chi),
                  ], AppColors.expense),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thứ tự trong `lineBarsData` **là** `barIndex` của tooltip: đường thu phải
/// đứng trước để nhãn "Thu"/"Chi" không đổi chỗ cho nhau.
LineChartBarData _duong(List<FlSpot> diem, Color mau) => LineChartBarData(
      spots: diem,
      isCurved: true,
      curveSmoothness: 0.25,
      // Đường cong nội suy có thể vọt xuống dưới 0 giữa hai điểm, vẽ ra một
      // ngày "âm tiền" không có thật.
      preventCurveOverShooting: true,
      color: mau,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mau.withValues(alpha: 0.22),
            mau.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

/// Một ô chú giải của biểu đồ. Bản sao có chủ ý của `_ChuGiaiDuong` ở trang
/// Phân tích: gộp làm một widget dùng chung sẽ buộc hai trang chia sẻ cả cỡ
/// chữ lẫn khoảng cách, thứ hai bên không hứa giống nhau.
class _ChuGiai extends StatelessWidget {
  final Color mau;
  final String ten;

  const _ChuGiai({required this.mau, required this.ten});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            ten,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}
