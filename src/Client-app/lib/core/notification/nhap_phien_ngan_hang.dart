/// Nhắc ghi sau khi dùng app ngân hàng — lượt nhập lúc mở app (spec `2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md`
/// §4.3–4.4, §5.1): đọc sự kiện dùng app ngân hàng từ tầng Kotlin, dựng phiên, xét bằng chứng trong CSDL, ghi hàng loại
/// 20 cho phiên đáng nhắc, rồi gỡ thông báo nhắc của Kotlin.
///
/// Chạy trong `NotificationScanner._nhapBienDong` SAU `NhapBienDong` và `NhapBienLai` — tin và biên lai đang chờ phải
/// đã thành hàng trước khi xét bằng chứng.
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';
import 'kenh_phien_ngan_hang.dart';
import 'moc_phien_store.dart';
import 'notification_rules.dart';
import 'phien_ngan_hang.dart';

class NhapPhienNganHang {
  NhapPhienNganHang({
    required this.kenh,
    required this.dao,
    required this.moc,
    required this.batNhac,
    required this.nguonCuaGoi,
    required this.giaoDichTrongKhoang,
    this.viCuaNguon,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? (() => const Uuid().v4());

  final KenhPhienNganHang kenh;
  final NotificationDao dao;
  final MocPhienStore moc;

  /// Cờ `NotificationPrefs.nhacSauNganHang` của tài khoản.
  final Future<bool> Function(int idaccount) batNhac;

  /// Gói → tên nguồn (`nguonCuaGoi` của D1 — một danh sách cho hai tính năng).
  final String? Function(String goi) nguonCuaGoi;

  /// Giao dịch sống của tài khoản có `date` trong [tu, den].
  final Future<List<BangChungGiaoDich>> Function(int idaccount, DateTime tu, DateTime den) giaoDichTrongKhoang;

  /// Ví của nguồn (`ViTheoNguonStore.docTheoNguon`); `null` = không biết → mọi giao dịch là bằng chứng.
  final Future<String?> Function(int idaccount, String nguon)? viCuaNguon;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Trả số dòng nhắc đã ghi. Không bao giờ ném.
  Future<int> nhap(int idaccount) async {
    try {
      final bayGio = clock();
      if (await moc.layVaXoaDangXuat()) {
        // Lượt nhập đầu sau một lần đăng xuất = lần đăng nhập kế: phiên giữa hai lúc ấy không thuộc tài khoản nào —
        // kể cả khi người đăng nhập lại là người khác (nghiệm thu Realme 2026-10-03).
        await moc.ghi(idaccount, bayGio);
      }
      final daXet = await moc.doc(idaccount);
      if (!await batNhac(idaccount)) {
        // Cờ Kotlin gắn MÁY, công tắc gắn TÀI KHOẢN (bẫy 3 D1): ghi lại theo người đang đăng nhập ở MỌI lượt.
        await kenh.datBat(false, daXetDen: daXet);
        return 0;
      }
      if (daXet == null || !await kenh.coQuyen()) {
        // Lần đầu / thiếu quyền: mốc = bây giờ — không đổ một tràng phiên cũ thành dòng (spec §4.4).
        await moc.ghi(idaccount, bayGio);
        await kenh.datBat(true, daXetDen: bayGio);
        return 0;
      }
      var mocXet = bayGio.subtract(kLuiToiDa);
      for (final m in [daXet, await kenh.boDen()]) {
        if (m != null && m.isAfter(mocXet)) mocXet = m;
      }
      final xet = phienCanXet(
        phienTuSuKien(await kenh.suKien(mocXet), bayGio: bayGio),
        bayGio: bayGio,
        moc: mocXet,
      );
      final mocMoi = mocSauKhiXet(xet);
      var moi = 0;
      if (mocMoi != null) {
        final tin = <BangChungTin>[
          for (final h in await dao.getAll(idaccount))
            if (h.kind == NotificationKind.bienDongSoDu.name && !laKhoaPhien(h.dedupeKey))
              if (_nguonCua(h.deeplink) case final n?) (nguon: n, luc: h.createdAt),
        ];
        final tu = xet.map((p) => p.batDau).reduce((a, b) => a.isBefore(b) ? a : b).subtract(kTruocPhien);
        final gd = await giaoDichTrongKhoang(idaccount, tu, mocMoi.add(kSauPhienGiaoDich));
        final vi = <String, String?>{};
        for (final p in xet) {
          final n = nguonCuaGoi(p.goi);
          if (n != null && !vi.containsKey(n)) vi[n] = await viCuaNguon?.call(idaccount, n);
        }
        final nhac = phienCanNhac(xet, nguonCuaGoi: nguonCuaGoi, tin: tin, giaoDich: gd, viCuaNguon: vi);
        moi = (await dao.insertAllIfAbsent([
          for (final p in nhac) _hang(p, nguonCuaGoi(p.goi)!, idaccount),
        ]))
            .length;
        await moc.ghi(idaccount, mocMoi);
      }
      await kenh.datBat(true, daXetDen: mocMoi ?? daXet);
      await kenh.huyNhac();
      return moi;
    } catch (e) {
      debugPrint('[NhacGhi] nhập phiên hỏng: ${e.runtimeType}');
      return 0;
    }
  }

  /// Đăng xuất: phiên lúc không ai đăng nhập không bao giờ thành dòng nhắc của ai (spec §4.4). Không bao giờ ném.
  ///
  /// ⚠️ Mốc = giờ đăng xuất là CHƯA ĐỦ: phiên giữa lúc ấy và lần đăng nhập kế vẫn mở sau mốc. Cờ máy
  /// [MocPhienStore.danhDauDangXuat] để lượt nhập đầu sau đó đặt mốc = lúc đăng nhập.
  Future<void> dongKhiDangXuat(int? idaccount) async {
    try {
      if (idaccount != null) await moc.ghi(idaccount, clock());
      await moc.danhDauDangXuat();
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
    try {
      await kenh.datBat(false);
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  static String? _nguonCua(String? deeplink) {
    final n = deeplink == null ? null : Uri.tryParse(deeplink)?.queryParameters['nguon'];
    return (n == null || n.isEmpty) ? null : n;
  }

  AppNotificationsCompanion _hang(PhienNganHang p, String nguon, int idaccount) {
    final khoa = dedupeKeyPhien(nguon, p.batDau);
    return AppNotificationsCompanion.insert(
      id: idGenerator(),
      idaccount: idaccount,
      kind: NotificationKind.bienDongSoDu.name,
      dedupeKey: khoa,
      title: tieuDePhien(nguon, p.batDau, p.ketThuc),
      body: kThanPhien,
      severity: NotificationSeverity.info.name,
      subjectType: const Value('bienDong'),
      deeplink: Value(deeplinkPhien(p, nguon: nguon, dedupeKey: khoa)),
      // Mốc của SỰ KIỆN (giờ mở app), không phải mốc nhập — cùng nếp `NhapBienDong`.
      createdAt: p.batDau,
    );
  }
}
