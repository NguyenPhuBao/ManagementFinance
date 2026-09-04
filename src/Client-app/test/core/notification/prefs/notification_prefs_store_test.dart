/// Kho tuỳ chọn thông báo.
///
/// Điều đáng canh nhất **không phải** đọc/ghi chạy được, mà là **tách theo
/// tài khoản**. Máy dùng chung là chuyện thật trong dự án này —
/// `purgeDataForOtherAccounts` tồn tại chính vì thế. Một khoá lưu chung cho
/// mọi tài khoản nghĩa là người đăng nhập sau thừa hưởng công tắc của người
/// trước, và cách nó biểu hiện là "tôi bật thông báo rồi mà chẳng thấy gì" —
/// không lỗi, không log.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageNotificationPrefsStore', () {
    late SecureStorageNotificationPrefsStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = const SecureStorageNotificationPrefsStore(FlutterSecureStorage());
    });

    test('chưa lưu gì thì đọc ra bản mặc định', () async {
      expect(await store.read(7), NotificationPrefs.macDinh,
          reason: 'Đây là đường đi của mọi tài khoản đã tồn tại trước bản này. '
              'Trả null hoặc ném ở đây là tính năng chết ngay với họ.');
    });

    test('ghi rồi đọc lại ra đúng thứ đã ghi', () async {
      const p = NotificationPrefs(
        osBat: false,
        nhomTat: {NotificationGroup.goal},
        gioNhac: 21,
        phutNhac: 15,
        soNgayNhacHoaDon: 5,
      );

      await store.write(7, p);

      expect(await store.read(7), p);
    });

    test('hai tài khoản không thấy tuỳ chọn của nhau', () async {
      await store.write(7, const NotificationPrefs(osBat: false));
      await store.write(9, const NotificationPrefs(gioNhac: 20));

      final cua7 = await store.read(7);
      final cua9 = await store.read(9);

      expect(cua7.osBat, isFalse);
      expect(cua9.osBat, isTrue,
          reason: 'Máy dùng chung là chuyện thật ở dự án này. Lẫn khoá giữa hai '
              'tài khoản thì người đăng nhập sau thừa hưởng công tắc của người '
              'trước, và biểu hiện là "tôi bật rồi mà chẳng thấy gì".');
      expect(cua9.gioNhac, 20);
      expect(cua7.gioNhac, 8);
    });

    test('JSON hỏng trên đĩa cho ra bản mặc định chứ không ném', () async {
      FlutterSecureStorage.setMockInitialValues({
        'notification_prefs_7': '{ đây không phải json',
      });

      expect(await store.read(7), NotificationPrefs.macDinh,
          reason: 'Nơi gọi là vòng quét thông báo; ném ở đây làm chết cả trung '
              'tâm thông báo trong app.');
    });

    test('JSON hợp lệ nhưng không phải object cũng cho ra mặc định', () async {
      FlutterSecureStorage.setMockInitialValues({
        'notification_prefs_7': '[1, 2, 3]',
      });

      expect(await store.read(7), NotificationPrefs.macDinh);
    });

    test('clear() đưa tài khoản về mặc định và không đụng tài khoản khác',
        () async {
      await store.write(7, const NotificationPrefs(osBat: false));
      await store.write(9, const NotificationPrefs(osBat: false));

      await store.clear(7);

      expect(await store.read(7), NotificationPrefs.macDinh);
      expect((await store.read(9)).osBat, isFalse,
          reason: 'Đăng xuất một tài khoản không được xoá tuỳ chọn của tài '
              'khoản khác trên cùng máy.');
    });

    test('ghi ra JSON đọc được, không phải chuỗi mờ', () async {
      await store.write(7, const NotificationPrefs(gioNhac: 21));

      final raw = await const FlutterSecureStorage()
          .read(key: 'notification_prefs_7');
      final json = jsonDecode(raw!) as Map<String, Object?>;

      expect(json['gioNhac'], 21,
          reason: 'Giữ dạng JSON để còn đọc được lúc gỡ lỗi trên máy thật, và '
              'để bản app sau thêm trường mà không phá bản ghi cũ.');
    });
  });

  group('InMemoryNotificationPrefsStore', () {
    test('hành xử giống bản thật: mặc định, ghi/đọc, tách tài khoản', () async {
      final store = InMemoryNotificationPrefsStore();

      expect(await store.read(7), NotificationPrefs.macDinh);

      await store.write(7, const NotificationPrefs(osBat: false));
      expect((await store.read(7)).osBat, isFalse);
      expect((await store.read(9)).osBat, isTrue);

      await store.clear(7);
      expect(await store.read(7), NotificationPrefs.macDinh);
    });
  });
}
