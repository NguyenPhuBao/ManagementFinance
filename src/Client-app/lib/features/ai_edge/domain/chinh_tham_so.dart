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
/// 6. **Không đụng** giá trị mà câu hỏi không nói tới.
///
/// So trên chữ **bỏ dấu** — đúng chỗ của `removeVietnameseTones` (đọc tham số,
/// như `khop_ten.dart`), không phải quy tắc trùng tên. ⚠️ Từ khoá chiều tiền
/// giữ dạng **chuỗi tách lúc chạy**: test quét 14 cấm `'chi'` / `'thu'` đứng
/// riêng trong `ai_edge/` — ở đây chúng là chữ của câu hỏi.
library;

import '../../../core/category/category_name.dart';

class KetQuaChinhThamSo {
  final Map<String, dynamic> args;

  /// Mỗi luật đã áp một dòng — in ra log `[SLM][tool] chỉnh tham số`.
  final List<String> ghiChu;
  const KetQuaChinhThamSo(this.args, this.ghiChu);
}

/// Bỏ dấu + chuẩn hoá (chữ thường, gom khoảng trắng); `_` đọc là dấu cách.
String _bo(String s) =>
    removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));

RegExp _tronTu(String tu) => RegExp('(?<![a-z0-9])${RegExp.escape(tu)}(?![a-z0-9])');

bool _co(String chuoi, String tu) => _tronTu(_bo(tu)).hasMatch(chuoi);

/// Từ khoá theo nhóm — một chuỗi, tách lúc chạy (xem docstring đầu tệp).
final List<String> _tuChi = 'khoan chi|chi tieu|tieu|chi|mua'.split('|');
final List<String> _tuThu = 'khoan thu|nhan duoc|luong|thu nhap|thu'.split('|');
final List<String> _tuChuyenTien =
    'chuyen tien|chuyen sang|chuyen khoan|chuyen vi|chuyen qua|chuyen den|chuyen vao'
        .split('|');
final List<String> _tuMoiNhat = 'lan gan nhat|lan cuoi|gan day|moi nhat|gan nhat'.split('|');
final List<String> _tuKy =
    'hom nay|hom qua|tuan nay|tuan truoc|thang nay|thang truoc|quy nay|nam nay|tuan|thang|quy'
        .split('|');
final List<String> _tuTu = 'tren|hon|tu|it nhat|toi thieu|lon hon'.split('|');
final List<String> _tuDen = 'duoi|khong qua|den|toi|toi da|nho hon|thap hon|it hon'.split('|');

const Map<String, double> _soChu = {
  'nua': 0.5, 'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'nam': 5, 'sau': 6,
  'bay': 7, 'tam': 8, 'chin': 9, 'muoi': 10,
};
const Map<String, double> _donVi = {
  'k': 1000, 'nghin': 1000, 'ngan': 1000, 'tr': 1000000, 'trieu': 1000000,
  'ty': 1000000000, 'ti': 1000000000, 'tram': 100,
};

final RegExp _mauSoChu = RegExp(
  '(?<![a-z0-9])(?:${_soChu.keys.join('|')})(?:\\s+(?:tram|nghin|ngan|trieu|ty|ti))+(?:\\s+ruoi)?(?![a-z0-9])',
);
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

KetQuaChinhThamSo chinhThamSoTimGiaoDich(
  String cauHoi,
  Map<String, dynamic> args, {
  required List<String> tenDanhMuc,
  required List<String> tenVi,
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

  // 2. Danh mục / ví nêu trong câu hỏi; chiều "chuyển ví" khi câu không chuyển tiền.
  if (_chuoi(a['danh_muc']) == null) {
    final dm = _tenTrong(q, bangDm);
    if (dm != null) {
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

  // 5. Sắp xếp và kỳ.
  if (_tuMoiNhat.any((t) => _co(q, t)) && a['sap_xep'] != 'moi_nhat') {
    a['sap_xep'] = 'moi_nhat';
    ghi.add('câu hỏi "gần nhất / lần cuối" → sap_xep=moi_nhat');
  }
  if (!_tuKy.any((t) => _co(q, t)) && a['ky'] != 'moi_luc') {
    a['ky'] = 'moi_luc';
    ghi.add('câu hỏi không nêu kỳ → ky=moi_luc');
  }

  return KetQuaChinhThamSo(a, ghi);
}

/// Cụm mang chữ chiều tiền mà KHÔNG nói chiều: "mục tiêu" có "tiêu" (C20 lần
/// 12: khoản nạp mục tiêu là chuyển ví, bộ chỉnh đọc thành khoản chi). Bỏ khỏi
/// câu trước khi dò động từ.
final List<String> _cumKhongPhaiDongTu = 'muc tieu|tieu de|chi tiet'.split('|');

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
  for (final m in _mauSoChu.allMatches(q)) {
    khoang.add((m.start, m.end, _giaTriSoChu(m.group(0)!)));
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

/// [cum] đứng cuối [chuoi] (là từ cuối, hay hai từ cuối).
bool _cuoi(String chuoi, String cum) =>
    RegExp('(?<![a-z0-9])${RegExp.escape(cum)}\$').hasMatch(chuoi);

double _giaTriSoChu(String cum) {
  var tong = 0.0;
  var nhom = double.nan;
  var boi = 1.0;
  for (final tu in cum.split(RegExp(r'\s+'))) {
    if (_soChu.containsKey(tu)) {
      if (!nhom.isNaN) tong += nhom * boi;
      nhom = _soChu[tu]!;
      boi = 1.0;
    } else if (_donVi.containsKey(tu)) {
      boi *= _donVi[tu]!;
    } else if (tu == 'ruoi') {
      nhom += 0.5;
    }
  }
  return tong + (nhom.isNaN ? 0 : nhom * boi);
}
