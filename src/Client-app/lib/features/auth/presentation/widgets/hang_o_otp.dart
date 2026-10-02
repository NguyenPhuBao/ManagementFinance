import 'package:flutter/material.dart';

/// Hàng ô nhập mã OTP, mỗi ô một chữ số — bố cục dùng chung của màn OTP đăng ký
/// và màn OTP quên mật khẩu.
///
/// Ô rộng tối đa [rongToiDa] và **co lại** khi hàng hẹp hơn, luôn chừa khe
/// [kheToiThieu] giữa hai ô. Trước 2026-10-02 hai màn mỗi nơi một hàng sáu
/// `SizedBox(width: 45)` = 270 dp cứng: vừa ở 411 dp, tràn 7–8 dp ở máy 360 dp
/// (sau hai lớp lề 24 dp chỉ còn ~263 dp) và che mất ô cuối bằng sọc cảnh báo.
class HangOOtp extends StatelessWidget {
  const HangOOtp({super.key, required this.soO, required this.dungO});

  final int soO;

  /// Dựng ô ở vị trí [viTri] (0 là ô trái nhất).
  final Widget Function(int viTri) dungO;

  static const double rongToiDa = 45;
  static const double kheToiThieu = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < soO; i++) ...[
          if (i > 0) const SizedBox(width: kheToiThieu),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: rongToiDa),
              child: dungO(i),
            ),
          ),
        ],
      ],
    );
  }
}
