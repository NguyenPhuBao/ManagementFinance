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

  /// Đăng nhập bằng MẬT KHẨU vừa được server chấp nhận (id hợp lệ) — gọi NGAY, trước [moPhienCucBo]. Khoá ứng dụng: xoá cấu hình
  /// PIN cũ của máy tại đây (đăng nhập bằng mật khẩu = đã chứng minh quyền sở hữu, PIN cũ hết ý nghĩa; đúng người đã quên PIN).
  /// ⚠️ KHÔNG gọi từ [moPhienCucBo] (chạy cả lúc mở lạnh — sẽ xoá PIN mỗi lần mở app) và KHÔNG chờ tới [sauDangNhap] (sau cả vòng
  /// đồng bộ đầu; tiến trình bị giết giữa chừng thì token còn + PIN cũ còn = hỏi lại đúng PIN vừa quên).
  Future<void> sauXacThucMatKhau(int idaccount);

  /// Pha cục bộ, TRƯỚC `AuthSuccess`: dọn tài khoản khác (xoá cache SLM nếu có dọn), chuyển hàng seed cũ, đặt gói (G93),
  /// bật bộ quét.
  Future<void> moPhienCucBo(int idaccount);

  /// Bật kênh thời gian thực.
  Future<void> batThoiGianThuc(int idaccount);

  /// Bật đồng bộ; [cho] đợi chu kỳ đầu (đăng nhập), không [cho] thì không đợi (mở app). Bản sao danh mục mặc định tạo
  /// trong chu kỳ đồng bộ, sau mỗi lượt kéo về thành công (`SyncEngine.sauKeoVe`, quy tắc 8).
  Future<void> batDongBo(int idaccount, {required bool cho});

  /// Chỉ sau đăng nhập mới (sau [batDongBo] chu kỳ đầu): seed dữ liệu tài khoản mới, đặt lại cờ giao diện sống theo phiên app.
  Future<void> sauDangNhap(int idaccount);

  /// Dừng mọi thứ sống theo phiên: đồng bộ, bộ quét (kèm huỷ lịch), socket, ảnh quét chờ, và khoá VÂN TAY của khoá ứng dụng
  /// (alias Keystore). Cấu hình PIN KHÔNG xoá ở đây — xem [sauXacThucMatKhau].
  Future<void> dongPhien();

  Future<void> dispose();
}
