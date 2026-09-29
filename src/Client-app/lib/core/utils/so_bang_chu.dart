/// Số viết bằng CHỮ trong một câu tiếng Việt — **định nghĩa duy nhất** (C2 task 1, spec
/// `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2.6).
///
/// Ba nơi đọc: ô *Nhập nhanh* của màn Thêm giao dịch (`docCauGiaoDich`), bộ kiểm số của Trợ lý AI (`kiem_so.dart` —
/// số chữ cũng là con số, bẫy 4.42) và bộ chỉnh tham số (`chinh_tham_so.dart` — ngưỡng tiền của câu hỏi). Trước
/// 2026-09-29 hai tệp sau mỗi tệp một bộ đọc riêng, và **cả hai mù hàng chục**: *"năm mươi nghìn"* ra rỗng, nên
/// *"dưới năm mươi nghìn"* không thành ngưỡng nào trong khi *"dưới 50k"* thì có.
///
/// Luật:
/// - Một cụm phải **kết thúc bằng đơn vị** (*trăm, nghìn / ngàn, triệu, tỷ / tỉ*) hoặc *rưỡi*. Từ số đứng không có đơn
///   vị không phải số: *"một khoản"*, *"năm nay"*; *"hai triệu năm nay"* chỉ đọc *"hai triệu"*. Đơn vị đứng một mình
///   (*"hàng triệu"*) cũng không.
/// - Hàng chục: *mười* (10) · *X mươi* / *X chục* (X·10) · ngay sau hàng chục: chữ số, hoặc *mốt* (1), *tư* (4),
///   *lăm / nhăm* (5) · *linh / lẻ* là hàng chục bằng 0 (*"một trăm linh năm"* = 105).
/// - *rưỡi*: sau *trăm* là +50; sau *nghìn / triệu / tỷ* là thêm nửa đơn vị ấy (*"một triệu rưỡi"*). *nửa* = 0,5.
/// - Đơn vị liền nhau **nhân** nhau (*"một nghìn tỷ"*), như bộ đọc trước lượt này.
/// - Lượng từ mơ hồ (*vài, mấy, dăm*) cho `NaN` — một số không bao giờ khớp số thật. Người gọi nào không muốn chúng thì
///   tự lọc `isNaN`.
/// - Mỗi từ khớp dạng **có dấu** hoặc dạng **không dấu hoàn toàn** — người gõ nhanh viết *"nam muoi nghin"*. ⚠️ Không bỏ
///   dấu cả câu: *"một tí"* bỏ dấu thành *"mot ti"* = một tỉ. Từ có dấu mà dấu khác (*tí*) thì không phải từ số. *muoi*
///   không dấu là *mươi* khi có chữ số đứng trước, là *mười* khi không.
///
/// Vị trí trả về là vị trí trong **chính** [cau] (kể cả câu tách dấu NFD), để người gọi cắt / thay đúng đoạn ấy.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../category/category_name.dart';

/// Một cụm số chữ: `[batDau, ketThuc)` trong câu, và giá trị (`NaN` khi mơ hồ).
typedef CumSoChu = ({int batDau, int ketThuc, double giaTri});

enum _Loai { so, soSauChuc, chuc, muoi, muoiKhongDau, linh, tram, bac, ruoi }

class _Tu {
  final _Loai loai;
  final double giaTri;
  const _Tu(this.loai, [this.giaTri = 0]);
}

