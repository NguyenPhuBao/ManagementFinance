/// D1 — điền sẵn form Thêm giao dịch từ một hàng biến động số dư (spec
/// `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.3). Hàm thuần.
///
/// Hợp đồng query là `deeplinkBienDong` / `deeplinkBienLaiChuaDoc` (`core/notification/nhap_bien_dong.dart`) và
/// `deeplinkPhien` (`core/notification/phien_ngan_hang.dart`): `amount · huong · date · note · nguon · duoi · khoa`
/// (+ `anh · doc · blt` của biên lai, `phien` của dòng nhắc). Query hỏng thì bỏ đúng trường ấy, không ném — route đọc
/// query từ URL (khuôn `dienSanTuQuery` của B2).
library;

import '../../../core/database/app_database.dart';
import '../../../core/notification/ten_tep_bien_lai.dart';
import '../../category/domain/gan_hang_loat.dart';
import '../../category/domain/phan_loai_ghi_chu.dart';
import 'doc_anh_quet.dart';
import 'doc_cau_giao_dich.dart';

/// Tiền tố `dedupeKey` của hàng loại 20 (`dedupeKeyBienDong`). Chỉ khoá mang tiền tố này mới mở đường
/// Lưu / Bỏ qua → xoá cứng hàng.
const String kTienToKhoaBienDong = 'bienDong:';

/// A5 — khoá của form mở từ ẢNH QUÉT (nút Quét Trang chủ): `quet:<tên ảnh>`. Không có hàng loại 20 nào đi kèm — Lưu /
/// Bỏ qua chỉ xoá ảnh trong `KhoAnhQuet`.
const String kTienToKhoaQuet = 'quet:';

/// Nguồn hiển thị của form mở từ ảnh quét.
const String kNguonAnhQuet = 'Ảnh quét';

