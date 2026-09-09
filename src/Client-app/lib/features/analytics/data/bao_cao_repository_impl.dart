import '../../../core/database/app_database.dart';
import '../domain/bao_cao_xuat.dart';
import 'bao_cao_repository.dart';

/// Đọc giao dịch, ví và danh mục của một tài khoản rồi giao cho [dungBaoCao].
///
/// Repository **không** cộng gì cả — mọi phép lọc và phép cộng nằm ở tầng
/// thuần, chỗ kiểm được bằng danh sách. Việc ở đây chỉ là tra tên.
class BaoCaoRepositoryImpl implements BaoCaoRepository {
  final AppDatabase db;

  BaoCaoRepositoryImpl({required this.db});

  @override
  Future<BaoCao> layBaoCao(int idaccount, {required LocBaoCao loc}) async {
    // `getAll` đã lọc `deletedAt` — giao dịch đã xoá mềm không thuộc báo cáo.
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
          );
        }(),
    ];

    return dungBaoCao(ds, loc: loc);
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
