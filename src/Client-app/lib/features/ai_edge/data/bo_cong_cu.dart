/// Bộ tool của bậc tool (chặng 4b): khai báo cho mô hình, tra tool theo tên.
/// `null` từ [chay] = mô hình bịa tên tool — vòng lặp trả lời nó bằng `{"loi": …}`
/// kèm danh sách tên thật, không `them` vào gói.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/data/bao_cao_repository.dart';
import '../../bill/data/repositories/bill_repository.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../goal/data/repositories/goal_repository.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_so_lieu.dart';
import 'cong_cu_chi_tieu.dart';
import 'cong_cu_giao_dich.dart';
import 'cong_cu_goi_y_han_muc.dart';
import 'cong_cu_hoa_don.dart';
import 'cong_cu_muc_tieu.dart';
import 'cong_cu_ngan_sach.dart';
import 'cong_cu_vi.dart';

class BoCongCu {
  BoCongCu(this.cacCongCu);
  final List<CongCu> cacCongCu;

  /// Thứ tự là tín hiệu định tuyến (lần đo 9, 2026-09-25): `tim_giao_dich` đứng
  /// ĐẦU, tổng kết ngay sau, rồi ba tool 4b còn lại và hai tool bước 2. Trước đó
  /// (bốn tool 4b rồi ba tool bước 2) `tim_giao_dich` đứng cuối với chín tham số,
  /// và sáu câu có điều kiện đều rơi vào tool một tham số đứng trước nó — bốn lần
  /// đo liền (5–8).
  factory BoCongCu.macDinh({
    required AnalyticsRepository phanTich,
    required BudgetRepository nganSach,
    required WalletRepository vi,
    required BillRepository hoaDon,
    required GoalRepository mucTieu,
    required TransactionRepository giaoDich,
    required BaoCaoRepository baoCao,
  }) =>
      BoCongCu([
        CongCuGiaoDich(giaoDich: giaoDich, nganSach: nganSach, baoCao: baoCao),
        CongCuChiTieu(phanTich),
        CongCuNganSach(nganSach),
        CongCuHoaDon(hoaDon),
        CongCuVi(vi),
        CongCuMucTieu(mucTieu),
        CongCuGoiYHanMuc(nganSach),
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
