/// Khoản chi lặp (B2) — phát hiện khoản người dùng ghi tay lặp lại theo tháng
/// hoặc tuần, để gợi ý biến nó thành hoá đơn. Hàm thuần, không đọc CSDL.
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
///
/// ⚠️ Bỏ dấu ở đây là **được phép**: đây là gợi ý, đoán sai chỉ tốn một cú
/// "Bỏ qua". Quy tắc 7 `CLAUDE.md` cấm bỏ dấu cho **luật trùng tên**, không
/// phải cho gợi ý.
///
/// ⚠️ [khoaNhomCua] là định nghĩa **duy nhất** của khoá nhóm: `timKhoanLap`
/// gom theo nó, và `chonDeXuatHoaDon` đếm "khoản mới sau lần Bỏ qua" theo nó.
/// Chép luật chuẩn hoá ra chỗ thứ hai là hai định nghĩa khoá lệch nhau, im lặng.
library;

import 'dart:math' as math;

import '../../../core/bill/bill_recurrence.dart';
import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import '../../analytics/domain/khoan_vao_thong_ke.dart';

/// Số lần tối thiểu của một chuỗi — người dùng chốt 3.
const int kSoLanToiThieu = 3;

/// Cửa sổ đọc giao dịch, tính lùi từ `now`.
const int kCuaSoKhoanLapNgay = 120;

class KhoanLap {
  /// `'<ghi chú chuẩn hoá>|<categoryId>'` — xem [khoaNhomCua].
  final String khoaNhom;

  /// Ghi chú của lần gần nhất, giữ dấu và chữ hoa, bỏ các từ có chữ số.
  final String ten;

  /// Số tiền lần gần nhất (đã cộng các dòng cùng ngày).
  final double soTien;

  /// `kBillCycleMonth` | `kBillCycleWeek`.
  final String chuKy;

  /// Ngày trong tháng cho `anchorDay` của hoá đơn; `null` với chu kỳ tuần.
  final int? ngayGoc;

  /// Ngày (không giờ) của lần gần nhất — form tạo hoá đơn lấy làm ngày bắt đầu.
  final DateTime ngayGanNhat;
  final String? categoryId;

  /// Ví xuất hiện nhiều nhất trong chuỗi; hoà thì ví của lần gần nhất.
  final String walletId;
  final int soLan;

  const KhoanLap({
    required this.khoaNhom,
    required this.ten,
    required this.soTien,
    required this.chuKy,
    required this.ngayGoc,
    required this.ngayGanNhat,
    required this.categoryId,
    required this.walletId,
    required this.soLan,
  });
}

final RegExp _coChuSo = RegExp(r'\d');
final RegExp _khongPhaiChuSo = RegExp(r'[^a-z0-9]');

/// Chỉ số các từ được GIỮ: bỏ từ có chữ số, và chữ "thang" / "t" đứng ngay
/// trước một từ vừa bị bỏ ("tháng 10", "T 9"). Từ chỉ gồm dấu câu cũng bỏ.
List<int> _giuLai(List<String> tuGoc) {
  final dang = [
    for (final w in tuGoc)
      removeVietnameseTones(w.toLowerCase()).replaceAll(_khongPhaiChuSo, ''),
  ];
  final bo = List<bool>.filled(dang.length, false);
  for (var i = 0; i < dang.length; i++) {
    if (dang[i].isEmpty) bo[i] = true;
    if (_coChuSo.hasMatch(dang[i])) {
      bo[i] = true;
      if (i > 0 && (dang[i - 1] == 'thang' || dang[i - 1] == 't')) bo[i - 1] = true;
    }
  }
  return [for (var i = 0; i < dang.length; i++) if (!bo[i]) i];
}

List<String> _tach(String s) =>
    normalizeCategoryName(s).split(' ').where((w) => w.isNotEmpty).toList();

/// *"Tiền nhà T9"*, *"tiền nhà tháng 10"*, *"Tien nha 11/2026"* → `tien nha`.
/// Có thể rỗng (ghi chú chỉ có số) — khi ấy khoản không được xét.
String ghiChuChuanHoa(String ghiChu) {
  final tu = _tach(ghiChu);
  return [
    for (final i in _giuLai(tu))
      removeVietnameseTones(tu[i].toLowerCase()).replaceAll(_khongPhaiChuSo, ''),
  ].join(' ');
}

/// Tên hiện cho người dùng: bỏ cùng những từ như [ghiChuChuanHoa] nhưng giữ dấu
/// và chữ hoa của chính họ.
String tenHienThi(String ghiChu) {
  final tu = ghiChu.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return [for (final i in _giuLai(tu)) tu[i]].join(' ');
}

String phanGhiChuCuaKhoa(String khoaNhom) =>
    khoaNhom.substring(0, khoaNhom.lastIndexOf('|'));

