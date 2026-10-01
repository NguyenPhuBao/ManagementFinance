/// Adapter tool `du_bao_dong_tien` (spec mở rộng tool 2026-09-27 §4.1). Đọc MỘT
/// nguồn — `AnalyticsRepository.watchKy` — vì `ThongKeKy.duBao` đã là kết quả
/// của `duBaoCua` trên đúng bốn nguồn của khối *Dự báo 30 ngày tới* (hoá đơn,
/// mục tiêu, ngân sách đang chạy tại `now`, ví). Tool không gọi lại `duBaoCua`:
/// gọi lại là dựng bản thứ hai của phép ghép bốn nguồn ấy.
///
/// Dự báo luôn tính từ hôm nay nên kỳ truyền vào chỉ để có một `ThongKeKy` —
/// tháng chứa `now`. Không tham số; tham số mô hình điền thừa bị bỏ qua.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_du_bao.dart';
import '../domain/hang_so_lieu.dart';

class CongCuDuBao implements CongCu {
  CongCuDuBao(this.phanTich);
  final AnalyticsRepository phanTich;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuDuBao,
        moTa: 'Gọi khi hỏi còn tiêu được bao nhiêu, tiền có đủ trả hoá đơn hay trích '
            'mục tiêu sắp tới không, trả hết hoá đơn thì còn bao nhiêu, sắp tới phải '
            'chi gì. Trả số dư hiện tại, tổng cam kết sắp tới (hoá đơn đến hạn, trích '
            'tự động cho mục tiêu), số còn tiêu được ĐÃ TRỪ cam kết, và ví nào thiếu '
            'tiền. Không có tham số.',
        thamSo: {'type': 'object', 'properties': <String, dynamic>{}},
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final tk = await phanTich
        .watchKy(idaccount, ky: cacKyGanNhat(now, DonViKy.thang).first, now: now)
        .first;
    return hangDuBao(tk.duBao, now: now);
  }
}
