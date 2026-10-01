/// Adapter tool `danh_sach_ngan_sach`: bộ chỉnh tham số theo câu hỏi
/// (`chinhThamSoNganSach`) → đọc repository → `hangNganSach`. Không tính gì;
/// không tự đọc phiên (idaccount do vòng lặp truyền).
library;

import '../../budget/data/de_xuat_nguon.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../budget/data/tai_phan_bo_nguon.dart';
import '../../../core/utils/khop_ten.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/chon.dart';
import '../domain/cong_cu.dart';
import '../domain/goi_so.dart';
import '../domain/hang_ngan_sach.dart';
import '../domain/hang_so_lieu.dart';
import 'nguon_goi_so.dart';

class CongCuNganSach implements CongCu {
  CongCuNganSach(this.nganSach, {required this.taiPhanBo, this.log = print});
  final BudgetRepository nganSach;

  /// Nguồn của kế hoạch tái phân bổ (`chon=can_doi`) — cùng nguồn với thẻ *Đề
  /// xuất cân đối*, qua `keHoachTaiPhanBoTu`.
  final TaiPhanBoNguon taiPhanBo;

  /// Log khi bộ chỉnh tham số đổi gì đó — `print`, không `debugPrint` (bẫy 4.31).
  final void Function(String) log;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuNganSach,
        moTa: 'Liệt kê các ngân sách đang chạy theo TÊN, kèm trạng thái, đã chi, '
            'hạn mức, tỉ lệ đã dùng, còn lại và số ngày còn lại; cộng tổng còn lại '
            'của mọi ngân sách. Gọi khi hỏi ngân sách nào sắp hết hoặc vượt, còn bao '
            'nhiêu tiền ngân sách, đã dùng bao nhiêu phần trăm. chon: lọc hoặc chọn '
            'theo tỉ lệ đã dùng — hỏi ngân sách nào dưới nửa, sắp hết, ít dùng nhất; '
            'chua_dat = danh mục đang chi mà CHƯA có ngân sách.',
        thamSo: {
          'type': 'object',
          'properties': {
            'chon': {
              'type': 'string',
              'enum': kChon,
              'description': 'Lọc hoặc chọn theo tỉ lệ đã dùng: ${[
                for (final e in kChuChon.entries) '${e.key} = ${e.value}',
              ].join('; ')}. Bỏ trống khi hỏi chung.',
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
    final chinh = chinhThamSoNganSach(cauHoi, args);
    if (chinh.ghiChu.isNotEmpty) {
      log('[SLM][tool] chỉnh tham số theo câu hỏi: ${chinh.ghiChu.join('; ')}');
    }
    final chon = chinh.args['chon']?.toString().trim();
    final tatCa = await nganSach.watchBudgets(idaccount, now: now).first;
    final dangChay = nganSachDangChay(tatCa, now);
    if (chon == 'chua_dat') {
      // Danh mục chưa có ngân sách — cùng nguồn với thẻ "Chưa đặt ngân sách".
      final goi = await deXuatTuKho(nganSach, idaccount, dangChay, toiDa: kToiDaMucMoiGoi);
      return hangChuaDatNganSach(goi, soNganSach: dangChay.length);
    }
    if (chon == 'can_doi') {
      // Tool KHÔNG áp dụng kế hoạch (bất biến ④) — áp dụng ở trang Ngân sách.
      final kh = await keHoachTaiPhanBoTu(taiPhanBo, idaccount, dangChay, now);
      return hangCanDoiNganSach(kh, soNganSach: dangChay.length);
    }
    // G2 cổng F (E10): câu nêu tên một ngân sách đang chạy → chỉ hàng ấy.
    final ten = tenNeuTrongCau(cauHoi, [for (final v in dangChay) v.displayName], tuLoai: 'ngân sách');
    if (ten != null) log('[SLM][tool] câu hỏi nêu ngân sách → chỉ "$ten"');
    return hangNganSach(
      dangChay,
      now: now,
      chon: (chon == null || chon.isEmpty) ? null : chon,
      ten: ten,
    );
  }
}
