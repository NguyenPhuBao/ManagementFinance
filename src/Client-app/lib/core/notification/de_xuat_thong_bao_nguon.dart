/// Nguồn dữ liệu cho đề xuất thông báo (B5b): gom nhật ký B5a, thông báo, mốc
/// ghi giao dịch và tuỳ chọn của MỘT tài khoản rồi gọi hàm thuần
/// `deXuatThongBao`. Trang Cài đặt thông báo và trung tâm thông báo nạp qua đây
/// **một lần** lúc mở (không nghe stream).
///
/// Spec `docs/superpowers/specs/2026-09-28-b5b-hoc-gio-thong-bao-design.md` §2–3.
library;

// Chỉ `debugPrint`: `foundation.dart` còn xuất chú thích `Category`, trùng tên
// data class danh mục của Drift.
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/app_database.dart';
import 'hoc_gio_thong_bao.dart';
import 'nhat_ky_thong_bao.dart';
import 'os/os_notifier.dart';
import 'prefs/notification_prefs_store.dart';

/// Mốc "lúc người dùng ghi giao dịch" (spec §2.3). Bảng `Transactions` **không
/// có `createdAt`**; `updatedAt` đổi cả khi sửa lẫn khi pull. Mốc thay thế:
/// `updatedAt` của khoản **chưa xoá** mà `updatedAt` **cùng ngày lịch** với
/// `date` — ghi trong ngày, không ghi lùi ngày.
List<DateTime> mocGhiGiaoDichTu(List<Transaction> ds) => [
      for (final t in ds)
        if (!t.isDeleted &&
            t.deletedAt == null &&
            t.updatedAt.year == t.date.year &&
            t.updatedAt.month == t.date.month &&
            t.updatedAt.day == t.date.day)
          t.updatedAt,
    ];

class DeXuatThongBaoNguon {
  DeXuatThongBaoNguon({
    required this.db,
    required this.store,
    required this.os,
    required this.nhatKy,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final NotificationPrefsStore store;
  final OsNotifier os;

  /// Cửa ghi DUY NHẤT vào `app_notification_events` — *Bỏ qua* đi qua nó.
  final NhatKyThongBao nhatKy;
  final DateTime Function() clock;

  /// Rỗng khi không có gì để đề xuất **hoặc** nạp hỏng — đề xuất là phần phụ
  /// của hai trang, một trục trặc ở đây không được làm vỡ trang.
  Future<List<DeXuatThongBao>> tai(int idaccount) async {
    // `idaccount` CHỈ từ phiên (quy tắc 2).
    if (idaccount <= 0) return const [];
    try {
      final now = clock();
      final prefs = await store.read(idaccount);
      // Chỉ HỎI quyền, không xin — cùng lý lẽ trang Cài đặt thông báo.
      final coQuyen = prefs.osBat ? await os.daCoQuyen() : true;
      final giaoDich = await db.transactionDao
          .getByDateRange(idaccount, now.subtract(kCuaSoHoc), now);
      return deXuatThongBao(
        nhatKy: await db.notificationEventDao.getAll(idaccount),
        thongBao: await db.notificationDao.getAll(idaccount),
        mocGhiGiaoDich: mocGhiGiaoDichTu(giaoDich),
        prefs: prefs,
        coQuyen: coQuyen,
        now: now,
      );
    } catch (e) {
      debugPrint('[DeXuat] nạp đề xuất hỏng: $e');
      return const [];
    }
  }

  /// Người dùng gạt một đề xuất — im 30 ngày (`kImSauBoQua`).
  Future<void> boQua(int idaccount, DeXuatThongBao d) =>
      nhatKy.ghi(d.khoa, SuKienThongBao.boQuaDeXuat, idaccount: idaccount);
}
