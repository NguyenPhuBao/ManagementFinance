/// App phải nói tiếng Việt ở CẢ những widget do Flutter vẽ — hộp chọn ngày,
/// giờ, nút Huỷ/OK, tên thứ, tuần bắt đầu thứ Hai.
///
/// Lượt đánh giá UX 2026-09-19 đo trên máy ảo: hộp chọn ngày ở màn Thêm giao
/// dịch hiện "Select date · Sat, Sep 19 · Cancel / OK" và tuần bắt đầu Chủ
/// nhật, giữa một giao diện tiếng Việt. Nguyên nhân: `MaterialApp` không khai
/// `localizationsDelegates`/`locale`, nên Flutter rơi về `en_US`.
///
/// Ba hằng ở `core/constants/app_localization.dart` là định nghĩa duy nhất;
/// `main.dart` phải nối đủ cả ba — thiếu một là hỏng im lặng (thiếu `locale`
/// thì theo máy, máy đặt tiếng Anh là lại "Select date").
library;

import 'dart:io';

import 'package:flowmoney/core/constants/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp dựng bằng ba hằng thì nút và ngày là tiếng Việt',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: kNgonNguApp,
      localizationsDelegates: kLocalizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    final ml = MaterialLocalizations.of(ctx);
    expect(ml.cancelButtonLabel, 'Huỷ',
        reason: 'Bản trước rơi về en_US: hộp chọn ngày hiện "Cancel".');
    expect(ml.firstDayOfWeekIndex, 1,
        reason: 'Lịch Việt Nam bắt đầu thứ Hai, không phải Chủ nhật.');
    expect(Localizations.localeOf(ctx).languageCode, 'vi');
  });

  testWidgets('hộp chọn ngày mở ra bằng tiếng Việt', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: kNgonNguApp,
      localizationsDelegates: kLocalizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => showDatePicker(
            context: c,
            initialDate: DateTime(2026, 9, 19),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
          child: const Text('mở'),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Select date'), findsNothing);
    expect(find.text('Chọn ngày'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Huỷ'), findsOneWidget);
  });

  test('main.dart nối đủ locale, delegates và supportedLocales', () {
    final ma = File('lib/main.dart').readAsStringSync();
    for (final ten in [
      'locale: kNgonNguApp',
      'localizationsDelegates: kLocalizationsDelegates',
      'supportedLocales: kSupportedLocales',
    ]) {
      expect(ma, contains(ten),
          reason: 'Ba hằng chỉ có tác dụng khi `MaterialApp.router` ở main.dart '
              'nhận đủ cả ba; thiếu "$ten" là hộp chọn ngày lại tiếng Anh.');
    }
  });
}
