import 'dart:async';

import 'package:flutter/foundation.dart';

import '../di/injection_container.dart';

/// Kênh thông báo tự do một dòng — bất kỳ chỗ nào trong app muốn nói một câu
/// ngắn thì đẩy vào đây, và `AppToast` (ở `MaterialApp.builder`, phủ mọi trang)
/// vẽ nó thành viên toast nổi ở đáy, tự ẩn.
///
/// Thêm 2026-09-19 cho "Nhấn lần nữa để thoát" (E3 của lượt UX). Lý do không
/// dùng `SnackBar`: nếp đã chốt của dự án là thông báo tạm thời phải là
/// **viên nhỏ thu gọn theo nội dung**, không phải dải kín ngang màn hình — và
/// app đã có đúng viên ấy trong `AppToast`, chỉ thiếu một lối đẩy chữ tự do
/// vào. Đăng ký ở `injection_container.dart`; người gọi lấy qua
/// `sl<ThongBaoNhanh>().hien(...)` hoặc hàm gọn [baoNhanh].
///
/// E4 (2026-10-06, người dùng duyệt): mọi `SnackBar` của các trang chuyển sang
/// kênh này. Câu mang [LoaiThongBao] (màu + biểu tượng của viên) và có thể mang
/// một [HanhDongToast] ("Hoàn tác"). Mọi câu đi qua đây là **phản hồi cho cú
/// bấm của người dùng** — `AppToast` cho chúng bậc cao nhất.
class ThongBaoNhanh {
  final _ctl = StreamController<ThongDiepNhanh>.broadcast();

  Stream<ThongDiepNhanh> get stream => _ctl.stream;

  void hien(String cau, {LoaiThongBao loai = LoaiThongBao.thongTin, HanhDongToast? hanhDong}) {
    if (!_ctl.isClosed) _ctl.add(ThongDiepNhanh(cau, loai: loai, hanhDong: hanhDong));
  }

  Future<void> dispose() => _ctl.close();
}

/// Màu và biểu tượng của viên: **lỗi** (đỏ — câu "Vui lòng…", lỗi bắt được),
/// **xong** (xanh — câu "Đã…"), **thông tin** (đen — mặc định).
enum LoaiThongBao { thongTin, loi, xong }

/// Nút chữ ở bên phải viên. Bấm → chạy [chay] rồi viên ẩn; không bấm thì viên
/// vẫn tự ẩn như mọi viên khác (khác `SnackBar` có `action` — Flutter giữ nó tới
/// khi người dùng chạm).
@immutable
class HanhDongToast {
  const HanhDongToast(this.nhan, this.chay);

  final String nhan;
  final VoidCallback chay;
}

@immutable
class ThongDiepNhanh {
  const ThongDiepNhanh(this.cau, {this.loai = LoaiThongBao.thongTin, this.hanhDong});

  final String cau;
  final LoaiThongBao loai;
  final HanhDongToast? hanhDong;
}

/// Lối gọn cho các trang: đẩy [cau] vào kênh đăng ký ở DI. Chưa đăng ký (vài
/// widget test dựng trang trần) thì bỏ qua — test nào cần kiểm câu thì đăng ký
/// một [ThongBaoNhanh] rồi nghe `stream`.
void baoNhanh(String cau, {LoaiThongBao loai = LoaiThongBao.thongTin, HanhDongToast? hanhDong}) {
  if (sl.isRegistered<ThongBaoNhanh>()) sl<ThongBaoNhanh>().hien(cau, loai: loai, hanhDong: hanhDong);
}
