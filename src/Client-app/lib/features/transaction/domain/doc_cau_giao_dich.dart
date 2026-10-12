/// C2 — đọc MỘT câu tiếng Việt thành các ô của form Thêm giao dịch (spec
/// `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2). Hàm thuần, **luật** — tự nó không gọi mô hình (ô của AI được
/// truyền vào, xem dưới): nhanh, chạy trên mọi máy, và **không bao giờ bịa số** — ô nào không đọc chắc được thì `null`,
/// form giữ nguyên ô ấy.
///
/// Bất biến ④ của nhóm C: đây chỉ là điền sẵn. Người dùng xem lại rồi bấm **Lưu** mới ghi.
///
/// Thứ tự: ngày (`timNgayTrongCau`) → số tiền (§2.1) → chuyển ví (§2.9: ví đích sau *sang / vào / đến / tới*…) hoặc ví
/// (§2.4) → loại (§2.2, trên câu đã bỏ các đoạn ấy, để *"thứ 2"* không đọc thành *"thu"*) → ghi chú (§2.7: câu gốc bỏ
/// các đoạn đã dùng) → danh mục (§2.5: tên nêu trong câu → B1 khi chắc → từ khoá của danh mục → danh mục AI chọn, tất
/// cả trên ghi chú đã rút của luật; chuyển ví không có danh mục).
///
/// **Đọc bằng AI (§2.8):** khi có [KetQuaAi] — các ô thô mô hình trên máy trả về — mỗi ô của AI phải QUA KIỂM của luật
/// mới được dùng. AI đề xuất, luật kiểm: AI được chọn cách đọc, không được đưa ra một chữ số, một cái tên, hay một chữ
/// ghi chú không có trong câu / trên máy. Người dùng chốt 2026-09-30 (*đổi lần hai*): luật trước — AI chỉ LẤP ô luật để
/// trống, và màn chỉ hỏi AI khi còn ô câu có nhắc mà luật không đọc được ([KetQuaDocCau.oThieu]).
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/khop_ten.dart';
import '../../../core/utils/ngay_trong_cau.dart';
import '../../../core/utils/so_bang_chu.dart';
import '../../category/data/models/category_suggestion.dart';
import '../../category/data/services/category_suggestion_engine.dart';
import '../../category/domain/gan_hang_loat.dart';
import '../../category/domain/phan_loai_ghi_chu.dart';

/// Ô CÂU CÓ NHẮC mà luật (và AI, nếu đã hỏi) không đọc được — người dùng chốt 2026-09-30 (§8 câu 2, 9 spec): màn chỉ gọi
/// mô hình khi còn ô như thế. *Số tiền*: câu có số / số chữ đọc được thành tiền (`cachDocSoTien` khác rỗng). *Ngày*: câu
/// nhắc một thời điểm (`cauNhacNgay`). *Ví*: phần câu chưa dùng nhắc một ví có thật (`_cauNhacVi` — *ví* trần; *thẻ, quẹt,
/// ck, chuyển khoản, atm* chỉ khi có ví ngân hàng; viết tắt tên ví). *Danh mục*: tên / B1 / từ khoá đều im mà ghi chú còn
/// chữ (người dùng sửa lại sau lượt đo 3: *"chỗ nào không điền được thì cho AI điền"*; khoản chuyển ví không có danh mục).
/// *Ghi chú*: ghi chú còn sót một số đọc được thành tiền mà luật không dùng (AI chỉ được bớt chữ). Thu/chi KHÔNG ở đây:
/// form luôn có một chiều, câu không có từ chỉ thu thì chi là đúng gần như mọi lần.
enum OThieu { soTien, ngay, vi, danhMuc, ghiChu }

/// Kết quả đọc. Mọi trường `null` nghĩa là *không đọc được* — form **giữ nguyên** ô ấy.
class KetQuaDocCau {
  final double? soTien;

  /// `'thu'`, `'chi'` hoặc `null` (form giữ chiều đang chọn). Luật chỉ trả `'thu'` — chi là mặc định của form, câu không
  /// có từ chỉ thu thì không chứng minh được gì; `'chi'` chỉ đến từ AI (§2.8).
  final String? loai;

  /// Đầu ngày. Form chỉ đổi phần ngày, giữ giờ.
  final DateTime? ngay;
  final String? walletId;
  final String? walletToId;
  final String? categoryId;

  /// Khác `null` khi danh mục đến từ B1 — màn dùng nó để ghi phản hồi `chon` / `khac` lúc lưu, như thẻ gợi ý.
  final DoanDanhMuc? doan;

  /// Câu lý do khi danh mục đến từ B1 (`cauLyDoHoc`) hoặc từ từ khoá (`cauLyDoTuKhoa`).
  final String? lyDoDanhMuc;

  /// Gợi ý đứng sau danh mục khi nó đến từ B1 **hoặc từ khoá** — màn đặt làm `_choPhanXu` để lúc lưu ghi phản hồi
  /// `chon` / `khac` đúng nguồn, như thẻ gợi ý. `null` khi danh mục đến từ tên trong câu hoặc từ AI.
  final CategorySuggestion? goiY;

  /// Câu gốc (dựng sẵn — NFC) bỏ các đoạn đã dùng, gom khoảng trắng.
  final String ghiChu;
  final List<String> canhBao;

  /// AI THẬT SỰ làm ĐỔI ít nhất một ô (kể cả ghi chú) — màn ghi nguồn *"Đọc bằng AI"* / *"Đọc bằng luật"*. AI được hỏi
  /// mà mọi ô của nó bị lớp kiểm chặn, hoặc nó chỉ xác nhận chiều / ví form ĐANG chọn (`chieuDangChon`, `viDangChon`), thì
  /// vẫn là *"Đọc bằng luật"* (người dùng chốt 2026-09-30 sau lượt đo 3).
  final bool quaAi;

  /// C4 (spec 2026-10-12 §3.4): số tiền do LUẬT đọc bằng một dạng nói mới học (N1 *X đơn vị Y*, N2 số 10–999 × 1.000)
  /// — màn cho Gemma kiểm chéo, lệch thì hai chip. `false` khi số đến từ dạng có đơn vị / chữ số đủ, hay từ AI.
  final bool soTienCanKiem;

  /// Ô câu có nhắc mà vẫn chưa đọc được, tính SAU khi AI lấp (xem [OThieu]). Đường luật một mình: khác rỗng thì màn hỏi AI.
  final Set<OThieu> oThieu;

  const KetQuaDocCau({
    this.oThieu = const {},
    this.soTien,
    this.loai,
    this.ngay,
    this.walletId,
    this.walletToId,
    this.categoryId,
    this.doan,
    this.lyDoDanhMuc,
    this.goiY,
    required this.ghiChu,
    this.canhBao = const [],
    this.quaAi = false,
    this.soTienCanKiem = false,
  });

  bool get khongDocDuocGi =>
      soTien == null && loai == null && ngay == null && walletId == null && walletToId == null && categoryId == null;
}

const String kCauChuaDocDuoc = 'Mình chưa đọc được câu này — bạn điền tay nhé.';

/// Dòng tóm tắt dưới ô Nhập nhanh (§3): *"Đã điền: 45.000 đ · Hôm qua · Tiền mặt · Ăn uống"*. Chỉ nêu những ô ĐÃ đổi;
/// [tenVi] / [tenDanhMuc] là tên của ví / danh mục mà màn thực sự đặt (màn có thể bỏ danh mục khi đang ở đoạn Chuyển
/// khoản). Chuyển ví (§2.9): *"… · Chuyển ví · Tiền mặt → Tiết kiệm"*, chỉ có ví đích thì *"sang Tiết kiệm"*. Không đọc
/// được gì → [kCauChuaDocDuoc].
String cauDaDien(
  KetQuaDocCau kq, {
  String? tenVi,
  String? tenViDen,
  String? tenDanhMuc,
  required DateTime now,
}) {
  if (kq.khongDocDuocGi) return kCauChuaDocDuoc;
  final ngay = kq.ngay;
  String? chuNgay;
  if (ngay != null) {
    final lui = DateTime(now.year, now.month, now.day).difference(DateTime(ngay.year, ngay.month, ngay.day)).inDays;
    chuNgay = switch (lui) {
      0 => 'Hôm nay',
      1 => 'Hôm qua',
      2 => 'Hôm kia',
      _ => '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}'
          '${ngay.year == now.year ? '' : '/${ngay.year}'}',
    };
  }
  final phan = [
    if (kq.soTien != null) CurrencyFormatter.format(kq.soTien!),
    if (kq.loai == 'thu') 'Thu nhập',
    if (kq.loai == 'transfer') 'Chuyển ví',
    if (chuNgay != null) chuNgay,
    if (tenViDen != null)
      tenVi != null ? '$tenVi → $tenViDen' : 'sang $tenViDen'
    else if (tenVi != null)
      tenVi,
    if (tenDanhMuc != null) tenDanhMuc,
  ];
  return phan.isEmpty ? kCauChuaDocDuoc : 'Đã điền: ${phan.join(' · ')}';
}

