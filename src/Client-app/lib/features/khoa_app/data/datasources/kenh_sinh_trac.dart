/// Khoá ứng dụng — cổng tới `SinhTrac.kt` (kênh [kKenhSinhTrac]): BiometricPrompt của hệ điều hành + khoá AndroidKeyStore.
/// Cùng khuôn `kenh_bien_dong.dart`: lỗi kênh thành giá trị, không ném.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

const String kKenhSinhTrac = 'flowmoney/sinh_trac';

/// `voHieu` = khoá Keystore bị vô hiệu (thêm vân tay mới); `matKhoa` = alias không còn (đăng xuất xoá nó rồi bị cắt giữa chừng
/// — M14). Cả hai: tự tắt vân tay, nhưng câu báo khác nhau.
enum LoiSinhTrac { huy, voHieu, matKhoa, tamKhoa, khongHoTro, loi }

LoiSinhTrac docLoiSinhTrac(Object? ma) => switch (ma) {
      'HUY' => LoiSinhTrac.huy,
      'VO_HIEU' => LoiSinhTrac.voHieu,
      'MAT_KHOA' => LoiSinhTrac.matKhoa,
      'TAM_KHOA' => LoiSinhTrac.tamKhoa,
      'KHONG_HO_TRO' => LoiSinhTrac.khongHoTro,
      _ => LoiSinhTrac.loi,
    };

class TrangThaiSinhTrac {
  const TrangThaiSinhTrac({required this.hoTro, required this.daDangKy});

  /// API ≥ 28 và có phần cứng sinh trắc MẠNH (Class 3).
  final bool hoTro;

  /// Đã đăng ký ít nhất một sinh trắc mạnh trên máy.
  final bool daDangKy;

  static const TrangThaiSinhTrac khong = TrangThaiSinhTrac(hoTro: false, daDangKy: false);
}

class KetQuaBatVanTay {
  const KetQuaBatVanTay.thanhCong({required String this.banMa, required String this.iv}) : loi = null;
  const KetQuaBatVanTay.loi(LoiSinhTrac this.loi)
      : banMa = null,
        iv = null;

  final String? banMa;
  final String? iv;
  final LoiSinhTrac? loi;
}

class KetQuaMoVanTay {
  const KetQuaMoVanTay.thanhCong(Uint8List this.biMat) : loi = null;
  const KetQuaMoVanTay.loi(LoiSinhTrac this.loi) : biMat = null;

  final Uint8List? biMat;
  final LoiSinhTrac? loi;
}

abstract class KenhSinhTrac {
  Future<TrangThaiSinhTrac> trangThai();

  /// Hộp "Chạm vân tay để bật" → mã hoá [biMat] bằng khoá Keystore vừa tạo cho [idaccount].
  Future<KetQuaBatVanTay> bat(int idaccount, Uint8List biMat);

  /// Hộp "Mở FlowMoney" → giải mã. Khoá vô hiệu (thêm vân tay mới) → `voHieu`; alias không còn → `matKhoa`; cả hai KHÔNG hiện hộp.
  Future<KetQuaMoVanTay> mo(int idaccount, {required String banMa, required String iv});

  /// Xoá mọi alias `flowmoney_khoa_app_*`.
  Future<void> xoaHet();
}

class KenhSinhTracAndroid implements KenhSinhTrac {
  const KenhSinhTracAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhSinhTrac);

  @override
  Future<TrangThaiSinhTrac> trangThai() async {
    try {
      final m = await _kenh.invokeMapMethod<String, Object?>('trangThai');
      return TrangThaiSinhTrac(hoTro: m?['hoTro'] == true, daDangKy: m?['daDangKy'] == true);
    } catch (_) {
      return TrangThaiSinhTrac.khong;
    }
  }

  @override
  Future<KetQuaBatVanTay> bat(int idaccount, Uint8List biMat) async {
    try {
      final m = await _kenh.invokeMapMethod<String, Object?>(
          'bat', {'idaccount': idaccount, 'biMat': base64Encode(biMat)});
      final banMa = m?['banMa'], iv = m?['iv'];
      if (banMa is String && iv is String) return KetQuaBatVanTay.thanhCong(banMa: banMa, iv: iv);
      return KetQuaBatVanTay.loi(docLoiSinhTrac(m?['loi']));
    } catch (_) {
      return const KetQuaBatVanTay.loi(LoiSinhTrac.loi);
    }
  }

  @override
  Future<KetQuaMoVanTay> mo(int idaccount, {required String banMa, required String iv}) async {
    try {
      final m = await _kenh
          .invokeMapMethod<String, Object?>('mo', {'idaccount': idaccount, 'banMa': banMa, 'iv': iv});
      final biMat = m?['biMat'];
      if (biMat is String) return KetQuaMoVanTay.thanhCong(base64Decode(biMat));
      return KetQuaMoVanTay.loi(docLoiSinhTrac(m?['loi']));
    } catch (_) {
      return const KetQuaMoVanTay.loi(LoiSinhTrac.loi);
    }
  }

  @override
  Future<void> xoaHet() async {
    try {
      await _kenh.invokeMethod<void>('xoaHet');
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }
}

/// Nền tảng không có tầng Kotlin (web, test): chỉ có PIN.
class KenhSinhTracTrong implements KenhSinhTrac {
  const KenhSinhTracTrong();

  @override
  Future<TrangThaiSinhTrac> trangThai() async => TrangThaiSinhTrac.khong;
  @override
  Future<KetQuaBatVanTay> bat(int idaccount, Uint8List biMat) async =>
      const KetQuaBatVanTay.loi(LoiSinhTrac.khongHoTro);
  @override
  Future<KetQuaMoVanTay> mo(int idaccount, {required String banMa, required String iv}) async =>
      const KetQuaMoVanTay.loi(LoiSinhTrac.khongHoTro);
  @override
  Future<void> xoaHet() async {}
}
