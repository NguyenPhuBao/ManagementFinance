/// `purgeDataForAccount` — ngược chiều `purgeDataForOtherAccounts`.
///
/// Đây là xoá **bản sao cục bộ** của một tài khoản mà server đã ẩn danh hoá
/// (xoá `note`, `images`), không phải xoá dữ liệu người dùng trên server — quy
/// tắc 5 `CLAUDE.md` không áp vào đây. Spec cưỡng chế đăng xuất §3.6.
///
/// Chỉ gọi cho tài khoản **đã bị xoá**. Tài khoản chỉ **bị khoá** thì admin mở
/// khoá lại được và thay đổi chưa đồng bộ vẫn còn đường lên server (mục 2, Q2).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  final moc = DateTime(2026, 9, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Chèn một hàng vào **cả chín** bảng mà hàm này đụng tới, dưới [idaccount].
  Future<void> themDuBoDuLieu(int idaccount, String hauTo) async {
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w_$hauTo',
          idaccount: idaccount,
          name: 'Tien mat $hauTo',
          updatedAt: moc,
        ));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c_$hauTo',
          idaccount: idaccount,
          name: 'An uong $hauTo',
          classify: 'expense',
          updatedAt: moc,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't_$hauTo',
          walletId: 'w_$hauTo',
          idaccount: idaccount,
          amount: 50000,
          type: 'chi',
          date: moc,
          updatedAt: moc,
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: 'b_$hauTo',
          idaccount: idaccount,
          amount: 1000000,
          startDate: moc,
          updatedAt: moc,
        ));
    await db.into(db.bills).insert(BillsCompanion.insert(
          id: 'bill_$hauTo',
          idaccount: idaccount,
          name: 'Tien dien $hauTo',
          amount: 200000,
          dueDate: moc,
          updatedAt: moc,
        ));
    await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'g_$hauTo',
          idaccount: idaccount,
          name: 'Mua xe $hauTo',
          targetAmount: 9000000,
          targetDate: moc,
          updatedAt: moc,
        ));
    await db.into(db.categoryKeywords).insert(CategoryKeywordsCompanion.insert(
          id: 'kw_$hauTo',
          idaccount: idaccount,
          categoryId: 'c_$hauTo',
          keyword: 'pho',
          normalizedKeyword: 'pho',
          createdAt: moc,
          updatedAt: moc,
        ));
    await db
        .into(db.categoryGroupMemberships)
        .insert(CategoryGroupMembershipsCompanion.insert(
          id: 'gm_$hauTo',
          idaccount: idaccount,
          groupId: 'grp_$hauTo',
          categoryId: 'c_$hauTo',
          createdAt: moc,
          updatedAt: moc,
        ));
    await db.into(db.appNotifications).insert(AppNotificationsCompanion.insert(
          id: 'n_$hauTo',
          idaccount: idaccount,
          kind: 'bill',
          dedupeKey: 'bill:$hauTo',
          title: 'Sap toi han',
          body: 'Tien dien',
          severity: 'info',
          createdAt: moc,
        ));
  }

  /// Số hàng còn lại của [idaccount] ở cả chín bảng.
  Future<int> conLai(int idaccount) async {
    var n = 0;
    n += (await (db.select(db.wallets)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.categories)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.transactions)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.budgets)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.bills)..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.goals)..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.categoryKeywords)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.categoryGroupMemberships)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    n += (await (db.select(db.appNotifications)
              ..where((t) => t.idaccount.equals(idaccount)))
            .get())
        .length;
    return n;
  }

  test('xoá đủ CHÍN bảng của đúng tài khoản được nêu', () async {
    await themDuBoDuLieu(11, 'a');

    final daXoa = await db.purgeDataForAccount(11);

    expect(daXoa, 9,
        reason: 'bỏ sót một bảng là để lại bản rõ của dữ liệu mà server đã ẩn '
            'danh hoá — hỏng im lặng, không ai thấy');
    expect(await conLai(11), 0);
  });

  test('tài khoản khác còn nguyên', () async {
    await themDuBoDuLieu(11, 'a');
    await themDuBoDuLieu(12, 'b');

    await db.purgeDataForAccount(11);

    expect(await conLai(12), 9,
        reason: 'quét cả máy là xoá dữ liệu của người khác đang dùng chung máy');
  });

  test('giữ danh mục mặc định idaccount = 0', () async {
    // Bộ mặc định đã nằm sẵn trong CSDL mới — dùng chính nó làm bằng chứng,
    // đừng tự chèn thêm (id `cat_*` đã có, chèn lại là vỡ UNIQUE).
    Future<int> soHangMacDinh() async => (await (db.select(db.categories)
              ..where((t) => t.idaccount.equals(0)))
            .get())
        .length;

    final truoc = await soHangMacDinh();
    expect(truoc, greaterThan(0),
        reason: 'CSDL mới phải có sẵn bộ khuôn, nếu không ca test này vô nghĩa');
    await themDuBoDuLieu(11, 'a');

    await db.purgeDataForAccount(11);

    expect(await soHangMacDinh(), truoc,
        reason: 'hàng idaccount = 0 là KHUÔN dùng chung, không thuộc về ai — '
            'xoá nó là mất chỗ dựa để tạo bản sao cho tài khoản kế tiếp');
  });

  test('id <= 0 thì không xoá gì', () async {
    await themDuBoDuLieu(11, 'a');

    for (final id in [0, -1]) {
      expect(await db.purgeDataForAccount(id), 0,
          reason: 'id hỏng mà xoá theo là quét sạch dữ liệu của người đang dùng; '
              'riêng 0 còn là bộ danh mục mặc định');
    }
    expect(await conLai(11), 9);
  });
}
