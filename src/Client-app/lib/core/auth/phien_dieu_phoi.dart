/// Điều phối vòng đời PHIÊN đăng nhập (spec bịt điểm rò 2026-10-10, mục 6).
///
/// `AuthBloc` giữ trạng thái, thứ tự emit và các chốt `_vanLaPhien`; lớp này gói "bật / tắt những gì sống theo phiên"
/// để Bloc không biết tên dịch vụ và không chạm `sl` (test quét 24). Bước tách nhỏ cố ý: giữa [batThoiGianThuc] và
/// [batDongBo] Bloc kiểm `_vanLaPhien` sau một `await` — phép kiểm ấy thuộc trạng thái phiên nên ở lại Bloc.
library;

import 'buoc_dang_xuat.dart';

abstract class PhienDieuPhoi {
  /// Gộp "phiên có thể đã chết" của bộ đồng bộ và interceptor — Bloc hỏi lại server trước khi đăng xuất.
  Stream<void> get phienCoTheChet;

  /// Gộp lời từ chối mang lý do từ socket và HTTP — Bloc không hỏi lại.
  Stream<ThongBaoBuocDangXuat> get buocDangXuat;

  /// Pha cục bộ, TRƯỚC `AuthSuccess`: dọn tài khoản khác (xoá cache SLM nếu có dọn), chuyển hàng seed cũ, đặt gói (G93),
  /// bật bộ quét.
  Future<void> moPhienCucBo(int idaccount);

  /// Bật kênh thời gian thực.
  Future<void> batThoiGianThuc(int idaccount);

  /// Bật đồng bộ; [cho] đợi chu kỳ đầu rồi tạo bản sao danh mục (đăng nhập), không [cho] thì nối việc ấy vào sau (mở app).
  Future<void> batDongBo(int idaccount, {required bool cho});

  /// Chỉ sau đăng nhập mới: seed dữ liệu tài khoản mới, đặt lại cờ giao diện sống theo phiên app.
  Future<void> sauDangNhap(int idaccount);

  /// Dừng mọi thứ sống theo phiên: đồng bộ, bộ quét (kèm huỷ lịch), socket, ảnh quét chờ.
  Future<void> dongPhien();

  /// Xoá bản sao cục bộ của tài khoản — Bloc chỉ gọi khi `daXoa` và nguồn khác `lamMoi` (G36, giữ 2026-09-13).
  Future<void> xoaDuLieu(int idaccount);

  Future<void> dispose();
}
