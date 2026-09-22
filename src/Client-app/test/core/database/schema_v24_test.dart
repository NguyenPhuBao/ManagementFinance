/// Schema v24 (Edge-SLM P2): cột `categories.ai_co_dinh` và bảng
/// `ai_rebalancing_feedbacks` — CẢ HAI cục bộ, không đi qua đồng bộ.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

AiRebalancingFeedbacksCompanion _dong({required int idaccount, String id = 'f'}) =>
    AiRebalancingFeedbacksCompanion.insert(
      id: '$id-$idaccount',
      idaccount: idaccount,
      createdAt: DateTime(2026, 9, 19),
      deficitBudgetId: 'an',
      donorBudgetId: 'ms',
      donorCategoryId: 'c-ms',
      suggestedAmount: 500000,
      actualAmount: 500000,
      action: 'accepted',
      periodFrom: DateTime(2026, 9, 1),
      periodTo: DateTime(2026, 10, 1),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema là v24', () => expect(db.schemaVersion, 24));

  test('categories có cột ai_co_dinh, mặc định false', () async {
    final cols = await db.customSelect("PRAGMA table_info('categories')").get();
    final c = cols.firstWhere((r) => r.read<String>('name') == 'ai_co_dinh');
    expect(c.read<String>('type').toUpperCase(), contains('INT'),
        reason: 'Drift lưu bool là INTEGER');
    // Hàng mới không nói gì về cờ thì cờ tắt — đúng hành vi trước bản này.
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          idaccount: 7,
          name: 'Tiền nhà',
          classify: 'chi',
          updatedAt: DateTime(2026, 9, 19),
        ));
    final row = await (db.select(db.categories)..where((t) => t.id.equals('c1')))
        .getSingle();
    expect(row.aiCoDinh, isFalse);
  });

  test('bảng ai_rebalancing_feedbacks tồn tại và KHÔNG có cột đồng bộ', () async {
    final cols = await db
        .customSelect("PRAGMA table_info('ai_rebalancing_feedbacks')")
        .get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(
        ten,
        containsAll([
          'id',
          'idaccount',
          'created_at',
          'deficit_budget_id',
          'donor_budget_id',
          'donor_category_id',
          'suggested_amount',
          'actual_amount',
          'action',
          'period_from',
          'period_to',
        ]));
    expect(
        ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}),
        isEmpty,
        reason: 'bảng cục bộ — vắng cột đồng bộ chính là tài liệu sống (quy tắc 9)');
  });

  test('DAO ghi và đọc theo tài khoản', () async {
    await db.aiFeedbackDao.ghi(_dong(idaccount: 7));
    await db.aiFeedbackDao.ghi(_dong(idaccount: 7, id: 'g'));
    await db.aiFeedbackDao.ghi(_dong(idaccount: 8));
    expect(await db.aiFeedbackDao.getAll(7), hasLength(2));
    expect(await db.aiFeedbackDao.getAll(8), hasLength(1));
    expect(await db.aiFeedbackDao.getAll(9), isEmpty);
  });

  test('purgeDataForOtherAccounts xoá phản hồi của tài khoản khác, giữ của mình',
      () async {
    await db.aiFeedbackDao.ghi(_dong(idaccount: 7));
    await db.aiFeedbackDao.ghi(_dong(idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect(await db.aiFeedbackDao.getAll(8), isEmpty);
    expect(await db.aiFeedbackDao.getAll(7), hasLength(1));
  });

  test('purgeDataForAccount xoá phản hồi của chính tài khoản ấy', () async {
    await db.aiFeedbackDao.ghi(_dong(idaccount: 7));
    await db.aiFeedbackDao.ghi(_dong(idaccount: 8));
    await db.purgeDataForAccount(7);
    expect(await db.aiFeedbackDao.getAll(7), isEmpty);
    expect(await db.aiFeedbackDao.getAll(8), hasLength(1));
  });
}
