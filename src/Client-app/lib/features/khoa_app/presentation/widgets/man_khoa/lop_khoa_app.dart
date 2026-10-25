import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../bloc/khoa_app_cubit.dart';
import '../../bloc/khoa_app_state.dart';
import 'man_khoa.dart';

/// Lớp khoá bọc NGOÀI CÙNG trong `MaterialApp.router(builder:)` (spec mục 5). Router vẫn điều hướng bên dưới (chạm thông
/// báo khi đang khoá → trang đích nằm sẵn dưới lớp này). Nằm ngoài `Navigator` → không `showDialog`, không `Tooltip`.
class LopKhoaApp extends StatelessWidget {
  const LopKhoaApp({super.key, required this.child, required this.khiQuenPin, this.dongHo});

  final Widget child;
  final VoidCallback khiQuenPin;
  final DateTime Function()? dongHo;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KhoaAppCubit, TrangThaiKhoaApp>(
      builder: (context, s) {
        final che = s is KhoaAppDangXet || s is KhoaAppDangRoi || s is KhoaAppKhoa;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Trình đọc màn hình không được đọc nội dung dưới lớp khoá.
            ExcludeFocus(excluding: che, child: ExcludeSemantics(excluding: che, child: child)),
            if (s is KhoaAppDangXet || s is KhoaAppDangRoi)
              const Positioned.fill(child: AbsorbPointer(child: ColoredBox(color: AppColors.background))),
            if (s is KhoaAppKhoa)
              Positioned.fill(child: ManKhoa(trangThai: s, khiQuenPin: khiQuenPin, dongHo: dongHo ?? DateTime.now)),
          ],
        );
      },
    );
  }
}
