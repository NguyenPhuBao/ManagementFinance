import 'package:flutter/material.dart';

/// Con số lớn ở đầu màn Thêm giao dịch.
///
/// ## Vì sao là một widget riêng
///
/// Nó tồn tại để giữ **một** luật: con số không được xuống dòng. Ở cỡ 48 trên
/// 411dp, `9.999.999.999.999đ` — **đúng trần** mà `themPhimSoTien` cho gõ —
/// ngắt thành hai dòng, chữ "đ" rơi xuống dòng dưới và cả khối đẩy phần còn lại
/// của màn xuống theo. Đo trên máy ảo 2026-09-18.
///
/// ⚠️ **Đây không phải "tràn bố cục"**: không sọc vàng, không `FlutterError`,
/// `takeException()` trả `null`. `Text` chỉ lặng lẽ ngắt dòng. Nên ca test của
/// nó phải đo **số dòng thật sự vẽ ra** (`computeLineMetrics`), không phải sự
/// vắng mặt của một exception — cùng bài học G43.
///
/// ## Vì sao `FittedBox` dùng được ở đây mà không dùng được ở ô số dư ví
///
/// `FittedBox` đo con ở ràng buộc **vô hạn** rồi mới thu nhỏ. `Text` có bề rộng
/// tự nhiên xác định dưới ràng buộc ấy, còn `TextField` thì không — đó là lý do
/// `OSoDuVi` phải đi đường khác (`Flexible` + bậc thang cỡ chữ).
class SoTienLon extends StatelessWidget {
  const SoTienLon({super.key, required this.chu, required this.mau});

  final String chu;
  final Color mau;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // Căn giữa như bản cũ; `scaleDown` chỉ thu nhỏ khi cần nên số ngắn giữ
        // nguyên cỡ 48 của thiết kế.
        alignment: Alignment.center,
        child: Text(
          chu,
          maxLines: 1,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
            color: mau,
          ),
        ),
      ),
    );
  }
}
