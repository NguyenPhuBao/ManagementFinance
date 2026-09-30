/// D1 — nhập hàng chờ tin biến động số dư (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.2).
///
/// Dịch vụ Kotlin (`BienDongListenerService`) chỉ **lọc thô** rồi nối mỗi tin một dòng JSON vào
/// [kTepBienDongCho] trong `filesDir` (= `getApplicationSupportDirectory()` phía Dart). Khi app mở
/// (`NotificationScanner.start` và `resumed`), [NhapBienDong] đọc tệp, đọc từng tin bằng
/// `docTinBienDong`, **gộp trùng** với nhau và với hàng loại 20 đang có, ghi hàng
/// `AppNotifications` loại `bienDongSoDu`, rồi **xoá tệp** — tin thô không nằm lại đĩa (Nghị định
/// 13, tối thiểu hoá). Cùng khuôn `NhapHangCho` của B5a: đổi tên → đọc → lọc → ghi → xoá.
///
/// ⚠️ Hàng loại 20 **không bắn ra hệ điều hành** từ Dart: scanner chỉ bắn hàng chính nó chèn. Thứ
/// hiện ngoài màn khoá là thông báo tóm tắt *không số* do Kotlin bắn; [NhapBienDong.huyTomTat] gỡ nó
/// sau mỗi lượt nhập.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/transaction/domain/doc_tin_bien_dong.dart';
import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import '../utils/currency_formatter.dart';
import 'notification_rules.dart';

const String kTepBienDongCho = 'bien_dong_cho.jsonl';

/// Hai tin cùng số tiền, cùng chiều, cách nhau không quá chừng này là **một** giao dịch (SMS và
/// thông báo app của cùng ngân hàng bắn cách nhau vài giây; đơn gốc mục 2, backend duyệt).
const Duration kCuaSoGopTrung = Duration(minutes: 5);

/// Thân thông báo cắt ở đây — dòng thông báo là lời mời, không phải bản sao tin.
const int _kToiDaThan = 140;

/// Một dòng Kotlin ghi: `{"goi","tieuDe","noiDung","luc","khoa"}`, `luc` là mili giây epoch
/// (`StatusBarNotification.postTime`), `khoa` là `StatusBarNotification.key`.
typedef DongBienDong = ({String goi, String tieuDe, String noiDung, DateTime luc, String khoa});

DongBienDong? docDongBienDong(String dong) {
  try {
    final m = jsonDecode(dong);
    if (m is! Map) return null;
    final goi = m['goi'];
    final tieuDe = m['tieuDe'];
    final noiDung = m['noiDung'];
    final luc = m['luc'];
    final khoa = m['khoa'];
    if (goi is! String || goi.isEmpty || noiDung is! String || luc is! int || khoa is! String) return null;
    return (
      goi: goi,
      tieuDe: tieuDe is String ? tieuDe : '',
      noiDung: noiDung,
      luc: DateTime.fromMillisecondsSinceEpoch(luc),
      khoa: khoa,
    );
  } catch (_) {
    return null;
  }
}

/// Dấu hiệu để gộp trùng — rút từ một tin mới ([dauBienDong]) hoặc từ một hàng loại 20 đang có
/// ([dauTuDeeplink]), để hai phía so bằng CÙNG một phép ([trungBienDong]).
typedef DauBienDong = ({double soTien, String chieu, DateTime thoiGian, String? ma});

DauBienDong dauBienDong(TinBienDong t) =>
    (soTien: t.soTien, chieu: t.chieu, thoiGian: t.thoiGian, ma: t.maGiaoDich);

/// Cùng mã giao dịch → trùng. Không thì cùng số tiền + cùng chiều và cách nhau ≤ [kCuaSoGopTrung].
bool trungBienDong(DauBienDong a, DauBienDong b) {
  if (a.ma != null && b.ma != null) return a.ma == b.ma;
  return a.soTien == b.soTien &&
      a.chieu == b.chieu &&
      a.thoiGian.difference(b.thoiGian).abs() <= kCuaSoGopTrung;
}

String _phut(DateTime d) => d.toIso8601String().substring(0, 16);

