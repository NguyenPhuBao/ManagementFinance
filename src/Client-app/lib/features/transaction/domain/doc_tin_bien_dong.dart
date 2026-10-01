/// D1 — bộ đọc tin biến động số dư (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.1).
/// Hàm thuần: không Flutter, không Drift, không mạng.
///
/// **Một khuôn cho mỗi nguồn**, chọn theo [docTinBienDong]'s `nguon` (tên hiển thị — Kotlin dịch tên
/// gói sang tên này bằng đúng bảng danh sách trắng, Task 3 D1). Khuôn BIDV / MB Bank / Techcombank
/// dựng từ **năm tin thật** ở `docs/AI/Classify.md` §4.3 (backend duyệt làm baseline); MoMo / ZaloPay từ
/// **hình dạng** tin thật đo trên OnePlus 13R 2026-09-30 (đã che — chỉ có chiều tiền VÀO). Vietcombank và
/// SMS **chưa có mẫu** → chưa có khuôn: trả `null`, không đoán (kế hoạch D1 Task 1).
///
/// Đây là nơi DUY NHẤT định nghĩa *"số tiền trong tin"*: Kotlin chỉ **lọc thô** (có `± chữ số`, không
/// OTP) chứ không trích gì. Tin không khớp khuôn → `null`, im — báo sai tệ hơn không báo.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Tên hiển thị của bảy nguồn trong danh sách trắng (spec §2; hai ví điện tử là quyết định của người
/// dùng, đơn `DA-XONG/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`). Màn xin đồng ý liệt kê **đúng** danh
/// sách này, không chép tay.
const String kNguonMb = 'MB Bank';
const String kNguonVcb = 'Vietcombank';
const String kNguonTcb = 'Techcombank';
const String kNguonBidv = 'BIDV';
const String kNguonSms = 'Tin nhắn (SMS)';
const String kNguonMomo = 'MoMo';
const String kNguonZalopay = 'ZaloPay';
const List<String> kNguonBienDong = [
  kNguonMb,
  kNguonVcb,
  kNguonTcb,
  kNguonBidv,
  kNguonSms,
  kNguonMomo,
  kNguonZalopay,
];

/// Tên gói Android → tên nguồn. Phải khớp TỪNG CẶP với `DANH_SACH_TRANG` ở
/// `BienDongListenerService.kt` (Kotlin lọc theo gói, Dart dịch gói → nguồn để chọn khuôn) —
/// `bien_dong_noi_day_test.dart` đọc tệp Kotlin để so. ⚠️ **Chỉ gói đã ĐO trên máy thật** (Task 1
/// D1; spec §2 cấm đoán), đo trên OnePlus 13R 2026-09-30 bằng tin biến động thật: `com.mbmobile` (khuôn MB
/// đọc trọn), `com.mservice.momotransfer`, `vn.com.vng.zalopay`. Vietcombank, Techcombank, BIDV, Tin nhắn
/// chưa có dòng nào.
const Map<String, String> kNguonTheoGoi = {
  'com.mbmobile': kNguonMb,
  'com.mservice.momotransfer': kNguonMomo,
  'vn.com.vng.zalopay': kNguonZalopay,
};

/// `null` = gói không trong danh sách trắng.
String? nguonCuaGoi(String goi) => kNguonTheoGoi[goi];

/// Các nguồn app **thật sự** đọc lúc này — suy từ [kNguonTheoGoi], không trùng, giữ thứ tự khai.
/// Màn xin đồng ý và dòng trạng thái ở Cài đặt thông báo liệt kê **đúng** danh sách này (người
/// dùng chốt 2026-09-30): không hứa những nguồn trong [kNguonBienDong] mà dịch vụ chưa đọc gói nào.
/// Đo thêm một gói → thêm vào [kNguonTheoGoi] (và `DANH_SACH_TRANG` Kotlin) là hai màn tự đổi.
List<String> get nguonDangDoc => [...{...kNguonTheoGoi.values}];

