/// G63 — ví trùng tên giữa hai máy cùng tài khoản: **định nghĩa duy nhất** của
/// "cặp trùng" và "bản ghi bị giữ".
///
/// Spec `docs/superpowers/specs/2026-10-05-g63-vi-trung-ten-hai-may-design.md`
/// mục 4.2 và 4.4. Mọi nơi cần biết ví nào đang bị giữ — engine, thẻ ở Quản lý
/// ví, nhãn trên dòng ví, dòng nhắc ở Trang chủ, dịch vụ gộp — đều gọi tệp này;
/// viết lại vế so tên ở một chỗ là bốn nơi đếm trên bốn tập (spec mục 8, bẫy 9).
library;

import '../data/models/wallet_entity.dart';
import 'rang_buoc_vi.dart';

/// Phần của một ví mà phép tìm cặp cần — chạy được trên cả hàng Drift (engine,
/// qua `ViTrungTenNguon`) lẫn `WalletEntity` (màn Quản lý ví).
class ViXetTrung {
  const ViXetTrung({
    required this.id,
    required this.ten,
    required this.biTuChoi,
    this.daXoa = false,
  });

  factory ViXetTrung.tuEntity(WalletEntity w) => ViXetTrung(
        id: w.id,
        ten: w.name,
        biTuChoi: w.biTuChoiTrungTen,
        daXoa: w.isDeleted,
      );

  final String id;
  final String ten;
  final bool biTuChoi;
  final bool daXoa;
}

/// Một cặp trùng: [idViMayNay] (R — bị server từ chối, đang bị giữ) và
/// [idViDaDongBo] (P — ví cùng tên đã có trên server và đã kéo về máy).
class CapViTrungTen {
  const CapViTrungTen({required this.idViMayNay, required this.idViDaDongBo});

  final String idViMayNay;
  final String idViDaDongBo;

  @override
  bool operator ==(Object other) =>
      other is CapViTrungTen &&
      other.idViMayNay == idViMayNay &&
      other.idViDaDongBo == idViDaDongBo;

  @override
  int get hashCode => Object.hash(idViMayNay, idViDaDongBo);

  @override
  String toString() => 'CapViTrungTen($idViMayNay → $idViDaDongBo)';
}

/// Mọi cặp trùng trong [vi]. Ví R **đang bị giữ** khi và chỉ khi đủ ba điều: R
/// còn sống; R mang cờ bị từ chối; có ví sống **khác**, **không** mang cờ, cùng
/// `chuanHoaTenVi(tên)` — ví ấy là P.
///
/// ⚠️ Cờ một mình **không đủ** (bẫy 2): máy kia đổi tên / xoá ví của nó thì R
/// phải quay lại hàng đợi. Cặp tên một mình cũng **không đủ**: hai ví cùng tên
/// chưa ai bị từ chối thì chưa có gì để giữ.
///
/// Ví lưu trữ vẫn tính: index `uq_wallet_account_name_active` của server chỉ lọc
/// `Delete_at`, không nhìn `Status`. Nhiều ứng viên P: trùng **nguyên văn** tên
/// trước, rồi id nhỏ hơn — chỉ để kết quả tất định.
List<CapViTrungTen> capViTrungTen(Iterable<ViXetTrung> vi) {
  final song = [for (final v in vi) if (!v.daXoa) v];
  final ra = <CapViTrungTen>[];
  for (final r in song) {
    if (!r.biTuChoi) continue;
    final khoa = chuanHoaTenVi(r.ten);
    final ungVien = [
      for (final p in song)
        if (p.id != r.id && !p.biTuChoi && chuanHoaTenVi(p.ten) == khoa) p,
    ]..sort((a, b) {
        final theoTen =
            (a.ten == r.ten ? 0 : 1).compareTo(b.ten == r.ten ? 0 : 1);
        return theoTen != 0 ? theoTen : a.id.compareTo(b.id);
      });
    if (ungVien.isEmpty) continue;
    ra.add(CapViTrungTen(idViMayNay: r.id, idViDaDongBo: ungVien.first.id));
  }
  return ra;
}

/// Id các ví đang bị giữ (R) — lối tắt của [capViTrungTen].
Set<String> idViBiGiu(Iterable<ViXetTrung> vi) =>
    {for (final c in capViTrungTen(vi)) c.idViMayNay};

typedef HoaDonChoXet = ({String id, String? walletId, String? truocDo});
typedef MucTieuChoXet = ({String id, String? walletId, String? viNguonTrich});
typedef GiaoDichChoXet = ({
  String id,
  String walletId,
  String? viNhan,
  String? billId,
  String? goalId,
});

/// Id các bản ghi `_collectPendingOps` phải bỏ khỏi lô đẩy — bảng 4.4 của spec.
class BanGhiBiGiu {
  const BanGhiBiGiu({
    required this.vi,
    required this.hoaDon,
    required this.mucTieu,
    required this.giaoDich,
  });

  static const BanGhiBiGiu rong = BanGhiBiGiu(
    vi: <String>{},
    hoaDon: <String>{},
    mucTieu: <String>{},
    giaoDich: <String>{},
  );

  final Set<String> vi;
  final Set<String> hoaDon;
  final Set<String> mucTieu;
  final Set<String> giaoDich;
}

/// Bản ghi đang chờ đẩy mà phải **giữ lại** vì dính tới một ví bị giữ — theo
/// đúng khoá ngoại phía server: `fk_bill_wallet` + `fk_bill_previous_bill` (hoá
/// đơn, lặp theo chuỗi kỳ), `fk_goal_wallet` + ví nguồn trích (mục tiêu — cột ấy
/// không có khoá ngoại nhưng không đẩy lên một mã ví server chưa có),
/// `fk_transaction_wallet` + `fk_transaction_wallet_transfer` +
/// `fk_transaction_bill` + `fk_transaction_goal` (giao dịch).
///
/// Bị giữ thì bỏ qua **mọi** loại thao tác, kể cả lệnh xoá. Đầu vào là các hàng
/// **đang chờ đẩy**: hàng đã đồng bộ thì đã có trên server, không vỡ khoá ngoại.
BanGhiBiGiu banGhiBiGiu({
  required Set<String> viBiGiu,
  required Iterable<HoaDonChoXet> hoaDon,
  required Iterable<MucTieuChoXet> mucTieu,
  required Iterable<GiaoDichChoXet> giaoDich,
}) {
  if (viBiGiu.isEmpty) return BanGhiBiGiu.rong;

  final dsHoaDon = hoaDon.toList();
  final hd = <String>{
    for (final b in dsHoaDon)
      if (viBiGiu.contains(b.walletId)) b.id,
  };
  var them = true;
  while (them) {
    them = false;
    for (final b in dsHoaDon) {
      if (!hd.contains(b.id) && b.truocDo != null && hd.contains(b.truocDo)) {
        hd.add(b.id);
        them = true;
      }
    }
  }

  final mt = <String>{
    for (final g in mucTieu)
      if (viBiGiu.contains(g.walletId) || viBiGiu.contains(g.viNguonTrich)) g.id,
  };

  final gd = <String>{
    for (final t in giaoDich)
      if (viBiGiu.contains(t.walletId) ||
          viBiGiu.contains(t.viNhan) ||
          hd.contains(t.billId) ||
          mt.contains(t.goalId))
        t.id,
  };

  return BanGhiBiGiu(vi: viBiGiu, hoaDon: hd, mucTieu: mt, giaoDich: gd);
}