/// `bienDong:<mã GD>`, không mã thì `bienDong:<nguồn>|<tiền>|<chiều>|<phút>`. Cố ý **không** mang nội
/// dung tin: khoá đi vào nhật ký B5a và payload thông báo, hai chỗ sống lâu hơn hàng.
String dedupeKeyBienDong(TinBienDong t) => t.maGiaoDich != null
    ? 'bienDong:${t.maGiaoDich}'
    : 'bienDong:${t.nguon}|${t.soTien.toInt()}|${t.chieu}|${_phut(t.thoiGian)}';

/// `/add?amount=…&huong=…&date=…&note=…&nguon=…&duoi=…&khoa=…` — route `/add` nằm ngoài shell, `push`
/// được (như deeplink `ghiChep`). `khoa` = dedupeKey để form xoá hàng khi Lưu / Bỏ qua (Task 7).
String deeplinkBienDong(TinBienDong t, {required String dedupeKey}) => Uri(
      path: '/add',
      queryParameters: {
        'amount': t.soTien.toInt().toString(),
        'huong': t.chieu,
        'date': t.thoiGian.toIso8601String(),
        'note': t.noiDung,
        'nguon': t.nguon,
        if (t.duoiTaiKhoan != null) 'duoi': t.duoiTaiKhoan!,
        'khoa': dedupeKey,
      },
    ).toString();

/// Đọc ngược dấu hiệu từ `deeplink` (+ `subjectId` = mã GD) của một hàng loại 20 đang có. `null`
/// nếu không phải deeplink của loại này.
DauBienDong? dauTuDeeplink(String deeplink, {required String? maGiaoDich}) {
  final u = Uri.tryParse(deeplink);
  if (u == null || u.path != '/add') return null;
  final q = u.queryParameters;
  final tien = double.tryParse(q['amount'] ?? '');
  final chieu = q['huong'];
  final ngay = DateTime.tryParse(q['date'] ?? '');
  if (tien == null || chieu == null || ngay == null) return null;
  return (soTien: tien, chieu: chieu, thoiGian: ngay, ma: maGiaoDich);
}

