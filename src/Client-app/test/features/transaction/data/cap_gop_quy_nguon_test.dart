/// Cổng `CapGopQuyNguon` (đợt 1B Task 9): nửa riêng của khoản góp / rút còn cặp để giữ khớp không.
///
/// Vì sao cần: lỗi đọc mà ném ra thì vuốt xoá, chạm khoản ở Sổ hỏng cả với khoản thường; lỗi đọc mà bịa ra một cặp thì
/// Sửa đẩy người dùng sang màn không có cặp. Mặc định an toàn là `null` = khoản thường, đúng như trước khi có cổng.
library;

import 'package:flowmoney/features/transaction/data/cap_gop_quy_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = TransactionEntity(
    id: 't',
    walletId: 'w',
    idaccount: 1,
    fundPairId: 'cap',
    amount: 1000,
    type: 'chi',
    date: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
  const cap = CapGopQuy(maCap: 'cap', laGop: true, cauXoa: 'câu', choThaoTac: true);

  test('cua trả đúng cặp hàm đọc đưa', () async {
    final nguon = CapGopQuyNguon(doc: (_) async => cap, xoa: (_) async {});
    expect(await nguon.cua(t), same(cap));
  });

  test('cua: hàm đọc trả null → null', () async {
    final nguon = CapGopQuyNguon(doc: (_) async => null, xoa: (_) async {});
    expect(await nguon.cua(t), isNull);
  });

  test('cua: hàm đọc ném → null, không ném ra chỗ gọi', () async {
    final nguon = CapGopQuyNguon(doc: (_) async => throw StateError('hỏng'), xoa: (_) async {});
    expect(await nguon.cua(t), isNull,
        reason: 'Lỗi đọc: khoản đi đường thường, không tệ hơn trước khi có cổng.');
  });

  test('xoaCap chuyển mã cặp cho hàm xoá; hàm xoá ném thì ném tiếp (trang báo lỗi)', () async {
    String? nhan;
    final nguon = CapGopQuyNguon(doc: (_) async => cap, xoa: (m) async => nhan = m);
    await nguon.xoaCap('cap');
    expect(nhan, 'cap');

    final hong = CapGopQuyNguon(doc: (_) async => cap, xoa: (_) async => throw StateError('không xoá được'));
    await expectLater(hong.xoaCap('cap'), throwsStateError,
        reason: 'Nuốt lỗi xoá thì hàng im lặng không biến mất mà người dùng không biết vì sao.');
  });
}
