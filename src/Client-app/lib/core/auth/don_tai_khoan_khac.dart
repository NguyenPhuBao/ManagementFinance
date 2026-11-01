import 'package:flutter/foundation.dart';

/// Phép dọn lúc mở phiên (`PhienDieuPhoi.moPhienCucBo`): chạy [don], rồi — khi CHƯA biết nhà ([nhaGiu] null) — [tinhLaiViNha]
/// (số dư ví nhà bị cắt sổ phải tính lại, xem `SoDuViService.tinhLaiViNha`). Trả số hàng [don] đã xoá.
///
/// ⚠️ Phép tính lại KHÔNG được làm hỏng cửa đăng nhập (G113 lỗ hổng 3): `moPhienCucBo` không `catch`, một lỗi ném ở đây lan
/// tới `AuthBloc` (mở app → về màn Đăng nhập; đăng nhập → `AuthError`) và mỗi lần thử lại chạy lại đúng lỗi ấy, kéo theo mất
/// luôn `daDon`, gói, bộ quét. Nên nuốt lỗi của riêng nó, ghi `runtimeType`; phép tính luỹ đẳng, lần mở sau làm lại.
Future<int> donVaTinhLaiViNha({
  required int? nhaGiu,
  required Future<int> Function() don,
  required Future<void> Function() tinhLaiViNha,
}) async {
  final daDon = await don();
  if (nhaGiu == null) {
    try {
      await tinhLaiViNha();
    } catch (e) {
      debugPrint('[GiaDinh] tính lại số dư ví nhà hỏng, lần mở sau làm lại: ${e.runtimeType}');
    }
  }
  return daDon;
}
