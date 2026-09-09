import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../analytics/domain/thong_ke_thang.dart' show rutGon;
import '../../data/models/goal_entity.dart';
import '../../domain/goal_history_filter.dart';
import '../../domain/goal_progress_series.dart';

/// Khối "Tiến độ theo thời gian" trên trang chi tiết mục tiêu.
///
/// Trước khối này, trang chỉ trả lời được *đang ở đâu* (vòng phần trăm) chứ
/// không trả lời được *đi nhanh hay chậm* — thứ mà thẻ "Cấu hình" chỉ nói được
/// bằng hai chữ "Chậm so với nhịp". Đường kế hoạch ở đây là **cùng một luật**,
/// vẽ ra thành hình.
///
/// Mọi phép tính nằm ở `goal_progress_series.dart` và được test ở đó; tệp này
/// chỉ vẽ. Phần vẽ **không kiểm được bằng test** (bẫy 4.9
/// `docs/ANALYTICS_FEATURE.md`) — màu, nét, vị trí tooltip chỉ thấy trên máy
/// ảo 411dp.
class GoalProgressChart extends StatelessWidget {
  final GoalEntity goal;

  /// Lịch sử tích luỹ, thứ tự nào cũng được — tầng thuần tự sắp lại.
  final List<KhoanTichLuy> khoan;

  /// `null` = đồng hồ máy; test truyền mốc cố định.
  final DateTime? now;

