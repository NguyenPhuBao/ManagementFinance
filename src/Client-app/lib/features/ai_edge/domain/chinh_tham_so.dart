/// Bộ CHỈNH THAM SỐ của `tim_giao_dich` theo CÂU HỎI — tất định, chạy trước
/// khi tool kiểm và tra cứu (2026-09-25, mục 9.28 `AI_EDGE_FEATURE.md`).
///
/// Cổng D lần 9–11: tool đã đúng 19/20 nhưng tham số đứng ở 13/20, và sáu câu
/// hỏng đều thuộc chỗ ví dụ trong lời hệ thống **hết tác dụng** — E2B không
/// tách được hai tên trong một câu, không đổi cách đọc *"nửa triệu"* sau ba
/// lần, bỏ sàn của *"từ … đến"*, quên `sap_xep`, đọc *"di chuyển"* thành chuyển
/// ví. Những thứ ấy đều **đọc được thẳng từ câu hỏi** bằng luật, nên đọc bằng
/// luật: câu hỏi là nguồn sự thật, tham số của mô hình chỉ là gợi ý.
///
/// Sáu luật, mỗi luật một họ lỗi đã đo:
/// 1. **Tách hai tên**: `danh_muc` / `vi` / `tu_khoa` không khớp tên nào nhưng
///    chứa tên danh mục và/hoặc tên ví có thật → điền đúng ô; chữ *"ví"* trong
///    cụm quyết định vế nào là ví.
/// 2. **Danh mục / ví nêu trong câu hỏi** mà ô trống → điền; `chieu` là chuyển
///    ví mà câu hỏi không có chữ chuyển tiền → `chieu` theo động từ của câu.
/// 3. **Chiều thiếu** → theo động từ (*chi / tiêu / mua* · *thu / nhận / lương*).
/// 4. **Ngưỡng của câu hỏi thắng** tham số mô hình: số + đơn vị (*500k, 1 triệu*)
///    hay số chữ (*nửa triệu, một triệu rưỡi*) kèm từ định hướng (*trên / hơn / từ
///    … trở lên* → `so_tien_tu`; *dưới / không quá / đến / tới* → `so_tien_den`).
/// 5. **Sắp xếp và kỳ**: *lần gần nhất / lần cuối / gần đây / mới nhất* →
///    `sap_xep=moi_nhat`; câu không có chữ kỳ nào → `ky=moi_luc`.
/// 11. **Kỳ nêu cụ thể** (spec mở rộng tool 2026-09-27 §3.1): *tháng 8, quý 2,
///    từ 1/9 đến 15/9, 3 tháng gần nhất, năm ngoái* → `ky=tuy_chon` + `tu_ngay`
///    / `den_ngay`; thắng luật 5. **11b** (đo Realme 2026-10-02, mục 9.45):
///    `tu_khoa` chỉ là ĐOẠN KỲ của câu hỏi (*"từ 1/9 den 15/9"*) → gỡ — cùng
///    lý lẽ 2a; chữ sau *"ghi chú"*, `tu_khoa` có chữ khác, câu không nêu kỳ
///    cụ thể thì giữ.
/// 12. **So sánh hai kỳ** (E13): *so với / hơn tháng trước* → `so_voi=ky_truoc`;
///    *cùng kỳ năm trước / năm ngoái* → `cung_ky_nam_truoc`. `ky` là kỳ GỐC —
///    kỳ đang nói — chứ không phải kỳ đem ra so; câu không so sánh mà mô hình
///    điền `so_voi` → gỡ (cùng lý lẽ luật 10).
/// 6. **Không đụng** giá trị mà câu hỏi không nói tới — TRỪ `chon` (luật 10):
///    cổng E lần 1 (9.32) đo được mô hình điền `chon: nhieu_nhat` cho *"liệt kê
///    các khoản chi…"* (C9) và *"5 khoản chi gần đây nhất"* (C16) nên chỉ còn
///    một hàng; câu không có *"…nhất"* thì `chon` không có bằng chứng → gỡ.
///    Cùng luật cho `chinhThamSoNganSach` (E10 `duoi_nua` thừa) và
///    `chinhThamSoMucTieu`. Từ vòng sửa cổng F (2026-09-28, G2) cũng TRỪ
///    `so_tien_*` khi câu không có số tiền nào (luật 4b — F2).
///
/// Vòng sửa cổng F (G2, mục 9.36): **2a** `tu_khoa` chỉ là chữ chiều (*"chi"*)
/// → gỡ; **2b** câu nêu *"mục tiêu <tên>"* → `tu_khoa` = tên (C20); **2c** mảnh
/// của cụm ví (*"vi tien"*) lọt vào `danh_muc` / `tu_khoa` → gỡ (C13); **4b**
/// câu không có số tiền → gỡ `so_tien_*` (F2). Cùng lượt: `tenNeuTrongCau` —
/// tên đối tượng câu hỏi nêu, cho tool ngân sách / hoá đơn / mục tiêu.
///
/// So trên chữ **bỏ dấu** — đúng chỗ của `removeVietnameseTones` (đọc tham số,
/// như `khop_ten.dart`), không phải quy tắc trùng tên. ⚠️ Từ khoá chiều tiền
/// giữ dạng **chuỗi tách lúc chạy**: test quét 14 cấm `'chi'` / `'thu'` đứng
/// riêng trong `ai_edge/` — ở đây chúng là chữ của câu hỏi.
///
/// Số viết bằng chữ đọc qua `timSoBangChu` (`core/utils/so_bang_chu.dart`, C2
/// task 1, 2026-09-29) — một định nghĩa với ô Nhập nhanh và bộ kiểm số. Bộ đọc
/// riêng trước đó mù hàng chục: *"dưới năm mươi nghìn"* không thành ngưỡng nào.
/// Lượng từ mơ hồ (*"vài trăm nghìn"*, `NaN`) bị bỏ qua như trước — bộ cũ không
/// có chúng.
library;

import '../../../core/category/category_name.dart';
import '../../../core/utils/khop_ten.dart';
import '../../../core/utils/so_bang_chu.dart';
import 'cong_cu.dart';
import 'hang_muc_tieu.dart';
import 'hang_tong_quan.dart';
import 'ma_ky.dart';

class KetQuaChinhThamSo {
  final Map<String, dynamic> args;

  /// Mỗi luật đã áp một dòng — in ra log `[SLM][tool] chỉnh tham số`.
  final List<String> ghiChu;

  /// Chữ kỳ CÓ SỐ (*"tháng 8/2026"*, *"3 tháng gần nhất"*) và các cách gọi kỳ
  /// ấy — chỉ có khi luật 11 đọc được kỳ cụ thể từ câu hỏi và đã điền
  /// `ky=tuy_chon`. Tool đưa chữ vào `boLoc`, tên vào `tenLienQuan`.
  final String? chuKy;
  final List<String> tenKy;
  const KetQuaChinhThamSo(
    this.args,
    this.ghiChu, {
    this.chuKy,
    this.tenKy = const [],
  });
}

/// Bỏ dấu + chuẩn hoá (chữ thường, gom khoảng trắng); `_` đọc là dấu cách.
String _bo(String s) =>
    removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));

RegExp _tronTu(String tu) => RegExp('(?<![a-z0-9])${RegExp.escape(tu)}(?![a-z0-9])');

bool _co(String chuoi, String tu) => _tronTu(_bo(tu)).hasMatch(chuoi);

/// Từ khoá theo nhóm — một chuỗi, tách lúc chạy (xem docstring đầu tệp).
final List<String> _tuChi = 'khoan chi|chi tieu|cho vay|tieu|chi|mua'.split('|');
final List<String> _tuThu = 'khoan thu|nhan duoc|thu ve|luong|thu nhap|thu'.split('|');
// Luật 7–9 (spec tool truy vấn 2026-09-27, mục 3): chọn · gộp · hai chiều.
/// "nhiều nhất", "ít nhất" — và dạng có MỘT từ chen giữa: "ít tiêu nhất", "chi
/// nhiều nhất" (E3 lần đo 15 viết "ít tiêu nhất"; từ khoá `it nhat` trần không khớp).
final RegExp _mauChon = RegExp(
    r'(?<![a-z0-9])(nhieu|lon|cao|it|nho|thap)(?:\s+(?!nhat)[a-z]+)?\s+nhat(?![a-z0-9])');
