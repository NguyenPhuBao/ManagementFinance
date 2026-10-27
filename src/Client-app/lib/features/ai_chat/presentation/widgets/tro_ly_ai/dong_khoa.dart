/// Băng khoá của màn Trợ lý AI — một câu + một nút (dời nguyên văn khỏi `ai_chat_page.dart`).
/// Trạng thái ở lại trang: widget nhận câu, cờ gói Basic và một callback (`onCaiDatAi`).
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../premium/presentation/widgets/nut_nang_cap.dart';

/// Băng khoá — một câu + một nút theo lý do (tạm ngừng: không nút). Basic → *Nâng cấp*
/// (spec Premium 8.1; màn Stitch *"Trợ lý AI - Khoá Premium (Basic)"*
/// `2b3fa0f69486498584fdf3a243f30147`); hai lý do cũ → *Cài đặt AI* như trước.
class DongKhoa extends StatelessWidget {
  const DongKhoa({
    super.key,
    required this.cau,
    required this.goiBasic,
    required this.onCaiDatAi,
    this.tamNgung = false,
  });

  final String cau;
  final bool goiBasic;

  /// B1: admin tắt — không nút nào (mua không mở, Cài đặt AI không giúp).
  final bool tamNgung;
  final VoidCallback onCaiDatAi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            Icon(
              tamNgung
                  ? Icons.smart_toy_outlined
                  : (goiBasic ? Icons.workspace_premium_outlined : Icons.info_outline),
              size: 16,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cau,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            if (goiBasic)
              const NutNangCap()
            else if (!tamNgung)
              TextButton(
                onPressed: onCaiDatAi,
                child: const Text('Cài đặt AI'),
              ),
          ],
        ),
      );
}
