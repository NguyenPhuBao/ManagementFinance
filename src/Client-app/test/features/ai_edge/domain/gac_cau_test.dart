/// Gác theo CÂU — cách hoà streaming với bộ kiểm (người dùng chốt 2026-09-22,
/// việc số 1 của lộ trình): token đổ vào bộ đệm, đủ một câu thì kiểm rồi mới
/// phát; trượt thì huỷ sinh và phát "bị chặn". Người dùng **không bao giờ**
/// thấy một câu chưa qua kiểm — dây an toàn của `kiemSo` giữ nguyên nghĩa.
///
/// Hai ca quan trọng nhất: dấu chấm ngăn nghìn không phải kết câu, và câu bị
/// chặn thì mọi token sau nó **không được** hiện.
library;

import 'dart:async';

import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tachCauHoanChinh', () {
    test('tách ở . ! ? theo sau bởi khoảng trắng hoặc hết chuỗi', () {
      final (cau, conLai) = tachCauHoanChinh(
        'Chi 2.141.000 đ trên 15.135.000 đ thu. Để dành 85,4%! Còn 9 ngày?',
      );
      expect(cau, [
        'Chi 2.141.000 đ trên 15.135.000 đ thu.',
        'Để dành 85,4%!',
        'Còn 9 ngày?',
      ]);
      expect(conLai, '');
    });

    test('⭐ dấu chấm ngăn nghìn KHÔNG phải kết câu', () {
      final (cau, conLai) = tachCauHoanChinh('Chi 2.141');
      expect(cau, isEmpty);
      expect(conLai, 'Chi 2.141');
    });

    test('phần chưa có dấu kết giữ lại làm phần còn lại', () {
      final (cau, conLai) = tachCauHoanChinh('Chi 2.141.000 đ. Để dành 85');
      expect(cau, ['Chi 2.141.000 đ.']);
      expect(conLai, 'Để dành 85');
    });

    test('câu phát ra đã trim, phần còn lại giữ nguyên chữ', () {
      final (cau, conLai) = tachCauHoanChinh('  Xong.   Còn ');
      expect(cau, ['Xong.']);
      expect(conLai, 'Còn ');
    });
  });

  group('gacTheoCau', () {
    Stream<String> tokens(List<String> ds) => Stream.fromIterable(ds);

    test('mọi câu qua kiểm thì phát từng câu, không huỷ', () async {
      var soLanHuy = 0;
      final sk = await gacTheoCau(
        tokens(['Chi 2.1', '41.000 đ. Để ', 'dành 85,4%.']),
        kiem: (_) => true,
        huy: () async => soLanHuy++,
      ).toList();
      expect(sk, [
        const CauQua('Chi 2.141.000 đ.'),
        const CauQua('Để dành 85,4%.'),
      ]);
      expect(soLanHuy, 0);
    });

    test('⭐ câu trượt: phát BiChan, huỷ đúng một lần, câu sau KHÔNG hiện',
        () async {
      var soLanHuy = 0;
      final daDoc = <String>[];
      final controller = StreamController<String>();
      final nguon = controller.stream.map((t) {
        daDoc.add(t);
        return t;
      });
      final ketQua = gacTheoCau(
        nguon,
        kiem: (c) => !c.contains('85,4'),
        huy: () async => soLanHuy++,
      ).toList();
      controller
        ..add('Chi 2.141.000 đ. ')
        ..add('Tỉ lệ phân bổ 85,4%. ')
        ..add('Còn 9 ngày.');
      await controller.close();

      expect(await ketQua, [
        const CauQua('Chi 2.141.000 đ.'),
        const BiChan('Tỉ lệ phân bổ 85,4%.'),
      ]);
      expect(soLanHuy, 1);
    });

    test('hết luồng mà không có dấu kết: phần còn lại vẫn là một câu phải kiểm',
        () async {
      final qua = await gacTheoCau(
        tokens(['Còn 9 ', 'ngày']),
        kiem: (_) => true,
        huy: () async {},
      ).toList();
      expect(qua, [const CauQua('Còn 9 ngày')]);

      final chan = await gacTheoCau(
        tokens(['Còn 99 ngày']),
        kiem: (_) => false,
        huy: () async {},
      ).toList();
      expect(chan, [const BiChan('Còn 99 ngày')]);
    });

    test('luồng rỗng hoặc chỉ khoảng trắng thì không phát gì', () async {
      expect(
        await gacTheoCau(tokens([]), kiem: (_) => true, huy: () async {})
            .toList(),
        isEmpty,
      );
      expect(
        await gacTheoCau(tokens(['  ', '\n']), kiem: (_) => true,
            huy: () async {}).toList(),
        isEmpty,
      );
    });

    test('câu đến trong MỘT token cũng kiểm từng câu', () async {
      final sk = await gacTheoCau(
        tokens(['A 1. B 2. C 3.']),
        kiem: (c) => !c.startsWith('B'),
        huy: () async {},
      ).toList();
      expect(sk, [const CauQua('A 1.'), const BiChan('B 2.')]);
    });
  });
}