class NhapBienDong {
  NhapBienDong({
    required this.thuMuc,
    required this.dao,
    required this.nguonCuaGoi,
    required this.batBienDong,
    this.huyTomTat,
    this.datBat,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? (() => const Uuid().v4());

  /// Thư mục Kotlin ghi: `filesDir` ↔ `getApplicationSupportDirectory()`.
  final Future<Directory> Function() thuMuc;
  final NotificationDao dao;

  /// Tên gói → tên nguồn hiển thị (`kNguon*`); `null` = không trong danh sách trắng. Bảng thật khớp
  /// **tay** với hằng Kotlin (Task 3 D1) — tên gói đo trên máy, không đoán.
  final String? Function(String goi) nguonCuaGoi;

  /// Cờ `NotificationPrefs.docBienDong` của tài khoản. Tắt → tệp vẫn bị xoá (tin thô không ở lại
  /// đĩa) nhưng không hàng nào được ghi.
  final Future<bool> Function(int idaccount) batBienDong;

  /// Gỡ thông báo tóm tắt của Kotlin (kênh `flowmoney/bien_dong`). `null` thì bỏ qua.
  final Future<void> Function()? huyTomTat;

  /// Ghi cờ bật của dịch vụ Kotlin (`KenhBienDong.datBat`). `null` thì bỏ qua.
  ///
  /// ⚠️ Cờ Kotlin gắn **máy** còn [batBienDong] gắn **tài khoản**: tài khoản A bật rồi đăng xuất,
  /// tài khoản B chưa từng đồng ý đăng nhập — không có bước này thì dịch vụ vẫn đọc và vẫn bắn
  /// thông báo tóm tắt cho B. Nên mỗi lượt [nhap] (đăng nhập + mỗi lần quay lại từ nền) ghi lại cờ
  /// theo tài khoản đang đăng nhập, và [tatDocMay] tắt nó lúc đăng xuất.
  final Future<void> Function(bool bat)? datBat;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Tắt dịch vụ Kotlin — gọi khi đăng xuất (`NotificationScanner.stop`). Không bao giờ ném.
  Future<void> tatDocMay() => _datBat(false);

  Future<void> _datBat(bool bat) async {
    try {
      await datBat?.call(bat);
    } catch (_) {
      // Bỏ qua có chủ ý: lượt nhập / đăng xuất không được hỏng vì kênh native.
    }
  }

  /// Trả số hàng đã ghi. Không bao giờ ném.
  ///
  /// Hàng chờ gắn **máy**, không gắn tài khoản: tin hiện trên máy của người đang cầm máy, nên nhập
  /// vào tài khoản **đang đăng nhập** (spec §6) — khác `NhapHangCho` của B5a, nơi khoá đã mang chủ.
  Future<int> nhap(int idaccount) async {
    try {
      // Đọc cờ và ghi sang Kotlin TRƯỚC khi xét tệp: "chưa có tệp" là ca thường nhất.
      final bat = await batBienDong(idaccount);
      await _datBat(bat);
      final dir = await thuMuc();
      final goc = File('${dir.path}/$kTepBienDongCho');
      if (!goc.existsSync()) return 0;
      // Đổi tên TRƯỚC khi đọc: Kotlin ghi tiếp vào tệp MỚI thay vì vào tệp sắp bị xoá.
      final dangNhap = await goc.rename('${goc.path}.dang_nhap');
      var soHang = 0;
      try {
        if (bat) {
          soHang = await _ghi(idaccount, await dangNhap.readAsLines());
        }
      } finally {
        await dangNhap.delete();
      }
      try {
        await huyTomTat?.call();
      } catch (_) {
        // Bỏ qua có chủ ý: tóm tắt còn treo chỉ là một thông báo thừa.
      }
      return soHang;
    } catch (e) {
      debugPrint('[BienDong] nhập hàng chờ hỏng: $e');
      return 0;
    }
  }

  Future<int> _ghi(int idaccount, List<String> dong) async {
    final daCo = [
      for (final h in await dao.getAll(idaccount))
        if (h.kind == NotificationKind.bienDongSoDu.name && h.deeplink != null)
          if (dauTuDeeplink(h.deeplink!, maGiaoDich: h.subjectId) case final d?) d,
    ];
    final ghi = <TinBienDong>[];
    for (final d in dong) {
      final r = docDongBienDong(d.trim());
      if (r == null) continue;
      final nguon = nguonCuaGoi(r.goi);
      if (nguon == null) continue;
      final t = docTinBienDong(nguon: nguon, tieuDe: r.tieuDe, noiDung: r.noiDung, luc: r.luc);
      if (t == null) continue;
      final dau = dauBienDong(t);
      if (daCo.any((c) => trungBienDong(c, dau))) continue;
      if (ghi.any((g) => trungBienDong(dauBienDong(g), dau))) continue;
      ghi.add(t);
    }
    final moi = await dao.insertAllIfAbsent([for (final t in ghi) _companion(t, idaccount)]);
    return moi.length;
  }

  AppNotificationsCompanion _companion(TinBienDong t, int idaccount) {
    final khoa = dedupeKeyBienDong(t);
    final than = t.noiDung.length <= _kToiDaThan ? t.noiDung : '${t.noiDung.substring(0, _kToiDaThan - 1)}…';
    return AppNotificationsCompanion.insert(
      id: idGenerator(),
      idaccount: idaccount,
      kind: NotificationKind.bienDongSoDu.name,
      dedupeKey: khoa,
      title: '${CurrencyFormatter.formatCoDau(t.soTien, thu: t.chieu == 'thu')} · ${t.nguon}',
      body: than,
      severity: NotificationSeverity.info.name,
      subjectType: const Value('bienDong'),
      subjectId: Value(t.maGiaoDich),
      deeplink: Value(deeplinkBienDong(t, dedupeKey: khoa)),
      // Mốc của SỰ KIỆN (giờ trong tin), không phải mốc nhập — cùng nếp `NotificationCandidate.createdAt`.
      createdAt: t.thoiGian,
    );
  }
}
