/// Adapter tool `danh_sach_ngan_sach`: đọc repository → `hangNganSach`. Không
/// tính gì; không tự đọc phiên (idaccount do vòng lặp truyền).
library;

import '../../budget/data/repositories/budget_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_ngan_sach.dart';
import '../domain/hang_so_lieu.dart';
import 'nguon_goi_so.dart';

class CongCuNganSach implements CongCu {
  CongCuNganSach(this.nganSach);
  final BudgetRepository nganSach;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuNganSach,
        moTa: 'Liệt kê các ngân sách đang chạy theo TÊN, kèm trạng thái, đã chi, '
            'hạn mức, tỉ lệ đã dùng, còn lại và số ngày còn lại; cộng tổng còn lại '
            'của mọi ngân sách. Gọi khi hỏi ngân sách nào sắp hết hoặc vượt, còn bao '
            'nhiêu tiền ngân sách, đã dùng bao nhiêu phần trăm.',
        thamSo: {'type': 'object', 'properties': <String, dynamic>{}},
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final tatCa = await nganSach.watchBudgets(idaccount, now: now).first;
    return hangNganSach(nganSachDangChay(tatCa, now), now: now);
  }
}
