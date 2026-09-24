/// Adapter tool `danh_sach_vi`: đọc repository → `viChoGoiSoTu` → `hangVi`.
library;

import '../../wallet/data/repositories/wallet_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/hang_vi.dart';
import 'nguon_goi_so.dart';

class CongCuVi implements CongCu {
  CongCuVi(this.vi);
  final WalletRepository vi;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuVi,
        moTa: 'Liệt kê các ví của người dùng theo TÊN kèm trạng thái (đang âm, ngoài '
            'tổng, lưu trữ, bình thường) và số dư; cộng tổng tài sản và số ví. Gọi khi '
            'hỏi ví nào đang âm, tiền trong ví còn bao nhiêu, tổng tài sản, có mấy ví.',
        thamSo: {'type': 'object', 'properties': <String, dynamic>{}},
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final vis = await vi.watchAll(idaccount).first;
    return hangVi(viChoGoiSoTu(vis));
  }
}
