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

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/transaction/domain/doc_tin_bien_dong.dart';
import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import '../utils/currency_formatter.dart';
import 'ten_tep_bien_lai.dart';
import 'notification_rules.dart';

const String kTepBienDongCho = 'bien_dong_cho.jsonl';

/// Hai tin cùng số tiền, cùng chiều, cách nhau không quá chừng này là **một** giao dịch (SMS và
/// thông báo app của cùng ngân hàng bắn cách nhau vài giây; đơn gốc mục 2, backend duyệt).
const Duration kCuaSoGopTrung = Duration(minutes: 5);

/// Hai TIN của CÙNG một app, không mã GD, không phân biệt được bằng số dư (MoMo, ZaloPay): chỉ là một giao dịch khi là
/// CÙNG thông báo được app đăng lại / cập nhật — cùng khoá thông báo (khi biết) và cách nhau không quá chừng này. Cửa
/// sổ [kCuaSoGopTrung] dành cho HAI KÊNH; áp nó cho một kênh là gộp hai lần nhận cùng số tiền cách vài phút làm một
/// (người dùng báo 2026-10-05: hai khoản MoMo đến liên tiếp, app chỉ bắt được một).
const Duration kCuaSoCungTin = Duration(seconds: 10);

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
///
/// [nguon] `null` = không biết (hàng cũ thiếu tham số). [khoaTin] = khoá thông báo Android đã băm ([bamKhoaTin]),
/// `null` với hàng ghi trước 2026-10-05 và với biên lai. [tuTin] = dấu hiệu rút từ một THÔNG BÁO (không phải ảnh biên
/// lai) — chỉ hai tin mới so bằng cửa sổ [kCuaSoCungTin].
typedef DauBienDong = ({
  double soTien,
  String chieu,
  DateTime thoiGian,
  String? ma,
  String? vanTay,
  String? nguon,
  String? khoaTin,
  bool tuTin,
});

/// [khoaTin] là khoá THÔ (`StatusBarNotification.key`); hàm tự băm.
DauBienDong dauBienDong(TinBienDong t, {String? khoaTin, bool tuTin = true}) => (
      soTien: t.soTien,
      chieu: t.chieu,
      thoiGian: t.thoiGian,
      ma: t.maGiaoDich,
      vanTay: t.vanTaySoDu,
      nguon: t.nguon,
      khoaTin: khoaTin == null ? null : bamKhoaTin(khoaTin),
      tuTin: tuTin,
    );

/// Khoá thông báo (`0|<gói>|<id>|<tag>|<uid>`) → 12 ký tự hex đầu của SHA-256. Chỉ để SO BẰNG; không để tên gói và id
/// nằm trần trong CSDL.
String bamKhoaTin(String khoa) => sha256.convert(utf8.encode('flowmoney-kt:$khoa')).toString().substring(0, 12);

/// Cùng mã giao dịch → trùng. Hai bên cùng mang vân tay số dư mà KHÁC nhau → không trùng: hai lần chuyển cùng
/// tiền, cùng chiều cách vài phút là hai giao dịch thật, số dư sau là thứ duy nhất phân biệt chúng (đo Realme
/// 2026-09-30 — khoản thứ hai từng bị gộp và MẤT). Hai TIN cùng nguồn không phân biệt được bằng số dư → chỉ trùng khi
/// là cùng thông báo đăng lại ([kCuaSoCungTin]). Còn lại (hai kênh, hoặc biên lai với tin): cùng số tiền + cùng chiều
/// và cách ≤ [kCuaSoGopTrung].
///
/// Hai nguồn là hai TÀI KHOẢN khác nhau (MB Bank · MoMo) → không trùng: cửa sổ 5 phút dành cho hai KÊNH của cùng
/// tài khoản — SMS, hoặc biên lai từ app không rõ ([_nguonChung]). Nghiệm thu OnePlus 2026-10-08: MoMo → MB 10.000
/// rồi MB → MoMo 10.000 cách 100 giây — tin nhận tiền của MoMo bị gộp vào hàng MB, khoản ấy MẤT.
bool trungBienDong(DauBienDong a, DauBienDong b) {
  if (a.ma != null && b.ma != null) return a.ma == b.ma;
  if (_haiTaiKhoan(a.nguon, b.nguon)) return false;
  if (a.vanTay != null && b.vanTay != null && a.vanTay != b.vanTay) return false;
  if (a.soTien != b.soTien || a.chieu != b.chieu) return false;
  final cach = a.thoiGian.difference(b.thoiGian).abs();
  final cungVanTay = a.vanTay != null && a.vanTay == b.vanTay;
  if (a.tuTin && b.tuTin && a.nguon != null && a.nguon == b.nguon && !cungVanTay) {
    if (a.khoaTin != null && b.khoaTin != null && a.khoaTin != b.khoaTin) return false;
    return cach <= kCuaSoCungTin;
  }
  return cach <= kCuaSoGopTrung;
}

