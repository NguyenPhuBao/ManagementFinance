/// Cổng "hoá đơn của khoản này đã xoá chưa" (việc 4c) — mặc định an toàn là KHOÁ.
///
/// Vì sao cần: sổ chỉ mở khoá khoản trả hoá đơn khi biết CHẮC hoá đơn đã xoá mềm. Hàm đọc lỗi, hay hoá đơn chưa kéo
/// về máy, mà trả `true` là mở khoá một khoản trả của hoá đơn còn sống — xoá rời ở sổ thì kỳ vẫn `Payed`, Hoàn tác
/// hết đường lần về.
library;

import 'package:flowmoney/features/transaction/data/hoa_don_da_xoa_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionEntity tx({String? billId}) => TransactionEntity(
        id: 't',
        walletId: 'w',
        idaccount: 1,
        billId: billId,
        amount: 1000,
        type: 'chi',
        date: DateTime(2026, 10, 17),
        updatedAt: DateTime(2026, 10, 17),
      );

  group('daXoa', () {
    test('hàm đọc nói đã xoá → true', () async {
      expect(await HoaDonDaXoaNguon((_) async => true).daXoa('b1'), isTrue);
    });

    test('hàm đọc nói còn (hoặc không có hàng) → false', () async {
      expect(await HoaDonDaXoaNguon((_) async => false).daXoa('b1'), isFalse);
    });

    test('hàm đọc ném → false (khoá), không ném ra chỗ gọi', () async {
      final nguon = HoaDonDaXoaNguon((_) async => throw StateError('kho hỏng'));
      expect(await nguon.daXoa('b1'), isFalse,
          reason: 'Lỗi kho không được biến thành "mở khoá"; ném ra thì vuốt xoá '
              'ở sổ đổ lỗi giữa chừng.');
    });
  });

  group('hoaDonDaXoaCua', () {
    test('khoản không gắn hoá đơn → false, KHÔNG gọi hàm đọc', () async {
      var soLanDoc = 0;
      final nguon = HoaDonDaXoaNguon((_) async {
        soLanDoc++;
        return true;
      });
      expect(await hoaDonDaXoaCua(tx(), nguon), isFalse);
      expect(soLanDoc, 0, reason: 'Giao dịch thường không tốn một lần đọc kho.');
    });

    test('trang chưa có cổng → false (khoá như cũ)', () async {
      expect(await hoaDonDaXoaCua(tx(billId: 'b1'), null), isFalse);
    });

    test('có billId → hỏi đúng hoá đơn ấy', () async {
      String? daHoi;
      final nguon = HoaDonDaXoaNguon((id) async {
        daHoi = id;
        return true;
      });
      expect(await hoaDonDaXoaCua(tx(billId: 'b-42'), nguon), isTrue);
      expect(daHoi, 'b-42');
    });
  });
}
