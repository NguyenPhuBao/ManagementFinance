/// G63 — **kế hoạch gộp** hai ví trùng tên: MỘT nguồn cho hộp xác nhận lẫn
/// bước thi hành (spec 2026-10-05 mục 6.1).
///
/// Hộp xác nhận in [cacDongXacNhanGop]; `GopViService.gop` làm theo đúng
/// [KeHoachGop]. Không chỗ nào tự đếm lại — hai phép đếm là hai con số có thể
/// lệch (bẫy 4).
library;

import '../../../core/utils/currency_formatter.dart';
import 'so_du_mo_so.dart';
import 'wallet_type.dart';

/// Phần của một ví mà kế hoạch cần.
class ViChoGop {
  const ViChoGop({
    required this.id,
    required this.loai,
    required this.soDu,
    required this.tongSo,
    this.macDinh = false,
    this.luuTru = false,
  });

  final String id;

  /// Khoá `WalletType`.
  final String loai;

  /// Cột `balance` — cache của sổ.
  final double soDu;

  /// `TransactionDao.tongTheoVi` — tổng sổ còn sống.
  final double tongSo;

  final bool macDinh;
  final bool luuTru;
}

typedef GiaoDichChoGop = ({
  String id,
  String walletId,
  String? viNhan,
  String loai,
  double soTien,
});
typedef HoaDonChoGop = ({String id});
typedef MucTieuChoGop = ({
  String id,
  String ten,
  String? walletId,
  String? viNguonTrich,
});

/// Việc làm với một mục tiêu dính tới ví bị bỏ.
class DoiViMucTieu {
  const DoiViMucTieu({
    required this.id,
    required this.ten,
    required this.doiViNhan,
    required this.doiViNguon,
    required this.tatTrich,
  });

  final String id;
  final String ten;
  final bool doiViNhan;
  final bool doiViNguon;

  /// Sau gộp ví nguồn trích trùng ví nhận → tắt trích (ba cột `auto_deposit_*`
  /// về `NULL` cùng nhau).
  final bool tatTrich;
}

/// Kế hoạch gộp ví [idViBo] (R — trên máy này) vào [idViGiu] (P — đã đồng bộ).
class KeHoachGop {
  const KeHoachGop({
    required this.idViBo,
    required this.idViGiu,
    required this.loaiViGiu,
    required this.viGiuLuuTru,
    required this.giaoDichDoiVi,
    required this.idKhoanMoSoBo,
    required this.soDuBanDauBo,
    required this.khoanChuyenNoiBo,
    required this.hoaDonDoiVi,
    required this.mucTieu,
    required this.soDuSauGop,
    required this.chuyenCoMacDinh,
    required this.lyDoKhongGop,
  });

  final String idViBo;
  final String idViGiu;
  final String loaiViGiu;
  final bool viGiuLuuTru;

  /// Giao dịch sống dính tới R (nguồn hoặc nhận) sẽ trỏ sang P — trừ khoản mở
  /// sổ và khoản chuyển nội bộ.
  final List<String> giaoDichDoiVi;

  /// Khoản "Số dư ban đầu" còn sống của R — bị xoá mềm, không chuyển. `null`
  /// nếu R không có.
  final String? idKhoanMoSoBo;

  /// `số dư R − (tổng sổ R − khoản mở sổ R)` — gồm cả phần số dư R chưa từng
  /// vào sổ.
  final double soDuBanDauBo;

  /// Khoản chuyển giữa R và P (hai chiều) — xoá mềm: sau gộp chúng là chuyển từ
  /// ví sang chính nó.
  final List<String> khoanChuyenNoiBo;

  final List<String> hoaDonDoiVi;
  final List<DoiViMucTieu> mucTieu;

  /// `tổng sổ P + tổng sổ R − khoản mở sổ R` — đúng con số
  /// `SoDuViService.tinhLaiSoDu(P)` cho ra sau gộp.
  final double soDuSauGop;

  /// R mang cờ mặc định và P không lưu trữ → P nhận cờ.
  final bool chuyenCoMacDinh;

  final String? lyDoKhongGop;

  bool get coTheGop => lyDoKhongGop == null;

  List<String> get tenMucTieuTatTrich =>
      [for (final m in mucTieu) if (m.tatTrich) m.ten];

  /// Cùng tập bản ghi với [khac] — `GopViService.gop` lập lại kế hoạch trong
  /// giao tác và từ chối nếu khác (một khoản ghi vào R giữa lúc mở hộp và lúc
  /// bấm Gộp sẽ trỏ tới một ví đã xoá).
  bool cungTapVoi(KeHoachGop khac) =>
      idViBo == khac.idViBo &&
      idViGiu == khac.idViGiu &&
      idKhoanMoSoBo == khac.idKhoanMoSoBo &&
      _cungTap(giaoDichDoiVi, khac.giaoDichDoiVi) &&
      _cungTap(khoanChuyenNoiBo, khac.khoanChuyenNoiBo) &&
      _cungTap(hoaDonDoiVi, khac.hoaDonDoiVi) &&
      _cungTap(
        [for (final m in mucTieu) m.id],
        [for (final m in khac.mucTieu) m.id],
      );
}

