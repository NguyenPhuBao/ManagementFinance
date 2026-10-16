/// Nhắc ghi sau khi dùng app ngân hàng (spec `docs/superpowers/specs/2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md`
/// §4) — **Dart thuần**: dựng phiên từ sự kiện vào / ra màn hình của app ngân hàng, rồi lọc phiên đáng nhắc.
///
/// ⚠️ `android/…/PhienNganHang.kt` viết lại ĐÚNG thuật toán [phienTuSuKien] và các hằng có cột Kotlin để quyết định
/// thông báo ở nền — khớp TAY; `phien_ngan_hang_noi_day_test.dart` so hằng hai bên. Đổi thuật toán ở đây thì đổi cả
/// bên ấy.
library;

/// Quay lại app trong khoảng này là CÙNG phiên; rời đủ khoảng này mới là phiên đã kết thúc. Kotlin `GOP_PHIEN_MS`.
const Duration kGopPhien = Duration(minutes: 3);

/// Tổng thời gian trên màn tối thiểu để nhắc. Kotlin `TOI_THIEU_TREN_MAN_MS`.
const Duration kToiThieuTrenMan = Duration(seconds: 20);

/// Bằng chứng tính từ *mở − 2 phút*. Kotlin `TRUOC_PHIEN_MS`.
const Duration kTruocPhien = Duration(minutes: 2);

/// Tin / biên lai tính tới *rời + 10 phút*. Kotlin `SAU_PHIEN_TIN_MS`.
const Duration kSauPhienTin = Duration(minutes: 10);

/// Giao dịch đã ghi tính tới *rời + 30 phút* — chỉ Dart (Kotlin không thấy sổ).
const Duration kSauPhienGiaoDich = Duration(minutes: 30);

/// Không xét phiên cũ hơn — lịch sử sử dụng của hệ thống cũng không giữ lâu. Kotlin chỉ lùi 1 ngày (`LUI_NEN_MS`).
const Duration kLuiToiDa = Duration(days: 7);

/// Tiền tố khoá của dòng nhắc. Bắt đầu bằng `bienDong:` (`kTienToKhoaBienDong`) nên form mở được đường Lưu / Bỏ qua →
/// xoá cứng của D1.
const String kTienToKhoaPhien = 'bienDong:phien|';

/// Thân của dòng nhắc trong danh sách *Biến động*.
const String kThanPhien = 'Chưa thấy giao dịch nào — chạm để ghi';

class SuKienSuDung {
  const SuKienSuDung({required this.goi, required this.lop, required this.vao, required this.luc});

  final String goi;

  /// Lớp activity. Dựng phiên theo LỚP chứ không theo gói: hai activity của cùng app đổi chỗ trong cùng một mili giây
  /// có thể đến lộn thứ tự (đo Realme 02/10: `PAUSED MainActivity` và `RESUMED …AuthenSessionActivity` cùng 18:30:29).
  final String lop;

  /// `true` = lên màn (`ACTIVITY_RESUMED`), `false` = rời màn (`ACTIVITY_PAUSED`).
  final bool vao;
  final DateTime luc;
}

/// Một phần tử của kênh `suKien` (`{goi, lop, loai: 'vao' | 'ra', luc: ms}`) → [SuKienSuDung]; sai hình dạng → `null`.
SuKienSuDung? docSuKien(Object? m) {
  if (m is! Map) return null;
  final goi = m['goi'];
  final lop = m['lop'];
  final loai = m['loai'];
  final luc = m['luc'];
  if (goi is! String || goi.isEmpty || lop is! String || luc is! int) return null;
  if (loai != 'vao' && loai != 'ra') return null;
  return SuKienSuDung(goi: goi, lop: lop, vao: loai == 'vao', luc: DateTime.fromMillisecondsSinceEpoch(luc));
}

class PhienNganHang {
  const PhienNganHang({
    required this.goi,
    required this.batDau,
    required this.ketThuc,
    required this.trenMan,
    this.dangMo = false,
  });

  final String goi;
  final DateTime batDau;

  /// Lúc rời app lần cuối; phiên [dangMo] thì là *bây giờ* của lúc dựng.
  final DateTime ketThuc;
  final Duration trenMan;

  /// App vẫn đang trên màn (khoảng cuối chưa có sự kiện rời).
  final bool dangMo;

  /// Đã rời đủ [kGopPhien] và không mở lại — hết khả năng gộp thêm khoảng nào.
  bool daKetThuc(DateTime bayGio) => !dangMo && bayGio.difference(ketThuc) >= kGopPhien;
}

