import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/wallets_table.dart';

part 'wallet_dao.g.dart';

@DriftAccessor(tables: [Wallets])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Thứ tự hiển thị ví — dùng chung cho MỌI đường đọc danh sách.
  ///
  /// Trước đây là `updatedAt` giảm dần, mà mỗi giao dịch đều bump `updatedAt`
  /// của ví qua [updateBalance] — nên danh sách ví tự xáo lại mỗi lần người
  /// dùng ghi chép. Nút "SẮP XẾP" trên thiết kế Stitch tồn tại đúng vì chỗ này
  /// không có thứ tự nào để giữ.
  ///
  /// Ví mặc định lên đầu (thiết kế vẽ nó ở đầu, kèm nhãn "MẶC ĐỊNH"), rồi tới
  /// tên. `lower()` để tên viết hoa không bị dồn thành một khối riêng: phép so
  /// mặc định của SQLite là nhị phân, 'Z' đứng trước 'v'. Nó chỉ chuẩn hoá chữ
  /// ASCII, nên dấu tiếng Việt vẫn xếp sau — chấp nhận được, cái cần sửa ở đây
  /// là tính ỔN ĐỊNH, không phải chất lượng phép so tiếng Việt.
  ///
  /// Bảng `wallets` không có `createdAt`, nên tên là mốc ổn định duy nhất hiện
  /// có. Cột thứ tự do người dùng kéo thả (nếu làm) chèn vào TRƯỚC hai khoá này.
  List<OrderClauseGenerator<$WalletsTable>> get _thuTuHienThi => [
        (t) => OrderingTerm.desc(t.isDefault),
        (t) => OrderingTerm.asc(t.name.lower()),
      ];

  /// Lấy tất cả ví của user (không xóa mềm)
  Future<List<Wallet>> getAll(int idaccount) {
    return (select(wallets)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy(_thuTuHienThi))
        .get();
  }

  Future<List<Wallet>> getAllNonDeleted() {
    return (select(wallets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Stream tất cả ví của user realtime — dùng trong BlocBuilder
  Stream<List<Wallet>> watchAll(int idaccount) {
    return (select(wallets)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy(_thuTuHienThi))
        .watch();
  }

  /// Lấy ví theo id
  Future<Wallet?> getById(String id) {
    return (select(wallets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Lấy ví mặc định của user.
  ///
  /// Cố ý KHÔNG dùng `getSingleOrNull()` trần: hàm ấy **ném** `StateError` khi
  /// có hơn một hàng, và hai hàng cùng cờ là trạng thái đến được từ server —
  /// `SyncEngine.upsertAll` ghi thẳng, không qua chốt nào của client. Làm nổ
  /// luồng "thêm ví" vì dữ liệu máy khác gửi về là sai. `limit(1)` cộng thứ tự
  /// xác định cho một câu trả lời luôn có: hàng được sửa gần nhất, tức ý định
  /// mới nhất của người dùng.
  Future<Wallet?> getDefault(int idaccount) {
    return (select(wallets)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDefault.equals(true) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Bỏ cờ mặc định của mọi ví khác trong cùng tài khoản, giữ lại [keepId].
  ///
  /// Ba chốt trong `where` đều có việc: `idaccount` để không đụng tài khoản
  /// khác trên cùng máy, `deletedAt.isNull()` để hàng đã xoá mềm không bị đánh
  /// dấu pending vô ích, và `isDefault.equals(true)` để lưu một ví **không**
  /// mặc định không kéo cả bảng về `pending` — mỗi hàng bị chạm là một lần đẩy.
  ///
  /// Đánh `pending` là bắt buộc, không phải cho gọn: xoá cờ mà không vào hàng
  /// đợi thì máy này có một ví mặc định còn máy kia vẫn có hai, vĩnh viễn.
  Future<void> clearDefaultExcept({
    required int idaccount,
    required String keepId,
  }) async {
    await (update(wallets)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.id.equals(keepId).not() &
              t.isDefault.equals(true) &
              t.deletedAt.isNull()))
        .write(WalletsCompanion(
      isDefault: const Value(false),
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Lấy các record chưa sync (pending)
  Future<List<Wallet>> getPending([int? idaccount]) {
    return (select(wallets)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  /// Thêm ví mới — id đã được tạo trước (UUID)
  Future<void> insert(WalletsCompanion entry) async {
    await into(wallets).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật ví
  Future<void> update_(WalletsCompanion entry) async {
    await (update(wallets)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Xoá mềm ví — set deletedAt (DB v2) & isDeleted (backward compat)
  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Đánh dấu đã sync thành công
  Future<void> markSynced(String id) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      const WalletsCompanion(
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
        await (select(wallets)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }

  /// Cập nhật balance sau khi giao dịch
  Future<void> updateBalance(String id, double newBalance) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        balance: Value(newBalance),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Upsert nhiều wallets (dùng khi sync từ server về) — chỉ cập nhật cột có
  /// trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<WalletsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(wallets, entries);
    });
  }
}
