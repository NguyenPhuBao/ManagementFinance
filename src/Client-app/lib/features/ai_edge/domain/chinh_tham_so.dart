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
///    / `den_ngay`; thắng luật 5.
/// 12. **So sánh hai kỳ** (E13): *so với / hơn tháng trước* → `so_voi=ky_truoc`;
///    *cùng kỳ năm trước / năm ngoái* → `cung_ky_nam_truoc`. `ky` là kỳ GỐC —
///    kỳ đang nói — chứ không phải kỳ đem ra so; câu không so sánh mà mô hình
///    điền `so_voi` → gỡ (cùng lý lẽ luật 10).
/// 6. **Không đụng** giá trị mà câu hỏi không nói tới — TRỪ `chon` (luật 10):
///    cổng E lần 1 (9.32) đo được mô hình điền `chon: nhieu_nhat` cho *"liệt kê
///    các khoản chi…"* (C9) và *"5 khoản chi gần đây nhất"* (C16) nên chỉ còn
///    một hàng; câu không có *"…nhất"* thì `chon` không có bằng chứng → gỡ.
///    Cùng luật cho `chinhThamSoNganSach` (E10 `duoi_nua` thừa) và
///    `chinhThamSoMucTieu`.
///
/// So trên chữ **bỏ dấu** — đúng chỗ của `removeVietnameseTones` (đọc tham số,
/// như `khop_ten.dart`), không phải quy tắc trùng tên. ⚠️ Từ khoá chiều tiền
/// giữ dạng **chuỗi tách lúc chạy**: test quét 14 cấm `'chi'` / `'thu'` đứng
/// riêng trong `ai_edge/` — ở đây chúng là chữ của câu hỏi.
library;

import '../../../core/category/category_name.dart';
import 'cong_cu.dart';
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
  required DateTime now,
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
  // ⚠️ Tên trùng với TỪ KHOÁ ghi chú mô hình đã điền thì không phải danh mục
  // (C17 lần 13: "ghi chú hoa don" ↔ danh mục "Hóa đơn" → lọc thêm danh mục →
  // 0 khoản).
  final tuKhoaBo = _bo(_chuoi(a['tu_khoa']) ?? '');
  // Chữ đứng sau "ghi chú" trong CÂU HỎI là từ khoá ghi chú, không phải danh mục
  // (C17 lần 14 trên OnePlus: mô hình bỏ trống tu_khoa nên vế trên không cứu).
  final sauGhiChu = _sauGhiChu(q);
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
  RegExp(r'(?<![a-z0-9])(?:tra|thanh toan) (?:het|xong)\b.*\bcon(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])\d+ (?:ngay|tuan|thang) (?:toi|sap toi|nua)\b.*\b(?:phai|can|se) (?:tra|chi|dong)(?![a-z0-9])'),
  RegExp(r'(?<![a-z0-9])sap (?:toi )?(?:toi )?(?:phai|can) (?:tra|chi|dong)(?![a-z0-9])'),
];

String? congCuTheoCauHoi(String cauHoi) {
  final q = _bo(cauHoi);
  if (q.isEmpty) return null;
  if (_co(q, 'ngan sach')) return null;
  if (_mauDuBao.any((m) => m.hasMatch(q))) return kTenCongCuDuBao;
  return null;
}

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
  final mauSo = RegExp('^(?:${_mauSoDonVi.pattern}|${_mauSoChu.pattern})');
  String? kq;
  for (final m in _mauChon.allMatches(q)) {
    final dau = m.group(1)!;
    if (dau == 'nhieu' || dau == 'lon' || dau == 'cao') return 'nhieu_nhat';
    final sau = q.substring(m.end).trimLeft();
    if (mauSo.hasMatch(sau)) continue;
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
/// "chưa đặt / chưa có / không có ngân sách" → `chua_dat` (câu người dùng 2026-09-27).
final List<String> _tuChuaDat =
    'chua dat ngan sach|chua co ngan sach|khong co ngan sach|chua dat|chua co han muc'.split('|');

KetQuaChinhThamSo chinhThamSoNganSach(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? chon;
  if (_tuChuaDat.any((t) => _co(q, t))) {
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

/// Bộ chỉnh của `danh_sach_muc_tieu` (cổng E lần 1, E11): trạng thái nêu trong
/// câu → `chon`; không nêu → gỡ `chon` mô hình điền thừa (luật 10).
final List<String> _tuMucTieuCham = 'cham ke hoach|cham tien do|bi cham|dang cham|cham|tre|khong kip'.split('|');
final List<String> _tuMucTieuQuaHan = 'qua han|tre han|het han'.split('|');
final List<String> _tuMucTieuDung = 'dung ke hoach|dung tien do|dung nhip|dang on'.split('|');

KetQuaChinhThamSo chinhThamSoMucTieu(String cauHoi, Map<String, dynamic> args) {
  final a = Map<String, dynamic>.from(args);
  final ghi = <String>[];
  final q = _bo(cauHoi);
  if (q.isEmpty) return KetQuaChinhThamSo(a, ghi);
  String? chon;
  // Quá hạn xét trước: "trễ hạn" chứa "trễ".
  if (_tuMucTieuQuaHan.any((t) => _co(q, t))) {
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
