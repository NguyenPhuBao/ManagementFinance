import '../../../core/database/app_database.dart';
import '../domain/gop_vi.dart';
import '../domain/so_du_mo_so.dart';
import '../domain/vi_trung_ten.dart';

/// Chỗ đọc ví trùng tên (G63) — engine và giao diện cùng hỏi ở đây, để không
/// nơi nào đếm trên một tập khác (spec 2026-10-05 mục 4.4, bẫy 9). Luật ở
/// `wallet/domain/vi_trung_ten.dart`.
abstract class ViTrungTenNguon {
  /// Id các ví đang bị giữ (R) của [idaccount].
  Future<Set<String>> viDangBiGiu(int idaccount);

  /// Các cặp trùng của [idaccount], phát lại mỗi khi bảng ví đổi (cờ vừa đặt,
  /// ví vừa gộp / đổi tên) — thẻ ở Quản lý ví và dòng nhắc ở Trang chủ nghe.
  Stream<List<CapViHienThi>> theoDoi(int idaccount);
}

/// Một cặp trùng, đủ để thẻ ở màn Quản lý ví hiển thị (spec mục 5.1).
class CapViHienThi {
  const CapViHienThi({
    required this.idViMayNay,
    required this.idViDaDongBo,
    required this.ten,
    required this.soDuMayNay,
    required this.soDuDaDongBo,
    required this.soGiaoDich,
    this.lyDoKhongGop,
  });

  /// R — ví trên máy này, bị server từ chối.
  final String idViMayNay;

  /// P — ví cùng tên đã đồng bộ.
  final String idViDaDongBo;

  /// Tên của ví trên máy này (R).
  final String ten;
  final double soDuMayNay;
  final double soDuDaDongBo;

  /// Giao dịch sống dính tới R theo mọi vai, **trừ** khoản "Số dư ban đầu" —
  /// bằng *số giao dịch sẽ chuyển* cộng *số khoản chuyển giữa hai ví* của hộp
  /// Gộp.
  final int soGiaoDich;

  /// `lyDoKhongGop` của `gop_vi.dart` — MỘT luật cho thẻ và kế hoạch.
  final String? lyDoKhongGop;

  bool get coTheGop => lyDoKhongGop == null;
}

class ViTrungTenNguonImpl implements ViTrungTenNguon {
  ViTrungTenNguonImpl({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// Đọc `getAll` — MỌI ví chưa xoá, **kể cả lưu trữ**: index trùng tên của
  /// server không nhìn `Status`.
  @override
  Future<Set<String>> viDangBiGiu(int idaccount) async =>
      idViBiGiu(xetTuHang(await _db.walletDao.getAll(idaccount)));

  /// Nghe `watchAll` — cũng MỌI ví chưa xoá, kể cả lưu trữ (cùng tập với
  /// [viDangBiGiu]).
  @override
  Stream<List<CapViHienThi>> theoDoi(int idaccount) =>
      _db.walletDao.watchAll(idaccount).asyncMap(_hienThi);

  Future<List<CapViHienThi>> _hienThi(List<Wallet> vi) async {
    final theoId = {for (final w in vi) w.id: w};
    final ra = <CapViHienThi>[];
    for (final c in capViTrungTen(xetTuHang(vi))) {
      final r = theoId[c.idViMayNay]!;
      final p = theoId[c.idViDaDongBo]!;
      // Khoản mở sổ tìm bằng ID tất định (bẫy 5) — ghi chú sửa được.
      final neo = await _db.transactionDao.getById(idKhoanMoSo(r.id));
      final coNeo = neo != null && neo.deletedAt == null;
      ra.add(CapViHienThi(
        idViMayNay: r.id,
        idViDaDongBo: p.id,
        ten: r.name,
        soDuMayNay: r.balance,
        soDuDaDongBo: p.balance,
        soGiaoDich:
            await _db.transactionDao.demGiaoDichLienQuan(r.id) - (coNeo ? 1 : 0),
        lyDoKhongGop: lyDoKhongGop(loaiViBo: r.type, loaiViGiu: p.type),
      ));
    }
    return ra;
  }

  /// Hàng Drift → phần phép tìm cặp cần.
  static List<ViXetTrung> xetTuHang(Iterable<Wallet> vi) => [
        for (final w in vi)
          ViXetTrung(
            id: w.id,
            ten: w.name,
            biTuChoi: w.biTuChoiTrungTen,
            daXoa: w.deletedAt != null,
          ),
      ];
}
