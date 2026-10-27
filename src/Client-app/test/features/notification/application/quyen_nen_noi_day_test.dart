/// B1 (spec 2026-10-27 mục 5) — DI nối vị từ quyền vào hai bộ nhắc, và `main.dart` nối "quyền đổi → resync". Hai chỗ này
/// không có test hành vi (DI và `main` không dựng trong `flutter test`) — ca đọc nguồn canh chúng không rơi mất.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Bỏ dòng chú thích (khuôn quét 21): một dòng nối bị comment không được tính là còn nối.
  String boChuThich(String nguon) =>
      nguon.split('\n').where((d) => !d.trim().startsWith('//')).join('\n');
  final di = boChuThich(File('lib/core/di/injection_container.dart').readAsStringSync());

  test('DI nối nhacTruocHanDuocPhep ở CẢ ReminderScheduler lẫn NotificationScanner', () {
    expect('nhacTruocHanDuocPhep: () => coQuyenNen(MaQuyen.billReminderNotifications)'.allMatches(di).length, 2,
        reason: 'thiếu ở bộ đặt lịch là lịch HĐH vẫn nổ; thiếu ở bộ quét là thông báo trong app vẫn sinh');
  });

  test('DI nối nhacGhiChepDuocPhep và canhBaoNganSachDuocPhep', () {
    expect(di, contains('nhacGhiChepDuocPhep: () => coQuyenNen(MaQuyen.dailyRecordingReminder)'));
    expect(di, contains('canhBaoNganSachDuocPhep: () => coQuyenNen(MaQuyen.budgetOverspendAlert)'));
  });

  test('main.dart nối quyền nhắc đổi → ReminderScheduler.resync', () {
    final main = boChuThich(File('lib/main.dart').readAsStringSync());
    expect(main, contains('noiKhiQuyenDoi('));
    expect(main, contains('MaQuyen.dailyRecordingReminder'));
    expect(main, contains('MaQuyen.billReminderNotifications'));
    expect(main, contains('sl<ReminderScheduler>().resync('));
  });
}