/// Các ô THÔ mô hình trả về qua tool `dien_giao_dich` (§2.8) — chưa kiểm gì. `null` = mô hình để trống.
class KetQuaAi {
  final double? soTien;
  final String? loai;
  final String? ngay;
  final String? vi;
  final String? viDen;
  final String? danhMuc;
  final String? ghiChu;
  const KetQuaAi({this.soTien, this.loai, this.ngay, this.vi, this.viDen, this.danhMuc, this.ghiChu});

  /// Từ tham số lời gọi tool. Lỏng tay với kiểu (số có thể đến dạng chuỗi); rỗng, `0`, `khong_ro` → `null`.
  factory KetQuaAi.tuThamSo(Map<String, dynamic> a) {
    String? chuoi(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final tien = switch (a['so_tien']) {
      final num n => n.toDouble(),
      final String t => double.tryParse(t.replaceAll(RegExp(r'[^\d.]'), '')),
      _ => null,
    };
    final loai = chuoi(a['loai']);
    return KetQuaAi(
      soTien: tien == null || tien <= 0 ? null : tien,
      loai: switch (loai) { 'chi' || 'thu' => loai, 'chuyen_vi' => 'transfer', _ => null },
      ngay: chuoi(a['ngay']),
      vi: chuoi(a['vi']),
      viDen: chuoi(a['vi_den']),
      danhMuc: chuoi(a['danh_muc']),
      ghiChu: chuoi(a['ghi_chu']),
    );
  }
}

const String kCanhBaoNhieuSoTien = 'Câu có nhiều số tiền — mình chỉ điền một khoản, bạn kiểm tra lại nhé.';
const String kCanhBaoSoTienQuaLon = 'Số tiền quá lớn — mình không điền.';
const String kCanhBaoSoTienKhongHopLe = 'Số tiền không hợp lệ — mình không điền.';
const String kCanhBaoSoChuChuaRo = 'Số tiền viết bằng chữ chưa rõ — bạn nhập tay nhé.';

typedef _Khoang = ({int batDau, int ketThuc});

/// [noi]: cụm đọc bằng dạng NÓI mới học (C4: N1 *X đơn vị Y*) — màn cho Gemma kiểm chéo ([KetQuaDocCau.soTienCanKiem]).
typedef _CumTien = ({int batDau, int ketThuc, double giaTri, bool lit, bool noi});

/// Số + đơn vị trên câu đã bỏ dấu: `45k`, `45 nghìn`, `2tr`, `1tr2`, `1,2 triệu`, `2 củ`, `2 lít`, `3 xị`, `2 tỷ`,
/// `1,5 tỉ`. Nhóm 3 là phần lẻ dính liền sau `tr` / `ty` (`1tr2`, `1tr25`, `1tr200`, `1ty2`).
/// ⚠️ `ty` / `ti` khớp trên chữ ĐÃ BỎ DẤU nên phải qua [_donViDungDau] — *"2 tí kẹo"* bỏ dấu là `2 ti`.
final RegExp _mauSoDonVi = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d+(?:[.,]\d+)?)\s*(trieu|tr|cu|nghin|ngan|k|lit|xi|ty|ti)(\d{1,3})?(?![\p{L}\p{N}])',
  unicode: true,
);

/// Số trần: có chấm / phẩy nghìn (`45.000`) hoặc không (`45000`), tuỳ chọn `đ / đồng / vnd` theo sau (nằm trong cụm để
/// ghi chú bỏ luôn). Không dính `/` (ngày) hay chữ.
final RegExp _mauSoTran = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d{1,3}(?:[.,]\d{3})+|\d+)(?:\s*(?:dong|vnd|d)(?!\p{L}))?(?![\p{L}\p{N}/]|[.,]\d)',
  unicode: true,
);

final RegExp _truocLaNam = RegExp(r'(?<![a-z])nam\s*$');

/// Số ≤ 31 đứng ngay sau *tháng / ngày / mùng / mồng* là mốc lịch, không phải tiền: *"tiền điện tháng 10"* không có
/// cách đọc 10.000 — không thì AI chọn nó và lớp kiểm cho qua.
final RegExp _truocLaMocLich = RegExp(r'(?<![a-z])(?:thang|ngay|mung|mong)\s*$');
final RegExp _sauLaChuSoChu = RegExp(r'^\s+(mot|hai|ba|bon|tu|nam|sau|bay|tam|chin)(?![a-z])');
final RegExp _sauLaDonViTien = RegExp(r'^\s*(?:dong|vnd|d)(?!\p{L})', unicode: true);
final RegExp _tuCuoi = RegExp(r'([\p{L}\p{M}]+)\s+$', unicode: true);
final RegExp _tu = RegExp(r'[\p{L}\p{M}]+', unicode: true);
final RegExp _chiAscii = RegExp(r'^[a-z]+$');
final RegExp _chuCaiNgoaiAscii = RegExp(r'(?![a-zA-Z])[\p{L}\p{M}]', unicode: true);

/// Cả câu không có chữ cái nào ngoài ASCII (không dấu, không *đ*) — gõ không dấu hoàn toàn. Chỉ khi ấy mới nhận chữ số
/// chữ / giới từ dạng không dấu (*"từ"* bỏ dấu là *tu* = *tư*, *"sáu"* và *"sau"* trùng nhau).
bool _cauKhongDau(String s) => !_chuCaiNgoaiAscii.hasMatch(s);

const Set<String> _chuThatKhongDau = {'sau', 'nam', 'bay'};

/// Chữ số viết bằng CHỮ ngay sau [kt] (*"một triệu **hai**"*) — [b] là câu đã bỏ dấu. Câu có dấu thì xét CÓ DẤU trên
/// [s]: bỏ dấu thì *"từ"* thành `tu` = *tư* (số 4) và *"chuyển năm trăm nghìn **từ** MB Bank"* từng bị coi là *"năm
/// trăm nghìn tư"* → "chưa rõ", không điền (spike C4 câu 19). [cauKhongDau] (cả câu không dấu, *"mot trieu hai"*)
/// thì nhận.
///
/// BA trạng thái: **chữ số** (`moHo` false: từ có dấu thuộc [chuSoDonCoDau] của `so_bang_chu.dart`, hoặc cả câu không
/// dấu), **mơ hồ** (`moHo`
/// true: câu có dấu mà từ ấy toàn ASCII và bỏ dấu là chữ số — *"một triệu tu"*: người gõ thiếu dấu hay đó là chữ
/// khác?), **không** (`null`: từ có dấu khác hẳn, *"từ"*; hoặc [_chuThatKhongDau] — *sau · nam · bay* không dấu là chữ
/// thật). Luật không đoán ca mơ hồ (chưa rõ như trước C4); [cachDocSoTien] vẫn liệt kê để Gemma chọn.
({int giaTri, int ketThuc, bool moHo})? _chuSoChuSau(String s, String b, int kt, {required bool cauKhongDau}) {
  final m = _sauLaChuSoChu.firstMatch(b.substring(kt));
  if (m == null) return null;
  final ketThuc = kt + m.end;
  final goc = unorm.nfc(s.substring(ketThuc - m.group(1)!.length, ketThuc).toLowerCase());
  final giaTri = _chuSoChu[m.group(1)]!;
  if (cauKhongDau || chuSoDonCoDau.contains(goc)) return (giaTri: giaTri, ketThuc: ketThuc, moHo: false);
  // sau · nam · bay viết không dấu trong câu có dấu là CHỮ THẬT (sau đó, Nam, bay), không phải chữ số gõ thiếu dấu.
  if (_chiAscii.hasMatch(goc) && !_chuThatKhongDau.contains(goc)) return (giaTri: giaTri, ketThuc: ketThuc, moHo: true);
  return null;
}

const Set<String> _sauSoTienCoDau = {
  'bằng', 'trả', 'qua', 'từ', 'sang', 'vào', 'hôm', 'ngày', 'mùng', 'mồng', 'thứ', 'ví', 'đến', 'tới', //
};
const Set<String> _sauSoTienKhongDau = {
  'bang', 'tra', 'qua', 'tu', 'sang', 'vao', 'hom', 'ngay', 'mung', 'mong', 'thu', 'vi', 'den', 'toi', //
};
const Set<String> _sauSoTienLaMocNgay = {'ngày', 'ngay', 'mùng', 'mung', 'mồng', 'mong'};
const Set<String> _sauSoTienLaHom = {'hôm', 'hom'};
const Set<String> _sauSoTienLaThu = {'thứ', 'thu'};

