/// Nhãn của một **nhóm** ô bằng nhau, co **cùng một hệ số** — hệ số của nhãn rộng nhất nhóm.
///
/// `FittedBox` riêng từng nhãn (G68 thanh điều hướng, G76 tab Ngân sách, hàng nút nhanh Trang chủ) co nhãn dài mà giữ
/// nhãn ngắn, nên ở khổ hẹp / cỡ chữ lớn các nhãn cạnh nhau lệch cỡ (Realme 320 dp, cỡ chữ 1,6 — buổi 4
/// `KHOA_APP_FEATURE.md`, 2026-10-26: *"Quét"*, *"Nói"* to hơn hẳn *"Thêm thu"*). Ở đây mỗi ô đo **cả nhóm** bằng
/// cùng họ chữ (`DefaultTextStyle`) và cùng cỡ chữ hệ thống (`textScaler`), rồi vẽ cỡ đã co với `TextScaler.noScaling`
/// (cỡ chữ hệ thống chỉ áp một lần). Ô đủ rộng thì giữ nguyên cỡ thiết kế, không bao giờ phóng.
///
/// ⚠️ Nhóm chỉ đúng khi các ô **bằng nhau** (`Expanded` đều, `TabBar` cố định) — mỗi ô tự tính hệ số trên bề rộng của nó.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/do_chu.dart';

class NhanCoDeu extends StatelessWidget {
  const NhanCoDeu(this.chu, {super.key, required this.nhom, this.kieu});

  final String chu;

  /// Mọi nhãn cùng nhóm (gồm cả [chu]).
  final List<String> nhom;

  /// Kiểu riêng — gộp lên `DefaultTextStyle` (ví dụ kiểu nhãn mà `TabBar` đặt).
  final TextStyle? kieu;

  @override
  Widget build(BuildContext context) {
    final goc = DefaultTextStyle.of(context).style.merge(kieu);
    final heChu = MediaQuery.textScalerOf(context);
    final huong = Directionality.of(context);
    double rongNhat(double co) {
      var r = 0.0;
      for (final n in nhom) {
        final p = TextPainter(
          text: TextSpan(text: n, style: goc.copyWith(fontSize: co)),
          textDirection: huong,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        r = math.max(r, p.width);
        p.dispose();
      }
      return r;
    }

    // `BoCucTheoFont`: font Inter nạp sau khung đầu — đo lại khi ấy, nếu không nhãn giữ cỡ đo theo font dự phòng (máy ảo
    // 320 dp × cỡ chữ 1,6, 2026-10-26: nút *"Googl"* cụt ở màn Đăng nhập mở lạnh).
    return BoCucTheoFont(builder: (context, rang) {
      var co = heChu.scale(goc.fontSize ?? 14);
      if (rang.hasBoundedWidth) {
        // Bề rộng chữ KHÔNG tỉ lệ thẳng theo cỡ (metric làm tròn theo cỡ): đo lại ở cỡ đã co, chỉnh tới khi vừa — một lượt
        // chia thẳng từng để nhãn tab Ngân sách lố 0,3 dp ở cỡ chữ 1,76 (`budget_tabs_hep_test`).
        for (var lan = 0; lan < 4; lan++) {
          final r = rongNhat(co);
          if (r <= rang.maxWidth || r == 0) break;
          co *= rang.maxWidth / r * 0.999;
        }
      }
      return Text(
        chu,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: goc.copyWith(fontSize: co),
      );
    });
  }
}
