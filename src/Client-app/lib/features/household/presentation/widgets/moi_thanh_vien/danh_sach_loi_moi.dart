import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/loi_moi.dart';
import '../../../domain/ma_moi.dart';
import '../../../domain/vai_nha.dart';
import '../nha_minh/khung_the_nha.dart';

class DanhSachLoiMoi extends StatelessWidget {
  const DanhSachLoiMoi({super.key, required this.ds, required this.now, required this.onHuy});

  /// Đã lọc qua `dongLoiMoiHien`.
  final List<MaMoiEntity> ds;
  final DateTime now;
  final ValueChanged<String> onHuy;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return KhungTheNha(
      child: Column(
        children: [
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              children: [
                Icon(ds[i].email == null ? Icons.key_outlined : Icons.mail_outline, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ds[i].email ?? ds[i].ma, maxLines: 1, overflow: TextOverflow.ellipsis, style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${ds[i].email == null ? 'Mã mời' : 'Email'} · ${tenVai(ds[i].vai)}', style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (ds[i].conHieuLucLuc(now))
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () => onHuy(ds[i].ma),
                    child: const Text('Huỷ'),
                  )
                else
                  Text(nhanTrangThaiLoiMoi(ds[i].trangThaiLuc(now)), style: chu.labelMedium?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
