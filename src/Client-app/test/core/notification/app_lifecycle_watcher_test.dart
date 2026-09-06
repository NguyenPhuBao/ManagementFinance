/// `AppLifecycleWatcher` — file DUY NHẤT trong vùng thông báo chạm
/// `WidgetsBinding`.
///
/// Nó tồn tại để `NotificationScanner` nhận vòng đời app qua một `Stream` tiêm
/// vào, đúng khuôn `SyncEngine.statusStream`. Hai điều đáng canh, cả hai đều
/// hỏng **âm thầm**:
///
/// 1. **Stream phải là broadcast.** `NotificationScanner.start()` huỷ
///    subscription cũ rồi nghe lại — với stream một-người-nghe thì lần nghe
///    thứ hai ném `Bad state: Stream has already been listened to`, và lỗi ấy
///    nổ bên trong `start()` trên đường đăng nhập.
/// 2. **`dispose()` phải gỡ observer khỏi binding.** Còn sót là mỗi lần dựng
///    lại phụ thuộc thêm một observer, và một lần mở lại app thành n lượt quét.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/app_lifecycle_watcher.dart';

void main() {
  late TestWidgetsFlutterBinding binding;

  setUp(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('phát ra trạng thái mà hệ điều hành báo về', () async {
    final watcher = AppLifecycleWatcher();
    addTearDown(watcher.dispose);

    final nhan = watcher.stream.first;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    expect(await nhan, AppLifecycleState.inactive,
        reason: 'Nếu watcher không thật sự được đăng ký vào WidgetsBinding thì '
            'stream im lặng mãi mãi — không lỗi, không log, và scanner chỉ '
            'đơn giản là không bao giờ chạy khi app quay lại.');
  });

  test('stream là broadcast: nghe lại sau khi huỷ vẫn được', () async {
    final watcher = AppLifecycleWatcher();
    addTearDown(watcher.dispose);

    final sub = watcher.stream.listen((_) {});
    await sub.cancel();

    final nhan = watcher.stream.first;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    expect(await nhan, AppLifecycleState.inactive,
        reason: 'NotificationScanner.start() huỷ subscription cũ rồi nghe lại. '
            'Stream một-người-nghe ném ở lần nghe thứ hai, và nó nổ ngay trên '
            'đường đăng nhập.');
  });

  test('dispose() gỡ observer nên không phát nữa', () async {
    final watcher = AppLifecycleWatcher();
    final daNhan = <AppLifecycleState>[];
    watcher.stream.listen(daNhan.add);

    await watcher.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);

    expect(daNhan, isEmpty,
        reason: 'Observer còn sót lại trong binding sau dispose() là rò bộ '
            'nhớ, và mỗi lần dựng lại phụ thuộc thêm một nguồn kích hoạt nữa.');
  });

  test('dispose() hai lần không ném', () async {
    final watcher = AppLifecycleWatcher();

    await watcher.dispose();

    await expectLater(watcher.dispose(), completes,
        reason: 'Đóng hai lần là chuyện thường ở luồng đăng xuất rồi thoát '
            'app; ném ở đó là chặn đúng đường thoát.');
  });
}
