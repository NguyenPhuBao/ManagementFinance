import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bao_cao_xuat.dart';

/// Màn **Xem trước báo cáo** — tờ báo cáo của một khoảng đã chốt.
///
/// Bố cục theo màn Stitch "Xem trước báo cáo - FlowMoney"
/// (`f0a0d1457401478596753a48531bc097`), sinh ngày 2026-09-09 theo design
/// system "Kinetic Finance" của chính dự án.
///
/// Trang này **không đọc CSDL**: [baoCao] đã dựng xong ở trang Xuất báo cáo.
/// Nhờ vậy nó kiểm được bằng widget test thuần, và nội dung không đổi dưới tay
/// người dùng khi họ đang đọc.
class ReportPreviewPage extends StatelessWidget {
  final BaoCao baoCao;

  /// Nhãn bộ lọc đang áp — "Tất cả ví" hoặc tên ví đã chọn.
  final String nhanVi;
  final String nhanDanhMuc;

  /// Định dạng tệp người dùng đã chọn ở trang trước. Lát 2c-1 chỉ **hiện** nó;
  /// việc sinh tệp là lát 2c-2.
  final String dinhDang;

  final DateTime lapNgay;

  const ReportPreviewPage({
    super.key,
    required this.baoCao,
    required this.nhanVi,
    required this.nhanDanhMuc,
    required this.dinhDang,
    required this.lapNgay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Xem trước báo cáo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _dauBaoCao(),
          if (baoCao.dongTien != null) ...[
            const SizedBox(height: 16),
            _khoiDongTien(baoCao.dongTien!),
          ],
          const SizedBox(height: 16),
          _baThe(),
          if (baoCao.rong) ...[
            const SizedBox(height: 16),
            _khiRong(),
          ] else ...[
            if (baoCao.chuoi.isNotEmpty) ...[
              const SizedBox(height: 16),
              _bieuDo(),
            ],
            const SizedBox(height: 16),
            _soLieuNhanh(),
            if (baoCao.theoDanhMuc.isNotEmpty) ...[
              const SizedBox(height: 16),
              _bangDanhMuc('CHI THEO DANH MỤC', baoCao.theoDanhMuc),
            ],
            if (baoCao.thuTheoDanhMuc.isNotEmpty) ...[
              const SizedBox(height: 16),
              _bangDanhMuc('THU THEO DANH MỤC', baoCao.thuTheoDanhMuc),
            ],
            if (baoCao.nganSach.isNotEmpty) ...[
              const SizedBox(height: 16),
              _khoiNganSach(),
            ],
            if (baoCao.theoVi.isNotEmpty) ...[
              const SizedBox(height: 16),
              _khoiTheoVi(),
            ],
            if (baoCao.topChi.isNotEmpty) ...[
              const SizedBox(height: 16),
              _khoiTopChi(),
            ],
            const SizedBox(height: 16),
            _danhSachGiaoDich(),
          ],
        ],
      ),
      bottomNavigationBar: _thanhDuoi(),
    );
  }

  Widget _the({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _nhanMuc(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF46464C),
          letterSpacing: 0.8,
        ),
      );

  Widget _dauBaoCao() => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _nhanMuc('BÁO CÁO TỔNG QUAN THU CHI')),
                const SizedBox(width: 8),
                Text(
                  'Lập ngày ${DateFormatter.formatDate(lapNgay)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Biên `to` MỞ: ngày cuối cùng NẰM TRONG báo cáo là `to - 1 ngày`.
            // Hiện thẳng `to` là tờ báo cáo tự nhận có dữ liệu của một ngày mà
            // nó không hề đếm.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${DateFormatter.formatDate(baoCao.from)} – '
                '${DateFormatter.formatDate(baoCao.to.subtract(const Duration(days: 1)))}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.account_balance_wallet_outlined, nhanVi),
                _chip(Icons.category_outlined, nhanDanhMuc),
              ],
            ),
          ],
        ),
      );

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3F46),
              ),
            ),
          ],
        ),
      );

  // `IntrinsicHeight` cho ba thẻ cao bằng nhau. Không có nó thì
  // `CrossAxisAlignment.stretch` trong `ListView` nhận chiều cao vô hạn và cả
  // trang chết — chiều dọc của ListView không bị chặn.
  Widget _baThe() => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _theTong('TỔNG THU', baoCao.tong.thu, AppColors.income,
                  phanTram: baoCao.thuSoVoiTruoc, tangLaTot: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _theTong('TỔNG CHI', baoCao.tong.chi, AppColors.expense,
                  phanTram: baoCao.chiSoVoiTruoc, tangLaTot: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _theTong(
                  'CÒN LẠI', baoCao.tong.conLai, AppColors.textPrimary),
            ),
          ],
        ),
      );

  /// [phanTram] là mức đổi so với **kỳ liền trước**; `null` khi kỳ trước bằng 0
  /// — khi ấy hiện dấu gạch chứ không hiện "100%" (một con số bịa, và người
  /// đọc sẽ tưởng kỳ trước có một nửa).
  ///
  /// [tangLaTot] quyết định màu chứ không quyết định mũi tên: thu tăng là tin
  /// tốt, chi tăng thì không.
  Widget _theTong(
    String nhan,
    double soTien,
    Color mau, {
    double? phanTram,
    bool tangLaTot = true,
  }) =>
      _the(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nhan,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            // Số hàng trăm triệu không vừa một phần ba màn 411dp — co lại chứ
            // đừng để tràn.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(soTien),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: mau,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                phanTram == null
                    ? '—'
                    : '${phanTram >= 0 ? '▲' : '▼'} '
                        '${phanTram.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: phanTram == null
                      ? AppColors.textSecondary
                      : ((phanTram >= 0) == tangLaTot
                          ? AppColors.income
                          : AppColors.expense),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _khiRong() => _the(
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Không có giao dịch nào trong khoảng đã chọn',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _bangDanhMuc(String tieuDe, List<DongDanhMucBaoCao> ds) => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _nhanMuc(tieuDe)),
                Text(
                  '${ds.length} danh mục',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final d in ds) _dongDanhMuc(d),
          ],
        ),
      );

  /// Khối **dòng tiền** — thứ biến tờ báo cáo thành một bản kê thay vì một
  /// đống số rời. Money Lover đặt nó ở trung tâm báo cáo của họ.
  ///
  /// Chỉ hiện khi [BaoCao.dongTien] khác `null`, tức khi báo cáo gộp mọi ví.
  Widget _khoiDongTien(DongTien dt) => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nhanMuc('DÒNG TIỀN TRONG KỲ'),
            const SizedBox(height: 14),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        dt.thayDoi >= 0
                            ? CurrencyFormatter.formatIncome(dt.thayDoi)
                            : CurrencyFormatter.formatExpense(dt.thayDoi),
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
            // App không lưu lịch sử số dư nên hai con số này là **suy ra**, và
            // người đọc có quyền biết điều đó: ví tạo giữa kỳ mang theo số dư
            // ban đầu KHÔNG phải là giao dịch, nên nó bị tính vào số dư đầu kỳ.
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

  /// Biểu đồ thu/chi trong kỳ. Cùng khuôn với khối "Xu hướng 6 tháng" của
  /// trang Phân tích (mục 3.11) — kể cả hai chốt chặn đã học được ở đó:
  /// `fitInside*` cho tooltip và `preventCurveOverShooting`.
  Widget _bieuDo() {
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

    return _the(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nhanMuc('THU CHI TRONG KỲ'),
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

  /// Thứ tự trong `lineBarsData` **là** `barIndex` của tooltip: đường thu phải
  /// đứng trước để nhãn "Thu"/"Chi" không đổi chỗ cho nhau.
  static LineChartBarData _duong(List<FlSpot> diem, Color mau) =>
      LineChartBarData(
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

  Widget _soLieuNhanh() {
    final s = baoCao.soLieu;
    return _the(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nhanMuc('SỐ LIỆU NHANH'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _oSoLieu(
                    'CHI MỖI NGÀY', CurrencyFormatter.format(s.chiMoiNgay)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _oSoLieu('SỐ GIAO DỊCH', '${baoCao.soGiaoDich}'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _oSoLieu(
                  'NGÀY CHI NHIỀU NHẤT',
                  s.ngayChiNhieuNhat == null
                      ? '—'
                      : DateFormatter.formatDate(s.ngayChiNhieuNhat!),
                  phu: s.ngayChiNhieuNhat == null
                      ? null
                      : CurrencyFormatter.format(s.chiNgayNhieuNhat),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _oSoLieu(
                  'KHOẢN CHI LỚN NHẤT',
                  s.khoanChiLonNhat?.tieuDe ?? '—',
                  phu: s.khoanChiLonNhat == null
                      ? null
                      : CurrencyFormatter.format(s.khoanChiLonNhat!.soTien),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _oSoLieu(String nhan, String giaTri, {String? phu}) => Column(
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
              giaTri,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (phu != null) ...[
            const SizedBox(height: 2),
            Text(
              phu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      );

  Widget _khoiNganSach() => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nhanMuc('NGÂN SÁCH KỲ NÀY'),
            const SizedBox(height: 14),
            for (final n in baoCao.nganSach)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.ten,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${CurrencyFormatter.format(n.daChi)} / '
                              '${CurrencyFormatter.format(n.hanMuc)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: n.tiLe.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerLow,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          n.vuot ? AppColors.expense : AppColors.income,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        n.vuot
                            ? 'Vượt ${CurrencyFormatter.format(-n.conLai)}'
                            : 'Còn ${CurrencyFormatter.format(n.conLai)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              n.vuot ? AppColors.expense : AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _khoiTheoVi() => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nhanMuc('PHÂN BỔ THEO VÍ'),
            const SizedBox(height: 8),
            for (final v in baoCao.theoVi)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.ten,
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
                            '${v.soGiaoDich} giao dịch',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _coDau(v.thu, thu: true),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                            Text(
                              _coDau(v.chi, thu: false),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _khoiTopChi() => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nhanMuc('TOP 5 KHOẢN CHI'),
            const SizedBox(height: 8),
            for (var i = 0; i < baoCao.topChi.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baoCao.topChi[i].tieuDe,
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
                            '${baoCao.topChi[i].tenDanhMuc} · '
                            '${DateFormatter.formatDate(baoCao.topChi[i].ngay)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(baoCao.topChi[i].soTien),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _dongDanhMuc(DongDanhMucBaoCao d) {
    final mau = d.categoryId == null
        ? AppColors.textSecondary
        : categoryColorFrom(d.mauHex, fallback: AppColors.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIconFor(d.icon), size: 18, color: mau),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Text(
                        CurrencyFormatter.format(d.soTien),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _phanTram(d.tiLe),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: d.tiLe.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(mau),
            ),
          ),
        ],
      ),
    );
  }

  /// Số tiền kèm dấu, nhưng **số 0 thì không mang dấu**: một ví không phát
  /// sinh khoản thu nào hiện "+0 ₫" trông như lỗi định dạng (thấy trên máy ảo
  /// 2026-09-09).
  static String _coDau(double soTien, {required bool thu}) {
    if (soTien == 0) return CurrencyFormatter.format(0);
    return thu
        ? CurrencyFormatter.formatIncome(soTien)
        : CurrencyFormatter.formatExpense(soTien);
  }

  /// `0.75` → `(75,0%)`. Dấu phẩy thập phân theo kiểu Việt, đồng bộ với phần
  /// còn lại của app.
  static String _phanTram(double tiLe) =>
      '(${(tiLe * 100).toStringAsFixed(1).replaceAll('.', ',')}%)';

  /// Khoá để test tìm **trong phạm vi khối này**: cùng một ngày hay cùng một
  /// số tiền nay còn xuất hiện ở "Số liệu nhanh", "Top 5 khoản chi" và "Phân bổ
  /// theo ví", nên `find.text` toàn trang không còn phân biệt được khối nào.
  Widget _danhSachGiaoDich() => KeyedSubtree(
        key: const Key('khoiGiaoDich'),
        child: _the(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _nhanMuc('DANH SÁCH GIAO DỊCH')),
                Text(
                  '${baoCao.soGiaoDich} giao dịch',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            for (final n in baoCao.nhom) ...[
              const SizedBox(height: 16),
              Text(
                DateFormatter.formatDate(n.ngay),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              for (final d in n.dong) _dongGiaoDich(d),
            ],
            ],
          ),
        ),
      );

  Widget _dongGiaoDich(DongGiaoDich d) {
    final laThu = d.loai == 'thu';
    final mau = d.categoryId == null
        ? AppColors.textSecondary
        : categoryColorFrom(d.mauHex, fallback: AppColors.outline);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIconFor(d.icon), size: 18, color: mau),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.tieuDe,
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
                  d.tenVi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                laThu
                    ? CurrencyFormatter.formatIncome(d.soTien)
                    : CurrencyFormatter.formatExpense(d.soTien),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: laThu ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thanhDuoi() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Định dạng: $dinhDang',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF46464C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // `Expanded` là **bắt buộc**, không phải để cho đẹp: theme của
              // app đặt `minimumSize: Size(double.infinity, 52)` cho mọi
              // `ElevatedButton`, nên nút đứng trần trong `Row` đòi bề ngang vô
              // hạn và làm **hỏng cả khung hình** — trang trắng trơn, không đỏ,
              // không một dòng lỗi nào trong logcat. Đã vấp thật 2026-09-09.
              Expanded(
                child:
                    // `onPressed: null` là **có chủ ý**: sinh tệp là lát 2c-2.
                    // Nút bấm được mà không ra tệp chính là kiểu "nút xuất chỉ
                    // hiện snackbar" mà lát này đang đi dọn.
                    ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text(
                    'Tải xuống',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

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
