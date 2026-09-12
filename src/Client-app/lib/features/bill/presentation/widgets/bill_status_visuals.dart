import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bill_status.dart';

/// Nhãn của từng trạng thái.
///
/// Bản dựng hình Stitch đầu tiên chỉ có ba; nhãn "QUÁ HẠN" là thứ tư, để nói
/// đúng `payStatus = 'Overdue'` mà trước đây không nơi nào đọc. "BỎ QUA" là
/// thứ năm (2026-09-12) — màu lấy từ ba màn Stitch "Chi tiết hóa đơn" dựng
/// cùng ngày, không tự chế.
String nhanTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => 'ĐÃ THANH TOÁN',
      BillDisplayStatus.skipped => 'BỎ QUA',
      BillDisplayStatus.overdue => 'QUÁ HẠN',
      BillDisplayStatus.dueSoon => 'SẮP ĐẾN HẠN',
      BillDisplayStatus.pending => 'CHƯA THANH TOÁN',
    };

Color mauChuTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => const Color(0xFF217128),
      // Xám đậm hơn `pending` một bậc: bỏ qua là một quyết định đã ra, không
      // phải một trạng thái đang chờ. Mã lấy từ màn Stitch "Chi tiết hóa đơn".
      BillDisplayStatus.skipped => const Color(0xFF5A5C56),
      BillDisplayStatus.overdue => const Color(0xFF93000A),
      BillDisplayStatus.dueSoon => const Color(0xFF8A5000),
      BillDisplayStatus.pending => AppColors.textSecondary,
    };

Color mauNenTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => const Color(0xFFA0F399),
      // Cùng nền với `pending` theo đúng màn Stitch — hai nhãn này không bao
      // giờ đứng cạnh nhau (bỏ qua chỉ hiện ở tab Lịch sử), và chữ đã khác.
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
      BillDisplayStatus.skipped => AppColors.textSecondary,
      BillDisplayStatus.overdue => AppColors.error,
      BillDisplayStatus.dueSoon => const Color(0xFFE8A33D),
      BillDisplayStatus.pending => AppColors.primary,
    };
