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
/// thì theo máy, máy đặt tiếng Anh là lại "Select date"). Cùng tệp có hàm
/// `bocDongHo24Gio` (G90, nhóm cuối tệp) — `main.dart` cũng phải gọi nó.
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
          reason:
              'Ba hằng chỉ có tác dụng khi `MaterialApp.router` ở main.dart '
              'nhận đủ cả ba; thiếu "$ten" là hộp chọn ngày lại tiếng Anh.');
    }
  });

  // G90 (2026-10-12) — bảng chọn giờ trên máy đặt đồng hồ 12 giờ.
  //
  // Flutter lấy KIỂU HIỂN THỊ của bảng từ ngôn ngữ (`vi` = HH:mm, không có nút
  // SA/CH) nhưng ĐỌC GIỜ GÕ VÀO theo `MediaQuery.alwaysUse24HourFormat`, tức cài
  // đặt đồng hồ của máy. Máy 12 giờ thì hai bên lệch: ô giờ chỉ nhận 1–12 rồi
  // ghép với SA/CH ẨN của giờ đang chọn. Đo bằng test thăm dò 2026-10-12:
  // gõ 20 hoặc 0 → "Nhập thời gian hợp lệ"; từ 20:00 gõ 8 → lưu 20:00; từ 08:00
  // gõ 12 → lưu 00:00 — hai ca sau sai IM LẶNG, không một dòng lỗi.
  //
  // Môi trường `flutter test` mặc định là máy 12 giờ (`MediaQuery` đo được
  // `false`). ⚠️ `platformDispatcher.alwaysUse24HourFormatTestValue = true` KHÔNG
  // tới được `MediaQuery` của `MaterialApp` (đo cùng ngày) — đừng dùng nó để
  // giả máy 24 giờ; trục ấy nghiệm thu trên máy ảo.
  group('G90 — bảng chọn giờ trên máy 12 giờ', () {
    Future<({TimeOfDay? kq, bool coLoi})> moVaGo(
      WidgetTester tester, {
      required TransitionBuilder? builder,
      required TimeOfDay dau,
      required String go,
    }) async {
      TimeOfDay? kq;
      await tester.pumpWidget(MaterialApp(
        locale: kNgonNguApp,
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        builder: builder,
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async {
              kq = await showTimePicker(
                context: c,
                initialTime: dau,
                initialEntryMode: TimePickerEntryMode.input,
              );
            },
            child: const Text('mở'),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      final o = find.byType(TextField);
      await tester.enterText(o.at(0), go);
      await tester.enterText(o.at(1), '00');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      return (
        kq: kq,
        coLoi: find.textContaining('hợp lệ').evaluate().isNotEmpty,
      );
    }

    testWidgets('tiền đề: không bọc thì máy 12 giờ từ chối "20"',
        (tester) async {
      final r = await moVaGo(tester,
          builder: null, dau: const TimeOfDay(hour: 20, minute: 0), go: '20');
      expect(r.coLoi, isTrue,
          reason: 'Ca này neo bộ test vào "môi trường test = máy 12 giờ". Nó '
              'xanh-ngược (không lỗi) nghĩa là Flutter đã đổi cách đọc giờ hoặc '
              'môi trường test đổi mặc định — khi ấy các ca dưới không còn canh '
              'G90 nữa, phải đo lại.');
      expect(r.kq, isNull);
    });

    for (final ca in [
      (
        dau: const TimeOfDay(hour: 20, minute: 0),
        go: '20',
        ra: 20,
        vi: 'gõ 20 từng bị báo "Nhập thời gian hợp lệ"'
      ),
      (
        dau: const TimeOfDay(hour: 20, minute: 0),
        go: '0',
        ra: 0,
        vi: 'gõ 0 từng bị báo "Nhập thời gian hợp lệ"'
      ),
      (
        dau: const TimeOfDay(hour: 20, minute: 0),
        go: '8',
        ra: 8,
        vi: 'từ 20:00 gõ 8 từng lưu 20:00 — sai IM LẶNG'
      ),
      (
        dau: const TimeOfDay(hour: 8, minute: 0),
        go: '12',
        ra: 12,
        vi: 'từ 08:00 gõ 12 từng lưu 00:00 (nửa đêm) — sai IM LẶNG'
      ),
    ]) {
      testWidgets(
          'bọc bocDongHo24Gio: từ ${ca.dau.hour}:00 gõ "${ca.go}" → '
          '${ca.ra}:00', (tester) async {
        final r = await moVaGo(tester,
            builder: (c, child) => bocDongHo24Gio(c, child!),
            dau: ca.dau,
            go: ca.go);
        expect(r.coLoi, isFalse, reason: ca.vi);
        expect(r.kq, TimeOfDay(hour: ca.ra, minute: 0), reason: ca.vi);
      });
    }

    test('main.dart bọc cả app bằng bocDongHo24Gio', () {
      final ma = File('lib/main.dart').readAsStringSync();
      // `\s*`: `dart format` xuống dòng sau dấu `(` khi đối số thứ hai dài.
      expect(ma, contains(RegExp(r'bocDongHo24Gio\(\s*context,')),
          reason:
              'Hàm chỉ có tác dụng khi `MaterialApp.router` ở main.dart gọi '
              'nó trong `builder`; thiếu là mọi bảng chọn giờ trên máy 12 giờ '
              'lại từ chối giờ > 12 và hiểu sai 8 / 12 (G90).');
    });
  });
}
