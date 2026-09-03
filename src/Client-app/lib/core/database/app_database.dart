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
  int get schemaVersion => 11;

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
          // `remaining` và `percent_spent` từng được thêm ở bước này. Bỏ đi vì
          // v11 xoá hẳn hai cột đó — thêm rồi xoá ngay trong cùng một lượt nâng
          // cấp là việc thừa, và giữ lại thì mã không biên dịch được nữa (lớp
          // `Budgets` không còn getter tương ứng).
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
        if (from < 8) {
          // Bản app trước 2026-09-02 đánh dấu nhóm danh mục và các danh mục
          // nằm trong nhóm là `is_local_only = 1`, vì hồi đó cấu trúc nhóm chỉ
          // tồn tại ở client. Nay hai chiều đã đồng bộ được (isGroup/parentId),
          // nhưng bộ lọc trong `getSyncableCategories` vẫn loại các hàng đó
          // khỏi batch đẩy — nghĩa là nhóm tạo TRƯỚC ngày đó không bao giờ lên
          // được backend, và hỏng hoàn toàn im lặng.
          //
          // An toàn vì không còn nơi nào trong `lib/` ghi is_local_only = 1:
          // cột mặc định là 0 và CategoryManagementRepository ghi thẳng false.
          // Chỉ đụng đúng những hàng mang cờ cũ, không đánh dấu pending tràn lan.
          await customStatement(
            "UPDATE categories SET is_local_only = 0, sync_status = 'pending' "
            "WHERE is_local_only = 1",
          );
        }
        if (from < 9) {
          // Trạng thái thất bại theo từng bản ghi (G3). Trước đây lược đồ chỉ
          // có `syncStatus` với đúng hai giá trị được ghi trong thực tế là
          // 'pending' và 'synced', nên một bản ghi hỏng vĩnh viễn nằm ở
          // 'pending' MÃI MÃI và được gửi lại ở mọi chu kỳ.
          //
          // Viết tường minh từng bảng thay vì lặp qua danh sách: các lớp bảng
          // Drift không có siêu kiểu chung mang các getter cột này.
          await m.addColumn(categories, categories.syncRetryCount);
          await m.addColumn(categories, categories.syncError);
          await m.addColumn(categories, categories.syncBlockedUntil);

          await m.addColumn(wallets, wallets.syncRetryCount);
          await m.addColumn(wallets, wallets.syncError);
          await m.addColumn(wallets, wallets.syncBlockedUntil);

          await m.addColumn(transactions, transactions.syncRetryCount);
          await m.addColumn(transactions, transactions.syncError);
          await m.addColumn(transactions, transactions.syncBlockedUntil);

          await m.addColumn(budgets, budgets.syncRetryCount);
          await m.addColumn(budgets, budgets.syncError);
          await m.addColumn(budgets, budgets.syncBlockedUntil);

          await m.addColumn(bills, bills.syncRetryCount);
          await m.addColumn(bills, bills.syncError);
          await m.addColumn(bills, bills.syncBlockedUntil);

          await m.addColumn(goals, goals.syncRetryCount);
          await m.addColumn(goals, goals.syncError);
          await m.addColumn(goals, goals.syncBlockedUntil);
        }
        if (from < 10) {
          // Bộ danh mục mặc định hai phía từng lệch nhau: client seed 18 mục,
          // backend chỉ có 13, và chỉ 10 mục KHỚP TÊN. Danh mục mặc định được
          // ánh xạ sang UUID của backend bằng cách so tên, nên 8 mục lệch kia
          // không tìm được bản nào — giao dịch dùng chúng bị hoãn đẩy VĨNH VIỄN
          // mà không có lỗi nào báo ra.
          //
          // Ba mục dưới đây chỉ khác NHÃN, cùng một khái niệm → đổi tên theo
          // backend là chúng tự gộp làm một khi pull về. KHÔNG xoá hàng: xoá
          // hàng seed trước khi giao dịch được repoint chính là lỗi 11.6.
          await customStatement(
            "UPDATE categories SET name = 'Y tế' "
            "WHERE id = 'cat_health' AND is_default = 1",
          );
          await customStatement(
            "UPDATE categories SET name = 'Nhà cửa' "
            "WHERE id = 'cat_housing' AND is_default = 1",
          );
          await customStatement(
            "UPDATE categories SET name = 'Hóa đơn' "
            "WHERE id = 'cat_bill_chi' AND is_default = 1",
          );
          // Năm mục backend KHÔNG có (Chi khác, Thu khác, Làm thêm, Trả nợ,
          // Thu nợ) được chuyển thành danh mục riêng của tài khoản — việc đó
          // cần biết idaccount nên phải làm lúc đăng nhập, xem
          // `PersonalDefaultCategories.ensureForAccount()`.
        }
        if (from < 11) {
          // Bảng `budgets` lệch với backend theo cả hai chiều:
          //
          // THIẾU `threshold_warning_percent` — backend có cột này từ đợt DB v2
          // nhưng client thì không, nên ngưỡng cảnh báo theo phần trăm không
          // bao giờ sang được máy khác. Trước v11 phía client dùng cứng 90%.
          //
          // THỪA `remaining`, `percent_spent`, `period` — ba cột backend KHÔNG
          // có. Hai cột đầu chỉ là amount - spent và spent / amount; lưu lại
          // tạo thêm một bản sao có thể lệch mà chẳng ai đọc. `period`
          // ('monthly'/'weekly'/...) đã bị `time_recurrence`
          // ('Month'/'Week'/...) thay thế hoàn toàn từ DB v2.
          //
          // Dùng `alterTable` thay vì `ALTER TABLE ... DROP COLUMN`: cú pháp đó
          // chỉ có từ SQLite 3.35, mà phiên bản đi kèm thì khác nhau giữa
          // Android, iOS và web. Drift dựng lại bảng theo lược đồ hiện tại rồi
          // chép dữ liệu sang, nên cột không còn trong lược đồ tự biến mất.
          //
          // `newColumns` là bắt buộc với cột MỚI: thiếu nó Drift sẽ đi tìm
          // `threshold_warning_percent` trong bảng cũ và câu SELECT sẽ hỏng.
          await m.alterTable(TableMigration(
            budgets,
            newColumns: [budgets.thresholdWarningPercent],
          ));
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

  // ── Dọn dữ liệu của các tài khoản khác ────────────────────────────────────

  /// Xoá mọi dòng dữ liệu KHÔNG thuộc [keepIdaccount] khỏi SQLite cục bộ.
  ///
  /// Vì sao cần: dữ liệu sót lại của một tài khoản cũ trên cùng thiết bị là
  /// dữ liệu chết — mọi truy vấn `getPending`/`getSyncableCategories` đều lọc
  /// theo tài khoản hiện tại nên chúng không bao giờ được đẩy lên nữa, nhưng
  /// chúng vẫn có thể bị đọc nhầm (ví dụ các truy vấn `*NonDeleted` không lọc
  /// tài khoản) và làm sống lại một `idaccount` đã chết.
  ///
  /// GIỮ NGUYÊN danh mục mặc định (`idaccount = 0`) — đó là dữ liệu dùng chung,
  /// không thuộc tài khoản nào.
  ///
  /// Xoá bảng con trước bảng cha vì `beforeOpen` bật `PRAGMA foreign_keys = ON`.
  Future<int> purgeDataForOtherAccounts(int keepIdaccount) async {
    if (keepIdaccount <= 0) return 0;
    var removed = 0;
    await transaction(() async {
      removed += await (delete(categoryKeywords)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      removed += await (delete(categoryGroupMemberships)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      removed += await (delete(transactions)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      removed += await (delete(budgets)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      removed += await (delete(bills)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      removed += await (delete(goals)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
      // idaccount = 0 là danh mục mặc định dùng chung → giữ lại.
      removed += await (delete(categories)
            ..where((t) =>
                t.idaccount.equals(keepIdaccount).not() &
                t.idaccount.equals(0).not()))
          .go();
      removed += await (delete(wallets)
            ..where((t) => t.idaccount.equals(keepIdaccount).not()))
          .go();
    });
    return removed;
  }

  /// Chuyển mọi tham chiếu danh mục của [idaccount] từ [fromCategoryId] sang
  /// [toCategoryId], ở cả ba bảng có cột `categoryId`.
  ///
  /// Trả về số dòng đã đổi.
  ///
  /// ⚠️ Nơi gọi PHẢI repoint XONG rồi mới xoá hàng danh mục cũ. Đảo thứ tự lại
  /// chính là lỗi 11.6: hàng `cat_food` bị xoá trước khiến `getById()` trả null
  /// và giao dịch kẹt vĩnh viễn.
  Future<int> repointCategoryReferences({
    required int idaccount,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    var moved = 0;
    await transaction(() async {
      moved += await (update(transactions)
            ..where((t) =>
                t.idaccount.equals(idaccount) &
                t.categoryId.equals(fromCategoryId)))
          .write(TransactionsCompanion(
        categoryId: Value(toCategoryId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));
      moved += await (update(budgets)
            ..where((t) =>
                t.idaccount.equals(idaccount) &
                t.categoryId.equals(fromCategoryId)))
          .write(BudgetsCompanion(
        categoryId: Value(toCategoryId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));
      moved += await (update(bills)
            ..where((t) =>
                t.idaccount.equals(idaccount) &
                t.categoryId.equals(fromCategoryId)))
          .write(BillsCompanion(
        categoryId: Value(toCategoryId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));
    });
    return moved;
  }

  // ── Seed default categories ───────────────────────────────────────────────
  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now();
    const defaultCats = [
      // ── Chi tiêu ──────────────────────────────────────────────────────────
      (id: 'cat_food',       name: 'Ăn uống',         classify: 'chi',     icon: 'restaurant',   colour: '#FF5722'),
      (id: 'cat_transport',  name: 'Di chuyển',        classify: 'chi',     icon: 'directions_car', colour: '#2196F3'),
      (id: 'cat_shopping',   name: 'Mua sắm',          classify: 'chi',     icon: 'shopping_bag',  colour: '#9C27B0'),
      (id: 'cat_health',     name: 'Y tế',             classify: 'chi',     icon: 'local_hospital', colour: '#F44336'),
      (id: 'cat_education',  name: 'Giáo dục',         classify: 'chi',     icon: 'school',        colour: '#3F51B5'),
      (id: 'cat_entertain',  name: 'Giải trí',         classify: 'chi',     icon: 'sports_esports', colour: '#E91E63'),
      (id: 'cat_housing',    name: 'Nhà cửa',          classify: 'chi',     icon: 'home',          colour: '#607D8B'),
      (id: 'cat_bill_chi',   name: 'Hóa đơn',          classify: 'chi',     icon: 'receipt',       colour: '#795548'),
      // ── Thu nhập ──────────────────────────────────────────────────────────
      (id: 'cat_salary',     name: 'Lương',            classify: 'thu',     icon: 'work',          colour: '#4CAF50'),
      (id: 'cat_bonus',      name: 'Thưởng',           classify: 'thu',     icon: 'card_giftcard', colour: '#8BC34A'),
      (id: 'cat_invest',     name: 'Đầu tư',           classify: 'thu',     icon: 'trending_up',   colour: '#009688'),
      // ── Vay / Nợ ──────────────────────────────────────────────────────────
      (id: 'cat_lend',       name: 'Cho vay',          classify: 'vay_no',  icon: 'person_add',    colour: '#FF9800'),
      (id: 'cat_borrow',     name: 'Đi vay',           classify: 'vay_no',  icon: 'person_remove', colour: '#FF5722'),
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
