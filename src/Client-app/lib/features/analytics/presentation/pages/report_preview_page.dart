import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/xuat_tep_service.dart';
import '../../domain/bao_cao_xuat.dart';
import '../widgets/xem_truoc_bao_cao/bieu_do_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/dau_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_dong_tien_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_danh_muc_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_tong_quan_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_so_lieu_nhanh_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_theo_vi_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/khoi_top_chi_bao_cao.dart';
import '../widgets/xem_truoc_bao_cao/danh_sach_giao_dich_bao_cao.dart';
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
            KhoiSoLieuNhanhBaoCao(baoCao: baoCao),
            if (baoCao.theoDanhMuc.isNotEmpty) ...[
              const SizedBox(height: 16),
              BangDanhMucBaoCao('CHI THEO DANH MỤC', baoCao.theoDanhMuc),
            ],
            if (baoCao.thuTheoDanhMuc.isNotEmpty) ...[
              const SizedBox(height: 16),
              BangDanhMucBaoCao('THU THEO DANH MỤC', baoCao.thuTheoDanhMuc),
            ],
            if (baoCao.nganSach.isNotEmpty) ...[
              const SizedBox(height: 16),
              KhoiNganSachBaoCao(baoCao: baoCao),
            ],
            if (baoCao.theoVi.isNotEmpty) ...[
              const SizedBox(height: 16),
              KhoiTheoViBaoCao(baoCao: baoCao),
            ],
            if (baoCao.topChi.isNotEmpty) ...[
              const SizedBox(height: 16),
              KhoiTopChiBaoCao(baoCao: baoCao),
            ],
            const SizedBox(height: 16),
            DanhSachGiaoDichBaoCao(baoCao: baoCao),
          ],
        ],
      ),
      bottomNavigationBar: _thanhDuoi(),
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
