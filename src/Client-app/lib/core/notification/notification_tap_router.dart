import 'dart:async';

import 'notification_deeplink.dart';
import 'os/os_notifier.dart';

/// Biến một cú chạm vào thông báo cấp hệ điều hành thành một lần điều hướng.
///
/// ## Vì sao là một lớp riêng chứ không nằm trong `OsNotifier`
///
/// `os_notifier_native.dart` là file **duy nhất** được phép import
/// `flutter_local_notifications`; kéo router vào đó là kéo cả go_router theo,
/// và bẫy 7.7 quay lại. Ngược lại, lớp này không biết gì về nền tảng: nó nhận
/// payload qua [OsNotifier] và trả route qua một callback, nên test chạy được
/// mà không cần binding lẫn cây widget.
///
/// ## Ba tình huống nó tồn tại để xử lý
///
/// 1. **Cold start.** Lịch nhắc hoá đơn nổ khi app đã đóng hẳn — ca *chính*
///    của lịch đặt trước, không phải ca phụ. Payload khi ấy chỉ lấy được qua
///    [OsNotifier.payloadKhoiDong].
/// 2. **Điều hướng hai lần.** Trên Android cùng một cú chạm có thể vừa nằm
///    trong chi tiết khởi động vừa được đẩy lên qua callback.
/// 3. **Chưa đăng nhập.** Token hết hạn sau vài ngày app đóng là chuyện
///    thường; điều hướng lúc ấy chỉ bị guard của router đá về `/login`.
class NotificationTapRouter {
  NotificationTapRouter({
    required this.osNotifier,
    required this.dieuHuong,
    required this.dangDangNhap,
    required this.phienDoi,
  });

  final OsNotifier osNotifier;

  /// Thực hiện điều hướng. Nơi gọi tự chọn `go` hay `push` bằng
  /// `thuocThanhTab()` — `push` một route trong shell từ ngoài shell làm app
  /// chết màn đỏ (bẫy 7.8).
  final void Function(String route) dieuHuong;

  /// Có phiên đăng nhập dùng được ngay lúc này không.
  ///
  /// Là hàm chứ không phải giá trị: [phienDoi] chỉ báo "có gì đó vừa đổi", còn
  /// trạng thái hiện tại phải hỏi lại nguồn thật. Nghe riêng stream thì một
  /// phiên đã đăng nhập TRƯỚC khi lớp này khởi động sẽ không bao giờ thấy.
  final bool Function() dangDangNhap;

  /// Phát mỗi khi phiên đăng nhập đổi trạng thái.
  final Stream<void> phienDoi;

  StreamSubscription<String>? _subCham;
  StreamSubscription<void>? _subPhien;

  /// Route đang chờ một phiên đăng nhập.
  ///
  /// Chỉ giữ **cái mới nhất**, không xếp hàng: xả cả hàng đợi sau khi đăng
  /// nhập là app tự nhảy qua mấy màn liên tiếp, còn người dùng thì chỉ đang
  /// chờ đúng thứ họ vừa bấm.
  String? _choDoi;

  /// Payload đã xử lý ở đường khởi động, giữ lại để **bỏ qua đúng một lần** nếu
  /// nền tảng đẩy tiếp chính nó qua callback. Nhớ mãi thì thông báo ấy chết
  /// vĩnh viễn trong cả phiên chạy.
  String? _boQuaMotLan;

  Future<void> start() async {
    await _subCham?.cancel();
    await _subPhien?.cancel();

    // Đọc chi tiết khởi động TRƯỚC khi nghe stream, không phải sau. Ngược lại
    // thì một cú chạm đẩy lên trong lúc đang `await` sẽ được xử lý xong xuôi
    // rồi chi tiết khởi động lại xử lý nó lần nữa — và `_boQuaMotLan` chưa kịp
    // được đặt để chặn.
    final khoiDong = await osNotifier.payloadKhoiDong();
    if (khoiDong != null) {
      // Xử lý TRƯỚC rồi mới dựng cờ chặn: đặt cờ trước thì `_xuLy` khớp ngay
      // với chính cú chạm này và bỏ qua nó — đúng cái nó sinh ra để bảo vệ.
      _xuLy(khoiDong);
      _boQuaMotLan = khoiDong;
    }

    _subCham = osNotifier.payloadDaCham.listen(_xuLy);
    _subPhien = phienDoi.listen((_) => _xaChoDoi());
  }

  Future<void> stop() async {
    await _subCham?.cancel();
    _subCham = null;
    await _subPhien?.cancel();
    _subPhien = null;
    _choDoi = null;
    _boQuaMotLan = null;
  }

  void _xuLy(String payload) {
    if (payload == _boQuaMotLan) {
      _boQuaMotLan = null;
      return;
    }

    final route = deeplinkTuDedupeKey(payload);
    if (!dangDangNhap()) {
      _choDoi = route;
      return;
    }
    dieuHuong(route);
  }

  void _xaChoDoi() {
    final route = _choDoi;
    if (route == null) return;
    // Vẫn chưa đăng nhập thì GIỮ tiếp — sự kiện này có thể là một bước trung
    // gian của luồng đăng nhập chứ không phải kết quả cuối.
    if (!dangDangNhap()) return;
    _choDoi = null;
    dieuHuong(route);
  }
}
