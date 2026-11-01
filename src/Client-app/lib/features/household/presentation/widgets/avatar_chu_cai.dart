import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class AvatarChuCai extends StatelessWidget {
  const AvatarChuCai({super.key, required this.ten, this.co = 40});

  final String ten;
  final double co;

  @override
  Widget build(BuildContext context) {
    final t = ten.trim();
    final chu = t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    // Nền và chữ khác nhau thật: `primary` trên `primaryContainer` là một màu (quét 13).
    return Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
      child: Text(chu, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}
