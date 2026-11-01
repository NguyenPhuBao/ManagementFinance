import 'package:flutter/foundation.dart';

/// Phép dọn lúc mở phiên (`PhienDieuPhoi.moPhienCucBo`): chạy [don], rồi — khi CHƯA biết nhà ([nhaGiu] null) — [tinhLaiViNha]
/// (số dư ví nhà bị cắt sổ phải tính lại, xem `SoDuViService.tinhLaiViNha`). Trả số hàng [don] đã xoá.
///
/// ⚠️ Phép tính lại KHÔNG được làm hỏng cửa đăng nhập (G113 lỗ hổng 3): `moPhienCucBo` không `catch`, một lỗi ném ở đây lan
/// tới `AuthBloc` (mở app → về màn Đăng nhập; đăng nhập → `AuthError`) và mỗi lần thử lại chạy lại đúng lỗi ấy, kéo theo mất
/// luôn `daDon`, gói, bộ quét. Nên nuốt lỗi của riêng nó, ghi `runtimeType`; phép tính luỹ đẳng, lần mở sau làm lại.
///
/// Khi ĐÃ biết nhà ([nhaGiu] không null): trước [don], trả tiền nửa của nhà CŨ còn trên máy ([cacNhaConTrenMay] khác [nhaGiu])
/// qua [traVeKhiBoNha] — kho đã nói nhà mới mà máy còn nửa nhà cũ chưa đẩy (tiến trình chết sau khi ghi kho, hoặc phép dọn
/// của `DieuPhoiDoiNha` ném) thì [don] xoá nửa nhà cũ mà không hoàn: tiền ra khỏi ví riêng, quỹ không nhận, im lặng. Cả ba
/// tham số đi cùng nhau (thiếu một = không trả). Lỗi ở bước này bị nuốt như phép tính lại: không được khoá cửa đăng nhập.
Future<int> donVaTinhLaiViNha({
  required int? nhaGiu,
  required Future<int> Function() don,
  required Future<void> Function() tinhLaiViNha,
  int? idaccount,
  Future<List<int>> Function()? cacNhaConTrenMay,
  Future<void> Function(int idNha, int idaccount)? traVeKhiBoNha,
}) async {
  if (nhaGiu != null && idaccount != null && cacNhaConTrenMay != null && traVeKhiBoNha != null) {
    try {
      for (final x in await cacNhaConTrenMay()) {
        if (x == nhaGiu) continue;
        try {
          await traVeKhiBoNha(x, idaccount);
        } catch (e) {
          debugPrint('[GiaDinh] trả tiền nửa nhà cũ hỏng, vẫn dọn: ${e.runtimeType}');
        }
      }
    } catch (e) {
      debugPrint('[GiaDinh] đọc nhà cũ còn trên máy hỏng, vẫn dọn: ${e.runtimeType}');
    }
  }
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