final List<String> _tuGopDanhMuc = 'danh muc nao|theo danh muc|vao danh muc nao|danh muc gi'.split('|');
final List<String> _tuGopVi = 'vi nao|theo vi'.split('|');
final List<String> _tuChuyenTien =
    'chuyen tien|chuyen sang|chuyen khoan|chuyen vi|chuyen qua|chuyen den|chuyen vao'
        .split('|');
final List<String> _tuMoiNhat = 'lan gan nhat|lan cuoi|gan day|moi nhat|gan nhat'.split('|');
/// Chữ kỳ — có cả *"đầu năm / đầu tháng / đầu tuần"* (E5 cổng E: *"kể từ đầu
/// năm"* từng bị đọc là không nêu kỳ → `moi_luc`).
final List<String> _tuKy =
    'hom nay|hom qua|tuan nay|tuan truoc|thang nay|thang truoc|quy nay|nam nay|dau nam|dau thang|dau tuan|tuan|thang|quy'
        .split('|');
final List<String> _tuTu = 'tren|hon|tu|it nhat|toi thieu|lon hon'.split('|');
final List<String> _tuDen = 'duoi|khong qua|den|toi|toi da|nho hon|thap hon|it hon'.split('|');

const Map<String, double> _donVi = {
  'k': 1000, 'nghin': 1000, 'ngan': 1000, 'tr': 1000000, 'trieu': 1000000,
  'ty': 1000000000, 'ti': 1000000000, 'tram': 100,
};

/// Cụm số chữ có giá trị xác định trong [q] (câu đã bỏ dấu).
List<CumSoChu> _cumSoChu(String q) => [
      for (final c in timSoBangChu(q))
        if (!c.giaTri.isNaN) c,
    ];

final RegExp _mauSoDonVi = RegExp(
  r'(?<![a-z0-9.,])(\d+(?:[.,]\d+)*)\s*(k|nghin|ngan|tr|trieu|ty|ti)?(?![a-z0-9])',
);

