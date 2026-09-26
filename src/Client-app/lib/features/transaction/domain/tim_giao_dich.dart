/// Tìm giao dịch theo tiêu chí — nguồn DUY NHẤT của tool `tim_giao_dich` (bước
/// 2, spec `2026-09-23-buoc-2-ba-tool-doc-tim-giao-dich-design.md` mục 3.8).
///
/// Nằm ở `transaction/domain/`, NGOÀI `ai_edge`: lọc theo ví và theo chiều tiền
/// là thứ test quét 14 cấm trong `ai_edge/`. Lớp AI chỉ CHÉP kết quả.
///
/// ⚠️ Lọc đi QUA `applyTransactionFilter` — định nghĩa duy nhất của bộ lọc Sổ
/// giao dịch (ví khớp cả ví đích của khoản chuyển; từ khoá không dấu; khoảng
/// tiền qua `KhoangTien.chua`). Viết lại phép lọc ở đây là bản thứ hai, và bản
/// thứ hai quên ví đích — im lặng.
library;

import '../../../core/utils/khop_ten.dart';
import '../../analytics/data/bao_cao_repository.dart';
import '../../analytics/domain/khoan_vao_thong_ke.dart';
import '../data/models/transaction_entity.dart';
import 'khoang_tien.dart';
import 'tieu_de_giao_dich.dart';
import 'transaction_filter.dart';
import 'transaction_lookup.dart';

enum ChieuTim { chi, thu, chuyen, tatCa }

enum SapXepTim { soTien, moiNhat }

enum TruongTen { danhMuc, vi }

class TieuChiTim {
  const TieuChiTim({
    this.chieu = ChieuTim.tatCa,
    this.khoangTien,
    this.tenDanhMuc,
    this.tenVi,
    this.tuKhoa = '',
    this.sapXep = SapXepTim.soTien,
  });

  final ChieuTim chieu;
  final KhoangTien? khoangTien;
  final String? tenDanhMuc;
  final String? tenVi;
  final String tuKhoa;
  final SapXepTim sapXep;
}

/// Một giao dịch đã tra tên — `ai_edge` chỉ chép.
class DongTimThay {
  const DongTimThay({
    required this.tieuDe,
    required this.tenDanhMuc,
    required this.tenVi,
    required this.tenViDich,
    required this.soTien,
    required this.chieu,
    required this.ngay,
  });

  /// `tieuDeGiaoDich` — cùng luật với tiêu đề dòng Sổ giao dịch.
  final String tieuDe;

  /// `null` = chưa phân loại (hoặc khoản chuyển).
  final String? tenDanhMuc;
  final String tenVi;

  /// Ví đích của khoản chuyển; `null` với khoản thu/chi.
  final String? tenViDich;
  final double soTien;

  /// `chi` · `thu` · `chuyen`; `tatCa` chỉ khi hàng mang một loại lạ.
  final ChieuTim chieu;
  final DateTime ngay;
}

/// Tham số tên không khớp đúng một mục — tool dựng lời từ chối từ đây.
class LoiKhopTen {
  const LoiKhopTen({
    required this.truong,
    required this.hoi,
    required this.nhieu,
    required this.tenGoiY,
  });

  final TruongTen truong;
  final String hoi;

  /// `true`: khớp nhiều mục, [tenGoiY] là các mục đã khớp. `false`: không khớp
  /// mục nào, [tenGoiY] là mọi tên còn sống — để mô hình gọi lại đúng.
  final bool nhieu;
  final List<String> tenGoiY;
}

class KetQuaTimGiaoDich {
  const KetQuaTimGiaoDich({
    required this.dong,
    required this.soKhop,
    required this.tongChi,
    required this.tongThu,
    required this.tongChuyen,
    this.tenDanhMucKhop,
    this.tenViKhop,
  }) : loi = null;

  const KetQuaTimGiaoDich.loi(LoiKhopTen this.loi)
      : dong = const [],
        soKhop = 0,
        tongChi = 0,
        tongThu = 0,
        tongChuyen = 0,
        tenDanhMucKhop = null,
        tenViKhop = null;

  /// Tối đa `toiDa` dòng, đã xếp.
  final List<DongTimThay> dong;

  /// MỌI khoản khớp — không phải `dong.length` (bẫy 10 của spec).
  final int soKhop;
  final double tongChi;
  final double tongThu;
  final double tongChuyen;

  /// Tên thật của danh mục / ví đã khớp tham số — `null` khi không lọc theo
  /// trường ấy. Có nhãn (bước 2c) để tiền tố mẫu câu in đúng "danh mục X, ví Y".
  final String? tenDanhMucKhop;
  final String? tenViKhop;

  /// Cả hai tên khớp, bỏ null — giữ cho chỗ đọc cũ.
  List<String> get tenKhop => [
        if (tenDanhMucKhop != null) tenDanhMucKhop!,
        if (tenViKhop != null) tenViKhop!,
      ];
  final LoiKhopTen? loi;
}

