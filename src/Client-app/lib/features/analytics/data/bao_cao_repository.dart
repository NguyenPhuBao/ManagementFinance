import '../domain/bao_cao_xuat.dart';

/// Một lựa chọn của bộ lọc trên trang Xuất báo cáo — dùng chung cho chip ví và
/// danh sách danh mục.
///
/// Cố ý **không** trả hàng Drift lên giao diện: trang chỉ cần id để lọc và tên
/// để hiện, và giữ như vậy thì thay nguồn dữ liệu không phải sửa widget.
class LuaChonLoc {
  final String id;
  final String ten;

  const LuaChonLoc({required this.id, required this.ten});
}

abstract class BaoCaoRepository {
  /// Một **ảnh chụp** theo bộ lọc: màn Xem trước là tờ báo cáo của một khoảng
  /// đã chốt, không phải bảng điều khiển sống. Trả `Future` chứ không `Stream`
  /// để nội dung không đổi dưới tay người dùng khi đang đọc.
  Future<BaoCao> layBaoCao(int idaccount, {required LocBaoCao loc});

  /// Ví **còn sống** của tài khoản, cho chip "Lọc theo ví".
  Stream<List<LuaChonLoc>> watchVi(int idaccount);

  /// Danh mục **còn sống** của tài khoản, cho ô "Danh mục".
  Stream<List<LuaChonLoc>> watchDanhMuc(int idaccount);
}