/// Tên thật (bỏ dấu → tên gốc), tên dài trước để "Chi khác" không bị "chi" cắt.
List<(String, String)> _bangTen(List<String> ten) => [
      for (final t in ten)
        if (_bo(t).isNotEmpty) (_bo(t), t),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

String? _khop(String? gia, List<(String, String)> bang) {
  if (gia == null) return null;
  final k = _bo(gia);
  for (final (b, goc) in bang) {
    if (b == k) return goc;
  }
  return null;
}

String? _tenTrong(String chuoiBoDau, List<(String, String)> bang) {
  for (final (b, goc) in bang) {
    if (_tronTu(b).hasMatch(chuoiBoDau)) return goc;
  }
  return null;
}

String? _chuoi(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Mọi âm tiết của [boDau] là chữ số (ngày, tháng, năm) hoặc chữ nối của một
/// đoạn kỳ — *"tu 1/9 den 15/9"*, *"thang 8"*. Chuỗi rỗng → `false`.
bool _chiLaChuKy(String boDau) {
  final am = boDau.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
  return am.isNotEmpty &&
      am.every((t) => RegExp(r'[0-9]').hasMatch(t) || _chuNoiKy.contains(t));
}

final Set<String> _chuNoiKy = 'tu|den|toi|ngay|thang|nam|quy|tuan'.split('|').toSet();

KetQuaChinhThamSo chinhThamSoTimGiaoDich(
  String cauHoi,
  Map<String, dynamic> args, {
  required List<String> tenDanhMuc,
  required List<String> tenVi,
  required DateTime now,
  List<String> tenMucTieu = const [],
}) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  // Không có câu hỏi thì không có bằng chứng để chỉnh gì (luật 6) — kể cả
  // "không nêu kỳ → moi_luc".
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  final bangDm = _bangTen(tenDanhMuc);
  final bangVi = _bangTen(tenVi);
  final bangCa = _bangTen([...tenDanhMuc, ...tenVi]);

  // 1. Tách hai tên trong một ô.
  for (final o in ['danh_muc', 'vi', 'tu_khoa']) {
    final v = _chuoi(a[o]);
    if (v == null || _khop(v, bangCa) != null) continue;
    final vb = _bo(v);
    String? dm;
    String? wallet;
    final mVi = RegExp(r'(?<![a-z0-9])vi(?![a-z0-9])').firstMatch(vb);
    if (mVi != null) {
      final trai = vb.substring(0, mVi.start).replaceAll(RegExp(r'\s+(tu|cua|cho|o|trong)\s*$'), '');
      final phai = vb.substring(mVi.end);
      wallet = _tenTrong(phai, bangVi);
      dm = _tenTrong(trai, bangDm);
    } else {
      dm = _tenTrong(vb, bangDm);
      final w = _tenTrong(vb, bangVi);
      if (w != null && (dm == null || _bo(w) != _bo(dm))) wallet = w;
    }
    if (dm == null && wallet == null) continue;
    if (dm != null && _khop(_chuoi(a['danh_muc']), bangDm) == null) {
      a['danh_muc'] = dm;
    }
    if (wallet != null && _khop(_chuoi(a['vi']), bangVi) == null) {
      a['vi'] = wallet;
    }
    if (o == 'tu_khoa' || (o == 'danh_muc' && dm == null) || (o == 'vi' && wallet == null)) {
      a.remove(o);
    }
    ghi.add('$o "$v" → ${[if (dm != null) 'danh_muc=$dm', if (wallet != null) 'vi=$wallet'].join(', ')}');
  }

  // Chữ đứng sau "ghi chú" trong CÂU HỎI là từ khoá ghi chú, không phải danh mục
  // (C17 lần 14 trên OnePlus: mô hình bỏ trống tu_khoa nên vế trên không cứu).
  final sauGhiChu = _sauGhiChu(q);

  // 2a. G2 cổng F (F2): tu_khoa chỉ là chữ CHIỀU ("chi", "khoản thu") — luật 3
  // đọc chiều từ câu rồi; tìm "chi" trong ghi chú ra 0 khoản. Trừ khi chữ ấy
  // đứng sau "ghi chú", hay trùng tên danh mục / ví thật ("Cho vay").
  final tkChieu = _chuoi(a['tu_khoa']);
  if (tkChieu != null &&
      _khop(tkChieu, bangCa) == null &&
      _bo(tkChieu) != sauGhiChu &&
      [..._tuChi, ..._tuThu].contains(_bo(tkChieu))) {
    a.remove('tu_khoa');
    ghi.add('tu_khoa "$tkChieu" chỉ là chữ chiều → bỏ');
  }

  // 2b. G2 cổng F (C20): câu nêu "mục tiêu <tên>" → tu_khoa là tên ấy — ghi chú
  // nạp / rút mục tiêu mang tên mục tiêu ("Tích lũy mục tiêu: MuaXe"). Tên ấy
  // lọt vào danh_muc thì gỡ: không danh mục nào mang tên mục tiêu.
  if (_co(q, 'muc tieu')) {
    final mt = tenNeuTrongCau(cauHoi, tenMucTieu, tuLoai: 'muc tieu');
    if (mt != null) {
      if (!_bo(_chuoi(a['tu_khoa']) ?? '').contains(_bo(mt))) {
        a['tu_khoa'] = mt;
        ghi.add('câu hỏi nêu mục tiêu → tu_khoa=$mt');
      }
      if (_bo(_chuoi(a['danh_muc']) ?? '') == _bo(mt)) {
        a.remove('danh_muc');
        ghi.add('danh_muc "$mt" là tên mục tiêu → bỏ');
      }
    }
  }

  // 2. Danh mục / ví nêu trong câu hỏi; chiều "chuyển ví" khi câu không chuyển tiền.
  // ⚠️ Tên trùng với TỪ KHOÁ ghi chú mô hình đã điền thì không phải danh mục
  // (C17 lần 13: "ghi chú hoa don" ↔ danh mục "Hóa đơn" → lọc thêm danh mục →
  // 0 khoản).
  final tuKhoaBo = _bo(_chuoi(a['tu_khoa']) ?? '');
  if (sauGhiChu != null && tuKhoaBo.isEmpty) {
    a['tu_khoa'] = sauGhiChu;
    ghi.add('câu hỏi "ghi chú …" → tu_khoa=$sauGhiChu');
  }
  if (_chuoi(a['danh_muc']) == null) {
    final dm = _tenTrong(q, bangDm);
    if (dm != null &&
        (tuKhoaBo.isEmpty || !tuKhoaBo.contains(_bo(dm))) &&
        (sauGhiChu == null || !sauGhiChu.contains(_bo(dm)))) {
      a['danh_muc'] = dm;
      ghi.add('câu hỏi nêu danh mục → danh_muc=$dm');
    }
  }
  if (_chuoi(a['vi']) == null) {
    final w = _tenTrong(q, bangVi);
    if (w != null && _bo(w) != _bo(_chuoi(a['danh_muc']) ?? '')) {
      a['vi'] = w;
      ghi.add('câu hỏi nêu ví → vi=$w');
    }
  }
  // 2c. G2 cổng F (C13): MẢNH của cụm ví trong câu ("vi tien" của "ví tiền
  // mặt") lọt vào danh_muc / tu_khoa, ô ví đã có tên thật → gỡ mảnh. Tên lạ
  // không phải mảnh ví ("abc", DC3) thì để tool từ chối như cũ.
  final viThat = _khop(_chuoi(a['vi']), bangVi);
  if (viThat != null) {
    final cumVi = 'vi ${_bo(viThat)}';
    for (final o in ['danh_muc', 'tu_khoa']) {
      final v = _chuoi(a[o]);
      if (v == null || _khop(v, bangCa) != null) continue;
      if (o == 'tu_khoa' && _bo(v) == sauGhiChu) continue;
      if (_tronTu(_bo(v)).hasMatch(cumVi)) {
        a.remove(o);
        ghi.add('$o "$v" là mảnh của ví $viThat → bỏ');
      }
    }
  }
  final coChuyenTien = _tuChuyenTien.any((t) => _co(q, t));
  if (a['chieu'] == 'chuyen_vi' && !coChuyenTien) {
    final theoDongTu = _chieuTheoDongTu(q);
    if (theoDongTu != null) {
      a['chieu'] = theoDongTu;
    } else {
      a.remove('chieu');
    }
    ghi.add('chieu chuyen_vi mà câu không chuyển tiền → ${a['chieu'] ?? 'bỏ'}');
  }

  // 3. Chiều thiếu → theo động từ.
  if (_chuoi(a['chieu']) == null) {
    final c = _chieuTheoDongTu(q);
    if (c != null) {
      a['chieu'] = c;
      ghi.add('câu hỏi nói chiều → chieu=$c');
    }
  }

  // 4. Ngưỡng của câu hỏi thắng.
  final nguong = _nguongTrongCau(q);
  if (nguong.tu != null && a['so_tien_tu'] != nguong.tu) {
    a['so_tien_tu'] = nguong.tu;
    ghi.add('câu hỏi có ngưỡng dưới → so_tien_tu=${nguong.tu}');
  }
  if (nguong.den != null && a['so_tien_den'] != nguong.den) {
    a['so_tien_den'] = nguong.den;
    ghi.add('câu hỏi có ngưỡng trên → so_tien_den=${nguong.den}');
  }
  // 4b. G2 cổng F (F2): câu không có SỐ TIỀN nào → ngưỡng của mô hình không có
  // bằng chứng (lý lẽ luật 10): "từ 1/9 đến 15/9" từng thành "từ 1 đ đến 15 đ".
  if (!_coSoTien(q)) {
    for (final o in ['so_tien_tu', 'so_tien_den']) {
      if (a.containsKey(o)) {
        a.remove(o);
        ghi.add('câu hỏi không nêu số tiền → bỏ $o');
      }
    }
  }

  // 12a. Câu so sánh hai kỳ? Cụm so sánh ("so với năm ngoái") bị bỏ khỏi câu
  // trước khi đọc kỳ tự do: nó nêu kỳ ĐEM RA SO, không phải kỳ đang hỏi.
  final soSanh = _soSanhTrongCau(q);
  final qKy = soSanh == null ? q : q.replaceAll(soSanh.mau, ' ');

  // 11. Kỳ nêu cụ thể trong câu (tháng 8, quý 2, từ 1/9 đến 15/9, 3 tháng gần nhất).
  final kyTuDo = kyTuCauHoi(qKy, now);
  if (kyTuDo != null) {
    a['ky'] = kMaKyTuyChon;
    a['tu_ngay'] = _ddmmyyyy(kyTuDo.from);
    a['den_ngay'] = _ddmmyyyy(kyTuDo.to.subtract(const Duration(hours: 12)));
    ghi.add('câu hỏi nêu kỳ cụ thể → ky=$kMaKyTuyChon ${a['tu_ngay']}–${a['den_ngay']}');
  }
  // 11b. Đo Realme 2026-10-02 (dự án B, Task 8 — F2 ở phiên một tool): mô hình
  // nhét cả ĐOẠN KỲ của câu hỏi vào tu_khoa ("từ 1/9 den 15/9"); tìm chuỗi ấy
  // trong ghi chú ra 0 khoản. Cùng lý lẽ 2a (chữ chiều): luật 11 đã đọc kỳ rồi.
  // Chỉ gỡ khi câu NÊU kỳ cụ thể, tu_khoa nằm trong câu, và mọi âm tiết của nó
  // là chữ số hoặc chữ kỳ — "tien nha thang 8", chữ sau "ghi chú" thì giữ.
  final tkKy = _chuoi(a['tu_khoa']);
  if (kyTuDo != null &&
      tkKy != null &&
      _khop(tkKy, bangCa) == null &&
      _bo(tkKy) != sauGhiChu &&
      q.contains(_bo(tkKy)) &&
      _chiLaChuKy(_bo(tkKy))) {
    a.remove('tu_khoa');
    ghi.add('tu_khoa "$tkKy" chỉ là chữ kỳ → bỏ');
  }

  // 5. Sắp xếp và kỳ. "3 tháng gần nhất" là kỳ, không phải "lần gần nhất".
  final qXep = q.replaceAll(mauKyLuiGanNhat, ' ');
  if (_tuMoiNhat.any((t) => _co(qXep, t)) && a['sap_xep'] != 'moi_nhat') {
    a['sap_xep'] = 'moi_nhat';
    ghi.add('câu hỏi "gần nhất / lần cuối" → sap_xep=moi_nhat');
  }
  // 14. Kỳ CHƯA TỚI (L7 mục 9.33): "30 ngày tới" từng bị đọc là không nêu kỳ →
  // moi_luc → tool liệt kê khoản đã qua. Sổ giao dịch chỉ có quá khứ: tool từ chối.
  final tuongLai = kyTuDo == null && soSanh == null && _laKyTuongLai(cauHoi, q);
  if (tuongLai) {
    a['ky'] = kMaKyTuongLai;
    ghi.add('câu hỏi nêu kỳ chưa tới → ky=$kMaKyTuongLai');
  }
  if (kyTuDo == null &&
      soSanh == null &&
      !tuongLai &&
      !_tuKy.any((t) => _co(q, t)) &&
      a['ky'] != 'moi_luc') {
    a['ky'] = 'moi_luc';
    ghi.add('câu hỏi không nêu kỳ → ky=moi_luc');
  }

  // 15. H3 cổng F lần 2 (E19): kỳ tương đối NÊU TRONG CÂU ("quý này") thắng ky của
  // mô hình — cùng lý lẽ luật 4: câu hỏi là nguồn sự thật. Chỉ các mã "… này":
  // câu nêu chúng thì không còn cách đọc nào khác.
  if (kyTuDo == null && soSanh == null && !tuongLai) {
    final neu = _kyGocNeu(q);
    if (neu != null && a['ky'] != neu) {
      a['ky'] = neu;
      ghi.add('câu hỏi nêu kỳ → ky=$neu');
    }
  }

  // 12b. So sánh hai kỳ (E13): kỳ gốc là kỳ đang nói, kỳ so sánh đi so_voi.
  if (soSanh != null) {
    if (a['so_voi'] != soSanh.ma) {
      a['so_voi'] = soSanh.ma;
      ghi.add('câu hỏi so sánh → so_voi=${soSanh.ma}');
    }
    if (kyTuDo == null) {
      final goc = _kyGocNeu(qKy) ?? soSanh.kyGocNgam;
      if (a['ky'] != goc) {
        a['ky'] = goc;
        ghi.add('kỳ gốc của phép so sánh → ky=$goc');
      }
    }
  } else if (_chuoi(a['so_voi']) != null) {
    a.remove('so_voi');
    ghi.add('câu hỏi không so sánh hai kỳ → bỏ so_voi');
  }
  // 7. Chọn (E3 lần đo 15). ⚠️ "ít nhất" đứng trước một số tiền là NGƯỠNG — luật
  //    4 đã ăn nó; ở đây chỉ nhận "ít nhất" KHÔNG theo sau bởi số.
  final chon = _chonTrongCau(q);
  if (chon != null && a['chon'] != chon) {
    a['chon'] = chon;
    ghi.add('câu hỏi "… nhất" → chon=$chon');
  }
  // 10. Câu không có "… nhất" mà mô hình vẫn điền chon → gỡ (C9, C16 cổng E).
  if (chon == null && _chuoi(a['chon']) != null) {
    a.remove('chon');
    ghi.add('câu hỏi không có "… nhất" → bỏ chon');
  }
  // 8. Gộp: danh mục / ví nói chung, KHÔNG nêu tên (E5 nêu tên → lọc, không gộp).
  if (_chuoi(a['danh_muc']) == null &&
      _tuGopDanhMuc.any((t) => _co(q, t)) &&
      a['gop'] != 'danh_muc') {
    a['gop'] = 'danh_muc';
    ghi.add('câu hỏi "danh mục nào / theo danh mục" → gop=danh_muc');
  } else if (_chuoi(a['vi']) == null &&
      _tuGopVi.any((t) => _co(q, t)) &&
      a['gop'] != 'vi') {
    a['gop'] = 'vi';
    ghi.add('câu hỏi "ví nào / theo ví" → gop=vi');
  }
  // 9. Hai chiều trong một câu (E15) → tat_ca.
  if (_coCaHaiChieu(q) && a['chieu'] != 'tat_ca') {
    a['chieu'] = 'tat_ca';
    ghi.add('câu hỏi nói cả chi lẫn thu → chieu=tat_ca');
  }
  return KetQuaChinhThamSo(
    a,
    ghi,
    chuKy: kyTuDo?.chu,
    tenKy: kyTuDo?.ten ?? const [],
  );
}

/// Kỳ chưa tới, đọc trên câu CÓ DẤU khi câu có dấu: bỏ dấu thì *"tới"* và
/// *"tôi"* thành một chữ (*"tháng này tôi chi"*).
final RegExp _mauTuongLaiCoDau = RegExp(
  r'(?<![\p{L}\p{N}])(?:\d+\s+(?:ngày|tuần|tháng|năm)\s+(?:tới|sắp tới|nữa)'
  r'|(?:ngày|tuần|tháng|quý|năm)\s+(?:sau|tới|sắp tới)'
  r'|sắp tới|ngày mai)(?![\p{L}\p{N}])',
  unicode: true,
);

/// Bản KHÔNG DẤU (câu gõ không dấu): *"toi"* chỉ được đọc là *"tới"* khi đứng
/// sau một con số + đơn vị, hoặc khi ngay sau nó là *"toi / phai / can / se"* hay
/// hết câu — *"thang toi chi"* để yên.
final RegExp _mauTuongLaiKhongDau = RegExp(
  r'(?<![a-z0-9])(?:\d+ (?:ngay|tuan|thang|nam) (?:toi|sap toi|nua)'
  r'|(?:ngay|tuan|thang|quy|nam) sau'
  r'|(?:tuan|thang|quy|nam) toi(?= toi| phai| can| se|$)'
  r'|sap toi|ngay mai)(?![a-z0-9])',
);

final RegExp _coDau = RegExp(r'[^\x00-\x7F]');

bool _laKyTuongLai(String cauHoiGoc, String q) => _coDau.hasMatch(cauHoiGoc)
    ? _mauTuongLaiCoDau.hasMatch(normalizeCategoryName(cauHoiGoc))
    : _mauTuongLaiKhongDau.hasMatch(q);

/// Bộ chỉnh của `tong_quan_tai_chinh`: kỳ nêu cụ thể → `tuy_chon` (luật 11);
/// câu không nêu kỳ nào → **tháng này** — KHÁC tool giao dịch (`moi_luc`), vì
/// "thu nhập mọi thời gian" không phải câu người dùng hỏi.
KetQuaChinhThamSo chinhThamSoTongQuan(
  String cauHoi,
  Map<String, dynamic> args, {
  required DateTime now,
}) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  final kyTuDo = kyTuCauHoi(q, now);
  if (kyTuDo != null) {
    a['ky'] = kMaKyTuyChon;
    a['tu_ngay'] = _ddmmyyyy(kyTuDo.from);
    a['den_ngay'] = _ddmmyyyy(kyTuDo.to.subtract(const Duration(hours: 12)));
    ghi.add('câu hỏi nêu kỳ cụ thể → ky=$kMaKyTuyChon ${a['tu_ngay']}–${a['den_ngay']}');
    return KetQuaChinhThamSo(a, ghi, chuKy: kyTuDo.chu, tenKy: kyTuDo.ten);
  }
  final neu = _kyGocNeu(q) ??
      [
        for (final ma in kMaKy.keys)
          if (_co(q, ma)) ma,
      ].firstOrNull;
  final dich = neu ?? 'thang_nay';
  if (a['ky'] != dich && (neu != null || !kMaKy.containsKey(a['ky']))) {
    a['ky'] = dich;
    ghi.add(neu != null ? 'câu hỏi nêu kỳ → ky=$dich' : 'câu hỏi không nêu kỳ → ky=$dich');
  } else if (neu == null && a['ky'] != 'thang_nay') {
    a['ky'] = 'thang_nay';
    ghi.add('câu hỏi không nêu kỳ → ky=thang_nay');
  }
  return KetQuaChinhThamSo(a, ghi);
}