const Map<String, _Tu> _coDau = {
  'nửa': _Tu(_Loai.so, 0.5),
  'một': _Tu(_Loai.so, 1),
  'hai': _Tu(_Loai.so, 2),
  'ba': _Tu(_Loai.so, 3),
  'bốn': _Tu(_Loai.so, 4),
  'năm': _Tu(_Loai.so, 5),
  'sáu': _Tu(_Loai.so, 6),
  'bảy': _Tu(_Loai.so, 7),
  'bẩy': _Tu(_Loai.so, 7),
  'tám': _Tu(_Loai.so, 8),
  'chín': _Tu(_Loai.so, 9),
  'vài': _Tu(_Loai.so, double.nan),
  'mấy': _Tu(_Loai.so, double.nan),
  'dăm': _Tu(_Loai.so, double.nan),
  'mốt': _Tu(_Loai.soSauChuc, 1),
  'tư': _Tu(_Loai.soSauChuc, 4),
  'lăm': _Tu(_Loai.soSauChuc, 5),
  'nhăm': _Tu(_Loai.soSauChuc, 5),
  'mươi': _Tu(_Loai.chuc),
  'chục': _Tu(_Loai.chuc),
  'mười': _Tu(_Loai.muoi),
  'linh': _Tu(_Loai.linh),
  'lẻ': _Tu(_Loai.linh),
  'trăm': _Tu(_Loai.tram),
  'nghìn': _Tu(_Loai.bac, 1000),
  'ngàn': _Tu(_Loai.bac, 1000),
  'triệu': _Tu(_Loai.bac, 1000000),
  'tỷ': _Tu(_Loai.bac, 1000000000),
  'tỉ': _Tu(_Loai.bac, 1000000000),
  'rưỡi': _Tu(_Loai.ruoi),
};

/// Dạng không dấu của [_coDau]. Hai từ trùng dạng không dấu thì từ ĐẦU thắng: *một* trước *mốt* (nên `mot` đứng đầu
/// cụm được), và *muoi* (mười / mươi) đặt sẵn để đọc theo ngữ cảnh.
final Map<String, _Tu> _khongDau = () {
  final m = <String, _Tu>{'muoi': const _Tu(_Loai.muoiKhongDau)};
  for (final e in _coDau.entries) {
    m.putIfAbsent(removeVietnameseTones(e.key), () => e.value);
  }
  return m;
}();

final RegExp _tu = RegExp(r'[\p{L}\p{M}]+', unicode: true);
final RegExp _chiAscii = RegExp(r'^[a-z]+$');
final RegExp _chuSo = RegExp(r'\p{N}', unicode: true);
final RegExp _chiKhoangTrang = RegExp(r'^\s+$');

_Tu? _nghiaCua(String tu) {
  final k = unorm.nfc(tu).toLowerCase();
  return _coDau[k] ?? (_chiAscii.hasMatch(k) ? _khongDau[k] : null);
}

/// Mọi cụm số chữ trong [cau], theo thứ tự câu.
///
/// [batBuocDonVi] `false` (chỉ lớp kiểm số tiền của ô Nhập nhanh đọc bằng AI dùng, C2 §2.8) nhận thêm cụm KHÔNG có đơn vị
/// nhưng có hàng chục: *"ba chục"* = 30, *"hai mươi lăm"* = 25 — người nói tiền hay bỏ chữ *nghìn*. Chữ số đứng một mình
/// (*"một"*, *"năm"*) vẫn không phải cụm: đó là *"một khoản"*, *"năm nay"*.
List<CumSoChu> timSoBangChu(String cau, {bool batBuocDonVi = true}) {
  final tu = [
    for (final m in _tu.allMatches(cau)) (batDau: m.start, ketThuc: m.end, nghia: _nghiaCua(m.group(0)!)),
  ];
  final kq = <CumSoChu>[];
  var i = 0;
  while (i < tu.length) {
    final dau = tu[i];
    if (dau.nghia == null || (dau.batDau > 0 && _chuSo.hasMatch(cau[dau.batDau - 1]))) {
      i++;
      continue;
    }
    final cum = _docTu(cau, tu, i, batBuocDonVi: batBuocDonVi);
    if (cum == null) {
      i++;
      continue;
    }
    final (cuoi, giaTri) = cum;
    final ketThuc = tu[cuoi].ketThuc;
    if (ketThuc < cau.length && _chuSo.hasMatch(cau[ketThuc])) {
      i++;
      continue;
    }
    kq.add((batDau: dau.batDau, ketThuc: ketThuc, giaTri: giaTri));
    i = cuoi + 1;
  }
  return kq;
}

