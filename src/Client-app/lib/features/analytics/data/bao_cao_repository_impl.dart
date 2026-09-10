import '../../../core/database/app_database.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../domain/bao_cao_xuat.dart';
import '../../wallet/domain/vi_tinh_vao_tong.dart';
import 'bao_cao_repository.dart';

/// Đọc giao dịch, ví và danh mục của một tài khoản rồi giao cho [dungBaoCao].
///
/// Repository **không** cộng gì cả — mọi phép lọc và phép cộng nằm ở tầng
/// thuần, chỗ kiểm được bằng danh sách. Việc ở đây chỉ là tra tên.
class BaoCaoRepositoryImpl implements BaoCaoRepository {
  final AppDatabase db;
  final BudgetRepository budgetRepository;

  /// Tiêm đồng hồ để test không phụ thuộc ngày chạy máy.
  final DateTime Function() clock;

  BaoCaoRepositoryImpl({
    required this.db,
    required this.budgetRepository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  @override
  Future<BaoCao> layBaoCao(int idaccount, {required LocBaoCao loc}) async {
    // `getAll` đã lọc `deletedAt` — giao dịch đã xoá mềm không thuộc báo cáo.
    // Lấy **toàn bộ** giao dịch chứ không lọc theo kỳ: kỳ trước và dòng tiền
    // nhìn ra ngoài khoảng đang xem, `dungBaoCao` tự cắt.
    final txs = await db.transactionDao.getAll(idaccount);

    // Ví và danh mục thì lấy **kể cả hàng đã xoá mềm**: giao dịch cũ vẫn trỏ
    // vào chúng và tên thật vẫn nằm trong hàng. Cùng luật với trang Phân tích;
    // lọc `deletedAt` ở đây là mọi khoản cũ mất tên sau một lần dọn danh mục.
    final vi = await (db.select(db.wallets)
          ..where((t) => t.idaccount.equals(idaccount)))
        .get();
    final cats = await (db.select(db.categories)
          ..where((t) => t.idaccount.equals(idaccount)))
        .get();

    final viTheoId = {for (final v in vi) v.id: v};
    final catTheoId = {for (final c in cats) c.id: c};

    final ds = [
      for (final t in txs)
        () {
          final cat = t.categoryId == null ? null : catTheoId[t.categoryId];
          // Ba ca, ba chữ — cùng bộ nhãn với trang Phân tích.
          final tenDanhMuc = t.categoryId == null
              ? 'Chưa phân loại'
              : (cat?.name ?? 'Danh mục đã xoá');
          return DongGiaoDich(
            id: t.id,
            ngay: t.date,
            // `amount` lưu dương ở client (nhánh pull gọi `.abs()`); chiều tiền
            // nằm ở `type`, không ở dấu.
            soTien: t.amount,
            loai: t.type,
            categoryId: t.categoryId,
            tenDanhMuc: tenDanhMuc,
            mauHex: cat?.colour,
            icon: cat?.icon,
            walletId: t.walletId,
            tenVi: viTheoId[t.walletId]?.name ?? 'Ví đã xoá',
            // Ghi chú rỗng là **mặc định của cột**, không phải "người dùng để
            // trống có chủ ý" — dòng báo cáo khi ấy lấy tên danh mục.
            tieuDe: t.note.trim().isEmpty ? tenDanhMuc : t.note,
            // Ghi chú THÔ, tách khỏi `tieuDe`: phép nhận dạng khoản điều
            // chỉnh số dư đọc đúng chuỗi này, còn `tieuDe` rơi về tên danh
            // mục khi ghi chú rỗng nên nó không nói lên được hàng có ghi chú
            // hay không. Thiếu dòng này thì luật loại trừ KHÔNG CÓ GÌ để đọc.
            ghiChu: t.note,
          );
        }(),
    ];

    // Tổng số dư ví — **cùng một luật** với trang chủ và màn Quản lý ví, để
    // con số "số dư cuối kỳ" khớp với số tiền người dùng nhìn thấy ở nơi
    // khác. Luật ấy có đúng một định nghĩa (`viTinhVaoTong`): bản chép tay
    // trước ở đây cộng `fold` trần trên mọi ví, nên nó thừa cả ví người dùng
    // đã tắt "Tính vào tổng tài sản" lẫn ví đã lưu trữ.
    final viSong = await db.walletDao.getAll(idaccount);
    final soDu = viSong
        .where((v) =>
            viTinhVaoTong(includeInTotal: v.includeInTotal, status: v.status))
        .fold<double>(0, (s, v) => s + v.balance);

    return dungBaoCao(
      ds,
      loc: loc,
      soDuHienTai: soDu,
      nganSach: await _nganSach(idaccount, loc: loc, catTheoId: catTheoId),
    );
  }

  /// Ngân sách **đang chạy** của kỳ, theo danh mục.
  ///
  /// Mốc tra lấy cùng quy tắc với trang Phân tích (mục 3.3): kỳ đang chứa hôm
  /// nay thì lấy "bây giờ" để số đã chi khớp trang Ngân sách; kỳ đã qua thì lấy
  /// giây cuối của kỳ, để ngân sách còn sống tới cuối kỳ vẫn được tính.
  ///
  /// `watchBudgets` trả **cả** ngân sách đã hết hạn (trang Ngân sách tự chia
  /// tab), nên phải lọc `isExpired` ở đây — bỏ dòng ấy là một ngân sách chết từ
  /// tháng 6 vẫn hiện trên báo cáo tháng 9.
  Future<List<DongNganSach>> _nganSach(
    int idaccount, {
    required LocBaoCao loc,
    required Map<String, Category> catTheoId,
  }) async {
    final at = clock();
    final trongKy = !at.isBefore(loc.from) && at.isBefore(loc.to);
    final moc = trongKy ? at : loc.to.subtract(const Duration(seconds: 1));

    final ds = await budgetRepository.watchBudgets(idaccount, now: moc).first;
    final ra = <DongNganSach>[];
    for (final v in ds) {
      final BudgetEntity b = v.budget;
      final id = b.categoryId;
      // Ngân sách tổng (`categoryId == null`) không thuộc dòng nào.
      if (id == null || b.isExpired(moc)) continue;
      // Danh mục đã lọc riêng thì chỉ giữ ngân sách của chính nó.
      if (loc.categoryId != null && id != loc.categoryId) continue;
      ra.add(DongNganSach(
        categoryId: id,
        ten: catTheoId[id]?.name ?? 'Danh mục đã xoá',
        hanMuc: b.amount,
        daChi: b.spent,
      ));
    }
    ra.sort((a, b) => b.tiLe.compareTo(a.tiLe));
    return ra;
  }

  @override
  Stream<List<LuaChonLoc>> watchVi(int idaccount) => db.walletDao
      .watchAll(idaccount)
      .map((ds) => [for (final v in ds) LuaChonLoc(id: v.id, ten: v.name)]);

  @override
  Stream<List<LuaChonLoc>> watchDanhMuc(int idaccount) => db.categoryDao
      .watchAll(idaccount)
      .map((ds) => [for (final c in ds) LuaChonLoc(id: c.id, ten: c.name)]);
}