/// Nhóm số của `tong_quan_tai_chinh` mà câu hỏi nhắc tới; RỖNG = câu hỏi chung
/// chung (hoặc không có câu hỏi) → tool trả mọi nhóm.
Set<NhomTongQuan> nhomTongQuanTheoCauHoi(String cauHoi) {
  final q = _bo(cauHoi);
  if (q.isEmpty) return const {};
  bool co(String mau) => RegExp('(?<![a-z0-9])(?:$mau)(?![a-z0-9])').hasMatch(q);
  return {
    if (co('thu nhap|de danh|tiet kiem|dong tien tu do')) NhomTongQuan.thuNhap,
    if (co('trung binh|ngay nao|nhieu nhat|lon nhat')) NhomTongQuan.chiTieu,
    if (co('tai san')) NhomTongQuan.taiSan,
    if (co('cho vay|chua thu|dang no|con no|vay no')) NhomTongQuan.vayNo,
  };
}

/// Bộ chỉnh của `danh_sach_danh_muc`: loại nêu trong câu → `loai`; không nêu →
/// gỡ `loai` mô hình điền (luật 10 — câu "tôi có những danh mục nào" là mọi loại).
KetQuaChinhThamSo chinhThamSoDanhMuc(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? loai;
  if (RegExp(r'danh muc (?:khoan )?(?:vay|no)(?![a-z0-9])').hasMatch(q)) {
    loai = 'vay_no';
  } else if (RegExp(r'danh muc (?:khoan )?(?:thu)(?![a-z0-9])').hasMatch(q)) {
    loai = 'khoan_thu';
  } else if (RegExp(r'danh muc (?:khoan )?(?:chi)(?![a-z0-9])').hasMatch(q)) {
    loai = 'khoan_chi';
  }
  if (loai != null && a['loai'] != loai) {
    a['loai'] = loai;
    ghi.add('câu hỏi nêu loại danh mục → loai=$loai');
  }
  if (loai == null && _chuoi(a['loai']) != null) {
    a.remove('loai');
    ghi.add('câu hỏi không nêu loại danh mục → bỏ loai');
  }
  return KetQuaChinhThamSo(a, ghi);
}

