/// C4 — kênh `flowmoney/micro` (`MainActivity.kt`): quyền micro đã bị CHẶN hẳn chưa, và mở trang thông tin ứng dụng. Mọi
/// lỗi thành "không biết" — trên nền tảng không có kênh (web, test) thì `MissingPluginException` là bình thường.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String kKenhMicro = 'flowmoney/micro';

abstract class KenhMicro {
  /// Gọi SAU một lần xin quyền bị từ chối: `true` = người dùng đã chặn hẳn (hộp xin quyền không hiện nữa).
  Future<bool> biChan();

  /// Mở trang thông tin ứng dụng (nơi bật lại quyền Micro).
  Future<void> moCaiDat();
}

class KenhMicroAndroid implements KenhMicro {
  const KenhMicroAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhMicro);

  @override
  Future<bool> biChan() async {
    try {
      return await _kenh.invokeMethod<bool>('biChan') ?? false;
    } catch (e) {
      debugPrint('[GiongNoi][Kenh] biChan lỗi: $e');
      return false;
    }
  }

  @override
  Future<void> moCaiDat() async {
    try {
      await _kenh.invokeMethod<void>('moCaiDat');
    } catch (e) {
      debugPrint('[GiongNoi][Kenh] moCaiDat lỗi: $e');
    }
  }
}
