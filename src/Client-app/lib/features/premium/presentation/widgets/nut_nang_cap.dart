import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/tran_goi.dart';

/// Nút dùng chung cho hai băng khoá (Trợ lý AI, Nhập nhanh) và thẻ Gói ở tab
/// Cá nhân: `push('/premium')` — route ngoài shell, push từ mọi nơi được (bẫy
/// 7.8 `NOTIFICATION_FEATURE.md` chỉ cấm push route TRONG shell). [tran] khác
/// `null` → kèm `?tran=` để màn Nâng cấp mở đầu bằng câu trần.
class NutNangCap extends StatelessWidget {
  const NutNangCap({super.key, this.nhan = 'Nâng cấp', this.tran, this.onMo});

  final String nhan;
  final LoaiTran? tran;

  /// Khe tiêm cho test. `null` → `context.push`.
  final VoidCallback? onMo;

  @override
  Widget build(BuildContext context) => TextButton(
        key: const Key('nut-nang-cap'),
        onPressed: onMo ??
            () => context.push(
                tran == null ? '/premium' : '/premium?tran=${maTran(tran!)}'),
        child: Text(nhan),
      );
}
