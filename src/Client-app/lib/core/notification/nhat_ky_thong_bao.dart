/// Nhật ký thông báo (B5a) — cửa ghi DUY NHẤT vào `app_notification_events`.
///
/// Trang trung tâm thông báo, hook của `NotificationTapRouter`, scanner và
/// scheduler đều ghi qua đây. B5a chỉ ghi; B5b mới đọc.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/notification_event_dao.dart';

/// Chín mã sự kiện. Chữ thô vì là giá trị lưu trong SQLite — đổi một chữ là
/// dữ liệu cũ đọc không ra, im lặng. Thêm mã mới thì được, đổi mã cũ thì không.
abstract final class SuKienThongBao {
  static const moTrongApp = 'mo_trong_app';
  static const gatBo = 'gat_bo';
  static const khoiPhuc = 'khoi_phuc';
  static const docTatCa = 'doc_tat_ca';
  static const chamHdh = 'cham_hdh';
  static const nutTraNgay = 'nut_tra_ngay';
  static const hoan = 'hoan';
  static const datLich = 'dat_lich';
  static const huyLich = 'huy_lich';
}

class NhatKyThongBao {
  NhatKyThongBao({
    required this.dao,
    required int? Function() idaccountPhien,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _idaccountPhien = idaccountPhien,
        clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? const Uuid().v4;

  final NotificationEventDao dao;

  /// Tài khoản của phiên đang đăng nhập; `null` = chưa có phiên. Là hàm chứ không
  /// phải giá trị — cùng lý lẽ `NotificationTapRouter.dangDangNhap`.
  int? Function() _idaccountPhien;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Gán nguồn phiên sau khi dựng. Cần vì `AuthBloc` đăng ký dạng **factory**
  /// trong `sl`: DI không với tới được bloc đang chạy của app, nên `main.dart`
  /// gán nguồn từ đúng bloc ấy (`idaccountTuTrangThai(authBloc.state)`).
  void datNguonPhien(int? Function() nguon) => _idaccountPhien = nguon;

  int? _taiKhoan(int? truyen) {
    final id = truyen ?? _idaccountPhien();
    return (id == null || id <= 0) ? null : id;
  }

  /// Không bao giờ ném. [idaccount] truyền thẳng (scanner, scheduler) thắng
  /// phiên; không có tài khoản thì bỏ, không đoán (quy tắc 2).
  Future<void> ghi(
    String dedupeKey,
    String suKien, {
    int? idaccount,
    DateTime? luc,
    int? osId,
  }) async {
    final id = _taiKhoan(idaccount);
    if (id == null) return;
    try {
      await dao.ghi(AppNotificationEventsCompanion.insert(
        id: idGenerator(),
        idaccount: id,
        dedupeKey: dedupeKey,
        suKien: suKien,
        luc: luc ?? clock(),
        osId: Value(osId),
      ));
    } catch (e) {
      debugPrint('[NhatKy] ghi $suKien hỏng: $e');
    }
  }

  Future<void> ghiNhieu(List<String> dedupeKeys, String suKien, {int? idaccount}) async {
    if (dedupeKeys.isEmpty) return;
    final id = _taiKhoan(idaccount);
    if (id == null) return;
    final luc = clock();
    try {
      await dao.ghiNhieu([
        for (final k in dedupeKeys)
          AppNotificationEventsCompanion.insert(
            id: idGenerator(),
            idaccount: id,
            dedupeKey: k,
            suKien: suKien,
            luc: luc,
          ),
      ]);
    } catch (e) {
      debugPrint('[NhatKy] ghi ${dedupeKeys.length} × $suKien hỏng: $e');
    }
  }
}
