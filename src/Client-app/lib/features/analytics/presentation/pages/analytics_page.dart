import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/category/category_classify.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/analytics_repository.dart';
import '../../domain/phan_loai_dong_tien.dart';
import '../../domain/thong_ke_thang.dart';
import '../bloc/analytics_cubit.dart';

/// Trang Phân tích — bố cục theo màn Stitch `c2a2b615c9514ca180b28d189b2ea197`
/// *"Thống kê - Xu hướng 6 tháng & Cơ cấu dòng tiền"* (2026-09-14).
///
/// ⚠️ **Không** phải màn cũ `a228fa69…` *"FlowMoney Analytics Dashboard"*: nó
/// vẫn còn trong dự án Stitch nhưng đã lỗi thời, vì `edit_screens` **tạo màn
/// mới** chứ không sửa màn được chọn.
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
      case AnalyticsLoaded(
          :final thongKe,
          :final phanLoaiDangXem,
          :final danhMucXuHuong
        ):
        if (thongKe.rong) {
          return [_Rong(nam: thongKe.nam, thang: thongKe.thang)];
        }
        return [
          _KhoiTong(tk: thongKe),
          const SizedBox(height: 24),
          // Thứ tự câu hỏi: bao nhiêu → xu hướng ra sao → tiền đi đâu.
          _KhoiXuHuong(tk: thongKe, danhMucXuHuong: danhMucXuHuong),
          const SizedBox(height: 24),
          _KhoiDonut(tk: thongKe, phanLoaiDangXem: phanLoaiDangXem),
          const SizedBox(height: 24),
          _DanhSachDanhMuc(tk: thongKe, phanLoai: phanLoaiDangXem),
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
/// Biểu đồ đường sáu tháng — A8 #6 (hai đường Thu/Chi) và A8 #7 (một đường cho
/// một danh mục, chọn bằng dropdown).
///
/// ⓘ Khối này từng **lệch Stitch có chủ ý** (mục 3.12 `ANALYTICS_FEATURE.md`):
/// tra cả 35 màn ngày 2026-09-08, không màn nào có biểu đồ đường. Từ 2026-09-14
/// nó **đã có** trên Stitch — màn `c2a2b615c9514ca180b28d189b2ea197` — nên lý
/// do lệch đã hết hiệu lực.
class _KhoiXuHuong extends StatelessWidget {
  final ThongKeThang tk;

  /// `null` là hai đường Thu/Chi.
  final String? danhMucXuHuong;
  const _KhoiXuHuong({required this.tk, required this.danhMucXuHuong});

  @override
  Widget build(BuildContext context) {
    final dm = danhMucXuHuong;
    // Danh mục đã chọn có thể vừa biến mất; cubit đã dọn nhưng khung dựng lại
    // có thể tới trước — rơi về hai đường thay vì nổ.
    final chuoi = dm == null ? tk.chuoi : (tk.chuoiDanhMuc[dm] ?? tk.chuoi);
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (chuoi.isEmpty) return const SizedBox.shrink();

    // Một danh mục thường chỉ đi một chiều tiền, nên đường đơn vẽ tổng thu +
    // chi của nó. Riêng danh mục vay/nợ có cả hai chiều: cộng lại là "tổng tiền
    // đi qua danh mục", đúng câu hỏi "nó đang lớn lên hay nhỏ đi".
    double giaTri(DiemThoiGian d) => d.tong.thu + d.tong.chi;

    var dinh = 0.0;
    for (final d in chuoi) {
      if (dm == null) {
        if (d.tong.thu > dinh) dinh = d.tong.thu;
        if (d.tong.chi > dinh) dinh = d.tong.chi;
      } else if (giaTri(d) > dinh) {
        dinh = giaTri(d);
      }
    }
    // Trần cao hơn đỉnh để đường không dính mép trên. Sáu tháng rỗng sạch thì
    // `dinh` bằng 0 và mọi phép chia thang đo sau đây sẽ hỏng, nên đặt 1.
    final maxY = dinh <= 0 ? 1.0 : dinh * 1.15;
    final buoc = maxY / 3;
    final dong = dm == null ? null : tk.dongCua(dm);
    final mauDon = _mauCua(dong);
    final tenDon = dong?.ten ?? 'Danh mục';

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
          _ChonDanhMucXuHuong(tk: tk, dangChon: dm),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: dm == null
                ? const [
                    _ChuGiaiDuong(mau: AppColors.income, ten: 'Thu'),
                    _ChuGiaiDuong(mau: AppColors.expense, ten: 'Chi'),
                  ]
                : [_ChuGiaiDuong(mau: mauDon, ten: tenDon)],
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
                          dm == null
                              ? '${s.barIndex == 0 ? 'Thu' : 'Chi'} ${rutGon(s.y)}'
                              : '$tenDon ${rutGon(s.y)}',
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
                // Đường đơn có dải hẹp hơn nên dễ vấp hơn bản hai đường.
                clipData: const FlClipData.all(),
                lineBarsData: dm == null
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
                        _duong(
                          [
                            for (var i = 0; i < chuoi.length; i++)
                              FlSpot(i.toDouble(), giaTri(chuoi[i])),
                          ],
                          mauDon,
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

/// Bộ chọn danh mục của khối xu hướng — A8 #7.
///
/// Chỉ liệt kê danh mục **có phát sinh trong sáu tháng** đang vẽ: liệt kê tất
/// cả là bắt người dùng cuộn qua hàng chục dòng để tìm ra một đường phẳng
/// bằng 0.
///
/// Là dropdown tại chỗ chứ không phải màn mới hay bottom sheet — cố ý. Trang
/// này nằm trong `StatefulShellRoute`, và `push` một route trong shell từ chỗ
/// khác đã từng làm app chết màn đỏ (bẫy 7.8 `NOTIFICATION_FEATURE.md`).
class _ChonDanhMucXuHuong extends StatelessWidget {
  final ThongKeThang tk;
  final String? dangChon;
  const _ChonDanhMucXuHuong({required this.tk, required this.dangChon});

  @override
  Widget build(BuildContext context) {
    // Tên tra từ cả `danhMuc` (chi) lẫn các lát (thu, vay/nợ) — nếu không thì
    // danh mục thu có chuỗi mà không có tên, và dropdown bỏ sót nó.
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

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: dangChon,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tất cả danh mục', overflow: TextOverflow.ellipsis),
            ),
            for (final k in id)
              DropdownMenuItem<String?>(
                value: k,
                // Tên danh mục dài tới 200 ký tự (`DoRongCot`), phải cắt được
                // ở 411dp.
                child: Text(ten[k]!, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) =>
              context.read<AnalyticsCubit>().chonDanhMucXuHuong(v),
        ),
      ),
    );
  }
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

/// Vòng tròn "Cơ cấu dòng tiền", **hai mức**.
///
/// - Mức gốc: ba lát theo `category.classify` — trả lời A8 #2.
/// - Chạm một lát: các danh mục bên trong lát ấy — trả lời A8 #3.
///
/// ⚠️ Lát "Chi" ở đây **không bằng** con số "Tổng chi" của thẻ đầu trang: phần
/// chi gắn danh mục vay/nợ đã sang lát Vay/nợ. Ba lát phải rời nhau thì tỷ
/// trọng mới có nghĩa — xem §2.1 spec
/// `2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc-design.md`.
class _KhoiDonut extends StatelessWidget {
  final ThongKeThang tk;
  final String? phanLoaiDangXem;
  const _KhoiDonut({required this.tk, required this.phanLoaiDangXem});

  @override
  Widget build(BuildContext context) {
    if (tk.latPhanLoai.isEmpty) return const SizedBox.shrink();
    final pl = phanLoaiDangXem;
    final v = pl == null ? _mucGoc() : _mucDanhMuc(pl);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        children: [
          Row(
            children: [
              if (pl != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      size: 20, color: AppColors.primary),
                  tooltip: 'Về cơ cấu dòng tiền',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () =>
                      context.read<AnalyticsCubit>().chonPhanLoai(null),
                ),
              // Một Text đứng trong Row không co được: bọc Expanded, nếu không
              // tên lát dài tràn (test 411dp bắt được).
              Expanded(
                child: Text(
                  v.tieuDe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
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
                _Donut(
                  lat: v.lat,
                  mau: v.mau,
                  nhan: v.nhanTam,
                  tong: v.tongTam,
                ),
                SizedBox(
                  width: 180,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < v.lat.length; i++)
                        _ChuGiai(
                          mau: v.mau[i],
                          nhan: v.ten[i],
                          // Chỉ mức gốc mới chạm được: mức danh mục không có
                          // tầng thứ ba để đi xuống.
                          onTap: pl == null
                              ? () => context
                                  .read<AnalyticsCubit>()
                                  .chonPhanLoai(tk.latPhanLoai[i].phanLoai)
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (pl == null) ...[
            const SizedBox(height: 16),
            const Text(
              'Chạm một lát để xem danh mục bên trong',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Ba lát theo phân loại.
  _NoiDungDonut _mucGoc() => (
        lat: [
          for (final l in tk.latPhanLoai)
            ChiTheoDanhMuc(
                categoryId: l.phanLoai, soTien: l.soTien, tiLe: l.tiLe),
        ],
        mau: [for (final l in tk.latPhanLoai) _mauLat(l.phanLoai)],
        ten: [for (final l in tk.latPhanLoai) tenLat(l.phanLoai)],
        tieuDe: 'Cơ cấu dòng tiền',
        nhanTam: 'TỔNG DÒNG TIỀN',
        tongTam: tk.latPhanLoai.fold<double>(0, (s, l) => s + l.soTien),
      );

  /// Danh mục bên trong một lát, vẫn top 4 + "Khác".
  _NoiDungDonut _mucDanhMuc(String pl) {
    final dong = tk.danhMucCua(pl);
    final tong = dong.fold<double>(0, (s, d) => s + d.soTien);
    final lat = topVaKhac([
      for (final d in dong)
        ChiTheoDanhMuc(
          categoryId: d.categoryId,
          soTien: d.soTien,
          tiLe: tong <= 0 ? 0 : d.soTien / tong,
        ),
    ]);
    final tra = {for (final d in dong) d.categoryId: d};
    return (
      lat: lat,
      mau: [
        for (final l in lat) l.laKhac ? _mauKhac : _mauCua(tra[l.categoryId]),
      ],
      ten: [
        for (final l in lat)
          l.laKhac ? 'Khác' : (tra[l.categoryId]?.ten ?? 'Chưa phân loại'),
      ],
      tieuDe: tenLat(pl),
      nhanTam: nhanTongCua(pl).toUpperCase(),
      tongTam: tong,
    );
  }
}

/// Mọi thứ khối donut cần vẽ ở một mức — gom lại để hai nhánh mức gốc và mức
/// danh mục trả về cùng một hình dạng.
typedef _NoiDungDonut = ({
  List<ChiTheoDanhMuc> lat,
  List<Color> mau,
  List<String> ten,
  String tieuDe,
  String nhanTam,
  double tongTam,
});

/// Màu của một lát phân loại. Ba màu phải khác nhau rõ — donut không có nhãn
/// trên lát, chỉ có chú giải bên cạnh.
Color _mauLat(String phanLoai) => switch (phanLoai) {
      'thu' => AppColors.income,
      kDebtClassify => AppColors.warning,
      _ => AppColors.expense,
    };

class _Donut extends StatelessWidget {
  final List<ChiTheoDanhMuc> lat;
  final List<Color> mau;

  /// Nhãn nhỏ ở tâm — "TỔNG DÒNG TIỀN" ở mức gốc, "TỔNG CHI"/"TỔNG THU"/
  /// "VAY/NỢ" khi đã mở một lát.
  final String nhan;
  final double tong;

  const _Donut({
    required this.lat,
    required this.mau,
    required this.nhan,
    required this.tong,
  });

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
                Text(
                  nhan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rutGon(tong),
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

  /// `null` là không chạm được — mức danh mục không có tầng thứ ba để đi xuống.
  final VoidCallback? onTap;
  const _ChuGiai({required this.mau, required this.nhan, this.onTap});

  @override
  Widget build(BuildContext context) {
    final noiDung = Row(
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
    if (onTap == null) return noiDung;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(padding: const EdgeInsets.all(2), child: noiDung),
    );
  }
}

// ── Chi tiết danh mục ─────────────────────────────────────────────────────

class _DanhSachDanhMuc extends StatelessWidget {
  final ThongKeThang tk;

  /// Lát đang mở; `null` là mức gốc (chi theo chiều tiền, như trước).
  final String? phanLoai;
  const _DanhSachDanhMuc({required this.tk, required this.phanLoai});

  /// Nguồn dòng: **đi theo donut** để hai khối luôn nói cùng một con số. Hai
  /// chỗ đọc hai nguồn khác nhau là donut nói 8.2M mà danh sách cộng ra 8.5M.
  List<DongDanhMuc> get _dong =>
      phanLoai == null ? tk.danhMuc : tk.danhMucCua(phanLoai!);

  /// Mẫu số của nhãn "% …" trong từng dòng.
  String get _nhomTiLe => phanLoai ?? 'chi';

  @override
  Widget build(BuildContext context) {
    final dong = _dong;
    if (dong.isEmpty) return const SizedBox.shrink();
    final hien = dong.take(_soDongToiDa).toList();

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
            if (dong.length > _soDongToiDa)
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
        for (final d in hien) _DongDanhMuc(d: d, phanLoai: _nhomTiLe),
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
            for (final d in _dong)
              _DongDanhMuc(d: d, phanLoai: _nhomTiLe),
          ],
        ),
      ),
    );
  }
}

class _DongDanhMuc extends StatelessWidget {
  final DongDanhMuc d;

  /// Lát chứa dòng này; quyết định mẫu số của nhãn "% …". Mặc định `'chi'` cho
  /// mức gốc, nơi danh sách vẫn là chi tiêu theo chiều tiền.
  final String phanLoai;
  const _DongDanhMuc({required this.d, this.phanLoai = 'chi'});

  @override
  Widget build(BuildContext context) {
    final mau = _mauCua(d);
    // Có ngân sách thì đo theo hạn mức; không thì theo tổng chi — và ĐỔI nhãn,
    // không hiện "0% ngân sách" cho một hạn mức không tồn tại.
    final tiLe = d.coNganSach ? d.tiLeNganSach! : d.tiLeTongChi;
    final nhan = d.coNganSach
        ? '${(tiLe * 100).round()}% ngân sách'
        : '${(tiLe * 100).round()}% ${nhanTongCua(phanLoai)}';

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
