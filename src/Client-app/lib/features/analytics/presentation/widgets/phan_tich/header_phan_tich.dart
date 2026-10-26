/// Khối "header_phan_tich" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/pham_vi_ky.dart';
import '../../bloc/analytics_cubit.dart';
import '../../widgets/chon_pham_vi_sheet.dart';
import '../../../../../core/ui/do_chu.dart';

class Header extends StatelessWidget {
  final AnalyticsState state;
  const Header({super.key, required this.state});

  /// Tỉ lệ chia chỗ trống của hàng ngang — tiêu đề : ô kỳ.
  static const int _flexTieuDe = 2;
  static const int _flexOKy = 3;

  /// Nút tải gọn: 40px thay vì 48px mặc định.
  static const double _rongNut = 40;

  static const TextStyle _kieuTieuDe = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  @override
  Widget build(BuildContext context) {
    // Trái co, phải giữ: ở 411dp thì "Thống kê" + nút xuất + ô chọn tháng
    // không đủ chỗ (tràn 53px trên máy ảo). Tiêu đề nhường trước vì nó là
    // thứ người dùng đã biết; ô chọn tháng mới là thứ họ cần đọc được.
    // Không có icon menu: bản trước vẽ một `Icon` trần trông hệt hamburger mở
    // drawer của Trang chủ, mà trang này không có drawer và icon không bọc nút
    // nào — bấm không xảy ra gì (UX 2026-09-19, A2).
    //
    // G2 (2026-10-06): cỡ chữ hệ thống lớn thì hàng ngang hết chỗ — đo font
    // thật (Roboto) ở 360dp ×1,3: "Phân tích" lẫn "Tháng này (T9 2026)" bị cắt.
    // Khi ấy ô kỳ xuống hàng thứ hai, rộng hết khung (Stitch `7f05fccd…`). Chữ
    // thường vẫn MỘT hàng như Stitch gốc — phép chọn đo bề rộng thật, không đoán
    // theo hệ số cỡ chữ.
    return BoCucTheoFont(builder: (context, rang) {
      if (_vuaMotHang(context, rang.maxWidth)) {
        return Row(
          children: [
            // Tỉ lệ 2:3, KHÔNG phải Expanded + Flexible bằng nhau: flex chia chỗ
            // trống theo hệ số bất kể con cần bao nhiêu, nên bản đầu cho tiêu đề
            // một nửa trong khi nó chỉ cần ~95px — và ô tháng bị cắt thành
            // "Tháng này (…" trên máy thật dù test 411dp xanh (font test khác
            // font thật, bẫy 4.4 `ANALYTICS_FEATURE.md`).
            const Flexible(flex: _flexTieuDe, child: TieuDeTrang()),
            const NutXuat(),
            Flexible(flex: _flexOKy, child: ChonPhamVi(state: state)),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: TieuDeTrang()),
              NutXuat(),
            ],
          ),
          const SizedBox(height: 8),
          ChonPhamVi(state: state, rongHet: true),
        ],
      );
    });
  }

  /// Hàng ngang đủ chỗ cho cả hai chữ ở cỡ chữ ĐANG DÙNG không. Mỗi bên chỉ
  /// được phần của nó theo flex, nên so từng bên với phần ấy — tổng vừa mà một
  /// bên vượt phần mình thì `Flexible` vẫn cắt bên đó.
  bool _vuaMotHang(BuildContext context, double rong) {
    final conLai = rong - _rongNut;
    const tong = _flexTieuDe + _flexOKy;
    final rongTieuDe = doRongChu(context, TieuDeTrang.chu, _kieuTieuDe);
    final rongOKy = ChonPhamVi.rongCan(context, ChonPhamVi.nhanCua(state));
    // Nửa điểm ảnh dung sai cho phép làm tròn của TextPainter.
    return rongTieuDe <= conLai * _flexTieuDe / tong + 0.5 &&
        rongOKy <= conLai * _flexOKy / tong + 0.5;
  }
}

class TieuDeTrang extends StatelessWidget {
  const TieuDeTrang({super.key});

  // Một đích một tên (D4, 2026-09-19): tab gọi là "Phân tích" nên tiêu đề
  // trang cũng thế. Drawer đã thôi có mục "Thống kê", nên không còn chỗ thứ
  // hai nào gọi trang này bằng tên khác.
  static const String chu = 'Phân tích';

