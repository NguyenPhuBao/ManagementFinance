import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `SyncEngine.start()` là hành động **mở phiên**: nó xoá giãn cách lùi
/// (`_resetBackoff`), huỷ rồi dựng lại bộ nghe kết nối và timer định kỳ, và chạy
/// ngay một `syncNow()`. Gọi nó lần thứ hai không phải "vô hại": mỗi lần là một
/// chu kỳ đồng bộ thừa và một lần backoff bị xoá — nghĩa là một bản ghi kẹt lỗi
/// vĩnh viễn được gửi lại ngay thay vì chờ hết giãn cách.
///
/// Vì thế chỉ **một** chỗ được gọi nó: `AuthBloc`, đúng lúc phiên đăng nhập mở
/// (`_onAuthCheckRequested`, `_onLoginRequested`) và đối xứng với `stop()` ở
/// `_dungMoiThuCuaPhien`. `home_page.dart` từng gọi thêm một lần **ngay trong
/// `build()`** — tức mỗi lần Trang chủ dựng lại (mỗi `AuthSuccess` re-emit, mỗi
/// lần quay về tab) là một lời gọi nữa. Chú thích ở `auth_bloc.dart` đã cảnh báo
/// đúng chỗ ấy từ trước mà bản trùng vẫn nằm đó tới 2026-09-12: không gì đỏ khi
/// người ta gọi start() thừa. Test này là cái đỏ ấy.
void main() {
  test('chỉ AuthBloc được gọi SyncEngine.start(idaccount:) trong lib/', () {
    // `sl<SyncEngine>().start(idaccount:` hay `engine.start(idaccount:` — bắt
    // theo tham số đặt tên, thứ chỉ SyncEngine và RealtimeChannel dùng
    // (NotificationScanner/BadgeUpdater dùng tham số vị trí). RealtimeChannel
    // cũng chỉ được khởi động ở AuthBloc, nên gom một luật là đúng ý.
    final goiStart = RegExp(r'\.start\(\s*idaccount\s*:');
    const choDuocPhep = 'lib/features/auth/presentation/bloc/auth_bloc.dart';

    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final duongDan = f.path.replaceAll(r'\', '/');
      if (duongDan.endsWith(choDuocPhep)) continue;
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        final d = dongs[i].trimLeft();
        // Ví dụ trong chú thích tài liệu (`/// sl<SyncEngine>().start(...)`) không
        // phải lời gọi.
        if (d.startsWith('//')) continue;
        if (goiStart.hasMatch(d)) viPham.add('$duongDan:${i + 1}');
      }
    }

    expect(viPham, isEmpty,
        reason: 'SyncEngine/RealtimeChannel chỉ mở ở AuthBloc, đối xứng với '
            'stop() ở _dungMoiThuCuaPhien. Gọi ở widget — nhất là trong '
            'build() — là mỗi lần dựng lại thêm một chu kỳ đồng bộ và xoá '
            'giãn cách lùi của bản ghi đang kẹt lỗi.');
  });
}