  const GoalProgressChart({
    super.key,
    required this.goal,
    required this.khoan,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final moc = now ?? DateTime.now();

    final chuoi = chuoiTienDo(
      khoan: khoan,
      soTienHienTai: goal.currentAmount,
      soTienDich: goal.targetAmount,
      ngayBatDau: goal.startDate,
      hanChot: goal.targetDate,
      now: moc,
    );
    // Mục tiêu vừa tạo thì chưa có gì để vẽ. Một thẻ trống mang tiêu đề vẫn
    // chiếm chỗ và vẫn hứa có nội dung.
    if (chuoi == null) return const SizedBox.shrink();

    final nhip = nhipSoVoiKeHoach(
      soTienHienTai: goal.currentAmount,
      soTienDich: goal.targetAmount,
      ngayBatDau: goal.startDate,
      hanChot: goal.targetDate,
      now: moc,
    );

    final minX = chuoi.tuNgay.millisecondsSinceEpoch.toDouble();
    final maxX = chuoi.denNgay.millisecondsSinceEpoch.toDouble();
    final buocX = (maxX - minX) / 3;
    final buocY = chuoi.dinhY / 3;

    // Mục tiêu vài tuần và mục tiêu vài năm dùng chung một trục; nhãn "09/26"
    // cho một mục tiêu 3 tuần thì bốn nhãn giống hệt nhau.
    final soNgay = chuoi.denNgay.difference(chuoi.tuNgay).inDays;
    final dinhDangNgay = DateFormat(soNgay >= 100 ? 'MM/yy' : 'dd/MM');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Text` đứng trong `Row` không co được; đứng trong `SizedBox` rộng
          // hết cỡ thì `ellipsis` mới có chỗ làm việc.
          const SizedBox(
            width: double.infinity,
            child: Text(
              'TIẾN ĐỘ THEO THỜI GIAN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              const _ChuGiai(mau: AppColors.income, ten: 'Thực tế'),
              // Không có ngày bắt đầu thì không có đường kế hoạch, nên một mục
              // chú giải trỏ vào đường không tồn tại là chỉ vào chỗ trống.
              if (chuoi.keHoach.isNotEmpty)
                const _ChuGiai(
                  mau: AppColors.textSecondary,
                  ten: 'Kế hoạch',
                  netDut: true,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: chuoi.dinhY,
                // **Bắt buộc.** `clipData` mặc định của fl_chart là
                // `FlClipData.none()`, tức điểm nằm ngoài dải vẫn được VẼ —
                // không phải bị cắt. Thấy trên máy ảo 2026-09-09: một điểm âm
                // kéo cả đường xuống chạy qua dòng chú thích và tràn khỏi thẻ,
                // đè lên phần trang bên dưới. Không log, không exception, và
                // không widget test nào bắt được vì mọi thứ vẽ trong canvas
                // của thư viện.
                //
                // Tầng thuần đã kẹp ở 0 (`_khongAm`) nên đây là lớp thứ hai:
                // một hình dáng dữ liệu chưa lường tới cũng không thể vẽ ra
                // ngoài khung nữa.
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buocY,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.outlineVariant,
                    strokeWidth: 1,
                  ),
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
                      interval: buocY,
                      // "123.5M" là chuỗi dài nhất; font của bộ test rộng gấp
                      // đôi ngoài đời nên chừa rộng tay.
                      reservedSize: 46,
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
                      interval: buocX,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        // Bỏ mốc ngoài dải, và mốc sát biên (nơi nhãn biên đã
                        // chiếm chỗ) — luật ở tầng thuần, có test riêng.
                        if (!hienNhanTruc(v: v, min: minX, max: maxX)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dinhDangNgay.format(
                              DateTime.fromMillisecondsSinceEpoch(v.round()),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
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
                    // Mặc định fl_chart để hộp tràn ra ngoài; chạm điểm cuối
                    // sát mép phải là lòi khỏi màn hình và mất chữ.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${dinhDangNgay.format(
                            DateTime.fromMillisecondsSinceEpoch(s.x.round()),
                          )} · ${rutGon(s.y)}',
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
                  if (chuoi.keHoach.isNotEmpty)
                    LineChartBarData(
                      spots: [
                        for (final d in chuoi.keHoach)
                          FlSpot(
                            d.ngay.millisecondsSinceEpoch.toDouble(),
                            d.soTien,
                          ),
                      ],
                      color: AppColors.textSecondary,
                      barWidth: 2,
                      dashArray: const [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                  LineChartBarData(
                    spots: [
                      for (final d in chuoi.thucTe)
                        FlSpot(
                          d.ngay.millisecondsSinceEpoch.toDouble(),
                          d.soTien,
                        ),
                    ],
                    // **Thẳng, không cong.** Tiền vào theo từng khoản rời rạc;
                    // một đường cong nội suy vẽ ra số dư ở những ngày chưa hề
                    // có giao dịch nào, và còn vọt xuống dưới 0 giữa hai điểm.
                    isCurved: false,
                    color: AppColors.income,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.income,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.income.withValues(alpha: 0.25),
                          AppColors.income.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nhip != null) ...[
            const SizedBox(height: 12),
            _ChuThichNhip(nhip: nhip.nhip, chenhLech: nhip.chenhLech),
          ],
        ],
      ),
    );
  }
}

/// Một mục chú giải: mẫu nét vẽ, rồi tên đường.
class _ChuGiai extends StatelessWidget {
  final Color mau;
  final String ten;
  final bool netDut;

  const _ChuGiai({
    required this.mau,
    required this.ten,
    this.netDut = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (netDut)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 4,
                    height: 2,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 3),
                    color: mau,
                  ),
              ],
            )
          else
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: mau,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 8),
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

/// Dòng chú thích dưới biểu đồ: đang chậm, đúng nhịp, hay vượt kế hoạch.
///
/// Số tiền in đậm và **có màu** vì đó là thứ người dùng đọc để quyết định nạp
/// bù bao nhiêu; câu chữ quanh nó chỉ là khung.
class _ChuThichNhip extends StatelessWidget {
  final NhipKeHoach nhip;
  final double chenhLech;

  const _ChuThichNhip({required this.nhip, required this.chenhLech});

  @override
  Widget build(BuildContext context) {
    const kieu = TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant);

    if (nhip == NhipKeHoach.dungNhip) {
      return const SizedBox(
        width: double.infinity,
        child: Text('Đang bám sát kế hoạch', style: kieu),
      );
    }

    final cham = nhip == NhipKeHoach.cham;
    final tien = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: kieu,
          children: [
            TextSpan(text: cham ? 'Chậm hơn kế hoạch ' : 'Vượt kế hoạch '),
            TextSpan(
              text: tien.format(chenhLech.abs()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cham ? AppColors.error : AppColors.income,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