KetQuaTimGiaoDich timGiaoDich({
  required List<TransactionEntity> trongKy,
  required TransactionLookup lookup,
  required List<LuaChonLoc> viSong,
  required List<LuaChonLoc> danhMucSong,
  required TieuChiTim tieuChi,
  required DateTime now,
  required int toiDa,
}) {
  // 1. Tên → id, hoặc từ chối.
  final (dm, loiDm) =
      _giaiTen(TruongTen.danhMuc, tieuChi.tenDanhMuc, danhMucSong);
  if (loiDm != null) return KetQuaTimGiaoDich.loi(loiDm);
  final (vi, loiVi) = _giaiTen(TruongTen.vi, tieuChi.tenVi, viSong);
  if (loiVi != null) return KetQuaTimGiaoDich.loi(loiVi);

  // 2. Bộ lọc của Sổ giao dịch — không viết lại.
  final loc = applyTransactionFilter(
    trongKy,
    TransactionFilter(
      type: switch (tieuChi.chieu) {
        ChieuTim.chi => TransactionTypeFilter.chi,
        ChieuTim.thu => TransactionTypeFilter.thu,
        ChieuTim.chuyen => TransactionTypeFilter.transfer,
        ChieuTim.tatCa => TransactionTypeFilter.all,
      },
      walletId: vi?.id,
      categoryId: dm?.id,
      query: tieuChi.tuKhoa,
      khoangTien: tieuChi.khoangTien,
    ),
  );

  final con = [
    for (final t in loc)
      // 3. Khoản chuyển đã qua bộ lọc chiều ở trên. Khoản thu/chi phải là thu chi
      //    THẬT: `khoanVaoThongKe` là định nghĩa duy nhất loại khoản điều chỉnh số
      //    dư và khoản mở sổ — ghi sổ, không phải thu chi.
      if ((t.type == 'transfer' ||
              khoanVaoThongKe(
                loai: t.type,
                categoryId: t.categoryId,
                ghiChu: t.note,
              )) &&
          // 4. Việc chưa xảy ra (khoản trích mục tiêu hẹn trước) — không bao giờ
          //    là "lần gần nhất" (spec mục 1.2 hàng 11).
          !t.date.isAfter(now))
        t,
  ];

  // 5. Tổng trên MỌI khoản còn lại.
  final tong = summarizeTransactions(con);
  var tongChuyen = 0.0;
  for (final t in con) {
    if (t.type == 'transfer') tongChuyen += t.amount;
  }

  // 6. Xếp, cắt, tra tên.
  final xep = [...con]
    ..sort(tieuChi.sapXep == SapXepTim.soTien ? _lonTruoc : _moiTruoc);
  return KetQuaTimGiaoDich(
    dong: [for (final t in xep.take(toiDa)) _dong(t, lookup)],
    soKhop: con.length,
    tongChi: tong.expense,
    tongThu: tong.income,
    tongChuyen: tongChuyen,
    tenDanhMucKhop: dm?.ten,
    tenViKhop: vi?.ten,
  );
}

(LuaChonLoc?, LoiKhopTen?) _giaiTen(
  TruongTen truong,
  String? ten,
  List<LuaChonLoc> tatCa,
) {
  final hoi = ten?.trim() ?? '';
  if (hoi.isEmpty) return (null, null);
  return switch (khopTheoTen<LuaChonLoc>(hoi, tatCa, (x) => x.ten)) {
    KhopMot(:final muc) => (muc, null),
    KhopNhieu(:final ds) => (
        null,
        LoiKhopTen(
          truong: truong,
          hoi: hoi,
          nhieu: true,
          tenGoiY: [for (final x in ds) x.ten],
        ),
      ),
    KhongKhop() => (
        null,
        LoiKhopTen(
          truong: truong,
          hoi: hoi,
          nhieu: false,
          tenGoiY: [for (final x in tatCa) x.ten],
        ),
      ),
  };
}

int _lonTruoc(TransactionEntity a, TransactionEntity b) {
  final c = b.amount.compareTo(a.amount);
  return c != 0 ? c : b.date.compareTo(a.date);
}

int _moiTruoc(TransactionEntity a, TransactionEntity b) {
  final c = b.date.compareTo(a.date);
  return c != 0 ? c : b.amount.compareTo(a.amount);
}

DongTimThay _dong(TransactionEntity t, TransactionLookup lookup) {
  final tenDm = lookup.category(t.categoryId)?.name;
  return DongTimThay(
    tieuDe: tieuDeGiaoDich(loai: t.type, ghiChu: t.note, tenDanhMuc: tenDm),
    tenDanhMuc: tenDm,
    tenVi: lookup.walletName(t.walletId),
    tenViDich:
        t.walletTransfer == null ? null : lookup.walletName(t.walletTransfer),
    soTien: t.amount,
    chieu: switch (t.type) {
      'chi' => ChieuTim.chi,
      'thu' => ChieuTim.thu,
      'transfer' => ChieuTim.chuyen,
      _ => ChieuTim.tatCa,
    },
    ngay: t.date,
  );
}
