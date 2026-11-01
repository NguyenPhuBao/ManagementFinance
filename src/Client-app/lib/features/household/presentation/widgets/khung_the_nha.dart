import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Thẻ trắng viền mảnh dùng chung các màn Nhà mình.
class KhungTheNha extends StatelessWidget {
  const KhungTheNha({super.key, required this.child, this.vien = AppColors.outlineVariant});

  final Widget child;
  final Color vien;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vien),
        ),
        child: child,
      );
}
