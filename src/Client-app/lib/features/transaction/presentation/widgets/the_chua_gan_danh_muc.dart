import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/do_chu.dart';
import '../../../../shared/theme/app_colors.dart';

/// Thẻ *"Có N giao dịch chưa có danh mục"* trên trang Sổ giao dịch — lối vào của C1 (gắn danh mục hàng loạt), màn
/// Stitch `a829606a98794c60804c820f8f063ee1`.
///
/// Chỉ vẽ; luật ẩn (N = 0 thì không dựng) nằm ở chỗ gọi, và N đến từ `demChuaGan` — một định nghĩa với màn duyệt.
class TheChuaGanDanhMuc extends StatelessWidget {
  const TheChuaGanDanhMuc({super.key, required this.soGiaoDich, required this.onGanNhanh});

  final int soGiaoDich;
  final VoidCallback onGanNhanh;

  @override
  Widget build(BuildContext context) => TheViecChoDuyet(
        icon: Icons.label_outline,
        tieuDe: 'Có $soGiaoDich giao dịch chưa có danh mục',
        phu: 'Gợi ý từ ghi chú của bạn, bạn duyệt trước khi lưu',
        nhanNut: 'Gắn nhanh',
        khoaNut: const Key('the-chua-gan-gan-nhanh'),
        onNhan: onGanNhanh,
      );
}

/// Thẻ *"Có N mục chờ ghi"* (D1, Stitch `e59155ff…`; đổi chữ 2026-10-03 vì dòng nhắc sau khi dùng app ngân hàng chưa
/// chắc có giao dịch) — đứng TRÊN thẻ C1. N là số hàng loại 20 chưa ghi (`NotificationDao.watchDemBienDong`): tin ngân
/// hàng, biên lai và dòng nhắc; **Xem** mở trung tâm thông báo lọc sẵn nhóm Biến động. Chỉ vẽ; N = 0 thì chỗ gọi không
/// dựng.
class TheBienDongChuaGhi extends StatelessWidget {
  const TheBienDongChuaGhi({super.key, required this.soBienDong, required this.onXem});

  final int soBienDong;
  final VoidCallback onXem;

  @override
  Widget build(BuildContext context) => TheViecChoDuyet(
        icon: Icons.account_balance_outlined,
        tieuDe: 'Có $soBienDong mục chờ ghi',
        phu: 'Tin ngân hàng, biên lai và lần dùng app ngân hàng — bạn duyệt trước khi lưu',
        nhanNut: 'Xem',
        khoaNut: const Key('the-bien-dong-xem'),
        onNhan: onXem,
      );
}

/// Khung chung của hai thẻ lối vào *"việc chờ bạn duyệt"* trên Sổ giao dịch.
///
/// Bố cục Stitch: [biểu tượng · khối chữ · nút] một hàng, khi tiêu đề và dòng phụ mỗi thứ vừa **hai** dòng cạnh nút (Stitch
/// đã cắt dòng chính ở 390 px). Không vừa — đo bằng `vuaSoDong`, không đoán theo cỡ chữ — thì nút xuống dưới, căn phải,
/// khối chữ lấy hết bề ngang và không trần số dòng: đo bằng font thật 2026-10-26, nút giữ bề rộng tự nhiên nên cột chữ chỉ
/// còn 63 dp ở 320 dp và 103 dp ở 360 dp ngay ở cỡ chữ thường (tiêu đề C1, dòng phụ D1 cụt *"…"*), 0 dp ở 320 dp × cỡ chữ 1,6.
class TheViecChoDuyet extends StatelessWidget {
  const TheViecChoDuyet({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.phu,
    required this.nhanNut,
    required this.khoaNut,
    required this.onNhan,
  });

  final IconData icon;
  final String tieuDe;
  final String phu;
  final String nhanNut;
  final Key khoaNut;
  final VoidCallback onNhan;

  static const _kieuTieuDe = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary);
  static const _kieuPhu = TextStyle(fontSize: 11, color: AppColors.textSecondary);
  static const _kieuNut = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// Biểu tượng 40 + khe 12 trước khối chữ.
  static const double _rongBieuTuong = 40 + 12;

  /// Bề rộng tự nhiên của nút: đệm 12 × 2 + chữ, không dưới bề rộng tối thiểu 64 của `OutlinedButton` (Material 3).
  double _rongNut(BuildContext context) => math.max(64, 24 + doRongChu(context, nhanNut, _kieuNut));

  @override
  Widget build(BuildContext context) {
    final bieuTuong = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
    final khoiChu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tieuDe, style: _kieuTieuDe),
        const SizedBox(height: 2),
        Text(phu, style: _kieuPhu),
      ],
    );
    final nut = OutlinedButton(
      key: khoaNut,
      onPressed: onNhan,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: _kieuNut,
      ),
      child: Text(nhanNut),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BoCucTheoFont(builder: (context, rang) {
        final choChu = rang.maxWidth - _rongBieuTuong - 8 - _rongNut(context);
        final motHang = choChu > 0 &&
            vuaSoDong(context, tieuDe, _kieuTieuDe, choChu, 2) &&
            vuaSoDong(context, phu, _kieuPhu, choChu, 2);
        if (motHang) {
          return Row(
            children: [
              bieuTuong,
              const SizedBox(width: 12),
              Expanded(child: khoiChu),
              const SizedBox(width: 8),
              nut,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                bieuTuong,
                const SizedBox(width: 12),
                Expanded(child: khoiChu),
              ],
            ),
            const SizedBox(height: 8),
            nut,
          ],
        );
      }),
    );
  }
}
