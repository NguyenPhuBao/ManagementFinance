/// C4 — ghi âm WAV 16 kHz mono cho lối Gemma, qua gói `record`. Tệp **duy nhất** import gói ấy (test quét 26).
library;

import 'dart:async';

import 'package:record/record.dart';

import '../../domain/do_im_lang.dart';

abstract class GhiAm {
  /// Có quyền micro chưa — XIN nếu chưa (hộp thoại hệ thống).
  Future<bool> coQuyen();

  /// Ghi vào [duongTep]; [onBienDo] mỗi [kNhipBienDo] (dBFS).
  Future<void> batDau(String duongTep, {required void Function(double dbfs) onBienDo});

  /// Dừng; trả đường dẫn tệp (hoặc `null`).
  Future<String?> dung();

  /// Dừng và bỏ tệp.
  Future<void> huy();
}

class GhiAmThat implements GhiAm {
  AudioRecorder? _rec;
  StreamSubscription<Amplitude>? _sub;

  AudioRecorder get _r => _rec ??= AudioRecorder();

  @override
  Future<bool> coQuyen() async {
    try {
      return await _r.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> batDau(String duongTep, {required void Function(double dbfs) onBienDo}) async {
    await _r.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: duongTep);
    await _sub?.cancel();
    _sub = _r.onAmplitudeChanged(kNhipBienDo).listen((a) => onBienDo(a.current));
  }

  @override
  Future<String?> dung() async {
    await _sub?.cancel();
    _sub = null;
    return _r.stop();
  }

  @override
  Future<void> huy() async {
    await _sub?.cancel();
    _sub = null;
    await _r.cancel();
  }
}
