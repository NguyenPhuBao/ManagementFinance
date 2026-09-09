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
          const SizedBox(height: 16),
          _baThe(),
          if (baoCao.rong) ...[
            const SizedBox(height: 16),
            _khiRong(),
          ] else ...[
            if (baoCao.theoDanhMuc.isNotEmpty) ...[
              const SizedBox(height: 16),
              _theoDanhMuc(),
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
              child: _theTong('TỔNG THU', baoCao.tong.thu, AppColors.income),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _theTong('TỔNG CHI', baoCao.tong.chi, AppColors.expense),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _theTong(
                  'CÒN LẠI', baoCao.tong.conLai, AppColors.textPrimary),
            ),
          ],
        ),
      );

  Widget _theTong(String nhan, double soTien, Color mau) => _the(
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

  Widget _theoDanhMuc() => _the(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _nhanMuc('CHI THEO DANH MỤC')),
                Text(
                  '${baoCao.theoDanhMuc.length} danh mục',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final d in baoCao.theoDanhMuc) _dongDanhMuc(d),
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

  /// `0.75` → `(75,0%)`. Dấu phẩy thập phân theo kiểu Việt, đồng bộ với phần
  /// còn lại của app.
  static String _phanTram(double tiLe) =>
      '(${(tiLe * 100).toStringAsFixed(1).replaceAll('.', ',')}%)';

  Widget _danhSachGiaoDich() => _the(
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