/// Chữ liền sau *hôm* làm nó thành mốc ngày (*hôm qua · nay · kia*). Tập riêng, không dùng lại `_sauHom` của
/// `ngay_trong_cau.dart` (riêng tư ở đó, và có *trước · nọ · bữa* nhưng không có *nay*): *"hai triệu ba hôm sau / hôm
/// trước"* là ba hôm, không phải 2,3 triệu.
const Set<String> _sauHomLaNgay = {'qua', 'nay', 'kia'};

/// Thứ trong tuần sau *thứ*: chữ số, hoặc *hai · ba · tư · năm · sáu · bảy*, *chủ nhật*, *cn* (dấu theo câu).
const Set<String> _sauThuCoDau = {'hai', 'ba', 'tư', 'năm', 'sáu', 'bảy', 'chủ', 'cn'};
const Set<String> _sauThuKhongDau = {'hai', 'ba', 'tu', 'nam', 'sau', 'bay', 'chu', 'cn'};
final RegExp _dauCauSau = RegExp(r'^\s*[,.;!?]');
final RegExp _sauBatDauBangSo = RegExp(r'^\s*\d');

/// Vị trí [kt] (cuối cụm Y của một dạng nói, C4) có phải CHỖ CỦA TIỀN không: hết câu, dấu câu, hoặc chữ liền sau
/// thuộc tập *đứng sau tiền* (ví · bằng · trả · qua · từ · sang · vào · đến · tới · hôm · ngày · mùng · thứ). Phép
/// chọn của LUẬT cho dạng nói (N1 *X đơn vị Y*, N2 số 10–999 × 1.000) chỉ áp ở đây — *"hai triệu năm nay"*, *"một triệu
/// hai tiền sách"* thì Y là chữ khác của câu. ⚠️ *ngày / mùng / mồng* chỉ tính khi liền sau là chữ SỐ (*"ngày 5"*),
/// *hôm* chỉ trước *qua · nay · kia*, *thứ* chỉ trước chữ số / tên thứ: *"hai triệu ba ngày sau"*, *"hai triệu ba hôm
/// sau"*, *"hai triệu ba thứ đồ"* không phải 2,3 triệu. Chữ không dấu ([_sauSoTienKhongDau]) chỉ khi [cauKhongDau];
/// câu có dấu so CÓ DẤU.
/// [b] là câu bỏ dấu (cùng độ dài [s]). Không dùng cho [cachDocSoTien] — nó liệt kê MỌI cách đọc để Gemma còn chọn.
bool _dungChoTien(String s, String b, int kt, {required bool cauKhongDau}) {
  final sau = b.substring(kt);
  if (sau.trim().isEmpty || _dauCauSau.hasMatch(sau)) return true;
  final m = _tu.firstMatch(s.substring(kt));
  if (m == null || s.substring(kt, kt + m.start).trim().isNotEmpty) return false;
  final tu = unorm.nfc(m.group(0)!.toLowerCase());
  final trongTap = cauKhongDau ? _sauSoTienKhongDau.contains(tu) : _sauSoTienCoDau.contains(tu);
  if (!trongTap) return false;
  final conLai = s.substring(kt + m.end);
  if (_sauSoTienLaMocNgay.contains(tu)) return _sauBatDauBangSo.hasMatch(conLai);
  final tiep = _tu.firstMatch(conLai);
  final tuTiep = tiep == null || conLai.substring(0, tiep.start).trim().isNotEmpty
      ? null
      : unorm.nfc(tiep.group(0)!.toLowerCase());
  if (_sauSoTienLaHom.contains(tu)) return tuTiep != null && _sauHomLaNgay.contains(tuTiep);
  if (_sauSoTienLaThu.contains(tu)) {
    return _sauBatDauBangSo.hasMatch(conLai) ||
        (tuTiep != null && (cauKhongDau ? _sauThuKhongDau : _sauThuCoDau).contains(tuTiep));
  }
  return true;
}

const Map<String, double> _giaTriDonVi = {
  'trieu': 1000000,
  'tr': 1000000,
  'cu': 1000000,
  'nghin': 1000,
  'ngan': 1000,
  'k': 1000,
  'lit': 100000,
  'xi': 100000,
  'ty': 1000000000,
  'ti': 1000000000,
};

const Set<String> _donViTy = {'ty', 'ti'};
const Set<String> _chuTyHopLe = {'tỷ', 'tỉ', 'ty', 'ti'};

/// Đơn vị của cụm [m] (khớp trên chữ bỏ dấu) có đúng là nó trên câu gốc [s] không. Chỉ *tỷ / tỉ* cần xét: dạng bỏ dấu
/// `ti` trùng với *tí* (*"mua 2 tí kẹo"*), *tì*, *tị*. Người gõ không dấu viết `ty` / `ti` trần thì nhận.
bool _donViDungDau(String s, RegExpMatch m, String dv) {
  if (!_donViTy.contains(dv)) return true;
  final chu = _tu.firstMatch(s.substring(m.start, m.end).toLowerCase())?.group(0);
  return _chuTyHopLe.contains(chu);
}

/// Phần lẻ dính liền sau đơn vị (`1tr2` = 1,2 triệu; `1ty25` = 1,25 tỷ): [le] chữ số đọc là phần thập phân của đơn vị.
double _phanLe(String le, double donVi) => int.parse(le) * donVi / const [1, 10, 100, 1000][le.length];

/// Chữ đứng ngay trước số tiền mà không mang nghĩa gì cho ghi chú (*"ăn phở hết 45k"*). ⚠️ `mat` không dấu cố ý vắng:
/// đó còn là *mặt* của *"tiền mặt"*.
const Set<String> _tuDemTruocTien = {'hết', 'mất', 'tốn', 'het', 'ton'};

