/// Nguồn dữ liệu của Tầng 2 tái phân bổ (Edge-SLM P2): cờ Cố định, TB 3
/// tháng của từng ngân sách, thu nhập 3 tháng, phản hồi cũ.
///
/// ⚠️ Đặt ở `budget/data/`, **không** ở `ai_edge/`: tệp này đọc bảng giao dịch
/// để tính thu nhập, mà test quét thứ 14 cấm `ai_edge/` chạm bảng ấy. Nó là
/// *nguồn dữ liệu của ngân sách*; lớp AI chỉ nhận [DuLieuTaiPhanBo] đã dựng
/// xong rồi gọi `taiPhanBoCua`.
library;

import '../../../core/database/app_database.dart';
import '../../ai_edge/domain/tai_phan_bo.dart';
import '../../analytics/domain/dong_tien_tu_do.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import '../../analytics/domain/thong_ke_thang.dart';
import '../../analytics/domain/vai_vay_no.dart';
import '../data/models/budget_entity.dart';
import 'repositories/budget_repository.dart';

class DuLieuTaiPhanBo {
  /// Tập **categoryId** có cờ Cố định.
  final Set<String> coDinh;

  /// Trung bình `thuNhapCua` của ba tháng liền trước; `0` khi chưa có gì.
  final double thuNhap3Thang;

  /// `BudgetRepository.suggestAmount` của từng ngân sách (TB 3 tháng làm tròn
  /// lên 10k, `null` khi không có lịch sử) — khoá là `budget.id`.
  final Map<String, double?> tb3ThangTheoNganSach;

  final List<PhanHoiCu> phanHoi;

  const DuLieuTaiPhanBo({
    required this.coDinh,
    required this.thuNhap3Thang,
    required this.tb3ThangTheoNganSach,
    required this.phanHoi,
  });

  static const DuLieuTaiPhanBo rong = DuLieuTaiPhanBo(
    coDinh: {},
    thuNhap3Thang: 0,
    tb3ThangTheoNganSach: {},
    phanHoi: [],
  );
}

abstract class TaiPhanBoNguon {
  Future<DuLieuTaiPhanBo> nap(
    int idaccount,
    List<BudgetView> dangChay,
    DateTime now,
  );
}

class TaiPhanBoNguonImpl implements TaiPhanBoNguon {
  final AppDatabase db;
  final BudgetRepository budgets;

  const TaiPhanBoNguonImpl({required this.db, required this.budgets});

  @override
  Future<DuLieuTaiPhanBo> nap(
    int idaccount,
    List<BudgetView> dangChay,
    DateTime now,
  ) async {
    // Bảng tra tên/classify gồm cả hàng đã xoá mềm và hàng mặc định toàn cục —
    // một định nghĩa ở `getBangTraTen` (G41).
    final cats = await db.categoryDao.getBangTraTen(idaccount);
    final coDinh = {
      for (final c in cats)
        if (c.aiCoDinh && !c.isDeleted) c.id,
    };

    final tb = <String, double?>{};
    for (final v in dangChay) {
      final cat = v.budget.categoryId;
      if (cat == null) continue;
      tb[v.budget.id] = await budgets.suggestAmount(idaccount, cat, now: now);
    }

    final phanHoi = [
      for (final r in await db.aiFeedbackDao.getAll(idaccount))
        PhanHoiCu(
          donorBudgetId: r.donorBudgetId,
          action: r.action,
          periodFrom: r.periodFrom,
        ),
    ];

    return DuLieuTaiPhanBo(
      coDinh: coDinh,
      thuNhap3Thang: await _thuNhap3Thang(idaccount, cats, now),
      tb3ThangTheoNganSach: tb,
      phanHoi: phanHoi,
    );
  }

  /// Trung bình thu nhập ba tháng liền trước, bằng **đúng** `thuNhapCua` (tổng
  /// thu trừ tiền đi vay / thu nợ / khoản vay-nợ tiền vào) — không phải
  /// `type = 'thu'` trần (bẫy A8 #8). Chép khối dựng `KhoanThuChi` của
  /// `analytics_repository_impl.dart` (`_dung`, khoản `khoan`).
  Future<double> _thuNhap3Thang(
    int idaccount,
    List<Category> cats,
    DateTime now,
  ) async {
    final txs = await db.transactionDao.getAll(idaccount);
    final classifyTheoId = {for (final c in cats) c.id: c.classify};
    final tenTheoId = {for (final c in cats) c.id: c.name};
    final khoan = [
      for (final t in txs)
        KhoanThuChi(
          ngay: t.date,
          soTien: t.amount,
          loai: t.type,
          categoryId: t.categoryId,
          classify: t.categoryId == null ? null : classifyTheoId[t.categoryId],
          ghiChu: t.note,
          tenDanhMuc: t.categoryId == null ? null : tenTheoId[t.categoryId],
        ),
    ];
    // Bốn kỳ kết thúc ở tháng hiện tại, cũ nhất trước → ba phần tử đầu là ba
    // tháng liền trước.
    final ky = Ky.thang(now.year, now.month);
    final vayNo = chuoiVayNo(khoan, ky: ky, soKy: 4).take(3).toList();
    if (vayNo.isEmpty) return 0;
    var tong = 0.0;
    for (final d in vayNo) {
      final t = tongThuChi(khoan, from: d.ky.from, to: d.ky.to);
      tong += thuNhapCua(tong: t, vayNo: d);
    }
    return tong / vayNo.length;
  }
}
