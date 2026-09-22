// lib/features/ai_edge/data/slm_runtime.dart
/// Tệp **DUY NHẤT** của dự án được import `flutter_gemma` — test quét thứ 16
/// canh (cùng khuôn `realtime_socket.dart`).
///
/// Mọi chỗ khác nhận [SlmRuntime], một giao diện thuần, nên test dựng được bản
/// giả mà không cần máy arm64 — và `flutter test` chạy trên x86_64 của máy
/// phát triển.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

/// Runtime mô hình. Ba trạng thái: chưa nạp, đang sẵn, đã đóng.
abstract class SlmRuntime {
  bool get dangSan;

  /// Nạp mô hình từ [duongTep]. Ném khi máy không chạy được — người gọi bắt và
  /// rơi về mẫu câu.
  Future<void> moHinhSan(String duongTep);

  Future<String> sinh(String prompt, {int tranToken});

  Future<void> dong();
}

class SlmRuntimeThat implements SlmRuntime {
  InferenceModel? _model;
  bool _daKhoiTao = false;

  @override
  bool get dangSan => _model != null;

  @override
  Future<void> moHinhSan(String duongTep) async {
    if (_model != null) return;

    // `initialize` đăng ký engine — gọi một lần trong đời tiến trình.
    if (!_daKhoiTao) {
      await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
      _daKhoiTao = true;
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(duongTep).install();

    // ⚠️ Máy không chạy được hỏng ở ĐÂY, không ở `install()` — P1 đo được:
    // `install()` xong trong 265 ms trên máy ảo x86_64 rồi `getActiveModel`
    // mới ném "require an arm64-v8a Android device (got android_x64)". Gói tự
    // nêu tên ABI, nên không cần tự đọc ABI ở tầng nào cả.
    //
    // GPU trước, CPU sau: P1 đo GPU nhanh gấp rưỡi và tốn 1,73 → 0,96 GB RAM.
    // Gói tự lùi về backend khác khi một backend hỏng, nhưng nêu rõ ý định thì
    // đọc mã ra được vì sao.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async {
    final m = _model;
    if (m == null) throw StateError('Mô hình chưa nạp');

    // Mỗi câu một phiên chat mới: khối Nhận xét không có hội thoại, và giữ
    // phiên cũ là để câu trước ảnh hưởng câu sau — thứ làm bộ kiểm số khó lần.
    final chat = await m.createChat(temperature: 0.2);
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final r = await chat.generateChatResponse();
    return (r is TextResponse ? r.token : r.toString()).trim();
  }

  @override
  Future<void> dong() async {
    try {
      await _model?.close();
    } catch (e) {
      debugPrint('[SLM] đóng mô hình hỏng: $e');
    }
    _model = null;
  }
}
