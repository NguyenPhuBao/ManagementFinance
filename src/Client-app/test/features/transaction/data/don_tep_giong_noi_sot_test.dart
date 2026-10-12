/// C4 — dọn WAV giọng nói sót (spec §2.4: không lưu âm thanh). Vòng dọn cũ trong DI là mã chết (mẫu `replaceAll` rỗng),
/// nên nó nay là hàm thuần có test trên thư mục tạm thật.
library;

import 'dart:io';

import 'package:flowmoney/features/transaction/data/nguon_giong_noi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory thuMuc;

  setUp(() => thuMuc = Directory.systemTemp.createTempSync('giong_noi_test'));
  tearDown(() {
    if (thuMuc.existsSync()) thuMuc.deleteSync(recursive: true);
  });

  File tao(String ten) => File('${thuMuc.path}/$ten')..writeAsStringSync('x');

  test('xoá giong_noi_*.wav, giữ tệp khác', () async {
    final a = tao('giong_noi_1.wav');
    final b = tao('giong_noi_2.wav');
    final khac = tao('khac.wav');
    final txt = tao('giong_noi_1.txt');
    await donTepGiongNoiSot(thuMuc);
    expect(a.existsSync(), isFalse, reason: 'tệp sót phải bị xoá — vòng cũ không bao giờ xoá gì');
    expect(b.existsSync(), isFalse);
    expect(khac.existsSync(), isTrue);
    expect(txt.existsSync(), isTrue);
  });

  test('tên tệp từ tepGiongNoiMoi khớp bộ dọn', () async {
    final f = File(tepGiongNoiMoi(thuMuc.path))..writeAsStringSync('x');
    await donTepGiongNoiSot(thuMuc);
    expect(f.existsSync(), isFalse, reason: 'một định nghĩa tiền tố/đuôi cho cả dựng tên lẫn dọn');
  });

  test('thư mục không tồn tại → không ném', () async {
    await donTepGiongNoiSot(Directory('${thuMuc.path}/khong_co'));
  });
}