/// Khoá nhóm của một giao dịch, hoặc `null` nếu khoản không được xét: đã xoá,
/// không phải chi, không vào thống kê (chuyển · điều chỉnh · mở sổ · nạp mục
/// tiêu dạng cũ), đã là hoá đơn / trích mục tiêu, ở tương lai, hoặc ghi chú rỗng
/// sau chuẩn hoá (người dùng chốt: không gộp theo danh mục).
String? khoaNhomCua(Transaction t, {required DateTime now}) {
  if (t.isDeleted || t.deletedAt != null) return null;
  if (t.type != 'chi') return null;
  if (!khoanVaoThongKe(loai: t.type, categoryId: t.categoryId, ghiChu: t.note)) {
    return null;
  }
  if (t.billId != null || t.goalId != null) return null;
  if (t.date.isAfter(now)) return null;
  final g = ghiChuChuanHoa(t.note);
  if (g.isEmpty) return null;
  return '$g|${t.categoryId ?? ''}';
}

DateTime _ngay(DateTime d) => DateTime(d.year, d.month, d.day);
int _soNgayTrongThang(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Một "lần" = mọi dòng cùng nhóm trong cùng một ngày, cộng tiền.
class _Lan {
  final DateTime ngay;
  double soTien;
  Transaction ganNhat;
  final List<String> vi;
  _Lan(this.ngay, this.soTien, this.ganNhat) : vi = [ganNhat.walletId];
}

double _trungVi(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Chuỗi dài nhất tính từ lần GẦN NHẤT lùi về, cho một chu kỳ `[min, max]`
/// ngày. `null` nếu lần gần nhất đã quá `trongVong` ngày hoặc chuỗi < 3.
List<_Lan>? _chuoi(List<_Lan> lan, int min, int max, int trongVong, DateTime now) {
  final cuoi = lan.last;
  if (_ngay(now).difference(cuoi.ngay).inDays > trongVong) return null;
  final r = <_Lan>[cuoi];
  for (var i = lan.length - 2; i >= 0; i--) {
    final d = r.first.ngay.difference(lan[i].ngay).inDays;
    if (d < min || d > max) break;
    r.insert(0, lan[i]);
  }
  // Hậu tố dài nhất mà mọi số tiền lệch ≤ 10 % so với trung vị của chính nó.
  for (var k = r.length; k >= kSoLanToiThieu; k--) {
    final s = r.sublist(r.length - k);
    final tv = _trungVi([for (final l in s) l.soTien]);
    if (tv > 0 && s.every((l) => (l.soTien - tv).abs() <= 0.10 * tv)) return s;
  }
  return null;
}

/// Mọi khoản lặp trong [ds] (giao dịch của MỘT tài khoản). Tháng xét trước
/// tuần; một nhóm ra nhiều nhất một kết quả. Thứ tự kết quả không có nghĩa —
/// `chonDeXuatHoaDon` tự xếp.
List<KhoanLap> timKhoanLap(List<Transaction> ds, {required DateTime now}) {
  final tu = _ngay(now).subtract(const Duration(days: kCuaSoKhoanLapNgay));
  final nhom = <String, Map<DateTime, _Lan>>{};
  for (final t in ds) {
    if (t.date.isBefore(tu)) continue;
    final k = khoaNhomCua(t, now: now);
    if (k == null) continue;
    final ngay = _ngay(t.date);
    final m = nhom.putIfAbsent(k, () => {});
    final l = m[ngay];
    if (l == null) {
      m[ngay] = _Lan(ngay, t.amount, t);
    } else {
      l.soTien += t.amount;
      l.vi.add(t.walletId);
      if (t.date.isAfter(l.ganNhat.date)) l.ganNhat = t;
    }
  }

  final ra = <KhoanLap>[];
  for (final e in nhom.entries) {
    final lan = e.value.values.toList()..sort((a, b) => a.ngay.compareTo(b.ngay));
    if (lan.length < kSoLanToiThieu) continue;
    var chuKy = kBillCycleMonth;
    var s = _chuoi(lan, 25, 34, 45, now);
    if (s == null) {
      chuKy = kBillCycleWeek;
      s = _chuoi(lan, 6, 8, 10, now);
    }
    if (s == null) continue;

    final cuoi = s.last;
    int? ngayGoc;
    if (chuKy == kBillCycleMonth) {
      // Lần gần nhất rơi đúng ngày cuối tháng (28/2, 30/11) thì người dùng
      // nhiều khả năng trả "cuối tháng" — lấy ngày lớn nhất của chuỗi, để
      // `anchorDay` của hoá đơn tự kẹp theo từng tháng.
      ngayGoc = cuoi.ngay.day == _soNgayTrongThang(cuoi.ngay)
          ? s.map((l) => l.ngay.day).reduce(math.max)
          : cuoi.ngay.day;
    }

    final dem = <String, int>{};
    for (final l in s) {
      for (final v in l.vi) {
        dem[v] = (dem[v] ?? 0) + 1;
      }
    }
    final maxDem = dem.values.reduce(math.max);
    final viCuoi = cuoi.ganNhat.walletId;
    final vi = dem[viCuoi] == maxDem
        ? viCuoi
        : dem.entries.firstWhere((x) => x.value == maxDem).key;

    ra.add(KhoanLap(
      khoaNhom: e.key,
      ten: tenHienThi(cuoi.ganNhat.note),
      soTien: cuoi.soTien,
      chuKy: chuKy,
      ngayGoc: ngayGoc,
      ngayGanNhat: cuoi.ngay,
      categoryId: cuoi.ganNhat.categoryId,
      walletId: vi,
      soLan: s.length,
    ));
  }
  return ra;
}