KetQuaDocCau docCauGiaoDich(
  String cau, {
  required DateTime now,
  required List<Wallet> vi,
  required List<Category> chonDuoc,
  BoPhanLoaiGhiChu? mo,
  Set<(String, String)> tatCap = const {},
  KetQuaAi? ai,
  Map<String, List<String>> tuKhoa = const {},
  String chieuDangChon = 'chi',
  String? viDangChon,
}) {
  final s = unorm.nfc(cau);
  final thuong = s.toLowerCase();
  final b = removeVietnameseTones(thuong);
  // Bỏ dấu giữ độ dài với câu dựng sẵn; khác đi (ký tự lạ) thì vị trí không tin được — không đọc gì.
  if (b.length != s.length) return KetQuaDocCau(ghiChu: cau.trim());

  final canhBao = <String>[];
  final daDung = <_Khoang>[];

  // Ngày.
  final ng = timNgayTrongCau(s, now);
  if (ng != null) daDung.add((batDau: ng.batDau, ketThuc: ng.ketThuc));

  // Số tiền.
  final tien = _chonSoTien(s, b, ngay: ng, canhBao: canhBao);
  double? soTien;
  var soTienCanKiem = false;
  if (tien != null) {
    if (tien.giaTri >= 1e13) {
      canhBao.add(kCanhBaoSoTienQuaLon);
    } else if (!(tien.giaTri > 0)) {
      canhBao.add(kCanhBaoSoTienKhongHopLe);
    } else {
      soTien = tien.giaTri.roundToDouble();
      soTienCanKiem = tien.noi;
      daDung.add(_moRongCumTien(thuong, b, tien));
    }
  }

  // Chuyển ví (§2.9, người dùng báo 2026-09-30) trước — câu chuyển nêu HAI ví, luật một ví bên dưới lấy nhầm ví đích.
  final dsVi = [for (final w in vi) if (!w.isDeleted) w];
  final nhac = _viNhacTrongCau(s, b, dsVi, daDung);
  String? walletId;
  String? walletToId;
  final chuyen = _docChuyenVi(thuong, nhac);
  if (chuyen != null) {
    walletId = chuyen.nguon?.id;
    walletToId = chuyen.dich.id;
    daDung.addAll(chuyen.khoang);
  } else {
    // Ví (§2.4): tên ví nêu trong câu; không có thì "tiền mặt" → ví tiền mặt duy nhất.
    final tenVi = timTenTrongCau(s, [for (final w in dsVi) w.name], tuLoai: 'ví');
    if (tenVi != null && !_vanVoiViThanhVi(thuong, tenVi)) {
      final trung = _cungTen(dsVi, tenVi.ten, (w) => w.name);
      if (trung.length == 1) {
        walletId = trung.single.id;
        daDung.add(_moRongTruocVi(thuong, tenVi.batDau, tenVi.ketThuc));
      }
    } else if (_tenGoiViTrongCau(thuong, _boKhoang(b, daDung), dsVi) case [final g, ...]) {
      walletId = g.vi.id;
      daDung.add(_moRongTruocVi(thuong, g.batDau, g.ketThuc));
    } else {
      final m = _mauTienMat.firstMatch(b);
      final tienMat = [for (final w in dsVi) if (w.type == 'cash') w];
      if (m != null && tienMat.length == 1) {
        walletId = tienMat.single.id;
        daDung.add(_moRongTruocVi(thuong, m.start, m.end));
      }
    }
  }

  var loai = chuyen != null ? 'transfer' : _loaiCua(_boKhoang(thuong, daDung));
  var ghiChu = _ghiChuTu(s, daDung);
  // Đoán danh mục trên ghi chú của LUẬT (câu đã bỏ tiền, ngày, ví) — ghi chú AI có thể đã bớt chữ.
  final ghiChuLuat = ghiChu;
  var ngay = ng?.ngay;

  // §2.8 — ô của AI qua kiểm của luật. ĐỔI LẦN HAI (người dùng chốt 2026-09-30): luật trước — AI chỉ LẤP ô luật để
  // trống, luật đọc được thì luật thắng (kể cả số tiền, kể cả khi số của AI là một cách đọc hợp lệ).
  var aiLap = false;
  if (ai != null) {
    final st = soTienAiHopLe(cau, ai, now: now);
    if (soTien == null && st != null) {
      soTien = st;
      canhBao.removeWhere((c) => c != kCanhBaoNhieuSoTien);
      aiLap = true;
    }
    if (ngay == null) {
      ngay = _ngayAiHopLe(ai.ngay, thuong, now);
      if (ngay != null) aiLap = true;
    }
    if (walletId == null && ai.vi != null) {
      final k = khopTheoTen(ai.vi!, dsVi, (w) => w.name);
      if (k is KhopMot<Wallet> && _cauNhacVi(thuong, k.muc)) {
        walletId = k.muc.id;
        if (k.muc.id != viDangChon) aiLap = true;
      }
    }
    if (loai == null && !_coVayNo(thuong)) {
      if (ai.loai == 'transfer') {
        // Ví đích phải là ví câu NÊU (tên hoặc viết tắt) — chữ "ví" / "thẻ" trần không đủ — và khác ví nguồn.
        final k = ai.viDen == null ? null : khopTheoTen(ai.viDen!, dsVi, (w) => w.name);
        if (k is KhopMot<Wallet> &&
            k.muc.id != walletId &&
            (nhac.any((x) => x.vi.id == k.muc.id) || _vietTatTenVi(thuong, k.muc.name))) {
          loai = 'transfer';
          walletToId = k.muc.id;
          aiLap = true;
        }
      } else if (ai.loai != null) {
        loai = ai.loai;
        if (ai.loai != chieuDangChon) aiLap = true;
      }
    }
    final gc = ai.ghiChu;
    if (gc != null && gc != ghiChu) {
      final cho = amTietCua(ghiChu).toSet();
      final cua = amTietCua(gc);
      if (cua.isNotEmpty && cua.every(cho.contains)) {
        ghiChu = gc;
        aiLap = true;
      }
    }
  }

  // Danh mục (§2.5): câu nói rõ chiều thì chỉ danh mục hợp chiều (C1 `hopLeTheoChieu`); không nói thì mọi danh mục chọn
  // được — cùng nếp thẻ gợi ý của màn Thêm giao dịch, nơi danh mục kéo đoạn Chi/Thu theo.
  // Chuyển ví không có danh mục (màn bỏ ô ấy ở đoạn Chuyển khoản) — tập hợp lệ rỗng làm cả bốn bước dưới im.
  final hopLe = loai == 'transfer'
      ? <String>{}
      : loai != null
          ? hopLeTheoChieu(loai, chonDuoc)
          : {for (final c in chonDuoc) if (!c.isDeleted && !c.isGroup) c.id};
  final dsHopLe = [for (final c in chonDuoc) if (hopLe.contains(c.id)) c];
  // Tìm tên trên câu đã bỏ đoạn ví: "45k ví Tiết kiệm" không được đọc thành danh mục "Tiết kiệm".
  final dm = doanDanhMucTuGhiChu(
    cauTimTen: _boKhoang(s, daDung),
    ghiChu: ghiChuLuat,
    chonDuoc: dsHopLe,
    mo: mo,
    tatCap: tatCap,
    tuKhoa: tuKhoa,
  );
  var categoryId = dm.categoryId;
  final doan = dm.doan;
  final lyDo = dm.lyDo;
  final goiY = dm.goiY;
  // AI là bước cuối, chỉ khi câu không nêu tên danh mục nào và B1 / từ khoá đều im.
  if (!dm.thayTen && categoryId == null && ai?.danhMuc != null) {
    final k = khopTheoTen(ai!.danhMuc!, dsHopLe, (c) => c.name);
    if (k is KhopMot<Category>) {
      categoryId = k.muc.id;
      aiLap = true;
    }
  }

  // Ô câu CÓ NHẮC mà (sau khi AI lấp, nếu có) vẫn chưa đọc được — màn chỉ gọi mô hình khi tập này khác rỗng.
  final oThieu = {
    if (soTien == null && cachDocSoTien(cau, now: now).isNotEmpty) OThieu.soTien,
    if (ngay == null && cauNhacNgay(thuong)) OThieu.ngay,
    // Xét trên câu đã bỏ các đoạn đã dùng: chữ "ví" của "sang ví Tiết kiệm" thuộc ví đích, không nhắc ví nguồn.
    if (walletId == null && dsVi.any((w) => _cauNhacVi(_boKhoang(thuong, daDung), w))) OThieu.vi,
    // Người dùng 2026-09-30: "chỗ nào không điền được thì cho AI điền" — kể cả danh mục, khi còn chữ để đoán.
    if (categoryId == null && dsHopLe.isNotEmpty && ghiChuLuat.isNotEmpty) OThieu.danhMuc,
    // Người dùng 2026-09-30: ghi chú còn sót số tiền luật không dùng ("mất ba chục", "grab 50k") thì nhờ AI dọn — AI vẫn
    // chỉ được BỚT chữ; ghi chú trống thì không (không có chữ để điền mà không bịa).
    if (cachDocSoTien(ghiChu, now: now).isNotEmpty) OThieu.ghiChu,
  };

  return KetQuaDocCau(
    oThieu: oThieu,
    soTien: soTien,
    loai: loai,
    ngay: ngay,
    walletId: walletId,
    walletToId: walletToId,
    categoryId: categoryId,
    doan: doan,
    lyDoDanhMuc: lyDo,
    goiY: goiY,
    ghiChu: ghiChu,
    canhBao: canhBao,
    quaAi: aiLap,
    soTienCanKiem: soTienCanKiem,
  );
}

/// Danh mục đoán từ ghi chú — bước danh mục của [docCauGiaoDich] không kể AI (§2.5, người dùng chốt 2026-09-30):
/// **tên** danh mục nêu trong [cauTimTen] → **B1** ([mo]) khi nó chắc → **từ khoá** của danh mục. [chonDuoc] là các
/// danh mục ĐÃ lọc hợp chiều. Tách ra (D1, 2026-09-30) để form điền sẵn từ tin biến động số dư đoán danh mục trên nội
/// dung tin bằng ĐÚNG luật này — cho nội dung tin đi qua cả [docCauGiaoDich] là đọc số tài khoản / ngày trong tin
/// thành số tiền / ngày.
///
/// `thayTen`: câu có nêu một tên danh mục (kể cả khi nhiều danh mục trùng tên nên không chọn được) — khi ấy người gọi
/// không hỏi thêm AI.
({String? categoryId, DoanDanhMuc? doan, String? lyDo, CategorySuggestion? goiY, bool thayTen}) doanDanhMucTuGhiChu({
  required String cauTimTen,
  required String ghiChu,
  required List<Category> chonDuoc,
  BoPhanLoaiGhiChu? mo,
  Set<(String, String)> tatCap = const {},
  Map<String, List<String>> tuKhoa = const {},
}) {
  final tenDm = timTenTrongCau(cauTimTen, [for (final c in chonDuoc) c.name], tuLoai: 'danh mục');
  if (tenDm != null) {
    final trung = _cungTen(chonDuoc, tenDm.ten, (c) => c.name);
    return (
      categoryId: trung.length == 1 ? trung.single.id : null,
      doan: null,
      lyDo: null,
      goiY: null,
      thayTen: true,
    );
  }
  // Thứ tự (người dùng chốt 2026-09-30): B1 khi nó chắc → từ khoá của danh mục → AI. Cùng thứ tự thẻ gợi ý trên màn
  // (B1 trước từ khoá): thói quen riêng, rồi điều người dùng tự khai báo, rồi mới tới hiểu biết chung của mô hình.
  final hopLe = {for (final c in chonDuoc) c.id};
  final d = mo?.doan(ghiChu, hopLe: hopLe, tatCap: tatCap);
  if (d != null) {
    final c = chonDuoc.firstWhere((c) => c.id == d.categoryId);
    final lyDo = cauLyDoHoc(d, ghiChuGoc: ghiChu, tenDanhMuc: c.name);
    return (
      categoryId: d.categoryId,
      doan: d,
      lyDo: lyDo,
      goiY: CategorySuggestion(
        category: c,
        matchedKeyword: d.cumBoDau,
        nguon: kNguonGoiYHoc,
        amTietChinh: d.cumBoDau,
        lyDo: lyDo,
      ),
      thayTen: false,
    );
  }
  final tk = const CategorySuggestionEngine().suggest(
    rawText: ghiChu,
    candidates: [
      for (final c in chonDuoc)
        for (final k in tuKhoa[c.id] ?? const <String>[]) CategoryKeywordCandidate(category: c, keyword: k),
    ],
  );
  return (categoryId: tk?.categoryId, doan: null, lyDo: tk?.lyDo, goiY: tk, thayTen: false);
}

