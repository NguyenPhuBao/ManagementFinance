import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../wallet/domain/vi_tinh_vao_tong.dart';
import '../../goal/data/models/goal_entity.dart';
import '../domain/bao_cao_xuat.dart';
import '../domain/du_bao_dong_tien.dart';
import '../domain/khoan_vao_thong_ke.dart';
import '../domain/lich_chi_tieu.dart';
import '../domain/pham_vi_ky.dart';
import '../domain/vai_vay_no.dart';
import '../domain/phan_loai_dong_tien.dart';
import '../domain/thong_ke_thang.dart';
import 'analytics_repository.dart';

/// Gộp **bảy** nguồn thành một [ThongKeKy] — giao dịch, danh mục, ngân sách
/// (mốc kỳ đang xem), ví, hoá đơn, mục tiêu, và ngân sách (mốc hôm nay).
///
/// Ví là nguồn thứ tư, thêm 2026-09-15 (P2): ba trong bốn khối mượn từ trang
/// Xuất báo cáo cần nó — "phân bổ theo ví" cần **tên** ví, "dòng tiền" cần
/// **tổng số dư** hiện tại.
///
/// Ba nguồn cuối thêm 2026-09-16 cho khối **Dự báo 30 ngày tới**. Nguồn thứ
/// bảy là ngân sách tra tại `now` — ⚠️ **không dùng chung** nguồn thứ ba, xem
/// chú thích trong [watchKy].
///
/// Cùng khuôn với `BudgetRepositoryImpl.watchBudgets`: một controller, mỗi
/// nguồn một subscription, phát khi **cả bảy** đã có dữ liệu. Không dùng thư
/// viện rx; dự án không có và bảy stream không đáng kéo thêm một phụ thuộc.
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
    List<Wallet>? vi;
    List<Bill>? hoaDon;
    List<Goal>? mucTieu;
    // Nguồn ngân sách THỨ HAI, tra tại `at` chứ không tại `mocNganSach`. Mốc
    // kia **lùi về giây cuối kỳ** khi người dùng xem kỳ đã qua, nên `spent` sẽ
    // là của kỳ ngân sách chứa cuối tháng 6 khi họ xem tháng 6. Dùng chung thì
    // dự báo đúng khi xem tháng này và SAI khi xem tháng khác — không lỗi nào
    // báo (bẫy 1 spec dự báo).
    List<BudgetView>? nganSachHomNay;

    void push() {
      if (txs == null ||
          cats == null ||
          nganSach == null ||
          vi == null ||
          hoaDon == null ||
          mucTieu == null ||
          nganSachHomNay == null) {
        return;
      }
      if (controller.isClosed) return;
      try {
        controller.add(_dung(
          ky: ky,
          now: at,
          fromTruoc: truoc.from,
          toTruoc: truoc.to,
          mocNganSach: mocNganSach,
          txs: txs!,
          cats: cats!,
          nganSach: nganSach!,
          vi: vi!,
          hoaDon: hoaDon!,
          mucTieu: mucTieu!,
          nganSachHomNay: nganSachHomNay!,
        ));
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    final subTx = db.transactionDao.watchAll(idaccount).listen((rows) {
      txs = rows;
      push();
    }, onError: controller.addError);
    // Bảng **tra tên** — giữ hàng đã xoá mềm VÀ gồm cả hàng mặc định toàn cục
    // (`idaccount = 0`). Hai luật ấy nay có một định nghĩa duy nhất ở
    // `categoryDao.watchBangTraTen`; đọc docstring của nó trước khi đổi.
    final subCat = db.categoryDao.watchBangTraTen(idaccount).listen((rows) {
      cats = rows;
      push();
    }, onError: controller.addError);
    final subNs = budgetRepository
        .watchBudgets(idaccount, now: mocNganSach)
        .listen((rows) {
      nganSach = rows;
      push();
    }, onError: controller.addError);

    // Ví lấy **kể cả hàng đã xoá mềm**, cùng luật với danh mục: giao dịch cũ
    // vẫn trỏ vào ví đã xoá và tên thật vẫn nằm trong hàng. Lọc `deletedAt` ở
    // đây là mọi khoản cũ mất tên ví sau một lần dọn.
    final subVi = (db.select(db.wallets)
          ..where((t) => t.idaccount.equals(idaccount)))
        .watch()
        .listen((rows) {
      vi = rows;
      push();
    }, onError: controller.addError);

    // Ba nguồn của khối Dự báo 30 ngày (2026-09-16).
    final subHoaDon = db.billDao.watchAll(idaccount).listen((rows) {
      hoaDon = rows;
      push();
    }, onError: controller.addError);
    final subMucTieu = db.goalDao.watchAll(idaccount).listen((rows) {
      mucTieu = rows;
      push();
    }, onError: controller.addError);
    final subNsHomNay =
        budgetRepository.watchBudgets(idaccount, now: at).listen((rows) {
      nganSachHomNay = rows;
      push();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subVi.cancel();
      await subTx.cancel();
      await subCat.cancel();
      await subNs.cancel();
      await subHoaDon.cancel();
      await subMucTieu.cancel();
      await subNsHomNay.cancel();
    };
    return controller.stream;
  }

  ThongKeKy _dung({
    required Ky ky,
    required DateTime now,
    required DateTime fromTruoc,
    required DateTime toTruoc,
    required DateTime mocNganSach,
    required List<Transaction> txs,
    required List<Category> cats,
    required List<BudgetView> nganSach,
    required List<Wallet> vi,
    required List<Bill> hoaDon,
    required List<Goal> mucTieu,
    required List<BudgetView> nganSachHomNay,
  }) {
    // `amount` lưu dương ở client (nhánh pull gọi `.abs()`), cộng thẳng —
    // cùng luật với `BudgetLocalDataSourceImpl.sumExpenses`.
    //
    // `cats` gồm CẢ hàng đã xoá mềm (xem chỗ đăng ký `subCat`), nên giao dịch
    // cũ trỏ vào danh mục đã xoá vẫn tra được `classify`. Thiếu bảng tra này
    // thì mọi khoản Trả nợ rơi về lát "chi" và vòng tròn nói sai tỷ trọng.
    final classifyTheoId = {for (final c in cats) c.id: c.classify};
    // Bảng tra TÊN, dựng cạnh bảng tra `classify` vì `khoan` cần cả hai và nó
    // được dựng trước `danhMucTheoId` ở dưới.
    final tenTheoId = {for (final c in cats) c.id: c.name};
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
          // TÊN danh mục — hai biểu đồ vay/nợ đọc vai từ đây, vì bốn vai
          // *cho vay · thu nợ · đi vay · trả nợ* không có chỗ nào lưu.
          tenDanhMuc:
              t.categoryId == null ? null : tenTheoId[t.categoryId],
        ),
    ];

    final from = ky.from;
    final to = ky.to;

    final tong = tongThuChi(khoan, from: from, to: to);
    final tongTruoc = tongThuChi(khoan, from: fromTruoc, to: toTruoc);
    // Mốc so sánh thứ hai (#2 khảo sát, 2026-09-16). **Không** cần nguồn stream
    // thứ tám: `khoan` là TOÀN BỘ giao dịch của tài khoản (xem chỗ đăng ký
    // `subTx`), nên kỳ năm trước chỉ là một lời gọi nữa trên đúng danh sách ấy.
    final nt = cungKyNamTruoc(ky);
    final tongNamTruoc = tongThuChi(khoan, from: nt.from, to: nt.to);
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

    // ── Bốn khối mượn từ trang Xuất báo cáo ────────────────────────────────
    // Dựng `DongGiaoDich` (đã tra sẵn tên ví và tên danh mục) rồi giao cho bốn
    // hàm thuần của `bao_cao_xuat.dart` — **không** gọi `dungBaoCao`: nó tính
    // thêm cả chuỗi biểu đồ, bảng danh mục và phép gom theo ngày mà trang này
    // đã có hoặc không cần, và stream này phát lại sau MỌI chu kỳ đồng bộ.
    final viTheoId = {for (final v in vi) v.id: v};
    final dongGd = [
      for (final t in txs)
        () {
          final cat = t.categoryId == null ? null : danhMucTheoId[t.categoryId];
          final tenDanhMuc = t.categoryId == null
              ? 'Chưa phân loại'
              : (cat?.name ?? 'Danh mục đã xoá');
          return DongGiaoDich(
            id: t.id,
            ngay: t.date,
            soTien: t.amount,
            loai: t.type,
            categoryId: t.categoryId,
            tenDanhMuc: tenDanhMuc,
            mauHex: cat?.colour,
            icon: cat?.icon,
            walletId: t.walletId,
            tenVi: viTheoId[t.walletId]?.name ?? 'Ví đã xoá',
            tieuDe: t.note.trim().isEmpty ? tenDanhMuc : t.note,
            // Ghi chú THÔ, tách khỏi `tieuDe`: luật loại khoản điều chỉnh số dư
            // đọc đúng chuỗi này. Thiếu nó thì luật ấy không có gì để đọc.
            ghiChu: t.note,
          );
        }(),
    ];
    final trongKy = [
      for (final d in dongGd)
        if (khoanVaoThongKe(
              loai: d.loai,
              categoryId: d.categoryId,
              ghiChu: d.ghiChu,
            ) &&
            !d.ngay.isBefore(from) &&
            d.ngay.isBefore(to))
          d,
    ];

    // Tổng số dư — **cùng một luật** với trang chủ, màn Quản lý ví và trang Báo
    // cáo (`viTinhVaoTong`), để "số dư cuối kỳ" khớp con số người dùng thấy ở
    // nơi khác. `fold` trần trên mọi ví là bản chép tay đã sai ba lần.
    //
    // ⚠️ `isDeleted` BẮT BUỘC ở đây và chỉ ở đây: `vi` đến từ một truy vấn
    // thẳng **không lọc `deletedAt`** (cố ý — bảng tra tên cần hàng đã xoá),
    // khác mọi chỗ gọi khác vốn đọc qua `walletDao`. Thiếu nó thì số dư ví
    // người dùng đã xoá vẫn phình "số dư cuối kỳ" — G42, đo được 7.000.000.
    final soDu = vi
        .where((v) => viTinhVaoTong(
              includeInTotal: v.includeInTotal,
              status: v.status,
              isDeleted: v.isDeleted,
            ))
        .fold<double>(0, (s, v) => s + v.balance);

    // Dự báo LUÔN tính từ `now`, không theo kỳ đang xem — và ngân sách của nó
    // là nguồn tra tại `now`, không phải `nganSach` của `mocNganSach`. `vi`
    // truyền NGUYÊN (kể cả hàng đã xoá mềm) để tra được tên ví của giao dịch
    // cũ; hàm tự lọc khi cộng số dư và khi cảnh báo ví thiếu.
    final duBao = duBaoCua(
      now: now,
      hoaDon: hoaDon,
      mucTieu: [for (final g in mucTieu) GoalEntity.fromDrift(g)],
      nganSach: nganSachHomNay,
      vi: vi,
    );

    return ThongKeKy(
      ky: ky,
      duBao: duBao,
      soLieu: soLieuNhanhCua(trongKy, from: from, to: to),
      theoVi: phanBoTheoVi(trongKy),
      topChi: topKhoanChi(trongKy),
      // Cùng danh sách `trongKy` với ba khối trên — không nguồn stream mới.
      lichChiTieu: lichChiTieuCua(trongKy),
      // `dongGd` chứ không phải `trongKy`: phép suy ngược cần biết phần phát sinh
      // SAU kỳ. Đưa danh sách đã cắt vào là hai con số bằng nhau, im lặng.
      dongTien: dongTienCua(dongGd, from: from, to: to, soDuHienTai: soDu),
      tong: tong,
      tongTruoc: tongTruoc,
      tongNamTruoc: tongNamTruoc,
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
      // Cùng lý do: dựng từ toàn bộ giao dịch, không phải từ kỳ đang xem.
      chuoiVayNo: chuoiVayNo(khoan, ky: ky),
    );
  }
}