/// Đọc tham lam từ từ thứ [i]: trả (chỉ số từ cuối, giá trị) của điểm dừng HỢP LỆ xa nhất (ngay sau một đơn vị hoặc
/// *rưỡi*), hoặc `null`.
(int, double)? _docTu(
  String cau,
  List<({int batDau, int ketThuc, _Tu? nghia})> tu,
  int i, {
  required bool batBuocDonVi,
}) {
  var tong = 0.0; // phần đã chốt bằng nghìn / triệu / tỷ
  var phan = 0.0; // phần dưới một nghìn đang dựng
  double? cho; // chữ số đang chờ đơn vị
  var coChuc = false; // hàng chục (hoặc linh) của phần này đã có
  var choDonVi = false; // ngay sau hàng chục / linh — chữ số kế tiếp là hàng đơn vị
  var canDonVi = false; // ngay sau linh / lẻ — BẮT BUỘC có chữ số hàng đơn vị
  var coDonVi = false;
  _Loai? truoc;
  double bacCuoi = 0;
  double gopCuoi = 0;
  (int, double)? tot;

  for (var j = i; j < tu.length; j++) {
    if (j > i && !_chiKhoangTrang.hasMatch(cau.substring(tu[j - 1].ketThuc, tu[j].batDau))) break;
    final n = tu[j].nghia;
    if (n == null) break;
    var loai = n.loai;
    if (loai == _Loai.muoiKhongDau) loai = cho != null ? _Loai.chuc : _Loai.muoi;
    switch (loai) {
      case _Loai.so || _Loai.soSauChuc:
        if (choDonVi) {
          phan += n.giaTri;
          choDonVi = false;
          canDonVi = false;
          coDonVi = true;
          if (!batBuocDonVi) tot = (j, tong + phan);
        } else if (loai == _Loai.soSauChuc || cho != null || coDonVi || coChuc) {
          return tot;
        } else {
          cho = n.giaTri;
        }
      case _Loai.chuc:
        if (cho == null || coChuc) return tot;
        phan += cho * 10;
        cho = null;
        coChuc = true;
        choDonVi = true;
        if (!batBuocDonVi) tot = (j, tong + phan);
      case _Loai.muoi:
        if (cho != null || coChuc) return tot;
        phan += 10;
        coChuc = true;
        choDonVi = true;
        if (!batBuocDonVi) tot = (j, tong + phan);
      case _Loai.linh:
        // Chỉ sau trăm ("một trăm linh năm") hoặc sau nghìn / triệu: "tiền lẻ năm nghìn" không nuốt chữ "lẻ".
        if (cho != null || coChuc || (phan == 0 && truoc != _Loai.bac)) return tot;
        coChuc = true;
        choDonVi = true;
        canDonVi = true;
      case _Loai.tram:
        if (cho == null || phan != 0) return tot;
        phan = cho * 100;
        cho = null;
        tot = (j, tong + phan);
      case _Loai.bac:
        final s = n.giaTri;
        if (cho == null && phan == 0) {
          // Đơn vị liền nhau nhân nhau ("một nghìn tỷ") — chỉ khi ngay trước là một đơn vị nhỏ hơn.
          if (truoc != _Loai.bac || bacCuoi >= s) return tot;
          tong += gopCuoi * s - gopCuoi;
          gopCuoi *= s;
        } else {
          if (canDonVi) return tot;
          gopCuoi = (phan + (cho ?? 0)) * s;
          tong += gopCuoi;
        }
        bacCuoi = s;
        phan = 0;
        cho = null;
        coChuc = false;
        choDonVi = false;
        coDonVi = false;
        tot = (j, tong);
      case _Loai.ruoi:
        if (truoc == _Loai.tram) {
          phan += 50;
          tot = (j, tong + phan);
        } else if (truoc == _Loai.bac) {
          return (j, tong + bacCuoi / 2);
        } else {
          return tot;
        }
      case _Loai.muoiKhongDau:
        return tot; // đã quy về chuc / muoi ở trên
    }
    truoc = loai;
  }
  return tot;
}
