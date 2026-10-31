import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

class KhoiChuaCoNha extends StatelessWidget {
  const KhoiChuaCoNha({super.key});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
            child: const Icon(Icons.diversity_3_outlined, size: 56, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          Text('Bạn chưa ở nhà nào', style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Tạo nhà để mời người thân, hoặc tham gia bằng mã mời chủ nhà gửi cho bạn.',
            style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
