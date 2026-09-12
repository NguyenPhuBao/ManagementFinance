import 'package:drift/drift.dart';
import '../../../features/bill/domain/bill_pay_status.dart';
import '../app_database.dart';
import '../tables/other_tables.dart';

part 'other_daos.g.dart';

// ─── Budget DAO ───────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Future<List<Budget>> getAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<Budget>> watchAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull()))
        .watch();
  }

  Future<Budget?> getById(String id) {
    return (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insert(BudgetsCompanion entry) async {
    await into(budgets).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật một phần: chỉ ghi những cột có mặt trong [entry].
  ///
  /// Cố ý KHÔNG dùng `insert(..., insertOrReplace)` như [insert]: chế độ đó
  /// thay cả hàng nên mọi cột không gán bị đưa về mặc định — chính là cách
  /// cấu trúc nhóm danh mục từng bị xoá sạch sau mỗi lần pull.
  Future<void> updateBudget(String id, BudgetsCompanion entry) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(entry);
  }

  /// Ghi lại số đã chi tính từ bảng giao dịch.
  ///
  /// Cố ý KHÔNG đụng `syncStatus` lẫn `updatedAt`: giá trị này được suy ra từ
  /// dữ liệu đã có sẵn ở local chứ không phải người dùng sửa. Nếu đánh dấu
  /// `pending` ở đây thì mỗi lần mở trang ngân sách lại sinh một thao tác đẩy
  /// mới, và `updatedAt` nhảy lên sẽ khiến LWW cho client thắng oan trước một
  /// thay đổi thật từ máy khác.
  Future<void> updateSpent(String id, double spent) async {
    await (update(budgets)..where((t) => t.id.equals(id)))
        .write(BudgetsCompanion(spent: Value(spent)));
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Chỉ cập nhật cột có trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<BudgetsCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(budgets, entries));
  }

  Future<List<Budget>> getPending([int? idaccount]) {
    return (select(budgets)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      const BudgetsCompanion(
        syncStatus: Value('synced'),
        // Đẩy thành công thì xoá sạch dấu vết thất bại cũ — nếu không, bản ghi
        // vẫn mang syncBlockedUntil của lần hỏng trước và bị chặn oan.
        syncRetryCount: Value(0),
        syncError: Value(null),
        syncBlockedUntil: Value(null),
      ),
    );
  }

  /// Chặn bản ghi khỏi hàng đợi đẩy cho tới [until] sau một lần đẩy thất bại.
  ///
  /// KHÔNG bỏ trạng thái 'pending': hết hạn chặn là bản ghi tự quay lại hàng
  /// đợi. Xem chú thích ở định nghĩa bảng để biết vì sao không dùng
  /// syncStatus = 'failed'.
  Future<void> markSyncBlocked(String id, DateTime until, String error) async {
    final current =
        await (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}

// ─── Bill DAO ─────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Bills])
class BillDao extends DatabaseAccessor<AppDatabase> with _$BillDaoMixin {
  BillDao(super.db);

  Future<List<Bill>> getAll(int idaccount) {
    return (select(bills)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .get();
  }

  Stream<List<Bill>> watchAll(int idaccount) {
    return (select(bills)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch();
  }

  /// Hoá đơn chưa thanh toán tới hạn trong [days] ngày tới — **gồm cả hoá đơn
  /// đã quá hạn**, vì đó chính là thứ đáng nhắc nhất.
  ///
  /// Lọc theo **CẢ HAI** cột trạng thái. `markPaid()` cẩn thận đặt cả hai,
  /// nhưng hàng kéo về từ backend hoặc do bản client cũ ghi có thể lệch: mang
  /// `payStatus = 'Payed'` trong khi `isPaid` còn false. Chỉ lọc một cột là
  /// người dùng bị giục trả một hoá đơn đã thanh toán rồi — không exception,
  /// không log.
  ///
  /// [now] tiêm được để test không phụ thuộc đồng hồ máy.
  Future<List<Bill>> getUpcoming(int idaccount,
      {int days = 7, DateTime? now}) {
    final limit = (now ?? DateTime.now()).add(Duration(days: days));
    return (select(bills)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.isPaid.equals(false) &
              t.payStatus.equals(kBillPayed).not() &
              // Kỳ bỏ qua không phải nợ. Thiếu dòng này thì bộ quét thông báo
              // và bộ đặt lịch cấp hệ điều hành đều lôi nó ra nhắc.
              t.payStatus.equals(kBillSkipped).not() &
              t.dueDate.isSmallerOrEqualValue(limit)))
        .get();
  }

  Future<void> insert(BillsCompanion entry) async {
    await into(bills).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<Bill?> getById(String id) {
    return (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Cập nhật CHỈ những cột có mặt trong [entry].
  ///
  /// Đường sửa **không được** đi qua [insert]: `InsertMode.insertOrReplace`
  /// thay nguyên hàng, nên mọi cột vắng mặt trong companion bị đưa về giá trị
  /// mặc định. Form sửa hoá đơn chỉ gửi lên vài trường, nên nó từng biến hoá
  /// đơn đã thanh toán thành chưa thanh toán, xoá sạch walletId/categoryId
  /// (hai cột NOT NULL phía backend) và hạ cờ isRecurrence.
  Future<void> updateFields(BillsCompanion entry) async {
    if (!entry.id.present) {
      throw ArgumentError('BillsCompanion phải có id để biết cập nhật hàng nào');
    }
    await (update(bills)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Đánh dấu đã thanh toán.
  ///
  /// Phải đặt CẢ HAI cột: nhánh đẩy gửi `pay_status` chứ không gửi `isPaid`,
  /// nên nếu chỉ đặt `isPaid` thì backend vĩnh viễn thấy hoá đơn là 'Pending'
  /// mà không có lỗi nào báo ra.
  Future<void> markPaid(String id) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        isPaid: const Value(true),
        payStatus: const Value('Payed'),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Đồng bộ cờ quá hạn với mốc thời gian — **cả hai chiều**.
  ///
  /// Trả về số hàng thật sự đổi. **Mỗi chiều đều có điều kiện trạng thái**:
  /// quét chạy sau MỌI lần đồng bộ, nên ghi lại vô điều kiện là bản ghi luôn ở
  /// trạng thái `pending` — đẩy lên rồi lại `pending` — một vòng lặp đẩy vô
  /// tận mà không có lỗi nào báo ra.
  ///
  /// So theo NGÀY: hoá đơn đến hạn đúng hôm nay chưa phải quá hạn, người dùng
  /// vẫn còn cả ngày để trả.
  ///
  /// **Chiều ngược lại (`Overdue → Pending`) thêm ngày 2026-09-06.** Trước đó
  /// cờ chỉ đi một chiều, trong khi form Sửa đổi được ngày bắt đầu và hạn trả
  /// tính lại theo chu kỳ — đẩy hạn ra tương lai thì cờ ở lại vĩnh viễn.
  /// `BillDraft.toUpdateCompanion` cố ý không đụng `payStatus` (form không hỏi
  /// gì về nó) nên đường sửa không tự chữa được. Client không lộ ra vì danh
  /// sách tính lại từ `dueDate`, nhưng cột này **có đi đồng bộ** — dữ liệu
  /// thật 06/09 có hai hoá đơn mang `'Overdue'` với hạn ở tương lai.
  ///
  /// Hai lệnh không giẫm lên nhau: hàng vừa nhận `'Overdue'` ở lệnh đầu có
  /// `dueDate < dauNgay` nên không lọt vào bộ lọc của lệnh sau.
  ///
  /// Kỳ `'Skipped'` nằm ngoài **cả hai** chiều, và đó là chủ ý: nó không phải
  /// nợ nên không thể quá hạn, mà cũng không được kéo về `'Pending'`.
  Future<int> markOverdue(int idaccount, DateTime now) async {
    final dauNgay = DateTime(now.year, now.month, now.day);

    final daQuaHan = await (update(bills)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.isPaid.equals(false) &
              t.payStatus.equals(kBillPending) &
              t.dueDate.isSmallerThanValue(dauNgay)))
        .write(BillsCompanion(
      payStatus: const Value('Overdue'),
      syncStatus: const Value('pending'),
      updatedAt: Value(now),
    ));

    final hetQuaHan = await (update(bills)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.isPaid.equals(false) &
              t.payStatus.equals(kBillOverdue) &
              t.dueDate.isBiggerOrEqualValue(dauNgay)))
        .write(BillsCompanion(
      payStatus: const Value('Pending'),
      syncStatus: const Value('pending'),
      updatedAt: Value(now),
    ));

    return daQuaHan + hetQuaHan;
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Kỳ kế tiếp được sinh ra khi trả hoá đơn [billId], nếu còn.
  ///
  /// Dùng cột **cục bộ** `generatedFromBillId` (v16) chứ không so tên và ngày:
  /// so tên là đúng phép so mà cột này sinh ra để thay thế. Trả `null` khi hoá
  /// đơn không lặp, hoặc kỳ ấy đã bị xoá.
  Future<Bill?> getGeneratedFrom(String billId) {
    return (select(bills)
          ..where((t) =>
              t.generatedFromBillId.equals(billId) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Chỉ cập nhật cột có trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<BillsCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(bills, entries));
  }

  Future<List<Bill>> getPending([int? idaccount]) {
    return (select(bills)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      const BillsCompanion(
        syncStatus: Value('synced'),
        // Đẩy thành công thì xoá sạch dấu vết thất bại cũ — nếu không, bản ghi
        // vẫn mang syncBlockedUntil của lần hỏng trước và bị chặn oan.
        syncRetryCount: Value(0),
        syncError: Value(null),
        syncBlockedUntil: Value(null),
      ),
    );
  }

  /// Chặn bản ghi khỏi hàng đợi đẩy cho tới [until] sau một lần đẩy thất bại.
  ///
  /// KHÔNG bỏ trạng thái 'pending': hết hạn chặn là bản ghi tự quay lại hàng
  /// đợi. Xem chú thích ở định nghĩa bảng để biết vì sao không dùng
  /// syncStatus = 'failed'.
  Future<void> markSyncBlocked(String id, DateTime until, String error) async {
    final current =
        await (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}

// ─── Goal DAO ─────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Future<List<Goal>> getAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Future<List<Goal>> getAllNonDeleted() {
    return (select(goals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Stream<List<Goal>> watchAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull()))
        .watch();
  }

  Stream<List<Goal>> watchAllNonDeleted() {
    return (select(goals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .watch();
  }

  Future<Goal?> getById(String id) {
    return (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insert(GoalsCompanion entry) async {
    await into(goals).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateAmount(String id, double newAmount) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        currentAmount: Value(newAmount),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Chỉ cập nhật cột có trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<GoalsCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(goals, entries));
  }

  Future<List<Goal>> getPending([int? idaccount]) {
    return (select(goals)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      const GoalsCompanion(
        syncStatus: Value('synced'),
        // Đẩy thành công thì xoá sạch dấu vết thất bại cũ — nếu không, bản ghi
        // vẫn mang syncBlockedUntil của lần hỏng trước và bị chặn oan.
        syncRetryCount: Value(0),
        syncError: Value(null),
        syncBlockedUntil: Value(null),
      ),
    );
  }
  /// Chặn bản ghi khỏi hàng đợi đẩy cho tới [until] sau một lần đẩy thất bại.
  ///
  /// KHÔNG bỏ trạng thái 'pending': hết hạn chặn là bản ghi tự quay lại hàng
  /// đợi. Xem chú thích ở định nghĩa bảng để biết vì sao không dùng
  /// syncStatus = 'failed'.
  Future<void> markSyncBlocked(String id, DateTime until, String error) async {
    final current =
        await (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}
