import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/thu_tu_khoi.dart';

/// Thẻ "Bạn hay xem ‹cụm› — đưa lên đầu trang?" (dự án C việc ba) — màn Stitch
/// `e081fc951e474cb1bc1b4ed655f5a026` *"Thống kê - Đề xuất thứ tự khối"*,
/// người dùng xác nhận 2026-10-05.
///
/// ⚠️ Widget không quyết định ẩn/hiện — trang chỉ dựng nó khi
/// `ThuTuKhoiState.deXuat != null`. Học rồi **đề xuất**: vị trí khối không bao
/// giờ tự nhảy (spec 1.3).
///
/// Nút **×** ở góc là của Stitch và mang **đúng nghĩa Bỏ qua** — không có lối
/// "đóng tạm" thứ ba mà luật học không biết (thẻ sẽ bật lại ở lần mở sau, như
/// người dùng chưa trả lời gì).
class TheDeXuatThuTu extends StatelessWidget {
  const TheDeXuatThuTu({
    super.key,
    required this.cum,
    required this.onDuaLen,
    required this.onBoQua,
  });

  final CumKhoi cum;
  final VoidCallback onDuaLen;
  final VoidCallback onBoQua;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('the-de-xuat-thu-tu'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'THỨ TỰ KHỐI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('thu-tu-dong'),
                tooltip: 'Bỏ qua',
                onPressed: onBoQua,
                icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Bạn hay xem '),
                TextSpan(
                  text: cum.ten,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: ' — đưa lên đầu trang?'),
              ]),
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Wrap chứ không Row: ở 360 dp font lớn hai nút xuống dòng được.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton(
                key: const ValueKey('thu-tu-dua-len'),
                onPressed: onDuaLen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  // Theme ép ElevatedButton rộng vô hạn — thiếu dòng này nút
                  // trong Wrap làm trắng cả trang (bẫy 4.11).
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text(
                  'Đưa lên',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                key: const ValueKey('thu-tu-bo-qua'),
                onPressed: onBoQua,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dòng cuối trang khi thứ tự khác mặc định (spec 2.3) — cùng màn Stitch.
class DongVeMacDinh extends StatelessWidget {
  const DongVeMacDinh({super.key, required this.onVeMacDinh});

  final VoidCallback onVeMacDinh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Thứ tự khối đang theo thói quen xem của bạn · ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            InkWell(
              key: const ValueKey('thu-tu-ve-mac-dinh'),
              onTap: onVeMacDinh,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Về mặc định',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
