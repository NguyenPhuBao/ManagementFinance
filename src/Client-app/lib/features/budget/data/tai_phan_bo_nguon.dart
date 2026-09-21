/// Nguồn dữ liệu của Tầng 2 tái phân bổ (Edge-SLM P2): cờ Cố định, mức mỗi
/// tháng của từng ngân sách, thu nhập mỗi tháng, phản hồi cũ.
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
import '../domain/cua_so_nhin_lai.dart';
import 'repositories/budget_repository.dart';

class DuLieuTaiPhanBo {
  /// Tập **categoryId** có cờ Cố định.
  final Set<String> coDinh;

  /// Thu nhập trung bình **mỗi tháng**, suy từ `cuaSoNhinLai`; `0` khi chưa đủ
  /// dữ liệu để nói.
  ///
  /// ⚠️ Tên cũ là `thuNhap3Thang`, đổi ngày 2026-09-21: cửa sổ nay **cuộn**
  /// theo ngày (tối đa 90, ngắn lại theo tuổi dữ liệu) chứ không còn là ba
  /// tháng lịch liền trước — và cửa sổ cũ rỗng trên mọi dữ liệu thật, nên con
  /// số này luôn bằng 0 cho tới khi đổi.
  final double thuNhapMoiThang;

  /// `BudgetRepository.suggestAmount` của từng ngân sách (mức mỗi tháng, làm
  /// tròn lên 10k, `null` khi không có lịch sử) — khoá là `budget.id`.
  final Map<String, double?> mucThangTheoNganSach;

  final List<PhanHoiCu> phanHoi;

  const DuLieuTaiPhanBo({
    required this.coDinh,
    required this.thuNhapMoiThang,
    required this.mucThangTheoNganSach,
    required this.phanHoi,
  });

  static const DuLieuTaiPhanBo rong = DuLieuTaiPhanBo(
    coDinh: {},
    thuNhapMoiThang: 0,
    mucThangTheoNganSach: {},
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
      thuNhapMoiThang: await _thuNhapMoiThang(idaccount, cats, now),
      mucThangTheoNganSach: tb,
      phanHoi: phanHoi,
    );
  }

  /// Thu nhập trung bình **mỗi tháng**, suy từ [cuaSoNhinLai].
  ///
  /// Vẫn đi qua **đúng** `thuNhapCua` (tổng thu trừ tiền đi vay / thu nợ /
  /// khoản vay-nợ tiền vào) — không phải `type = 'thu'` trần (bẫy A8 #8). Chép
  /// khối dựng `KhoanThuChi` của `analytics_repository_impl.dart` (`_dung`,
  /// khoản `khoan`).
  ///
  /// ⚠️ Chỉ **cửa sổ** đổi, luật thu nhập giữ nguyên. Trước 2026-09-21 hàm này
  /// cắt ba tháng lịch liền trước và trả 0 trên mọi dữ liệu thật, nên phép neo
  /// ngưỡng theo thu nhập luôn rơi về sàn.
  Future<double> _thuNhapMoiThang(
    int idaccount,
    List<Category> cats,
    DateTime now,
  ) async {
    final cuaSo = cuaSoNhinLai(
      now,
      await db.transactionDao.getFirstTransactionDate(idaccount),
    );
    // Chưa đủ dữ liệu để nói — trả 0 chứ không suy một mức tháng từ vài ngày.
    if (cuaSo == null) return 0;

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
    // MỘT kỳ đúng bằng cửa sổ, thay cho bốn kỳ tháng rồi `take(3)`.
    // `chuoiVayNo` cần một `Ky`; `Ky.tuyChon` nhận đúng biên `[from, to)`.
    final ky = Ky.tuyChon(from: cuaSo.from, to: cuaSo.to);
    final vayNo = chuoiVayNo(khoan, ky: ky, soKy: 1);
    if (vayNo.isEmpty) return 0;

    final tong = tongThuChi(khoan, from: cuaSo.from, to: cuaSo.to);
    final thuNhapCuaSo = thuNhapCua(tong: tong, vayNo: vayNo.first);
    return thuNhapCuaSo / cuaSo.soNgay * kSoNgayMotThang;
  }
}
