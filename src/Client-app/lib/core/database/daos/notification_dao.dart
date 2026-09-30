import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notification_table.dart';

part 'notification_dao.g.dart';

@DriftAccessor(tables: [AppNotifications])
class NotificationDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationDaoMixin {
  NotificationDao(super.db);

  /// Chèn nếu chưa có. Trả `true` **chỉ khi hàng thật sự được ghi**.
  ///
  /// Giá trị trả về là tín hiệu DUY NHẤT quyết định có bắn thông báo ra hệ điều
  /// hành hay không. Báo nhầm `true` là người dùng nhận lại thông báo cũ mỗi
  /// lần mở app.
  ///
  /// Dùng `insertReturningOrNull` chứ không đọc rowid: với `OR IGNORE`, khi
  /// đụng ràng buộc SQLite không chèn gì và `last_insert_rowid()` giữ nguyên
  /// giá trị của lần chèn TRƯỚC — đọc nó sẽ tưởng là vừa chèn thành công.
  Future<bool> insertIfAbsent(AppNotificationsCompanion entry) async {
    final row = await into(appNotifications)
        .insertReturningOrNull(entry, mode: InsertMode.insertOrIgnore);
    return row != null;
  }

  /// Chèn cả loạt, trả về những companion **thật sự** được ghi.
  Future<List<AppNotificationsCompanion>> insertAllIfAbsent(
    List<AppNotificationsCompanion> entries,
  ) async {
    final moi = <AppNotificationsCompanion>[];
    await transaction(() async {
      for (final e in entries) {
        if (await insertIfAbsent(e)) moi.add(e);
      }
    });
    return moi;
  }

  /// Đường thô — gồm cả hàng đã xoá mềm. Dùng cho khoá trùng và dọn dẹp.
  Future<List<AppNotification>> getAll(int idaccount) {
    return (select(appNotifications)
          ..where((t) => t.idaccount.equals(idaccount)))
        .get();
  }

