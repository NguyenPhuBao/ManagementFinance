import 'package:flutter/material.dart';

import '../../../domain/vai_nha.dart';

/// Hai lựa chọn vai khi mời. Chủ nhà không mời được vai Chủ.
class ChonVaiMoi extends StatelessWidget {
  const ChonVaiMoi({super.key, required this.vai, required this.onDoi});

  final VaiNha vai;
  final ValueChanged<VaiNha> onDoi;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vai', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [VaiNha.thanhVien, VaiNha.chiXem])
                ChoiceChip(label: Text(tenVai(v)), selected: vai == v, onSelected: (_) => onDoi(v)),
            ],
          ),
        ],
      );
}
