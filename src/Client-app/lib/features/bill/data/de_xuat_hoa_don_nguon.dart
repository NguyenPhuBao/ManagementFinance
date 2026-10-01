/// Nguồn dữ liệu của thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn (B2).
///
/// Đọc giao dịch 120 ngày, hoá đơn và phản hồi của MỘT tài khoản rồi gọi hai
/// hàm thuần `timKhoanLap` → `chonDeXuatHoaDon`. Không có repository mới:
/// `BillBloc` không đổi, thẻ tự nạp qua lớp này.
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
/// mục 4.
library;

// Chỉ `debugPrint`: `foundation.dart` còn xuất chú thích `Category`, trùng tên
// data class danh mục của Drift.
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../transaction/domain/khoan_lap.dart';
import '../domain/de_xuat_hoa_don.dart';

class DeXuatHoaDonNguon {
  DeXuatHoaDonNguon({
    required this.db,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? const Uuid().v4;

  final AppDatabase db;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// `null` = không có gì để gợi ý (hoặc nạp hỏng) — thẻ không dựng gì.
  ///
  /// Nuốt lỗi: thẻ là gợi ý phụ trên trang Hoá đơn, một trục trặc ở đây không
  /// được làm vỡ trang.
  Future<List<KhoanLap>?> tai(int idaccount) async {
    // `idaccount` CHỈ từ phiên (quy tắc 2) — id hỏng thì không đọc gì.
    if (idaccount <= 0) return null;
    try {
      final now = clock();
      final tu = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: kCuaSoKhoanLapNgay));
      final giaoDich = await db.transactionDao.getByDateRange(idaccount, tu, now);
      final hoaDon = await db.billDao.getAll(idaccount);
      final phanHoi = await db.goiYHoaDonDao.getAll(idaccount);
      return chonDeXuatHoaDon(
        ds: timKhoanLap(giaoDich, now: now),
        hoaDon: hoaDon,
        phanHoi: phanHoi,
        giaoDich: giaoDich,
        now: now,
      );
    } catch (e) {
      debugPrint('[KhoanLap] nạp gợi ý hỏng: $e');
      return null;
    }
  }

  /// Bảng tra danh mục cho biểu tượng / màu của từng dòng — qua
  /// `getBangTraTen`, định nghĩa duy nhất của bảng tra (giữ cả hàng mặc định
  /// toàn cục, G41). Hỏng thì bảng rỗng: dòng rơi về biểu tượng mặc định.
  Future<Map<String, Category>> bangDanhMuc(int idaccount) async {
    if (idaccount <= 0) return const {};
    try {
      final ds = await db.categoryDao.getBangTraTen(idaccount);
      return {for (final c in ds) c.id: c};
    } catch (e) {
      debugPrint('[KhoanLap] nạp bảng danh mục hỏng: $e');
      return const {};
    }
  }

  Future<void> boQua(int idaccount, String khoaNhom) => _ghi(idaccount, khoaNhom, kGoiYBoQua);

  Future<void> daTao(int idaccount, String khoaNhom) => _ghi(idaccount, khoaNhom, kGoiYDaTao);

  Future<void> _ghi(int idaccount, String khoaNhom, String ketQua) async {
    if (idaccount <= 0) return;
    try {
      await db.goiYHoaDonDao.ghi(GoiYHoaDonPhanHoisCompanion.insert(
        id: idGenerator(),
        idaccount: idaccount,
        khoaNhom: khoaNhom,
        ketQua: ketQua,
        createdAt: clock(),
      ));
    } catch (e) {
      debugPrint('[KhoanLap] ghi $ketQua hỏng: $e');
    }
  }
}
