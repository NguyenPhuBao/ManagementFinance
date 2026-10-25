import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Bàn phím số của khoá ứng dụng — Stitch `34c3cade…`: lưới 3 cột, phím tròn ≤ 72 px, chữ 28, cách ngang 24 dọc 12.
/// Không `IconButton` (lớp khoá nằm ngoài `Navigator` → không có `Overlay` cho `Tooltip`): phím là `InkResponse`.
class BanPhimPin extends StatelessWidget {
  const BanPhimPin({super.key, required this.khiGo, required this.khiXoa, this.khiVanTay, this.tatSo = false});

  final ValueChanged<String> khiGo;
  final VoidCallback khiXoa;
  final VoidCallback? khiVanTay;

  /// Đang chờ sau nhiều lần sai: phím số + xoá tắt; phím vân tay vẫn bật.
  final bool tatSo;

  static const double _toiDa = 72;
  static const double _ngang = 24;
  static const double _doc = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, rang) {
      final theoNgang = (math.min(rang.maxWidth, 288) - 2 * _ngang) / 3;
      final theoDoc = rang.hasBoundedHeight ? (rang.maxHeight - 3 * _doc) / 4 : _toiDa;
      final canh = math.max(40.0, math.min(_toiDa, math.min(theoNgang, theoDoc)));
      Widget o(Widget w) => SizedBox(width: canh, height: canh, child: w);
      Widget so(int d) => o(_Phim(
            key: Key('phim-$d'),
            nhan: '$d',
            bat: !tatSo,
            khiCham: () => khiGo('$d'),
            child: Text('$d',
                style: TextStyle(fontSize: canh * 28 / 72, color: tatSo ? AppColors.outline : AppColors.primary)),
          ));
      Widget hang(List<Widget> c) =>
          Row(mainAxisSize: MainAxisSize.min, children: [c[0], const SizedBox(width: _ngang), c[1], const SizedBox(width: _ngang), c[2]]);
      final vanTay = khiVanTay;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hang([so(1), so(2), so(3)]),
          const SizedBox(height: _doc),
          hang([so(4), so(5), so(6)]),
          const SizedBox(height: _doc),
          hang([so(7), so(8), so(9)]),
          const SizedBox(height: _doc),
          hang([
            vanTay == null
                ? o(const SizedBox.shrink())
                : o(_Phim(
                    key: const Key('phim-van-tay'),
                    nhan: 'Mở bằng vân tay',
                    bat: true,
                    khiCham: vanTay,
                    child: Icon(Icons.fingerprint, size: canh * 32 / 72, color: AppColors.primary),
                  )),
            so(0),
            o(_Phim(
              key: const Key('phim-xoa'),
              nhan: 'Xoá',
              bat: !tatSo,
              khiCham: khiXoa,
              child: Icon(Icons.backspace_outlined,
                  size: canh * 28 / 72, color: tatSo ? AppColors.outline : AppColors.primary),
            )),
          ]),
        ],
      );
    });
  }
}

class _Phim extends StatelessWidget {
  const _Phim({super.key, required this.nhan, required this.bat, required this.khiCham, required this.child});

  final String nhan;
  final bool bat;
  final VoidCallback khiCham;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: bat,
      label: nhan,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: bat ? khiCham : null,
          customBorder: const CircleBorder(),
          child: Center(child: ExcludeSemantics(child: child)),
        ),
      ),
    );
  }
}
