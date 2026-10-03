# Quy tắc R8 riêng của FlowMoney — Flutter Gradle plugin tự nạp tệp này cho bản release khi nó tồn tại
# (FlutterPlugin.kt), không cần khai trong build.gradle.kts.

# google_mlkit_text_recognition (đọc chữ biên lai): plugin tham chiếu lớp tuỳ chọn của bốn hệ chữ mà nó chỉ khai
# compileOnly. App chỉ dùng chữ Latin (TextRecognitionScript.latin), nên bốn nhánh ấy không bao giờ chạy. Thiếu bốn
# dòng dưới thì R8 dừng ở "Missing class com.google.mlkit.vision.text.chinese…" và bản release không dựng được
# (đo 2026-10-03). Canh bởi test/core/ocr/ban_release_r8_mlkit_test.dart.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
