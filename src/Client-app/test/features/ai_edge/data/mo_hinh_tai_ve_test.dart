// test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mohinh'));
  tearDown(() => tmp.deleteSync(recursive: true));

  MoHinhTaiVe dung({
    Future<void> Function(String url, File dich, void Function(double))? taiGia,
  }) =>
      MoHinhTaiVe(
        thuMuc: () async => tmp,
        taiTep: taiGia ??
            (url, dich, bao) async {
              bao(0.5);
              dich.writeAsBytesSync(List.filled(1024, 0));
              bao(1.0);
            },
      );

  test('chưa tải thì daCo() false', () async {
    expect(await dung().daCo(), isFalse);
  });

  test('tải xong thì daCo() true và tệp nằm đúng chỗ', () async {
    final m = dung();
    await m.tai();
    expect(await m.daCo(), isTrue);
    expect(File(await m.duongTep()).existsSync(), isTrue);
  });

  test('phát tiến độ từ dangTai tới daTai', () async {
    final m = dung();
    final thu = <TrangThaiMoHinh>[];
    final sub = m.tienDo.listen((t) => thu.add(t.trangThai));
    await m.tai();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.first, TrangThaiMoHinh.dangTai);
    expect(thu.last, TrangThaiMoHinh.daTai);
  });

  test('⚠️ tải hỏng giữa chừng thì XOÁ tệp dở, không để lại bản cụt', () async {
    // Tệp cụt 1,2 GB trông y hệt tệp đủ với `existsSync()`, và lần mở app sau
    // sẽ nạp nó rồi ném "Model may be invalid" — đúng thông báo mà P1 đã mất
    // hàng giờ vì nó (mục 8.2). Xoá ngay lúc hỏng là chỗ rẻ nhất để chặn.
    final m = dung(taiGia: (url, dich, bao) async {
      dich.writeAsBytesSync(List.filled(512, 0));
      throw const SocketException('mất mạng');
    });
    await expectLater(m.tai(), throwsA(isA<Exception>()));
    expect(await m.daCo(), isFalse);
    expect(File(await m.duongTep()).existsSync(), isFalse);
  });

  test('trạng thái sau khi hỏng là loi, kèm câu lỗi', () async {
    final m = dung(taiGia: (url, dich, bao) async {
      throw const SocketException('mất mạng');
    });
    final thu = <TienDoTai>[];
    final sub = m.tienDo.listen(thu.add);
    try {
      await m.tai();
    } catch (_) {}
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.last.trangThai, TrangThaiMoHinh.loi);
    expect(thu.last.loi, isNotNull);
  });

  test('xoa() gỡ tệp và đưa daCo() về false', () async {
    final m = dung();
    await m.tai();
    await m.xoa();
    expect(await m.daCo(), isFalse);
  });

  test('gọi tai() hai lần chồng nhau chỉ chạy MỘT lượt', () async {
    var soLan = 0;
    final m = dung(taiGia: (url, dich, bao) async {
      soLan++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      dich.writeAsBytesSync(List.filled(16, 0));
    });
    await Future.wait([m.tai(), m.tai()]);
    expect(soLan, 1,
        reason: 'Người dùng bấm hai lần, hoặc màn dựng lại giữa chừng — hai '
            'lượt tải 2,41 GB song song vào cùng một tệp là hỏng tệp.');
  });
}