/// Số tiền của AI qua lưới §2.8: dưới 13 chữ số và là MỘT cách đọc có trong câu ([cachDocSoTien]). Một định nghĩa — bước
/// lấp ô của [docCauGiaoDich] và phép kiểm chéo của C4 (spec 2026-10-12 §3.4) cùng gọi.
double? soTienAiHopLe(String cau, KetQuaAi? ai, {required DateTime now}) {
  final st = ai?.soTien;
  if (st == null || st >= 1e13) return null;
  return cachDocSoTien(cau, now: now).any((v) => (v - st).abs() <= 0.5) ? st.roundToDouble() : null;
}

/// Mọi CÁCH ĐỌC hợp lệ (≥ 1.000 đ, dưới 13 chữ số) của các con số có trong [cau] — lưới kiểm số tiền của AI (§2.8). AI
/// được CHỌN một cách đọc; số nào không nằm đây là số AI tự đặt ra, bị bỏ.
///
/// Gồm: mọi cụm luật thấy, kể cả cụm luật không chọn (lít / xị, số thứ hai); số trần `n` → `n`, và `n × 1.000` khi
/// `10 ≤ n < 1.000` (*"ăn phở 45"*; số một chữ số là số lượng: *"2 ly"*); số chữ không đơn vị có hàng chục → × 1.000
/// (*"ba chục"* = 30.000); *"X triệu Y"* / *"X tr Y"* / *"một triệu hai"* → X,Y triệu — bất kể vị trí của Y (luật chỉ CHỌN
/// cách đọc này khi Y ở chỗ của tiền, [_dungChoTien]; ở chỗ khác Gemma mới chọn); *"2k5"* → 2.500.
Set<double> cachDocSoTien(String cau, {required DateTime now}) {
  final s = unorm.nfc(cau);
  final b = removeVietnameseTones(s.toLowerCase());
  if (b.length != s.length) return const {};
  final kd = _cauKhongDau(s);
  final ng = timNgayTrongCau(s, now);
  bool trungNgay(int bd, int kt) => ng != null && bd < ng.ketThuc && kt > ng.batDau;
  final kq = <double>{};
  final daPhu = <_Khoang>[];

  for (final m in _mauSoDonVi.allMatches(b)) {
    if (trungNgay(m.start, m.end)) continue;
    final dv = m.group(2)!;
    if (!_donViDungDau(s, m, dv)) continue;
    final le = m.group(3);
    var gt = double.parse(m.group(1)!.replaceAll(',', '.')) * _giaTriDonVi[dv]!;
    if (le != null) {
      if (dv == 'tr' || _donViTy.contains(dv)) {
        gt += _phanLe(le, _giaTriDonVi[dv]!);
      } else if (dv == 'k' && le.length == 1) {
        gt += int.parse(le) * 100;
      } else {
        continue;
      }
    }
    kq.add(gt);
    daPhu.add((batDau: m.start, ketThuc: m.end));
  }

  for (final m in _mauTrieuLe.allMatches(b)) {
    final dv = m.group(2)!;
    if (trungNgay(m.start, m.end) || !_donViDungDau(s, m, dv)) continue;
    final donVi = _giaTriDonVi[dv]!;
    kq.add(int.parse(m.group(1)!) * donVi + int.parse(m.group(3)!) * donVi / 10);
    daPhu.add((batDau: m.start, ketThuc: m.end));
  }

  for (final m in _mauSoTran.allMatches(b)) {
    if (trungNgay(m.start, m.end) || daPhu.any((k) => m.start < k.ketThuc && m.end > k.batDau)) continue;
    final chuSo = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    if (chuSo.length >= 2 && chuSo.startsWith('0')) continue;
    if (_truocLaNam.hasMatch(b.substring(0, m.start))) continue;
    final n = double.parse(chuSo);
    if (n <= 31 && _truocLaMocLich.hasMatch(b.substring(0, m.start))) continue; // "tháng 10", "ngày 15"
    kq.add(n);
    if (n >= 10 && n < 1000) kq.add(n * 1000);
  }

  for (final c in timSoBangChu(s)) {
    if (c.giaTri.isNaN || trungNgay(c.batDau, c.ketThuc)) continue;
    kq.add(c.giaTri);
    final sau = _chuSoChuSau(s, b, c.ketThuc, cauKhongDau: kd);
    final bac = _bacCuoi.firstMatch(b.substring(c.batDau, c.ketThuc))?.group(1);
    if (sau != null && bac != null) {
      kq.add(c.giaTri + sau.giaTri * _giaTriBac[bac]! / 10);
    }
  }
  for (final c in timSoBangChu(s, batBuocDonVi: false)) {
    if (c.giaTri.isNaN || trungNgay(c.batDau, c.ketThuc)) continue;
    if (c.giaTri <= 31 && _truocLaMocLich.hasMatch(b.substring(0, c.batDau))) continue; // "tháng mười"
    kq.add(c.giaTri);
    if (c.giaTri >= 10 && c.giaTri < 1000) kq.add(c.giaTri * 1000);
  }
  return {for (final v in kq) if (v >= 1000 && v < 1e13) v};
}

/// *"2 triệu 5"*, *"2 tr 5"*, *"2 củ 5"*, *"1 tỷ 2"* — một chữ số lẻ tách bằng dấu cách, không kèm đơn vị riêng.
final RegExp _mauTrieuLe = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d+)\s*(trieu|tr|cu|ty|ti)\s+(\d)(?![\p{L}\p{N}/])(?![.,]\d)(?!\s*(?:k|nghin|ngan|tr|trieu|cu|lit|xi|ty|ti)(?![a-z]))',
  unicode: true,
);
final RegExp _bacCuoi = RegExp(r'(nghin|ngan|trieu|ty|ti)\s*$');
const Map<String, double> _giaTriBac = {'nghin': 1e3, 'ngan': 1e3, 'trieu': 1e6, 'ty': 1e9, 'ti': 1e9};
const Map<String, int> _chuSoChu = {
  'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9, //
};

final RegExp _mauNgayAi = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

