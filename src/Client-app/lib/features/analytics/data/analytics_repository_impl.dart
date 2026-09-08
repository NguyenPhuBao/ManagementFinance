import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../domain/thong_ke_thang.dart';
import 'analytics_repository.dart';

/// Gộp ba nguồn — giao dịch, danh mục, ngân sách — thành một [ThongKeThang].
///
/// Cùng khuôn với `BudgetRepositoryImpl.watchBudgets`: một controller, mỗi
/// nguồn một subscription, phát khi **cả ba** đã có dữ liệu. Không dùng thư
/// viện rx; dự án không có và ba stream không đáng kéo thêm một phụ thuộc.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AppDatabase db;
  final BudgetRepository budgetRepository;

  AnalyticsRepositoryImpl({required this.db, required this.budgetRepository});

  @override
  Stream<ThongKeThang> watchThang(
    int idaccount, {
    required int nam,
    required int thang,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final bien = bienThang(nam, thang);
    // `thang - 1` bằng 0 tự cuộn về tháng 12 năm trước nhờ `DateTime`.
    final bienTruoc = bienThang(nam, thang - 1);

    // Mốc tra ngân sách. Kỳ ngân sách không trùng tháng dương lịch, nên chọn
    // một điểm trong tháng: tháng hiện tại thì lấy đúng "bây giờ" để số đã chi
    // khớp trang Ngân sách; tháng đã qua thì lấy giây cuối của tháng ấy, để
    // ngân sách nào còn sống tới cuối tháng vẫn được tính.
    final laThangHienTai = at.year == nam && at.month == thang;
    final mocNganSach =
        laThangHienTai ? at : bien.to.subtract(const Duration(seconds: 1));

    final controller = StreamController<ThongKeThang>.broadcast();
    List<Transaction>? txs;
    List<Category>? cats;
    List<BudgetView>? nganSach;

    void push() {
      if (txs == null || cats == null || nganSach == null) return;
      if (controller.isClosed) return;
      try {
        controller.add(_dung(
          nam: nam,
          thang: thang,
          from: bien.from,
          to: bien.to,
          fromTruoc: bienTruoc.from,
          toTruoc: bienTruoc.to,
          mocNganSach: mocNganSach,
          txs: txs!,
          cats: cats!,
          nganSach: nganSach!,
        ));
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    final subTx = db.transactionDao.watchAll(idaccount).listen((rows) {
      txs = rows;
      push();
    }, onError: controller.addError);
    // KỂ CẢ hàng đã xoá mềm — không dùng `categoryDao.watchAll` (lọc
    // `deletedAt`). Giao dịch cũ vẫn trỏ vào danh mục đã xoá, và tên vẫn nằm
    // trong hàng: "Chi khác" có ích hơn "Danh mục đã xoá". Trên máy thật, 5
    // danh mục mặc định bị xoá mềm hôm 2026-09-07 làm cả một lát donut mang
    // tên "Danh mục đã xoá" trong khi tên thật còn đó.
    final subCat = (db.select(db.categories)
          ..where((t) => t.idaccount.equals(idaccount)))
        .watch()
        .listen((rows) {
      cats = rows;
      push();
    }, onError: controller.addError);
    final subNs = budgetRepository
        .watchBudgets(idaccount, now: mocNganSach)
        .listen((rows) {
      nganSach = rows;
      push();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subTx.cancel();
      await subCat.cancel();
      await subNs.cancel();
    };
    return controller.stream;
  }

  ThongKeThang _dung({
    required int nam,
    required int thang,
    required DateTime from,
    required DateTime to,
    required DateTime fromTruoc,
    required DateTime toTruoc,
    required DateTime mocNganSach,
    required List<Transaction> txs,
    required List<Category> cats,
    required List<BudgetView> nganSach,
  }) {
    // `amount` lưu dương ở client (nhánh pull gọi `.abs()`), cộng thẳng —
    // cùng luật với `BudgetLocalDataSourceImpl.sumExpenses`.
    final khoan = [
      for (final t in txs)
        KhoanThuChi(
          ngay: t.date,
          soTien: t.amount,
          loai: t.type,
          categoryId: t.categoryId,
        ),
    ];

    final tong = tongThuChi(khoan, from: from, to: to);
    final tongTruoc = tongThuChi(khoan, from: fromTruoc, to: toTruoc);
    final chi = chiTheoDanhMuc(khoan, from: from, to: to);

    final danhMucTheoId = {for (final c in cats) c.id: c};

    // Ngân sách theo danh mục. Ngân sách tổng (`categoryId == null`) không
    // thuộc dòng nào nên bỏ qua.
    // `watchBudgets` trả CẢ ngân sách đã hết hạn (trang Ngân sách tự chia
    // tab), nên phải lọc ở đây. Bỏ dòng `isExpired` là một ngân sách chết từ
    // tháng 6 vẫn ra "10% ngân sách" ở tháng 9 — bản sai có chủ ý đã chứng
    // minh test bắt được đúng ca này.
    final nganSachTheoDanhMuc = <String, BudgetEntity>{};
    for (final v in nganSach) {
      final id = v.budget.categoryId;
      if (id == null || v.budget.isExpired(mocNganSach)) continue;
      nganSachTheoDanhMuc[id] = v.budget;
    }

    final dong = [
      for (final c in chi)
        () {
          final cat = c.categoryId == null ? null : danhMucTheoId[c.categoryId];
          // Ba ca, ba chữ: có danh mục (kể cả đã xoá mềm — giữ tên thật) /
          // chưa phân loại / id không còn hàng nào (chưa từng đồng bộ về).
          final ten = c.categoryId == null
              ? 'Chưa phân loại'
              : (cat?.name ?? 'Danh mục đã xoá');
          final ns =
              c.categoryId == null ? null : nganSachTheoDanhMuc[c.categoryId];
          return DongDanhMuc(
            categoryId: c.categoryId,
            ten: ten,
            icon: cat?.icon,
            mauHex: cat?.colour,
            soTien: c.soTien,
            tiLeTongChi: c.tiLe,
            nganSachHanMuc: ns?.amount,
            nganSachDaChi: ns?.spent,
          );
        }(),
    ];

    return ThongKeThang(
      nam: nam,
      thang: thang,
      tong: tong,
      tongTruoc: tongTruoc,
      chiTheoDanhMuc: chi,
      danhMuc: dong,
    );
  }
}