/// Nguồn không chỉ ra một tài khoản: SMS (kênh của mọi ngân hàng), biên lai chia sẻ từ app không có trong danh sách.
const Set<String> _nguonChung = {kNguonSms, kNguonBienLai};

bool _haiTaiKhoan(String? a, String? b) =>
    a != null && b != null && a != b && !_nguonChung.contains(a) && !_nguonChung.contains(b);

String _phut(DateTime d) => d.toIso8601String().substring(0, 16);
String _giay(DateTime d) => d.toIso8601String().substring(0, 19);

/// `bienDong:<mã GD>`, không mã thì `bienDong:<nguồn>|<tiền>|<chiều>|<phút>[|<vân tay số dư>]`. Cố ý **không**
/// mang nội dung tin hay con số số dư: khoá đi vào nhật ký B5a và payload thông báo, hai chỗ sống lâu hơn hàng.
/// Vân tay có mặt thì hai giao dịch CÙNG PHÚT khác số dư không trùng khoá — trùng khoá là `insertAllIfAbsent`
/// bỏ hàng thứ hai, im lặng.
///
/// Không mã, không vân tay (MoMo, ZaloPay) thì mốc tính tới GIÂY: hai lần nhận cùng số tiền trong cùng một phút là
/// hai hàng (báo lỗi 2026-10-05) — [trungBienDong] đã lọc thông báo đăng lại trước khi tới đây.
String dedupeKeyBienDong(TinBienDong t) => t.maGiaoDich != null
    ? 'bienDong:${t.maGiaoDich}'
    : t.vanTaySoDu != null
        ? 'bienDong:${t.nguon}|${t.soTien.toInt()}|${t.chieu}|${_phut(t.thoiGian)}|${t.vanTaySoDu}'
        : 'bienDong:${t.nguon}|${t.soTien.toInt()}|${t.chieu}|${_giay(t.thoiGian)}';

/// `/add?amount=…&huong=…&date=…&note=…&nguon=…&duoi=…&khoa=…` — route `/add` nằm ngoài shell, `push`
/// được (như deeplink `ghiChep`). `khoa` = dedupeKey để form xoá hàng khi Lưu / Bỏ qua (Task 7).
///
/// Chia sẻ biên lai (2026-10-02) thêm hai tham số tuỳ chọn — hàng sinh từ tin ngân hàng không truyền gì và query của
/// nó y như trước: [anh] = tên tệp ảnh trong `filesDir/bien_lai/`; [cachDoc] = `mau` | `chung` (cách đọc chữ trên
/// ảnh). Có [anh] thì query mang thêm `blt` = giờ IN TRÊN BIÊN LAI — dấu để nhận ra cùng một biên lai được chia sẻ
/// lại ([gioBienLaiTuDeeplink]).
String deeplinkBienDong(
  TinBienDong t, {
  required String dedupeKey,
  String? anh,
  String? cachDoc,
  String? khoaTin,
}) =>
    Uri(
      path: '/add',
      queryParameters: {
        'amount': t.soTien.toInt().toString(),
        'huong': t.chieu,
        'date': t.thoiGian.toIso8601String(),
        'note': t.noiDung,
        'nguon': t.nguon,
        if (t.duoiTaiKhoan != null) 'duoi': t.duoiTaiKhoan!,
        // Vân tay số dư — chỉ để [dauTuDeeplink] so hàng ĐÃ CÓ với tin mới; form không đọc nó.
        if (t.vanTaySoDu != null) 'vt': t.vanTaySoDu!,
        // Khoá thông báo đã băm — để [dauTuDeeplink] nhận ra cùng một thông báo được app đăng lại. Form không đọc.
        if (khoaTin != null) 'kt': bamKhoaTin(khoaTin),
        if (anh != null) 'anh': anh,
        if (anh != null) 'blt': t.thoiGian.toIso8601String(),
        if (cachDoc != null) 'doc': cachDoc,
        'khoa': dedupeKey,
      },
    ).toString();

