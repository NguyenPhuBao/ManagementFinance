/// Chia sẻ biên lai — phần Dart của hàng chờ (spec `2026-10-02-chia-se-bien-lai-design.md`).
library;

import 'dart:io';

import 'package:flowmoney/core/notification/nhap_bien_lai.dart';
import 'package:flowmoney/core/ocr/doc_chu_anh.dart';
import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bộ đọc chữ giả: trả các dòng đã dựng sẵn theo TÊN TỆP ảnh.
class _DocGia implements DocChuAnh {
  _DocGia(this.theoTep, {this.nem = false});
  final Map<String, List<DongOcr>> theoTep;
  final bool nem;
  final daDoc = <String>[];

  @override
  Future<List<DongOcr>> doc(String duongDan) async {
    if (nem) throw StateError('bộ đọc hỏng /data/user/0/bien_lai/bi-mat.jpg');
    daDoc.add(duongDan);
    return theoTep[duongDan.split(RegExp(r'[\\/]')).last] ?? const [];
  }
}

DongOcr _d(String chu, double tren) => DongOcr(chu, trai: 0, tren: tren, phai: 100, duoi: tren + 10);

void main() {
  group('thuMauBienLai — chế độ thu mẫu, chỉ bản debug', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('bienlai_thu'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('⭐ in tên gói và HÌNH DẠNG ĐÃ CHE từng hàng — không chữ số thật, không tên riêng; KHÔNG xoá hàng chờ', () async {
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync('{"tep":"abcd.jpg","goi":"com.mbmobile","luc":1}\n');
      final ra = <String>[];
      final doc = _DocGia({
        'abcd.jpg': [_d('Số tiền 150.000 VND', 0), _d('Người nhận TRAN VAN B', 20)],
      });
      await thuMauBienLai(thuMuc: () async => dir, docChu: doc, inRa: ra.add);
      final tat = ra.join('\n');
      expect(doc.daDoc.single, endsWith('$kThuMucBienLai/abcd.jpg'));
      expect(tat, contains('com.mbmobile'));
      expect(tat, contains('Số tiền 999.999 VND'));
      expect(tat, isNot(contains('150')), reason: '§13.6: con số thật không bao giờ ra log');
      expect(tat, isNot(contains('TRAN')));
      expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isTrue, reason: 'thu mẫu chỉ ĐỌC — nhập là việc khác');
    });

    test('không có hàng chờ → không in gì, không gọi bộ đọc', () async {
      final ra = <String>[];
      final doc = _DocGia({});
      await thuMauBienLai(thuMuc: () async => dir, docChu: doc, inRa: ra.add);
      expect(ra, isEmpty);
      expect(doc.daDoc, isEmpty);
    });

    test('bộ đọc ném → MỘT dòng báo hỏng chỉ mang kiểu lỗi (thông báo lỗi có thể chứa đường dẫn), không ném ra ngoài',
        () async {
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync('{"tep":"abcd.jpg","goi":"","luc":1}\n');
      final ra = <String>[];
      await thuMauBienLai(thuMuc: () async => dir, docChu: _DocGia({}, nem: true), inRa: ra.add);
      expect(ra.single, contains('hỏng'));
      expect(ra.single, isNot(contains('bi-mat')));
    });
  });

  group('docDongBienLai', () {
    test('dòng đúng → tep, goi, luc', () {
      final r = docDongBienLai('{"tep":"a1b2.jpg","goi":"com.mbmobile","luc":1790940000000}');
      expect(r, isNotNull);
      expect(r!.tep, 'a1b2.jpg');
      expect(r.goi, 'com.mbmobile');
      expect(r.luc, DateTime.fromMillisecondsSinceEpoch(1790940000000));
    });

    test('goi rỗng vẫn nhận (không lấy được app gửi)', () {
      expect(docDongBienLai('{"tep":"abcd.png","goi":"","luc":1}')!.goi, '');
    });

    test('tên tệp Kotlin đặt (UUID + đuôi) hợp lệ', () {
      expect(tenTepBienLaiHopLe('3f2b8c1e-7a4d-4e0b-9c2a-1d5e6f7a8b9c.jpg'), isTrue);
      expect(tenTepBienLaiHopLe('0f3a-9c.jpeg'), isTrue);
    });

    test('⭐ tên tệp có dấu gạch chéo / .. bị từ chối — tên tệp đi vào deeplink rồi thành đường dẫn', () {
      expect(docDongBienLai('{"tep":"../x.jpg","goi":"","luc":1}'), isNull);
      expect(docDongBienLai('{"tep":"a/b.jpg","goi":"","luc":1}'), isNull);
      expect(docDongBienLai(r'{"tep":"a\\b.jpg","goi":"","luc":1}'), isNull);
      expect(tenTepBienLaiHopLe('x'), isFalse);
      expect(tenTepBienLaiHopLe('abcd.jpg.exe.toolongext'), isFalse);
    });

    test('JSON hỏng, thiếu khoá, sai kiểu → null, không ném', () {
      expect(docDongBienLai('không phải json'), isNull);
      expect(docDongBienLai('{"tep":"abcd.jpg"}'), isNull);
      expect(docDongBienLai('{"tep":"abcd.jpg","goi":1,"luc":1}'), isNull);
      expect(docDongBienLai('[1,2]'), isNull);
    });
  });
}
