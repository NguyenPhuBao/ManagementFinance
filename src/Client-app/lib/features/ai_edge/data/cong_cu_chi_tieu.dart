/// Adapter tool `tong_ket_thu_chi_ky` (tên cũ `chi_tieu_theo_ky` tới 2026-09-24):
/// mã kỳ → `Ky` → `watchKy` → `hangChiTieu`.
/// Mã lạ thì từ chối TRƯỚC khi đọc dữ liệu — không đoán kỳ.
library;

import '../../analytics/data/analytics_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_chi_tieu.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/loi_tham_so.dart';

class CongCuChiTieu implements CongCu {
  CongCuChiTieu(this.phanTich);
  final AnalyticsRepository phanTich;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuTongKet,
        moTa: 'Tổng chi, tổng thu và tổng chi theo từng DANH MỤC (có tên) của một kỳ — '
            'chỉ có TỔNG, không liệt kê từng khoản. Gọi khi hỏi tiêu bao nhiêu trong một '
            'kỳ, hoặc danh mục nào chi nhiều nhất. Hỏi tiêu gì, những khoản nào, khoản thu '
            'nào, khoản lớn nhất, khoản của một ví, trên hay dưới một số tiền thì dùng '
            'tim_giao_dich.',
        thamSo: {
          'type': 'object',
          'properties': {
            'ky': {
              'type': 'string',
              'enum': kMaKy.keys.toList(),
              'description': [
                for (final e in kMaKy.entries) '${e.key} = ${e.value}',
              ].join('; '),
            },
          },
          'required': ['ky'],
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    final ma = args['ky']?.toString() ?? '';
    final ky = kyTuMa(ma, now);
    if (ky == null) return tuChoiGiaTri('ky', ma, kMaKy.keys);
    final tk = await phanTich.watchKy(idaccount, ky: ky, now: now).first;
    return hangChiTieu(tk, ma: ma);
  }
}
