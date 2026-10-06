import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/gop_vi.dart';

/// Hộp xác nhận Gộp (G63, spec mục 5.3; màn Stitch
/// `303d12a1d16340bb8096ab6abc373c69` *"Quản lý ví - Hộp gộp ví"*). In ĐÚNG các
/// dòng của [keHoach] qua `cacDongXacNhanGop` — không đếm lại ở đây (bẫy 4).
/// Trả `true` khi người dùng bấm Gộp.
Future<bool> hoiGopVi(
  BuildContext context, {
  required String tenVi,
  required KeHoachGop keHoach,
}) async {
  final dong = cacDongXacNhanGop(keHoach);
  final dongY = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Gộp hai ví "$tenVi"?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < dong.length; i++)
              _Dong(
                dong[i],
                // Ba dòng cuối của `cacDongXacNhanGop` luôn là: số dư sau
                // gộp · ví giữ lại · "Không hoàn tác được." — Stitch tô đậm
                // dòng đầu và tô màu lỗi dòng cuối.
                dam: i == dong.length - 3,
                canhBao: i == dong.length - 1,
              ),
          ],
        ),
      ),
      actions: [
        // `Navigator.pop`, KHÔNG `ctx.pop` của go_router: hộp nằm ngoài cây
        // route.
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        // FilledButton chứ không ElevatedButton: theme ép ElevatedButton rộng
        // vô hạn (bẫy 4.11).
        FilledButton(
          key: const ValueKey('nut-xac-nhan-gop'),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: const Text('Gộp'),
        ),
      ],
    ),
  );
  return dongY == true;
}

class _Dong extends StatelessWidget {
  const _Dong(this.chu, {required this.dam, required this.canhBao});

  final String chu;
  final bool dam;
  final bool canhBao;

  @override
  Widget build(BuildContext context) {
    final mau = canhBao ? AppColors.error : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: canhBao ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chu,
              style: TextStyle(
                color: mau,
                fontWeight: dam
                    ? FontWeight.w700
                    : (canhBao ? FontWeight.w500 : FontWeight.w400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