/// Ngày AI trả về (`dd/mm/yyyy`) khi qua kiểm (§2.8): có thật trên lịch, trong `[hôm nay − 366, hôm nay + 7]`, và câu
/// NHẮC một thời điểm ([cauNhacNgay] — cùng phép màn dùng để quyết có hỏi AI không; chữ lẻ *"tháng"* của *"vé tháng"*
/// không tính). Không qua → `null` (form giữ ngày của nó).
DateTime? _ngayAiHopLe(String? chu, String thuong, DateTime now) {
  final m = _mauNgayAi.firstMatch(chu?.trim() ?? '');
  if (m == null || !cauNhacNgay(thuong)) return null;
  final x = ngayHopLe(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  if (x == null) return null;
  final homNay = DateTime(now.year, now.month, now.day);
  final lech = x.difference(homNay).inDays;
  // Hôm nay = AI không biết ngày (Realme 2026-09-30: *"đầu tháng"* → hôm nay). Form mặc định đã là hôm nay; nhận nó chỉ
  // làm dòng tóm tắt tuyên bố *"Hôm nay"* — điều câu không nói.
  return lech > 7 || lech < -366 || lech == 0 ? null : x;
}

/// Câu có NHẮC ví [w] không (§2.8) — AI không được tự điền ví câu không nói tới (Realme 2026-09-30: 9/10 câu mô hình trả
/// ví mặc định). Nhắc = chữ *ví* trần (mọi ví); chữ chỉ thẻ / ngân hàng — *thẻ, quẹt, ck, chuyển khoản, atm* — chỉ với ví
/// NGÂN HÀNG (người dùng chốt sau lượt đo 3: *"quẹt thẻ ăn phở"* nhận ví Tiền mặt); hoặc một chữ ≥ 4 ký tự là **viết tắt**
/// (tiền tố thật sự ngắn hơn) của một từ trong tên [w] (*"techcom"* → *Techcombank*). Trùng nguyên một từ thường
/// (*"tiền"* của *Tiền mặt*) không tính — tên ví nêu trọn thì luật đã bắt trước.
///
/// ⚠️ Khớp TỪNG TỪ CÓ DẤU, như từ chỉ thu: bỏ dấu thì *"vì"* thành *vi*, *"thế"* thành *the* — *"vì đói nên ăn phở"* từng
/// là "câu nhắc ví" và, từ đổi lần hai, gọi AI oan ~18 s. Gõ không dấu (*vi, the, quet*) vẫn nhận.
bool _cauNhacVi(String thuong, Wallet w) {
  if (cauNhacViTheoTen(thuong, w.name)) return true;
  if (w.type != 'bank' && w.type != 'banking') return false;
  final tu = [for (final m in _tu.allMatches(thuong)) unorm.nfc(m.group(0)!)];
  for (var i = 0; i < tu.length; i++) {
    if (_chuNganHang.contains(tu[i])) return true;
    if (i + 1 < tu.length && _chuyenKhoan.contains('${tu[i]} ${tu[i + 1]}')) return true;
  }
  return false;
}

/// Hai vế KHÔNG cần loại ví của [_cauNhacVi]: chữ *ví* trần, hoặc viết tắt một từ trong [tenVi]. Mở công khai cho lệnh
/// tạo ở màn Trợ lý (C3 §8.3) — chỗ ấy chỉ có tên ví, và cũng không được nhận ví mô hình tự điền. [thuong] là câu đã
/// `toLowerCase()`, CÒN DẤU.
bool cauNhacViTheoTen(String thuong, String tenVi) =>
    _tu.allMatches(thuong).any((m) => _chuVi.contains(unorm.nfc(m.group(0)!))) || _vietTatTenVi(thuong, tenVi);

bool _vietTatTenVi(String thuong, String tenVi) {
  final tuVi = removeVietnameseTones(normalizeCategoryName(tenVi)).split(' ');
  return _tu
      .allMatches(thuong)
      .map((m) => removeVietnameseTones(unorm.nfc(m.group(0)!)))
      .any((t) => t.length >= 4 && tuVi.any((x) => x.length > t.length && x.startsWith(t)));
}

const Set<String> _chuVi = {'ví', 'vi'};
const Set<String> _chuNganHang = {'thẻ', 'the', 'quẹt', 'quet', 'ck', 'atm'};
const Set<String> _chuyenKhoan = {'chuyển khoản', 'chuyen khoan'};

final RegExp _mauTienMat = RegExp(r'(?<![a-z0-9])tien\s+mat(?![a-z0-9])');

/// Chữ đứng trước tên ví mà ghi chú bỏ luôn: *ví*, *bằng*, *bằng ví* (§2.7).
const Set<String> _tuTruocVi = {'ví', 'vi', 'bằng', 'bang'};

_Khoang _moRongTruocVi(String thuong, int batDau, int ketThuc) {
  var bd = batDau;
  for (var i = 0; i < 2; i++) {
    final truoc = _tuCuoi.firstMatch(thuong.substring(0, bd));
    if (truoc == null || !_tuTruocVi.contains(truoc.group(1))) break;
    bd = truoc.start;
  }
  return (batDau: bd, ketThuc: ketThuc);
}


typedef _ViNhac = ({Wallet vi, int batDau, int ketThuc});

/// Mọi ví câu NÊU, theo vị trí: tên ví (trùng đúng một ví), và *"tiền mặt"* → ví tiền mặt duy nhất khi không ví nào tên
/// như thế. Trên câu đã bỏ đoạn tiền / ngày.
List<_ViNhac> _viNhacTrongCau(String s, String b, List<Wallet> dsVi, List<_Khoang> daDung) {
  final kq = <_ViNhac>[];
  for (final t in timCacTenTrongCau(_boKhoang(s, daDung), [for (final w in dsVi) w.name], tuLoai: 'ví')) {
    if (_vanVoiViThanhVi(s.toLowerCase(), t)) continue;
    final trung = _cungTen(dsVi, t.ten, (w) => w.name);
    if (trung.length == 1) kq.add((vi: trung.single, batDau: t.batDau, ketThuc: t.ketThuc));
  }
  for (final g in _tenGoiViTrongCau(s.toLowerCase(), _boKhoang(b, daDung), dsVi)) {
    if (kq.any((k) => g.batDau < k.ketThuc && g.ketThuc > k.batDau)) continue;
    kq.add(g);
  }
  final tienMat = [for (final w in dsVi) if (w.type == 'cash') w];
  if (tienMat.length == 1) {
    for (final m in _mauTienMat.allMatches(b)) {
      if (kq.any((k) => m.start < k.ketThuc && m.end > k.batDau)) continue;
      kq.add((vi: tienMat.single, batDau: m.start, ketThuc: m.end));
    }
  }
  return kq..sort((x, y) => x.batDau.compareTo(y.batDau));
}

/// Chữ đứng ngay trước TÊN GỌI TẮT của ví (C4 §3.3, khối 🔧 ý 4), so CÓ DẤU khi câu có dấu: *"vì"* bỏ dấu là *vi* —
/// *"đi chơi vì MB Bank tặng voucher"* không nêu ví. Dạng không dấu chỉ khi CẢ CÂU không dấu ([_cauKhongDau]).
/// Cùng giới từ với [_sauSoTienCoDau] / [_sauSoTienKhongDau] nhưng vai khác: ở đó chữ đứng SAU số tiền, ở đây đứng
/// TRƯỚC tên ví (bỏ *hôm · ngày · mùng · mồng · thứ · trả*, thêm hai tập riêng — không dùng chung được).
const Set<String> _truocTenGoiViCoDau = {'ví', 'bằng', 'qua', 'từ', 'sang', 'vào', 'đến', 'tới'};
const Set<String> _truocTenGoiViKhongDau = {'vi', 'bang', 'qua', 'tu', 'sang', 'vao', 'den', 'toi'};

/// Tên gọi tắt của ví: tên bỏ chữ *Ví* đầu (*Ví MB Bank* → *mb bank*), đã chuẩn hoá. `null` khi tên không mở đầu bằng
/// *Ví*, hoặc phần còn lại dưới 3 ký tự (bỏ dấu, không khoảng trắng) — *"Ví A"* không được khớp mọi chữ *a*.
String? _tenGoiCuaVi(String ten) {
  final n = normalizeCategoryName(ten);
  if (!removeVietnameseTones(n).startsWith('vi ')) return null;
  final goi = n.substring(3).trim();
  return removeVietnameseTones(goi).replaceAll(' ', '').length >= 3 ? goi : null;
}

/// Mọi chỗ câu nêu TÊN GỌI TẮT của một ví, chỉ ngay sau [_truocTenGoiViCoDau] (đoạn trả về KHÔNG gồm giới từ, để
/// `_chuTruoc` của chuyển ví vẫn thấy *từ / sang*). Nhận ở mọi chỗ thì *"mua sách tiết kiệm"* chọn ví *Ví tiết kiệm*.
/// [thuong] là câu chữ thường CÒN DẤU (xét giới từ), [b] là câu bỏ dấu đã bỏ các đoạn đã dùng (tìm tên) — cùng độ dài.
List<_ViNhac> _tenGoiViTrongCau(String thuong, String b, List<Wallet> dsVi) {
  final tap = _cauKhongDau(thuong) ? _truocTenGoiViKhongDau : _truocTenGoiViCoDau;
  final kq = <_ViNhac>[];
  for (final w in dsVi) {
    final goi = _tenGoiCuaVi(w.name);
    if (goi == null) continue;
    final than = removeVietnameseTones(goi).split(' ').map(RegExp.escape).join(r'\s+');
    for (final m in RegExp('(?<![a-z0-9])$than(?![a-z0-9])').allMatches(b)) {
      final truoc = _tuCuoi.firstMatch(thuong.substring(0, m.start));
      if (truoc == null || !tap.contains(truoc.group(1))) continue;
      kq.add((vi: w, batDau: m.start, ketThuc: m.end));
    }
  }
  return kq..sort((x, y) => x.batDau.compareTo(y.batDau));
}

/// Tên ví đầy đủ khớp bỏ dấu nên *"vì MB Bank"* khớp *"Ví MB Bank"* — khi câu có dấu mà đoạn khớp mở bằng *vì* (không
/// phải *ví*) thì đó là lý do chứ không phải tên ví: bỏ.
bool _vanVoiViThanhVi(String thuong, TenTrongCau t) =>
    !_cauKhongDau(thuong) && thuong.substring(t.batDau, t.ketThuc).startsWith('vì ');

/// Chữ đứng ngay trước ví ở [bd] mà làm nó thành ví ĐÍCH / ví NGUỒN của một khoản chuyển (§2.9).
const Set<String> _gioiTuDich = {'sang', 'vào', 'vao', 'đến', 'den', 'tới'};
const Set<String> _gioiTuNguon = {'từ', 'tu'};

/// Chuyển giữa hai ví của người dùng (§2.9). Ví ĐÍCH = ví nêu ngay sau *sang · vào · đến · tới* (bỏ qua một chữ *ví*),
/// hoặc sau *qua* khi câu có động từ *chuyển* — *"trả qua Techcombank"*, *"chuyển khoản qua Techcombank"* là trả BẰNG
/// ví ấy. Không có giới từ thì *chuyển* + đúng hai ví khác nhau: trước là nguồn, sau là đích. Ví NGUỒN = ví sau *từ*,
/// không có thì ví còn lại khi chỉ còn đúng một; trùng ví đích thì bỏ (form giữ ví đang chọn). Không có ví đích →
/// không phải chuyển ví (*"chuyển khoản 500k cho mẹ"* vẫn là khoản chi).
({Wallet? nguon, Wallet dich, List<_Khoang> khoang})? _docChuyenVi(String thuong, List<_ViNhac> nhac) {
  if (nhac.isEmpty) return null;
  final dongTu = _dongTuChuyen(thuong);
  _ViNhac? dich;
  _Khoang? kDich;
  _ViNhac? tu;
  _Khoang? kTu;
  for (final x in nhac) {
    final t = _chuTruoc(thuong, x.batDau);
    if (t == null) continue;
    if (dich == null && (_gioiTuDich.contains(t.chu) || (dongTu != null && t.chu == 'qua'))) {
      dich = x;
      kDich = (batDau: t.batDau, ketThuc: x.ketThuc);
    } else if (tu == null && _gioiTuNguon.contains(t.chu)) {
      tu = x;
      kTu = (batDau: t.batDau, ketThuc: x.ketThuc);
    }
  }
  _Khoang khoangCua(_ViNhac x) => identical(x, tu) ? kTu! : _moRongTruocVi(thuong, x.batDau, x.ketThuc);

  if (dich == null) {
    if (dongTu == null || nhac.length != 2 || nhac[0].vi.id == nhac[1].vi.id) return null;
    return (nguon: nhac[0].vi, dich: nhac[1].vi, khoang: [khoangCua(nhac[0]), khoangCua(nhac[1]), dongTu]);
  }
  final d = dich;
  final nguonNhac = tu ?? (nhac.length == 2 ? nhac.firstWhere((x) => !identical(x, d)) : null);
  return (
    nguon: nguonNhac == null || nguonNhac.vi.id == d.vi.id ? null : nguonNhac.vi,
    dich: d.vi,
    khoang: [kDich!, if (nguonNhac != null) khoangCua(nguonNhac), if (dongTu != null) dongTu],
  );
}

/// Động từ *chuyển* (kèm *tiền* ngay sau) — không tính *chuyển khoản* (đó là CÁCH trả tiền). Đoạn trả về để ghi chú bỏ.
_Khoang? _dongTuChuyen(String thuong) {
  final tu = _tu.allMatches(thuong).toList();
  for (var i = 0; i < tu.length; i++) {
    if (removeVietnameseTones(unorm.nfc(tu[i].group(0)!)) != 'chuyen') continue;
    final ke = i + 1 < tu.length ? removeVietnameseTones(unorm.nfc(tu[i + 1].group(0)!)) : null;
    if (ke == 'khoan') continue;
    final kt = ke == 'tien' ? tu[i + 1].end : tu[i].end;
    return (batDau: tu[i].start, ketThuc: kt);
  }
  return null;
}

/// Chữ ngay trước [bd], bỏ qua một chữ *ví* (*"sang ví Tiết kiệm"*).
({String chu, int batDau})? _chuTruoc(String thuong, int bd) {
  var m = _tuCuoi.firstMatch(thuong.substring(0, bd));
  if (m != null && const {'ví', 'vi'}.contains(m.group(1))) {
    m = _tuCuoi.firstMatch(thuong.substring(0, m.start)) ?? m;
  }
  return m == null ? null : (chu: m.group(1)!, batDau: m.start);
}

List<T> _cungTen<T>(List<T> ds, String ten, String Function(T) tenCua) {
  final k = normalizeCategoryName(ten);
  return [for (final x in ds) if (normalizeCategoryName(tenCua(x)) == k) x];
}

/// Số tiền của [cau] theo ĐÚNG bộ chọn của ô Nhập nhanh (§2.1) kèm vị trí `[batDau, ketThuc)` trong câu đã NFC — C3 (lệnh
/// tạo ở màn Trợ lý AI) dùng lại, một định nghĩa. `null` khi không đọc được, số không dương, hoặc ≥ 13 chữ số.
({int batDau, int ketThuc, double giaTri})? chonSoTienTrongCau(String cau, {required DateTime now}) {
  final s = unorm.nfc(cau);
  final b = removeVietnameseTones(s.toLowerCase());
  if (b.length != s.length) return null;
  final c = _chonSoTien(s, b, ngay: timNgayTrongCau(s, now), canhBao: <String>[]);
  if (c == null || !(c.giaTri > 0) || c.giaTri >= 1e13) return null;
  return (batDau: c.batDau, ketThuc: c.ketThuc, giaTri: c.giaTri.roundToDouble());
}

/// Cụm số tiền được chọn (§2.1), hoặc `null`. Hạng ưu tiên: *k / nghìn / tr / củ*, số chữ, số trần ≥ 1.000 trước;
/// dạng nói mới học (N1 — C4) sau; *lít / xị* cuối (*"đổ 2 lít xăng 50k"* → 50.000). Lấy cụm đầu của hạng thắng; cảnh
/// báo nhiều số tiền khi có ≥ 2 cụm chắc + nói (khác hạng cũng tính), hoặc ≥ 2 cụm lít / xị khi chỉ có chúng.
_CumTien? _chonSoTien(
  String s,
  String b, {
  required NgayTrongCau? ngay,
  required List<String> canhBao,
}) {
  final cum = <_CumTien>[];
  final kd = _cauKhongDau(s);
  bool trungNgay(int bd, int kt) => ngay != null && bd < ngay.ketThuc && kt > ngay.batDau;

  // N1 (C4) dạng chữ số: "1 triệu 2" = 1.200.000 — cùng phép của `cachDocSoTien`, CHỈ khi Y ở chỗ của tiền. Đứng TRƯỚC
  // `_mauSoDonVi`: mẫu ấy khớp "1 triệu" rồi bỏ số 2 (lỗi sẵn có tới 2026-10-12). Y ở chỗ khác ("2 triệu 3 ngày sau") thì
  // không thêm cụm — `_mauSoDonVi` đọc "2 triệu" như trước.
  for (final m in _mauTrieuLe.allMatches(b)) {
    final dv = m.group(2)!;
    if (trungNgay(m.start, m.end) || !_donViDungDau(s, m, dv) || !_dungChoTien(s, b, m.end, cauKhongDau: kd)) continue;
    final donVi = _giaTriDonVi[dv]!;
    cum.add((
      batDau: m.start,
      ketThuc: m.end,
      giaTri: int.parse(m.group(1)!) * donVi + int.parse(m.group(3)!) * donVi / 10,
      lit: false,
      noi: true,
    ));
  }

  for (final m in _mauSoDonVi.allMatches(b)) {
    if (cum.any((c) => m.start < c.ketThuc && m.end > c.batDau)) continue;
    final dv = m.group(2)!;
    if (!_donViDungDau(s, m, dv)) continue;
    final le = m.group(3);
    if (le != null && dv != 'tr' && !_donViTy.contains(dv)) continue; // "2k5" — không chắc thì không đọc
    var gt = double.parse(m.group(1)!.replaceAll(',', '.')) * _giaTriDonVi[dv]!;
    if (le != null) gt += _phanLe(le, _giaTriDonVi[dv]!);
    if (trungNgay(m.start, m.end)) continue;
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: dv == 'lit' || dv == 'xi', noi: false));
  }

  for (final m in _mauSoTran.allMatches(b)) {
    if (cum.any((c) => m.start < c.ketThuc && m.end > c.batDau) || trungNgay(m.start, m.end)) continue;
    final chuSo = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    if (chuSo.length >= 2 && chuSo.startsWith('0')) continue; // số điện thoại, mã
    if (_truocLaNam.hasMatch(b.substring(0, m.start))) continue; // "năm 2026"
    final gt = double.parse(chuSo);
    if (gt < 1000) {
      // N2 (C4): "đổ xăng 50", "sửa xe 350" → × 1.000. Không khi có "đồng" (người nói nói rõ đơn vị), số đứng sau
      // tháng / ngày / mùng / mồng (mốc lịch), hay đứng trước danh từ khác ("2 ly", "15 phút") — chỉ ở chỗ của tiền ([_dungChoTien]).
      final coDong = m.group(0)!.length > m.group(1)!.length;
      if (gt >= 10 &&
          !coDong &&
          !_truocLaMocLich.hasMatch(b.substring(0, m.start)) &&
          _dungChoTien(s, b, m.end, cauKhongDau: kd)) {
        cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt * 1000, lit: false, noi: true));
      }
      continue;
    }
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: false, noi: false));
  }

  var chuaRo = false;
  for (final c in timSoBangChu(s)) {
    if (trungNgay(c.batDau, c.ketThuc)) continue;
    if (c.giaTri.isNaN) {
      chuaRo = true;
      continue;
    }
    final sau = _chuSoChuSau(s, b, c.ketThuc, cauKhongDau: kd);
    if (sau != null) {
      // "một triệu hai" = 1.200.000 hay 1.000.000 rồi chữ khác? N1 (C4): luật CHỌN 1.200.000 khi Y ở chỗ của tiền
      // (cần kiểm chéo); ở chỗ khác ("hai triệu năm nay") không chắc thì không đọc.
      final bac = _bacCuoi.firstMatch(b.substring(c.batDau, c.ketThuc))?.group(1);
      if (bac == null || sau.moHo || !_dungChoTien(s, b, sau.ketThuc, cauKhongDau: kd)) {
        chuaRo = true;
        continue;
      }
      cum.add((
        batDau: c.batDau,
        ketThuc: sau.ketThuc,
        giaTri: c.giaTri + sau.giaTri * _giaTriBac[bac]! / 10,
        lit: false,
        noi: true,
      ));
      continue;
    }
    if (c.giaTri < 1000) continue; // < 1.000: N2 ở vòng `batBuocDonVi: false` bên dưới ("ba trăm rưỡi" = 350 cũng ở đó)
    cum.add((batDau: c.batDau, ketThuc: c.ketThuc, giaTri: c.giaTri, lit: false, noi: false));
  }

  // N2 (C4): cụm số chữ KHÔNG đơn vị có hàng chục — "năm chục", "bốn mươi lăm" — cùng tập `cachDocSoTien` (× 1.000).
  for (final c in timSoBangChu(s, batBuocDonVi: false)) {
    if (c.giaTri.isNaN || c.giaTri < 10 || c.giaTri >= 1000 || trungNgay(c.batDau, c.ketThuc)) continue;
    if (cum.any((x) => c.batDau < x.ketThuc && c.ketThuc > x.batDau)) continue;
    if (_truocLaMocLich.hasMatch(b.substring(0, c.batDau)) || !_dungChoTien(s, b, c.ketThuc, cauKhongDau: kd)) continue;
    cum.add((batDau: c.batDau, ketThuc: c.ketThuc, giaTri: c.giaTri * 1000, lit: false, noi: true));
  }

  cum.sort((x, y) => x.batDau.compareTo(y.batDau));
  final chac = [for (final c in cum) if (!c.lit && !c.noi) c];
  final noi = [for (final c in cum) if (!c.lit && c.noi) c];
  final hang = chac.isNotEmpty
      ? chac
      : noi.isNotEmpty
          ? noi
          : [for (final c in cum) if (c.lit) c];
  if (hang.isEmpty) {
    if (chuaRo) canhBao.add(kCanhBaoSoChuChuaRo);
    return null;
  }
  // Đếm cả cụm chắc lẫn cụm nói (xếp hạng chỉ chọn một): "ăn phở 45k tiền điện 1 triệu 2" vẫn có nhiều số tiền.
  if ((chac.isNotEmpty || noi.isNotEmpty ? chac.length + noi.length : hang.length) >= 2) {
    canhBao.add(kCanhBaoNhieuSoTien);
  }
  return hang.first;
}

