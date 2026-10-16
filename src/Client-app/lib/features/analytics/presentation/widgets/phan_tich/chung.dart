/// Khối "chung" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import '../../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../../../../category/presentation/widgets/category_visuals.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/thong_ke_ky.dart';

/// Màu lát "Khác" và màu dự phòng khi danh mục không có màu.
const Color mauKhac = Color(0xFF586062);

const Color mauXanhLa = Color(0xFF2E6B27);

/// Màu của một dòng. Ba ca không có màu thật phải ra BA màu khác nhau: trên
/// máy thật, "Chưa phân loại" và "Danh mục đã xoá" từng cùng xanh dự phòng nên
/// hai lát donut không phân biệt được — test không bắt vì nó không nhìn màu.
Color mauCua(DongDanhMuc? d) {
  if (d == null || d.categoryId == null) return AppColors.textSecondary;
  if (d.mauHex == null) return AppColors.outline; // id có, hàng không còn
  return categoryColorFrom(d.mauHex, fallback: mauXanhLa);
}

String chuoiTien(double x) => CurrencyFormatter.format(x);

/// Tiêu đề khối, cùng kiểu với "Xu hướng …" và "Cơ cấu theo danh mục".
///
/// `Text` đứng trong `Row` không co được, nên bọc `SizedBox` rộng vô hạn — cùng
/// lý do đã ghi ở hai khối kia.
Widget tieuDeKhoi(String chu) => SizedBox(
      width: double.infinity,
      child: Text(
        chu,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );

BoxDecoration theTrang({Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
