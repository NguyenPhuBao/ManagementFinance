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

  /// Sinh **dần**: phát từng token khi mô hình viết. Dùng cho màn Trợ lý AI
  /// (việc số 1, 2026-09-22) — người gọi gác theo câu (`gacTheoCau`) chứ
  /// không hiện thẳng token: bộ kiểm chỉ có nghĩa trên câu đầy đủ.
  Stream<String> sinhDan(String prompt, {int tranToken});

  /// Dừng lượt sinh đang chạy (engine native thôi giải mã). Không có lượt nào
  /// đang chạy thì im lặng.
  Future<void> huy();

  Future<void> dong();
}

class SlmRuntimeThat implements SlmRuntime {
  InferenceModel? _model;
  bool _daKhoiTao = false;

  /// Phiên chat của lượt `sinhDan` đang chạy — để `huy()` có chỗ để dừng.
  InferenceChat? _chatDangSinh;

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
    final dongHo = Stopwatch()..start();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );
    debugPrint('[SLM] nạp mô hình xong sau ${dongHo.elapsedMilliseconds} ms');
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async {
    final m = _model;
    if (m == null) throw StateError('Mô hình chưa nạp');

    // Mỗi câu một phiên chat mới: khối Nhận xét không có hội thoại, và giữ
    // phiên cũ là để câu trước ảnh hưởng câu sau — thứ làm bộ kiểm số khó lần.
    // Đồng hồ: chỗ DUY NHẤT đo được giá thật của một câu. Giữ lại sau P3 —
    // mọi phép đo sau này (máy khác, mô hình khác, bậc thang khác) đều cần
    // đúng con số này, và không có nó thì phải sửa mã mới đo lại được.
    final dongHo = Stopwatch()..start();
    final chat = await m.createChat(temperature: 0.2);
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final r = await chat.generateChatResponse();
    final cau = (r is TextResponse ? r.token : r.toString()).trim();
    debugPrint('[SLM] sinh câu xong sau ${dongHo.elapsedMilliseconds} ms '
        '(prompt ${prompt.length} ký tự → câu ${cau.length} ký tự)');
    return cau;
  }

  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 300}) async* {
    final m = _model;
    if (m == null) throw StateError('Mô hình chưa nạp');

    // Cùng khuôn `sinh`: mỗi câu một phiên chat mới, và đồng hồ là chỗ duy
    // nhất đo được giá thật. Thêm mốc **token đầu** — với streaming đó mới là
    // con số người dùng cảm nhận, không phải tổng thời gian.
    final dongHo = Stopwatch()..start();
    final chat = await m.createChat(temperature: 0.2);
    _chatDangSinh = chat;
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    var tokenDau = -1;
    var soKyTu = 0;
    try {
      // ⚠️ `stopGeneration()` chứ không `cancel()` subscription: gói ghi rõ
      // chỉ `stopGeneration` mới tới được engine native trên mọi engine;
      // huỷ subscription thì engine vẫn giải mã tiếp cho hết.
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is! TextResponse) continue;
        if (tokenDau < 0) tokenDau = dongHo.elapsedMilliseconds;
        soKyTu += r.token.length;
        yield r.token;
      }
    } finally {
      _chatDangSinh = null;
      debugPrint('[SLM] sinh dần xong sau ${dongHo.elapsedMilliseconds} ms '
          '(token đầu $tokenDau ms; prompt ${prompt.length} ký tự → '
          '$soKyTu ký tự)');
    }
  }

  @override
  Future<void> huy() async {
    final chat = _chatDangSinh;
    if (chat == null) return;
    try {
      await chat.stopGeneration();
      debugPrint('[SLM] đã huỷ lượt sinh giữa chừng');
    } catch (e) {
      debugPrint('[SLM] huỷ lượt sinh hỏng: $e');
    }
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