/// ĐỊNH TUYẾN theo câu hỏi (mục 9.33 `AI_EDGE_FEATURE.md`): tên tool mà câu hỏi
/// đòi, hoặc `null` khi câu hỏi không nói rõ — khi ấy tool mô hình chọn được
/// giữ nguyên. Mở rộng nguyên tắc *"câu hỏi là nguồn sự thật"* từ THAM SỐ sang
/// TÊN TOOL: lượt đo lát 1 mô hình không gọi `du_bao_dong_tien` lần nào (0/3) dù
/// lời hệ thống có ví dụ — nó chọn tool mang đúng chữ của câu (*ví*, *hoá đơn*).
///
/// ⚠️ Mỗi cụm là một dương tính giả tiềm tàng, nên danh sách NGẮN và có phản ví
/// dụ trong test: câu nhắc *ngân sách* hay *mục tiêu … còn thiếu* không phải câu
/// dự báo (*"ngân sách ăn uống còn tiêu được bao nhiêu"* thuộc tool ngân sách).
final List<RegExp> _mauDuBao = [
  RegExp(r'(?<![a-z0-9])con (?:duoc )?tieu duoc(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:co )?du (?:tien )?(?:de )?(?:tra|trich|thanh toan)(?![a-z0-9])'),
  // 2026-10-04 (họ B): *đóng / trừ* hết hoá đơn, và *dư* cũng là "còn".
  RegExp(r'(?<![a-z0-9])(?:tra|thanh toan|dong|tru) (?:het|xong)\b.*\b(?:con|du)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])\d+ (?:ngay|tuan|thang) (?:toi|sap toi|nua)\b.*\b(?:phai|can|se) (?:tra|chi|dong)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])sap (?:toi )?(?:toi )?(?:phai|can) (?:tra|chi|dong)(?![a-z0-9])'),
];

/// Lát 2: câu về thu nhập, tiết kiệm, dòng tiền tự do, trung bình ngày, ngày chi
/// nhiều nhất, tài sản tăng/giảm, dư nợ. ⚠️ *"khoản chi lớn nhất"* KHÔNG ở đây —
/// tool giao dịch đã trả lời nó (C18), và đổi tool là làm tụt câu cũ.
///
/// ⚠️ Câu hỏi ĐỊNH NGHĨA (*"dòng tiền tự do là gì"*, *"thuế thu nhập cá nhân tính
/// thế nào"*) mang đúng từ khoá mà không hỏi số của người dùng — [_laCauDinhNghia]
/// chặn chúng trước (họ D, 2026-10-04). Chỉ chặn ở nhánh tổng quan: *"khoản chi lớn
/// nhất tháng này là gì"* (C18) cũng kết thúc bằng *"là gì"*.
final List<RegExp> _mauTongQuan = [
  RegExp(r'(?<![a-z0-9])thu nhap(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:de danh|tiet kiem) (?:duoc )?(?:bao nhieu )?(?:phan tram|%)'),
  RegExp(r'(?<![a-z0-9])t[iy] le (?:tiet kiem|de danh)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])dong tien tu do(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])trung binh (?:moi|mot|1) ngay(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])ngay nao\b.*\b(?:chi|tieu) nhieu nhat(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:tong )?tai san\b.*\b(?:tang|giam|thay doi)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:dang cho vay|cho vay\b.*\bchua thu|chua thu ve|dang no|con no)(?![a-z0-9])'),
];

/// Lát 2: câu LIỆT KÊ hay ĐẾM danh mục. Câu xếp hạng danh mục theo tiền (*"danh
/// mục nào chi nhiều nhất"*) thuộc tool giao dịch — bị loại bằng chữ "nhất".
final List<RegExp> _mauDanhMuc = [
  RegExp(r'(?<![a-z0-9])(?:nhung|cac) danh muc (?:nao|gi)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:bao nhieu|may) danh muc(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])(?:liet ke|ke ten|danh sach)(?: cac| nhung)? danh muc(?![a-z0-9])'),
];

/// 2026-10-04 (họ C): *"các danh mục thu nhập của tôi"* — liệt kê theo LOẠI. Mẫu
/// riêng vì nó đòi thêm `!_coSoHoacKy`: *"các danh mục chi tháng này tiêu bao
/// nhiêu"* là câu tiền; còn ba mẫu trên thì *"bao nhiêu danh mục"* là câu ĐẾM.
final RegExp _mauDanhMucTheoLoai = RegExp(
    r'(?<![a-z0-9])(?:nhung|cac) danh muc (?:khoan )?(?:thu nhap|thu|chi tieu|chi)(?![a-z0-9])');

/// Câu nhắc số tiền hay kỳ — không còn là câu LIỆT KÊ danh mục thuần.
bool _coSoHoacKy(String q) => _coMot(q,
    'bao nhieu|tong|nhieu nhat|it nhat|hom nay|hom qua|tuan|thang|quy|nam nay|nam ngoai');

/// Họ D (2026-10-04): câu hỏi định nghĩa / cách tính — không phải câu số liệu.
final RegExp _mauDinhNghia = RegExp(
    r'(?<![a-z0-9])(?:la gi|nghia la gi|tinh the nao|tinh nhu the nao|cach tinh)$');

bool _laCauDinhNghia(String q) => _mauDinhNghia.hasMatch(q.trim());

/// Họ C (2026-10-04): *"có những loại thu nhập nào"* hỏi DANH MỤC thu, không hỏi
/// số thu nhập — tổng quan không được giành nó.
final RegExp _mauLoaiThuNhap =
    RegExp(r'(?<![a-z0-9])(?:loai|danh muc|nguon) (?:khoan )?thu nhap(?![a-z0-9])');

/// Họ B2 (2026-10-04): *"nếu tiêu đúng ngân sách thì cuối tháng còn bao nhiêu"* —
/// tầng 2 của tool dự báo; xét TRƯỚC luật ngân sách (câu có chữ "ngân sách").
final RegExp _mauDuBaoTheoNganSach = RegExp(
    r'(?<![a-z0-9])neu (?:tieu|chi) (?:dung|het|theo|du) (?:ngan sach|han muc)(?![a-z0-9])');

/// Họ E (2026-10-04): số LOẠI đối tượng câu nhắc trong ngân sách / hoá đơn / mục
/// tiêu. Từ hai trở lên là câu cần hai tool — luật một loại chỉ trả lời nửa câu.
int _soLoaiDoiTuong(String q) =>
    ['ngan sach', 'hoa don', 'muc tieu'].where((t) => _co(q, t)).length;

/// H2 cổng F lần 2 (B2): *"mỗi tháng tôi cần để dành bao nhiêu cho MuaXe"* — mô
/// hình gọi `goi_y_han_muc` với danh_muc = tên mục tiêu rồi bị từ chối. Chữ
/// *"cần"* là bắt buộc: *"tôi để dành được bao nhiêu phần trăm"* (F7) là tổng quan.
final RegExp _mauCanTich = RegExp(
    r'(?<![a-z0-9])can (?:phai )?(?:de danh|tich luy|tich|tiet kiem|nap)(?![a-z0-9])');

/// Nhóm số của `danh_sach_muc_tieu` mà câu hỏi nhắm tới; `null` = câu chung,
/// hoặc câu về TRÍCH (đường riêng: `cauHoiVeTrich` + `ket_qua`).
String? nhomMucTieuTheoCauHoi(String cauHoi) {
  final q = _bo(cauHoi);
  if (q.isEmpty || _tuVeTrich.any((t) => _co(q, t))) return null;
  if (_mauCanTich.hasMatch(q) || (_co(q, 'muc tieu') && _co(q, 'moi') && _co(q, 'bao nhieu'))) {
    return kNhomMucTieuMoiKy;
  }
  if (_co(q, 'khi nao') || _co(q, 'bao gio') || _co(q, 'bao lau')) {
    return kNhomMucTieuKhiNao;
  }
  return null;
}

/// Câu LIỆT KÊ giao dịch: *"những lần …"*, *"<số> khoản / giao dịch …"*. ⚠️
/// *"bao nhiêu khoản"* là câu ĐẾM, *"những gì"* mô hình đã kể tốt (C13, F2).
final RegExp _mauLietKe = RegExp(
    r'(?<![a-z0-9])(?:(?:nhung|cac) lan|\d+ (?:khoan|giao dich))(?![a-z0-9])');

bool cauHoiLietKe(String cauHoi) => _mauLietKe.hasMatch(_bo(cauHoi));

/// A2 (2026-09-29): năm họ câu cũ về phiên MỘT tool. Số đo cổng F lần 1 trên
/// Realme: lượt sinh đầu 41,1 s ở phiên sáu tool, 15,6 s ở phiên một tool — và
/// ở mốc 72 câu mô hình đã tự chọn đúng tool đích này cho cả 18 câu của năm họ.
/// ⚠️ Mỗi họ có danh sách LOẠI: câu về giao dịch nhắc tên loại (*"ghi chú hoá
/// đơn"*, *"ví tiền mặt chi những gì"*, *"lần cuối nạp tiền cho mục tiêu"*) phải
/// ở lại tool giao dịch. Bỏ dấu nên `dat` là cả *đạt* lẫn *đặt*, `con` cả *còn*
/// lẫn *con* — chấp nhận, vì mỗi họ đã đòi thêm từ loại.
bool _coMot(String q, String ds) => ds.split('|').any((t) => _co(q, t));

