/// `getLastTransactionDate` — đầu vào **duy nhất** của lời nhắc ghi chép.
///
/// Lời nhắc hằng ngày là loại nhắc duy nhất trong app suy từ việc **không có**
/// dữ liệu, nên nó đứng hay ngã hoàn toàn ở truy vấn này. Ba cách hỏng đều
/// **im lặng** — không exception, không log: đọc nhầm cả giao dịch đã xoá mềm
/// thì người dùng vừa xoá hết vẫn không được nhắc; đọc nhầm tài khoản khác thì
/// trên máy dùng chung lời nhắc biến mất theo hoạt động của người kia; và trả
/// `null` sai thì họ bị nhắc mỗi ngày dù vẫn đang ghi đều.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  const accountId = 7;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // ⚠️ `forTesting` bật `PRAGMA foreign_keys = ON`, và `transactions.walletId`
    // tham chiếu `wallets.id`. Thiếu hàng ví này thì mọi lệnh chèn dưới đây nổ
    // `SqliteException(787)` — một lỗi đọc như hỏng truy vấn nhưng thật ra chỉ
    // là thiếu dữ liệu dựng sẵn.
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w-1',
      idaccount: accountId,
      name: 'Tiền mặt',
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w-9',
      idaccount: 9,
      name: 'Ví người khác',
      updatedAt: DateTime(2026, 9, 1),
    ));
  });
  tearDown(() async => db.close());

  Future<void> them({
    required String id,
    required DateTime date,
    int idaccount = accountId,
    bool daXoa = false,
  }) async {
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: id,
      walletId: idaccount == accountId ? 'w-1' : 'w-9',
      idaccount: idaccount,
      amount: 50000,
      type: 'chi',
      date: date,
      updatedAt: date,
      deletedAt: daXoa ? Value(date) : const Value.absent(),
    ));
  }

  test('trả về ngày của giao dịch MỚI NHẤT', () async {
    await them(id: 't1', date: DateTime(2026, 9, 1, 8));
    await them(id: 't2', date: DateTime(2026, 9, 5, 21, 30));
    await them(id: 't3', date: DateTime(2026, 9, 3, 12));

    expect(await db.transactionDao.getLastTransactionDate(accountId),
        DateTime(2026, 9, 5, 21, 30),
        reason: 'Phải là MAX chứ không phải hàng đầu tiên gặp được — thứ tự '
            'chèn không nói gì về thứ tự ngày.');
  });

  test('bỏ qua giao dịch đã xoá mềm', () async {
    await them(id: 'cu', date: DateTime(2026, 9, 1));
    await them(id: 'daXoa', date: DateTime(2026, 9, 9), daXoa: true);

    expect(await db.transactionDao.getLastTransactionDate(accountId),
        DateTime(2026, 9, 1),
        reason: 'Người dùng xoá giao dịch hôm nay rồi thì hôm nay coi như chưa '
            'ghi gì — không lọc là lời nhắc im lặng biến mất đúng hôm cần nhất.');
  });

  test('không đọc giao dịch của tài khoản khác', () async {
    await them(id: 'cua-toi', date: DateTime(2026, 9, 1));
    await them(id: 'cua-nguoi-khac', date: DateTime(2026, 9, 9), idaccount: 9);

    expect(await db.transactionDao.getLastTransactionDate(accountId),
        DateTime(2026, 9, 1),
        reason: 'Dự án đã có tiền lệ hỏng đúng kiểu này: các truy vấn '
            '*NonDeleted không lọc tài khoản. Trên máy dùng chung, đọc lẫn là '
            'lời nhắc của người này tắt theo hoạt động của người kia.');
  });

  test('chưa có giao dịch nào thì trả null', () async {
    expect(await db.transactionDao.getLastTransactionDate(accountId), isNull,
        reason: 'null nghĩa là "chưa từng ghi gì", và nơi gọi phải đọc nó '
            'thành CẦN nhắc — người mới cài app chính là người cần nhắc nhất.');
  });

  test('chỉ có giao dịch đã xoá mềm cũng trả null', () async {
    await them(id: 'daXoa', date: DateTime(2026, 9, 9), daXoa: true);

    expect(await db.transactionDao.getLastTransactionDate(accountId), isNull,
        reason: 'MAX trên tập rỗng phải ra null chứ không được ném hay trả về '
            'một mốc mặc định nào đó.');
  });
}
