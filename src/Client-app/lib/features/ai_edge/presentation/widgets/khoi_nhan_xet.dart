import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bo_dien_giai.dart';
import '../../domain/goi_so.dart';
import '../../domain/mau_cau.dart';
import '../../domain/nhan_xet.dart';
import 'the_so_lieu.dart';

/// Khối "Nhận xét" dùng chung cho **sáu** màn — Ngân sách · Phân tích · Trang
/// chủ · Mục tiêu · Hoá đơn · Quản lý ví — theo màn Stitch `b396533b…`.
///
/// ⚠️ Bốn màn đầu là của P2 Task 14 (2026-09-19); Hoá đơn và Quản lý ví thêm
/// ngày 2026-09-21 (chặng 1.3 và 1.5, mục 12 và 14 `AI_EDGE_FEATURE.md`). Đếm
/// lại bằng máy thay vì tin con số này: `grep -rl 'KhoiNhanXet(' lib/`.
///
/// Nhận **gói số**, không nhận câu: hiện `goi.mauCau()` ngay lập tức, rồi hỏi
/// bộ diễn giải và thay câu khi xong (P3: SLM chậm vài giây, người dùng không
/// được nhìn ô trống). Bộ diễn giải ném lỗi thì giữ mẫu câu, chỉ `debugPrint`
/// — H3: không toast lỗi kỹ thuật.
///
/// [boDienGiai] để `null` thì lấy từ GetIt nếu P3 đã đăng ký, không thì
/// `const MauCau()`.
class KhoiNhanXet extends StatefulWidget {
  final GoiSo goi;
  final BoDienGiai? boDienGiai;

  /// `true` cho thẻ nền tối của Trang chủ (thay thẻ "Insight AI" cũ).
  final bool nenToi;

  const KhoiNhanXet({
    super.key,
    required this.goi,
    this.boDienGiai,
    this.nenToi = false,
  });

  @override
  State<KhoiNhanXet> createState() => _KhoiNhanXetState();
}

class _KhoiNhanXetState extends State<KhoiNhanXet> {
  late NhanXet _nhanXet;

  /// Dấu vân của gói đang hiện — stream phát lại với gói không đổi thì không
  /// hỏi bộ diễn giải lần hai.
  String? _dauVanDaHoi;

  BoDienGiai get _bo {
    final b = widget.boDienGiai;
    if (b != null) return b;
    if (sl.isRegistered<BoDienGiai>()) return sl<BoDienGiai>();
    return const MauCau();
  }

  @override
  void initState() {
    super.initState();
    _nhanXet = widget.goi.mauCau();
    _hoi();
  }

  @override
  void didUpdateWidget(covariant KhoiNhanXet cu) {
    super.didUpdateWidget(cu);
    if (cu.goi.dauVan != widget.goi.dauVan) {
      _nhanXet = widget.goi.mauCau();
      _hoi();
    }
  }

  Future<void> _hoi() async {
    final goi = widget.goi;
    if (goi.thieuDuLieu) return;
    final dauVan = goi.dauVan;
    if (_dauVanDaHoi == dauVan) return;
    _dauVanDaHoi = dauVan;
    try {
      final nx = await _bo.dienGiai(goi);
      if (!mounted || widget.goi.dauVan != dauVan) return;
      setState(() => _nhanXet = nx);
    } catch (e) {
      debugPrint('[KhoiNhanXet] bộ diễn giải lỗi, giữ mẫu câu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final toi = widget.nenToi;
    final canhBao = _nhanXet.muc == MucNhanXet.canhBao;
    final thieu = _nhanXet.muc == MucNhanXet.thieuDuLieu;
    final mauChu = toi
        ? Colors.white
        : thieu
            ? AppColors.textSecondary
            : AppColors.textPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: toi ? AppColors.primaryContainer : Colors.white,
        borderRadius: BorderRadius.circular(toi ? 24 : 8),
        border: canhBao && !toi
            ? const Border(left: BorderSide(color: AppColors.error, width: 3))
            : null,
      ),
      child: Column(
        key: canhBao ? const ValueKey('nhan-xet-vien-canh-bao') : null,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                toi ? Icons.lightbulb : Icons.auto_awesome,
                size: 16,
                color: toi ? const Color(0xFFFDE047) : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'NHẬN XÉT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: toi ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              if (_nhanXet.tuMoHinh) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: toi
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: toi ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nhanXet.cau,
            style: TextStyle(fontSize: 14, height: 1.5, color: mauChu),
          ),
          if (_nhanXet.theSoLieu.isNotEmpty) ...[
            const SizedBox(height: 10),
            TheSoLieu(ds: _nhanXet.theSoLieu, nenToi: toi),
          ],
        ],
      ),
    );
  }
}
