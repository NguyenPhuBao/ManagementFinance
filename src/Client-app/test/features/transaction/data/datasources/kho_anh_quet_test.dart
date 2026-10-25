/// A5 mục 5.5 — kho ảnh QUÉT (`filesDir/anh_quet/`): mỗi lúc một ảnh, danh sách món nằm cạnh ảnh, không hàm nào ném.
library;

import 'dart:io';

import 'package:flowmoney/features/transaction/data/datasources/kho_anh_quet.dart';
import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory goc;
  late KhoAnhQuet kho;

  setUp(() {
    goc = Directory.systemTemp.createTempSync('aq');
    kho = KhoAnhQuet(thuMuc: () async => goc);
  });
  tearDown(() => goc.deleteSync(recursive: true));

  File anhNguon(String ten) => File('${goc.path}/$ten')..writeAsBytesSync([1, 2, 3]);

  test('⭐ luu chép ảnh vào anh_quet/, tên hợp lệ; lần sau XOÁ ảnh trước (mỗi lúc một ảnh)', () async {
    final a = await kho.luu(anhNguon('x.jpg').path);
    expect(a, isNotNull);
    expect(await kho.duongDan(a!), isNotNull);
    expect(File('${goc.path}/x.jpg').existsSync(), isTrue, reason: 'ảnh gốc (cache của image_picker) không bị đụng');
    final b = await kho.luu(anhNguon('y.PNG').path);
    expect(await kho.duongDan(a), isNull, reason: 'bắt đầu lần quét kế thì ảnh cũ bị xoá (spec 5.5)');
    expect(b!.endsWith('.png'), isTrue);
  });

  test('luuMon / docMon; xoa gỡ cả .mon.json', () async {
    final a = (await kho.luu(anhNguon('x.jpg').path))!;
    await kho.luuMon(a, const [MonHang(id: 0, ten: 'OMO', soTien: 120000)]);
    expect((await kho.docMon(a)).single.ten, 'OMO');
    await kho.xoa(a);
    expect(await kho.duongDan(a), isNull);
    expect(await kho.docMon(a), isEmpty);
    expect(File('${goc.path}/$kThuMucAnhQuet/$a.mon.json').existsSync(), isFalse);
  });

  test('.mon.json: số âm (dòng giảm giá) giữ dấu; phần tử sai kiểu chỉ làm hỏng chính nó', () async {
    final a = (await kho.luu(anhNguon('x.jpg').path))!;
    await kho.luuMon(a, const [MonHang(id: 3, ten: 'KM', soTien: -5000), MonHang(id: 4, ten: 'OMO', soTien: 120000)]);
    expect([for (final m in await kho.docMon(a)) '${m.id}|${m.ten}|${m.soTien}'], ['3|KM|-5000.0', '4|OMO|120000.0'],
        reason: 'ghi rồi đọc lại phải ra đúng id / tên / số tiền, kể cả số âm');
    File('${goc.path}/$kThuMucAnhQuet/$a.mon.json')
        .writeAsStringSync('[{"id":"x"},42,{"id":1,"ten":"A","soTien":10000}]');
    expect([for (final m in await kho.docMon(a)) m.ten], ['A'],
        reason: 'id sai kiểu và phần tử không phải Map bị bỏ; soTien kiểu int vẫn đọc được (num → double)');
  });

  test('.mon.json hỏng → không món; tên tệp hỏng → không ghép đường dẫn, không ném', () async {
    final a = (await kho.luu(anhNguon('x.jpg').path))!;
    File('${goc.path}/$kThuMucAnhQuet/$a.mon.json').writeAsStringSync('{rác');
    expect(await kho.docMon(a), isEmpty);
    expect(await kho.duongDan('../../etc/passwd'), isNull);
    await kho.xoa('../x');
    await kho.xoa(null);
  });

  test('ảnh nguồn không tồn tại → null, không ném; xoaHet xoá thư mục', () async {
    expect(await kho.luu('${goc.path}/khong_co.jpg'), isNull);
    await kho.luu(anhNguon('x.jpg').path);
    await kho.xoaHet();
    expect(Directory('${goc.path}/$kThuMucAnhQuet').existsSync(), isFalse);
  });
}
