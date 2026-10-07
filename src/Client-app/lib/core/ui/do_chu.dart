import 'package:flutter/widgets.dart';

/// Bề rộng một dòng chữ như `Text` sẽ vẽ: cùng kiểu kế thừa
/// (`DefaultTextStyle`, tức cả họ font của theme) và cùng cỡ chữ hệ thống của
/// [context].
///
/// Dùng để chọn bố cục theo **bề rộng thật** thay vì đoán theo hệ số cỡ chữ
/// hay một mốc dp cố định: header trang Phân tích (G2) và thẻ hoá đơn (G74)
/// đều xếp chồng khi đo thấy không vừa một hàng. Màn hẹp có hai nguồn — cỡ chữ
/// hệ thống lớn, và "cỡ hiển thị" của ColorOS (đổi mật độ, 360 → 320 dp) — và
/// phép đo này phủ cả hai.
double doRongChu(BuildContext context, String chu, TextStyle kieu) {
  final tp = TextPainter(
    text: TextSpan(
        text: chu, style: DefaultTextStyle.of(context).style.merge(kieu)),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final rong = tp.width;
  tp.dispose();
  return rong;
}
