import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/analytics_repository.dart';
import '../../domain/thong_ke_thang.dart';
import '../bloc/analytics_cubit.dart';

/// Trang Phân tích — bố cục theo màn Stitch "Analytics Dashboard".
///
/// Trước 2026-09-08 trang này là **số cứng**: mọi con số là hằng số, kể cả
/// tháng đang hiện ("T6 2026" khi đang là tháng 9). Nay mọi thứ đi qua
/// [AnalyticsCubit]; widget không tự cộng gì cả.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ĐĂNG KÝ với AuthBloc, không chỉ đọc một phát — cùng lỗi G17 ở trang Mục
    // tiêu: `currentAccountIdOrNull` dùng `context.read` bên trong (không đăng
    // ký), và `BlocProvider.create` chỉ chạy MỘT lần. Phiên tới muộn thì cubit
    // nhận `null` rồi không bao giờ hỏi lại. `ValueKey(idaccount)` buộc dựng
    // lại provider khi phiên đổi.
    context.watch<AuthBloc>();
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<AnalyticsCubit>(
      key: ValueKey(idaccount),
      create: (_) => sl<AnalyticsCubit>()..xem(idaccount),
      child: const _NoiDung(),
    );
  }
}

/// Màu lát "Khác" và màu dự phòng khi danh mục không có màu.
const Color _mauKhac = Color(0xFF586062);
const Color _mauXanhLa = Color(0xFF2E6B27);

/// Màu của một dòng. Ba ca không có màu thật phải ra BA màu khác nhau: trên
/// máy thật, "Chưa phân loại" và "Danh mục đã xoá" từng cùng xanh dự phòng nên
/// hai lát donut không phân biệt được — test không bắt vì nó không nhìn màu.
Color _mauCua(DongDanhMuc? d) {
  if (d == null || d.categoryId == null) return AppColors.textSecondary;
  if (d.mauHex == null) return AppColors.outline; // id có, hàng không còn
  return categoryColorFrom(d.mauHex, fallback: _mauXanhLa);
}

/// Số dòng danh mục dựng thẳng trên trang; phần còn lại vào bảng "Xem tất cả".
/// Cùng lý do với lịch sử mục tiêu: danh sách ở đây không ảo hoá.
const int _soDongToiDa = 5;

