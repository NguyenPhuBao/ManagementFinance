/// Khoá ứng dụng — bộ điều phối (spec mục 5–6): PIN (PBKDF2 trong isolate), đếm sai + chờ, vân tay qua cổng
/// `KenhSinhTrac`, xoá theo phiên. Không log PIN / bí mật.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show compute;

import '../data/datasources/kenh_sinh_trac.dart';
import '../data/khoa_app_store.dart';
import '../data/models/cau_hinh_khoa_app.dart';
import '../domain/bam_ma_pin.dart';
import '../domain/luat_khoa_app.dart';

typedef BamMaPin = Future<String> Function(String pin, List<int> salt, int soVong);

/// Băm ngoài luồng giao diện (`compute` chạy được cả web — `Isolate.run` thì không).
Future<String> bamTrongIsolate(String pin, List<int> salt, int soVong) =>
    compute(_bam, (pin: pin, salt: salt, soVong: soVong));

String _bam(({String pin, List<int> salt, int soVong}) d) => bamMaPin(d.pin, d.salt, d.soVong);

class KetQuaKiemPin {
  const KetQuaKiemPin({required this.dung, required this.soLanSai, this.choDen, this.dangCho = false});

  final bool dung;
  final int soLanSai;
  final DateTime? choDen;

  /// Đang trong thời gian chờ — PIN không được kiểm.
  final bool dangCho;
}

class KhoaAppService {
  KhoaAppService({
    required KhoaAppStore store,
    required KenhSinhTrac kenh,
    BamMaPin bam = bamTrongIsolate,
    Random? ngauNhien,
    DateTime Function()? clock,
    this.soVong = kSoVongMacDinh,
  })  : _store = store,
        _kenh = kenh,
        _bam = bam,
        _ngauNhien = ngauNhien ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  final KhoaAppStore _store;
  final KenhSinhTrac _kenh;
  final BamMaPin _bam;
  final Random _ngauNhien;
  final DateTime Function() _clock;
  final int soVong;

  Uint8List _byte(int n) => Uint8List.fromList(List<int>.generate(n, (_) => _ngauNhien.nextInt(256)));

  Future<CauHinhKhoaApp?> doc(int idaccount) => _store.doc(idaccount);

  Future<TrangThaiSinhTrac> trangThaiMay() => _kenh.trangThai();

  /// Bật khoá (chưa có cấu hình) hoặc đổi PIN (giữ mức tự khoá + vân tay).
  Future<void> datPin(int idaccount, String pin) async {
    if (!maPinHopLe(pin)) throw ArgumentError('Mã PIN phải gồm $kDoDaiPin chữ số');
    final salt = _byte(16);
    final bam = await _bam(pin, salt, soVong);
    final cu = await _store.doc(idaccount);
    final saltB64 = base64Encode(salt);
    await _store.ghi(
      idaccount,
      cu == null
          ? CauHinhKhoaApp(salt: saltB64, bam: bam, soVong: soVong)
          : cu.voiPin(salt: saltB64, bam: bam, soVong: soVong),
    );
  }

  Future<KetQuaKiemPin> kiemPin(int idaccount, String pin) async {
    final c = await _store.doc(idaccount);
    if (c == null) return const KetQuaKiemPin(dung: true, soLanSai: 0);
    final nay = _clock();
    final cho = c.choDen;
    if (conCho(cho, nay) != null) {
      return KetQuaKiemPin(dung: false, soLanSai: c.soLanSai, choDen: cho, dangCho: true);
    }
    final bam = await _bam(pin, base64Decode(c.salt), c.soVong);
    if (soSanhHangThoiGian(base64Decode(bam), base64Decode(c.bam))) {
      if (c.soLanSai != 0 || c.choDen != null) await _store.ghi(idaccount, c.voiLanSai(0, null));
      return const KetQuaKiemPin(dung: true, soLanSai: 0);
    }
    final n = c.soLanSai + 1;
    final cho2 = thoiGianCho(n);
    final choDen = cho2 == null ? null : nay.add(cho2);
    // GHI TRƯỚC khi trả: tắt app giữa chừng không được xoá lần sai (spec mục 6). Kho hỏng → ném.
    await _store.ghi(idaccount, c.voiLanSai(n, choDen));
    return KetQuaKiemPin(dung: false, soLanSai: n, choDen: choDen);
  }

  Future<void> tatKhoa(int idaccount) async {
    await _store.xoa(idaccount);
    await _kenh.xoaHet();
  }

  Future<void> datTuKhoaSau(int idaccount, TuKhoaSau muc) async {
    final c = await _store.doc(idaccount);
    if (c != null) await _store.ghi(idaccount, c.voiTuKhoaSau(muc));
  }

  /// `null` = đã bật.
  Future<LoiSinhTrac?> batVanTay(int idaccount) async {
    final c = await _store.doc(idaccount);
    if (c == null) return LoiSinhTrac.loi;
    final biMat = _byte(32);
    final kq = await _kenh.bat(idaccount, biMat);
    final banMa = kq.banMa, iv = kq.iv;
    if (kq.loi != null || banMa == null || iv == null) return kq.loi ?? LoiSinhTrac.loi;
    await _store.ghi(
      idaccount,
      c.voiVanTay(VanTayDaBat(banMa: banMa, iv: iv, bamBiMat: base64Encode(sha256.convert(biMat).bytes))),
    );
    return null;
  }

  Future<void> tatVanTay(int idaccount) async {
    final c = await _store.doc(idaccount);
    if (c != null) await _store.ghi(idaccount, c.voiVanTay(null));
    await _kenh.xoaHet();
  }

  /// `null` = mở được (đếm sai về 0). Khoá Keystore vô hiệu → tự tắt vân tay.
  Future<LoiSinhTrac?> moBangVanTay(int idaccount) async {
    final c = await _store.doc(idaccount);
    final v = c?.vanTay;
    if (c == null || v == null) return LoiSinhTrac.khongHoTro;
    final kq = await _kenh.mo(idaccount, banMa: v.banMa, iv: v.iv);
    if (kq.loi == LoiSinhTrac.voHieu) {
      await tatVanTay(idaccount);
      return LoiSinhTrac.voHieu;
    }
    final biMat = kq.biMat;
    if (kq.loi != null || biMat == null) return kq.loi ?? LoiSinhTrac.loi;
    if (!soSanhHangThoiGian(sha256.convert(biMat).bytes, base64Decode(v.bamBiMat))) return LoiSinhTrac.loi;
    if (c.soLanSai != 0 || c.choDen != null) await _store.ghi(idaccount, c.voiLanSai(0, null));
    return null;
  }

  /// Đăng xuất (hook `PhienDieuPhoiThat.dongPhien`).
  Future<void> xoaHet() async {
    await _store.xoaHet();
    await _kenh.xoaHet();
  }
}