class TinBienDong {
  /// Luôn DƯƠNG; chiều ở [chieu] — cùng quy ước với `transactions.amount` của client.
  final double soTien;

  /// `'thu'` | `'chi'` — theo dấu trong tin: `+` là thu, `-` là chi.
  final String chieu;

  /// Thời điểm giao dịch ghi trong tin; không có thì là lúc thông báo hiện.
  final DateTime thoiGian;

  /// Phần diễn giải của tin (input cho gợi ý danh mục), không gồm số tài khoản / số dư.
  final String noiDung;
  final String nguon;

  /// Tối đa 4 chữ số cuối của số tài khoản — khoá của bảng *"nguồn + đuôi → ví"*.
  final String? duoiTaiKhoan;

  /// Mã giao dịch của ngân hàng, dùng **cục bộ** để gộp trùng. Không đi đâu.
  final String? maGiaoDich;

  /// Vân tay của **số dư sau giao dịch** ([vanTaySoDu]) — `null` khi tin không mang số dư (MoMo, ZaloPay).
  /// Dùng **cục bộ** để gộp trùng khi tin không có mã GD: hai lần chuyển cùng tiền, cùng chiều cách vài phút
  /// là hai giao dịch thật và chỉ khác nhau ở số dư sau (đo Realme 2026-09-30 — khoản thứ hai từng MẤT).
  final String? vanTaySoDu;
  const TinBienDong({
    required this.soTien,
    required this.chieu,
    required this.thoiGian,
    required this.noiDung,
    required this.nguon,
    this.duoiTaiKhoan,
    this.maGiaoDich,
    this.vanTaySoDu,
  });
}

/// Số dư trong tin (`5,027,757` · `0` · `-1,000`) → 12 ký tự hex đầu của SHA-256. Chỉ để SO BẰNG: không giữ
/// con số trên đĩa (hàng loại 20, khoá trùng — quy tắc §13.6 `progress/Client-app.md`). ⚠️ Không phải lớp bảo
/// vệ mật mã: không gian số dư nhỏ, dò ngược được — nó chỉ ngăn con số nằm trần trong CSDL và nhật ký.
String? vanTaySoDu(String? soDu) {
  if (soDu == null) return null;
  final chuan = soDu.replaceAll(RegExp(r'[.,\s]'), '');
  if (!RegExp(r'^-?\d+$').hasMatch(chuan)) return null;
  return sha256.convert(utf8.encode('flowmoney-sd:$chuan')).toString().substring(0, 12);
}

/// Lớp lọc OTP **thứ hai** (Kotlin đã lọc trước khi ghi đĩa): một tin xác thực lọt tới đây cũng
/// không bao giờ thành một dòng thông báo.
final RegExp _otp = RegExp(r'otp|mã xác thực|ma xac thuc', caseSensitive: false);
final RegExp _khoangTrang = RegExp(r'\s+');

