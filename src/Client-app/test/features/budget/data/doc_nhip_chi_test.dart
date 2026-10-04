/// Nhịp chi là phần PHỤ (spec mục 5): đọc hỏng thì rơi về {} — mọi chỗ dùng đi
/// phép chi đều như trước, không làm hỏng trang / kế hoạch / tool.
library;

import 'package:flowmoney/features/budget/data/doc_nhip_chi.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/nhip_chi_mau.dart';

class _Repo implements BudgetRepository {
  _Repo({this.ketQua = const {}, this.nem = false});
  final Map<String, NhipChi?> ketQua;
  final bool nem;
  var soLanGoi = 0;

  @override
  Future<Map<String, NhipChi?>> nhipChiTheoNganSach(
      int idaccount, List<BudgetEntity> budgets,
      {DateTime? now}) async {
    soLanGoi++;
    if (nem) throw StateError('CSDL hỏng');
    return ketQua;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

final _b = BudgetEntity(
  id: 'b1',
  idaccount: 7,
  categoryId: 'c1',
  amount: 1,
  startDate: DateTime(2026, 9, 1),
  recurrence: true,
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  test('chuyển nguyên kết quả của repository', () async {
    final n = nhipNhaO();
    final kq = await docNhipChi(_Repo(ketQua: {'b1': n}), 7, [_b], mocMau);
    expect(kq['b1'], same(n));
  });

  test('repository ném → {} (rơi về chi đều), không ném tiếp', () async {
    expect(await docNhipChi(_Repo(nem: true), 7, [_b], mocMau), isEmpty);
  });

  test('danh sách rỗng → {} và không gọi repository', () async {
    final r = _Repo();
    expect(await docNhipChi(r, 7, const [], mocMau), isEmpty);
    expect(r.soLanGoi, 0);
  });
}
