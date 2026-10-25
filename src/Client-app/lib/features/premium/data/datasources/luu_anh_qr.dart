import 'package:flutter/services.dart';

/// Kết quả lưu ảnh QR: đã lưu · máy không lưu kiểu này được (Android < 10, web) · hỏng (tải / ghi lỗi).
enum KetQuaLuuAnh { daLuu, khongHoTro, hong }

/// Lưu ảnh mã VietQR của đơn vào Thư viện ảnh, để người dùng mở app ngân hàng → *Quét từ ảnh* (spec G94 2026-10-18
/// mục 5.3). Cổng nền tảng cùng khuôn `MoLienKet` / `LuuTepPlatform` (KIEN_TRUC mục 6 chữ ký 3): kênh
/// `flowmoney/luu_anh` sang `MainActivity.kt` — `MediaStore.Images`, không xin quyền trên Android 10+. Bộ tải ảnh tiêm qua `taiAnh` — DI đưa `taiAnhBangDioTran`
/// (`datasources/tai_anh_dio_tran.dart`).
class LuuAnhQr {
  LuuAnhQr({required Future<Uint8List> Function(Uri url) taiAnh}) : _taiAnh = taiAnh;

  static const MethodChannel kenh = MethodChannel('flowmoney/luu_anh');

  final Future<Uint8List> Function(Uri url) _taiAnh;

  Future<KetQuaLuuAnh> luu(Uri url, {required String ten}) async {
    final Uint8List bytes;
    try {
      bytes = await _taiAnh(url);
    } catch (_) {
      return KetQuaLuuAnh.hong;
    }
    try {
      final ok = await kenh.invokeMethod<bool>('luuAnh', {'ten': ten, 'bytes': bytes});
      return ok == true ? KetQuaLuuAnh.daLuu : KetQuaLuuAnh.khongHoTro;
    } on MissingPluginException {
      return KetQuaLuuAnh.khongHoTro;
    } on PlatformException {
      return KetQuaLuuAnh.hong;
    }
  }
}
