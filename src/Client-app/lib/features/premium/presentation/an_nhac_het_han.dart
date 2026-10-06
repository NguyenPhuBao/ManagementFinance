import 'package:flutter/foundation.dart';

/// Cờ ✕ của dòng nhắc hết hạn Trang chủ — trong bộ nhớ, theo **ngày** và theo
/// tài khoản (spec Premium 9.5); khuôn `AnNhacViTrungTen`. Qua ngày mới dòng
/// hiện lại; tài khoản khác không thừa hưởng nên không cần đặt lại khi đổi phiên.
class AnNhacHetHan extends ValueNotifier<({int idaccount, DateTime ngay})?> {
  AnNhacHetHan() : super(null);

  static DateTime _ngay(DateTime t) => DateTime(t.year, t.month, t.day);

  bool daAn(int idaccount, DateTime now) {
    final v = value;
    return v != null && v.idaccount == idaccount && v.ngay == _ngay(now);
  }

  void an(int idaccount, DateTime now) =>
      value = (idaccount: idaccount, ngay: _ngay(now));
}