/// ⚠️ *"thu nhập trung bình mỗi tháng"* là câu tổng quan: `goi_y_han_muc` trả
/// mức CHI theo danh mục.
///
/// Họ A (2026-10-04): xin mức NÊN đặt không chỉ là *"nên đặt"* — *"bao nhiêu là đủ /
/// vừa / hợp lý"*, *"nên để"*, *"nên là"* cũng thế; một danh sách cho cả hai luật.
const String _tuNenDat = 'nen dat|nen de|nen la|la du|la vua|hop ly';

bool _laCauGoiYHanMuc(String q) =>
    (_co(q, 'ngan sach') && _coMot(q, _tuNenDat)) ||
    (_co(q, 'trung binh moi thang') && !_coMot(q, 'thu nhap|thu|luong'));

bool _laCauNganSach(String q) =>
    _co(q, 'ngan sach') &&
    !_coMot(q, _tuNenDat) &&
    _coMot(q, 'nao|con|sap het|bao nhieu|chua dung|vuot');

bool _laCauMucTieu(String q) =>
    _co(q, 'muc tieu') &&
    !_coMot(q, 'nap|rut|lan cuoi|gan nhat|giao dich|khoan') &&
    _coMot(q, 'nao|khi nao|bao gio|cham|con thieu|tien do|dat');

bool _laCauHoaDon(String q) =>
    _co(q, 'hoa don') &&
    // `lan cuoi / lan truoc / lan gan nhat`: câu LỊCH SỬ trả — tool giao dịch (họ F).
    !_coMot(q,
        'ghi chu|giao dich|khoan chi|da tra|thanh toan hoa don|lan cuoi|lan truoc|lan gan nhat') &&
    _coMot(q, 'nao|bao nhieu|may|qua han|chua tra|den han|con phai tra|tu tra|thang toi|sap toi');

bool _laCauVi(String q) =>
    !_coMot(q, 'chi|thu|giao dich|khoan|chuyen') &&
    (_coMot(q, 'vi nao|may vi|bao nhieu vi') ||
        (_co(q, 'tong tai san') && !_coMot(q, 'tang|giam|thay doi')));

String? congCuTheoCauHoi(String cauHoi) {
  final q = _bo(cauHoi);
  if (q.isEmpty) return null;
  // Họ E (2026-10-04): ngân sách NHÀ NƯỚC — ngoài phạm vi app.
  if (_co(q, 'nha nuoc')) return null;
  // Họ B2: tầng 2 của dự báo mang chữ "ngân sách" — xét trước khối ngân sách.
  if (_mauDuBaoTheoNganSach.hasMatch(q)) return kTenCongCuDuBao;
  final haiLoai = _soLoaiDoiTuong(q) >= 2;
  if (_co(q, 'ngan sach')) {
    // Họ E: ngân sách + hoá đơn / mục tiêu → câu hai tool, phiên sáu tool.
    if (haiLoai) return null;
    // G4 cổng F (F15): câu CHUYỂN tiền giữa các ngân sách → tool ngân sách, phiên
    // một tool (bộ chỉnh đặt chon=can_doi). Sáu tool thì mô hình chọn goi_y_han_muc.
    if (_tuCanDoi.any((t) => _co(q, t))) return kTenCongCuNganSach;
    if (_laCauGoiYHanMuc(q)) return kTenCongCuGoiYHanMuc;
    if (_laCauNganSach(q)) return kTenCongCuNganSach;
    return null;
  }
  if (_laCauGoiYHanMuc(q)) return kTenCongCuGoiYHanMuc;
  if (_laCauTrichMucTieu(q)) return kTenCongCuMucTieu;
  if (_mauCanTich.hasMatch(q)) return kTenCongCuMucTieu;
  // Họ G: "hạn mức" là chữ của ngân sách — "trong hạn mức còn tiêu được" không
  // phải câu dự báo.
  if (!_co(q, 'han muc') && _mauDuBao.any((m) => m.hasMatch(q))) {
    return kTenCongCuDuBao;
  }
  if (_mauSoDuVi.any((m) => m.hasMatch(q))) return kTenCongCuVi;
  if (_laCauVi(q)) return kTenCongCuVi;
  // Họ E: hoá đơn + mục tiêu mà không phải câu đủ tiền (dự báo đã xét ở trên).
  if (haiLoai) return null;
  if (_laCauMucTieu(q)) return kTenCongCuMucTieu;
  if (_co(q, 'muc tieu')) return null;
  if (_laCauHoaDon(q)) return kTenCongCuHoaDon;
  if (!_co(q, 'nhat') &&
      (_mauDanhMuc.any((m) => m.hasMatch(q)) ||
          (_mauDanhMucTheoLoai.hasMatch(q) && !_coSoHoacKy(q)))) {
    return kTenCongCuDanhMuc;
  }
  if (_laCauDinhNghia(q) || _mauLoaiThuNhap.hasMatch(q)) return null;
  if (_mauTongQuan.any((m) => m.hasMatch(q))) return kTenCongCuTongQuan;
  return null;
}

/// Lát 3 (người dùng chốt 2026-09-28): câu về TRÍCH TỰ ĐỘNG cho mục tiêu — ví
/// có đủ trích không, kỳ trích tiếp, trích mỗi tháng — đi tool mục tiêu, thứ
/// nay mang lịch trích và kết luận ví nguồn; xét TRƯỚC tool dự báo (cụm *"đủ
/// tiền trích"* của nó từng bắt F13). Câu nhắc cả hoá đơn → dự báo (gộp hai loại
/// cam kết). Câu về LỊCH SỬ trích → đường cũ: tool mục tiêu không có lịch sử nạp.
final List<String> _tuTrichMucTieu =
    'ky trich|trich tiep|trich moi|trich tu dong|tu dong trich'.split('|');
final List<String> _tuLichSuTrich =
    'da trich|vua trich|gan nhat|lan cuoi|gan day'.split('|');

bool _laCauTrichMucTieu(String q) =>
    _co(q, 'trich') &&
    !_co(q, 'hoa don') &&
    !_tuLichSuTrich.any((t) => _co(q, t)) &&
    (_co(q, 'muc tieu') || _tuTrichMucTieu.any((t) => _co(q, t)));

/// G1 cổng F (mục 9.36): câu hỏi có NÓI VỀ trích tự động / ví nguồn không. Tool
/// mục tiêu chỉ mang chữ trích (hậu tố ví, kỳ trích tiếp, kết luận ví nguồn) khi
/// có — B1 *"khi nào đạt MuaXe"* từng nhận *"đặt ngân sách vì ví nguồn không
/// đủ"*, DC1 *"lãi suất tiết kiệm"* nhận kết luận ví nguồn: chữ thật mà lạc đề.
final List<String> _tuVeTrich = 'trich|vi nguon|tu dong'.split('|');

bool cauHoiVeTrich(String cauHoi) {
  final q = _bo(cauHoi);
  return q.isNotEmpty && _tuVeTrich.any((t) => _co(q, t));
}

/// G1 cổng F (E7): câu hỏi SỐ DƯ ví → `danh_sach_vi`. Mô hình từng chọn tool
/// mục tiêu cho *"Ví Tiết kiệm hiện có bao nhiêu tiền"* (chữ "tiết kiệm").
/// ⚠️ *"bao nhiêu giao dịch / khoản / lần"* là câu giao dịch — bị loại.
final List<RegExp> _mauSoDuVi = [
  RegExp(r'(?<![a-z0-9])vi\b.*\b(?:con|co|hien co|hien con|dang co)\s+(?:bao nhieu|may)'
      r'(?!\s+(?:giao dich|khoan|lan|danh muc|hoa don|muc tieu|ngan sach))(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])so du(?: cua)?(?: cac| nhung)? vi(?![a-z0-9])'),
];

String _ddmmyyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "so với / hơn / bằng <đơn vị> trước" — kỳ liền trước; đơn vị của cụm cũng là
/// kỳ gốc NGẦM khi câu không nêu kỳ gốc ("hơn tuần trước" → tuần này).
final RegExp _mauSoVoiKyTruoc = RegExp(
    r'(?<![a-z0-9])(?:so voi|so sanh voi|hon|bang)\s+(thang|tuan|quy|nam|ky) truoc(?![a-z0-9])');
