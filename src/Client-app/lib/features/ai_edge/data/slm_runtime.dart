// lib/features/ai_edge/data/slm_runtime.dart
/// Tệp **DUY NHẤT** của dự án được import `flutter_gemma` — test quét thứ 16
/// canh (cùng khuôn `realtime_socket.dart`).
///
/// Mọi chỗ khác nhận [SlmRuntime], một giao diện thuần, nên test dựng được bản
/// giả mà không cần máy arm64 — và `flutter test` chạy trên x86_64 của máy
/// phát triển.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import '../domain/canary_cong_cu.dart';
import '../domain/canary_gpu.dart';
import '../domain/cong_cu.dart';
import 'phien_cong_cu.dart';

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

  /// Mở một PHIÊN hội thoại có tool (chặng 4b). [heThong] đi bằng system
  /// instruction native của LiteRT-LM; [cauHoi] là tin người dùng đã xếp vào
  /// phiên. Ném `StateError` khi mô hình chưa nạp — người gọi bắt và rơi về
  /// câu "không chạy được" (L4). Ném `BacCongCuDaTat` khi máy này từng sập
  /// native ở phiên có tool (canary 1b) — người gọi rơi về bậc 1 (L1).
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  });

  /// Dừng lượt sinh đang chạy (engine native thôi giải mã). Không có lượt nào
  /// đang chạy thì im lặng.
  Future<void> huy();

  Future<void> dong();
}

class SlmRuntimeThat implements SlmRuntime {
  /// Dấu canary GPU — `null` chỉ trong test; đường thật luôn có (DI).
  final CanaryGpu? canary;

  /// Dấu canary của phiên có tool (bước 1b) — `null` chỉ trong test.
  final CanaryCongCu? canaryCongCu;

  SlmRuntimeThat({this.canary, this.canaryCongCu});

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
    // Gói tự lùi về backend khác khi một backend ném lỗi — nhưng ⚠️ trên
    // Mali (Dimensity 1100, đo 2026-09-22) delegate OpenCL **sập native**, thứ
    // không ném gì cả; canary là cách duy nhất biết được điều ấy ở lần sau.
    final dungCpu = await canary?.nenDungCpu() ?? false;
    final dongHo = Stopwatch()..start();
    await canary?.batDauThu();
    try {
      _model = await FlutterGemma.getActiveModel(
        // ⚠️ Đây là trần cho **tổng** input + output, và nó là hằng của
        // CLIENT chứ không phải giới hạn của Gemma 4 E2B.
        //
        // 1024 đủ cho tới chặng 4a, rồi vỡ ngay lượt đo đầu: gói số mang thêm
        // danh sách có tên nên prompt hỏi đáp lên 2.276 ký tự = **1.084**
        // token, và gói ném `INVALID_ARGUMENT: Input token ids are too long`
        // — lỗi **cứng**, câu trả lời rỗng, không phải chỉ chậm đi. Cắt bớt
        // dữ liệu để vừa trần cũ là cắt đúng thứ lát 4a thêm vào, nên trần
        // được nới thay vì gói bị xén.
        maxTokens: 2048,
        preferredBackend: dungCpu ? PreferredBackend.cpu : PreferredBackend.gpu,
      );
    } finally {
      // Exception thường cũng dọn dấu: chỉ crash native (không chạy tới đây)
      // mới để dấu lại.
      await canary?.thuXong();
    }
    debugPrint('[SLM] nạp mô hình xong sau ${dongHo.elapsedMilliseconds} ms '
        '(${dungCpu ? 'CPU — GPU máy này từng sập' : 'GPU'})');
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
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    final m = _model;
    if (m == null) throw StateError('Mô hình chưa nạp');

    // Canary 1b (bẫy 4.33): máy này từng sập native ở phiên có tool — và lần
    // thoát ấy được Android xác nhận là sập, không phải bị giết — thì không mở
    // phiên nữa. Vòng lặp nhận lỗi này và đi bậc 1, im lặng.
    if (await canaryCongCu?.daTat() ?? false) throw const BacCongCuDaTat();

