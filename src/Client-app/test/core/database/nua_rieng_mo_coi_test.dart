/// `TransactionDao.nuaRiengMoCoi` — nửa riêng còn sống mà MỌI nửa của nhà cùng mã cặp đã bị xoá (gia đình 1A). Ca canh kết quả
/// của bản hai-truy-vấn-rồi-nhóm-trong-Dart (thay cho một truy vấn mỗi nửa riêng): ghép đúng theo mã cặp, không lẫn cặp.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final ngay = DateTime(2026, 11, 1, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final (id, tk, nha) in [('vr', 10, null), ('vr2', 11, null), ('vn7', 99, 7), ('vn8', 99, 8)]) {
      await db.walletDao.insert(WalletsCompanion.insert(
          id: id, idaccount: tk, name: id, idhousehold: Value(nha), updatedAt: DateTime(2026, 10, 1)));
    }
  });
  tearDown(() => db.close());

  Future<void> them(String id, String vi, {int tk = 10, int? nha, String? cap, bool xoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion(
        id: Value(id),
        idaccount: Value(tk),
        walletId: Value(vi),
        idhousehold: Value(nha),
        fundPairId: Value(cap),
        amount: const Value(100),
        type: const Value('chi'),
        date: Value(ngay),
        isDeleted: Value(xoa),
        deletedAt: Value(xoa ? ngay : null),
        updatedAt: Value(ngay),
      ));

  test('chỉ cặp có MỌI nửa nhà đã xoá mới là mồ côi; ghép theo mã cặp, kèm nhà và ví chung của nửa ấy', () async {
    // A: một nửa nhà, đã xoá ⇒ mồ côi.
    await them('a-rieng', 'vr', cap: 'A');
    await them('a-nha', 'vn7', tk: 99, nha: 7, cap: 'A', xoa: true);
    // B: nửa nhà còn sống ⇒ không mồ côi.
    await them('b-rieng', 'vr', cap: 'B');
    await them('b-nha', 'vn7', tk: 99, nha: 7, cap: 'B');
    // C: hai nửa nhà, một xoá một sống ⇒ không mồ côi.
    await them('c-rieng', 'vr', cap: 'C');
    await them('c-nha-1', 'vn7', tk: 99, nha: 7, cap: 'C', xoa: true);
    await them('c-nha-2', 'vn7', tk: 98, nha: 7, cap: 'C');
    // D: không còn nửa nhà nào trên máy (đã dọn khi rời nhà) ⇒ KHÔNG mồ côi.
    await them('d-rieng', 'vr', cap: 'D');
    // E: nhà khác, xoá hết ⇒ mồ côi, kèm nhà 8 và ví của nhà 8.
    await them('e-rieng', 'vr', cap: 'E');
    await them('e-nha', 'vn8', tk: 99, nha: 8, cap: 'E', xoa: true);
    // F: nửa riêng của TÀI KHOẢN KHÁC ⇒ không tính cho tài khoản 10.
    await them('f-rieng', 'vr2', tk: 11, cap: 'F');
    await them('f-nha', 'vn7', tk: 99, nha: 7, cap: 'F', xoa: true);
    // G: nửa riêng đã xoá ⇒ không tính.
    await them('g-rieng', 'vr', cap: 'G', xoa: true);
    await them('g-nha', 'vn7', tk: 99, nha: 7, cap: 'G', xoa: true);

    final ra = await db.transactionDao.nuaRiengMoCoi(10);
    final theoId = {for (final r in ra) r.rieng.id: (r.idNha, r.viNhaId)};
    expect(theoId.keys.toSet(), {'a-rieng', 'e-rieng'});
    expect(theoId['a-rieng'], (7, 'vn7'));
    expect(theoId['e-rieng'], (8, 'vn8'), reason: 'mỗi cặp ghép đúng nửa nhà của MÃ CẶP ấy, không lẫn sang cặp khác');
  });

  test('không có nửa riêng nào: trả rỗng', () async {
    expect(await db.transactionDao.nuaRiengMoCoi(10), isEmpty);
  });
}
