// lib/features/ai_edge/data/nguon_ly_do_thoat.dart
/// Bản thật của [NguonLyDoThoat] — nói chuyện với `MainActivity` qua kênh
/// [kKenhLyDoThoat] (bước 1b, 2026-09-23).
///
/// Phía native trả **một** bản đồ: `phienBan` (`versionCode`) và `lanThoat` —
/// danh sách `{lyDo, luc}` lấy từ `ActivityManager.getHistoricalProcessExitReasons`
/// (Android 11+, API 30), hoặc `null` trên Android 10 trở xuống.
///
/// ⚠️ Mọi lỗi đều thành `null` — "không biết", chứ không ném: phép này chạy ở
/// đường khởi động app (`main.dart`), và trên nền tảng không có kênh này (web,
/// test) thì `MissingPluginException` là chuyện bình thường.
library;

import 'package:flutter/services.dart';

import '../domain/canary_cong_cu.dart';

const String kKenhLyDoThoat = 'flowmoney/ly_do_thoat';

class NguonLyDoThoatAndroid implements NguonLyDoThoat {
  const NguonLyDoThoatAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhLyDoThoat);

  Future<Map<Object?, Object?>?> _doc() async {
    try {
      return await _kenh.invokeMapMethod<Object?, Object?>('thongTin');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LanThoat>?> cacLanThoat() async {
    final ds = (await _doc())?['lanThoat'];
    if (ds is! List) return null;
    return [
      for (final e in ds)
        if (e is Map && e['lyDo'] is int && e['luc'] is int)
          LanThoat(
            lyDo: e['lyDo'] as int,
            luc: DateTime.fromMillisecondsSinceEpoch(e['luc'] as int),
          ),
    ];
  }

  @override
  Future<int?> phienBan() async {
    final pb = (await _doc())?['phienBan'];
    return pb is int ? pb : null;
  }
}
