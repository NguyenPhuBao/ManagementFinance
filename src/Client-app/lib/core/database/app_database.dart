import 'package:drift/drift.dart';
import 'connection/connection.dart';

import 'tables/wallets_table.dart';
import 'tables/transactions_table.dart';
import 'tables/categories_table.dart';
import 'tables/other_tables.dart';
import 'daos/wallet_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/category_dao.dart';
import 'daos/other_daos.dart';

// ── Code generation ──────────────────────────────────────────────────────────
// File này cần chạy build_runner để sinh ra:
//   dart run build_runner build --delete-conflicting-outputs
part 'app_database.g.dart';

/// AppDatabase — single source of truth cho tất cả local data.
///
/// Sử dụng Drift (SQLite) với:
/// - LazyDatabase: mở DB trễ, chỉ khi cần (tiết kiệm tài nguyên)
/// - Schema versioning: schemaVersion tăng theo migrations
/// - DAOs: tách logic truy vấn theo từng entity
///
/// Cách dùng:
/// ```dart
/// final db = sl<AppDatabase>();
/// final wallets = await db.walletDao.getAll(idaccount);
/// ```
@DriftDatabase(
  tables: [
    Wallets,
    Transactions,
    Categories,
    CategoryKeywords,
    CategoryGroupMemberships,
    Budgets,
    Bills,
    Goals,
  ],
  daos: [
    WalletDao,
    TransactionDao,
    CategoryDao,
    BudgetDao,
    BillDao,
    GoalDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Seed default categories sau khi tạo DB lần đầu
        await _seedDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(goals, goals.walletId);
        }
        if (from < 3) {
          await m.addColumn(categories, categories.parentId);
          await m.addColumn(categories, categories.isGroup);
          await m.addColumn(categories, categories.isLocalOnly);
          await m.createTable(categoryKeywords);
        }
        if (from < 4) {
          await m.createTable(categoryGroupMemberships);
        }
        if (from < 5) {
          // Thêm cột includeInTotal cho việc tính vào tổng tài sản
          await m.addColumn(wallets, wallets.includeInTotal);
        }
        if (from < 6) {
          // ── Wallets (DB v2) ──────────────────────────────────────────────
          // Id_bank_casso: liên kết bank_account khi Type='Banking'
          await m.addColumn(wallets, wallets.bankCassoId);
          // Status: 'Active' | 'Inactive'
          await m.addColumn(wallets, wallets.status);
          // deletedAt: soft delete timestamp
          await m.addColumn(wallets, wallets.deletedAt);

          // ── Transactions (DB v2) ─────────────────────────────────────────
          // provider: 'Manual' | 'Casso' | 'SMS' | 'OCR'
          await m.addColumn(transactions, transactions.provider);
          // walletTransfer: ví đích khi chuyển khoản nội bộ
          await m.addColumn(transactions, transactions.walletTransfer);
          // bankTranId: ID giao dịch từ ngân hàng
          await m.addColumn(transactions, transactions.bankTranId);
          // deletedAt: soft delete timestamp
          await m.addColumn(transactions, transactions.deletedAt);

          // ── Categories (DB v2) ───────────────────────────────────────────
          await m.addColumn(categories, categories.deletedAt);

          // ── Budgets (DB v2) ──────────────────────────────────────────────
          await m.addColumn(budgets, budgets.spent);
          await m.addColumn(budgets, budgets.remaining);
          await m.addColumn(budgets, budgets.percentSpent);
          await m.addColumn(budgets, budgets.overSpending);
          await m.addColumn(budgets, budgets.overAmount);
          await m.addColumn(budgets, budgets.recurrence);
          await m.addColumn(budgets, budgets.timeRecurrence);
          await m.addColumn(budgets, budgets.deletedAt);

          // ── Bills (DB v2) ────────────────────────────────────────────────
          await m.addColumn(bills, bills.walletId);
          await m.addColumn(bills, bills.categoryId);
          await m.addColumn(bills, bills.isRecurrence);
          await m.addColumn(bills, bills.timeRecurrence);
          await m.addColumn(bills, bills.deletedAt);

          // ── Goals (DB v2) ────────────────────────────────────────────────
          await m.addColumn(goals, goals.deletedAt);
        }
        if (from < 7) {
          // ── Align SQLite schema with backend PostgreSQL (New_Database.md) ──

          // Transactions: thêm status giao dịch
          await m.addColumn(transactions, transactions.status);

          // Bills: thêm payStatus (thay thế isPaid boolean)
          await m.addColumn(bills, bills.payStatus);
          // Bills: thêm startDate (Start_date từ backend)
          await m.addColumn(bills, bills.startDate);
          // Bills: thêm timeNotification (số ngày nhắc trước hạn)
          await m.addColumn(bills, bills.timeNotification);

          // Budgets: thêm thresholdWarningAmount
          await m.addColumn(budgets, budgets.thresholdWarningAmount);
          // Budgets: thêm nextTimeRecurrence
          await m.addColumn(budgets, budgets.nextTimeRecurrence);

          // Goals: thêm startDate
          await m.addColumn(goals, goals.startDate);
          // Goals: thêm cycleTakeMoney
          await m.addColumn(goals, goals.cycleTakeMoney);
          // Goals: thêm timeCycleTakeMoney
          await m.addColumn(goals, goals.timeCycleTakeMoney);
          // Goals: thêm recurrence
          await m.addColumn(goals, goals.recurrence);
          // Goals: thêm timeRecurrence
          await m.addColumn(goals, goals.timeRecurrence);

          // Migrate isPaid → payStatus cho Bills đã có dữ liệu
          await customStatement(
            "UPDATE bills SET pay_status = CASE WHEN is_paid = 1 THEN 'Payed' ELSE 'Pending' END "
            "WHERE pay_status = 'Pending'",
          );
        }
      },
      beforeOpen: (details) async {
        // Bật foreign key constraints (SQLite tắt mặc định)
        await customStatement('PRAGMA foreign_keys = ON');
        // Tối ưu performance
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        // Fail-safe migration cho wallet_id trên DB cũ
        try {
          await customStatement('ALTER TABLE goals ADD COLUMN wallet_id TEXT;');
        } catch (_) {
          // Cột đã tồn tại hoặc đã được tạo bởi Drift migration
        }
      },
    );
  }

  // ── DAO getters (tiện dùng) ───────────────────────────────────────────────

  @override WalletDao      get walletDao      => WalletDao(this);
  @override TransactionDao get transactionDao => TransactionDao(this);
  @override CategoryDao    get categoryDao    => CategoryDao(this);
  @override BudgetDao      get budgetDao      => BudgetDao(this);
  @override BillDao        get billDao        => BillDao(this);
  @override GoalDao        get goalDao        => GoalDao(this);

  // ── Seed default categories ───────────────────────────────────────────────
  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now();
    const defaultCats = [
      // ── Chi tiêu ──────────────────────────────────────────────────────────
      (id: 'cat_food',       name: 'Ăn uống',         classify: 'chi',     icon: 'restaurant',   colour: '#FF5722'),
      (id: 'cat_transport',  name: 'Di chuyển',        classify: 'chi',     icon: 'directions_car', colour: '#2196F3'),
      (id: 'cat_shopping',   name: 'Mua sắm',          classify: 'chi',     icon: 'shopping_bag',  colour: '#9C27B0'),
      (id: 'cat_health',     name: 'Sức khoẻ',         classify: 'chi',     icon: 'local_hospital', colour: '#F44336'),
      (id: 'cat_education',  name: 'Giáo dục',         classify: 'chi',     icon: 'school',        colour: '#3F51B5'),
      (id: 'cat_entertain',  name: 'Giải trí',         classify: 'chi',     icon: 'sports_esports', colour: '#E91E63'),
      (id: 'cat_housing',    name: 'Nhà ở',            classify: 'chi',     icon: 'home',          colour: '#607D8B'),
      (id: 'cat_bill_chi',   name: 'Hoá đơn & Dịch vụ', classify: 'chi',  icon: 'receipt',       colour: '#795548'),
      (id: 'cat_other_chi',  name: 'Chi khác',         classify: 'chi',     icon: 'more_horiz',    colour: '#9E9E9E'),
      // ── Thu nhập ──────────────────────────────────────────────────────────
      (id: 'cat_salary',     name: 'Lương',            classify: 'thu',     icon: 'work',          colour: '#4CAF50'),
      (id: 'cat_bonus',      name: 'Thưởng',           classify: 'thu',     icon: 'card_giftcard', colour: '#8BC34A'),
      (id: 'cat_freelance',  name: 'Làm thêm',         classify: 'thu',     icon: 'laptop',        colour: '#00BCD4'),
      (id: 'cat_invest',     name: 'Đầu tư',           classify: 'thu',     icon: 'trending_up',   colour: '#009688'),
      (id: 'cat_other_thu',  name: 'Thu khác',         classify: 'thu',     icon: 'more_horiz',    colour: '#4CAF50'),
      // ── Vay / Nợ ──────────────────────────────────────────────────────────
      (id: 'cat_lend',       name: 'Cho vay',          classify: 'vay_no',  icon: 'person_add',    colour: '#FF9800'),
      (id: 'cat_borrow',     name: 'Đi vay',           classify: 'vay_no',  icon: 'person_remove', colour: '#FF5722'),
      (id: 'cat_repay',      name: 'Trả nợ',           classify: 'vay_no',  icon: 'payment',       colour: '#795548'),
      (id: 'cat_collect',    name: 'Thu nợ',           classify: 'vay_no',  icon: 'attach_money',  colour: '#4CAF50'),
    ];

    final companions = defaultCats.map((c) => CategoriesCompanion.insert(
      id: c.id,
      idaccount: 0, // 0 = global default (không thuộc user nào)
      name: c.name,
      classify: c.classify,
      icon: Value(c.icon),
      colour: Value(c.colour),
      isDefault: const Value(true),
      syncStatus: const Value('synced'), // default không cần sync
      updatedAt: now,
    )).toList();

    await categoryDao.upsertAll(companions);
  }
}
