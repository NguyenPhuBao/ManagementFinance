/// Chia sẻ biên lai (spec `2026-10-02-chia-se-bien-lai-design.md`). `NhanBienLaiActivity` (Kotlin) chép ảnh người dùng
/// chia sẻ từ app ngân hàng vào `filesDir/[kThuMucBienLai]/` và nối mỗi ảnh một dòng JSON vào [kTepBienLaiCho]; phía
/// Dart đọc khi app mở. Hai hằng tên tệp khớp TAY với hằng Kotlin — `bien_lai_noi_day_test.dart` canh.
///
/// [NhapBienLai] (cuối tệp) biến mỗi biên lai chờ thành một hàng `AppNotifications` loại `bienDongSoDu` — CÙNG loại
/// với tin ngân hàng của D1, để trung tâm thông báo, thẻ *"Có N mục chờ ghi"* và form `/add` dùng nguyên.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/transaction/domain/doc_bien_lai.dart';
import '../../features/transaction/domain/doc_tin_bien_dong.dart';
import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import '../ocr/che_hinh_dang.dart';
import '../ocr/doc_chu_anh.dart';
import '../ocr/dong_ocr.dart';
import '../utils/currency_formatter.dart';
import 'kho_bien_lai.dart';
import 'nhap_bien_dong.dart';
import 'notification_rules.dart';
import 'ten_tep_bien_lai.dart';

// Hằng tên tệp + `tenTepBienLaiHopLe` nằm ở tệp thuần riêng (tầng domain của form cũng dùng) — xuất lại ở đây.
export 'ten_tep_bien_lai.dart';

/// Một dòng Kotlin ghi: `{"tep","goi","luc"}`, `luc` là mili giây epoch (lúc chia sẻ).
typedef DongBienLai = ({String tep, String goi, DateTime luc});

/// `null` = dòng hỏng. Không bao giờ ném.
DongBienLai? docDongBienLai(String dong) {
  try {
    final m = jsonDecode(dong);
    if (m is! Map) return null;
    final tep = m['tep'];
    final goi = m['goi'];
    final luc = m['luc'];
    if (tep is! String || !tenTepBienLaiHopLe(tep) || goi is! String || luc is! int) return null;
    return (tep: tep, goi: goi, luc: DateTime.fromMillisecondsSinceEpoch(luc));
  } catch (_) {
    return null;
  }
}

/// Chế độ thu mẫu — CHỈ nối ở bản debug (DI truyền khi `kDebugMode`): in hình dạng ĐÃ CHE ([cheHinhDang]) của chữ trên
/// từng biên lai đang chờ, để viết mẫu đọc cho một app ngân hàng mà không lộ số tiền / số tài khoản / tên người (quy
/// tắc §13.6 `progress/Client-app.md`). Chỉ ĐỌC — không xoá hàng chờ, không xoá ảnh. Không bao giờ ném.
///
/// `print` chứ không `debugPrint`: `debugPrint` bị tiết lưu và nuốt dòng khi in nhiều (đã vấp ở lượt đo AI).
Future<void> thuMauBienLai({
  required Future<Directory> Function() thuMuc,
  required DocChuAnh docChu,
  void Function(String dong)? inRa,
}) async {
  // ignore: avoid_print
  final ra = inRa ?? print;
  try {
    final dir = await thuMuc();
    final tep = File('${dir.path}/$kTepBienLaiCho');
    if (!tep.existsSync()) return;
    for (final d in await tep.readAsLines()) {
      final r = docDongBienLai(d.trim());
      if (r == null) continue;
      final dong = await docChu.doc('${dir.path}/$kThuMucBienLai/${r.tep}');
      ra('[BienLaiThu] goi=${r.goi} · ${dong.length} dòng chữ');
      for (final h in ghepDongTheoHang(dong).split('\n')) {
        ra('[BienLaiThu]   ${cheHinhDang(h)}');
      }
    }
  } catch (e) {
    // Chỉ KIỂU lỗi: thông báo lỗi của gói đọc ảnh có thể mang đường dẫn tệp.
    ra('[BienLaiThu] hỏng: ${e.runtimeType}');
  }
}

