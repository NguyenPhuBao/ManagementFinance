import '../../../core/database/app_database.dart';
import '../../../core/sync/cong_vi_bi_giu.dart';
import 'tha_vi_bi_giu.dart';
import 'vi_trung_ten_nguon.dart';

/// Bản thi hành [CongViBiGiu] (G88 gạch 4 — `SyncEngine` thôi import mảng ví): bọc ĐÚNG ba thứ engine từng gọi thẳng —
/// `ViTrungTenNguon.viCanTha` + `ThaViBiGiu.tha` (thả), `viDangBiGiu` + `ViTrungTenNguonImpl.banGhiBiGiuTuHang` (giữ khỏi
/// lô). Không đổi phép tính; luật ở `wallet/domain/vi_trung_ten.dart`. Tự dựng `ViTrungTenNguonImpl` như engine từng làm —
/// lớp ấy không giữ trạng thái.
class ViBiGiuDongBo implements CongViBiGiu {
  ViBiGiuDongBo({required AppDatabase db})
      : _db = db,
        _viTrungTen = ViTrungTenNguonImpl(db: db);

  final AppDatabase _db;
  final ViTrungTenNguon _viTrungTen;

  @override
  Future<void> thaViKhongConCap(int idaccount) async {
    for (final id in await _viTrungTen.viCanTha(idaccount)) {
      await ThaViBiGiu(db: _db).tha(id);
    }
  }

  @override
  Future<BanGhiGiuKhoiDay> banGhiGiuKhoiDay(
    int idaccount, {
    required Iterable<Bill> hoaDon,
    required Iterable<Goal> mucTieu,
    required Iterable<Transaction> giaoDich,
  }) async {
    final giu = ViTrungTenNguonImpl.banGhiBiGiuTuHang(
      viBiGiu: await _viTrungTen.viDangBiGiu(idaccount),
      hoaDon: hoaDon,
      mucTieu: mucTieu,
      giaoDich: giaoDich,
    );
    return (
      vi: giu.vi,
      hoaDon: giu.hoaDon,
      mucTieu: giu.mucTieu,
      giaoDich: giu.giaoDich
    );
  }
}
