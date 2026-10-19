/// Khối "khoi_du_bao" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/bao_cao_xuat.dart';
import '../../../domain/du_bao_dong_tien.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../../domain/uoc_tinh_chi_tuy_y.dart';
import 'chung.dart';

/// Khối "Dự báo 30 ngày tới" — spec
/// `docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md` §5.3; màn
/// Stitch `732587777370466098aa98d17bd0cbd4` *"Thống kê - Dự báo 30 ngày
/// tới"* (2026-09-16).
///
/// Phép tính nằm trọn ở `du_bao_dong_tien.dart`; ở đây chỉ vẽ.
/// `StatefulWidget` **chỉ** để giữ cờ "đã mở hết" của danh sách — state cục
/// bộ, không qua cubit, vì nó không phải một lựa chọn cần sống sót qua lần
/// repository phát lại (khác `phanLoaiDangXem` và `danhMucXuHuong`).
///
/// `null` → `SizedBox.shrink()`: lớp **thứ hai** của chốt "không có ví thì ẩn
/// cả khối"; lớp thứ nhất là `if` ở `_than`. Cùng cách thác nước.
class KhoiDuBao extends StatefulWidget {
  final DuBaoDongTien? duBao;

  /// Tầng 3 (B4) — `null` là **im hẳn**. `required` dù nullable: khối được
  /// dựng ở HAI chỗ (kỳ rỗng và kỳ thường), quên truyền ở một chỗ là dòng ước
  /// tính biến mất đúng ở nhánh ấy, im lặng.
  final UocTinhChiTuyY? uocTinh;
  const KhoiDuBao({super.key, required this.duBao, required this.uocTinh});

  @override
  State<KhoiDuBao> createState() => _KhoiDuBaoState();
}

/// Số dòng cam kết khi chưa bấm "Xem thêm".
const int soDongCamKetThuGon = 5;


class _KhoiDuBaoState extends State<KhoiDuBao> {
  bool _moHet = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.duBao;
    if (d == null) return const SizedBox.shrink();

