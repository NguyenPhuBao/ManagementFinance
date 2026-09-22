import 'dart:async';

/// Kênh thông báo tự do một dòng — bất kỳ chỗ nào trong app muốn nói một câu
/// ngắn thì đẩy vào đây, và `AppToast` (ở `MaterialApp.builder`, phủ mọi trang)
/// vẽ nó thành viên toast nổi ở đáy, tự ẩn.
///
/// Thêm 2026-09-19 cho "Nhấn lần nữa để thoát" (E3 của lượt UX). Lý do không
/// dùng `SnackBar`: nếp đã chốt của dự án là thông báo tạm thời phải là
/// **viên nhỏ thu gọn theo nội dung**, không phải dải kín ngang màn hình — và
/// app đã có đúng viên ấy trong `AppToast`, chỉ thiếu một lối đẩy chữ tự do
/// vào. Đăng ký ở `injection_container.dart`; người gọi lấy qua
/// `sl<ThongBaoNhanh>().hien(...)`.
class ThongBaoNhanh {
  final _ctl = StreamController<String>.broadcast();

  Stream<String> get stream => _ctl.stream;

  void hien(String cau) {
    if (!_ctl.isClosed) _ctl.add(cau);
  }

  Future<void> dispose() => _ctl.close();
}
