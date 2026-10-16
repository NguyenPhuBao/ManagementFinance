/// Các ô dựng sẵn của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`): nhãn, ô chữ, ô xổ xuống, bảng chọn biểu tượng và bảng chọn màu — dời nguyên văn từ các hàm `_build…` của trang (G88 gạch 2).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../goal_appearance.dart';

class NhanMucTieu extends StatelessWidget {
  const NhanMucTieu(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class ONhapMucTieu extends StatelessWidget {
  const ONhapMucTieu({
    super.key,
    required this.controller,
    required this.hint,
    this.textColor = AppColors.primary,
    this.isBold = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final Color textColor;
  final bool isBold;
  final TextInputType keyboardType;
  final IconData? suffixIcon;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 16,
        color: textColor,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: AppColors.outlineVariant, size: 20)
            : null,
      ),
    );
  }
}

class ODropdownMucTieu extends StatelessWidget {
  const ODropdownMucTieu({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    this.onTap,

    /// Mũi tên xổ xuống là lời hứa "bấm được". Ô chỉ đọc phải bỏ nó đi, nếu
    /// không người dùng cứ bấm mãi vào một chỗ không phản hồi.
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    // Thuộc tính `final` của lớp không tự thăng kiểu sau `!= null`, nên bắt vào biến cục bộ.
    final subtitle = this.subtitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.expand_more, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// Bảng chọn biểu tượng.
///
/// Cuộn ngang có chủ ý: điện thoại thật rộng 411dp chứ không phải 1280px như
/// Chrome trong bộ test, và một `Wrap` mười ô ở đây từng là kiểu bố cục đã
/// gây tràn ở những màn khác. Cuộn thì không bao giờ tràn dù thêm bao nhiêu
/// lựa chọn.
class ChonBieuTuongMucTieu extends StatelessWidget {
  const ChonBieuTuongMucTieu({
    super.key,
    required this.icon,
    required this.colour,
    required this.onChon,
  });

  final String icon;
  final String colour;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    final mau = mauMucTieu(colour);
    // Danh sách phải chứa biểu tượng ĐANG lưu, kể cả khi nó ngoài bảng chọn —
    // xem `danhSachBieuTuong`.
    final danhSach = danhSachBieuTuong(icon);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: danhSach.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final ten = danhSach[i];
          final chon = ten == icon;
          return GestureDetector(
            onTap: () => onChon(ten),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: chon
                    ? mau.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: chon ? Border.all(color: mau, width: 2) : null,
              ),
              child: Icon(
                bieuTuongMucTieu(ten),
                color: chon ? mau : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChonMauMucTieu extends StatelessWidget {
  const ChonMauMucTieu({super.key, required this.colour, required this.onChon});

  final String colour;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kMauMucTieu.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final hex = kMauMucTieu[i];
          final mau = mauMucTieu(hex);
          final chon = hex == colour;
          return GestureDetector(
            onTap: () => onChon(hex),
            child: Container(
              width: 36,
              decoration: BoxDecoration(
                color: mau,
                shape: BoxShape.circle,
                border: chon
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: chon
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
