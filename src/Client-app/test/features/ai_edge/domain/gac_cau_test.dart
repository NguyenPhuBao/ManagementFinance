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
    test('tách ở . ! ? theo sau bởi khoảng trắng; CUỐI CHUỖI thì chưa', () {
      // Cuối bộ đệm không phải cuối câu khi luồng còn mở — xem ca ⭐ dưới.
      final (cau, conLai) = tachCauHoanChinh(
        'Chi 2.141.000 đ trên 15.135.000 đ thu. Để dành 85,4%! Còn 9 ngày?',
      );
      expect(cau, [
        'Chi 2.141.000 đ trên 15.135.000 đ thu.',
        'Để dành 85,4%!',
      ]);
      expect(conLai, 'Còn 9 ngày?');
    });

    test('⭐ dấu chấm ngăn nghìn KHÔNG phải kết câu', () {
      final (cau, conLai) = tachCauHoanChinh('Chi 2.141');
      expect(cau, isEmpty);
      expect(conLai, 'Chi 2.141');
    });

    test('⭐ dấu chấm ở CUỐI bộ đệm chưa phải kết câu — token cắt giữa con số',
        () {
      // Đo trên OnePlus 13R 2026-09-22: mô hình phát "…là 2" rồi ".141.000 đ."
      // — bộ đệm dừng ở "là 2." đúng một nhịp, bản đầu coi đó là câu xong,
      // bộ kiểm chặn "2" (không khớp số nào) và cả lượt rơi về câu lùi.
      // Fake stream của test đưa nguyên con số nên không bao giờ thấy.
      final (cau, conLai) = tachCauHoanChinh('Chi tiêu tháng này là 2.');
      expect(cau, isEmpty);
      expect(conLai, 'Chi tiêu tháng này là 2.');
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

    test('⭐ token cắt giữa con số: câu chỉ kiểm khi số đã đủ', () async {
      // Chính lượt đo 2026-09-22: vết cắt nằm NGAY SAU dấu chấm — token "…là
      // 2." rồi "141.000 đ. ". Với bản sai, sự kiện đầu là
      // BiChan('Chi tiêu tháng này là 2.'). ⚠️ Cắt trước dấu chấm ("là 2" +
      // ".141") thì bản sai cũng xanh — ca đầu viết thế và không canh gì.
      final sk = await gacTheoCau(
        tokens(['Chi tiêu tháng này là 2.', '141.000 đ. ', 'Xong.']),
        kiem: (c) => !c.endsWith(' 2.'),
        huy: () async {},
      ).toList();
      expect(sk, [
        const CauQua('Chi tiêu tháng này là 2.141.000 đ.'),
        const CauQua('Xong.'),
      ]);
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

  group('hai sự kiện của vòng lặp tool (chặng 4b)', () {
    test('DangTraCuu so bằng theo tên; null = mô hình đang viết', () {
      expect(const DangTraCuu('danh_sach_vi'), const DangTraCuu('danh_sach_vi'));
      expect(const DangTraCuu(null), const DangTraCuu(null));
      expect(const DangTraCuu('a'), isNot(const DangTraCuu(null)));
    });
    test('KhongTraCuu là singleton về nghĩa', () {
      expect(const KhongTraCuu(), const KhongTraCuu());
    });
  });
}
