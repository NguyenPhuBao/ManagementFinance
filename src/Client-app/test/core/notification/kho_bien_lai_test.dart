/// `KhoBienLai` — thư mục ảnh biên lai. Ảnh mang số tài khoản và tên người: xoá sót là dữ liệu của người đăng nhập
/// trước nằm lại trên máy; xoá nhầm là mất biên lai người dùng vừa chia sẻ. Cả hai đều im lặng.
library;

import 'dart:io';

import 'package:flowmoney/core/notification/kho_bien_lai.dart';
import 'package:flowmoney/core/notification/nhap_bien_lai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late KhoBienLai kho;

  File anh(String ten) => File('${dir.path}/$kThuMucBienLai/$ten')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  List<String> conLai() => [
        for (final f in Directory('${dir.path}/$kThuMucBienLai').listSync()) f.uri.pathSegments.last,
      ]..sort();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kho_bien_lai');
    kho = KhoBienLai(thuMuc: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('duongDan: tệp còn → đường dẫn; tệp mất hoặc tên bẩn → null', () async {
    anh('aaaa.jpg');
    expect(await kho.duongDan('aaaa.jpg'), endsWith('aaaa.jpg'));
    expect(await kho.duongDan('bbbb.jpg'), isNull);
    File('${dir.path}/ngoai.jpg').writeAsStringSync('x');
    expect(await kho.duongDan('../ngoai.jpg'), isNull, reason: 'tên tệp đến từ deeplink — không ghép đường dẫn lạ');
  });

  test('xoa: xoá đúng tệp; null / tên bẩn / tệp không có → không ném, không xoá gì khác', () async {
    anh('aaaa.jpg');
    anh('bbbb.jpg');
    File('${dir.path}/ngoai.jpg').writeAsStringSync('x');
    await kho.xoa('aaaa.jpg');
    await kho.xoa(null);
    await kho.xoa('../ngoai.jpg');
    await kho.xoa('cccc.jpg');
    expect(conLai(), ['bbbb.jpg']);
    expect(File('${dir.path}/ngoai.jpg').existsSync(), isTrue);
  });

  test('⭐ donMoCoi: chỉ giữ ảnh còn được trỏ tới', () async {
    anh('aaaa.jpg');
    anh('bbbb.jpg');
    anh('cccc.png');
    expect(await kho.donMoCoi({'bbbb.jpg'}), 2);
    expect(conLai(), ['bbbb.jpg']);
  });

  test('donMoCoi khi chưa có thư mục → 0, không ném', () async {
    expect(await kho.donMoCoi(const {}), 0);
  });

  test('⭐ xoaHet: ảnh, hàng chờ và tệp .dang_nhap đều mất; tệp khác của app thì nguyên', () async {
    anh('aaaa.jpg');
    File('${dir.path}/$kTepBienLaiCho').writeAsStringSync('{}');
    File('${dir.path}/$kTepBienLaiCho.dang_nhap').writeAsStringSync('{}');
    File('${dir.path}/bien_dong_cho.jsonl').writeAsStringSync('{}');
    await kho.xoaHet();
    expect(Directory('${dir.path}/$kThuMucBienLai').existsSync(), isFalse);
    expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isFalse);
    expect(File('${dir.path}/$kTepBienLaiCho.dang_nhap').existsSync(), isFalse);
    expect(File('${dir.path}/bien_dong_cho.jsonl').existsSync(), isTrue, reason: 'hàng chờ của D1 không phải việc của kho này');
  });

  test('xoaHet khi chưa có gì → không ném', () async {
    await kho.xoaHet();
  });
}
