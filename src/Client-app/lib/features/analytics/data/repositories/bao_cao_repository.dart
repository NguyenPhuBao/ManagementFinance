import '../../domain/bao_cao_xuat.dart';
import '../models/lua_chon_loc.dart';

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
