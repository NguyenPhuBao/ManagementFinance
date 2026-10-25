// lib/features/ai_edge/data/datasources/kenh_giu_mo_hinh.dart
/// G100 (đường gỡ task, 2026-10-21) — kênh `flowmoney/giu_mo_hinh` (`MainActivity.kt`): báo tiến trình có đang giữ một
/// bản mô hình Gemma không. Activity bị huỷ thật (gỡ task khỏi Đa nhiệm, đường rơi về `SystemNavigator.pop()`) mà cờ
/// bật thì Kotlin giết tiến trình: engine dựng lại trong tiến trình còn sống (dịch vụ D1 giữ nó) sẽ nạp THÊM một bản,
/// và bản cũ không ai giải phóng được — `flutter_gemma_litertlm` chỉ cất địa chỉ engine native trong đối tượng Dart.
///
/// Mọi lỗi bị nuốt: lời báo đi trên đường nạp mô hình (`BoNapMoHinh`), và trên nền tảng không có kênh (web, test) thì
/// `MissingPluginException` là bình thường.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String kKenhGiuMoHinh = 'flowmoney/giu_mo_hinh';

class KenhGiuMoHinh {
  const KenhGiuMoHinh();

  static const MethodChannel _kenh = MethodChannel(kKenhGiuMoHinh);

  Future<void> dat(bool giu) async {
    try {
      await _kenh.invokeMethod<void>('datGiu', {'giu': giu});
    } catch (e) {
      debugPrint('[SLM][giu] báo native hỏng: $e');
    }
  }
}
