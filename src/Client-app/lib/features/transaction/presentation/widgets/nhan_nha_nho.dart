import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Viên nhỏ "🏠 tên nhà" trên dòng khoản của NHÀ ở Sổ giao dịch và Trang chủ (spec 2026-11-16 mục 3). Cùng bảng màu với
/// `NhanNha` của form (nền `#F0F4EB`, viền `#D6E3CB`). Tên dài co về một dòng bằng dấu ba chấm — dòng phụ không được cao thêm.
class NhanNhaNho extends StatelessWidget {
  const NhanNhaNho({super.key, required this.tenNha});

  final String tenNha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4EB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E3CB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home, size: 11, color: AppColors.onSecondaryContainer),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              tenNha,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng phụ của một dòng giao dịch: chữ phụ + (khoản của nhà) viên tên nhà. Hai phần cùng `Flexible` — tên nhà dài hay dòng
/// phụ dài đều co về dấu ba chấm, không tràn ở 320 dp.
class DongPhuGiaoDich extends StatelessWidget {
  const DongPhuGiaoDich({super.key, required this.chu, this.tenNha, this.style});

  final String chu;
  final String? tenNha;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = Text(chu, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final nha = tenNha;
    if (nha == null) return t;
    return Row(
      children: [
        Flexible(child: t),
        const SizedBox(width: 6),
        Flexible(child: NhanNhaNho(tenNha: nha)),
      ],
    );
  }
}
