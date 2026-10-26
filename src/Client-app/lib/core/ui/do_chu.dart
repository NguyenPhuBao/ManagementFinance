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
///
/// ⚠️ Đo trong `builder` của [BoCucTheoFont], không phải `LayoutBuilder` trần:
/// font của app nạp sau khung đầu, xem lớp ấy.
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

/// [chu] có vẽ trọn trong tối đa [soDong] dòng ở bề rộng [rong] không — cùng kiểu kế thừa và cỡ chữ hệ thống như
/// [doRongChu]. Cho chỗ chữ được xuống dòng: chọn bố cục khi một khối chữ cạnh nút không còn vừa (thẻ việc chờ duyệt ở
/// Sổ giao dịch, 2026-10-26).
bool vuaSoDong(BuildContext context, String chu, TextStyle kieu, double rong, int soDong) {
  final tp = TextPainter(
    text: TextSpan(
        text: chu, style: DefaultTextStyle.of(context).style.merge(kieu)),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: soDong,
  )..layout(maxWidth: rong);
  final vua = !tp.didExceedMaxLines;
  tp.dispose();
  return vua;
}

/// `LayoutBuilder` dựng lại khi font hệ thống đổi — cho mọi bố cục chọn theo
/// bề rộng chữ đo lúc dựng ([doRongChu], `TextPainter`).
///
/// Font Inter của app tải bằng `google_fonts` (không đóng gói sẵn) và nạp
/// **sau** khung đầu — từ bộ nhớ đệm, hoặc từ mạng ở lần chạy đầu. Trang dựng
/// sớm (màn Đăng nhập, Trang chủ lúc mở lạnh) đo bằng font dự phòng. `Text` tự
/// đo lại khi font nạp xong (`RenderParagraph` nghe
/// `PaintingBinding.systemFonts`), còn phép đo trong `builder` thì không: ràng
/// buộc không đổi nên `LayoutBuilder` không gọi lại — máy ảo 320 dp × cỡ chữ
/// 1,6 (2026-10-26) vẽ nút *"Googl"* cụt chữ vì đo theo font dự phòng hẹp hơn
/// Inter.
class BoCucTheoFont extends StatefulWidget {
  const BoCucTheoFont({super.key, required this.builder});

  final Widget Function(BuildContext context, BoxConstraints rang) builder;

  @override
  State<BoCucTheoFont> createState() => _BoCucTheoFontState();
}

class _BoCucTheoFontState extends State<BoCucTheoFont> {
  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_doiFont);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_doiFont);
    super.dispose();
  }

  void _doiFont() {
    if (mounted) setState(() {});
  }

  // `LayoutBuilder` mới mỗi lần dựng: phần tử của nó gọi lại `builder` khi
  // widget được thay, kể cả khi ràng buộc không đổi.
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: widget.builder);
}
