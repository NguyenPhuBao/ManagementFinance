/// Khối "khoi_xu_huong" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../domain/pham_vi_ky.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../bloc/analytics_cubit.dart';
import '../../../../../core/ui/bieu_do_cham.dart';
import 'chung.dart';

/// Sáu tháng gần nhất, hai đường: thu và chi.
///
/// **Cố ý lệch bản Stitch.** Màn "Analytics Dashboard" chỉ có donut, tức chỉ
/// trả lời *tiền đi đâu*; câu *đang tăng hay đang giảm* không có chỗ nào trên
/// trang trả lời. Khối này nằm giữa khối tổng và donut vì đó là thứ tự câu
/// hỏi: bao nhiêu → xu hướng ra sao → đi vào đâu. Đừng "sửa lại cho khớp
/// Stitch".
/// Biểu đồ đường sáu tháng — A8 #6 (hai đường Thu/Chi) và A8 #7 (tới
/// `kToiDaDuongXuHuong` đường danh mục, bật/tắt bằng chip).
///
/// ⓘ Khối này từng **lệch Stitch có chủ ý** (mục 3.12 `ANALYTICS_FEATURE.md`):
/// tra cả 35 màn ngày 2026-09-08, không màn nào có biểu đồ đường. Từ 2026-09-14
/// nó **đã có** trên Stitch — màn `c2a2b615c9514ca180b28d189b2ea197` — nên lý
/// do lệch đã hết hiệu lực.
class KhoiXuHuong extends StatelessWidget {
  final ThongKeKy tk;

  /// Rỗng là hai đường Thu/Chi. Tối đa `kToiDaDuongXuHuong` phần tử — cubit
  /// chốt, ở đây chỉ vẽ.
  final Set<String> danhMucXuHuong;
  const KhoiXuHuong(
      {super.key, required this.tk, required this.danhMucXuHuong});

