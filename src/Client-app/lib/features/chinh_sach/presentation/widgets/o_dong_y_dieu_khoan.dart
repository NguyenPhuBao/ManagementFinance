import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_colors.dart';

/// Ô tick bắt buộc ở màn Đăng ký (spec điều khoản viết cứng 2026-11-16 mục 1). Trạng thái tick + lỗi do trang giữ.
/// Hai cụm chữ mở `/chinh-sach/:ma` (route mở cho cả hai phía — người chưa đăng nhập đọc được).
class ODongYDieuKhoan extends StatefulWidget {
  const ODongYDieuKhoan({super.key, required this.daDongY, required this.hienLoi, required this.khiDoi});

  final bool daDongY;
  final bool hienLoi;
  final ValueChanged<bool> khiDoi;

  @override
  State<ODongYDieuKhoan> createState() => _ODongYDieuKhoanState();
}

class _ODongYDieuKhoanState extends State<ODongYDieuKhoan> {
  late final TapGestureRecognizer _dieuKhoan = TapGestureRecognizer()
    ..onTap = () => context.push('/chinh-sach/dieu-khoan');
  late final TapGestureRecognizer _baoMat = TapGestureRecognizer()
    ..onTap = () => context.push('/chinh-sach/bao-mat');

  @override
  void dispose() {
    _dieuKhoan.dispose();
    _baoMat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const lienKet = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Checkbox(
            key: const Key('o-dong-y'),
            value: widget.daDongY,
            onChanged: (v) => widget.khiDoi(v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              children: [
                const TextSpan(text: 'Tôi đã đọc và đồng ý với '),
                TextSpan(text: 'Điều khoản sử dụng', style: lienKet, recognizer: _dieuKhoan),
                const TextSpan(text: ' và '),
                TextSpan(text: 'Chính sách bảo mật', style: lienKet, recognizer: _baoMat),
              ],
            )),
          ),
        ),
      ]),
      if (widget.hienLoi)
        const Padding(
          padding: EdgeInsets.only(left: 40, top: 4),
          child: Text(
            'Bạn cần đồng ý với Điều khoản sử dụng và Chính sách bảo mật',
            key: Key('loi-dong-y'),
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
    ]);
  }
}
