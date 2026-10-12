/// C4 — bộ nhận giọng nói của Android qua `speech_to_text`. Tệp **duy nhất** import gói ấy (test quét 26).
///
/// ⚠️ `SpeechToText.initialize` chỉ nhận callback ở lần ĐẦU — lớp này đăng ký một lần với hàm chuyển tiếp sang người nghe
/// của lượt hiện tại. ⚠️ Chỉ coi lượt nghe xong ở trạng thái `done` (không `notListening`): `notListening` đến TRƯỚC
/// chữ cuối, chốt ở đó là lấy chữ tạm thay chữ cuối.
library;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/do_im_lang.dart';

abstract class NgheAndroid {
  /// `false` = máy không có dịch vụ nhận dạng / thiếu quyền. Thành công thì giữ; thất bại thì lần sau thử lại.
  Future<bool> khoiTao();

  /// Nghe tiếng Việt. Chữ tạm qua [onChu] (`xong` = false), chữ cuối một lần (`xong` = true); lỗi qua [onLoi] (mã
  /// `error_*`); [onDung] khi lượt kết thúc (sau chữ cuối hoặc lỗi).
  Future<void> nghe({
    required bool trenMay,
    required void Function(String chu, bool xong) onChu,
    required void Function(String ma) onLoi,
    required void Function() onDung,
  });

  Future<void> dung();
  Future<void> huy();
}

class NgheAndroidThat implements NgheAndroid {
  final SpeechToText _stt = SpeechToText();
  bool _daKhoiTao = false;
  void Function(String ma)? _onLoi;
  void Function()? _onDung;

  @override
  Future<bool> khoiTao() async {
    if (_daKhoiTao) return true;
    try {
      _daKhoiTao = await _stt.initialize(
        onError: (SpeechRecognitionError e) => _onLoi?.call(e.errorMsg),
        onStatus: (s) {
          if (s == 'done') _onDung?.call();
        },
      );
    } catch (e) {
      debugPrint('[GiongNoi][Android] khởi tạo lỗi: $e');
      _daKhoiTao = false;
    }
    return _daKhoiTao;
  }

  @override
  Future<void> nghe({
    required bool trenMay,
    required void Function(String chu, bool xong) onChu,
    required void Function(String ma) onLoi,
    required void Function() onDung,
  }) async {
    _onLoi = onLoi;
    _onDung = onDung;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenFor: kNgheToiDa,
        pauseFor: kImDeDung,
        onDevice: trenMay,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) => onChu(r.recognizedWords, r.finalResult),
    );
  }

  @override
  Future<void> dung() => _stt.stop();

  @override
  Future<void> huy() => _stt.cancel();
}
