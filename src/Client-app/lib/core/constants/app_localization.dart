import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Ngôn ngữ của app — một định nghĩa duy nhất, `main.dart` nối vào
/// `MaterialApp.router` (có test canh cả ba hằng được nối).
///
/// Thêm 2026-09-19 sau lượt đánh giá UX: không khai gì thì Flutter vẽ hộp chọn
/// ngày bằng `en_US` — "Select date · Sat, Sep 19 · Cancel / OK", tuần bắt đầu
/// Chủ nhật — giữa một giao diện tiếng Việt. Chữ của app thì tiếng Việt vì
/// viết cứng; chữ do Flutter vẽ (date picker, time picker, nút hộp thoại, tooltip
/// của back/menu) thì đi qua `MaterialLocalizations`, và lớp ấy chỉ nói tiếng
/// Việt khi có `GlobalMaterialLocalizations` cùng `locale` tương ứng.
///
/// Ghim `locale` thay vì theo máy: app chỉ có một ngôn ngữ, và một máy đặt
/// tiếng Anh sẽ lại thấy "Select date" trong khi mọi chữ khác vẫn tiếng Việt.
const Locale kNgonNguApp = Locale('vi');

const List<Locale> kSupportedLocales = [kNgonNguApp];

const List<LocalizationsDelegate<dynamic>> kLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Ép cả app dùng đồng hồ 24 giờ, bất kể máy đặt 12 hay 24 giờ — `main.dart`
/// gọi trong `builder` của `MaterialApp.router` (có test canh).
///
/// G90 (2026-10-12): bảng chọn giờ của Flutter lấy KIỂU HIỂN THỊ từ ngôn ngữ
/// (`vi` = HH:mm, không có nút SA/CH) nhưng ĐỌC GIỜ GÕ VÀO theo
/// `MediaQuery.alwaysUse24HourFormat`, tức cài đặt của máy. Máy đặt 12 giờ thì
/// hai bên lệch: ô giờ chỉ nhận 1–12 rồi ghép với SA/CH ẩn của giờ đang chọn —
/// gõ 20 bị báo "Nhập thời gian hợp lệ", còn từ 20:00 gõ 8 thì lưu 20:00 và từ
/// 08:00 gõ 12 thì lưu 00:00, im lặng. Cùng lý lẽ với việc ghim `locale`: app
/// chỉ có một ngôn ngữ, và tiếng Việt viết giờ kiểu 24 giờ.
///
/// Đặt ở tầng app chứ không ở từng chỗ gọi `showTimePicker`: bảng chọn giờ thứ
/// sáu thêm sau này tự đúng mà không ai phải nhớ. Không chỗ nào khác trong
/// `lib/` đọc cờ ấy (đo 2026-10-12), nên ép nó không đổi gì nhìn thấy được ngoài
/// bảng chọn giờ.
Widget bocDongHo24Gio(BuildContext context, Widget child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child,
    );
