import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../domain/vai_nha.dart';
import '../bloc/nha_cubit.dart';

/// Về lại Nhà mình: đóng hộp thoại đang mở (nếu có) rồi `pop`. `/nha*` là route gốc anh em: `go('/nha')` thay cả stack, Back sau
/// đó thoát app. Chỉ `go` khi không còn gì để pop.
void roiVeNhaMinh(BuildContext context) {
  Navigator.of(context, rootNavigator: true).popUntil((r) => r is! PopupRoute);
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/nha');
  }
}

/// Màn chỉ dành cho Chủ nhà (Mời, Quản lý thành viên): sự kiện từ máy khác làm mất vai, bị mời ra, nhà giải tán ⇒ tự về kèm câu
/// (spec 12.3). [dangTuThaoTac] = thao tác của chính màn này gây ra đổi trạng thái (chuyển chủ, giải tán): màn tự pop, ở đây
/// không làm gì, nếu không là pop hai lần.
class GacVaiChu extends StatelessWidget {
  const GacVaiChu({super.key, required this.child, required this.dangTuThaoTac});

  final Widget child;
  final bool Function() dangTuThaoTac;

  static bool _laChu(NhaState s) => s.nha.coNha && s.nha.vai == VaiNha.chu;

  @override
  Widget build(BuildContext context) => BlocListener<NhaCubit, NhaState>(
        listenWhen: (a, b) => _laChu(a) && !_laChu(b),
        listener: (ctx, s) {
          // Phiên đóng (đăng xuất cưỡng chế): `xoaPhien` đặt id về null rồi mới phát `khongCo` — không phải mất nhà.
          if (ctx.read<NhaCubit>().idToi == null) return;
          if (dangTuThaoTac()) return;
          baoNhanh(s.nha.coNha ? 'Bạn không còn là chủ nhà.' : 'Bạn không còn ở nhà này.');
          roiVeNhaMinh(ctx);
        },
        child: child,
      );
}
