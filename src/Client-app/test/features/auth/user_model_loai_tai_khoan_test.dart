/// `UserModel.loaiTaiKhoan` — `type` của `/auth/login` và `/auth/profile`
/// (`Basic` | `Premium`), chỉ `GoiRepository` đọc làm nhánh rơi về khi kho
/// trống và `/payment/*` hỏng (spec Premium 6.6).
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson đọc type; thiếu → Basic; toJson giữ', () {
    final p = UserModel.fromJson({
      'idaccount': 10,
      'username': 'a',
      'fullname': 'A',
      'email': 'a@x',
      'type': 'Premium',
    });
    expect(p.loaiTaiKhoan, 'Premium');
    expect(
        UserModel.fromJson({
          'idaccount': 10,
          'username': 'a',
          'fullname': 'A',
          'email': 'a@x',
        }).loaiTaiKhoan,
        'Basic',
        reason: 'bộ nhớ đệm của bản client cũ không có trường này');
    expect(UserModel.fromJson(p.toJson()).loaiTaiKhoan, 'Premium');
  });

  test('voiTrangThai và copyWith giữ loaiTaiKhoan; voiTrangThai đổi được', () {
    final p = UserModel(
        id: '10',
        username: 'a',
        name: 'A',
        email: 'a@x',
        loaiTaiKhoan: 'Premium');
    expect(p.voiTrangThai(status: 'Active').loaiTaiKhoan, 'Premium');
    expect(p.copyWith(name: 'B').loaiTaiKhoan, 'Premium');
    expect(p.voiTrangThai(status: 'Active', loaiTaiKhoan: 'Basic').loaiTaiKhoan,
        'Basic');
  });
}
