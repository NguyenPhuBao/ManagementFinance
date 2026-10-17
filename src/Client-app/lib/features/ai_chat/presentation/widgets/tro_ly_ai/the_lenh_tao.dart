import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../ai_edge/domain/lenh_tao.dart';

/// C3 — thẻ lệnh tạo (Stitch *"Trợ lý AI - Thẻ lệnh tạo hoá đơn"*): tóm tắt ô đọc được, dòng ô thiếu, dòng tầng 4,
/// nút mở form điền sẵn bằng `push` (route ngoài shell; quay về giữ lịch sử chat). Không lưu gì.
class TheLenhTao extends StatelessWidget {
  const TheLenhTao({super.key, required this.lenh});
  final LenhTao lenh;

  @override
  Widget build(BuildContext context) {
    final t = tomTatLenhTao(lenh);
    const phu = TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            key: const Key('the-lenh-tao'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dòng nguồn nói thứ ĐÃ XẢY RA: "Đọc bằng AI" chỉ khi mô hình lấp ít nhất một ô qua lưới kiểm (§8.3).
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        lenh.nguon == NguonLenh.ai ? Icons.auto_awesome : Icons.rule,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lenh.nguon == NguonLenh.ai ? 'Đọc bằng AI' : 'Đọc bằng luật',
                      key: const Key('nguon-lenh'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
                    children: [
                      TextSpan(text: 'Mình hiểu là: ${t.hanhDong}'),
                      if (t.ten != null)
                        TextSpan(text: ' ${t.ten}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (t.chiTiet.isNotEmpty) TextSpan(text: ' · ${t.chiTiet.join(' · ')}'),
                    ],
                  ),
                ),
                if (t.thieu.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Hộp nền nhạt + dấu hỏi (Stitch `59454c61…`): ô thiếu là thứ người dùng PHẢI làm tiếp trong form.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(t.thieu, style: phu)),
                      ],
                    ),
                  ),
                ],
                if (t.nhacTuTra) ...[const SizedBox(height: 6), const Text('Tự trả phải bật trong form', style: phu)],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push(lenh.duongDan),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(t.nut)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