  @override
  Widget build(BuildContext context) => const Text(
        chu,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Header._kieuTieuDe,
      );
}

/// Nút gọn 40px thay vì 48px mặc định: ở 411dp thật, tiêu đề 24px + nút + nhãn
/// tháng đầy đủ thiếu đúng vài chục px, và flex chia kiểu gì cũng phải cắt một
/// trong hai chữ. Bớt chỗ chiếm cố định mới là cách.
class NutXuat extends StatelessWidget {
  const NutXuat({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.download, color: AppColors.primary),
        onPressed: () => context.push('/analytics/export'),
        tooltip: 'Xuất Báo cáo',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(
          minWidth: Header._rongNut,
          minHeight: Header._rongNut,
        ),
      );
}

/// Ô chọn phạm vi. Nhãn "Tháng này (T9 2026)" chỉ khi kỳ đang xem chứa hôm nay;
/// kỳ đã qua thì "T8 2026" — giữ "Tháng này" cho một tháng đã qua là nói dối về
/// thứ đang hiện. Luật ấy có một chỗ định nghĩa: `nhanOChon`.
///
/// Bấm vào mở bottom sheet hai tầng chứ không phải menu một tầng: từ 2026-09-15
/// có năm đơn vị, và một danh sách phẳng trộn tuần lẫn quý thì không ai đọc
/// được. Ô này **không đổi kích thước**, nên không đụng lại bài toán tràn 53px
/// của hàng header.
class ChonPhamVi extends StatelessWidget {
  final AnalyticsState state;

  /// Ô rộng hết khung, mũi tên dạt phải — khi header xuống hai hàng (G2).
  final bool rongHet;
  const ChonPhamVi({super.key, required this.state, this.rongHet = false});

  static const TextStyle _kieuNhan = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Đệm ngang 10 × 2 + viền 1 × 2 + khoảng 6 + mũi tên 16.
  static const double _phanCoDinh = 10 * 2 + 1 * 2 + 6 + 16;

  static String nhanCua(AnalyticsState state) => switch (state) {
        AnalyticsLoaded(:final thongKe, :final moc) =>
          nhanOChon(thongKe.ky, moc),
        // Cùng nhãn với lúc có số liệu — khác nhãn là header nhảy hàng (G69).
        AnalyticsLoading(:final ky, :final moc) => nhanOChon(ky, moc),
        _ => 'Tháng này',
      };

  /// Bề rộng ô cần để nhãn [nhan] không bị cắt ở cỡ chữ đang dùng.
  static double rongCan(BuildContext context, String nhan) =>
      doRongChu(context, nhan, _kieuNhan) + _phanCoDinh;

  @override
  Widget build(BuildContext context) {
    final nhan = nhanCua(state);
    final (ky, moc) = switch (state) {
      AnalyticsLoaded(:final thongKe, :final moc) => (thongKe.ky, moc),
      _ => (null, null),
    };

    final chu = Text(
      nhan,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _kieuNhan,
    );
    final o = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: rongHet ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (rongHet) Expanded(child: chu) else Flexible(child: chu),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more,
              size: 16, color: AppColors.textSecondary),
        ],
      ),
    );

    // Chưa có dữ liệu thì ô chỉ là một nhãn: mở bộ chọn lúc chưa biết kỳ nào
    // đang xem sẽ vẽ một sheet không có dấu tích ở đâu cả.
    if (ky == null || moc == null) return o;

    return Semantics(
      button: true,
      label: 'Chọn phạm vi',
      child: InkWell(
        onTap: () async {
          final cubit = context.read<AnalyticsCubit>();
          final chon = await moChonPhamVi(context, kyHienTai: ky, moc: moc);
          // Đóng sheet TRƯỚC rồi mới đổi kỳ (`moChonPhamVi` pop rồi mới trả
          // về): gọi `chonKy` khi sheet còn đứng là nó nháy một khung dữ liệu
          // mới ngay trước lúc biến mất.
          if (chon != null) cubit.chonKy(chon);
        },
        borderRadius: BorderRadius.circular(8),
        child: o,
      ),
    );
  }
}

// ── Rỗng ──────────────────────────────────────────────────────────────────

class Rong extends StatelessWidget {
  final Ky ky;
  const Rong({super.key, required this.ky});

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
              'Chưa có giao dịch nào trong ${ky.nhanNgan}.',
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
