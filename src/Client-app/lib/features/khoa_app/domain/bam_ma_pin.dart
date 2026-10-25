/// Băm mã PIN của khoá ứng dụng — PBKDF2-HMAC-SHA256 (RFC 8018), Dart thuần trên gói `crypto` đã có (không thêm gói).
///
/// Số vòng cất CÙNG băm trong cấu hình (`CauHinhKhoaApp.soVong`), nên đổi [kSoVongMacDinh] về sau không làm vỡ PIN cũ.
/// Với PIN 6 số (10^6 tổ hợp) số vòng chỉ làm chậm dò thử khi kho đã bị đọc ra; lớp chặn chính là kho Keystore của
/// `flutter_secure_storage` + chờ tăng dần (`luat_khoa_app.dart`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Số vòng mặc định — một lần băm trên Realme (Dimensity 1100, bản release) ~0,2–0,3 s. Đo 2026-10-25 (gồm cả dựng isolate
/// của `compute`): 30.000 → 160–193 ms · 60.000 → 324 ms · 100.000 → 535 ms · 150.000 → 796 ms (`KHOA_APP_FEATURE.md` mục 10).
const int kSoVongMacDinh = 50000;

/// Độ dài băm (byte).
const int kDoDaiBam = 32;

Uint8List pbkdf2HmacSha256(List<int> matKhau, List<int> salt, int soVong, int doDai) {
  final hmac = Hmac(sha256, matKhau);
  final soKhoi = (doDai + 31) ~/ 32;
  final ra = BytesBuilder(copy: false);
  for (var i = 1; i <= soKhoi; i++) {
    final dau = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..[salt.length] = (i >> 24) & 0xff
      ..[salt.length + 1] = (i >> 16) & 0xff
      ..[salt.length + 2] = (i >> 8) & 0xff
      ..[salt.length + 3] = i & 0xff;
    var u = hmac.convert(dau).bytes;
    final t = Uint8List.fromList(u);
    for (var j = 1; j < soVong; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    ra.add(t);
  }
  return Uint8List.sublistView(ra.takeBytes(), 0, doDai);
}

/// Base64 của PBKDF2-HMAC-SHA256(utf8([pin]), [salt], [soVong], [kDoDaiBam]).
String bamMaPin(String pin, List<int> salt, int soVong) =>
    base64Encode(pbkdf2HmacSha256(utf8.encode(pin), salt, soVong, kDoDaiBam));

/// So hai dãy byte, thời gian không phụ thuộc vị trí khác đầu tiên.
bool soSanhHangThoiGian(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var khac = 0;
  for (var i = 0; i < a.length; i++) {
    khac |= a[i] ^ b[i];
  }
  return khac == 0;
}
