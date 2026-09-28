/// Adapter tool `tong_quan_tai_chinh` (spec mở rộng tool 2026-09-27 §4.2): đọc
/// `AnalyticsRepository.watchKy` HAI lần — kỳ đang hỏi, và một kỳ trùm mọi
/// thời gian cho dư nợ vay/nợ — rồi giao cho `hangTongQuan`.
///
/// `ky` bắt buộc như tool giao dịch, nhưng bộ chỉnh mặc định **tháng này** khi
/// câu không nêu kỳ: "thu nhập mọi thời gian" không phải câu người dùng hỏi.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_giao_dich.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/hang_tong_quan.dart';
import '../domain/loi_tham_so.dart';
import '../domain/ma_ky.dart';

class CongCuTongQuan implements CongCu {
  CongCuTongQuan(this.phanTich, {this.log = print});
  final AnalyticsRepository phanTich;
  final void Function(String) log;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuTongQuan,
        moTa: 'Gọi khi hỏi thu nhập, để dành hay tiết kiệm được bao nhiêu phần trăm, '
            'dòng tiền tự do, chi trung bình mỗi ngày, ngày nào chi nhiều nhất, tổng '
            'tài sản tăng hay giảm, đang cho vay hay đang nợ bao nhiêu. Thu nhập '
            'không gồm tiền đi vay và tiền thu nợ; vay nợ tính mọi thời gian.',
        thamSo: {
          'type': 'object',
          'properties': {
            'ky': {
              'type': 'string',
              'enum': [...kMaKy.keys, kMaKyTuyChon],
              'description': 'Kỳ đang hỏi; không nêu thì thang_nay. $kMaKyTuyChon: '
                  'điền tu_ngay, den_ngay.',
            },
            'tu_ngay': {'type': 'string', 'description': 'dd/mm/yyyy.'},
            'den_ngay': {'type': 'string', 'description': 'dd/mm/yyyy.'},
          },
          'required': ['ky'],
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final chinh = chinhThamSoTongQuan(cauHoi, args, now: now);
    if (chinh.ghiChu.isNotEmpty) {
      log('[SLM][tool] chỉnh tham số theo câu hỏi: ${chinh.ghiChu.join('; ')}');
    }
    final a = chinh.args;
    final maKy = a['ky']?.toString().trim() ?? '';
    final hopLe = [...kMaKy.keys, kMaKyTuyChon];
    final Ky ky;
    if (maKy == kMaKyTuyChon) {
      final k = khoangTuThamSo(a['tu_ngay'], a['den_ngay']);
      if (k == null) return tuChoiKhoangNgay(a['tu_ngay'], a['den_ngay']);
      // Trọn MỘT tháng dương lịch thì là kỳ tháng: chuỗi sáu kỳ và các phép
      // lùi của trang Phân tích khi ấy lùi theo lịch, không theo số ngày.
      final tronThang = k.from.day == 1 &&
          k.to == DateTime(k.from.year, k.from.month + 1, 1);
      ky = tronThang
          ? Ky.thang(k.from.year, k.from.month)
          : Ky.tuyChon(from: k.from, to: k.to);
    } else {
      final k = kyTuMa(maKy, now);
      if (k == null) return tuChoiGiaTri('ky', maKy, hopLe);
      ky = k;
    }
    final tk = await phanTich.watchKy(idaccount, ky: ky, now: now).first;
    // Dư nợ vay/nợ không theo kỳ: một kỳ trùm từ mốc xa tới hết hôm nay.
    final moiLuc = await phanTich
        .watchKy(
          idaccount,
          ky: Ky.tuyChon(
            from: DateTime(1970),
            to: DateTime(now.year, now.month, now.day + 1),
          ),
          now: now,
        )
        .first;
    final kq = hangTongQuan(
      tk,
      vayNoMoiLuc: moiLuc.chuoiVayNo.isEmpty ? null : moiLuc.chuoiVayNo.last,
      now: now,
      chuKy: maKy == kMaKyTuyChon ? kChuKyTuyChon : kMaKy[maKy]!,
      nhom: nhomTongQuanTheoCauHoi(cauHoi),
    );
    if (maKy != kMaKyTuyChon) return kq;
    return ganKyTuyChon(
      kq,
      from: ky.from,
      to: ky.to,
      chu: chinh.chuKy ??
          chuKhoangNgay(ky.from, DateTime(ky.to.year, ky.to.month, ky.to.day - 1)),
      ten: chinh.tenKy,
      now: now,
    );
  }
}
