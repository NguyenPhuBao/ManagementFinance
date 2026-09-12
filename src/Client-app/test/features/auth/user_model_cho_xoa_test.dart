/// Trạng thái chờ xoá nằm trong `UserModel` — spec cưỡng chế đăng xuất §4.1.
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON đệm của bản cũ (không có ba trường) đọc thành Active', () {
    final user = UserModel.fromJson({
      'idaccount': '11',
      'username': 'dat',
      'fullname': 'Đạt',
      'email': 'dat@example.com',
      'rolename': 'user',
    });
    expect(user.status, 'Active');
    expect(user.countdown, isNull);
    expect(user.countdownNhanLuc, isNull);
    expect(user.dangChoXoa, isFalse,
        reason: 'Máy đăng nhập từ trước bản này không được tự nhiên hiện thẻ chờ xoá.');
  });

  test('đọc status và countdown từ response đăng nhập của backend', () {
    final user = UserModel.fromJson({
      'idaccount': 11,
      'username': 'dat',
      'fullname': 'Đạt',
      'email': 'dat@example.com',
      'rolename': 'user',
      'status': 'PendingDelete',
      'countdown': 30,
    });
    expect(user.id, '11');
    expect(user.dangChoXoa, isTrue);
    expect(user.countdown, 30);
  });

  test('vòng toJson/fromJson giữ countdown và countdown_nhan_luc', () {
    final goc = UserModel(
      id: '11',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
      status: 'PendingDelete',
      countdown: 12,
      countdownNhanLuc: DateTime.utc(2026, 9, 11, 3, 15),
    );
    final lai = UserModel.fromJson(goc.toJson());
    expect(lai.status, 'PendingDelete');
    expect(lai.countdown, 12);
    expect(lai.countdownNhanLuc, DateTime.utc(2026, 9, 11, 3, 15),
        reason: 'Mất mốc nhận thì số ngày còn lại đứng yên ở con số lúc đăng nhập.');
  });

  test('dangChoXoa không phân biệt hoa thường, như middleware/auth.js', () {
    UserModel voi(String status) =>
        UserModel(id: '11', username: 'dat', name: 'Đạt', email: 'e', status: status);
    expect(voi('PendingDelete').dangChoXoa, isTrue);
    expect(voi('pendingdelete').dangChoXoa, isTrue);
    expect(voi('Active').dangChoXoa, isFalse);
  });

  test('voiTrangThai huỷ xoá thì bỏ countdown, giữ danh tính', () {
    final choXoa = UserModel(
      id: '11',
      username: 'dat',
      name: 'Đạt',
      email: 'e',
      status: 'PendingDelete',
      countdown: 30,
      countdownNhanLuc: DateTime.utc(2026, 9, 11),
    );
    final hoatDong = choXoa.voiTrangThai(status: 'Active');
    expect(hoatDong.id, '11');
    expect(hoatDong.name, 'Đạt');
    expect(hoatDong.dangChoXoa, isFalse);
    expect(hoatDong.countdown, isNull);
    expect(hoatDong.countdownNhanLuc, isNull);
  });
}
