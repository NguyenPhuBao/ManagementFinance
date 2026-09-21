import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Lấy tất cả giao dịch của user (mới nhất trước)
  Future<List<Transaction>> getAll(int idaccount) {
    return (select(transactions)
          ..where(
              (t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Mốc của giao dịch **gần nhất**, `null` khi tài khoản chưa có giao dịch nào.
  ///
  /// Đầu vào duy nhất của lời nhắc ghi chép hằng ngày trong `ReminderScheduler`
  /// — loại nhắc duy nhất trong app suy từ việc **không có** dữ liệu. `null`
  /// phải đọc thành *cần nhắc*: người mới cài app chính là người cần nhắc nhất.
  ///
  /// Dùng `MAX` chứ không `getAll().first`: hàm kia nạp cả bảng về Dart chỉ để
  /// đọc một mốc, và trang này chạy ở mỗi lượt `resync()`.
  ///
  /// ⚠️ Đếm **mọi** hàng, kể cả giao dịch do bộ tự trả hoá đơn và bộ trích mục
  /// tiêu sinh ra. Nghĩa là có hôm app tự tạo giao dịch và lời nhắc bị bỏ qua
  /// oan. Chấp nhận có chủ ý: lọc theo `billId`/`goalId` sai theo chiều tệ hơn
  /// vì trả hoá đơn **bằng tay** cũng đặt `billId`, và đây là một lời nhắc chứ
  /// không phải một phép kiểm toán.
  Future<DateTime?> getLastTransactionDate(int idaccount) async {
    final moc = transactions.date.max();
    final q = selectOnly(transactions)
      ..addColumns([moc])
      ..where(transactions.idaccount.equals(idaccount) &
          transactions.deletedAt.isNull());
    return (await q.getSingle()).read(moc);
  }

  /// Stream theo dõi realtime theo idaccount
  Stream<List<Transaction>> watchAll(int idaccount) {
    return (select(transactions)
          ..where(
              (t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream tất cả giao dịch chưa xóa realtime (dùng cho fallback/Home)
  Stream<List<Transaction>> watchAllNonDeleted() {
    return (select(transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream giao dịch theo pattern ghi chú (dùng cho Mục tiêu tiết kiệm)
  /// Lịch sử tích luỹ của MỘT mục tiêu.
  ///
  /// Nối bằng [goalId] cho hàng mới, và giữ nhánh tra theo ghi chú cho hàng cũ
  /// — hàng do bản app trước tạo, và mọi hàng kéo về từ server (cột `goalId` là
  /// cục bộ nên server không bao giờ trả nó về).
  ///
  /// Nhánh ghi chú vẫn mang khuyết điểm cũ: nó là `LIKE` trên tên nên mục tiêu
  /// tên "Mua" còn khớp ghi chú của "Mua xe". Giữ lại vì mất lịch sử đã có còn
  /// tệ hơn; khuyết điểm ấy **tắt dần** theo thời gian vì mọi khoản nạp mới đều
  /// mang `goalId`. Điều kiện `goalId IS NULL` ở nhánh này là thứ chặn không
  /// cho một hàng đã có chủ bị mục tiêu khác nhận vơ.
  Stream<List<Transaction>> watchByGoal(
    int idaccount,
    String goalId,
    String goalName,
  ) {
    final pattern = 'Tích lũy mục tiêu: $goalName';
    return (select(transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.idaccount.equals(idaccount) &
              (t.goalId.equals(goalId) |
                  (t.goalId.isNull() & t.note.like('%$pattern%'))))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<List<Transaction>> watchByNotePattern(int idaccount, String pattern) {
    return (select(transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.idaccount.equals(idaccount) &
              t.note.like('%$pattern%'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Lọc theo ví — **chỉ ví NGUỒN**, tức cột `walletId`.
  ///
  /// ⚠️ Cố ý không đếm khoản chuyển *đến* ví này: chúng nằm ở cột
  /// `walletTransfer`. Chỗ nào cần câu hỏi "ví này có dính giao dịch nào không"
  /// thì dùng [demGiaoDichLienQuan]; nhầm hai hàm là chỗ đã sinh ra một lỗ hổng
  /// thật (xem chú thích của hàm ấy).
  Future<List<Transaction>> getByWallet(String walletId) {
    return (select(transactions)
          ..where(
              (t) => t.walletId.equals(walletId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Số giao dịch còn sống **dính tới** [walletId] theo bất kỳ vai nào: ví
  /// nguồn (`walletId`) **hoặc** ví đích của khoản chuyển (`walletTransfer`).
  ///
  /// Sinh ra ngày 2026-09-18 cho chốt xoá ví. Trước đó chốt ấy hỏi qua
  /// [getByWallet], hàm chỉ nhìn cột `walletId` — nên một ví **chỉ nhận tiền
  /// chuyển vào**, chưa từng chi gì, bị coi là "chưa có giao dịch" và **xoá
  /// được**. Điều đó đi ngược chính lời hứa "bảo toàn lịch sử tài chính" mà
  /// thông báo của chốt ấy nói ra, và hỏng **im lặng**: ví biến mất, còn khoản
  /// chuyển thì ở lại trỏ vào một ví không còn trong danh sách nào.
  ///
  /// Đếm chứ không trả danh sách: chỗ gọi chỉ cần biết *có hay không*, và một
  /// ví dùng lâu năm có thể mang hàng nghìn hàng.
  Future<int> demGiaoDichLienQuan(String walletId) async {
    final bien = countAll();
    final q = selectOnly(transactions)
      ..addColumns([bien])
      ..where((transactions.walletId.equals(walletId) |
              transactions.walletTransfer.equals(walletId)) &
          transactions.deletedAt.isNull());
    final row = await q.getSingle();
    return row.read(bien) ?? 0;
  }

  /// Lọc theo khoảng thời gian
  Future<List<Transaction>> getByDateRange(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Lọc theo tháng (dùng cho trang Home và Analytics)
  Future<List<Transaction>> getByMonth(int idaccount, int year, int month) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    return getByDateRange(idaccount, from, to);
  }

  /// Stream giao dịch của một tài khoản trong khoảng `[from, to)`, mới nhất
  /// trước.
  ///
  /// ⚠️ Biên `to` **MỞ**, cùng quy ước với `tuanTruoc` và `tongThuChi` ngay dưới
  /// đây. Hàm này **thay** `watchByMonth` ngày 2026-09-21, khi trang Sổ giao
  /// dịch bỏ phép buộc-theo-tháng để xem được theo tuần/quý/năm/khoảng tuỳ chọn.
  ///
  /// Bản cũ dùng biên ĐÓNG (`isSmallerOrEqualValue` với `to` đặt ở 23:59:59
  /// ngày cuối tháng). Giữ lại cả hai là để **hai quy ước biên** sống chung
  /// trong một DAO, và khi ấy một khoản ghi đúng mốc giao giữa hai kỳ bị đếm
  /// vào **cả hai** — không exception, chỉ là một con số lớn hơn thực tế.
  Stream<List<Transaction>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Khoảng `[from, to)` có giao dịch nào không.
  ///
  /// Trả **bool** chứ không phải tổng: thông báo Tổng kết tuần cố ý không nêu
  /// số nào, nên nó chỉ cần biết có hay không. Viết sẵn một hàm tính tổng khi
  /// chưa ai dùng đến là thêm một thứ phải giữ đúng mà không ai kiểm.
  ///
  /// Biên `to` **mở**, cùng quy ước với `tuanTruoc` và `tongThuChi`: lấy biên
  /// đóng thì một khoản ghi đúng nửa đêm bị đếm vào hai tuần.
  ///
  /// `limit(1)` chứ không `count()`: câu hỏi là "có hay không", và một tuần
  /// bận rộn không đáng phải đếm hết.
  Future<bool> coGiaoDichTrongKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) async {
    final hang = await (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to))
          ..limit(1))
        .getSingleOrNull();
    return hang != null;
  }

  /// Mọi khoản **chi** còn sống từ [from] trở đi — đầu vào của luật "Khoản chi
  /// lớn" (#7, 2026-09-17).
  ///
  /// Không lọc theo số tiền ở đây: ngưỡng là tuỳ chọn của người dùng và luật
  /// sống ở tầng thuần, nên đưa nó xuống SQL là chẻ một luật ra làm hai nơi.
  /// Cửa sổ [from] mới là thứ giữ cho câu này rẻ — nơi gọi truyền đúng
  /// `cuaSoSuKien` 30 ngày.
  ///
  /// `type = 'chi'` lọc sẵn được vì nó là cột; ba luật loại trừ còn lại (khoản
  /// chuyển, điều chỉnh số dư, mở sổ) **cố ý để bộ luật lo** qua
  /// `khoanVaoThongKe` — chúng có một định nghĩa duy nhất và nó không nằm ở
  /// tầng này.
  Future<List<Transaction>> getChiTuNgay(int idaccount, DateTime from) {
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.deletedAt.isNull() &
              t.type.equals('chi') &
              t.date.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Tổng thu/chi theo tháng
  Future<Map<String, double>> getSummaryByMonth(
    int idaccount,
    int year,
    int month,
  ) async {
    final list = await getByMonth(idaccount, year, month);
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.type == 'thu') {
        income += t.amount;
      } else if (t.type == 'chi') {
        expense += t.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  /// Pending sync records
  Future<List<Transaction>> getPending([int? idaccount]) {
    return (select(transactions)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null
                  ? const Constant(true)
                  : t.idaccount.equals(idaccount))))
        .get();
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  /// Khoản chi sinh ra khi trả hoá đơn [billId], nếu còn.
  ///
  /// Dùng cột **cục bộ** `billId` (v16) chứ không dò tiền tố ghi chú: người
  /// dùng gõ trùng tiền tố là hoàn nhầm tiền vào ví bằng một khoản chi khác
  /// của chính họ. Trả `null` với khoản trả ghi bằng bản app trước 2026-09-06
  /// — nơi gọi phải từ chối hoàn tác chứ không được đoán.
  Future<Transaction?> getByBill(String billId) {
    return (select(transactions)
          ..where((t) => t.billId.equals(billId) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Tra giao dịch theo id, **kể cả hàng đã xoá mềm**.
  ///
  /// Ngược chiều với [getByBill]: nơi gọi cầm id **khoản chi** và muốn tìm hoá
  /// đơn của nó. `BillPaymentConflictResolver` cần đúng chiều này — server trả
  /// về `localId` của thao tác bị từ chối, chứ không trả `billId`.
  ///
  /// ⚠️ Cố ý **không** lọc `deletedAt` như [getByBill]: tới lúc resolver chạy,
  /// một chu kỳ đồng bộ trước đó có thể đã gỡ khoản chi rồi. Lọc sẵn là trả
  /// `null`, resolver coi như "không có gì để làm" và **bỏ qua im lặng** một ca
  /// đáng xử — trong khi hai bản ghi vẫn còn kẹt hàng đợi đẩy.
  Future<Transaction?> getById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Mọi khoản trả hoá đơn còn sống của [idaccount], theo `billId`.
  ///
  /// Một truy vấn cho cả trang hoá đơn thay vì gọi [getByBill] cho từng dòng.
  /// Hoá đơn kéo về từ server không có mục ở đây (cột `billId` cục bộ) — nơi
  /// gọi phải coi đó là "không biết ngày trả", không được đoán.
  Future<Map<String, Transaction>> getBillPayments(int idaccount) async {
    final rows = await (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.billId.isNotNull() &
              t.deletedAt.isNull()))
        .get();
    return {for (final t in rows) t.billId!: t};
  }

  /// Tổng mọi giao dịch còn sống của ví [walletId] — **công thức số dư**.
  ///
  /// ```
  /// balance(w) = Σ thu(w) − Σ chi(w) − Σ transfer TỪ w + Σ transfer ĐẾN w
  /// ```
  ///
  /// Luật lấy **nguyên văn** từ `TransactionRepository._applyBalances`, kể cả
  /// ngoại lệ của nó: khoản `transfer` **không có ví đích** thì không tính bên
  /// nào — *"đừng trừ một nửa"*. Lệch khỏi luật ấy là số dư tính lại khác số dư
  /// từng cộng dồn, và không gì báo ra.
  ///
  /// Khoản **mở sổ** nằm trong tổng này như một giao dịch bình thường — đó
  /// chính là vai trò của nó; xem `wallet/domain/so_du_mo_so.dart`.
  ///
  /// Vì sao gom trong Dart chứ không `SUM` bằng SQL: ba vế trên có ba điều kiện
  /// khác nhau trên cùng một hàng (`walletId` với `thu`/`chi`, cả `walletId` lẫn
  /// `walletTransfer` với `transfer`), nên một câu `SUM` phải là ba câu con cộng
  /// lại — dài hơn, và chỗ nào sai thì im lặng. Cỡ dữ liệu của app này là vài
  /// chục tới vài nghìn hàng mỗi ví.
  Future<double> tongTheoVi(String walletId) async {
    final rows = await (select(transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              (t.walletId.equals(walletId) |
                  t.walletTransfer.equals(walletId))))
        .get();

    var tong = 0.0;
    for (final t in rows) {
      switch (t.type) {
        case 'thu':
          if (t.walletId == walletId) tong += t.amount;
        case 'chi':
          if (t.walletId == walletId) tong -= t.amount;
        case 'transfer':
          if (t.walletTransfer == null) continue;
          if (t.walletId == walletId) tong -= t.amount;
          if (t.walletTransfer == walletId) tong += t.amount;
      }
    }
    return tong;
  }

  Future<void> insert(TransactionsCompanion entry) async {
    await into(transactions).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Ghi đè các cột có trong [values] cho hàng [id]. Nơi gọi tự đặt
  /// `syncStatus`/`updatedAt` — DAO không đoán ý (repair có lúc không muốn
  /// đổi mốc).
  Future<void> updateRow(String id, TransactionsCompanion values) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(values);
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markSynced(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(
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
        await (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }

  /// Ghi dữ liệu pull về — chỉ cập nhật cột có trong companion (xem chú thích
  /// ở CategoryDao.upsertAll). Tránh việc pull xoá mất walletTransfer,
  /// bankTranId, status, provider, images... vì mapper pull không gán chúng.
  Future<void> upsertAll(List<TransactionsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(transactions, entries);
    });
  }

  /// Cập nhật categoryId của transaction (dùng khi repair cat_food → UUID)
  Future<void> updateCategoryId(String transactionId, String? newCategoryId) async {
    await (update(transactions)..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        categoryId: Value(newCategoryId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Repair: cập nhật categoryId từ local seed (cat_food) sang UUID từ backend,
  /// sau đó mark pending để re-push.
  ///
  /// Truyền vào [resolveUuid]: hàm async nhận categoryId cũ → trả về UUID hợp lệ (hoặc null).
  /// Gọi sau khi categories được pull về đầy đủ từ backend.
  Future<int> repairPendingTransactionsCategoryId(
    Future<String?> Function(String? categoryId) resolveUuid,
  ) async {
    // Lấy tất cả PENDING transactions có categoryId dạng non-UUID (local seed)
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final pending = await (select(transactions)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              t.categoryId.isNotNull() &
              t.deletedAt.isNull()))
        .get();

    int repaired = 0;
    for (final tx in pending) {
      if (tx.categoryId == null) continue;
      if (uuidRegex.hasMatch(tx.categoryId!)) continue; // đã là UUID → bỏ qua
      // categoryId là dạng 'cat_food' → resolve sang UUID
      final uuid = await resolveUuid(tx.categoryId);
      if (uuid == null) continue;
      await updateCategoryId(tx.id, uuid);
      repaired++;
    }
    return repaired;
  }
}
