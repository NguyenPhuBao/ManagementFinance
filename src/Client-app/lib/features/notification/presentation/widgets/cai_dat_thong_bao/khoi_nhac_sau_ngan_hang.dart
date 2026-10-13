/// Khối *Nhắc ghi sau khi dùng app ngân hàng* của trang Cài đặt thông báo (`notification_settings_page.dart`), nằm dưới thẻ D1 trong cùng một thẻ; dời nguyên văn khỏi trang.
library;

import 'package:flutter/material.dart';

import '../../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../transaction/domain/doc_tin_bien_dong.dart';
import '../../../domain/cau_chu_dong_y.dart';

/// Khối *Nhắc ghi sau khi dùng app ngân hàng* (spec 2026-10-03 §3.1) — dưới khối D1, cùng thẻ. Hàng pin chỉ hiện khi
/// khối D1 KHÔNG đang hiện hàng của nó (hai hàng = hai nút cùng khoá [NotificationSettingsPage.khoaMoCaiDatPin]).
class KhoiNhacSauNganHang extends StatelessWidget {
  const KhoiNhacSauNganHang({
    super.key,
    required this.prefs,
    required this.coQuyenBienDong,
    required this.coQuyenPhien,
    required this.duocChayNen,
    required this.onDoi,
    required this.khoaCongTac,
    required this.dongQuyen,
    required this.dongTreNen,
  });

  final NotificationPrefs prefs;
  final bool coQuyenBienDong;
  final bool coQuyenPhien;
  final bool duocChayNen;
  final ValueChanged<bool> onDoi;
  final Key khoaCongTac;
  final Widget dongQuyen;
  final Widget dongTreNen;

  @override
  Widget build(BuildContext context) {
    final bat = prefs.nhacSauNganHang;
    final d1DangHienPin = prefs.docBienDong && coQuyenBienDong && !duocChayNen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_paused_outlined,
                          size: 18, color: AppColors.onSecondaryContainer),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          kTenNhacSauNganHang,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nhắc khi bạn dùng ${nguonDangDoc.join(', ')} mà chưa ghi giao dịch',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              key: khoaCongTac,
              value: bat,
              onChanged: onDoi,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF006E1C),
            ),
          ],
        ),
        if (bat) ...[
          const SizedBox(height: 14),
          dongQuyen,
          if (coQuyenPhien && !duocChayNen && !d1DangHienPin) ...[
            const SizedBox(height: 10),
            dongTreNen,
          ],
        ] else if (coQuyenPhien) ...[
          const SizedBox(height: 10),
          const Text(kNhacThuHoiQuyenSuDung,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}