final RegExp _mauSoVoiNamTruoc = RegExp(
    r'(?<![a-z0-9])(?:(?:so voi |so sanh voi |hon |bang )?cung ky (?:cua )?nam (?:truoc|ngoai)|(?:so voi|so sanh voi|hon|bang) nam ngoai)(?![a-z0-9])');

({String ma, RegExp mau, String kyGocNgam})? _soSanhTrongCau(String q) {
  if (_mauSoVoiNamTruoc.hasMatch(q)) {
    return (ma: 'cung_ky_nam_truoc', mau: _mauSoVoiNamTruoc, kyGocNgam: 'thang_nay');
  }
  final m = _mauSoVoiKyTruoc.firstMatch(q);
  if (m == null) return null;
  final goc = switch (m.group(1)) {
    'tuan' => 'tuan_nay',
    'quy' => 'quy_nay',
    'nam' => 'nam_nay',
    _ => 'thang_nay',
  };
  return (ma: 'ky_truoc', mau: _mauSoVoiKyTruoc, kyGocNgam: goc);
}

/// Kỳ gốc NÊU RÕ trong câu so sánh ("thang nay … thang truoc" → thang_nay).
String? _kyGocNeu(String q) {
  for (final ma in ['hom_nay', 'tuan_nay', 'thang_nay', 'quy_nay', 'nam_nay']) {
    if (_co(q, ma)) return ma;
  }
  return null;
}

/// Phép chọn trong câu: "nhiều / lớn / cao … nhất" → `nhieu_nhat` (thắng khi câu
/// có cả hai); "ít / nhỏ / thấp … nhất" → `it_nhat`, TRỪ khi ngay sau là một số
/// tiền — *"ít nhất 200k"* là ngưỡng của luật 4, không phải chọn.
String? _chonTrongCau(String q) {
  final mauSo = RegExp('^(?:${_mauSoDonVi.pattern})');
  String? kq;
  for (final m in _mauChon.allMatches(q)) {
    final dau = m.group(1)!;
    if (dau == 'nhieu' || dau == 'lon' || dau == 'cao') return 'nhieu_nhat';
    final sau = q.substring(m.end).trimLeft();
    if (mauSo.hasMatch(sau) || _cumSoChu(sau).any((c) => c.batDau == 0)) continue;
    kq ??= 'it_nhat';
  }
  return kq;
}

bool _coCaHaiChieu(String q0) {
  var q = q0;
  for (final c in _cumKhongPhaiDongTu) {
    q = q.replaceAll(_tronTu(c), ' ');
  }
  return _tuThu.any((t) => _co(q, t)) && _tuChi.any((t) => _co(q, t));
}

/// Bộ chỉnh của `danh_sach_ngan_sach` (spec tool truy vấn mục 4): cùng khuôn,
/// một luật — chữ về tỉ lệ đã dùng trong câu → `chon`.
final List<String> _tuDuoiNua =
    'chua dung den mot nua|duoi nua|chua den nua|duoi mot nua|chua toi nua'.split('|');
final List<String> _tuTrenNua = 'qua nua|hon nua|tren nua'.split('|');
final List<String> _tuNganSachCang = 'sap het|cang nhat|dung nhieu nhat|vuot'.split('|');
final List<String> _tuNganSachRong = 'it dung nhat|con nhieu nhat|dung it nhat'.split('|');
/// Lát 3 Task 11: hỏi CHUYỂN tiền giữa các ngân sách → `can_doi`, xét trước mọi
/// mã khác (F15 *"nên chuyển bớt ngân sách nào sang ngân sách nào"* không có chữ
/// tỉ lệ nào nhưng *"ngân sách nào sắp hết thì bù từ đâu"* có *"sắp hết"*).
final List<String> _tuCanDoi =
    'can doi|chuyen bot|lay tu ngan sach|de bu|bu cho|bu tu|bu vao|bu dap|don ngan sach|tai phan bo'
        .split('|');
/// "chưa đặt / chưa có / không có ngân sách" → `chua_dat` (câu người dùng 2026-09-27).
final List<String> _tuChuaDat =
    'chua dat ngan sach|chua co ngan sach|khong co ngan sach|chua dat|chua co han muc'.split('|');

KetQuaChinhThamSo chinhThamSoNganSach(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? chon;
  if (_tuCanDoi.any((t) => _co(q, t))) {
    chon = 'can_doi';
  } else if (_tuChuaDat.any((t) => _co(q, t))) {
    chon = 'chua_dat';
  } else if (_tuDuoiNua.any((t) => _co(q, t))) {
    chon = 'duoi_nua';
  } else if (_tuTrenNua.any((t) => _co(q, t))) {
    chon = 'tren_nua';
  } else if (_tuNganSachCang.any((t) => _co(q, t))) {
    chon = 'nhieu_nhat';
  } else if (_tuNganSachRong.any((t) => _co(q, t))) {
    chon = 'it_nhat';
  }
  if (chon != null && a['chon'] != chon) {
    a['chon'] = chon;
    ghi.add('câu hỏi về tỉ lệ đã dùng → chon=$chon');
  }
  // Luật 10: không chữ nào về tỉ lệ / nhất mà mô hình điền chon → gỡ (E10 cổng E).
  if (chon == null && _chuoi(a['chon']) != null) {
    a.remove('chon');
    ghi.add('câu hỏi không nói tỉ lệ / nhất → bỏ chon');
  }
  return KetQuaChinhThamSo(a, ghi);
}

/// Bộ chỉnh của `danh_sach_hoa_don` (lát 3, spec mở rộng tool §5.1): kỳ nêu
/// trong câu → `ky`; không nêu → gỡ `ky` mô hình điền (luật 10). Câu về *tự
/// trả* / *cố định mỗi tháng* không đổi tham số — số đã nằm trong tổng hợp.
///
/// ⚠️ Cùng bẫy với `_laKyTuongLai`: bỏ dấu thì *"tới"* và *"tôi"* là một chữ,
/// nên câu có dấu đọc trên bản CÓ DẤU; câu gõ không dấu thì *"thang toi"* chỉ
/// là *tháng tới* khi theo sau là *toi / phai / can / se / co* hay hết câu.
final RegExp _mauHoaDonKyToiCoDau = RegExp(
  r'(?<![\p{L}\p{N}])(?:tháng|kỳ|kì)\s+(?:tới|sau|sắp tới|kế tiếp)(?![\p{L}\p{N}])',
  unicode: true,
);
final RegExp _mauHoaDonKyToiKhongDau = RegExp(
  r'(?<![a-z0-9])(?:(?:thang|ky) (?:sau|sap toi|ke tiep)'
  r'|(?:thang|ky) toi(?= toi| phai| can| se| co|$))(?![a-z0-9])',
);
final RegExp _mauHoaDonMoiKy = RegExp(
  r'(?<![a-z0-9])(?:tat ca|toan bo|moi)(?: cac| nhung)? hoa don(?![a-z0-9])',
);

KetQuaChinhThamSo chinhThamSoHoaDon(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? ky;
  final kyToi = _coDau.hasMatch(cauHoi)
      ? _mauHoaDonKyToiCoDau.hasMatch(normalizeCategoryName(cauHoi))
      : _mauHoaDonKyToiKhongDau.hasMatch(q);
  if (kyToi) {
    ky = 'ky_toi';
  } else if (_mauHoaDonMoiKy.hasMatch(q)) {
    ky = 'tat_ca';
  }
  // G3 cổng F (F12): "hoá đơn nào tự trả" → `tu_tra` (không khai cho mô hình);
  // kỳ không nêu → mọi kỳ: kỳ tự trả sắp tới thường đã sang tháng sau. Cổng F
  // đo được mô hình tự dò ba lần ba kỳ rồi trả lời "2 hoá đơn quá hạn".
  final tuTra = _mauTuTra.hasMatch(q);
  if (tuTra && ky == null) ky = 'tat_ca';
  if (ky != null && a['ky'] != ky) {
    a['ky'] = ky;
    ghi.add('câu hỏi nêu kỳ hoá đơn → ky=$ky');
  }
  if (ky == null && _chuoi(a['ky']) != null) {
    a.remove('ky');
    ghi.add('câu hỏi không nêu kỳ hoá đơn → bỏ ky');
  }
  if (tuTra && a['tu_tra'] != true) {
    a['tu_tra'] = true;
    ghi.add('câu hỏi về hoá đơn tự trả → tu_tra');
  } else if (!tuTra && a.containsKey('tu_tra')) {
    a.remove('tu_tra');
    ghi.add('câu hỏi không nói tự trả → bỏ tu_tra');
  }
  // F12 tụt (mục 9.38, luật 10 — họ bẫy 4.44): câu tự trả KHÔNG nêu trạng thái trả mà mô hình điền `trang_thai` →
  // gỡ, tool dùng mặc định `chua_tra`. Đo Realme 2026-09-29: phiên một tool điền `da_tra`, tool lọc "tự trả VÀ đã
  // trả" → một kỳ đã trả, câu trả lời "Netflix đã được trả" trong khi kỳ sau còn phải trả. Chỉ áp cho câu tự trả:
  // câu hoá đơn thường giữ hành vi cũ.
  if (tuTra && !_mauTrangThaiTra.hasMatch(q) && _chuoi(a['trang_thai']) != null) {
    a.remove('trang_thai');
    ghi.add('câu hỏi tự trả không nêu trạng thái trả → bỏ trang_thai');
  }
  return KetQuaChinhThamSo(a, ghi);
}

