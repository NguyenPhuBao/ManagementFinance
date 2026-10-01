/// Bộ tool của bậc tool (chặng 4b): khai báo cho mô hình, tra tool theo tên.
/// `null` từ [chay] = mô hình bịa tên tool — vòng lặp trả lời nó bằng `{"loi": …}`
/// kèm danh sách tên thật, không `them` vào gói.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/data/bao_cao_repository.dart';
import '../../bill/data/repositories/bill_repository.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../budget/data/tai_phan_bo_nguon.dart';
import '../../category/data/repositories/category_management_repository.dart';
import '../../goal/data/repositories/goal_repository.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_so_lieu.dart';
import 'cong_cu_danh_muc.dart';
import 'cong_cu_du_bao.dart';
import 'cong_cu_goi_y_han_muc.dart';
import 'cong_cu_hoa_don.dart';
import 'cong_cu_muc_tieu.dart';
import 'cong_cu_ngan_sach.dart';
import 'cong_cu_tong_quan.dart';
import 'cong_cu_truy_van.dart';
import 'cong_cu_vi.dart';

class BoCongCu {
  BoCongCu(this.cacCongCu);
  final List<CongCu> cacCongCu;

  /// Thứ tự là tín hiệu định tuyến (lần đo 9, 2026-09-25): tool giao dịch đứng
  /// ĐẦU (từ 2026-09-27 là `truy_van_giao_dich`, thay hai tool cũ), rồi ba tool
  /// 4b còn lại và hai tool bước 2. Trước đó
  /// (bốn tool 4b rồi ba tool bước 2) `tim_giao_dich` đứng cuối với chín tham số,
  /// và sáu câu có điều kiện đều rơi vào tool một tham số đứng trước nó — bốn lần
  /// đo liền (5–8). Tool của spec mở rộng (2026-09-27) nối vào CUỐI — thứ tự sáu
  /// tool đã đo không đổi.
  factory BoCongCu.macDinh({
    required BudgetRepository nganSach,
    required WalletRepository vi,
    required BillRepository hoaDon,
    required GoalRepository mucTieu,
    required TransactionRepository giaoDich,
    required BaoCaoRepository baoCao,
    required AnalyticsRepository phanTich,
    required CategoryManagementRepository danhMuc,
    required TaiPhanBoNguon taiPhanBo,
  }) =>
      BoCongCu([
        CongCuTruyVan(giaoDich: giaoDich, nganSach: nganSach, baoCao: baoCao, mucTieu: mucTieu),
        CongCuNganSach(nganSach, taiPhanBo: taiPhanBo),
        CongCuHoaDon(hoaDon),
        CongCuVi(vi),
        CongCuMucTieu(mucTieu, vi: vi),
        CongCuGoiYHanMuc(nganSach),
        CongCuDuBao(phanTich),
        CongCuTongQuan(phanTich),
        CongCuDanhMuc(danhMuc: danhMuc, nganSach: nganSach),
      ]);

  List<KhaiBaoCongCu> get khaiBao => [for (final c in cacCongCu) c.khaiBao];

  /// Khai báo gửi cho MÔ HÌNH ở một phiên. Câu hỏi đã định tuyến được
  /// ([tenDich] có và bộ tool có nó) → chỉ MỘT tool ấy: prompt ngắn hẳn, và mô
  /// hình không còn gì để chọn nhầm. Không thì mọi tool TRỪ nhóm chỉ đi qua
  /// định tuyến (`kCongCuChiQuaDinhTuyen`).
  ///
  /// ⚠️ [chay] vẫn chạy được MỌI tool của bộ — phép thu hẹp chỉ áp cho thứ mô
  /// hình nhìn thấy.
  List<KhaiBaoCongCu> khaiBaoCho(String? tenDich) {
    if (tenDich != null) {
      final mot = [
        for (final c in cacCongCu)
          if (c.khaiBao.ten == tenDich) c.khaiBao,
      ];
      if (mot.isNotEmpty) return mot;
    }
    return [
      for (final c in cacCongCu)
        if (!kCongCuChiQuaDinhTuyen.contains(c.khaiBao.ten)) c.khaiBao,
    ];
  }

  List<String> get tenCacCongCu => [for (final c in cacCongCu) c.khaiBao.ten];

  Future<KetQuaCongCu?> chay(
    String ten,
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    for (final c in cacCongCu) {
      if (c.khaiBao.ten == ten) {
        return c.chay(args, idaccount: idaccount, now: now, cauHoi: cauHoi);
      }
    }
    return null;
  }
}
