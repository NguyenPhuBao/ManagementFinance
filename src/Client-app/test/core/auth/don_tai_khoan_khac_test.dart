/// `donVaTinhLaiViNha` — phép tính lại số dư ví nhà sau khi dọn KHÔNG được làm hỏng cửa đăng nhập (G113 lỗ hổng 3).
library;

import 'package:flowmoney/core/auth/don_tai_khoan_khac.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chưa biết nhà: dọn rồi tính lại, trả số hàng đã dọn', () async {
    final nhatKy = <String>[];
    final n = await donVaTinhLaiViNha(
      nhaGiu: null,
      don: () async {
        nhatKy.add('don');
        return 4;
      },
      tinhLaiViNha: () async => nhatKy.add('tinhLai'),
    );
    expect(n, 4);
    expect(nhatKy, ['don', 'tinhLai']);
  });

  test('đã biết nhà: không tính lại', () async {
    var tinh = 0;
    final n = await donVaTinhLaiViNha(nhaGiu: 7, don: () async => 2, tinhLaiViNha: () async => tinh++);
    expect(n, 2);
    expect(tinh, 0, reason: 'đã biết nhà thì sổ của nhà được giữ nguyên, không có gì bị cắt');
  });

  test('tính lại ném lỗi: vẫn trả số hàng đã dọn, không ném (không khoá người dùng ở màn Đăng nhập)', () async {
    final n = await donVaTinhLaiViNha(
      nhaGiu: null,
      don: () async => 3,
      tinhLaiViNha: () async => throw StateError('csdl'),
    );
    expect(n, 3, reason: 'mất daDon là mất cả việc xoá cache SLM và xin kéo toàn bộ; lỗi lan lên là AuthError mỗi lần thử lại');
  });

  group('đã biết nhà MỚI: trả tiền nửa của các nhà CŨ còn trên máy TRƯỚC khi dọn (M-1)', () {
    test('mọi nhà khác nhà giữ được trả về, rồi mới dọn; nhà giữ không bị trả', () async {
      final nhatKy = <String>[];
      final n = await donVaTinhLaiViNha(
        nhaGiu: 8,
        idaccount: 10,
        cacNhaConTrenMay: () async => [7, 8, 9],
        traVeKhiBoNha: (idNha, id) async => nhatKy.add('tra:$idNha:$id'),
        don: () async {
          nhatKy.add('don');
          return 5;
        },
        tinhLaiViNha: () async => nhatKy.add('tinhLai'),
      );
      expect(n, 5);
      expect(nhatKy, ['tra:7:10', 'tra:9:10', 'don'],
          reason: 'trả tiền phải đứng TRƯỚC dọn: dọn xoá nửa nhà cũ mà không hoàn thì tiền ra khỏi ví riêng, quỹ không nhận');
    });

    test('một nhà trả hỏng: nuốt lỗi, nhà sau vẫn trả, vẫn dọn (không khoá cửa đăng nhập)', () async {
      final nhatKy = <String>[];
      final n = await donVaTinhLaiViNha(
        nhaGiu: 8,
        idaccount: 10,
        cacNhaConTrenMay: () async => [7, 9],
        traVeKhiBoNha: (idNha, id) async {
          nhatKy.add('tra:$idNha');
          if (idNha == 7) throw StateError('csdl');
        },
        don: () async {
          nhatKy.add('don');
          return 1;
        },
        tinhLaiViNha: () async {},
      );
      expect(n, 1);
      expect(nhatKy, ['tra:7', 'tra:9', 'don']);
    });

    test('đọc danh sách nhà hỏng: nuốt lỗi, vẫn dọn', () async {
      final n = await donVaTinhLaiViNha(
        nhaGiu: 8,
        idaccount: 10,
        cacNhaConTrenMay: () async => throw StateError('csdl'),
        traVeKhiBoNha: (idNha, id) async {},
        don: () async => 2,
        tinhLaiViNha: () async {},
      );
      expect(n, 2);
    });

    test('chưa biết nhà (nhaGiu null): không trả gì', () async {
      var tra = 0;
      await donVaTinhLaiViNha(
        nhaGiu: null,
        idaccount: 10,
        cacNhaConTrenMay: () async => [7],
        traVeKhiBoNha: (idNha, id) async => tra++,
        don: () async => 0,
        tinhLaiViNha: () async {},
      );
      expect(tra, 0, reason: 'chưa biết nhà thì phép dọn giữ hàng chưa đẩy của tôi, không có gì bị xoá để hoàn');
    });
  });

  test('chính phép dọn ném lỗi thì vẫn ném (không nuốt nhầm)', () async {
    await expectLater(
      donVaTinhLaiViNha(nhaGiu: null, don: () async => throw StateError('xoa'), tinhLaiViNha: () async {}),
      throwsA(isA<StateError>()),
    );
  });
}