  @override
  Widget build(BuildContext context) {
    final chuoi = tk.chuoi;
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (chuoi.isEmpty) return const SizedBox.shrink();

    // Cubit đã loại khoá không còn, nhưng khung dựng lại có thể tới trước —
    // chỉ vẽ những danh mục thật sự có chuỗi, đừng `!`. Sắp theo tên để thứ
    // tự đường, chú giải và tooltip là MỘT thứ tự: `lineBarsData[i]` chính là
    // `barIndex` của tooltip.
    final dong = <String, DongDanhMuc?>{
      for (final id in danhMucXuHuong)
        if (tk.chuoiDanhMuc.containsKey(id)) id: tk.dongCua(id),
    };
    String tenCua(String id) => dong[id]?.ten ?? 'Danh mục';
    final chon = dong.keys.toList()
      ..sort(
          (a, b) => tenCua(a).toLowerCase().compareTo(tenCua(b).toLowerCase()));
    final theoThuChi = chon.isEmpty;

    // Một danh mục thường chỉ đi một chiều tiền, nên đường của nó vẽ tổng thu
    // + chi. Riêng danh mục vay/nợ có cả hai chiều: cộng lại là "tổng tiền đi
    // qua danh mục", đúng câu hỏi "nó đang lớn lên hay nhỏ đi".
    double giaTri(DiemThoiGian d) => d.tong.thu + d.tong.chi;

    var dinh = 0.0;
    if (theoThuChi) {
      for (final d in chuoi) {
        if (d.tong.thu > dinh) dinh = d.tong.thu;
        if (d.tong.chi > dinh) dinh = d.tong.chi;
      }
    } else {
      for (final id in chon) {
        for (final d in tk.chuoiDanhMuc[id]!) {
          if (giaTri(d) > dinh) dinh = giaTri(d);
        }
      }
    }
    // Trần cao hơn đỉnh để đường không dính mép trên. Sáu tháng rỗng sạch thì
    // `dinh` bằng 0 và mọi phép chia thang đo sau đây sẽ hỏng, nên đặt 1.
    final buoc = (dinh <= 0 ? 1.0 : dinh * 1.15) / 3;
    // ⚠️ Trần phải là ĐÚNG ba lần `buoc`, không phải con số đã đem chia.
    // fl_chart vẽ nhãn cho cả mốc theo `interval` lẫn biên trên, mà hai thứ ấy
    // ở cùng một vị trí; `3 * (x / 3)` lệch `x` chừng 1e-14 trong dấu phẩy động,
    // đủ để `rutGon` trả hai chuỗi khác nhau khi giá trị rơi đúng ranh giới làm
    // tròn — và hai nhãn in đè khít lên nhau, không ai đọc được (G39, thấy
    // trên máy ảo 2026-09-14; bẫy 4.18 `ANALYTICS_FEATURE.md`).
    final maxY = buoc * 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cùng lý do với tiêu đề donut: Text đứng trong Row không co được.
          SizedBox(
            width: double.infinity,
            child: Text(
              tieuDeXuHuong(tk.ky.donVi),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ChonDanhMucXuHuong(tk: tk, dangChon: danhMucXuHuong),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: theoThuChi
                ? const [
                    ChuGiaiDuong(mau: AppColors.income, ten: 'Thu'),
                    ChuGiaiDuong(mau: AppColors.expense, ten: 'Chi'),
                  ]
                : [
                    for (final id in chon)
                      ChuGiaiDuong(mau: mauCua(dong[id]), ten: tenCua(id)),
                  ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                // Nới hai đầu để chấm kỳ đầu/cuối nằm trọn trong vùng vẽ (G79).
                minX: trucNgangCoCham(0, (chuoi.length - 1).toDouble()).min,
                maxX: trucNgangCoCham(0, (chuoi.length - 1).toDouble()).max,
                minY: 0,
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
                      // Số tiền rút gọn nên "123.5M" là chuỗi dài nhất; font
                      // của bộ test rộng gấp đôi ngoài đời nên chừa rộng tay.
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
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới, và
                        // hai biên đã nới (số lẻ) — bỏ cả hai (G79).
                        if (!laMocChiSo(v) || i < 0 || i >= chuoi.length) {
                          return const SizedBox.shrink();
                        }
                        // Tháng đang xem là điểm cuối — in đậm để biết mình
                        // đang đứng ở đâu trên trục.
                        final cuoi = i == chuoi.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            chuoi[i].ky.nhanTruc,
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
                    // Bắt buộc: mặc định fl_chart đặt hộp giữa điểm chạm và
                    // để nó tràn ra ngoài. Chạm điểm cuối (tháng đang xem,
                    // sát mép phải) là hộp lòi khỏi màn hình và mất chữ —
                    // thấy trên máy ảo 411dp, không test nào bắt được vì
                    // tooltip vẽ trong canvas của thư viện.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          theoThuChi
                              ? '${s.barIndex == 0 ? 'Thu' : 'Chi'} ${rutGon(s.y)}'
                              : '${tenCua(chon[s.barIndex])} ${rutGon(s.y)}',
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
                // fl_chart là `FlClipData.none()` và đường tràn khỏi thẻ
                // (bẫy 4.17 `ANALYTICS_FEATURE.md`, chỉ lộ trên máy thật).
                // Đường danh mục có dải hẹp hơn nên dễ vấp hơn bản hai đường.
                // Cắt cả bốn mép; chấm kỳ đầu/cuối không mất nửa nhờ trục
                // ngang đã nới (G79 — `vertical()` của G55 vẫn cắt trái/phải).
                clipData: const FlClipData.all(),
                lineBarsData: theoThuChi
                    ? [
                        _duong(
                          [
                            for (var i = 0; i < chuoi.length; i++)
                              FlSpot(i.toDouble(), chuoi[i].tong.thu),
                          ],
                          AppColors.income,
                        ),
                        _duong(
                          [
                            for (var i = 0; i < chuoi.length; i++)
                              FlSpot(i.toDouble(), chuoi[i].tong.chi),
                          ],
                          AppColors.expense,
                        ),
                      ]
                    : [
                        for (final id in chon)
                          _duong(
                            [
                              for (var i = 0;
                                  i < tk.chuoiDanhMuc[id]!.length;
                                  i++)
                                FlSpot(i.toDouble(),
                                    giaTri(tk.chuoiDanhMuc[id]![i])),
                            ],
                            mauCua(dong[id]),
                          ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thứ tự trong `lineBarsData` **là** thứ tự `barIndex` của tooltip: đường
  /// thu phải đứng trước để nhãn "Thu"/"Chi" không đổi chỗ cho nhau.
  static LineChartBarData _duong(List<FlSpot> diem, Color mau) =>
      LineChartBarData(
        spots: diem,
        isCurved: true,
        curveSmoothness: 0.25,
        // Đường cong nội suy có thể vọt xuống dưới 0 giữa hai điểm, vẽ ra một
        // tháng "âm tiền" không có thật.
        preventCurveOverShooting: true,
        color: mau,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3.5,
            color: mau,
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
              mau.withValues(alpha: 0.25),
              mau.withValues(alpha: 0.0),
            ],
          ),
        ),
      );
}

/// Bộ chọn danh mục của khối xu hướng — A8 #7, chọn **nhiều** (từ 2026-09-14;
/// bản đầu là dropdown chọn một).
///
/// Hàng chip cuộn ngang **tại chỗ** — không màn mới, không bottom sheet — cố
/// ý. Trang này nằm trong `StatefulShellRoute`, và `push` một route trong
/// shell từ chỗ khác đã từng làm app chết màn đỏ (bẫy 7.8
/// `NOTIFICATION_FEATURE.md`).
///
/// Chỉ liệt kê danh mục **có phát sinh trong sáu tháng** đang vẽ: liệt kê tất
/// cả là bắt người dùng lướt qua hàng chục chip để tìm ra một đường phẳng
/// bằng 0.
///
/// Đủ trần `kToiDaDuongXuHuong` thì chip chưa bật bị **khoá** (`onSelected`
/// null) — người dùng thấy được vì sao, thay vì bấm mà không có gì xảy ra.
/// Chốt thật nằm ở cubit; khoá ở đây chỉ để nhìn thấy.
class ChonDanhMucXuHuong extends StatelessWidget {
  final ThongKeKy tk;
  final Set<String> dangChon;
  const ChonDanhMucXuHuong(
      {super.key, required this.tk, required this.dangChon});

  @override
  Widget build(BuildContext context) {
    // Tên tra từ cả `danhMuc` (chi) lẫn các nhóm (thu, vay/nợ) — nếu không
    // thì danh mục thu có chuỗi mà không có tên, và hàng chip bỏ sót nó.
    final ten = <String, String>{};
    for (final d in tk.danhMuc) {
      if (d.categoryId != null) ten[d.categoryId!] = d.ten;
    }
    for (final ds in tk.danhMucTheoLat.values) {
      for (final d in ds) {
        if (d.categoryId != null) ten[d.categoryId!] = d.ten;
      }
    }
    final id = [
      for (final k in tk.chuoiDanhMuc.keys)
        if (k != null && ten.containsKey(k)) k,
    ]..sort((a, b) => ten[a]!.toLowerCase().compareTo(ten[b]!.toLowerCase()));

    if (id.isEmpty) return const SizedBox.shrink();

    final dayTran = dangChon.length >= kToiDaDuongXuHuong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in id)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipDanhMuc(
                    chipKey: Key('chip-xu-huong-$k'),
                    ten: ten[k]!,
                    mau: mauCua(tk.dongCua(k)),
                    dangBat: dangChon.contains(k),
                    // Đang bật thì luôn tắt được; chưa bật mà đủ trần thì khoá.
                    onChon: (!dangChon.contains(k) && dayTran)
                        ? null
                        : () => context
                            .read<AnalyticsCubit>()
                            .batTatDanhMucXuHuong(k),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn tối đa $kToiDaDuongXuHuong danh mục · Bỏ chọn hết để xem Thu/Chi',
          // G78 (2026-10-07): ở màn hẹp (320 dp) chữ phụ này từng cụt "…" — nay xuống tối đa hai dòng.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Một chip danh mục của hàng chọn: chấm màu + tên, đổi nền khi bật.
///
/// Bọc `FilterChip` để test tìm được `onSelected == null` (chip bị khoá) mà
/// không phải đọc màu.
class ChipDanhMuc extends StatelessWidget {
  /// Đặt lên chính `FilterChip` (không phải widget bọc) để widget test
  /// `find.byKey` rồi đọc `onSelected` được.
  final Key chipKey;
  final String ten;
  final Color mau;
  final bool dangBat;
  final VoidCallback? onChon;
  const ChipDanhMuc({
    super.key,
    required this.chipKey,
    required this.ten,
    required this.mau,
    required this.dangBat,
    required this.onChon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: chipKey,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
      ),
      // Tên danh mục dài tới 200 ký tự (`DoRongCot`), phải cắt được ở 411dp.
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: dangBat ? FontWeight.w600 : FontWeight.w500,
        color: dangBat ? AppColors.primary : AppColors.textSecondary,
      ),
      selected: dangBat,
      showCheckmark: false,
      selectedColor: mau.withValues(alpha: 0.16),
      backgroundColor: Colors.white,
      side: BorderSide(color: dangBat ? mau : AppColors.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: onChon == null ? null : (_) => onChon!(),
    );
  }
}

class ChuGiaiDuong extends StatelessWidget {
  final Color mau;
  final String ten;
  const ChuGiaiDuong({super.key, required this.mau, required this.ten});

  @override
  Widget build(BuildContext context) {
    return Row(
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
}

// ── Donut ─────────────────────────────────────────────────────────────────

/// Vòng tròn "Cơ cấu theo danh mục" — A8 #3.
///
/// Ba chip *Chi | Thu | Vay-nợ* chọn nhóm; vòng tròn vẽ các danh mục **bên
/// trong** nhóm ấy (top 4 + "Khác"), và danh sách cuối trang đi theo cùng lựa
/// chọn nên hai khối luôn nói cùng một con số.
///
/// Mức gốc ba lát theo phân loại (A8 #2) **đã bỏ** ngày 2026-09-14 — người
/// dùng chốt. `theoPhanLoai()` ở tầng domain vẫn giữ: nó là nguồn duy nhất
/// cho biết nhóm nào có phát sinh, tức chip nào được hiện.
///
/// ⚠️ Nhóm "Chi" ở đây **không bằng** con số "Tổng chi" của thẻ đầu trang:
/// phần chi gắn danh mục vay/nợ đã sang nhóm Vay/nợ. Ba nhóm phải rời nhau
/// thì tỷ trọng mới có nghĩa — xem §2.1 spec
/// `2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc-design.md`.
// ── Bốn khối mượn từ trang Xuất báo cáo (P2, 2026-09-15) ──────────────────
//
// Phép tính nằm trọn ở bốn hàm thuần của `bao_cao_xuat.dart`, dùng chung với
// trang Báo cáo — ở đây chỉ có việc vẽ. Khuôn thẻ và cách xếp chữ chép từ
// `report_preview_page.dart` để hai trang trông như một; riêng tiêu đề thì theo
// kiểu của trang này (18px đậm) chứ không phải nhãn in hoa của tờ báo cáo.

/// ⚠️ **Cột số tiền phải là `Expanded`, không phải `Flexible`.**
///
/// Cả hai đều mang `flex: 1` nên chia đôi chỗ trống như nhau — khác biệt nằm ở
/// chỗ `Flexible` để con giữ bề rộng tự nhiên, và `MainAxisAlignment.start` đẩy
/// phần thừa về **cuối hàng**. Mỗi hàng thừa một kiểu, nên mép phải răng cưa:
/// đo được **26,5px** lệch giữa hai dòng của cùng một khối. `Expanded` cho con
/// chiếm trọn suất của nó, và khi ấy `alignment: Alignment.centerRight` mới đẩy
/// được chữ ra sát mép. Không mất chỗ nào của cột trái — tỉ lệ chia vẫn 1:1.
///
/// Người dùng bắt được trên máy ảo 2026-09-15; có ca test so mép phải canh.
