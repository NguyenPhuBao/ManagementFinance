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

  test('chính phép dọn ném lỗi thì vẫn ném (không nuốt nhầm)', () async {
    await expectLater(
      donVaTinhLaiViNha(nhaGiu: null, don: () async => throw StateError('xoa'), tinhLaiViNha: () async {}),
      throwsA(isA<StateError>()),
    );
  });
}
