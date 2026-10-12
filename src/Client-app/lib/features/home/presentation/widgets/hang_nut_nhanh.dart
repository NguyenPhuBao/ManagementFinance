// lib/features/home/presentation/widgets/hang_nut_nhanh.dart
/// Hàng nút nhanh ở Trang chủ — tách từ `_buildActionItem` của `home_page.dart` ngày 2026-10-12 khi thêm nút *Nói* (C4
/// §2.3, Stitch *"Trang chủ - Năm nút nhanh có Nói"*). Năm vòng 56 dp `spaceBetween` tràn ở 320 dp; nay mỗi nút một ô
/// `Expanded`, vòng 52 dp, nhãn co bằng `FittedBox`.
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/widgets/nut_nang_cap.dart';

class NutNhanh {
  const NutNhanh({required this.bieuTuong, required this.nhan, required this.dam, required this.onTap, this.khoa});

  final IconData bieuTuong;
  final String nhan;

  /// Nền đen (gradient) — *Thêm thu*, *Thêm chi*; còn lại nền trắng viền.
  final bool dam;
  final VoidCallback onTap;
  final Key? khoa;
}

/// Đích của nút *Nói*: có quyền *Nhập nhanh bằng câu* → form mở và nghe ngay; Basic → màn Nâng cấp mở bằng tên tính năng.
String duongNutNoi({required bool coQuyen}) => coQuyen ? '/add?noi=1' : duongNangCap(quyen: MaQuyen.aiQuickInput);

class HangNutNhanh extends StatelessWidget {
  const HangNutNhanh({super.key, required this.nut});

  final List<NutNhanh> nut;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final n in nut) Expanded(child: _Nut(n))],
      );
}

class _Nut extends StatelessWidget {
  const _Nut(this.n);
  final NutNhanh n;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: n.khoa,
        onTap: n.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n.dam ? AppColors.primary : Colors.white,
                border: n.dam ? null : Border.all(color: Colors.black12),
                gradient: n.dam
                    ? const LinearGradient(
                        colors: [Color(0xFF1A1A19), Color(0xFF374151)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: Icon(n.bieuTuong, color: n.dam ? Colors.white : AppColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                n.nhan,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
}
