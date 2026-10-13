import 'package:flutter/material.dart';

import '../../../category/presentation/widgets/category_visuals.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/xuat_tep_service.dart';
import '../../domain/bao_cao_xuat.dart';
import '../widgets/xem_truoc_bao_cao/bieu_do_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/dau_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_dong_tien_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_tong_quan_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/the_bao_cao.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

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

  /// Định dạng tệp người dùng đã chọn ở trang trước — `'PDF'` hoặc `'CSV'`.
  /// Nút "Tải xuống" chuyển thẳng giá trị này xuống `XuatTepService`.
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
          tooltip: 'Quay lại',
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
          DauBaoCao(
            baoCao: baoCao,
            nhanVi: nhanVi,
            nhanDanhMuc: nhanDanhMuc,
            lapNgay: lapNgay,
          ),
          if (baoCao.dongTien != null) ...[
            const SizedBox(height: 16),
            KhoiDongTienBaoCao(baoCao.dongTien!),
          ],
          const SizedBox(height: 16),
          BaTheBaoCao(baoCao: baoCao),
          // Cùng vị từ với tệp xuất (`xuat_tep.dart`) — hai bên từng nói khác
          // nhau đúng ở khối Ngân sách, G44.
          if (!inKhoiTheoKy(baoCao)) ...[
            const SizedBox(height: 16),
            const KhiRongBaoCao(),
          ] else ...[
            if (baoCao.chuoi.isNotEmpty) ...[
              const SizedBox(height: 16),
              BieuDoBaoCao(baoCao: baoCao),
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

  Widget _bangDanhMuc(String tieuDe, List<DongDanhMucBaoCao> ds) => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: NhanMucBaoCao(tieuDe)),
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

  Widget _soLieuNhanh() {
    final s = baoCao.soLieu;
    return TheBaoCao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NhanMucBaoCao('SỐ LIỆU NHANH'),
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
                  chu: true,
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

  Widget _oSoLieu(String nhan, String giaTri, {String? phu, bool chu = false}) =>
      Column(
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
          // Ô mang CHỮ (tiêu đề giao dịch) thì xuống dòng: co một dòng dài ~80 ký tự cho vừa là chữ tí hon không đọc
          // được (ảnh người dùng gửi 2026-10-05). Ô mang SỐ thì giữ một dòng, co lại khi chật.
          if (chu)
            Text(
              giaTri,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            )
          else
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

  Widget _khoiNganSach() => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('NGÂN SÁCH KỲ NÀY'),
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
                        Expanded(
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

  Widget _khoiTheoVi() => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('PHÂN BỔ THEO VÍ'),
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              coDauBaoCao(v.thu, thu: true),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                            Text(
                              coDauBaoCao(v.chi, thu: false),
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

  Widget _khoiTopChi() => TheBaoCao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NhanMucBaoCao('TOP 5 KHOẢN CHI'),
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
                    Expanded(
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
              Expanded(
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
                        phanTramBaoCao(d.tiLe),
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

  /// Khoá để test tìm **trong phạm vi khối này**: cùng một ngày hay cùng một
  /// số tiền nay còn xuất hiện ở "Số liệu nhanh", "Top 5 khoản chi" và "Phân bổ
  /// theo ví", nên `find.text` toàn trang không còn phân biệt được khối nào.
  Widget _danhSachGiaoDich() => KeyedSubtree(
        key: const Key('khoiGiaoDich'),
        child: TheBaoCao(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: NhanMucBaoCao('DANH SÁCH GIAO DỊCH')),
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
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.formatCoDau(d.soTien, thu: laThu),
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
                child: _NutTaiXuong(
                  baoCao: baoCao,
                  dinhDang: dinhDang,
                  nhanVi: nhanVi,
                  nhanDanhMuc: nhanDanhMuc,
                  lapNgay: lapNgay,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Nút "Tải xuống": sinh tệp rồi mở sheet chia sẻ/lưu của hệ điều hành.
///
/// Là widget **riêng và có state** để trang giữ nguyên `StatelessWidget`: chỉ
/// mỗi cái nút cần biết mình đang bận hay không.
class _NutTaiXuong extends StatefulWidget {
  final BaoCao baoCao;
  final String dinhDang;
  final String nhanVi;
  final String nhanDanhMuc;
  final DateTime lapNgay;

  const _NutTaiXuong({
    required this.baoCao,
    required this.dinhDang,
    required this.nhanVi,
    required this.nhanDanhMuc,
    required this.lapNgay,
  });

  @override
  State<_NutTaiXuong> createState() => _NutTaiXuongState();
}

class _NutTaiXuongState extends State<_NutTaiXuong> {
  bool _dangXuat = false;

  Future<void> _xuat() async {
    setState(() => _dangXuat = true);
    try {
      final noiLuu = await sl<XuatTepService>().xuat(
        widget.baoCao,
        dinhDang: widget.dinhDang,
        nhanVi: widget.nhanVi,
        nhanDanhMuc: widget.nhanDanhMuc,
        lapNgay: widget.lapNgay,
      );
      if (!mounted) return;
      // `null` nghĩa là tệp đi qua sheet chia sẻ chứ chưa nằm ở đâu cả — nói
      // "đã lưu" khi ấy là nói dối, và người dùng sẽ đi tìm một tệp không có.
      if (noiLuu != null) {
        baoNhanh('Đã lưu vào $noiLuu', loai: LoaiThongBao.xong);
      }
    } catch (e) {
      if (!mounted) return;
      // NÓI RA. Bấm "Tải xuống" mà không thấy gì thì người dùng sẽ bấm tiếp
      // mãi — im lặng là kiểu hỏng tệ nhất ở đây.
      baoNhanh('Không xuất được tệp: $e', loai: LoaiThongBao.loi);
    } finally {
      if (mounted) setState(() => _dangXuat = false);
    }
  }

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: _dangXuat ? null : _xuat,
        icon: _dangXuat
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download, size: 20),
        label: const Text(
          'Tải xuống',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
