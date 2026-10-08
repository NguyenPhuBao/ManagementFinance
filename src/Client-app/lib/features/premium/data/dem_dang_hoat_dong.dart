import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
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
        final rows = await db.billDao.getAll(idaccount); // đã lọc deletedAt
        return rows.where((r) => !r.isPaid && r.payStatus != 'Payed').length;
      case LoaiTran.danhMucRieng:
        final rows = await db.categoryDao.getAll(idaccount);
        return rows.where((r) => !r.isDefault && r.idaccount == idaccount).length;
    }
  }
}