/// Biên lai KHÔNG đọc ra số tiền: không `amount`, không `huong` — form mở với số tiền trống, và [dauTuDeeplink] trả
/// `null` nên hàng này không tham gia gộp trùng với gì cả.
String deeplinkBienLaiChuaDoc({
  required String nguon,
  required DateTime luc,
  required String noiDung,
  required String anh,
  required String dedupeKey,
}) =>
    Uri(path: '/add', queryParameters: {
      'date': luc.toIso8601String(),
      'note': noiDung,
      'nguon': nguon,
      'anh': anh,
      'doc': 'khong',
      'khoa': dedupeKey,
    }).toString();

/// Tên tệp ảnh biên lai gắn trên một hàng loại 20; `null` khi hàng không có ảnh hoặc tên không hợp lệ
/// ([tenTepBienLaiHopLe] — tên này sẽ được ghép thành đường dẫn).
String? anhTuDeeplink(String? deeplink) {
  final a = deeplink == null ? null : Uri.tryParse(deeplink)?.queryParameters['anh'];
  return (a != null && tenTepBienLaiHopLe(a)) ? a : null;
}

/// Giờ in trên biên lai mà hàng này đang mang (`blt`); `null` khi hàng chưa mang biên lai nào. Hai lần chia sẻ CÙNG
/// một biên lai có giờ in y hệt nhau — khác với hai lần chuyển cùng số tiền cách nhau vài phút.
DateTime? gioBienLaiTuDeeplink(String? deeplink) {
  final g = deeplink == null ? null : Uri.tryParse(deeplink)?.queryParameters['blt'];
  return g == null ? null : DateTime.tryParse(g);
}

/// Gắn ảnh biên lai vào deeplink của một hàng ĐÃ CÓ (tin ngân hàng đến trước biên lai của cùng giao dịch); giữ mọi
/// tham số cũ. [gioBienLai] là giờ in trên biên lai — có thể lệch giờ của tin vài giây tới vài phút.
///
/// ⚠️ KHÔNG ghi `doc`: số tiền, giờ, nội dung của hàng này đến từ TIN ngân hàng, ảnh chỉ để đối chiếu. `doc` có mặt
/// ⇔ dữ liệu của hàng đọc từ ảnh — form dựa vào đó để nói *"Từ biên lai…"* và *"Đọc từ ảnh — hãy kiểm lại"*.
String themAnhVaoDeeplink(String deeplink, String anh, DateTime gioBienLai) {
  final u = Uri.parse(deeplink);
  return u.replace(queryParameters: {
    ...u.queryParameters,
    'anh': anh,
    'blt': gioBienLai.toIso8601String(),
  }).toString();
}

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
  return (
    soTien: tien,
    chieu: chieu,
    thoiGian: ngay,
    ma: maGiaoDich,
    vanTay: q['vt'],
    nguon: q['nguon'],
    khoaTin: q['kt'],
    // `doc` có mặt ⇔ số liệu của hàng đọc từ ảnh biên lai (hàng tin được gắn ảnh thì không có `doc`).
    tuTin: q['doc'] == null,
  );
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
    final ghi = <({TinBienDong tin, String khoa})>[];
    for (final d in dong) {
      final r = docDongBienDong(d.trim());
      if (r == null) continue;
      final nguon = nguonCuaGoi(r.goi);
      if (nguon == null) continue;
      final t = docTinBienDong(nguon: nguon, tieuDe: r.tieuDe, noiDung: r.noiDung, luc: r.luc);
      if (t == null) continue;
      final dau = dauBienDong(t, khoaTin: r.khoa);
      if (daCo.any((c) => trungBienDong(c, dau))) continue;
      if (ghi.any((g) => trungBienDong(dauBienDong(g.tin, khoaTin: g.khoa), dau))) continue;
      ghi.add((tin: t, khoa: r.khoa));
    }
    final moi = await dao.insertAllIfAbsent([for (final g in ghi) _companion(g.tin, idaccount, khoaTin: g.khoa)]);
    return moi.length;
  }

  AppNotificationsCompanion _companion(TinBienDong t, int idaccount, {String? khoaTin}) {
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
      deeplink: Value(deeplinkBienDong(t, dedupeKey: khoa, khoaTin: khoaTin)),
      // Mốc của SỰ KIỆN (giờ trong tin), không phải mốc nhập — cùng nếp `NotificationCandidate.createdAt`.
      createdAt: t.thoiGian,
    );
  }
}
