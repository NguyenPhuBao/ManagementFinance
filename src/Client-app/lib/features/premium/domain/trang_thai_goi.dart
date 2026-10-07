import 'tran_goi.dart';

/// Giá và số ngày mặc định của gói — server đè bằng `price` / `packageDays`
/// của `/payment/subscription-info` khi backend thêm hai trường ấy (đơn
/// CAN-LAM); tới lúc đó đây là con số của `.env` backend ngày 2026-10-06.
const int kGiaPremium = 49000;
const int kSoNgayGoi = 30;

enum LoaiGoi { basic, premium }

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
  });

  final LoaiGoi loai;
  final DateTime? hetHan;
  final TranGoi tran;

  /// Lúc nhận từ server (hoặc lúc dựng từ `type` của phiên). Dùng cho phép
  /// giãn 5 phút ở `resumed`.
  final DateTime nhanLuc;
  final int gia;
  final int soNgayGoi;

  /// Bảng phân quyền tính năng động (TOGGLE: ai_assistant, ai_quick_input...)
  final Map<String, bool> quyenTinhNang;

  static TrangThaiGoi basicMacDinh(DateTime nhanLuc) =>
      TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: nhanLuc);

  bool laPremium(DateTime now) =>
      loai == LoaiGoi.premium && (hetHan == null || hetHan!.isAfter(now));

  /// Kiểm tra quyền được dùng của một tính năng cụ thể.
  /// Ưu tiên cấu hình động trong [quyenTinhNang], fallback theo [fallback] hoặc [laPremium].
  bool duocDung(String maTinhNang, {bool Function()? fallback}) {
    if (quyenTinhNang.containsKey(maTinhNang)) {
      return quyenTinhNang[maTinhNang] == true;
    }
    return fallback != null ? fallback() : laPremium(DateTime.now());
  }

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
    final rawQuyen = json['quyenTinhNang'];
    final Map<String, bool> quyen = rawQuyen is Map
        ? rawQuyen.map((k, v) => MapEntry(k.toString(), v == true))
        : const {};
    return TrangThaiGoi(
      loai: json['loai'] == 'premium' ? LoaiGoi.premium : LoaiGoi.basic,
      hetHan: hetHan is String ? DateTime.tryParse(hetHan) : null,
      tran: TranGoi.tuJson(json['tran']),
      nhanLuc: moc,
      gia: gia is num && gia > 0 ? gia.toInt() : kGiaPremium,
      soNgayGoi: ngay is num && ngay > 0 ? ngay.toInt() : kSoNgayGoi,
      quyenTinhNang: quyen,
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
  final rawFeatures = json['features'] ?? json['quyenTinhNang'];
  final Map<String, bool> quyen = rawFeatures is Map
      ? rawFeatures.map((k, v) => MapEntry(k.toString(), v == true))
      : const {};
  return TrangThaiGoi(
    loai: loai,
    hetHan: loai == LoaiGoi.premium ? hetHan : null,
    tran: TranGoi.tuJson(json['limits']),
    nhanLuc: nhanLuc,
    gia: gia is num && gia > 0 ? gia.toInt() : kGiaPremium,
    soNgayGoi: ngay is num && ngay > 0 ? ngay.toInt() : kSoNgayGoi,
    quyenTinhNang: quyen,
  );
}

/// Nhánh rơi về khi kho trống và `/payment/*` hỏng: `type` của `/auth/login`
/// hay `/auth/profile`. `Premium` → Premium chưa biết hạn.
TrangThaiGoi trangThaiTuLoaiPhien(String? type, {required DateTime nhanLuc}) =>
    TrangThaiGoi(
      loai: type?.toLowerCase() == 'premium' ? LoaiGoi.premium : LoaiGoi.basic,
      nhanLuc: nhanLuc,
    );