/// `null` = không đọc được (nguồn chưa có khuôn, tin không khớp khuôn, tin OTP). Không bao giờ ném.
///
/// [tieuDe] và [noiDung] được **gộp** rồi mới đọc: thông báo của cùng một app đặt số tiền lúc ở
/// tiêu đề (Techcombank), lúc ở nội dung (MB Bank), và ranh giới ấy đổi theo phiên bản app.
TinBienDong? docTinBienDong({
  required String nguon,
  required String tieuDe,
  required String noiDung,
  required DateTime luc,
}) {
  final chu = unorm.nfc('$tieuDe $noiDung').replaceAll(_khoangTrang, ' ').trim();
  if (_otp.hasMatch(chu)) return null;
  try {
    return switch (nguon) {
      kNguonBidv => _docBidv(chu, luc),
      kNguonMb => _docMb(chu, luc),
      kNguonTcb => _docTcb(chu, luc),
      kNguonMomo => _docMomo(tieuDe, chu, luc),
      kNguonZalopay => _docZalopay(tieuDe, chu, luc),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// `-1,199,000` / `1.200.000` → 1199000. Cả `,` lẫn `.` là ngăn nghìn — tin ngân hàng Việt Nam không
/// mang phần lẻ.
double? _tien(String s) {
  final so = int.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
  return so == null || so <= 0 ? null : so.toDouble();
}

/// `5111012066` → `2066`; `25xxx999` → `999`: dãy chữ số CUỐI, tối đa 4.
String? _duoi(String? tk) {
  if (tk == null) return null;
  final m = RegExp(r'\d+$').firstMatch(tk);
  if (m == null) return null;
  final d = m.group(0)!;
  return d.length <= 4 ? d : d.substring(d.length - 4);
}

int _nam(String s) => s.length == 2 ? 2000 + int.parse(s) : int.parse(s);

/// BIDV (SmartBanking), mẫu 1 §4.3:
/// `Thời gian giao dịch: 10:52 02/09/2026 Tài khoản thanh toán: 5111012066 Số tiền GD: -1,199,000 VND
/// Số dư cuối: 110 VND Nội dung giao dịch: … Mã giao dịch: …`
TinBienDong? _docBidv(String chu, DateTime luc) {
  final m = RegExp(r'Số tiền GD:\s*([+-])\s?([\d.,]+)\s*VND').firstMatch(chu);
  final tien = m == null ? null : _tien(m.group(2)!);
  if (m == null || tien == null) return null;
  final g = RegExp(r'Thời gian giao dịch:\s*(\d{1,2}):(\d{2})\s+(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(chu);
  final nd = RegExp(r'Nội dung giao dịch:\s*(.*?)\s*(?:Mã giao dịch:|$)').firstMatch(chu)?.group(1);
  return TinBienDong(
    soTien: tien,
    chieu: m.group(1) == '+' ? 'thu' : 'chi',
    thoiGian: g == null
        ? luc
        : DateTime(int.parse(g.group(5)!), int.parse(g.group(4)!), int.parse(g.group(3)!),
            int.parse(g.group(1)!), int.parse(g.group(2)!)),
    noiDung: (nd == null || nd.isEmpty) ? chu : nd,
    nguon: kNguonBidv,
    duoiTaiKhoan: _duoi(RegExp(r'Tài khoản thanh toán:\s*(\S+)').firstMatch(chu)?.group(1)),
    maGiaoDich: RegExp(r'Mã giao dịch:\s*(\S+)').firstMatch(chu)?.group(1),
    vanTaySoDu: vanTaySoDu(RegExp(r'Số dư cuối:\s*(-?[\d.,]+)\s*VND').firstMatch(chu)?.group(1)),
  );
}

/// MB Bank, mẫu 2–4 §4.3:
/// `TK 25xxx999|GD: +1,200,000VND 02/09/26 15:33 |SD: 1,200,007VND|TU: … - …|ND: … Ma GD ACSP/ 9l191181`
TinBienDong? _docMb(String chu, DateTime luc) {
  final m = RegExp(r'GD:\s*([+-])\s?([\d.,]+)\s*VND\s*(?:(\d{1,2})/(\d{1,2})/(\d{2,4})\s+(\d{1,2}):(\d{2}))?')
      .firstMatch(chu);
  final tien = m == null ? null : _tien(m.group(2)!);
  if (m == null || tien == null) return null;
  final nd = RegExp(r'ND:\s*(.+)$').firstMatch(chu)?.group(1)?.trim();
  return TinBienDong(
    soTien: tien,
    chieu: m.group(1) == '+' ? 'thu' : 'chi',
    thoiGian: m.group(3) == null
        ? luc
        : DateTime(_nam(m.group(5)!), int.parse(m.group(4)!), int.parse(m.group(3)!),
            int.parse(m.group(6)!), int.parse(m.group(7)!)),
    noiDung: (nd == null || nd.isEmpty) ? chu : nd,
    nguon: kNguonMb,
    duoiTaiKhoan: _duoi(RegExp(r'TK\s+(\S+?)\s*\|').firstMatch(chu)?.group(1)),
    maGiaoDich: nd == null ? null : RegExp(r'Ma GD\s*(.+)$').firstMatch(nd)?.group(1)?.trim(),
    vanTaySoDu: vanTaySoDu(RegExp(r'SD:\s*(-?[\d.,]+)\s*VND').firstMatch(chu)?.group(1)),
  );
}

/// Techcombank, mẫu 5 §4.3 — số tiền ở TIÊU ĐỀ:
/// `+ VND 208,080` · `Tài khoản: 5555047777777 Số dư: VND 218,042 RUT VI MOMO … 02/09/2026 10:57:56 144879146167`
TinBienDong? _docTcb(String chu, DateTime luc) {
  final m = RegExp(r'([+-])\s*VND\s*([\d.,]+)').firstMatch(chu);
  final tien = m == null ? null : _tien(m.group(2)!);
  if (m == null || tien == null) return null;
  final nd = RegExp(r'Số dư:\s*VND\s*[\d.,]+\s*(.+)$').firstMatch(chu)?.group(1)?.trim();
  final g = nd == null
      ? null
      : RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})').firstMatch(nd);
  return TinBienDong(
    soTien: tien,
    chieu: m.group(1) == '+' ? 'thu' : 'chi',
    thoiGian: g == null
        ? luc
        : DateTime(int.parse(g.group(3)!), int.parse(g.group(2)!), int.parse(g.group(1)!),
            int.parse(g.group(4)!), int.parse(g.group(5)!), int.parse(g.group(6)!)),
    noiDung: (nd == null || nd.isEmpty) ? chu : nd,
    nguon: kNguonTcb,
    duoiTaiKhoan: _duoi(RegExp(r'Tài khoản:\s*(\d+)').firstMatch(chu)?.group(1)),
    maGiaoDich: nd == null ? null : RegExp(r'\s(\d{9,})$').firstMatch(nd)?.group(1),
    vanTaySoDu: vanTaySoDu(RegExp(r'Số dư:\s*VND\s*(-?[\d.,]+)').firstMatch(chu)?.group(1)),
  );
}

/// Tin ví điện tử KHÔNG mang dấu ± (đo 2026-09-30) — chiều nằm ở động từ. Chỉ có mẫu tiền **vào**
/// (*"Nhận …"*), nên chỉ đọc chiều ấy; tin không mở đầu bằng *"Nhận"* → `null`, không đoán chiều ra.
final RegExp _nhan = RegExp(r'^\s*Nhận');

/// MoMo — tiêu đề `Nhận chuyển khoản từ <tên>`, nội dung `Số tiền 20.000 ₫ … Lời nhắn: "…"`.
TinBienDong? _docMomo(String tieuDe, String chu, DateTime luc) {
  if (!_nhan.hasMatch(unorm.nfc(tieuDe))) return null;
  final m = RegExp(r'Số tiền\s*([\d.,]+)\s*₫').firstMatch(chu);
  final tien = m == null ? null : _tien(m.group(1)!);
  if (tien == null) return null;
  final loi = RegExp(r'Lời nhắn:\s*"([^"]*)"').firstMatch(chu)?.group(1)?.trim();
  return TinBienDong(
    soTien: tien,
    chieu: 'thu',
    thoiGian: luc,
    noiDung: (loi == null || loi.isEmpty) ? unorm.nfc(tieuDe).trim() : loi,
    nguon: kNguonMomo,
  );
}

/// ZaloPay — tiêu đề `Nhận tiền qua mã …`, nội dung `Nhận 15.000đ qua chuyển khoản`.
TinBienDong? _docZalopay(String tieuDe, String chu, DateTime luc) {
  if (!_nhan.hasMatch(unorm.nfc(tieuDe))) return null;
  final m = RegExp(r'Nhận\s+([\d.,]+)\s*đ').firstMatch(chu);
  final tien = m == null ? null : _tien(m.group(1)!);
  if (tien == null) return null;
  return TinBienDong(
    soTien: tien,
    chieu: 'thu',
    thoiGian: luc,
    noiDung: unorm.nfc(tieuDe).trim(),
    nguon: kNguonZalopay,
  );
}