    final tools = [
      for (final k in congCu)
        Tool(name: k.ten, description: k.moTa, parameters: k.thamSo),
    ];
    // Đo cho bẫy 4.29: khai báo tool do runtime native dựng từ tools_json cũng
    // chiếm ngữ cảnh, và trần maxTokens là trần TỔNG. Chuỗi này cùng nội dung
    // với thứ gói gửi xuống SDK (`SdkResponseParser.serializeToolsForSdk`).
    final doDaiToolsJson = jsonEncode([
      for (final k in congCu)
        {
          'type': 'function',
          'function': {
            'name': k.ten,
            'description': k.moTa,
            'parameters': k.thamSo,
          },
        },
    ]).length;

    final dongHo = Stopwatch()..start();
    // Gemma 4 trên LiteRT-LM: tools đi bằng tools_json lúc tạo hội thoại; prompt
    // tool phía Dart bị gói bỏ qua, nên ToolChoice chỉ có nghĩa với `none`.
    final chat = await m.createChat(
      temperature: 0.2,
      tools: tools,
      supportsFunctionCalls: true,
      toolChoice: ToolChoice.auto,
      systemInstruction: heThong,
    );
    await chat.addQueryChunk(Message.text(text: cauHoi, isUser: true));
    debugPrint('[SLM][tool] mở phiên sau ${dongHo.elapsedMilliseconds} ms: '
        '${congCu.length} tool, tools_json $doDaiToolsJson ký tự, '
        'hệ thống ${heThong.length} ký tự, câu hỏi ${cauHoi.length} ký tự');
    return _PhienThat(chat, canaryCongCu);
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

/// Bản thật của [PhienCongCu] — bọc `InferenceChat` của gói. Mỗi câu hỏi một
/// phiên, cùng lý lẽ với `sinh`/`sinhDan`: không để câu trước ảnh hưởng câu sau.
class _PhienThat implements PhienCongCu {
  _PhienThat(this._chat, this._canary);
  final InferenceChat _chat;
  final CanaryCongCu? _canary;

  /// Mỗi lượt đi qua canary 1b: dấu có mặt từ trước khi engine giải mã tới sự
  /// kiện đầu tiên — khoảng mà bản engine cũ sập (bẫy 4.33).
  @override
  Stream<SuKienLuot> sinhLuot() => quaCanary(_sinhLuot, _canary);

  Stream<SuKienLuot> _sinhLuot() async* {
    final dongHo = Stopwatch()..start();
    var tokenDau = -1;
    var soKyTu = 0;
    var soLoiGoi = 0;
    try {
      await for (final r in _chat.generateChatResponseAsync()) {
        // `ModelResponse` là sealed: thêm subtype là lỗi biên dịch ở đây, không
        // phải một sự kiện rơi im lặng.
        switch (r) {
          case TextResponse(:final token):
            if (tokenDau < 0) tokenDau = dongHo.elapsedMilliseconds;
            soKyTu += token.length;
            yield Chu(token);
          case FunctionCallResponse(:final name, :final args):
            soLoiGoi++;
            yield GoiCongCu(name, args);
          case ParallelFunctionCallResponse(:final calls):
            for (final c in calls) {
              soLoiGoi++;
              yield GoiCongCu(c.name, c.args);
            }
          case ThinkingResponse():
            // Gemma 4 không bật thinking; nếu gói có phát thì không phải chữ
            // cho người đọc.
            break;
        }
      }
    } finally {
      debugPrint('[SLM][tool] lượt sinh xong sau ${dongHo.elapsedMilliseconds} ms '
          '(token đầu $tokenDau ms; $soKyTu ký tự; $soLoiGoi lời gọi)');
    }
  }

  @override
  Future<void> traKetQua(String ten, Map<String, dynamic> json) =>
      _chat.addQueryChunk(Message.toolResponse(toolName: ten, response: json));

  @override
  Future<void> huy() async {
    try {
      await _chat.stopGeneration();
    } catch (e) {
      debugPrint('[SLM][tool] huỷ lượt sinh hỏng: $e');
    }
  }

  @override
  Future<void> dong() async {
    try {
      await _chat.close();
    } catch (e) {
      debugPrint('[SLM][tool] đóng phiên hỏng: $e');
    }
  }
}
