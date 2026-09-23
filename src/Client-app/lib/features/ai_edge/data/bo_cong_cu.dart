/// Bộ tool của bậc tool (chặng 4b): khai báo cho mô hình, tra tool theo tên.
/// `null` từ [chay] = mô hình bịa tên tool — vòng lặp trả lời nó bằng `{"loi": …}`
/// kèm danh sách tên thật, không `them` vào gói.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../bill/data/repositories/bill_repository.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_so_lieu.dart';
import 'cong_cu_chi_tieu.dart';
import 'cong_cu_hoa_don.dart';
import 'cong_cu_ngan_sach.dart';
import 'cong_cu_vi.dart';

class BoCongCu {
  BoCongCu(this.cacCongCu);
  final List<CongCu> cacCongCu;

  /// Bốn tool của lát 4b, đúng thứ tự bảng 5.6 đặt hàng.
  factory BoCongCu.macDinh({
    required AnalyticsRepository phanTich,
    required BudgetRepository nganSach,
    required WalletRepository vi,
    required BillRepository hoaDon,
  }) =>
      BoCongCu([
        CongCuNganSach(nganSach),
        CongCuHoaDon(hoaDon),
        CongCuVi(vi),
        CongCuChiTieu(phanTich),
      ]);

  List<KhaiBaoCongCu> get khaiBao => [for (final c in cacCongCu) c.khaiBao];

  List<String> get tenCacCongCu => [for (final c in cacCongCu) c.khaiBao.ten];

  Future<KetQuaCongCu?> chay(
    String ten,
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    for (final c in cacCongCu) {
      if (c.khaiBao.ten == ten) {
        return c.chay(args, idaccount: idaccount, now: now);
      }
    }
    return null;
  }
}
