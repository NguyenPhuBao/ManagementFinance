import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bill_status.dart';

/// Nhãn của từng trạng thái. Bản dựng hình Stitch chỉ có ba; nhãn "QUÁ HẠN" là
/// thứ tư, để nói đúng `payStatus = 'Overdue'` mà trước đây không nơi nào đọc.
String nhanTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => 'ĐÃ THANH TOÁN',
      // TẠM — hạng mục 6 thay bằng màu Stitch chốt.
      BillDisplayStatus.skipped => 'CHƯA THANH TOÁN',
      BillDisplayStatus.overdue => 'QUÁ HẠN',
      BillDisplayStatus.dueSoon => 'SẮP ĐẾN HẠN',
      BillDisplayStatus.pending => 'CHƯA THANH TOÁN',
    };

Color mauChuTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => const Color(0xFF217128),
      // TẠM — hạng mục 6 thay bằng màu Stitch chốt.
      BillDisplayStatus.skipped => AppColors.textSecondary,
      BillDisplayStatus.overdue => const Color(0xFF93000A),
      BillDisplayStatus.dueSoon => const Color(0xFF8A5000),
      BillDisplayStatus.pending => AppColors.textSecondary,
    };

Color mauNenTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => const Color(0xFFA0F399),
      // TẠM — hạng mục 6 thay bằng màu Stitch chốt.
      BillDisplayStatus.skipped => AppColors.surfaceContainerHigh,
      BillDisplayStatus.overdue => const Color(0xFFFFDAD6),
      BillDisplayStatus.dueSoon => const Color(0xFFFFE0B2),
      BillDisplayStatus.pending => AppColors.surfaceContainerHigh,
    };

/// Vạch màu bên trái thẻ.
///
/// Nhánh quá hạn từng dùng `AppColors.income` — đúng màu xanh lá của khoản
/// THU — cho một hoá đơn đã trễ hạn.
Color mauVachTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => AppColors.outlineVariant,
      // TẠM — hạng mục 6 thay bằng màu Stitch chốt.
      BillDisplayStatus.skipped => AppColors.primary,
      BillDisplayStatus.overdue => AppColors.error,
      BillDisplayStatus.dueSoon => const Color(0xFFE8A33D),
      BillDisplayStatus.pending => AppColors.primary,
    };
