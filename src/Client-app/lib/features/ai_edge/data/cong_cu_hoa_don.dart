/// Adapter tool `danh_sach_hoa_don`: bộ chỉnh tham số theo câu hỏi
/// (`chinhThamSoHoaDon`) → đọc repository → `hangHoaDon`.
library;

import '../../bill/data/repositories/bill_repository.dart';
import '../../../core/utils/khop_ten.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_hoa_don.dart';
import '../domain/hang_so_lieu.dart';

class CongCuHoaDon implements CongCu {
  CongCuHoaDon(this.hoaDon, {this.log = print});
  final BillRepository hoaDon;

  /// Log khi bộ chỉnh tham số đổi gì đó — `print`, không `debugPrint` (bẫy 4.31).
  final void Function(String) log;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuHoaDon,
        moTa: 'Liệt kê hoá đơn theo TÊN kèm trạng thái, số tiền, ngày đến hạn; cộng '
            'tổng còn phải trả, số quá hạn, chưa trả, số tự trả và tiền cố định mỗi '
            'tháng. Gọi khi hỏi hoá đơn nào quá hạn, sắp đến hạn, còn phải trả, đã trả, '
            'còn phải trả bao nhiêu, tháng tới phải trả hoá đơn nào, hoá đơn nào tự '
            'trả, cố định mỗi tháng bao nhiêu.',
        thamSo: {
          'type': 'object',
          'properties': {
            'trang_thai': {
              'type': 'string',
              'enum': kTrangThaiHoaDon,
              'description': 'qua_han: đã quá hạn; chua_tra: còn phải trả (mặc định); '
                  'da_tra: đã trả; tat_ca: mọi trạng thái',
            },
            'ky': {
              'type': 'string',
              'enum': kKyHoaDon,
              'description': 'ky_nay: tháng này và nợ cũ (mặc định); ky_toi: tháng '
                  'tới, kể cả kỳ dự kiến; tat_ca: mọi tháng',
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
    final chinh = chinhThamSoHoaDon(cauHoi, args);
    if (chinh.ghiChu.isNotEmpty) {
      log('[SLM][tool] chỉnh tham số theo câu hỏi: ${chinh.ghiChu.join('; ')}');
    }
    final bills = await hoaDon.watchBills(idaccount).first;
    // G3 cổng F (E8): câu nêu tên một hoá đơn → tập của riêng nó, mọi trạng thái.
    final ten = tenNeuTrongCau(cauHoi, [for (final b in bills) b.name], tuLoai: 'hoá đơn');
    if (ten != null) log('[SLM][tool] câu hỏi nêu hoá đơn → chỉ "$ten", mọi trạng thái');
    return hangHoaDon(
      bills,
      now: now,
      trangThai:
          chinh.args['trang_thai']?.toString() ?? kTrangThaiHoaDonMacDinh,
      ky: chinh.args['ky']?.toString() ?? kKyHoaDonMacDinh,
      ten: ten,
      tuTra: chinh.args['tu_tra'] == true,
    );
  }
}
