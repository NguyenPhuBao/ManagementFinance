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
