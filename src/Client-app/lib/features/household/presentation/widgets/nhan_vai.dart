import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/vai_nha.dart';

class NhanVai extends StatelessWidget {
  const NhanVai({super.key, required this.vai});

  final VaiNha vai;

  @override
  Widget build(BuildContext context) {
    final chu = vai == VaiNha.chu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chu ? AppColors.primary : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tenVai(vai),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: chu ? AppColors.onPrimary : AppColors.textPrimary),
      ),
    );
  }
}