class DienSanBienDong {
  const DienSanBienDong({
    required this.khoa,
    required this.nguon,
    required this.ghiChu,
    this.soTien,
    this.chieu,
    this.thoiGian,
    this.duoi,
    this.anh,
    this.cachDoc,
    this.phien,
    this.ai = false,
    this.luaChonTien = const [],
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

  /// Chia sẻ biên lai (2026-10-02): tên tệp ảnh biên lai trong `filesDir/bien_lai/` — form hiện ảnh nhỏ để đối chiếu
  /// và xoá tệp khi Lưu / Bỏ qua. `null` = hàng không mang ảnh.
  final String? anh;

  /// `'mau'` | `'chung'` | `'khong'` — số liệu của hàng này ĐỌC TỪ ẢNH biên lai, bằng cách nào. `null` = số liệu đến
  /// từ tin ngân hàng (kể cả khi hàng được gắn thêm ảnh để đối chiếu).
  final String? cachDoc;

  /// Nhắc ghi sau khi dùng app ngân hàng (2026-10-03): giờ RỜI app ngân hàng của phiên đang nhắc. Có mặt ⇔ hàng là dòng
  /// nhắc (không số tiền, không chiều — [thoiGian] là giờ mở app).
  final DateTime? phien;

  /// A5 — ít nhất một ô do AI lấp (chỉ có nghĩa với khoá `quet:`).
  final bool ai;

  /// A5 mục 13 — ảnh quét mà số AI và số luật LỆCH nhau: các số cho người dùng chạm chọn (số AI trước), ô số tiền để
  /// trống. Rỗng với mọi khoá khác `quet:`.
  final List<double> luaChonTien;

  /// Form mở từ ảnh quét (A5) — không gắn nguồn ngân hàng, không hàng loại 20.
  bool get laQuet => khoa.startsWith(kTienToKhoaQuet);
}

/// `null` khi query không phải của một hàng biến động số dư — form mở như thường.
DienSanBienDong? dienSanBienDongTuQuery(Map<String, String> q) {
  final khoa = q['khoa'];
  final nguon = q['nguon']?.trim() ?? '';
  if (khoa == null || nguon.isEmpty) return null;
  if (!khoa.startsWith(kTienToKhoaBienDong) && !khoa.startsWith(kTienToKhoaQuet)) return null;
  final tien = double.tryParse(q['amount'] ?? '');
  final chieu = q['huong'];
  final duoi = q['duoi']?.trim() ?? '';
  final anh = q['anh'];
  final doc = q['doc'];
  return DienSanBienDong(
    // Tên tệp sẽ được ghép thành đường dẫn — không khớp khuôn thì coi như không có ảnh.
    anh: (anh != null && tenTepBienLaiHopLe(anh)) ? anh : null,
    cachDoc: const {'mau', 'chung', 'khong'}.contains(doc) ? doc : null,
    khoa: khoa,
    nguon: nguon,
    ghiChu: (q['note'] ?? '').trim(),
    // Dưới 13 chữ số: cột tiền là numeric(15,2) (trần `kSoChuSoToiDaSoTien`).
    soTien: (tien != null && tien > 0 && tien < 1e13) ? tien : null,
    chieu: const {'thu', 'chi'}.contains(chieu) ? chieu : null,
    thoiGian: DateTime.tryParse(q['date'] ?? ''),
    duoi: duoi.isEmpty ? null : duoi,
    phien: DateTime.tryParse(q['phien'] ?? ''),
    ai: khoa.startsWith(kTienToKhoaQuet) && q['ai'] == '1',
    luaChonTien: !khoa.startsWith(kTienToKhoaQuet)
        ? const []
        : [
            for (final x in (q['chon'] ?? '').split(','))
              if (double.tryParse(x) case final v? when v > 0 && v < 1e13) v,
          ],
  );
}

/// A5 — query mở form từ ảnh quét. Khoá mang tên ảnh: mỗi lần quét một khoá khác.
///
/// [luaChonTien] — số AI và số luật lệch nhau (`chotTongQuet`): form hiện chip chọn, ô số tiền trống.
String deeplinkQuet(KetQuaAnhQuet kq, {required String anh, List<double> luaChonTien = const []}) =>
    Uri(path: '/add', queryParameters: {
      'khoa': '$kTienToKhoaQuet$anh',
      'nguon': kNguonAnhQuet,
      'anh': anh,
      'huong': kq.chieu,
      'date': kq.thoiGian.toIso8601String(),
      'note': kq.ghiChu,
      if (kq.soTien != null) 'amount': kq.soTien!.toStringAsFixed(0),
      if (kq.aiLap) 'ai': '1',
      if (luaChonTien.isNotEmpty) 'chon': [for (final v in luaChonTien) v.toStringAsFixed(0)].join(','),
    }).toString();

String _hai(int n) => n.toString().padLeft(2, '0');

/// Dải nguồn trên form (Stitch `52d9d2ef…`): *"Từ thông báo MB Bank · TK ••7777 · 02/09 12:01"*.
///
/// Hàng có số liệu ĐỌC TỪ ẢNH biên lai ([DienSanBienDong.cachDoc] khác `null`) thì nói *"Từ biên lai MB Bank · …"*;
/// app gửi không rõ (nguồn là [kNguonBienLai]) thì chỉ *"Từ biên lai · …"* — không lặp chữ.
String dongNguonBienDong(DienSanBienDong d) {
  final t = d.thoiGian;
  final dau = d.laQuet
      ? 'Từ ảnh quét'
      : d.phien != null
          ? 'Dùng ${d.nguon}'
          : d.cachDoc == null
              ? 'Từ thông báo ${d.nguon}'
              : (d.nguon == kNguonBienLai ? 'Từ biên lai' : 'Từ biên lai ${d.nguon}');
  return [
    dau,
    if (d.duoi != null) 'TK ••${d.duoi}',
    if (t != null) '${_hai(t.day)}/${_hai(t.month)} ${_hai(t.hour)}:${_hai(t.minute)}',
    if (d.laQuet && d.ai) 'Đọc bằng AI',
  ].join(' · ');
}

/// Dòng phụ dưới dải nguồn của form mở từ BIÊN LAI. `null` = không cần nói gì (đọc bằng mẫu riêng đã đo, hoặc số
/// liệu không đến từ ảnh).
String? dongPhuBienLai(String? cachDoc) => switch (cachDoc) {
      'chung' => 'Đọc từ ảnh — hãy kiểm lại',
      'khong' => 'Chưa đọc được số tiền — nhìn ảnh để nhập',
      _ => null,
    };

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
      : {
          for (final c in chonDuoc)
            if (!c.isDeleted && !c.isGroup) c.id
        };
  final dm = d.ghiChu.isEmpty
      ? null
      : doanDanhMucTuGhiChu(
          cauTimTen: d.ghiChu,
          ghiChu: d.ghiChu,
          chonDuoc: [
            for (final c in chonDuoc)
              if (hopLe.contains(c.id)) c
          ],
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
