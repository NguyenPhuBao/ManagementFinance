import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../domain/pham_vi_ky.dart';
import '../domain/phan_loai_dong_tien.dart';
import '../domain/thong_ke_thang.dart';
import 'analytics_repository.dart';

/// Gộp ba nguồn — giao dịch, danh mục, ngân sách — thành một [ThongKeKy].
///
/// Cùng khuôn với `BudgetRepositoryImpl.watchBudgets`: một controller, mỗi
/// nguồn một subscription, phát khi **cả ba** đã có dữ liệu. Không dùng thư
/// viện rx; dự án không có và ba stream không đáng kéo thêm một phụ thuộc.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AppDatabase db;
  final BudgetRepository budgetRepository;

  AnalyticsRepositoryImpl({required this.db, required this.budgetRepository});

  @override
  Stream<ThongKeKy> watchKy(
    int idaccount, {
    required Ky ky,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    // Kỳ liền trước mượn nguyên `khoangKyTruoc` — hàm đã đúng cho cả năm đơn
    // vị: tuần lùi 7 ngày, tháng/quý/năm lùi theo tháng dương lịch, khoảng tuỳ
    // chọn lùi đúng độ dài của nó.
    final truoc = khoangKyTruoc(from: ky.from, to: ky.to);

    // Mốc tra ngân sách. Kỳ ngân sách không trùng kỳ đang xem, nên chọn một
    // điểm trong kỳ: kỳ đang diễn ra thì lấy đúng "bây giờ" để số đã chi khớp
    // trang Ngân sách; kỳ đã qua thì lấy giây cuối của kỳ ấy, để ngân sách nào
    // còn sống tới cuối kỳ vẫn được tính.
    final mocNganSach =
        ky.chua(at) ? at : ky.to.subtract(const Duration(seconds: 1));

    final controller = StreamController<ThongKeKy>.broadcast();
    List<Transaction>? txs;
    List<Category>? cats;
    List<BudgetView>? nganSach;

    void push() {
      if (txs == null || cats == null || nganSach == null) return;
      if (controller.isClosed) return;
      try {
        controller.add(_dung(
          ky: ky,
          fromTruoc: truoc.from,
          toTruoc: truoc.to,
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

  ThongKeKy _dung({
    required Ky ky,
    required DateTime fromTruoc,
    required DateTime toTruoc,
    required DateTime mocNganSach,
    required List<Transaction> txs,
    required List<Category> cats,
    required List<BudgetView> nganSach,
  }) {
    // `amount` lưu dương ở client (nhánh pull gọi `.abs()`), cộng thẳng —
    // cùng luật với `BudgetLocalDataSourceImpl.sumExpenses`.
    //
    // `cats` gồm CẢ hàng đã xoá mềm (xem chỗ đăng ký `subCat`), nên giao dịch
    // cũ trỏ vào danh mục đã xoá vẫn tra được `classify`. Thiếu bảng tra này
    // thì mọi khoản Trả nợ rơi về lát "chi" và vòng tròn nói sai tỷ trọng.
    final classifyTheoId = {for (final c in cats) c.id: c.classify};
    final khoan = [
      for (final t in txs)
        KhoanThuChi(
          ngay: t.date,
          soTien: t.amount,
          loai: t.type,
          categoryId: t.categoryId,
          classify:
              t.categoryId == null ? null : classifyTheoId[t.categoryId],
          // Cần cho phép loại khoản điều chỉnh số dư khỏi thống kê; thiếu
          // nó thì luật ấy không có gì để đọc và khoản bù thành thu nhập.
          ghiChu: t.note,
        ),
    ];

    final from = ky.from;
    final to = ky.to;

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
    // ⚠️ Ngân sách chỉ có nghĩa khi kỳ đang xem trùng khít một THÁNG dương
    // lịch. `BudgetView.spent` đếm theo kỳ của **chính ngân sách ấy**, không
    // theo kỳ đang xem — vẽ thanh ấy cạnh số liệu một tuần là đặt hai kỳ khác
    // nhau lên cùng một tỉ lệ, và nó sai **im lặng**: con số trông rất hợp lý.
    // Khi kỳ khác tháng, dòng danh mục tự rơi về nhãn "% tổng chi" (đường đã có
    // sẵn cho ca danh mục không có ngân sách).
    final gapNganSach = ky.donVi == DonViKy.thang;

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
          final ns = (gapNganSach && c.categoryId != null)
              ? nganSachTheoDanhMuc[c.categoryId]
              : null;
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

    // ── Ba lát và danh mục bên trong từng lát ───────────────────────────────
    // Dựng cho CẢ ba phân loại chứ không chỉ lát đang xem: lựa chọn nằm ở tầng
    // state, và stream này phát lại sau mọi chu kỳ đồng bộ — tính sẵn ở đây rẻ
    // hơn là bắt giao diện hỏi lại repository mỗi lần chạm.
    final lat = theoPhanLoai(khoan, from: from, to: to);
    final theoLat = <String, List<DongDanhMuc>>{};
    for (final l in lat) {
      final ds = danhMucTheoPhanLoai(
        khoan,
        from: from,
        to: to,
        phanLoai: l.phanLoai,
      );
      theoLat[l.phanLoai] = [
        for (final c in ds)
          () {
            final cat =
                c.categoryId == null ? null : danhMucTheoId[c.categoryId];
            final ten = c.categoryId == null
                ? 'Chưa phân loại'
                : (cat?.name ?? 'Danh mục đã xoá');
            // Ngân sách chỉ có nghĩa cho chi tiêu: `BudgetRepository` không có
            // khái niệm ngân sách thu. Gắn nó vào lát thu là hiện một hạn mức
            // không tồn tại.
            final ns =
                (gapNganSach && l.phanLoai == 'chi' && c.categoryId != null)
                    ? nganSachTheoDanhMuc[c.categoryId]
                    : null;
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
    }

    return ThongKeKy(
      ky: ky,
      tong: tong,
      tongTruoc: tongTruoc,
      chiTheoDanhMuc: chi,
      danhMuc: dong,
      // Dựng từ `khoan` — TOÀN BỘ giao dịch của tài khoản, chưa lọc kỳ. Chuỗi
      // nhìn xa sáu kỳ, xa hơn `tong`/`tongTruoc` nhiều.
      chuoi: chuoiTheoKy(khoan, ky: ky),
      latPhanLoai: lat,
      danhMucTheoLat: theoLat,
      // Cùng lý do với `chuoi`: dựng từ toàn bộ giao dịch, không phải từ kỳ
      // đang xem.
      chuoiDanhMuc: chuoiTheoDanhMuc(khoan, ky: ky),
    );
  }
}
