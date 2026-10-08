import '../../../core/database/app_database.dart';
import '../../bill/domain/bill_pay_status.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../category/domain/ban_sao_mac_dinh.dart';
import '../../goal/data/models/goal_entity.dart';
import '../domain/tran_goi.dart';

/// Mặt cắt để `redirect` của router tiêm được bản giả (test không dựng CSDL).
abstract class NguonDemDangHoatDong {
  Future<int> dem(LoaiTran loai, int idaccount);
}

/// Số bản ghi **đang hoạt động** của một loại — đầu vào `dangCo` của
/// `conTaoDuoc` (spec Premium 2026-10-06 mục 6.7). Lưu trữ một ví / hoàn thành
/// một mục tiêu là nhả một chỗ — cố ý, cùng luật với bộ chọn ví.
class DemDangHoatDong implements NguonDemDangHoatDong {
  DemDangHoatDong({required this.db, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

  @override
  Future<int> dem(LoaiTran loai, int idaccount) async {
    switch (loai) {
      case LoaiTran.vi:
        // `getActive`: chưa xoá, không lưu trữ — cùng phép đọc với bộ chọn ví.
        return (await db.walletDao.getActive(idaccount)).length;
      case LoaiTran.nganSach:
        final now = _now();
        final rows = await db.budgetDao.getAll(idaccount); // đã lọc deletedAt
        return rows
            .where((r) => !BudgetEntity.fromDrift(r).isExpired(now))
            .length;
      case LoaiTran.mucTieu:
        final rows = await db.goalDao.getAll(idaccount); // đã lọc deletedAt
        return rows.where((r) => !GoalEntity.fromDrift(r).daHoanThanh).length;
      case LoaiTran.hoaDon:
        // Một chuỗi hoá đơn lặp có đúng một kỳ còn phải trả; kỳ `Skipped` / `Payed` không tính (spec phân quyền
        // 2026-10-08 mục 4.2). `conPhaiTra` là định nghĩa duy nhất — không so chuỗi trạng thái ở đây.
        return (await db.billDao.getAll(idaccount)).where(conPhaiTra).length;
      case LoaiTran.danhMucRieng:
        // Bản sao bộ mặc định (seeder, `isDefault: false`) KHÔNG tính — nếu không, 13 bản sao của mọi tài khoản đã
        // vượt trần 5 và Basic không tạo được danh mục nào.
        final khuon = await db.categoryDao.getBackendDefaults();
        return (await db.categoryDao.getAll(idaccount)) // đã lọc deletedAt
            .where((r) => !r.isDefault && !r.isDeleted && !laBanSaoMacDinh(r, khuon))
            .length;
    }
  }
}
