/// C4 — lối Android phải chờ TIẾNG ĐẦU tới [kChoTiengDau] rồi mới áp luật im [kImDeDung]. Nghiệm thu Realme 2026-10-21:
/// `pauseFor` của `speech_to_text` 7.5.0 tính từ lúc BẮT ĐẦU nghe (`_lastSpeechEventAt = _listenStartedAt`) và chỉ đặt lại
/// khi có chữ, nên với `pauseFor` 2 s gói tự `stop()` sau ~1,7 s âm thanh — người dùng chưa kịp nói, Google trả
/// `NO_SPEECH_DETECTED`. Test chạy gói THẬT qua kênh giả; giờ của gói đi qua `clock` nên `fakeAsync` điều khiển được.
library;

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/transaction/data/datasources/nghe_android.dart';
import 'package:flowmoney/features/transaction/domain/do_im_lang.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kenh = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final may = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late int soLanStop;

  setUp(() {
    soLanStop = 0;
    may.setMockMethodCallHandler(kenh, (call) async {
      switch (call.method) {
        case 'initialize' || 'listen' || 'has_permission':
          return true;
        case 'stop':
          soLanStop++;
          return null;
      }
      return null;
    });
  });
  tearDown(() => may.setMockMethodCallHandler(kenh, null));

  void phat(String phuongThuc, Object? doiSo) => may.handlePlatformMessage(
        kenh.name,
        kenh.codec.encodeMethodCall(MethodCall(phuongThuc, doiSo)),
        (_) {},
      );

  /// Phía native báo một kết quả nhận dạng (chữ tạm).
  void phatChu(String chu) => phat(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': chu, 'confidence': 0.9},
          ],
          'resultType': 0,
        }),
      );

  /// Bắt đầu một lượt như trên máy: native nhận `listen` rồi báo trạng thái `listening`. Trả các chữ `onChu` nhận được.
  List<String> batDauNghe(FakeAsync fa) {
    final nhan = <String>[];
    final nghe = NgheAndroidThat(stt: SpeechToText.withMethodChannel());
    nghe.khoiTao();
    fa.flushMicrotasks();
    nghe.nghe(trenMay: false, onChu: (chu, _) => nhan.add(chu), onLoi: (_) {}, onDung: () {});
    fa.flushMicrotasks();
    phat('notifyStatus', SpeechToText.listeningStatus);
    fa.flushMicrotasks();
    return nhan;
  }

  test('⚠️ chưa có chữ: 3 giây vẫn nghe (bản cũ tự dừng ở 2 giây), tới giây 6 thì dừng', () {
    fakeAsync((fa) {
      batDauNghe(fa);
      fa.elapse(const Duration(seconds: 3));
      expect(soLanStop, 0,
          reason: 'người dùng cần thời gian mở miệng — Realme: gói dừng sau 1,7 s âm thanh, Google trả NO_SPEECH_DETECTED');
      fa.elapse(kChoTiengDau - const Duration(seconds: 3) + const Duration(milliseconds: 100));
      expect(soLanStop, 1, reason: 'chưa nói gì sau 6 giây thì dừng — cùng mốc với lối Gemma');
    });
  });

  test('có chữ tạm ở giây 1 → im 2 giây sau chữ thì dừng, không chờ tới giây 6', () {
    fakeAsync((fa) {
      batDauNghe(fa);
      fa.elapse(const Duration(seconds: 1));
      phatChu('ăn phở');
      fa.flushMicrotasks();
      fa.elapse(kImDeDung - const Duration(milliseconds: 100));
      expect(soLanStop, 0);
      fa.elapse(const Duration(milliseconds: 300));
      expect(soLanStop, 1, reason: 'đã có chữ thì áp luật im 2 giây — thiếu changePauseFor là chờ tới giây 7');
    });
  });

  test('chữ tới SAU trạng thái notListening → không ném, chữ vẫn tới người nghe', () {
    fakeAsync((fa) {
      final nhan = batDauNghe(fa);
      phat('notifyStatus', SpeechToText.notListeningStatus);
      fa.flushMicrotasks();
      phatChu('ăn phở 45 nghìn');
      fa.flushMicrotasks();
      expect(nhan, ['ăn phở 45 nghìn'],
          reason: 'changePauseFor ném ListenNotStartedException khi gói không còn nghe — không bọc là mất chữ của lượt');
    });
  });

  test('chữ tạm rỗng không tính là đã nói', () {
    fakeAsync((fa) {
      batDauNghe(fa);
      fa.elapse(const Duration(seconds: 1));
      phatChu('  ');
      fa.flushMicrotasks();
      fa.elapse(const Duration(seconds: 3));
      expect(soLanStop, 0, reason: 'kết quả rỗng không phải tiếng nói — chưa được rút về 2 giây');
    });
  });
}
