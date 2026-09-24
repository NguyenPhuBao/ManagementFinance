/// Adapter tool `danh_sach_hoa_don`: đọc repository → `hangHoaDon`.
library;

import '../../bill/data/repositories/bill_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_hoa_don.dart';
import '../domain/hang_so_lieu.dart';

class CongCuHoaDon implements CongCu {
  CongCuHoaDon(this.hoaDon);
  final BillRepository hoaDon;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuHoaDon,
        moTa: 'Liệt kê hoá đơn kỳ này theo TÊN kèm trạng thái và số tiền; cộng tổng '
            'còn phải trả, số hoá đơn quá hạn và chưa trả. Gọi khi hỏi hoá đơn nào quá '
            'hạn, sắp đến hạn, còn phải trả, đã trả, hoặc còn phải trả bao nhiêu.',
        thamSo: {
          'type': 'object',
          'properties': {
            'trang_thai': {
              'type': 'string',
              'enum': kTrangThaiHoaDon,
              'description': 'qua_han: đã quá hạn; chua_tra: còn phải trả (mặc định); '
                  'da_tra: đã trả; tat_ca: mọi hoá đơn kỳ này',
            },
          },
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final bills = await hoaDon.watchBills(idaccount).first;
    return hangHoaDon(
      bills,
      now: now,
      trangThai: args['trang_thai']?.toString() ?? kTrangThaiHoaDonMacDinh,
    );
  }
}
