/// Bộ đếm giây xem — phần thuần của `TheoDoiXem` (spec 3.1). Widget gọi
/// [nhip] mỗi giây khi trang đang hiện; lớp này quyết định giây ấy có được
/// cộng không và khi nào phải ghi xuống CSDL.
library;

import 'thu_tu_khoi.dart';

class LuotGhi {
  const LuotGhi(this.ngay, this.giay);
  final DateTime ngay;
  final Map<CumKhoi, int> giay;
}

class BoDemGiay {
  final Map<CumKhoi, int> _chuaGhi = {};
  DateTime? _ngay;
  double? _viTriTruoc;
  DateTime? _tuongTacCuoi;
  int _soNhip = 0;

  /// Trang vừa hiện (lần đầu hoặc quay lại): nhịp kế tiếp **không** cộng.
  void batDau(DateTime luc) {
    _viTriTruoc = null;
    _tuongTacCuoi = luc;
  }

  void tuongTac(DateTime luc) => _tuongTacCuoi = luc;

  LuotGhi? nhip({required DateTime luc, required double viTri, required CumKhoi? cum}) {
    final ngay = ngayCua(luc);
    LuotGhi? ra;
    if (_chuaGhi.isNotEmpty && _ngay != ngay) ra = xa();

    final dungYen = _viTriTruoc != null && viTri == _viTriTruoc;
    if (_viTriTruoc != null && viTri != _viTriTruoc) _tuongTacCuoi = luc;
    _viTriTruoc = viTri;

    final moc = _tuongTacCuoi;
    final conHoatDong = moc != null && luc.difference(moc).inSeconds <= kGiayImToiDa;
    if (dungYen && conHoatDong && cum != null) {
      _chuaGhi[cum] = (_chuaGhi[cum] ?? 0) + 1;
      _ngay = ngay;
    }
    // Chỉ đếm nhịp khi có giây chưa ghi — xem "làm rõ" 5 của kế hoạch.
    if (_chuaGhi.isNotEmpty) _soNhip++;
    if (ra == null && _soNhip >= kNhipGhi) ra = xa();
    return ra;
  }

  /// Lấy hết phần chưa ghi (rời trang, xuống nền, gỡ widget).
  LuotGhi? xa() {
    _soNhip = 0;
    if (_chuaGhi.isEmpty) return null;
    final r = LuotGhi(_ngay!, Map.unmodifiable(Map.of(_chuaGhi)));
    _chuaGhi.clear();
    return r;
  }
}
