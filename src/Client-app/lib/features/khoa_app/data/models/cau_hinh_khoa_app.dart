/// Cấu hình khoá ứng dụng của MỘT tài khoản trên máy (spec mục 5). Có cấu hình = khoá đang bật; tắt = xoá.
library;

import '../../domain/luat_khoa_app.dart';

/// Vân tay đã bật: bản mã của bí mật + IV + SHA-256(bí mật) — đều base64. KHÔNG bao giờ cất bí mật.
class VanTayDaBat {
  const VanTayDaBat({required this.banMa, required this.iv, required this.bamBiMat});

  final String banMa;
  final String iv;
  final String bamBiMat;

  Map<String, Object?> toJson() => {'banMa': banMa, 'iv': iv, 'bamBiMat': bamBiMat};

  static VanTayDaBat? tuJson(Object? j) {
    if (j is! Map) return null;
    final banMa = j['banMa'], iv = j['iv'], bam = j['bamBiMat'];
    if (banMa is! String || iv is! String || bam is! String) return null;
    return VanTayDaBat(banMa: banMa, iv: iv, bamBiMat: bam);
  }
}

class CauHinhKhoaApp {
  const CauHinhKhoaApp({
    required this.salt,
    required this.bam,
    required this.soVong,
    this.tuKhoaSau = TuKhoaSau.macDinh,
    this.vanTay,
    this.soLanSai = 0,
    this.choDen,
  });

  /// Base64 của salt 16 byte.
  final String salt;

  /// Base64 của PBKDF2 (`bam_ma_pin.dart`).
  final String bam;
  final int soVong;
  final TuKhoaSau tuKhoaSau;
  final VanTayDaBat? vanTay;

  /// Số lần sai PIN liền nhau — giữ qua lần tắt app.
  final int soLanSai;

  /// Chờ tới lúc này mới được nhập PIN tiếp (giờ máy — spec mục 6, giới hạn chấp nhận).
  final DateTime? choDen;

  CauHinhKhoaApp _sao({
    TuKhoaSau? tuKhoaSau,
    VanTayDaBat? vanTay,
    bool goVanTay = false,
    int? soLanSai,
    DateTime? choDen,
    bool goCho = false,
    String? salt,
    String? bam,
    int? soVong,
  }) =>
      CauHinhKhoaApp(
        salt: salt ?? this.salt,
        bam: bam ?? this.bam,
        soVong: soVong ?? this.soVong,
        tuKhoaSau: tuKhoaSau ?? this.tuKhoaSau,
        vanTay: goVanTay ? null : (vanTay ?? this.vanTay),
        soLanSai: soLanSai ?? this.soLanSai,
        choDen: goCho ? null : (choDen ?? this.choDen),
      );

  CauHinhKhoaApp voiTuKhoaSau(TuKhoaSau m) => _sao(tuKhoaSau: m);
  CauHinhKhoaApp voiVanTay(VanTayDaBat? v) => v == null ? _sao(goVanTay: true) : _sao(vanTay: v);
  CauHinhKhoaApp voiLanSai(int n, DateTime? cho) =>
      cho == null ? _sao(soLanSai: n, goCho: true) : _sao(soLanSai: n, choDen: cho);

  /// Đổi PIN: giữ mức tự khoá + vân tay (bí mật vân tay độc lập với PIN), xoá đếm sai.
  CauHinhKhoaApp voiPin({required String salt, required String bam, required int soVong}) =>
      _sao(salt: salt, bam: bam, soVong: soVong, soLanSai: 0, goCho: true);

  Map<String, Object?> toJson() => {
        'v': 1,
        'salt': salt,
        'bam': bam,
        'soVong': soVong,
        'tuKhoaSau': tuKhoaSau.name,
        'vanTay': vanTay?.toJson(),
        'soLanSai': soLanSai,
        'choDen': choDen?.millisecondsSinceEpoch,
      };

  static CauHinhKhoaApp? tuJson(Object? j) {
    if (j is! Map) return null;
    final salt = j['salt'], bam = j['bam'], soVong = j['soVong'];
    if (salt is! String || bam is! String || soVong is! int || soVong < 1) return null;
    final sai = j['soLanSai'];
    final cho = j['choDen'];
    final muc = j['tuKhoaSau'];
    return CauHinhKhoaApp(
      salt: salt,
      bam: bam,
      soVong: soVong,
      tuKhoaSau: TuKhoaSau.tuTen(muc is String ? muc : null),
      vanTay: VanTayDaBat.tuJson(j['vanTay']),
      soLanSai: sai is int && sai > 0 ? sai : 0,
      choDen: cho is int ? DateTime.fromMillisecondsSinceEpoch(cho) : null,
    );
  }
}
