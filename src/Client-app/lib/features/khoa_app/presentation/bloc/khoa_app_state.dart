import 'package:equatable/equatable.dart';

const String kCauSaiPin = 'Mã PIN không đúng';
const String kCauVanTayDaDoi = 'Vân tay trên máy đã thay đổi — nhập mã PIN rồi bật lại trong Cài đặt';

/// M14: alias Keystore không còn (đăng xuất bị cắt giữa chừng) — người dùng không đổi vân tay nào, đừng nói "đã thay đổi".
const String kCauVanTayDaTat = 'Vân tay đã tắt — nhập mã PIN rồi bật lại trong Cài đặt';
const String kCauVanTayTamKhoa = 'Vân tay tạm bị khoá — thử lại sau hoặc nhập mã PIN';
const String kCauVanTayHong = 'Không mở được bằng vân tay — nhập mã PIN';

/// Kho hỏng khi kiểm PIN — KHÔNG được nói "Mã PIN không đúng" (nói sai với người dùng), và lần ấy không tính sai.
const String kCauKhongKiemDuoc = 'Không kiểm được mã PIN — thử lại';

/// Trang Đặt / Đổi / Tắt mã PIN: ghi PIN mới hỏng.
const String kCauKhongLuuPin = 'Không lưu được mã PIN — thử lại';

/// Trang Khoá ứng dụng: ghi / đọc kho hỏng (khuôn với câu của trang PIN).
const String kCauKhoAppKhongLuu = 'Không lưu được cài đặt khoá — thử lại';

/// M11 (người dùng chốt 2026-10-25): đăng nhập bằng mật khẩu đã xoá khoá của tài khoản này — viên toast một lần.
const String kCauKhoaVuaTat = 'Khoá ứng dụng đã tắt — bật lại trong Cài đặt';

sealed class TrangThaiKhoaApp extends Equatable {
  const TrangThaiKhoaApp();
  @override
  List<Object?> get props => [];
}

/// Chưa biết (mở lạnh / vừa đổi phiên): lớp phủ ĐẶC che nội dung.
class KhoaAppDangXet extends TrangThaiKhoaApp {
  const KhoaAppDangXet();
}

/// Đang rời phiên (đang khoá / đang xét rồi mất phiên): giữ lớp phủ ĐẶC, cùng hình với [KhoaAppDangXet], cho tới khi router
/// đã đứng yên ở route công khai — gỡ sớm hơn là trang được bảo vệ lộ ra dưới hiệu ứng chuyển sang màn Đăng nhập.
class KhoaAppDangRoi extends TrangThaiKhoaApp {
  const KhoaAppDangRoi();
}

/// Không có phiên — không khoá (màn Đăng nhập).
class KhoaAppTat extends TrangThaiKhoaApp {
  const KhoaAppTat();
}

class KhoaAppMo extends TrangThaiKhoaApp {
  const KhoaAppMo({required this.daBat, this.che = false});
  final bool daBat;

  /// F1 (nghiệm thu Realme 2026-10-25): app vừa mất tiêu điểm (`inactive`) khi khoá đang bật — lớp phủ vẽ nền ĐẶC để khung
  /// cuối trước khi app rời màn không mang nội dung (engine vẽ lại khung ấy lên surface mới TRƯỚC khi Dart nhận `resumed`).
  /// Vẫn là trạng thái *mở*: mọi cổng `state is KhoaAppMo` của luật tự khoá giữ nguyên.
  final bool che;

  @override
  List<Object?> get props => [daBat, che];
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