/// Đoạn ghi chú bỏ cho số tiền: cụm, cộng *"đồng"* ngay sau, cộng *"hết / mất / tốn"* ngay trước.
_Khoang _moRongCumTien(String thuong, String b, _CumTien c) {
  var bd = c.batDau;
  var kt = c.ketThuc;
  final sau = _sauLaDonViTien.firstMatch(b.substring(kt));
  if (sau != null) kt += sau.end;
  final truoc = _tuCuoi.firstMatch(thuong.substring(0, bd));
  if (truoc != null && _tuDemTruocTien.contains(truoc.group(1))) bd = truoc.start;
  return (batDau: bd, ketThuc: kt);
}

/// [s] với mọi [khoang] thay bằng khoảng trắng cùng độ dài — giữ vị trí.
String _boKhoang(String s, List<_Khoang> khoang) {
  final c = s.split('');
  for (final k in khoang) {
    for (var i = k.batDau; i < k.ketThuc && i < c.length; i++) {
      c[i] = ' ';
    }
  }
  return c.join();
}

String _ghiChuTu(String s, List<_Khoang> daDung) {
  var g = _boKhoang(s, daDung).replaceAll(RegExp(r'\s+'), ' ');
  g = g.replaceAllMapped(RegExp(r' ([,.;:!?])'), (m) => m[1]!);
  g = g.replaceAllMapped(RegExp(r'([,.;:])(?:[\s,.;:])*[,.;:]'), (m) => m[1]!);
  return g.replaceAll(RegExp(r'^[\s,.;:\-–]+|[\s,.;:\-–]+$'), '');
}