  /// Danh sách hiển thị: bỏ hàng đã xoá mềm, mới nhất lên trước.
  ///
  /// [kinds] `null` nghĩa là **không lọc** — khác hẳn danh sách rỗng, vốn
  /// nghĩa là không loại nào khớp. Nhận `List<String>` chứ không phải
  /// `NotificationGroup` có chủ ý: DAO nằm ở tầng CSDL, kéo
  /// `notification_prefs.dart` vào đây là buộc tầng lưu trữ phụ thuộc tầng
  /// thông báo. Nơi gọi tự quy đổi nhóm thành danh sách `kind`.
  ///
  /// Cả hai bộ lọc và [limit] phải nằm trong **cùng một câu SQL**. Lọc ở tầng
  /// Dart sau khi đã cắt là bấm "Tải thêm" mãi mà danh sách không dài ra: câu
  /// truy vấn lấy đúng `limit` hàng mới nhất rồi vứt gần hết đi, trong khi
  /// những hàng khớp vẫn nằm nguyên trong bảng.
  Stream<List<AppNotification>> watchFeed(
    int idaccount, {
    int limit = 50,
    List<String>? kinds,
    bool chiChuaDoc = false,
  }) {
    return (select(appNotifications)
          ..where((t) {
            var dieuKien =
                t.idaccount.equals(idaccount) & t.dismissedAt.isNull();
            if (kinds != null) dieuKien = dieuKien & t.kind.isIn(kinds);
            if (chiChuaDoc) dieuKien = dieuKien & t.readAt.isNull();
            return dieuKien;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchUnreadCount(int idaccount) {
    final dem = appNotifications.id.count();
    final q = selectOnly(appNotifications)
      ..addColumns([dem])
      ..where(appNotifications.idaccount.equals(idaccount) &
          appNotifications.readAt.isNull() &
          appNotifications.dismissedAt.isNull());
    return q.map((r) => r.read(dem) ?? 0).watchSingle();
  }

  /// D1 — số hàng biến động số dư CHƯA ghi (chưa gạt) của tài khoản: con số trên thẻ *"Có N biến động chưa ghi"* ở
  /// Sổ giao dịch. Stream, nên Lưu / Bỏ qua (xoá cứng) tự làm con số đổi.
  Stream<int> watchDemBienDong(int idaccount) {
    final dem = appNotifications.id.count();
    final q = selectOnly(appNotifications)
      ..addColumns([dem])
      ..where(appNotifications.idaccount.equals(idaccount) &
          appNotifications.kind.equals(kKindBienDongSoDu) &
          appNotifications.dismissedAt.isNull());
    return q.map((r) => r.read(dem) ?? 0).watchSingle();
  }

  Future<void> markRead(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(readAt: Value(DateTime.now())));
  }

  /// Khoá của mọi hàng chưa đọc **đang hiện** (chưa gạt bỏ) — nhật ký B5a ghi một
  /// `doc_tat_ca` cho mỗi khoá khi người dùng bấm "Đọc tất cả".
  ///
  /// ⚠️ Không đúng bằng tập của [markAllRead]: hàm ấy đánh dấu cả hàng đã gạt bỏ
  /// mà chưa đọc. Hàng đã gạt không còn trên màn, nên cú bấm không phải phản ứng
  /// với nó — ghi nó vào nhật ký là dạy B5b một phản ứng không có thật.
  Future<List<String>> khoaChuaDoc(int idaccount) async {
    final rows = await (select(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.readAt.isNull() &
              t.dismissedAt.isNull()))
        .get();
    return [for (final r in rows) r.dedupeKey];
  }

  /// Ghi mốc đã giao thông báo cho hệ điều hành (lúc quyền đang bật). B5a: cột
  /// này có từ v13 mà chưa từng được ghi.
  Future<void> danhDauDaBan(int idaccount, String dedupeKey, DateTime luc) async {
    await (update(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.dedupeKey.equals(dedupeKey)))
        .write(AppNotificationsCompanion(osDeliveredAt: Value(luc)));
  }

  /// Tài khoản có hàng nào mang khoá này không (kể cả hàng đã xoá mềm) — bộ
  /// nhập hàng chờ B5a dùng để biết một cú Hoãn thuộc về ai.
  Future<bool> coDedupeKey(int idaccount, String dedupeKey) async {
    final r = await (select(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.dedupeKey.equals(dedupeKey))
          ..limit(1))
        .getSingleOrNull();
    return r != null;
  }

  Future<void> markAllRead(int idaccount) async {
    await (update(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.readAt.isNull()))
        .write(AppNotificationsCompanion(readAt: Value(DateTime.now())));
  }

  /// Gỡ cờ đã đọc — đối xứng với [markRead].
  ///
  /// Cần thiết vì "Đọc tất cả" đọc hộ **cả** những mục người dùng chưa kịp
  /// xem: không có đường quay lại thì một cú bấm nhầm xoá sạch dấu vết những
  /// gì còn phải xử lý, và chuông trên Home tụt về 0 trong khi việc vẫn còn đó.
  Future<void> markUnread(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(const AppNotificationsCompanion(readAt: Value(null)));
  }

  /// Xoá mềm. Xem chú thích cột `dismissedAt` để biết vì sao không DELETE.
  Future<void> dismiss(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(dismissedAt: Value(DateTime.now())));
  }

  /// Gỡ cờ xoá mềm — đường quay lại cho một cú vuốt lỡ tay.
  ///
  /// Cần thiết vì hàng đã xoá **vẫn nằm trong bảng** để chặn trùng: lượt quét
  /// sau nhìn thấy `dedupeKey` ấy và bỏ qua, nên nếu không có hàm này thì một
  /// cú vuốt nhầm làm thông báo biến mất khỏi giao diện **vĩnh viễn**.
  Future<void> khoiPhuc(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(const AppNotificationsCompanion(dismissedAt: Value(null)));
  }

  /// Dọn hàng cũ. Bảng này chỉ lớn lên — hàng đã xoá mềm phải giữ để chặn
  /// trùng — nên không dọn thì sau một năm màn danh sách tải hàng nghìn hàng.
  /// An toàn vì mọi `dedupeKey` đều đã hết hạn từ lâu trước mốc cắt.
  Future<int> purgeOlderThan(DateTime cutoff) {
    return (delete(appNotifications)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Dọn riêng MỘT loại theo mốc ngắn hơn [purgeOlderThan] — hàng biến động số dư
  /// (D1) mang nội dung tin ngân hàng nên chỉ giữ 30 ngày (spec D1 §3.3), trong
  /// khi mọi loại khác giữ 90.
  Future<int> purgeKindOlderThan(String kind, DateTime cutoff) {
    return (delete(appNotifications)
          ..where((t) => t.kind.equals(kind) & t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Xoá **CỨNG** một hàng biến động số dư (D1) khi người dùng *Lưu* hoặc *Bỏ qua* nó trên form.
  ///
  /// ⚠️ **Ngoại lệ có chủ ý** của nếp *"dismiss mềm để giữ khoá chặn trùng"* (spec D1 §3.3): hàng loại
  /// 20 mang nội dung tin ngân hàng, tin đã xử lý thì không còn lý do giữ nó (Nghị định 13, tối thiểu
  /// hoá). Chống trùng về sau dựa vào phép gộp 5 phút của `NhapBienDong`, đủ vì nguồn chỉ bắn lại ngay.
  /// Chỉ xoá hàng mang đúng loại [kKindBienDongSoDu] — mọi loại khác vẫn phải xoá mềm, nên hàm không
  /// tin vào khoá một mình. Trả số hàng đã xoá.
  Future<int> xoaCung(int idaccount, String dedupeKey) {
    return (delete(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.dedupeKey.equals(dedupeKey) &
              t.kind.equals(kKindBienDongSoDu)))
        .go();
  }
}

/// `NotificationKind.bienDongSoDu.name` — chép thành chuỗi vì tầng CSDL không phụ thuộc tầng thông
/// báo (xem [NotificationDao.watchFeed]); `notification_dao_test.dart` canh hai bên bằng nhau.
const String kKindBienDongSoDu = 'bienDongSoDu';
