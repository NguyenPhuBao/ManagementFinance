/// Khung thẻ, nhãn mục và hai hàm định dạng dùng chung của các khối trên tờ báo cáo ở trang Xem trước báo cáo
/// (`report_preview_page.dart`).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';

class TheBaoCao extends StatelessWidget {
  const TheBaoCao({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

class NhanMucBaoCao extends StatelessWidget {
  const NhanMucBaoCao(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF46464C),
          letterSpacing: 0.8,
        ),
      );
}

/// Số tiền kèm dấu, nhưng **số 0 thì không mang dấu**: một ví không phát
/// sinh khoản thu nào hiện "+0 đ" trông như lỗi định dạng (thấy trên máy ảo
/// 2026-09-09).
/// Chuyển sang `CurrencyFormatter.formatCoDau` ngày 2026-09-15: luật "số 0
/// không mang dấu" nay dùng chung với trang Phân tích, và mọi luật hiển thị
/// tiền phải nằm ở một chỗ duy nhất.
String coDauBaoCao(double soTien, {required bool thu}) =>
    CurrencyFormatter.formatCoDau(soTien, thu: thu);

/// `0.75` → `(75,0%)`. Dấu phẩy thập phân theo kiểu Việt, đồng bộ với phần
/// còn lại của app.
String phanTramBaoCao(double tiLe) =>
    '(${(tiLe * 100).toStringAsFixed(1).replaceAll('.', ',')}%)';
