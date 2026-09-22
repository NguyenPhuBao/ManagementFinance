// test/features/ai_edge/data/slm_cache_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/slm_cache.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('slmcache'));
  tearDown(() => tmp.deleteSync(recursive: true));

  SlmCache dung() => SlmCache(thuMuc: () async => tmp);

  test('ghi rồi đọc lại trong cùng phiên', () async {
    final c = dung();
    await c.nap();
    await c.ghi('van1', 'Câu một');
    expect(c.doc('van1'), 'Câu một');
  });

  test('dấu vân lạ trả null', () async {
    final c = dung();
    await c.nap();
    expect(c.doc('chua-co'), isNull);
  });

  test('sống qua phiên — bản mới đọc được tệp bản cũ ghi', () async {
    final a = dung();
    await a.nap();
    await a.ghi('van1', 'Câu một');

    final b = dung();
    await b.nap();
    expect(b.doc('van1'), 'Câu một',
        reason: 'Cache chỉ đáng giá khi sống qua lần mở app sau: stream phát '
            'lại sau MỖI chu kỳ đồng bộ, và gọi lại mô hình cho một gói số '
            'không đổi là 2,3 giây mỗi lần.');
  });

  test('⚠️ quá trần thì bỏ mục CŨ NHẤT, giữ đủ trần', () async {
    final c = dung();
    await c.nap();
    for (var i = 0; i < kTranCache + 10; i++) {
      await c.ghi('van$i', 'Câu $i');
    }
    expect(c.doc('van0'), isNull, reason: 'mục cũ nhất phải bị bỏ');
    expect(c.doc('van${kTranCache + 9}'), 'Câu ${kTranCache + 9}');
  });

  test('⚠️ đọc lại một mục làm nó THÀNH MỚI, không bị bỏ ở lượt dọn sau',
      () async {
    // LRU chứ không FIFO: gói số của Trang chủ được đọc mỗi lần mở app, nên nó
    // phải sống sót dù được ghi từ lâu. FIFO thuần sẽ bỏ đúng mục dùng nhiều
    // nhất — và không gì báo, chỉ là mô hình bị gọi lại.
    final c = dung();
    await c.nap();
    await c.ghi('cu', 'Câu cũ');
    for (var i = 0; i < kTranCache - 1; i++) {
      await c.ghi('van$i', 'Câu $i');
    }
    c.doc('cu'); // chạm vào
    await c.ghi('moi', 'Câu mới'); // vượt trần → phải bỏ 'van0', không phải 'cu'
    expect(c.doc('cu'), 'Câu cũ');
    expect(c.doc('van0'), isNull);
  });

  test('tệp JSON hỏng thì nạp thành cache RỖNG, không ném', () async {
    File('${tmp.path}/slm_cache.json').writeAsStringSync('{khong-phai-json');
    final c = dung();
    await expectLater(c.nap(), completes);
    expect(c.doc('bat-ky'), isNull);
  });

  test('xoaHet dọn cả bộ nhớ lẫn tệp', () async {
    final c = dung();
    await c.nap();
    await c.ghi('van1', 'Câu một');
    await c.xoaHet();
    expect(c.doc('van1'), isNull);

    final b = dung();
    await b.nap();
    expect(b.doc('van1'), isNull);
  });
}