/// Dựng phiên theo từng gói (spec §4.2): tập lớp đang trên màn rỗng → khác rỗng mở một khoảng, ngược lại đóng khoảng;
/// khoảng cách nhau ≤ [kGopPhien] gộp làm một phiên. Bỏ sự kiện sau [bayGio] và sự kiện rời lẻ.
List<PhienNganHang> phienTuSuKien(Iterable<SuKienSuDung> suKien, {required DateTime bayGio}) {
  final theoGoi = <String, List<(int, SuKienSuDung)>>{};
  var thuTu = 0;
  for (final e in suKien) {
    if (e.luc.isAfter(bayGio)) continue;
    (theoGoi[e.goi] ??= []).add((thuTu++, e));
  }
  final ra = <PhienNganHang>[];
  for (final goi in theoGoi.keys) {
    // `List.sort` không ổn định — thứ tự kênh trả về làm khoá phụ cho hai sự kiện cùng mili giây.
    final ds = theoGoi[goi]!
      ..sort((a, b) {
        final c = a.$2.luc.compareTo(b.$2.luc);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final khoang = <(DateTime, DateTime?)>[];
    final tren = <String>{};
    DateTime? moTu;
    for (final (_, e) in ds) {
      if (e.vao) {
        if (tren.isEmpty) moTu = e.luc;
        tren.add(e.lop);
      } else if (tren.remove(e.lop) && tren.isEmpty && moTu != null) {
        khoang.add((moTu, e.luc));
        moTu = null;
      }
    }
    if (moTu != null) khoang.add((moTu, null));

    PhienNganHang? hien;
    for (final (bd, kt) in khoang) {
      final ket = kt ?? bayGio;
      final dai = ket.difference(bd);
      final h = hien;
      if (h != null && !h.dangMo && bd.difference(h.ketThuc) <= kGopPhien) {
        hien = PhienNganHang(goi: goi, batDau: h.batDau, ketThuc: ket, trenMan: h.trenMan + dai, dangMo: kt == null);
      } else {
        if (h != null) ra.add(h);
        hien = PhienNganHang(goi: goi, batDau: bd, ketThuc: ket, trenMan: dai, dangMo: kt == null);
      }
    }
    if (hien != null) ra.add(hien);
  }
  ra.sort((a, b) => a.batDau.compareTo(b.batDau));
  return ra;
}

/// Phiên đã kết thúc và mở SAU [moc] — những phiên lượt nhập này phải xét (tạo dòng hay không).
List<PhienNganHang> phienCanXet(List<PhienNganHang> phien, {required DateTime bayGio, required DateTime moc}) => [
      for (final p in phien)
        if (p.batDau.isAfter(moc) && p.daKetThuc(bayGio)) p,
    ];

/// Mốc mới sau khi xét [xet]: giờ rời lớn nhất; `null` khi không có gì để xét (mốc giữ nguyên).
DateTime? mocSauKhiXet(List<PhienNganHang> xet) =>
    xet.isEmpty ? null : xet.map((p) => p.ketThuc).reduce((a, b) => a.isAfter(b) ? a : b);

/// Tin ngân hàng / biên lai đang là hàng loại 20 (KHÔNG phải dòng nhắc): nguồn + mốc sự kiện (`createdAt`).
typedef BangChungTin = ({String nguon, DateTime luc});

/// Một giao dịch sống trong sổ.
typedef BangChungGiaoDich = ({DateTime ngay, String walletId, String? walletTransfer});

bool _trong(DateTime t, DateTime tu, DateTime den) => !t.isBefore(tu) && !t.isAfter(den);

/// Phiên đáng nhắc (spec §4.3): đủ [kToiThieuTrenMan], gói theo dõi, không tin / biên lai cùng nguồn trong
/// [mở − kTruocPhien, rời + kSauPhienTin], không giao dịch nào trong [mở − kTruocPhien, rời + kSauPhienGiaoDich].
/// Biết ví của nguồn ([viCuaNguon]) thì chỉ giao dịch có ví đi hoặc ví đến là ví ấy mới là bằng chứng.
List<PhienNganHang> phienCanNhac(
  List<PhienNganHang> xet, {
  required String? Function(String goi) nguonCuaGoi,
  required List<BangChungTin> tin,
  required List<BangChungGiaoDich> giaoDich,
  Map<String, String?> viCuaNguon = const {},
}) {
  final ra = <PhienNganHang>[];
  for (final p in xet) {
    if (p.trenMan < kToiThieuTrenMan) continue;
    final nguon = nguonCuaGoi(p.goi);
    if (nguon == null) continue;
    final tu = p.batDau.subtract(kTruocPhien);
    final denTin = p.ketThuc.add(kSauPhienTin);
    if (tin.any((b) => b.nguon == nguon && _trong(b.luc, tu, denTin))) continue;
    final vi = viCuaNguon[nguon];
    final denGd = p.ketThuc.add(kSauPhienGiaoDich);
    if (giaoDich.any((g) =>
        _trong(g.ngay, tu, denGd) && (vi == null || g.walletId == vi || g.walletTransfer == vi))) {
      continue;
    }
    ra.add(p);
  }
  return ra;
}

String _hai(int n) => n.toString().padLeft(2, '0');

/// `bienDong:phien|<nguồn>|<yyyy-MM-ddTHH:mm của giờ mở>`.
String dedupeKeyPhien(String nguon, DateTime batDau) =>
    '$kTienToKhoaPhien$nguon|${batDau.toIso8601String().substring(0, 16)}';

bool laKhoaPhien(String dedupeKey) => dedupeKey.startsWith(kTienToKhoaPhien);

/// `/add?date=<giờ mở>&nguon=…&phien=<giờ rời>&khoa=…` — không `amount` / `huong`: form mở với số tiền trống.
String deeplinkPhien(PhienNganHang p, {required String nguon, required String dedupeKey}) => Uri(
      path: '/add',
      queryParameters: {
        'date': p.batDau.toIso8601String(),
        'nguon': nguon,
        'phien': p.ketThuc.toIso8601String(),
        'khoa': dedupeKey,
      },
    ).toString();

/// *"MB Bank · 11:19 – 11:20"*; cùng phút thì một mốc.
String tieuDePhien(String nguon, DateTime batDau, DateTime ketThuc) {
  String gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';
  final cungPhut = batDau.year == ketThuc.year &&
      batDau.month == ketThuc.month &&
      batDau.day == ketThuc.day &&
      batDau.hour == ketThuc.hour &&
      batDau.minute == ketThuc.minute;
  return cungPhut ? '$nguon · ${gio(batDau)}' : '$nguon · ${gio(batDau)} – ${gio(ketThuc)}';
}