    final hien = _moHet ? d.camKet : d.camKet.take(soDongCamKetThuGon).toList();
    final conLai = d.camKet.length - hien.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dự báo 30 ngày tới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Từ hôm nay, không theo kỳ đang xem — chỉ tính hoá đơn và trích tự '
            'động đã đặt',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          BaConSoDuBao(d: d, uocTinh: widget.uocTinh),
          for (final v in d.viThieu) ...[
            const SizedBox(height: 12),
            DongViThieu(v: v),
          ],
          const SizedBox(height: 20),
          if (d.camKet.isEmpty)
            const Text(
              'Không có hoá đơn hay trích tự động nào trong 30 ngày tới',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else ...[
            SizedBox(height: 180, child: BieuDoDuBao(d: d)),
            const SizedBox(height: 8),
            ChuGiaiDuBao(coNganSach: d.coNganSach),
            const SizedBox(height: 12),
            for (final c in hien) DongCamKet(c: c),
            if (conLai > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _moHet = true),
                  child: Text('Xem thêm ($conLai)'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class BaConSoDuBao extends StatelessWidget {
  final DuBaoDongTien d;
  final UocTinhChiTuyY? uocTinh;
  const BaConSoDuBao({super.key, required this.d, required this.uocTinh});

  @override
  Widget build(BuildContext context) {
    final am = d.conTieuDuoc < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Còn tiêu được',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            chuoiTien(d.conTieuDuoc),
            maxLines: 1,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: am ? AppColors.expense : AppColors.income,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DongSo(nhan: 'Số dư hiện tại', giaTri: chuoiTien(d.soDuHienTai)),
        if (d.coNganSach) ...[
          const SizedBox(height: 4),
          DongSo(
            nhan: 'Nếu tiêu đúng ngân sách',
            giaTri: chuoiTien(d.conTieuDuocTheoNganSach),
          ),
        ],
        if (uocTinh case final u?) ...[
          const SizedBox(height: 4),
          // B4 tầng 3 — một dòng chữ PHỤ, không phải con số chính: đây là ước
          // tính, không được mượn độ tin của hai con số trên nó (quyết định
          // 16/09, spec B4 §1). Màn Stitch `7aa215e9…`: 12 px thường, xám,
          // không biểu tượng, không hộp.
          //
          // "Còn khoảng" trừ từ `conTieuDuocTheoNganSach` — tầng 3 chỉ tính
          // phần chưa tầng nào tính, nên nó đứng SAU cam kết và ngân sách;
          // không có ngân sách thì số ấy bằng `conTieuDuoc`. Hai số được phép
          // âm và KHÔNG kẹp — cùng luật với "Còn tiêu được".
          Text(
            'Nếu tiêu như thói quen (${u.soTuan} tuần gần nhất): chi thêm '
            'khoảng ${chuoiTien(u.thap)} – ${chuoiTien(u.cao)}, còn khoảng '
            '${chuoiTien(d.conTieuDuocTheoNganSach - u.cao)} – '
            '${chuoiTien(d.conTieuDuocTheoNganSach - u.thap)}.',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class DongSo extends StatelessWidget {
  final String nhan;
  final String giaTri;
  const DongSo({super.key, required this.nhan, required this.giaTri});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          giaTri,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class DongViThieu extends StatelessWidget {
  final ViThieu v;
  const DongViThieu({super.key, required this.v});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ví ${v.ten} thiếu ${chuoiTien(v.thieu)} để trả cam kết ngày '
              '${DateFormatter.formatDayMonth(v.ngay)}',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chú giải hai đường. Có trong màn Stitch và **cần thật**: nét đứt đi chéo
/// xuống mà không có nhãn thì người đọc không đoán được nó là kế hoạch tiêu
/// hay một dự báo thứ hai.
class ChuGiaiDuBao extends StatelessWidget {
  final bool coNganSach;
  const ChuGiaiDuBao({super.key, required this.coNganSach});

  @override
  Widget build(BuildContext context) {
    // `Wrap`, không phải `Row`: hai mục chú giải cạnh nhau tràn 55px ở 411dp
    // (bắt được bằng widget test ở đúng khổ ấy). Font của bộ test rộng gấp đôi
    // ngoài đời nên trên máy thật nó vừa — nhưng một hàng không co được là
    // đúng bẫy 4.4, và xuống dòng thì đọc vẫn tự nhiên.
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const MucChuGiai(
            mau: AppColors.primary, netDut: false, chu: 'Thực tế cam kết'),
        if (coNganSach)
          const MucChuGiai(
              mau: AppColors.warning, netDut: true, chu: 'Theo ngân sách'),
      ],
    );
  }
}

class MucChuGiai extends StatelessWidget {
  final Color mau;
  final bool netDut;
  final String chu;
  const MucChuGiai(
      {super.key, required this.mau, required this.netDut, required this.chu});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NetChuGiai(mau: mau, netDut: netDut),
        const SizedBox(width: 6),
        Text(chu,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class NetChuGiai extends StatelessWidget {
  final Color mau;
  final bool netDut;
  const NetChuGiai({super.key, required this.mau, required this.netDut});

  @override
  Widget build(BuildContext context) {
    if (!netDut) {
      return Container(width: 16, height: 3, color: mau);
    }
    return SizedBox(
      width: 16,
      height: 3,
      child: Row(
        children: [
          Container(width: 6, height: 3, color: mau),
          const SizedBox(width: 4),
          Container(width: 6, height: 3, color: mau),
        ],
      ),
    );
  }
}

/// Biểu đồ bậc thang tầng 1 + nét đứt "theo ngân sách".
///
/// Khối `fl_chart` thứ **tám** của app và là chỗ **đầu tiên** dùng
/// `isStepLineChart` — số dư không giảm dần đều, nó đứng yên rồi tụt một bậc
/// đúng ngày phải trả; vẽ đường cong là nói dối về hình dạng của tiền.
///
/// Tầng vẽ không test tự động được (bẫy 4.9): bậc thang, nét đứt, nhãn trục
/// và vùng tô chỉ kiểm được bằng mắt trên máy ảo 411dp.
class BieuDoDuBao extends StatelessWidget {
  final DuBaoDongTien d;
  const BieuDoDuBao({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final ds = d.chuoi;
    // Dải trục CO theo dữ liệu — phép tính và lý lẽ ở `daiTrucDuBao`, nơi nó
    // được test (kể cả ca dải hẹp làm bốn nhãn in ra cùng một chuỗi).
    final (:san, :buoc) = daiTrucDuBao([
      for (final p in ds) ...[
        p.chacChan,
        if (d.coNganSach) p.theoNganSach,
      ],
    ]);
    // Trần phải là ĐÚNG `san + 3 * buoc`, không phải con số đã đem chia: sai
    // số dấu phẩy động đủ để `rutGon` trả hai chuỗi khác nhau cho cùng một vị
    // trí, và hai nhãn in đè khít lên nhau (G39, bẫy 4.18).
    final maxY = san + buoc * 3;
    // Vạch 0 và vùng tô phần âm chỉ có nghĩa khi mốc 0 NẰM TRONG dải. Trục co
    // nên số dư dương lớn cho ra một khung hoàn toàn trên 0.
    final coAm = san < 0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: kSoNgayDuBao.toDouble(),
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
        // Vạch 0 chỉ có nghĩa khi dải có phần âm; khi mọi điểm đều dương thì
        // `san` đã bằng 0 và vạch trùng đúng mép dưới.
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
              interval: 10,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                // Bốn nhãn: 0 · 10 · 20 · 30. Hai biên trùng đúng mốc
                // `interval` nên không sinh nhãn thứ năm in đè (bẫy 4.18).
                if (i < 0 || i > kSoNgayDuBao || i % 10 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormatter.formatDayMonth(ds[i].ngay),
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
            // Bắt buộc: mặc định hộp tooltip tràn ra ngoài màn hình ở điểm
            // cuối, sát mép phải — thấy trên máy ảo 411dp.
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
        // Điểm ngoài dải vẫn được VẼ nếu không cắt — mặc định của fl_chart là
        // `FlClipData.none()` (bẫy 4.17).
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < ds.length; i++)
                FlSpot(i.toDouble(), ds[i].chacChan),
            ],
            isStepLineChart: true,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
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
            // Phần ÂM tô màu chi. Thiếu vế này thì vùng tô đổ suốt xuống đáy
            // và một ngày âm trông y hệt một ngày dương.
            aboveBarData: BarAreaData(
              show: coAm,
              applyCutOffY: true,
              cutOffY: 0,
              color: AppColors.expense.withValues(alpha: 0.18),
            ),
          ),
          if (d.coNganSach)
            LineChartBarData(
              spots: [
                for (var i = 0; i < ds.length; i++)
                  FlSpot(i.toDouble(), ds[i].theoNganSach),
              ],
              isCurved: false,
              color: AppColors.warning,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}

class DongCamKet extends StatelessWidget {
  final CamKet c;
  const DongCamKet({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final laHoaDon = c.loai == LoaiCamKet.hoaDon;
    final mau = laHoaDon ? AppColors.expense : AppColors.income;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              laHoaDon ? Icons.receipt_long : Icons.savings,
              size: 18,
              color: mau,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.formatDayMonth(c.ngay)} · ${c.tenVi ?? 'Ví đã xoá'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${chuoiTien(c.soTien)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.expense,
                ),
              ),
              if (c.quaHan)
                const NhanNho(chu: 'Quá hạn', mau: AppColors.expense)
              else if (c.laKyChieu)
                const NhanNho(chu: 'Dự kiến', mau: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class NhanNho extends StatelessWidget {
  final String chu;
  final Color mau;
  const NhanNho({super.key, required this.chu, required this.mau});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        chu,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: mau),
      ),
    );
  }
}
