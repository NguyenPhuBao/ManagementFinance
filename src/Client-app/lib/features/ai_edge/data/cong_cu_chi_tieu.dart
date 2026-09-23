/// Adapter tool `chi_tieu_theo_ky`: mã kỳ → `Ky` → `watchKy` → `hangChiTieu`.
/// Mã lạ thì từ chối TRƯỚC khi đọc dữ liệu — không đoán kỳ.
library;

import '../../analytics/data/analytics_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_chi_tieu.dart';
import '../domain/hang_so_lieu.dart';

class CongCuChiTieu implements CongCu {
  CongCuChiTieu(this.phanTich);
  final AnalyticsRepository phanTich;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuChiTieu,
        moTa: 'Tổng chi, tổng thu và chi theo từng DANH MỤC (có tên) của một kỳ: hôm '
            'nay, hôm qua, tuần này, tuần trước, tháng này, tháng trước, quý này, năm '
            'nay. Gọi khi hỏi tiêu bao nhiêu trong một kỳ, hoặc chi nhiều nhất vào danh '
            'mục nào.',
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
    if (ky == null) return KetQuaCongCu.loi(loiMaKy(ma));
    final tk = await phanTich.watchKy(idaccount, ky: ky, now: now).first;
    return hangChiTieu(tk, ma: ma);
  }
}