bool _cungTap(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

/// `null` khi gộp được. Ví liên kết ngân hàng không gộp được ở **cả hai phía**:
/// `SoDuViService` không tính lại số dư loại ấy từ sổ, nên dời sổ sang hay khỏi
/// nó đều làm mất con số ngân hàng báo về (spec 6.4).
String? lyDoKhongGop({required String loaiViBo, required String loaiViGiu}) {
  if (WalletType.tuKhoa(loaiViGiu) == WalletType.banking) {
    return 'Ví kia là ví liên kết ngân hàng nên không gộp được.';
  }
  if (WalletType.tuKhoa(loaiViBo) == WalletType.banking) {
    return 'Ví này là ví liên kết ngân hàng nên không gộp được.';
  }
  return null;
}

KeHoachGop keHoachGop({
  required ViChoGop viBo,
  required ViChoGop viGiu,
  required List<GiaoDichChoGop> giaoDich,
  required List<HoaDonChoGop> hoaDon,
  required List<MucTieuChoGop> mucTieu,
}) {
  // Khoản mở sổ tìm bằng ID TẤT ĐỊNH — ghi chú sửa được (bẫy 5).
  final idNeo = idKhoanMoSo(viBo.id);
  String? idNeoSong;
  var neo = 0.0;
  final doiVi = <String>[];
  final noiBo = <String>[];
  for (final t in giaoDich) {
    if (t.id == idNeo) {
      idNeoSong = t.id;
      neo = t.loai == 'thu' ? t.soTien : -t.soTien;
      continue;
    }
    final laNoiBo = t.loai == 'transfer' &&
        ((t.walletId == viBo.id && t.viNhan == viGiu.id) ||
            (t.walletId == viGiu.id && t.viNhan == viBo.id));
    (laNoiBo ? noiBo : doiVi).add(t.id);
  }

  return KeHoachGop(
    idViBo: viBo.id,
    idViGiu: viGiu.id,
    loaiViGiu: viGiu.loai,
    viGiuLuuTru: viGiu.luuTru,
    giaoDichDoiVi: doiVi,
    idKhoanMoSoBo: idNeoSong,
    soDuBanDauBo: viBo.soDu - (viBo.tongSo - neo),
    khoanChuyenNoiBo: noiBo,
    hoaDonDoiVi: [for (final b in hoaDon) b.id],
    mucTieu: [
      for (final m in mucTieu) _doiMucTieu(m, idBo: viBo.id, idGiu: viGiu.id),
    ],
    // Khoản chuyển nội bộ tự triệt tiêu trong tổng hai sổ, nên không cần vế riêng.
    soDuSauGop: viGiu.tongSo + viBo.tongSo - neo,
    chuyenCoMacDinh: viBo.macDinh && !viGiu.luuTru,
    lyDoKhongGop: lyDoKhongGop(loaiViBo: viBo.loai, loaiViGiu: viGiu.loai),
  );
}

DoiViMucTieu _doiMucTieu(
  MucTieuChoGop m, {
  required String idBo,
  required String idGiu,
}) {
  final viNhan = m.walletId == idBo ? idGiu : m.walletId;
  final viNguon = m.viNguonTrich == idBo ? idGiu : m.viNguonTrich;
  return DoiViMucTieu(
    id: m.id,
    ten: m.ten,
    doiViNhan: m.walletId == idBo,
    doiViNguon: m.viNguonTrich == idBo,
    tatTrich: viNguon != null && viNguon == viNhan,
  );
}

/// Các dòng hộp xác nhận Gộp — in đúng [kh], không đếm lại (bẫy 4). Chữ là bản
/// nháp của spec mục 5.3; màn Stitch đã duyệt thắng.
List<String> cacDongXacNhanGop(KeHoachGop kh) {
  final phan = <String>[
    if (kh.giaoDichDoiVi.isNotEmpty) '${kh.giaoDichDoiVi.length} giao dịch',
    if (kh.hoaDonDoiVi.isNotEmpty) '${kh.hoaDonDoiVi.length} hoá đơn',
    if (kh.mucTieu.isNotEmpty) '${kh.mucTieu.length} mục tiêu',
  ];
  return [
    phan.isEmpty
        ? 'Không có giao dịch nào cần chuyển.'
        : 'Chuyển ${phan.join(', ')} sang ví đã đồng bộ.',
    if (kh.khoanChuyenNoiBo.isNotEmpty)
      'Bỏ ${kh.khoanChuyenNoiBo.length} khoản chuyển giữa hai ví.',
    if (kh.soDuBanDauBo.abs() >= 0.5)
      'Bỏ số dư ban đầu ${CurrencyFormatter.format(kh.soDuBanDauBo)} '
          'của ví trên máy này.',
    if (kh.tenMucTieuTatTrich.isNotEmpty)
      'Tắt trích tự động của mục tiêu ${kh.tenMucTieuTatTrich.join(', ')}.',
    'Số dư sau gộp: ${CurrencyFormatter.format(kh.soDuSauGop)}.',
    'Ví giữ lại: ${WalletType.tuKhoa(kh.loaiViGiu).nhan}'
        '${kh.viGiuLuuTru ? ', đang lưu trữ' : ''}.',
    'Không hoàn tác được.',
  ];
}
