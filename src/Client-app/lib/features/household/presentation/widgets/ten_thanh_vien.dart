import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Tên + nhãn *Bạn*: chỉ tên bị cắt, nhãn luôn còn nguyên (spec 12.2).
class TenThanhVien extends StatelessWidget {
  const TenThanhVien({super.key, required this.ten, required this.laToi});

  final String ten;
  final bool laToi;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (laToi) ...[
            const SizedBox(width: 6),
            Text('Bạn', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      );
}
