import 'package:flowmoney/features/transaction/data/models/transaction_type_label.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiêu đề dự phòng của một dòng giao dịch khi ghi chú để trống.
///
/// Canh chừng điều gì: trang sổ giao dịch từng viết `type == 'chi' ? 'Khoản
/// chi' : 'Khoản thu'` — hai nhánh cho ba loại — nên khoản chuyển ví không ghi
/// chú hiện thành "Khoản thu".
void main() {
  test('mỗi loại giao dịch một tiêu đề, khoản chuyển không bị gọi là khoản thu',
      () {
    expect(transactionTypeLabel('chi'), 'Khoản chi');
    expect(transactionTypeLabel('thu'), 'Khoản thu');
    expect(transactionTypeLabel('transfer'), 'Chuyển khoản');
  });

  test('giá trị lạ không nổ, trả về nhãn chung', () {
    expect(transactionTypeLabel('adjustment'), 'Giao dịch');
  });
}
