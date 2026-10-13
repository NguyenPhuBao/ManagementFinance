/// Tên, mô tả, biểu tượng của nhóm thông báo và tên thứ trong tuần dùng ở trang Cài đặt thông báo
/// (`notification_settings_page.dart`): năm hàm thuần, dời nguyên văn khỏi trang.
library;

import 'package:flutter/material.dart';

import '../../../../../core/notification/prefs/notification_prefs.dart';

String tenNhomThongBao(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return 'Hoá đơn';
    case NotificationGroup.budget:
      return 'Ngân sách';
    case NotificationGroup.goal:
      return 'Mục tiêu';
    case NotificationGroup.system:
      return 'Hệ thống';
    case NotificationGroup.summary:
      return 'Tổng kết';
    case NotificationGroup.bienDong:
      return 'Biến động số dư';
  }
}

String moTaNhomThongBao(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return 'Sắp đến hạn và quá hạn.';
    case NotificationGroup.budget:
      return 'Sắp chạm ngưỡng và đã vượt hạn mức.';
    case NotificationGroup.goal:
      return 'Hoàn thành và trễ tiến độ.';
    case NotificationGroup.system:
      return 'Đồng bộ hỏng và cảnh báo số dư ví.';
    case NotificationGroup.summary:
      return 'Nhìn lại tuần vừa qua.';
    case NotificationGroup.bienDong:
      return 'Đọc thông báo ngân hàng / ví điện tử trên máy để điền sẵn giao dịch.';
  }
}

IconData iconNhomThongBao(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return Icons.receipt_long_outlined;
    case NotificationGroup.budget:
      return Icons.account_balance_wallet_outlined;
    case NotificationGroup.goal:
      return Icons.flag_outlined;
    case NotificationGroup.system:
      return Icons.sync_problem_outlined;
    case NotificationGroup.summary:
      return Icons.calendar_view_week_outlined;
    case NotificationGroup.bienDong:
      return Icons.account_balance_outlined;
  }
}

/// Tên thứ giữa câu: chữ thường ở đầu (*"thứ Bảy"*, *"chủ nhật"*).
String tenThuThuongThongBao(int thu) {
  final t = tenThuThongBao(thu);
  return t[0].toLowerCase() + t.substring(1);
}

/// Tên thứ trong tuần theo quy ước `DateTime.weekday` (1 = thứ Hai).
String tenThuThongBao(int thu) => switch (thu) {
      DateTime.tuesday => 'Thứ Ba',
      DateTime.wednesday => 'Thứ Tư',
      DateTime.thursday => 'Thứ Năm',
      DateTime.friday => 'Thứ Sáu',
      DateTime.saturday => 'Thứ Bảy',
      DateTime.sunday => 'Chủ nhật',
      // Thứ Hai là mặc định, và cũng là chỗ rơi cho giá trị lạ — `fromJson` đã
      // kẹp về dải 1–7 nên nhánh này chỉ còn là lưới cuối.
      _ => 'Thứ Hai',
    };
