/// A5 — nghiệm thu OnePlus 2026-10-08: `files/anh_quet/` được xoá đúng sau khi lưu, nhưng `image_picker` để lại BẢN SAO
/// ảnh hoá đơn trong `cache/` của app (45 thư mục `cache/<uuid>/<tên>.jpg` + `cache/scaled_<tên>.jpg`, 13 MB sau ~20 lần
/// quét) — trái lời hứa "ảnh xoá khi Lưu / Bỏ qua".
library;

import 'dart:io';

import 'package:flowmoney/core/ocr/tep_tam_chon_anh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory goc;
  setUp(() => goc = Directory.systemTemp.createTempSync('tam'));
  tearDown(() => goc.deleteSync(recursive: true));

  File tao(String duong) => File('${goc.path}/$duong')
    ..createSync(recursive: true)
    ..writeAsBytesSync([1]);

  test('⭐ ảnh thu nhỏ trong cache → xoá nó VÀ bản chép gốc trong cache/<uuid>/, gỡ thư mục rỗng', () {
    final thuNho = tao('cache/scaled_2531.jpg');
    final banGoc = tao('cache/08620382-9226/2531.jpg');
    final khac = tao('cache/84d223bd-f6b1/2536.jpg');
    xoaTepTamChonAnh(thuNho.path);
    expect(thuNho.existsSync(), isFalse);
    expect(banGoc.existsSync(), isFalse);
    expect(Directory('${goc.path}/cache/08620382-9226').existsSync(), isFalse);
    expect(khac.existsSync(), isTrue, reason: 'ảnh của lần quét khác không đụng');
  });

  test('ảnh không thu nhỏ (cache/<tên>) → xoá nó và bản cùng tên trong thư mục con', () {
    final anh = tao('cache/2540.jpg');
    final banGoc = tao('cache/abc/2540.jpg');
    xoaTepTamChonAnh(anh.path);
    expect(anh.existsSync(), isFalse);
    expect(banGoc.existsSync(), isFalse);
  });

  test('thư mục con còn tệp khác → chỉ xoá tệp, giữ thư mục', () {
    final thuNho = tao('cache/scaled_1.jpg');
    tao('cache/abc/1.jpg');
    final conLai = tao('cache/abc/ghi_chu.txt');
    xoaTepTamChonAnh(thuNho.path);
    expect(conLai.existsSync(), isTrue);
  });

  test('⭐ tệp KHÔNG nằm thẳng trong thư mục "cache" → không xoá gì (không bao giờ đụng ảnh thư viện của người dùng)', () {
    final anh = tao('DCIM/Camera/scaled_7.jpg');
    final banGoc = tao('DCIM/Camera/x/7.jpg');
    xoaTepTamChonAnh(anh.path);
    expect(anh.existsSync(), isTrue);
    expect(banGoc.existsSync(), isTrue);
  });

  test('tệp không tồn tại → không ném', () {
    expect(() => xoaTepTamChonAnh('${goc.path}/cache/scaled_khong_co.jpg'), returnsNormally);
  });
}