class _NoiDung extends StatelessWidget {
  const _NoiDung();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
          builder: (context, state) {
            return SingleChildScrollView(
              // Đệm đáy 96 chứ không 8: FAB của MainShell đè lên dòng cuối
              // (thấy trên máy thật — chú giải "Khác" nằm dưới nút cộng).
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(state: state),
                  const SizedBox(height: 24),
                  ..._than(context, state),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _than(BuildContext context, AnalyticsState state) {
    switch (state) {
      case AnalyticsLoaded(:final thongKe):
        if (thongKe.rong) {
          return [_Rong(nam: thongKe.nam, thang: thongKe.thang)];
        }
        return [
          _KhoiTong(tk: thongKe),
          const SizedBox(height: 24),
          // Thứ tự câu hỏi: bao nhiêu → xu hướng ra sao → tiền đi đâu.
          _KhoiXuHuong(chuoi: thongKe.chuoi),
          const SizedBox(height: 24),
          _KhoiDonut(tk: thongKe),
          const SizedBox(height: 24),
          _DanhSachDanhMuc(tk: thongKe),
        ];
      case AnalyticsError(:final message):
        return [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ];
      default:
        return const [
          Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
    }
  }
}

// ── Định dạng dùng chung ──────────────────────────────────────────────────

String _dong(double x) => '${CurrencyFormatter.formatSoThoi(x.round())}đ';

/// `T9 2026` — nhãn ngắn của một tháng.
String _nhanThang(int nam, int thang) => 'T$thang $nam';

int _thangTruoc(int thang) => thang == 1 ? 12 : thang - 1;

/// "Tăng 25% so với T8" / "Giảm 5% so với T8" / "Không có dữ liệu T8".
///
/// `null` là tháng trước bằng 0: không in "tăng ∞%" hay "tăng 100%" — cả hai
/// đều là số bịa.
String _soVoiThangTruoc(double? phanTram, int thang) {
  final t = _thangTruoc(thang);
  if (phanTram == null) return 'Không có dữ liệu T$t';
  final tu = phanTram >= 0 ? 'Tăng' : 'Giảm';
  return '$tu ${phanTram.abs().round()}% so với T$t';
}

// ── Đầu trang ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AnalyticsState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    // Trái co, phải giữ: ở 411dp thì "Thống kê" + nút xuất + ô chọn tháng
    // không đủ chỗ (tràn 53px trên máy ảo). Tiêu đề nhường trước vì nó là
    // thứ người dùng đã biết; ô chọn tháng mới là thứ họ cần đọc được.
    return Row(
      children: [
        const Icon(Icons.menu, color: AppColors.textSecondary, size: 28),
        const SizedBox(width: 12),
        // Tỉ lệ 1:2, KHÔNG phải Expanded + Flexible bằng nhau: flex chia chỗ
        // trống theo hệ số bất kể con cần bao nhiêu, nên bản đầu cho tiêu đề
        // một nửa trong khi nó chỉ cần ~95px — và ô tháng bị cắt thành
        // "Tháng này (…" trên máy thật dù test 411dp xanh (font test khác
        // font thật, bẫy 4.4 `ANALYTICS_FEATURE.md`).
        const Flexible(
          flex: 2,
          child: Text(
            'Thống kê',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        // Nút gọn 40px thay vì 48px mặc định: ở 411dp thật, tiêu đề 24px +
        // nút + nhãn tháng đầy đủ thiếu đúng vài chục px, và flex chia kiểu gì
        // cũng phải cắt một trong hai chữ. Bớt chỗ chiếm cố định mới là cách.
        IconButton(
          icon: const Icon(Icons.download, color: AppColors.primary),
          onPressed: () => context.push('/analytics/export'),
          tooltip: 'Xuất Báo cáo',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Flexible(flex: 3, child: _ChonThang(state: state)),
      ],
    );
  }
}

/// Ô chọn tháng. Nhãn "Tháng này (T9 2026)" chỉ khi tháng đang xem là tháng
/// hiện tại; tháng đã qua thì "T8 2026" — giữ "Tháng này" cho một tháng đã
/// qua là nói dối về thứ đang hiện.
class _ChonThang extends StatelessWidget {
  final AnalyticsState state;
  const _ChonThang({required this.state});

  @override
  Widget build(BuildContext context) {
    final (nhan, cacThang) = switch (state) {
      AnalyticsLoaded(:final thongKe, :final cacThang) => (
          thongKe.nam == cacThang.first.nam &&
                  thongKe.thang == cacThang.first.thang
              ? 'Tháng này (${_nhanThang(thongKe.nam, thongKe.thang)})'
              : _nhanThang(thongKe.nam, thongKe.thang),
          cacThang,
        ),
      AnalyticsLoading(:final nam, :final thang) => (
          _nhanThang(nam, thang),
          const <({int nam, int thang})>[],
        ),
      _ => ('Tháng này', const <({int nam, int thang})>[]),
    };

    final o = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              nhan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );

    if (cacThang.isEmpty) return o;
    return PopupMenuButton<({int nam, int thang})>(
      tooltip: 'Chọn tháng',
      onSelected: (t) =>
          context.read<AnalyticsCubit>().chonThang(t.nam, t.thang),
      itemBuilder: (_) => [
        for (final t in cacThang)
          PopupMenuItem(value: t, child: Text(_nhanThang(t.nam, t.thang))),
      ],
      child: o,
    );
  }
}

// ── Rỗng ──────────────────────────────────────────────────────────────────

class _Rong extends StatelessWidget {
  final int nam;
  final int thang;
  const _Rong({required this.nam, required this.thang});

  @override
  Widget build(BuildContext context) {
    // Nói rỗng chứ không vẽ toàn số 0: donut của một tháng rỗng là một vòng
    // tròn xám với chữ "0" ở giữa — trông như lỗi tải dữ liệu.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(
              'Chưa có giao dịch nào trong ${_nhanThang(nam, thang)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ba thẻ tổng ───────────────────────────────────────────────────────────

class _KhoiTong extends StatelessWidget {
  final ThongKeThang tk;
  const _KhoiTong({required this.tk});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TheTong(
                title: 'Tổng thu',
                amount: '+${_dong(tk.tong.thu)}',
                diff: _soVoiThangTruoc(tk.thuSoVoiTruoc, tk.thang),
                icon: Icons.arrow_upward,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TheTong(
                title: 'Tổng chi',
                amount: '-${_dong(tk.tong.chi)}',
                diff: _soVoiThangTruoc(tk.chiSoVoiTruoc, tk.thang),
                icon: Icons.arrow_downward,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TheConLai(tk: tk),
      ],
    );
  }
}

class _TheTong extends StatelessWidget {
  final String title;
  final String amount;
  final String diff;
  final IconData icon;
  final Color color;

  const _TheTong({
    required this.title,
    required this.amount,
    required this.diff,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diff,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _TheConLai extends StatelessWidget {
  final ThongKeThang tk;
  const _TheConLai({required this.tk});

  @override
  Widget build(BuildContext context) {
    final conLai = tk.tong.conLai;
    // Thanh = phần thu còn giữ được. Thu bằng 0 thì không có gì để chia.
    final tiLe = tk.tong.thu > 0 ? (conLai / tk.tong.thu).clamp(0.0, 1.0) : 0.0;
    // Số ÂM hiện là số âm, không kẹp về 0: người dùng mở trang này chính là
    // để biết tháng này đã âm.
    final chu = conLai < 0 ? '-${_dong(-conLai)}' : _dong(conLai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _theTrang(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số dư còn lại',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chu,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: conLai < 0 ? const Color(0xFFFFB3AE) : Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: tiLe,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF94F990), // secondary-fixed của Stitch
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Xu hướng theo thời gian ───────────────────────────────────────────────

/// Sáu tháng gần nhất, hai đường: thu và chi.
///
/// **Cố ý lệch bản Stitch.** Màn "Analytics Dashboard" chỉ có donut, tức chỉ
/// trả lời *tiền đi đâu*; câu *đang tăng hay đang giảm* không có chỗ nào trên
/// trang trả lời. Khối này nằm giữa khối tổng và donut vì đó là thứ tự câu
/// hỏi: bao nhiêu → xu hướng ra sao → đi vào đâu. Đừng "sửa lại cho khớp
/// Stitch".
class _KhoiXuHuong extends StatelessWidget {
  final List<DiemThoiGian> chuoi;
  const _KhoiXuHuong({required this.chuoi});

  @override
  Widget build(BuildContext context) {
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (chuoi.isEmpty) return const SizedBox.shrink();

    var dinh = 0.0;
    for (final d in chuoi) {
      if (d.tong.thu > dinh) dinh = d.tong.thu;
      if (d.tong.chi > dinh) dinh = d.tong.chi;
    }
    // Trần cao hơn đỉnh để đường không dính mép trên. Sáu tháng rỗng sạch thì
    // `dinh` bằng 0 và mọi phép chia thang đo sau đây sẽ hỏng, nên đặt 1.
    final maxY = dinh <= 0 ? 1.0 : dinh * 1.15;
    final buoc = maxY / 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cùng lý do với tiêu đề donut: Text đứng trong Row không co được.
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Xu hướng 6 tháng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ChuGiaiDuong(mau: AppColors.income, ten: 'Thu'),
              _ChuGiaiDuong(mau: AppColors.expense, ten: 'Chi'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (chuoi.length - 1).toDouble(),
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
                        // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới.
                        if (i < 0 || i >= chuoi.length) {
                          return const SizedBox.shrink();
                        }
                        // Tháng đang xem là điểm cuối — in đậm để biết mình
                        // đang đứng ở đâu trên trục.
                        final cuoi = i == chuoi.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'T${chuoi[i].thang}',
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

class _ChuGiaiDuong extends StatelessWidget {
  final Color mau;
  final String ten;
  const _ChuGiaiDuong({required this.mau, required this.ten});

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

class _KhoiDonut extends StatelessWidget {
  final ThongKeThang tk;
  const _KhoiDonut({required this.tk});

  @override
  Widget build(BuildContext context) {
    if (tk.chiTheoDanhMuc.isEmpty) return const SizedBox.shrink();
    final lat = topVaKhac(tk.chiTheoDanhMuc);

    final mau = [
      for (final l in lat)
        l.laKhac ? _mauKhac : _mauCua(tk.dongCua(l.categoryId)),
    ];
    final ten = [
      for (final l in lat)
        l.laKhac ? 'Khác' : (tk.dongCua(l.categoryId)?.ten ?? 'Chưa phân loại'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        children: [
          // Không bọc trong Row: một Text đứng trong Row không co được, và ở
          // font đơn cách của bộ test nó tràn 71px (test 411dp bắt được).
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Chi tiêu theo hạng mục',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 32,
              runSpacing: 24,
              children: [
                _Donut(lat: lat, mau: mau, tongChi: tk.tong.chi),
                SizedBox(
                  width: 180,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < lat.length; i++)
                        _ChuGiai(mau: mau[i], nhan: ten[i]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final List<ChiTheoDanhMuc> lat;
  final List<Color> mau;
  final double tongChi;

  const _Donut({required this.lat, required this.mau, required this.tongChi});

  @override
  Widget build(BuildContext context) {
    // Mỗi lát hai stop cùng màu để có cạnh sắc; tổng tỉ lệ có thể hụt 1.0 vì
    // làm tròn, phần hụt tô màu nền để vòng không hở.
    final stops = <double>[];
    final colors = <Color>[];
    var dau = 0.0;
    for (var i = 0; i < lat.length; i++) {
      final cuoi = (dau + lat[i].tiLe).clamp(0.0, 1.0);
      stops
        ..add(dau)
        ..add(cuoi);
      colors
        ..add(mau[i])
        ..add(mau[i]);
      dau = cuoi;
    }
    if (dau < 1.0) {
      stops
        ..add(dau)
        ..add(1.0);
      colors
        ..add(AppColors.surfaceContainer)
        ..add(AppColors.surfaceContainer);
    }

    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(stops: stops, colors: colors),
            ),
          ),
          Container(
            width: 154,
            height: 154,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TỔNG CHI',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rutGon(tongChi),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChuGiai extends StatelessWidget {
  final Color mau;
  final String nhan;
  const _ChuGiai({required this.mau, required this.nhan});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: mau,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            nhan,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chi tiết danh mục ─────────────────────────────────────────────────────

class _DanhSachDanhMuc extends StatelessWidget {
  final ThongKeThang tk;
  const _DanhSachDanhMuc({required this.tk});

  @override
  Widget build(BuildContext context) {
    if (tk.danhMuc.isEmpty) return const SizedBox.shrink();
    final hien = tk.danhMuc.take(_soDongToiDa).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CHI TIẾT DANH MỤC',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (tk.danhMuc.length > _soDongToiDa)
              TextButton(
                onPressed: () => _moBang(context),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: AppColors.income,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final d in hien) _DongDanhMuc(d: d),
      ],
    );
  }

  /// Bottom sheet, không phải trang mới — cùng lý do với lịch sử mục tiêu:
  /// route mới phải trả lời "nằm trong shell không", đặt nhầm là màn đỏ.
  void _moBang(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Chi tiết danh mục',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            for (final d in tk.danhMuc) _DongDanhMuc(d: d),
          ],
        ),
      ),
    );
  }
}

class _DongDanhMuc extends StatelessWidget {
  final DongDanhMuc d;
  const _DongDanhMuc({required this.d});

  @override
  Widget build(BuildContext context) {
    final mau = _mauCua(d);
    // Có ngân sách thì đo theo hạn mức; không thì theo tổng chi — và ĐỔI nhãn,
    // không hiện "0% ngân sách" cho một hạn mức không tồn tại.
    final tiLe = d.coNganSach ? d.tiLeNganSach! : d.tiLeTongChi;
    final nhan = d.coNganSach
        ? '${(tiLe * 100).round()}% ngân sách'
        : '${(tiLe * 100).round()}% tổng chi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _theTrang(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(categoryIconFor(d.icon), color: mau),
          ),
          const SizedBox(width: 16),
          // Expanded + ellipsis: bản Stitch chép sang đặt tên trong một Row
          // không giới hạn bề rộng, tên dài tràn 521px qua cột số tiền — test
          // 411dp bắt được đúng ca ấy.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nhan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _dong(d.soTien),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: tiLe.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: mau,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _theTrang({Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
