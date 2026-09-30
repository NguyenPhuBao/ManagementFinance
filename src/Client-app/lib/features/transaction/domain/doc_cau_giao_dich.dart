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

const String kCanhBaoNhieuSoTien = 'Câu có nhiều số tiền — mình chỉ điền khoản đầu.';
const String kCanhBaoSoTienQuaLon = 'Số tiền quá lớn — mình không điền.';
const String kCanhBaoSoTienKhongHopLe = 'Số tiền không hợp lệ — mình không điền.';
const String kCanhBaoSoChuChuaRo = 'Số tiền viết bằng chữ chưa rõ — bạn nhập tay nhé.';

typedef _Khoang = ({int batDau, int ketThuc});
typedef _CumTien = ({int batDau, int ketThuc, double giaTri, bool lit});

/// Số + đơn vị trên câu đã bỏ dấu: `45k`, `45 nghìn`, `2tr`, `1tr2`, `1,2 triệu`, `2 củ`, `2 lít`, `3 xị`. Nhóm 3 là
/// phần lẻ dính liền sau `tr` (`1tr2`, `1tr25`, `1tr200`).
final RegExp _mauSoDonVi = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d+(?:[.,]\d+)?)\s*(trieu|tr|cu|nghin|ngan|k|lit|xi)(\d{1,3})?(?![\p{L}\p{N}])',
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

