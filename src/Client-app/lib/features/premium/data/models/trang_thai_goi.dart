import '../../domain/hang_goi.dart';
import 'tran_goi.dart';

/// Trạng thái gói của tài khoản đang đăng nhập (spec Premium 2026-10-06 mục
/// 5.1).
///
/// [hetHan] `null` = **chưa biết** hạn (phiên nói `type: Premium` mà
/// `/payment/*` chưa trả lời) — không phải vô hạn. Mọi phép đọc đi qua
/// [laPremium] với giờ máy truyền vào, nên hết hạn offline tự về Basic mà
/// không cần sự kiện nào.
class TrangThaiGoi {
  const TrangThaiGoi({
    required this.loai,
    this.hetHan,
    this.tran = TranGoi.macDinh,
    required this.nhanLuc,
    this.gia = kGiaPremium,
    this.soNgayGoi = kSoNgayGoi,
    this.quyenTinhNang = const {},
    this.quyenPremium = const {},
    this.tranPremium,
  });

  final LoaiGoi loai;
  final DateTime? hetHan;
  final TranGoi tran;

  /// Lúc nhận từ server (hoặc lúc dựng từ `type` của phiên). Dùng cho phép
  /// giãn 5 phút ở `resumed`.
  final DateTime nhanLuc;
  final int gia;
  final int soNgayGoi;

  /// Bảng quyền bật/tắt server trả (`features`) cho gói HIỆU LỰC lúc [nhanLuc]. Chỉ đọc qua `duocDung`
  /// (`quyen_tinh_nang.dart`) — đọc thẳng là bỏ qua phép xét hạn (test quét 21).
  final Map<String, bool> quyenTinhNang;

  /// Cột PREMIUM của bảng quyền (`premiumFeatures` — server gửi cho tài khoản hiệu lực Basic, đơn CAN-LAM 55 A1). Rỗng =
  /// server chưa gửi (như trước B1). Chỉ đọc qua `trangThaiQuyen` / `dacQuyenPremium` (`quyen_tinh_nang.dart`) — test quét 21.
  final Map<String, bool> quyenPremium;

  /// Trần cột Premium (`premiumLimits`, đơn 55 A1). `null` = server chưa gửi — KHÁC `TranGoi.khongGioiHan`. Chỉ
  /// `dacQuyenPremium` đọc (test quét 21).
  final TranGoi? tranPremium;

  static TrangThaiGoi basicMacDinh(DateTime nhanLuc) =>
      TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: nhanLuc);

  bool laPremium(DateTime now) =>
      loai == LoaiGoi.premium && (hetHan == null || hetHan!.isAfter(now));

  /// Số ngày LỊCH còn lại (giờ địa phương); `0` = hết hạn trong hôm nay.
  /// `null` khi không còn Premium hoặc chưa biết hạn — không bao giờ âm.
  int? soNgayConLai(DateTime now) {
    final h = hetHan;
    if (h == null || !laPremium(now)) return null;
    final hl = h.toLocal();
    final nl = now.toLocal();
    return DateTime(hl.year, hl.month, hl.day)
        .difference(DateTime(nl.year, nl.month, nl.day))
        .inDays;
  }

  Map<String, Object?> toJson() => {
        'loai': loai.name,
        'hetHan': hetHan?.toUtc().toIso8601String(),
        'tran': tran.toJson(),
        'nhanLuc': nhanLuc.toUtc().toIso8601String(),
        'gia': gia,
        'soNgayGoi': soNgayGoi,
        'quyenTinhNang': quyenTinhNang,
        'quyenPremium': quyenPremium,
        'tranPremium': tranPremium?.toJson(),
      };

  /// Đọc lại từ kho. Rác / thiếu `nhanLuc` → `null` (hàng hỏng, kho coi như
  /// trống).
  static TrangThaiGoi? tuJsonKho(Object? json) {
    if (json is! Map) return null;
    final nhanLuc = json['nhanLuc'];
    final moc = nhanLuc is String ? DateTime.tryParse(nhanLuc) : null;
    if (moc == null) return null;
    final hetHan = json['hetHan'];
    final gia = json['gia'];
    final ngay = json['soNgayGoi'];
    return TrangThaiGoi(
      loai: json['loai'] == 'premium' ? LoaiGoi.premium : LoaiGoi.basic,
      hetHan: hetHan is String ? DateTime.tryParse(hetHan) : null,
      tran: TranGoi.tuJson(json['tran']),
      nhanLuc: moc,
      gia: gia is num && gia > 0 ? gia.toInt() : kGiaPremium,
      soNgayGoi: ngay is num && ngay > 0 ? ngay.toInt() : kSoNgayGoi,
      quyenTinhNang: _docQuyen(json['quyenTinhNang']),
      quyenPremium: _docQuyen(json['quyenPremium']),
      tranPremium: _docTranPremium(json['tranPremium']),
    );
  }
}

/// Đọc `data` của `GET /payment/subscription-info`. ⚠️ Mã backend trả
/// `accountType` (`payment.service.js:235`), hướng dẫn ghi `type` — đọc cả
/// hai. Không bao giờ ném: trường rác rơi về mặc định của đúng trường ấy.
TrangThaiGoi trangThaiTuJson(
  Map<String, Object?> json, {
  required DateTime nhanLuc,
}) {
  final loaiTho =
      (json['accountType'] ?? json['type'])?.toString().toLowerCase();
  final loai = loaiTho == 'premium' ? LoaiGoi.premium : LoaiGoi.basic;
  final hetHanTho = json['premiumExpiresAt'];
  final hetHan = hetHanTho is String ? DateTime.tryParse(hetHanTho) : null;
  final gia = json['price'];
  final ngay = json['packageDays'];
  return TrangThaiGoi(
    loai: loai,
    hetHan: loai == LoaiGoi.premium ? hetHan : null,
    tran: TranGoi.tuJson(json['limits']),
    nhanLuc: nhanLuc,
    gia: gia is num && gia > 0 ? gia.toInt() : kGiaPremium,
    soNgayGoi: ngay is num && ngay > 0 ? ngay.toInt() : kSoNgayGoi,
    quyenTinhNang: _docQuyen(json['features'] ?? json['quyenTinhNang']),
    quyenPremium: _docQuyen(json['premiumFeatures']),
    tranPremium: _docTranPremium(json['premiumLimits']),
  );
}

Map<String, bool> _docQuyen(Object? raw) =>
    raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v == true)) : const {};

/// `premiumLimits` / kho: không phải Map → `null` (server chưa gửi). ⚠️ Không đưa rác thẳng vào [TranGoi.tuJson] — hàm ấy
/// trả trần mặc định cho rác, và "chưa gửi" thành "đã gửi".
TranGoi? _docTranPremium(Object? raw) =>
    raw is Map ? TranGoi.tuJson(raw, khiThieu: TranGoi.khongGioiHan) : null;

/// Nhánh rơi về khi kho trống và `/payment/*` hỏng: `type` của `/auth/login`
/// hay `/auth/profile`. `Premium` → Premium chưa biết hạn.
TrangThaiGoi trangThaiTuLoaiPhien(String? type, {required DateTime nhanLuc}) =>
    TrangThaiGoi(
      loai: type?.toLowerCase() == 'premium' ? LoaiGoi.premium : LoaiGoi.basic,
      nhanLuc: nhanLuc,
    );
