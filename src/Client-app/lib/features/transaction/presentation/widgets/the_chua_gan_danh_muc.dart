import 'package:flutter/material.dart';

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

/// Thẻ *"Có N biến động chưa ghi"* (D1, Stitch `e59155ff…`) — đứng TRÊN thẻ C1. N là số hàng loại 20 chưa ghi
/// (`NotificationDao.watchDemBienDong`); **Xem** mở trung tâm thông báo lọc sẵn nhóm Biến động. Chỉ vẽ; N = 0 thì chỗ
/// gọi không dựng.
class TheBienDongChuaGhi extends StatelessWidget {
  const TheBienDongChuaGhi({super.key, required this.soBienDong, required this.onXem});

  final int soBienDong;
  final VoidCallback onXem;

  @override
  Widget build(BuildContext context) => TheViecChoDuyet(
        icon: Icons.account_balance_outlined,
        tieuDe: 'Có $soBienDong biến động chưa ghi',
        phu: 'Từ thông báo ngân hàng, bạn duyệt trước khi lưu',
        nhanNut: 'Xem',
        khoaNut: const Key('the-bien-dong-xem'),
        onNhan: onXem,
      );
}

/// Khung chung của hai thẻ lối vào *"việc chờ bạn duyệt"* trên Sổ giao dịch.
///
/// ⚠️ Dòng chính được xuống **hai** dòng: Stitch đã cắt nó ở 390 px, và máy thật hẹp nhất của dự án là 360 dp.
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

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tieuDe,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phu,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: khoaNut,
            onPressed: onNhan,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: Text(nhanNut),
          ),
        ],
      ),
    );
  }
}
