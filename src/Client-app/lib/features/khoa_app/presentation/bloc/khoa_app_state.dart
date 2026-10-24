import 'package:equatable/equatable.dart';

const String kCauSaiPin = 'Mã PIN không đúng';
const String kCauVanTayDaDoi = 'Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại trong Cài đặt';
const String kCauVanTayTamKhoa = 'Vân tay tạm bị khoá — thử lại sau hoặc nhập mã PIN';
const String kCauVanTayHong = 'Không mở được bằng vân tay — nhập mã PIN';

/// Kho hỏng khi kiểm PIN — KHÔNG được nói "Mã PIN không đúng" (nói sai với người dùng), và lần ấy không tính sai.
const String kCauKhongKiemDuoc = 'Không kiểm được mã PIN — thử lại';

/// Trang Khoá ứng dụng: ghi / đọc kho hỏng (khuôn với câu của trang PIN).
const String kCauKhoAppKhongLuu = 'Không lưu được cài đặt khoá — thử lại';

sealed class TrangThaiKhoaApp extends Equatable {
  const TrangThaiKhoaApp();
  @override
  List<Object?> get props => [];
}

/// Chưa biết (mở lạnh / vừa đổi phiên): lớp phủ ĐẶC che nội dung.
class KhoaAppDangXet extends TrangThaiKhoaApp {
  const KhoaAppDangXet();
}

/// Không có phiên — không khoá (màn Đăng nhập).
class KhoaAppTat extends TrangThaiKhoaApp {
  const KhoaAppTat();
}

class KhoaAppMo extends TrangThaiKhoaApp {
  const KhoaAppMo({required this.daBat});
  final bool daBat;
  @override
  List<Object?> get props => [daBat];
}

class KhoaAppKhoa extends TrangThaiKhoaApp {
  const KhoaAppKhoa({
    required this.coVanTay,
    this.soLanSai = 0,
    this.choDen,
    this.loiNhan,
    this.dangKiem = false,
    this.lanKhoa = 0,
    this.lanKiem = 0,
  });

  final bool coVanTay;
  final int soLanSai;
  final DateTime? choDen;
  final String? loiNhan;
  final bool dangKiem;

  /// Tăng mỗi lần app vào trạng thái khoá — màn khoá tự mở hộp vân tay đúng MỘT lần mỗi lần khoá.
  final int lanKhoa;

  /// Tăng sau mỗi lượt kiểm PIN KẾT THÚC — sai, bị chặn vì đang chờ, kho hỏng. Màn khoá xoá sáu chấm khi số này
  /// đổi (không dựa vào khung trung gian `dangKiem: true`, vốn có thể không bao giờ được dựng — P13).
  final int lanKiem;

  @override
  List<Object?> get props => [coVanTay, soLanSai, choDen, loiNhan, dangKiem, lanKhoa, lanKiem];
}
