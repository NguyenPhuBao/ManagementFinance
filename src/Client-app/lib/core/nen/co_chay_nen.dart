import 'package:flutter/foundation.dart';

/// Nền tảng có tự chuyển tiền chạy nền (WorkManager Kotlin) — chỉ Android. iOS giữ lời nhắc "Mở app…" và câu "chỉ
/// trích khi mở app" vì không có gì thay thế (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 6).
bool get coChayNen => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
