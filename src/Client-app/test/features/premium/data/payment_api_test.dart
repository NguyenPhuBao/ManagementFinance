/// `bocData` / `bocDanhSach` — bóc bao `{success, message, data}` của backend
/// (spec Premium 6.2). Bản Dio mỏng, chỉ phần bóc thân là có gì để test.
library;

import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bocData bóc `data` khỏi bao {success, message, data}', () {
    expect(
        bocData({
          'success': true,
          'message': 'ok',
          'data': {'accountType': 'Premium'},
        }),
        {'accountType': 'Premium'});
  });

  test('bocData: không có `data` thì coi cả thân là data; không phải Map → {}',
      () {
    expect(bocData({'accountType': 'Basic'}), {'accountType': 'Basic'});
    expect(bocData('x'), isEmpty);
    expect(bocData(null), isEmpty);
    expect(bocData({'success': true, 'data': 'rac'}),
        {'success': true, 'data': 'rac'});
  });

  test('bocDanhSach lấy items, bỏ phần tử không phải Map', () {
    final ds = bocDanhSach({
      'data': {
        'total': 2,
        'items': [
          {'order_code': 1},
          'rac',
          {'order_code': 2},
        ],
      },
    }, 'items');
    expect(ds.map((e) => e['order_code']), [1, 2]);
    expect(bocDanhSach({'data': {}}, 'items'), isEmpty);
    expect(bocDanhSach(null, 'items'), isEmpty);
  });
}
