import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../../shared/theme/kieu_thanh_trang_thai.dart';
import '../../../../../shared/widgets/thoat_hai_lan.dart';
import '../../bloc/khoa_app_cubit.dart';
import '../../bloc/khoa_app_state.dart';
import 'man_khoa.dart';

/// Lớp khoá bọc NGOÀI CÙNG trong `MaterialApp.router(builder:)` (spec mục 5). Router vẫn điều hướng bên dưới (chạm thông
/// báo khi đang khoá → trang đích nằm sẵn dưới lớp này). Nằm ngoài `Navigator` → không `showDialog`, không `Tooltip`.
class LopKhoaApp extends StatefulWidget {
  const LopKhoaApp({super.key, required this.child, required this.khiQuenPin, this.dongHo});

  final Widget child;
  final VoidCallback khiQuenPin;
  final DateTime Function()? dongHo;

  @override
  State<LopKhoaApp> createState() => _LopKhoaAppState();
}

class _LopKhoaAppState extends State<LopKhoaApp> with WidgetsBindingObserver {
  final _manKhoa = GlobalKey<ManKhoaState>();

  @override
  void initState() {
    super.initState();
    // Đăng ký ở `initState` của lớp này — chạy TRƯỚC `Router` con (nơi `RootBackButtonDispatcher` đăng ký), và Flutter hỏi
    // `didPopRoute` theo thứ tự đăng ký (`WidgetsBinding.handlePopRoute`, đọc ở 3.47.8) — nên lớp khoá thắng router.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// M5: Back khi đang che / đang khoá KHÔNG được tới router — nó pop trang nằm dưới lớp khoá (mở khoá xong về trang cha).
  /// Khoá: tấm Quên PIN mở thì Back là Huỷ, còn lại đưa app xuống nền (như Back lần hai ở Trang chủ — G100: không đóng
  /// activity). Lớp đặc (đang xét / đang rời phiên): nuốt Back. `Mo(che)` chỉ có khi app mất tiêu điểm — Back không tới.
  @override
  Future<bool> didPopRoute() async {
    final s = context.read<KhoaAppCubit>().state;
    if (s is KhoaAppKhoa) {
      if (_manKhoa.currentState?.xuLyBackTrenTam() ?? false) return true;
      await duaAppXuongNen();
      return true;
    }
    return s is KhoaAppDangXet || s is KhoaAppDangRoi;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KhoaAppCubit, TrangThaiKhoaApp>(
      builder: (context, s) {
        final che = s is KhoaAppDangXet || s is KhoaAppDangRoi || s is KhoaAppKhoa;
        // F1: `Mo(che)` — app vừa mất tiêu điểm khi khoá bật; lớp ĐẶC để khung cuối trước khi rời màn không mang nội dung.
        // Chỉ che HÌNH, không vào `che` (ExcludeFocus): kéo thanh thông báo lúc đang gõ mà cướp tiêu điểm là đóng bàn phím.
        final dac = s is KhoaAppDangXet || s is KhoaAppDangRoi || (s is KhoaAppMo && s.che);
        const lopDac = AbsorbPointer(child: ColoredBox(color: AppColors.background));
        return Stack(
          fit: StackFit.expand,
          children: [
            // Trình đọc màn hình không được đọc nội dung dưới lớp khoá.
            ExcludeFocus(excluding: che, child: ExcludeSemantics(excluding: che, child: widget.child)),
            // Lớp che của `Mo(che)` (app mất tiêu điểm) không đổi thanh trạng thái — chỉ ba trạng thái che hẳn mới đổi.
            if (dac) Positioned.fill(child: che ? const _KieuThanhTrangThaiKhoa(child: lopDac) : lopDac),
            if (s is KhoaAppKhoa)
              Positioned.fill(
                child: _KieuThanhTrangThaiKhoa(
                  child: ManKhoa(
                    key: _manKhoa,
                    trangThai: s,
                    khiQuenPin: widget.khiQuenPin,
                    dongHo: widget.dongHo ?? DateTime.now,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Thanh trạng thái của màn khoá: kiểu chung của app (`kKieuThanhTrangThaiSang` — trong suốt, biểu tượng tối trên nền kem).
/// Màn khoá vẫn tự bọc vì trang dưới có thể đặt kiểu khác (trang có AppBar màu, màn Quét nền tối) — không có lớp này thì màn
/// khoá ăn theo trang nằm dưới (nghiệm thu Realme 2026-10-25). Gỡ lớp này thì vùng gốc (`VungThanhTrangThaiGoc`) hoặc vùng
/// của trang dưới được tìm thấy lại.
class _KieuThanhTrangThaiKhoa extends StatelessWidget {
  const _KieuThanhTrangThaiKhoa({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: kKieuThanhTrangThaiSang, child: child);
}
