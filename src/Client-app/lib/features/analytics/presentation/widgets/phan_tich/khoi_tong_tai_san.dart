/// Khối "khoi_tong_tai_san" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../domain/bao_cao_xuat.dart';
import '../../../domain/du_bao_dong_tien.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../../domain/tong_tai_san.dart';
import '../../../../../core/ui/bieu_do_cham.dart';
import 'chung.dart';

/// Tổng tài sản theo thời gian — #5 của khảo sát lần hai (2026-09-17).
///
/// Phép tính nằm trọn ở `tongTaiSanCua()` (tầng thuần, có test); ở đây chỉ vẽ.
/// Khối `fl_chart` thứ **chín** của app.
///
/// ## Ba điều dễ phá, cả ba hỏng im lặng
///
/// 1. **Con số lớn là `ds.last.tong`, không phải một phép cộng riêng.** Nó phải
///    bằng đúng số dư Trang chủ — đó là mốc để người dùng tin cả đường. Cộng
///    lại ví ở đây là bản chép tay thứ sáu của `viTinhVaoTong` (G42).
/// 2. **Dòng thay đổi ẨN khi [thayDoiTaiSan] trả `null`.** Đừng thay bằng
///    `?? 0` hay một hiệu tính tay: khi chuỗi chạm quãng chưa có giao dịch nào,
///    điểm đầu là số 0 **"chưa biết"**, và hiệu với nó in ra nguyên cả tài sản
///    như thể người dùng vừa kiếm được ngần ấy trong sáu kỳ.
/// 3. **Trục CO theo dữ liệu, bước TRÒN** — mượn nguyên `daiTrucDuBao` (bẫy
///    4.21). Trục từ 0 cho ra một đường phẳng khi dao động chỉ vài phần trăm
///    số dư; bước lẻ làm hai nhãn cuối in đè (G39, bẫy 4.18).
///
/// Tầng vẽ không test tự động được (bẫy 4.9): vùng tô, chấm cuối và vị trí
/// tooltip chỉ kiểm được bằng mắt trên máy ảo 411dp.
class KhoiTongTaiSan extends StatelessWidget {
  final ThongKeKy tk;
  const KhoiTongTaiSan({super.key, required this.tk});

  @override
  Widget build(BuildContext context) {
    final ds = tk.taiSan;
    // Chốt lớp thứ hai — xem chú thích ở chỗ dựng khối trong `_NoiDung`.
    if (ds.isEmpty) return const SizedBox.shrink();

    final thieu = mocThieuDuLieu(ds, giaoDichDauTien: tk.giaoDichDauTien);
    final thayDoi = thayDoiTaiSan(ds, giaoDichDauTien: tk.giaoDichDauTien);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tieuDeKhoi(tieuDeTongTaiSan(tk.ky.donVi)),
          const SizedBox(height: 12),
          Text(
            // ⚠️ Điểm cuối của đường, không phải một phép cộng ví riêng.
            CurrencyFormatter.format(ds.last.tong),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (thayDoi != null) ...[
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.formatCoDau(thayDoi, thu: thayDoi >= 0)}'
              ' trong ${cumSoKy(tk.ky.donVi)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: thayDoi >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 180, child: BieuDoTaiSan(ds: ds)),
          if (thieu != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                // ⚠️ `Expanded` chứ không `Flexible`: câu này dài hơn một dòng
                // ở 411dp, và `Flexible` để con giữ bề rộng tự nhiên nên chữ
                // tràn ra ngoài thẻ (bẫy 4.19).
                Expanded(
                  child: Text(
                    'Trước ${DateFormatter.formatDate(thieu)} chưa có giao '
                    'dịch nào để suy ra số dư.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Đường tổng tài sản sáu kỳ.
class BieuDoTaiSan extends StatelessWidget {
  final List<DiemTaiSan> ds;
  const BieuDoTaiSan({super.key, required this.ds});

  @override
  Widget build(BuildContext context) {
    // Dải trục CO theo dữ liệu với bước TRÒN — mượn nguyên phép của khối Dự
    // báo, nơi nó đã có test (kể cả ca dải hẹp làm bốn nhãn in ra cùng chuỗi).
    final (:san, :buoc) = daiTrucDuBao([for (final d in ds) d.tong]);
    // Trần phải là ĐÚNG `san + 3 * buoc`, không phải con số đã đem chia: sai số
    // dấu phẩy động đủ để `rutGon` trả hai chuỗi khác nhau cho cùng một vị trí,
    // và hai nhãn in đè khít lên nhau (G39, bẫy 4.18).
    final maxY = san + buoc * 3;
    final coAm = san < 0;
    final cuoi = ds.length - 1;

    return LineChart(
      LineChartData(
        // Nới hai đầu để chấm kỳ đầu/cuối nằm trọn trong vùng vẽ (G79).
        minX: trucNgangCoCham(0, cuoi.toDouble()).min,
        maxX: trucNgangCoCham(0, cuoi.toDouble()).max,
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: buoc,
              reservedSize: 50,
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
                // Hai biên đã nới là số lẻ — bỏ (G79).
                if (!laMocChiSo(v) || i < 0 || i > cuoi) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    // Nhãn kỳ lấy từ `Ky.nhanTruc` — nơi luật "sáu nhãn phải
                    // đôi một khác nhau" đã được giải quyết (quý mang năm).
                    ds[i].ky.nhanTruc,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
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
        // Điểm ngoài dải vẫn được VẼ nếu không cắt (bẫy 4.17). Cắt cả bốn
        // mép; chấm kỳ đầu/cuối không mất nửa nhờ trục ngang đã nới (G79).
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < ds.length; i++)
                FlSpot(i.toDouble(), ds[i].tong),
            ],
            // Số dư đổi theo từng giao dịch chứ không theo một đường cong —
            // nối thẳng là nói đúng hình dạng của tiền.
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                // Chấm cuối to hơn và có viền trắng: đó là con số đang hiện ở
                // dòng lớn phía trên, mắt cần nối được hai thứ với nhau.
                radius: i == cuoi ? 5 : 3,
                color: AppColors.primary,
                strokeWidth: i == cuoi ? 2 : 0,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              // Chỉ cắt ở mốc 0 khi 0 nằm trong dải; trục co thì nó thường
              // không, và cắt ở một mốc ngoài khung là tô đặc cả biểu đồ.
              applyCutOffY: coAm,
              cutOffY: 0,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            // Phần ÂM tô màu chi. Thiếu vế này thì vùng tô đổ suốt xuống đáy và
            // một kỳ âm trông y hệt một kỳ dương.
            aboveBarData: BarAreaData(
              show: coAm,
              applyCutOffY: true,
              cutOffY: 0,
              color: AppColors.expense.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
