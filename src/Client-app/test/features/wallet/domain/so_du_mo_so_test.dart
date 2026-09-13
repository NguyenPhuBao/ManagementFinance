/// Khoản "Số dư ban đầu" — điểm neo để số dư ví suy được từ sổ giao dịch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

void main() {
  const idVi = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  group('idKhoanMoSo', () {
    test('CÙNG ví thì CÙNG id, gọi bao nhiêu lần cũng vậy', () {
      expect(idKhoanMoSo(idVi), idKhoanMoSo(idVi),
          reason: 'Đây là chốt chặn DUY NHẤT giữ cho hai máy cùng vá neo mà '
              'không đẻ ra hai khoản mở sổ: cùng id thì `/sync/push` ghép làm '
              'một hàng.');
    });

    test('ví khác thì id khác', () {
      expect(idKhoanMoSo(idVi),
          isNot(idKhoanMoSo('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')));
    });

    test('là UUID v5 hợp lệ', () {
      expect(
          idKhoanMoSo(idVi),
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
          reason: 'Cột `transaction.Idtran` là VarChar(36); id không hợp lệ là '
              'bản ghi vỡ ở tầng CSDL rồi kẹt hàng đợi đẩy, im lặng.');
    });
  });

  group('laKhoanMoSo', () {
    test('nhận đúng khoản mở sổ', () {
      expect(laKhoanMoSo(loai: 'thu', categoryId: null, ghiChu: ghiChuMoSo()),
          isTrue);
    });

    test('TỪ CHỐI khi có danh mục, dù ghi chú đúng tiền tố', () {
      expect(
          laKhoanMoSo(loai: 'thu', categoryId: 'cat-1', ghiChu: ghiChuMoSo()),
          isFalse,
          reason: 'Phép nhận dạng đòi CẶP điều kiện. `transaction.Note` sửa '
              'được, nên một dấu hiệu chỉ nằm trong ghi chú có thể mất — và '
              'mất thì khoản mở sổ lặng lẽ thành thu nhập thật trong báo cáo.');
    });

    test('TỪ CHỐI khoản chuyển', () {
      expect(
          laKhoanMoSo(
              loai: 'transfer', categoryId: null, ghiChu: ghiChuMoSo()),
          isFalse,
          reason: 'Khoản chuyển đã có luật loại riêng; nhận nó ở đây là hai '
              'luật cùng nói về một hàng.');
    });

    test('TỪ CHỐI ghi chú khác', () {
      expect(
          laKhoanMoSo(
              loai: 'thu', categoryId: null, ghiChu: 'Lương tháng 9'),
          isFalse);
    });

    test('chịu được khoảng trắng đứng trước', () {
      expect(
          laKhoanMoSo(
              loai: 'thu', categoryId: null, ghiChu: '  ${ghiChuMoSo()}'),
          isTrue);
    });
  });
}