const Map<String, double> _giaTriDonVi = {
  'trieu': 1000000,
  'tr': 1000000,
  'cu': 1000000,
  'nghin': 1000,
  'ngan': 1000,
  'k': 1000,
  'lit': 100000,
  'xi': 100000,
};

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
  if (tien != null) {
    if (tien.giaTri >= 1e13) {
      canhBao.add(kCanhBaoSoTienQuaLon);
    } else if (!(tien.giaTri > 0)) {
      canhBao.add(kCanhBaoSoTienKhongHopLe);
    } else {
      soTien = tien.giaTri.roundToDouble();
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
    if (tenVi != null) {
      final trung = _cungTen(dsVi, tenVi.ten, (w) => w.name);
      if (trung.length == 1) {
        walletId = trung.single.id;
        daDung.add(_moRongTruocVi(thuong, tenVi.batDau, tenVi.ketThuc));
      }
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
    final st = ai.soTien;
    if (soTien == null && st != null && st < 1e13 && cachDocSoTien(cau, now: now).any((v) => (v - st).abs() <= 0.5)) {
      soTien = st.roundToDouble();
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
  String? categoryId;
  DoanDanhMuc? doan;
  String? lyDo;
  CategorySuggestion? goiY;
  // Tìm trên câu đã bỏ đoạn ví: "45k ví Tiết kiệm" không được đọc thành danh mục "Tiết kiệm".
  final tenDm = timTenTrongCau(_boKhoang(s, daDung), [for (final c in dsHopLe) c.name], tuLoai: 'danh mục');
  if (tenDm != null) {
    final trung = _cungTen(dsHopLe, tenDm.ten, (c) => c.name);
    if (trung.length == 1) categoryId = trung.single.id;
  } else {
    // Thứ tự (người dùng chốt 2026-09-30): B1 khi nó chắc → từ khoá của danh mục → AI. Cùng thứ tự thẻ gợi ý trên màn
    // (B1 trước từ khoá): thói quen riêng, rồi điều người dùng tự khai báo, rồi mới tới hiểu biết chung của mô hình.
    final d = mo?.doan(ghiChuLuat, hopLe: hopLe, tatCap: tatCap);
    final tk = d != null
        ? null
        : const CategorySuggestionEngine().suggest(
            rawText: ghiChuLuat,
            candidates: [
              for (final c in dsHopLe)
                for (final k in tuKhoa[c.id] ?? const <String>[]) CategoryKeywordCandidate(category: c, keyword: k),
            ],
          );
    if (d != null) {
      categoryId = d.categoryId;
      doan = d;
      final ten = dsHopLe.firstWhere((c) => c.id == d.categoryId).name;
      lyDo = cauLyDoHoc(d, ghiChuGoc: ghiChuLuat, tenDanhMuc: ten);
      goiY = CategorySuggestion(
        category: dsHopLe.firstWhere((c) => c.id == d.categoryId),
        matchedKeyword: d.cumBoDau,
        nguon: kNguonGoiYHoc,
        amTietChinh: d.cumBoDau,
        lyDo: lyDo,
      );
    } else if (tk != null) {
      categoryId = tk.categoryId;
      lyDo = tk.lyDo;
      goiY = tk;
    } else if (ai?.danhMuc != null) {
      final k = khopTheoTen(ai!.danhMuc!, dsHopLe, (c) => c.name);
      if (k is KhopMot<Category>) {
        categoryId = k.muc.id;
        aiLap = true;
      }
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
  );
}

/// Mọi CÁCH ĐỌC hợp lệ (≥ 1.000 đ, dưới 13 chữ số) của các con số có trong [cau] — lưới kiểm số tiền của AI (§2.8). AI
/// được CHỌN một cách đọc; số nào không nằm đây là số AI tự đặt ra, bị bỏ.
///
/// Gồm: mọi cụm luật thấy, kể cả cụm luật không chọn (lít / xị, số thứ hai); số trần `n` → `n`, và `n × 1.000` khi
/// `10 ≤ n < 1.000` (*"ăn phở 45"*; số một chữ số là số lượng: *"2 ly"*); số chữ không đơn vị có hàng chục → × 1.000
/// (*"ba chục"* = 30.000); *"X triệu Y"* / *"X tr Y"* / *"một triệu hai"* → X,Y triệu; *"2k5"* → 2.500.
Set<double> cachDocSoTien(String cau, {required DateTime now}) {
  final s = unorm.nfc(cau);
  final b = removeVietnameseTones(s.toLowerCase());
  if (b.length != s.length) return const {};
  final ng = timNgayTrongCau(s, now);
  bool trungNgay(int bd, int kt) => ng != null && bd < ng.ketThuc && kt > ng.batDau;
  final kq = <double>{};
  final daPhu = <_Khoang>[];

  for (final m in _mauSoDonVi.allMatches(b)) {
    if (trungNgay(m.start, m.end)) continue;
    final dv = m.group(2)!;
    final le = m.group(3);
    var gt = double.parse(m.group(1)!.replaceAll(',', '.')) * _giaTriDonVi[dv]!;
    if (le != null) {
      if (dv == 'tr') {
        gt += int.parse(le) * const [0, 100000, 10000, 1000][le.length];
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
    if (trungNgay(m.start, m.end)) continue;
    kq.add(int.parse(m.group(1)!) * 1e6 + int.parse(m.group(2)!) * 1e5);
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
    final sau = _sauLaChuSoChu.firstMatch(b.substring(c.ketThuc));
    final bac = _bacCuoi.firstMatch(b.substring(c.batDau, c.ketThuc))?.group(1);
    if (sau != null && bac != null) {
      kq.add(c.giaTri + _chuSoChu[sau.group(1)]! * _giaTriBac[bac]! / 10);
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

/// *"2 triệu 5"*, *"2 tr 5"*, *"2 củ 5"* — một chữ số lẻ tách bằng dấu cách, không kèm đơn vị riêng.
final RegExp _mauTrieuLe = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d+)\s*(?:trieu|tr|cu)\s+(\d)(?![\p{L}\p{N}.,/])(?!\s*(?:k|nghin|ngan|tr|trieu|cu|lit|xi)(?![a-z]))',
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
  final tu = [for (final m in _tu.allMatches(thuong)) unorm.nfc(m.group(0)!)];
  final nganHang = w.type == 'bank' || w.type == 'banking';
  for (var i = 0; i < tu.length; i++) {
    if (_chuVi.contains(tu[i])) return true;
    if (nganHang && _chuNganHang.contains(tu[i])) return true;
    if (nganHang && i + 1 < tu.length && _chuyenKhoan.contains('${tu[i]} ${tu[i + 1]}')) return true;
  }
  return _vietTatTenVi(thuong, w.name);
}

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
    final trung = _cungTen(dsVi, t.ten, (w) => w.name);
    if (trung.length == 1) kq.add((vi: trung.single, batDau: t.batDau, ketThuc: t.ketThuc));
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

/// Cụm số tiền được chọn (§2.1), hoặc `null`. Hạng ưu tiên: *k / nghìn / tr / củ*, số chữ, số trần ≥ 1.000 trước; *lít /
/// xị* sau (*"đổ 2 lít xăng 50k"* → 50.000). Còn ≥ 2 cụm cùng hạng → cụm đầu + cảnh báo.
_CumTien? _chonSoTien(
  String s,
  String b, {
  required NgayTrongCau? ngay,
  required List<String> canhBao,
}) {
  final cum = <_CumTien>[];
  bool trungNgay(int bd, int kt) => ngay != null && bd < ngay.ketThuc && kt > ngay.batDau;

  for (final m in _mauSoDonVi.allMatches(b)) {
    final dv = m.group(2)!;
    final le = m.group(3);
    if (le != null && dv != 'tr') continue; // "2k5" — không chắc thì không đọc
    var gt = double.parse(m.group(1)!.replaceAll(',', '.')) * _giaTriDonVi[dv]!;
    if (le != null) gt += int.parse(le) * const [0, 100000, 10000, 1000][le.length];
    if (trungNgay(m.start, m.end)) continue;
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: dv == 'lit' || dv == 'xi'));
  }

  for (final m in _mauSoTran.allMatches(b)) {
    if (cum.any((c) => m.start < c.ketThuc && m.end > c.batDau) || trungNgay(m.start, m.end)) continue;
    final chuSo = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    if (chuSo.length >= 2 && chuSo.startsWith('0')) continue; // số điện thoại, mã
    if (_truocLaNam.hasMatch(b.substring(0, m.start))) continue; // "năm 2026"
    final gt = double.parse(chuSo);
    if (gt < 1000) continue; // số lượng: "2 ly cà phê"
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: false));
  }

  var chuaRo = false;
  for (final c in timSoBangChu(s)) {
    if (trungNgay(c.batDau, c.ketThuc)) continue;
    // "một triệu hai" = 1.200.000 hay 1.000.000 rồi chữ khác? Không chắc thì không đọc.
    if (c.giaTri.isNaN || _sauLaChuSoChu.hasMatch(b.substring(c.ketThuc))) {
      chuaRo = true;
      continue;
    }
    if (c.giaTri < 1000) continue;
    cum.add((batDau: c.batDau, ketThuc: c.ketThuc, giaTri: c.giaTri, lit: false));
  }

  cum.sort((x, y) => x.batDau.compareTo(y.batDau));
  final truoc = [for (final c in cum) if (!c.lit) c];
  final hang = truoc.isNotEmpty ? truoc : [for (final c in cum) if (c.lit) c];
  if (hang.isEmpty) {
    if (chuaRo) canhBao.add(kCanhBaoSoChuChuaRo);
    return null;
  }
  if (hang.length >= 2) canhBao.add(kCanhBaoNhieuSoTien);
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