/// Câu hỏi NÊU trạng thái trả của hoá đơn — khi ấy `trang_thai` của mô hình có chỗ bám, giữ nguyên.
final RegExp _mauTrangThaiTra = RegExp(
  r'(?<![a-z0-9])(?:da tra|chua tra|con phai tra|qua han|tre han|da thanh toan|chua thanh toan)(?![a-z0-9])',
);

/// "tự trả / tự động trả / tự động thanh toán" — ⚠️ *"phải tự trả"* là trả TAY.
final RegExp _mauTuTra = RegExp(
  r'(?<![a-z0-9])(?<!phai )(?:tu tra|tu dong tra|tu dong thanh toan|thanh toan tu dong|tra tu dong)(?![a-z0-9])',
);

/// Bộ chỉnh của `danh_sach_muc_tieu` (cổng E lần 1, E11): trạng thái nêu trong
/// câu → `chon`; không nêu → gỡ `chon` mô hình điền thừa (luật 10).
final List<String> _tuMucTieuCham = 'cham ke hoach|cham tien do|bi cham|dang cham|cham|tre|khong kip'.split('|');
final List<String> _tuMucTieuQuaHan = 'qua han|tre han|het han'.split('|');
final List<String> _tuMucTieuDung = 'dung ke hoach|dung tien do|dung nhip|dang on'.split('|');
/// Lát 3 Task 10. ⚠️ *"có đủ … không"* (F13) là câu hỏi CHUNG, không phải lọc.
final List<String> _tuMucTieuViKhongDu =
    'vi khong du|khong du tien trich|khong du de trich|khong du tien de trich|thieu tien trich|thieu tien de trich'
        .split('|');

KetQuaChinhThamSo chinhThamSoMucTieu(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? chon;
  // Ví không đủ xét trước tiên — cờ của trích tự động, câu có thể nhắc thêm
  // "chậm". Quá hạn trước chậm: "trễ hạn" chứa "trễ".
  if (_tuMucTieuViKhongDu.any((t) => _co(q, t))) {
    chon = 'vi_khong_du';
  } else if (_tuMucTieuQuaHan.any((t) => _co(q, t))) {
    chon = 'qua_han';
  } else if (_tuMucTieuCham.any((t) => _co(q, t))) {
    chon = 'cham_ke_hoach';
  } else if (_tuMucTieuDung.any((t) => _co(q, t))) {
    chon = 'dung_ke_hoach';
  }
  if (chon != null && a['chon'] != chon) {
    a['chon'] = chon;
    ghi.add('câu hỏi nêu trạng thái mục tiêu → chon=$chon');
  }
  if (chon == null && _chuoi(a['chon']) != null) {
    a.remove('chon');
    ghi.add('câu hỏi không nêu trạng thái → bỏ chon');
  }
  return KetQuaChinhThamSo(a, ghi);
}

/// Cụm mang chữ chiều tiền mà KHÔNG nói chiều: "mục tiêu" có "tiêu" (C20 lần
/// 12: khoản nạp mục tiêu là chuyển ví, bộ chỉnh đọc thành khoản chi). Bỏ khỏi
/// câu trước khi dò động từ.
final List<String> _cumKhongPhaiDongTu = 'muc tieu|tieu de|chi tiet'.split('|');

final RegExp _mauGhiChu = RegExp(r'(?<![a-z0-9])ghi chu\s+(.+)$');
final RegExp _duoiCauHoi =
    RegExp(r'\s+(khong|nao|la gi|gi|la|thang|tuan|nam|quy|hom|trong|cua)(\s.*)?$');

/// Chữ đứng sau "ghi chú" trong câu hỏi (đã bỏ dấu), cắt bỏ đuôi câu hỏi
/// ("… hoa don khong" → "hoa don"); `null` khi câu không nói ghi chú.
String? _sauGhiChu(String q) {
  final m = _mauGhiChu.firstMatch(q);
  if (m == null) return null;
  final s = m.group(1)!.replaceFirst(_duoiCauHoi, '').trim();
  return s.isEmpty ? null : s;
}

String? _chieuTheoDongTu(String q0) {
  var q = q0;
  for (final c in _cumKhongPhaiDongTu) {
    q = q.replaceAll(_tronTu(c), ' ');
  }
  final thu = _tuThu.any((t) => _co(q, t));
  final chi = _tuChi.any((t) => _co(q, t));
  if (thu == chi) return null;
  return thu ? 'khoan_thu' : 'khoan_chi';
}

({int? tu, int? den}) _nguongTrongCau(String q) {
  int? tu;
  int? den;
  final khoang = <(int, int, double)>[];
  for (final m in _mauSoDonVi.allMatches(q)) {
    final tho = m.group(1)!;
    final dv = m.group(2);
    double gia;
    if (dv != null) {
      final chuan = tho.replaceAll(',', '.');
      gia = chuan.split('.').length > 2
          ? double.parse(chuan.replaceAll('.', ''))
          : double.parse(chuan);
      gia *= _donVi[dv]!;
    } else {
      final soChuSo = tho.replaceAll(RegExp(r'[.,]'), '');
      if (soChuSo.length < 4 || tho.contains(RegExp(r'[.,]\d{1,2}$'))) continue;
      gia = double.parse(soChuSo);
    }
    khoang.add((m.start, m.end, gia));
  }
  for (final c in _cumSoChu(q)) {
    khoang.add((c.batDau, c.ketThuc, c.giaTri));
  }
  for (final (bd, kt, gia) in khoang) {
    final truoc = q.substring(0, bd).trim().split(RegExp(r'\s+'));
    final sau = q.substring(kt).trim();
    final baTruoc = truoc.length <= 3 ? truoc.join(' ') : truoc.sublist(truoc.length - 3).join(' ');
    final v = gia.round();
    if (sau.startsWith('tro len') || _tuTu.any((t) => _cuoi(baTruoc, t))) {
      tu = v;
    } else if (_tuDen.any((t) => _cuoi(baTruoc, t))) {
      den = v;
    }
  }
  return (tu: tu, den: den);
}

/// Câu có SỐ TIỀN không: số kèm đơn vị (*500k, 1 triệu*), số chữ (*nửa triệu*),
/// hay số trần từ bốn chữ số. ⚠️ Ngày (*1/9*, *15/9/2026*) và năm (*năm 2026*)
/// không phải tiền — cùng cách đọc với luật 4.
bool _coSoTien(String q) {
  if (_cumSoChu(q).isNotEmpty) return true;
  for (final m in _mauSoDonVi.allMatches(q)) {
    if (m.group(2) != null) return true;
    if (m.start > 0 && q[m.start - 1] == '/') continue;
    if (m.end < q.length && q[m.end] == '/') continue;
    if (RegExp(r'(?<![a-z0-9])nam\s*$').hasMatch(q.substring(0, m.start))) continue;
    if (m.group(1)!.replaceAll(RegExp(r'[.,]'), '').length >= 4) return true;
  }
  return false;
}

/// [cum] đứng cuối [chuoi] (là từ cuối, hay hai từ cuối).
bool _cuoi(String chuoi, String cum) =>
    RegExp('(?<![a-z0-9])${RegExp.escape(cum)}\$').hasMatch(chuoi);

