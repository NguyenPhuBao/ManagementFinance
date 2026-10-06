/// Nạp font THẬT cho widget test đo bố cục (G2, 2026-10-06).
///
/// App dùng Inter qua `google_fonts`, tải lúc chạy — bộ test không tải được nên
/// mọi chữ rơi về **Ahem**, mỗi ký tự rộng đúng 1 em, tức gần gấp đôi chữ thật
/// (bẫy 4.4 `ANALYTICS_FEATURE.md`). Đo cỡ chữ hệ thống lớn bằng Ahem là báo tràn
/// ở mọi nơi; nên ở đây nạp **Roboto** có sẵn trong `assets/fonts/` dưới đúng các
/// tên họ mà `GoogleFonts.inter()` sinh ra (`Inter_regular`, `Inter_500` …).
///
/// ⚠️ Roboto hẹp hơn Inter vài phần trăm — phép đo hơi LẠC QUAN. Một chỗ vừa
/// khít ở đây có thể vẫn cắt trên máy; ca test nên chừa biên chứ không đo sát.
library;

import 'dart:io';

import 'package:flutter/services.dart';

bool _daNap = false;

Future<void> napFontThat() async {
  if (_daNap) return;
  final thuong = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
  final dam = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
  Future<void> nap(String ho, Uint8List byte) async {
    final l = FontLoader(ho)..addFont(Future.value(ByteData.sublistView(byte)));
    await l.load();
  }

  for (final ho in ['Inter_regular', 'Inter_500', 'Inter', 'Roboto']) {
    await nap(ho, thuong);
  }
  for (final ho in ['Inter_600', 'Inter_700', 'Inter_800', 'Inter_900']) {
    await nap(ho, dam);
  }
  _daNap = true;
}