// §2.2 — từ chỉ THU. Khớp theo TỪNG TỪ, phân biệt dấu: bỏ dấu cả câu thì "bạn" thành "ban" (= bán), "lại" thành "lai"
// (= lãi), "bình thường" chứa "thuong" (= thưởng) — câu rất thường gặp "ăn với bạn 200k" sẽ thành khoản thu. Từ gõ
// KHÔNG dấu chỉ nhận những dạng không lẫn được.
const Set<String> _thuCoDau = {'lương', 'thưởng', 'thu', 'bán', 'lãi'};
const Set<String> _thuKhongDau = {'luong', 'thu'};
const Set<String> _thuHaiTu = {
  'được cho', 'được tặng', 'được biếu', 'được trả', 'được hoàn', 'hoàn tiền', 'hoàn trả', 'lì xì', //
  'duoc cho', 'duoc tang', 'duoc bieu', 'duoc tra', 'duoc hoan', 'hoan tien', 'hoan tra', 'li xi', 'tien thuong',
};

/// *nhận* là thu, trừ *nhận hàng / đồ / đơn / gói* (nhận hàng thường là trả tiền).
const Set<String> _sauNhanKhongPhaiThu = {'hàng', 'đồ', 'đơn', 'gói', 'hang', 'do', 'don', 'goi'};

/// Vay / nợ: chiều tiền đọc từ danh mục + ô *Chiều tiền*, không đoán từ câu. So bỏ dấu (bắt nhầm *"nó"* chỉ làm câu
/// không đặt loại — vô hại).
const Set<String> _vayNo = {'no', 'vay'};

bool _coVayNo(String thuong) =>
    _tu.allMatches(thuong).any((m) => _vayNo.contains(removeVietnameseTones(unorm.nfc(m.group(0)!))));

String? _loaiCua(String thuong) {
  final tu = [for (final m in _tu.allMatches(thuong)) unorm.nfc(m.group(0)!)];
  if (_coVayNo(thuong)) return null;
  for (var i = 0; i < tu.length; i++) {
    final t = tu[i];
    final ascii = _chiAscii.hasMatch(t);
    final ke = i + 1 < tu.length ? tu[i + 1] : null;
    if (ke != null && _thuHaiTu.contains('$t $ke')) return 'thu';
    if (ascii ? _thuKhongDau.contains(t) : _thuCoDau.contains(t)) return 'thu';
    if ((t == 'nhận' || t == 'nhan') && (ke == null || !_sauNhanKhongPhaiThu.contains(ke))) return 'thu';
  }
  return null;
}
