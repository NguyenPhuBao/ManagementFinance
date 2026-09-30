/// D1 — điền sẵn form Thêm giao dịch từ một hàng biến động số dư (spec
/// `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.3). Hàm thuần.
///
/// Hợp đồng query là `deeplinkBienDong` (`core/notification/nhap_bien_dong.dart`): `amount · huong · date · note ·
/// nguon · duoi · khoa`. Query hỏng thì bỏ đúng trường ấy, không ném — route đọc query từ URL (khuôn
/// `dienSanTuQuery` của B2).
library;

import '../../../core/database/app_database.dart';
import '../../category/domain/gan_hang_loat.dart';
import '../../category/domain/phan_loai_ghi_chu.dart';
import 'doc_cau_giao_dich.dart';

/// Tiền tố `dedupeKey` của hàng loại 20 (`dedupeKeyBienDong`). Chỉ khoá mang tiền tố này mới mở đường
/// Lưu / Bỏ qua → xoá cứng hàng.
const String kTienToKhoaBienDong = 'bienDong:';

class DienSanBienDong {
  const DienSanBienDong({
    required this.khoa,
    required this.nguon,
    required this.ghiChu,
    this.soTien,
    this.chieu,
    this.thoiGian,
    this.duoi,
  });

  /// `dedupeKey` của hàng loại 20 — xoá cứng hàng ấy khi Lưu / Bỏ qua.
  final String khoa;
  final String nguon;

  /// Nội dung tin (đã bỏ số TK / số dư ở `docTinBienDong`), rỗng khi thiếu.
  final String ghiChu;
  final double? soTien;

  /// `'thu'` | `'chi'`.
  final String? chieu;

  /// Ngày GIỜ trong tin — form giữ cả giờ (spec §3.3).
  final DateTime? thoiGian;

  /// Đuôi số tài khoản trong tin — khoá chọn sẵn ví cùng [nguon].
  final String? duoi;
}

/// `null` khi query không phải của một hàng biến động số dư — form mở như thường.
DienSanBienDong? dienSanBienDongTuQuery(Map<String, String> q) {
  final khoa = q['khoa'];
  final nguon = q['nguon']?.trim() ?? '';
  if (khoa == null || !khoa.startsWith(kTienToKhoaBienDong) || nguon.isEmpty) return null;
  final tien = double.tryParse(q['amount'] ?? '');
  final chieu = q['huong'];
  final duoi = q['duoi']?.trim() ?? '';
  return DienSanBienDong(
    khoa: khoa,
    nguon: nguon,
    ghiChu: (q['note'] ?? '').trim(),
    // Dưới 13 chữ số: cột tiền là numeric(15,2) (trần `kSoChuSoToiDaSoTien`).
    soTien: (tien != null && tien > 0 && tien < 1e13) ? tien : null,
    chieu: const {'thu', 'chi'}.contains(chieu) ? chieu : null,
    thoiGian: DateTime.tryParse(q['date'] ?? ''),
    duoi: duoi.isEmpty ? null : duoi,
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

/// Dải nguồn trên form (Stitch `52d9d2ef…`): *"Từ thông báo MB Bank · TK ••7777 · 02/09 12:01"*.
String dongNguonBienDong(DienSanBienDong d) {
  final t = d.thoiGian;
  return [
    'Từ thông báo ${d.nguon}',
    if (d.duoi != null) 'TK ••${d.duoi}',
    if (t != null) '${_hai(t.day)}/${_hai(t.month)} ${_hai(t.hour)}:${_hai(t.minute)}',
  ].join(' · ');
}

/// Dựng [KetQuaDocCau] cho đường điền của C2 (`_dienKetQua`). Danh mục đoán trên nội dung tin bằng ĐÚNG luật C2
/// ([doanDanhMucTuGhiChu]: tên → B1 → từ khoá, không AI), chỉ trong danh mục hợp chiều ([hopLeTheoChieu]). [walletId]
/// là ví chọn sẵn theo nguồn + đuôi TK (`ViTheoNguonStore`), `null` = chưa biết.
KetQuaDocCau ketQuaTuBienDong(
  DienSanBienDong d, {
  required List<Category> chonDuoc,
  BoPhanLoaiGhiChu? mo,
  Set<(String, String)> tatCap = const {},
  Map<String, List<String>> tuKhoa = const {},
  String? walletId,
}) {
  final chieu = d.chieu;
  final hopLe = chieu != null
      ? hopLeTheoChieu(chieu, chonDuoc)
      : {for (final c in chonDuoc) if (!c.isDeleted && !c.isGroup) c.id};
  final dm = d.ghiChu.isEmpty
      ? null
      : doanDanhMucTuGhiChu(
          cauTimTen: d.ghiChu,
          ghiChu: d.ghiChu,
          chonDuoc: [for (final c in chonDuoc) if (hopLe.contains(c.id)) c],
          mo: mo,
          tatCap: tatCap,
          tuKhoa: tuKhoa,
        );
  final t = d.thoiGian;
  return KetQuaDocCau(
    soTien: d.soTien,
    loai: chieu,
    ngay: t == null ? null : DateTime(t.year, t.month, t.day),
    walletId: walletId,
    categoryId: dm?.categoryId,
    doan: dm?.doan,
    lyDoDanhMuc: dm?.lyDo,
    goiY: dm?.goiY,
    ghiChu: d.ghiChu,
  );
}

/// Một khoản trong sổ, đủ để xét *"có thể bạn đã ghi khoản này"*.
typedef KhoanSo = ({String id, double soTien, String loai, DateTime ngay, String ghiChu});

/// Khoản trong sổ cùng số tiền (ngưỡng nửa đồng — `amount` là `double`), cùng chiều, cùng NGÀY lịch với tin (spec
/// §3.3). Chỉ để NHẮC — người dùng tự quyết, không chặn. Thiếu một trong ba căn cứ thì không nhắc.
List<KhoanSo> khoanCoTheDaGhi(
  List<KhoanSo> so, {
  required double? soTien,
  required String? chieu,
  required DateTime? ngay,
}) {
  if (soTien == null || chieu == null || ngay == null) return const [];
  return [
    for (final k in so)
      if (k.loai == chieu &&
          (k.soTien - soTien).abs() < 0.5 &&
          k.ngay.year == ngay.year &&
          k.ngay.month == ngay.month &&
          k.ngay.day == ngay.day)
        k,
  ];
}
