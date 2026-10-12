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
import 'luot_nghe.dart';

abstract class NgheAndroid {
  /// `false` = máy không có dịch vụ nhận dạng / thiếu quyền. Thành công thì giữ; thất bại thì lần sau thử lại.
  Future<bool> khoiTao();

  /// Nghe tiếng Việt. Hợp đồng: chữ tạm qua [onChu] (`xong` = false), rồi **ĐÚNG MỘT** kết thúc — chữ cuối
  /// `onChu(_, true)` | [onLoi] (mã `error_*`) | [onDung] (lượt kết thúc không chữ, không lỗi). Lỗi thắng `done`
  /// (xem [LuotNghe]).
  ///
  /// ⚠️ Có thể NÉM (`SpeechToTextNotInitializedException`, `ListenFailedException`) — người gọi bọc try/catch (P11).
  /// ⚠️ Nếu bộ nhận dạng native bận và không bắt đầu, gói không ném và không callback (`listen` không trả cờ; `isListening`
  /// đổi bất đồng bộ nên không tin được ngay) — chưa có tín hiệu tin cậy; người gọi nên có hạn chót riêng.
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
  LuotNghe? _luot;

  @override
  Future<bool> khoiTao() async {
    if (_daKhoiTao) return true;
    try {
      _daKhoiTao = await _stt.initialize(
        onError: (SpeechRecognitionError e) => _luot?.loi(e.errorMsg),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus) _luot?.done();
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
    _luot?.huy();
    final luot = _luot = LuotNghe(onChu: onChu, onLoi: onLoi, onDung: onDung);
    try {
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
        onResult: (SpeechRecognitionResult r) => luot.chu(r.recognizedWords, r.finalResult),
      );
    } catch (_) {
      // `listen` ném thì lượt này không bao giờ bắt đầu — đừng để LuotNghe sống và hẹn `onDung` ma.
      luot.huy();
      if (identical(_luot, luot)) _luot = null;
      rethrow;
    }
  }

  @override
  Future<void> dung() => _stt.stop();

  @override
  Future<void> huy() {
    // Gỡ người nghe TRƯỚC: `cancel` phát `doneNoResult` trước khi trả về.
    _luot?.huy();
    _luot = null;
    return _stt.cancel();
  }
}