/// Biên lai chờ quá chừng này thì bỏ — cùng mốc `NotificationScanner.giuBienDong` của hàng loại 20.
const Duration kGiuBienLai = Duration(days: 30);

/// Thân dòng thông báo cắt ở đây — cùng con số với `NhapBienDong`.
const int _kToiDaThan = 140;

typedef _HangCo = ({AppNotification hang, DauBienDong dau, String? anh, DateTime? gioBienLai});

/// Hai dấu hiệu là của CÙNG một biên lai: cùng mã giao dịch (khi cả hai có), không thì cùng số tiền + chiều và giờ in
/// trên biên lai Y HỆT. Chặt hơn `trungBienDong` (cửa sổ 5 phút) có chủ ý: hai lần chuyển cùng số tiền cách nhau vài
/// phút là hai giao dịch thật, hai biên lai của chúng in hai giờ khác nhau — gộp là mất khoản sau, im lặng.
bool _cungBienLai(DauBienDong co, DateTime gioBienLaiCo, DauBienDong moi) {
  if (co.ma != null && moi.ma != null) return co.ma == moi.ma;
  return co.soTien == moi.soTien && co.chieu == moi.chieu && gioBienLaiCo.isAtSameMomentAs(moi.thoiGian);
}

/// Nhập hàng chờ biên lai (spec `2026-10-02-chia-se-bien-lai-design.md` mục 4, 6, 7). Cùng khuôn `NhapBienDong`: đổi
/// tên → đọc → ghi → xoá tệp hàng chờ. Khác ở chỗ ẢNH ở lại đĩa cho tới khi người dùng Lưu / Bỏ qua (form cần ảnh để
/// đối chiếu) — nên mỗi lượt kết thúc bằng một bước dọn ảnh mồ côi.
///
/// Không đọc cờ `docBienDong` và không qua màn xin đồng ý của D1: mỗi biên lai là do người dùng TỰ chia sẻ.
class NhapBienLai {
  NhapBienLai({
    required this.thuMuc,
    required this.dao,
    required this.docChu,
    required this.kho,
    required this.nguonCuaGoi,
    this.huyTomTat,
    this.thuMau,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? (() => const Uuid().v4());

  /// Thư mục Kotlin ghi: `filesDir` ↔ `getApplicationSupportDirectory()`.
  final Future<Directory> Function() thuMuc;
  final NotificationDao dao;
  final DocChuAnh docChu;
  final KhoBienLai kho;

  /// Tên gói của app GỬI → tên nguồn của D1 (`kNguonTheoGoi`); `null` → [kNguonBienLai]. Dùng chung tên nguồn với D1
  /// để bảng *nguồn → ví* và mẫu đọc theo nguồn không phải học hai lần.
  final String? Function(String goi) nguonCuaGoi;

  /// Gỡ thông báo tóm tắt của Kotlin. `null` thì bỏ qua.
  final Future<void> Function()? huyTomTat;

  /// Chế độ thu mẫu — chỉ bản debug (DI nối khi `kDebugMode`): in hình dạng đã che TRƯỚC khi hàng chờ bị tiêu.
  final Future<void> Function()? thuMau;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Trả số hàng MỚI. Không bao giờ ném.
  ///
  /// Gọi SAU `NhapBienDong.nhap` trong cùng lượt: tin ngân hàng thành hàng trước, biên lai của cùng giao dịch gắn ảnh
  /// vào hàng ấy thay vì đẻ hàng thứ hai. Hàng chờ gắn MÁY, nhập vào tài khoản đang đăng nhập — `NhanBienLaiActivity`
  /// chỉ nhận ảnh khi máy có phiên, và [donKhiDangXuat] xoá sạch lúc hết phiên.
  Future<int> nhap(int idaccount) async {
    try {
      final dir = await thuMuc();
      final goc = File('${dir.path}/$kTepBienLaiCho');
      var moi = 0;
      if (goc.existsSync()) {
        try {
          await thuMau?.call();
        } catch (_) {
          // Bỏ qua có chủ ý.
        }
        // Đổi tên TRƯỚC khi đọc: Kotlin ghi tiếp vào tệp MỚI thay vì vào tệp sắp bị xoá.
        final dangNhap = await goc.rename('${goc.path}.dang_nhap');
        try {
          moi = await _ghi(idaccount, await dangNhap.readAsLines());
        } finally {
          await dangNhap.delete();
        }
        try {
          await huyTomTat?.call();
        } catch (_) {
          // Bỏ qua có chủ ý: tóm tắt còn treo chỉ là một thông báo thừa.
        }
      }
      await _donMoCoi(idaccount, dir);
      return moi;
    } catch (e) {
      debugPrint('[BienLai] nhập hàng chờ hỏng: ${e.runtimeType}');
      return 0;
    }
  }

  Future<int> _ghi(int idaccount, List<String> dong) async {
    final co = <_HangCo>[
      for (final h in await dao.getAll(idaccount))
        if (h.kind == NotificationKind.bienDongSoDu.name && h.deeplink != null)
          if (dauTuDeeplink(h.deeplink!, maGiaoDich: h.subjectId) case final d?)
            (hang: h, dau: d, anh: anhTuDeeplink(h.deeplink), gioBienLai: gioBienLaiTuDeeplink(h.deeplink)),
    ];
    // Hàng tin ngân hàng vừa được gắn ảnh TRONG lượt này — không gắn hai ảnh vào một hàng.
    final daGan = <String>{};
    // Biên lai đã xử lý trong lượt (thành hàng mới hoặc đã gắn vào hàng tin) — để nhận ra chia sẻ lặp.
    final trongLuot = <DauBienDong>[];
    final ghi = <AppNotificationsCompanion>[];
    final gioiHan = clock().subtract(kGiuBienLai);

    for (final d in dong) {
      final r = docDongBienLai(d.trim());
      if (r == null || r.luc.isBefore(gioiHan)) continue;
      final duongDan = await kho.duongDan(r.tep);
      if (duongDan == null) continue;
      final nguonGoi = nguonCuaGoi(r.goi);
      final nguon = nguonGoi ?? kNguonBienLai;
      var chu = const <DongOcr>[];
      try {
        chu = await docChu.doc(duongDan);
      } catch (_) {
        // Bộ đọc hỏng → coi như không đọc ra chữ nào: biên lai vẫn thành một hàng "chưa đọc được".
      }
      final b = docBienLai(vanBan: ghepDongTheoHang(chu), nguon: nguonGoi, luc: r.luc);
      final tien = b.soTien;
      if (tien == null) {
        ghi.add(_hangChuaDoc(b, r.tep, nguon, idaccount));
        continue;
      }
      final t = TinBienDong(
        soTien: tien,
        chieu: b.chieu,
        thoiGian: b.thoiGian,
        noiDung: b.noiDung,
        nguon: nguon,
        duoiTaiKhoan: b.duoiTaiKhoan,
        maGiaoDich: b.maGiaoDich,
      );
      final dau = dauBienDong(t);

      // 1) Chia sẻ LẠI cùng một biên lai (đã thành hàng, hoặc đã gắn vào một hàng tin) → ảnh này thừa.
      final lapLai = co.any((c) => c.gioBienLai != null && _cungBienLai(c.dau, c.gioBienLai!, dau)) ||
          trongLuot.any((m) => _cungBienLai(m, m.thoiGian, dau));
      if (lapLai) {
        await kho.xoa(r.tep);
        continue;
      }
      trongLuot.add(dau);

      // 2) Tin ngân hàng của cùng giao dịch đã có hàng mà chưa có ảnh → gắn ảnh vào hàng GẦN GIỜ nhất.
      final ungVien = [
        for (final c in co)
          if (c.anh == null && !daGan.contains(c.hang.dedupeKey) && trungBienDong(c.dau, dau)) c,
      ]..sort((x, y) => x.dau.thoiGian
          .difference(t.thoiGian)
          .abs()
          .compareTo(y.dau.thoiGian.difference(t.thoiGian).abs()));
      if (ungVien.isNotEmpty) {
        final c = ungVien.first;
        await dao.datDeeplink(
            idaccount, c.hang.dedupeKey, themAnhVaoDeeplink(c.hang.deeplink!, r.tep, t.thoiGian));
        daGan.add(c.hang.dedupeKey);
        continue;
      }

      // 3) Hàng mới.
      ghi.add(_hang(t, r.tep, b.cachDoc, idaccount));
    }
    return (await dao.insertAllIfAbsent(ghi)).length;
  }

  AppNotificationsCompanion _hang(TinBienDong t, String tep, String cachDoc, int idaccount) {
    final khoa = dedupeKeyBienDong(t);
    final than = t.noiDung.length <= _kToiDaThan ? t.noiDung : '${t.noiDung.substring(0, _kToiDaThan - 1)}…';
    return AppNotificationsCompanion.insert(
      id: idGenerator(),
      idaccount: idaccount,
      kind: NotificationKind.bienDongSoDu.name,
      dedupeKey: khoa,
      title: '${CurrencyFormatter.formatCoDau(t.soTien, thu: t.chieu == 'thu')} · ${t.nguon}',
      body: than.isEmpty ? 'Từ ảnh biên lai' : than,
      severity: NotificationSeverity.info.name,
      subjectType: const Value('bienDong'),
      subjectId: Value(t.maGiaoDich),
      deeplink: Value(deeplinkBienDong(t, dedupeKey: khoa, anh: tep, cachDoc: cachDoc)),
      // Mốc của SỰ KIỆN (giờ in trên biên lai), không phải mốc nhập — cùng nếp `NhapBienDong`.
      createdAt: t.thoiGian,
    );
  }

  /// Biên lai không đọc ra số tiền (người dùng chốt: vẫn giữ làm khoản chờ ghi, form mở với số tiền trống + ảnh).
  AppNotificationsCompanion _hangChuaDoc(BienLaiDoc b, String tep, String nguon, int idaccount) {
    final khoa = 'bienDong:bienLai|$tep';
    return AppNotificationsCompanion.insert(
      id: idGenerator(),
      idaccount: idaccount,
      kind: NotificationKind.bienDongSoDu.name,
      dedupeKey: khoa,
      title: 'Biên lai chưa đọc được · $nguon',
      body: 'Chạm để nhìn ảnh và nhập số tiền',
      severity: NotificationSeverity.info.name,
      subjectType: const Value('bienDong'),
      deeplink: Value(deeplinkBienLaiChuaDoc(
          nguon: nguon, luc: b.thoiGian, noiDung: b.noiDung, anh: tep, dedupeKey: khoa)),
      createdAt: b.thoiGian,
    );
  }

  /// Ảnh còn dùng = ảnh của mọi hàng loại 20 của tài khoản + ảnh của hàng chờ ĐANG CÓ. ⚠️ Vế sau không được bỏ: Kotlin
  /// có thể vừa nhận thêm một biên lai trong lúc lượt này đọc chữ — xoá ảnh ấy là mất biên lai người dùng vừa chia sẻ.
  Future<void> _donMoCoi(int idaccount, Directory dir) async {
    final con = <String>{
      for (final h in await dao.getAll(idaccount))
        if (h.kind == NotificationKind.bienDongSoDu.name)
          if (anhTuDeeplink(h.deeplink) case final a?) a,
    };
    final cho = File('${dir.path}/$kTepBienLaiCho');
    if (cho.existsSync()) {
      for (final d in await cho.readAsLines()) {
        if (docDongBienLai(d.trim()) case final r?) con.add(r.tep);
      }
    }
    await kho.donMoCoi(con);
  }

  /// Đăng xuất (`NotificationScanner.stop`): hàng chờ gắn MÁY — người đăng nhập sau không được thấy biên lai của người
  /// trước (spec mục 7). Xoá cứng các hàng loại 20 đang mang ảnh, rồi xoá mọi ảnh và hàng chờ. Không bao giờ ném.
  Future<void> donKhiDangXuat(int? idaccount) async {
    try {
      if (idaccount != null) {
        for (final h in await dao.getAll(idaccount)) {
          if (h.kind == NotificationKind.bienDongSoDu.name && anhTuDeeplink(h.deeplink) != null) {
            await dao.xoaCung(idaccount, h.dedupeKey);
          }
        }
      }
    } catch (e) {
      debugPrint('[BienLai] xoá hàng biên lai lúc đăng xuất hỏng: ${e.runtimeType}');
    }
    await kho.xoaHet();
  }
}
