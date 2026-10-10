/// Khối "khoi_dong_tien" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
// ignore_for_file: use_key_in_widget_constructors
library;

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../domain/bao_cao_xuat.dart';
import '../../../domain/du_bao_dong_tien.dart';
import '../../../domain/thac_nuoc.dart';
import '../../../domain/thong_ke_thang.dart';
import 'chung.dart';
import 'khoi_co_cau.dart';

/// Số dư ví ở hai đầu kỳ.
///
/// ⚠️ **Câu "Suy ngược từ số dư hiện tại của các ví" là bắt buộc.** App không
/// lưu lịch sử số dư, nên hai con số này suy ngược từ số dư hôm nay; bê mỗi con
/// số là để người đọc tưởng đây là số đo. Ví tạo giữa kỳ mang theo số dư ban
/// đầu không phải giao dịch, nên nó rơi vào số dư đầu kỳ — mục 3.16.
class KhoiDongTien extends StatelessWidget {
  final DongTien dt;
  const KhoiDongTien({required this.dt});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: theTrang(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tieuDeKhoi('Dòng tiền trong kỳ'),
            const SizedBox(height: 16),
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
            const Text(
              'Suy ngược từ số dư hiện tại của các ví',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _oSoDu(String nhan, double soTien) => Column(
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
}

/// Thác nước: số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư cuối kỳ.
///
/// Phép tính ở `domain/thac_nuoc.dart`; khối này chỉ lo vẽ và tra tên danh mục.
/// Nhóm chi mượn **`topVaKhac`** — cùng hàm mà vòng tròn cơ cấu dùng, nên hai
/// khối không thể nói hai con số cho một kỳ.
class KhoiThacNuoc extends StatelessWidget {
  final ThongKeKy tk;

  const KhoiThacNuoc({required this.tk});

  /// Năm nhóm lớn nhất, phần còn lại gom thành "Khác" — chín cột là đã kịch
  /// khổ 411dp.
  static const int _soNhom = 5;
  static const double _rongCot = 15;

  /// Nhãn trục hoành xoay −35° (G54): chữ dài hơn chừng này thì cắt "…".
  /// 72dp đủ cho "Chưa phân loại" ở cỡ 9 (64dp cắt còn "Chưa phân l…" trên
  /// Realme).
  static const double _rongNhanTrucHoanh = 72;

  /// Chiều cao dành cho nhãn nghiêng: `72 × sin 35° + cao dòng × cos 35°`
  /// cộng đệm trên 6dp. Vùng vẽ giữ nguyên vì khung biểu đồ cao thêm đúng
  /// phần chênh so với 40dp cũ.
  static const double _caoNhanTrucHoanh = 58;

  @override
  Widget build(BuildContext context) {
    final dt = tk.dongTien;
    // Cùng điều kiện với khối "Dòng tiền trong kỳ": lọc theo một ví thì số dư
    // hai đầu không suy ngược được (mục 3.16), và thác nước mất luôn hai cột
    // mốc — còn lại một hình không kể được gì.
    if (dt == null) return const SizedBox.shrink();

    // `danhMuc` cùng thứ tự với `chiTheoDanhMuc` và đã tra sẵn tên.
    final ten = <String?, String>{};
    for (final d in tk.danhMuc) {
      ten[d.categoryId] = d.ten;
    }

    final lat = topVaKhac(tk.chiTheoDanhMuc, top: _soNhom);
    final nhomChi = <({String ten, double soTien})>[
      for (final l in lat)
        (
          ten: l.laKhac ? 'Khác' : (ten[l.categoryId] ?? 'Chưa phân loại'),
          soTien: l.soTien,
        ),
    ];

    final buoc = thacNuocCua(
      dauKy: dt.dauKy,
      cuoiKy: dt.cuoiKy,
      thu: tk.tong.thu,
      nhomChi: nhomChi,
    );
    if (buoc.isEmpty) return const SizedBox.shrink();

    final tb = trungBinhNhomChi(nhomChi);

    var lo = 0.0;
    var hi = 0.0;
    for (final b in buoc) {
      lo = math.min(lo, math.min(b.tu, b.den));
      hi = math.max(hi, math.max(b.tu, b.den));
    }
    // Sàn và trần là BỘI của bước tròn — phép và lý lẽ ở `daiTrucCot`. Bản cũ
    // đặt `minY = lo`: số dư đầu kỳ âm thì biên trên lệch mọi mốc và hai nhãn
    // in đè (G53).
    final (san: minY, tran: maxY, buoc: buocTruc) = daiTrucCot(lo, hi);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tieuDeKhoi('Tiền đi đâu'),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              ChuGiaiDonut(mau: AppColors.textPrimary, nhan: 'Số dư'),
              ChuGiaiDonut(mau: AppColors.income, nhan: 'Thu'),
              ChuGiaiDonut(mau: AppColors.expense, nhan: 'Chi'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            // 200 cũ cộng phần nhãn nghiêng cao hơn nhãn thẳng (58 − 40).
            height: 218,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: minY,
                alignment: BarChartAlignment.spaceAround,
                // ⚠️ `BarChartData` **không có** `clipData` — bẫy 4.17 nói về
                // `LineChartData`. Ở đây chống tràn bằng cách khác: `minY`/
                // `maxY` bọc trọn mọi bậc (`lo`/`hi` quét cả `tu` lẫn `den`),
                // nên không cột nào rơi ra ngoài dải để mà tràn.
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buocTruc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
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
                      interval: buocTruc,
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
                      reservedSize: _caoNhanTrucHoanh,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= buoc.length) {
                          return const SizedBox.shrink();
                        }
                        // Nhãn XOAY −35°, một dòng — đúng màn Stitch
                        // `52450ac5…` (G54). Ô thẳng đứng 32dp hai dòng cũ
                        // vừa ở 411dp (~36dp mỗi cột) nhưng dính nhau ở 360dp
                        // (~27dp): "chuyểnphân l…" trên Realme. Nhãn nghiêng
                        // thì hai nhãn cạnh nhau cách nhau `bước cột × sin 35°`
                        // theo phương vuông góc (~15dp ở 360dp) — rộng hơn
                        // chiều cao chữ, nên cột hẹp mấy cũng không chồng.
                        //
                        // ⚠️ ĐẦU PHẢI của chữ neo đúng tâm cột rồi xoay quanh
                        // góc trên-phải (như `text-anchor="end"` của Stitch):
                        // xoay quanh tâm thì nửa phải của nhãn dài chồi lên
                        // vùng cột. Ô rộng 0 đặt ở tâm cột, `OverflowBox`
                        // canh phải cho chữ tràn sang trái.
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 0,
                            height: _caoNhanTrucHoanh - 6,
                            child: OverflowBox(
                              alignment: Alignment.topRight,
                              minWidth: 0,
                              maxWidth: _rongNhanTrucHoanh,
                              // Chữ cao đúng một dòng — không nhận chiều cao
                              // chặt của ô cha.
                              minHeight: 0,
                              child: Transform.rotate(
                                angle: -35 * math.pi / 180,
                                alignment: Alignment.topRight,
                                child: Text(
                                  buoc[i].nhan,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buoc.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [_cot(buoc[i], tb)],
                    ),
                ],
              ),
            ),
          ),
          if (tb > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Phần đậm là chỗ vượt mức trung bình '
              '${CurrencyFormatter.format(tb)}/nhóm',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Một cột của thác nước.
  ///
  /// Hai cột mốc mọc từ đáy; cột thu và các cột chi **nổi** — `fromY`/`toY` là
  /// thứ làm nên bậc thang. `fl_chart` đòi `fromY < toY` nên phải lấy `min`/
  /// `max`, còn chiều thì đã nằm trong `tu`/`den` của bậc.
  BarChartRodData _cot(BuocThacNuoc b, double tb) {
    final day = math.min(b.tu, b.den);
    final dinh = math.max(b.tu, b.den);
    final mau = switch (b.loai) {
      LoaiBuoc.moc => AppColors.textPrimary,
      LoaiBuoc.thu => AppColors.income,
      LoaiBuoc.chi => AppColors.expense,
    };
    final ranh = ranhVuotTrungBinh(b, tb);

    return BarChartRodData(
      fromY: day,
      toY: dinh,
      width: _rongCot,
      color: mau,
      borderRadius: BorderRadius.circular(3),
      // Nhóm vượt mức trung bình thì cột chia hai sắc độ: phần trong mức nhạt,
      // phần vượt đậm. Vì sao KHÔNG phải một đường ngang vắt qua biểu đồ —
      // xem `ranhVuotTrungBinh`.
      rodStackItems: ranh == null
          ? const []
          : [
              BarChartRodStackItem(day, ranh, mau),
              BarChartRodStackItem(ranh, dinh, mau.withValues(alpha: 0.35)),
            ],
    );
  }
}
