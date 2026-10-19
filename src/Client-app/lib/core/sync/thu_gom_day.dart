/// Gom mọi bản ghi `pending` thành lô thao tác đẩy, đúng thứ tự khoá ngoại — tách khỏi `SyncEngine` 2026-10-19 (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`). Thân dời nguyên văn.
library;

import 'package:flutter/foundation.dart' hide Category;

import '../../features/goal/domain/uu_tien_hop_le.dart';
import '../database/app_database.dart';
import 'cong_vi_bi_giu.dart';
import 'sync_models.dart';
import 'uuid_dong_bo.dart';

/// Nửa đêm UTC của ngày CỤC BỘ của [d] — cho cột `@db.Date` trên server.
///
/// `d.toUtc()` của 03:00 giờ +07 là 20:00 UTC hôm trước; PostgreSQL cắt giờ
/// và giữ lại ngày sai. Chỉ dùng cho cột ngày-không-giờ (hiện là
/// `bill.Period_end`); cột timestamp vẫn gửi `toUtc()` như cũ.
String? _ngayCucBoUtcIso(DateTime? d) =>
    d == null ? null : DateTime.utc(d.year, d.month, d.day).toIso8601String();

/// Chỉ `SyncEngine` dựng lớp này. Hai thứ của engine đọc **qua hàm**, không chụp giá trị: [_now] (đồng hồ tiêm được) và
/// [_taiKhoanPhien] (`syncMotLuot` đặt rồi trả lại tài khoản phiên quanh một lượt — chụp lúc dựng là đọc `null`).
class ThuGomThaoTacDay {
  ThuGomThaoTacDay({
    required AppDatabase db,
    required CongViBiGiu viBiGiu,
    required DateTime Function() now,
    required int? Function() taiKhoanPhien,
  })  : _db = db,
        _viBiGiu = viBiGiu,
        _now = now,
        _taiKhoanPhien = taiKhoanPhien;

  final AppDatabase _db;

  /// Ví nào đang bị giữ vì trùng tên (G63) — qua cổng, bản thật `ViBiGiuDongBo` (`features/wallet/data/`). Engine KHÔNG đọc
  /// cột cờ trực tiếp — test quét `vi_trung_ten_cuc_bo_test` canh tên cột không xuất hiện ở tệp này.
  final CongViBiGiu _viBiGiu;

  final DateTime Function() _now;
  final int? Function() _taiKhoanPhien;

  /// Bản ghi có đang bị chặn khỏi hàng đợi đẩy không (G3).
  ///
  /// Chặn theo THỜI GIAN chứ không loại hẳn: nhiều lỗi chỉ tự khỏi sau khi Pull
  /// xong, nên một bản ghi bị gạt vĩnh viễn sẽ không bao giờ được sửa.
  bool _isSyncBlocked(DateTime? blockedUntil) =>
      blockedUntil != null && _now().isBefore(blockedUntil);

  // ── Collect pending operations ────────────────────────────────────────────

  Future<List<SyncOperation>> collectPendingOps(int idaccount) async {
    final ops = <SyncOperation>[];
    final now = DateTime.now();

    // ── 0. Bản ghi bị GIỮ vì ví trùng tên (G63) ───────────────────────────────
    // Ví mà server từ chối vì trùng tên với một ví đã kéo về thì CHƯA lên được
    // server, và mọi thứ trỏ vào nó vỡ khoá ngoại. Gửi chúng là vòng lặp lỗi ở
    // mọi chu kỳ, kéo chậm cả dữ liệu khác — nên giữ lại tới khi người dùng Gộp
    // hoặc Đổi tên. Luật: `wallet/domain/vi_trung_ten.dart`; spec 2026-10-05
    // mục 4.4.
    //
    // Ví mang cờ mà không còn cặp (ví kia bị xoá / đổi tên ở máy khác) thì THẢ
    // trước khi đọc hàng chờ: gỡ cờ + mốc chặn, làm mới giờ sửa của nó và bản
    // ghi từng bị giữ. Lý do gốc (nghiệm thu 2026-10-05): khi mốc kéo về còn
    // theo giờ ghi của máy, giờ ghi cũ nằm dưới mốc của máy khác và không bao giờ
    // được kéo. Từ G67 (2026-10-08) mốc theo giờ-server nên ca ấy đã hết; việc
    // làm mới giờ sửa vẫn giữ — với server chưa có `maxSince` nó vẫn cần.
    await _viBiGiu.thaViKhongConCap(idaccount);
    final pendingGoals = await _db.goalDao.getPending(idaccount);
    final pendingBills = await _db.billDao.getPending(idaccount);
    final pendingTx = await _db.transactionDao.getPending(idaccount);
    final giu = await _viBiGiu.banGhiGiuKhoiDay(
      idaccount,
      hoaDon: pendingBills,
      mucTieu: pendingGoals,
      giaoDich: pendingTx,
    );

    // ── 1. Categories (phải đứng TRƯỚC transactions/budgets/bills) ────────────
    // Transaction.idcategory, Budget.idcategory, Bill.idcategory đều FK → category
    // Nếu categories push sau thì backend báo FK constraint violation.
    final syncableCategories =
        await _db.categoryDao.getSyncableCategories(idaccount);
    // Nạp từ khoá MỘT lần cho cả lô. `getKeywords` trong vòng lặp sinh một
    // truy vấn cho mỗi danh mục, mà vòng này chạy ở MỌI chu kỳ đẩy.
    final tuKhoaTheoDanhMuc = await _db.categoryDao.getAllKeywords(idaccount);
    // Nhóm phải được đẩy TRƯỚC danh mục con của nó: backend có khoá ngoại
    // fk_category_parent (Idgroup → Idcategory), con đi trước sẽ vi phạm FK.
    syncableCategories.sort((a, b) {
      if (a.isGroup == b.isGroup) return 0;
      return a.isGroup ? -1 : 1;
    });
    for (final c in syncableCategories) {
      if (_isSyncBlocked(c.syncBlockedUntil)) continue;
      final validId = toValidUuid(c.id);
      String validClassify = c.classify;
      if (validClassify == 'vay_no' || validClassify == 'vay-no') {
        validClassify = 'vay/no';
      }
      ops.add(SyncOperation(
        localId: c.id,
        entity: SyncEntityType.category,
        operation:
            c.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': c.name,
          'namecategory': c.name,
          'classify': validClassify,
          'icon': c.icon,
          'colour': c.colour,
          'is_default': c.isDefault,
          'is_deleted': c.isDeleted,
          // Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy trên chính
          // hàng `category` (cột `Keyword`, `@db.Text`), và `/sync/push` đã
          // nhận nó ở cả nhánh tạo lẫn nhánh cập nhật.
          //
          // ⚠️ Chỉ gửi khi CÓ từ khoá. Chuỗi rỗng là lệnh XOÁ: backend cũng tự
          // học từ khoá qua `recordFeedback()` → `appendCategoryKeyword()`, nên
          // một chuỗi rỗng từ client quét sạch thứ server vừa học được.
          if ((tuKhoaTheoDanhMuc[c.id] ?? const <String>[]).isNotEmpty)
            'keyword': tuKhoaTheoDanhMuc[c.id]!.join(','),
          // Cấu trúc nhóm — backend mapEntityFields() nhận camelCase:
          // isGroup → Is_group, parentId → Idgroup.
          'isGroup': c.isGroup,
          'parentId': c.parentId != null ? toValidUuid(c.parentId!) : null,
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
          'idaccount': c.idaccount > 0 ? c.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 2. Wallets (phải đứng TRƯỚC transactions/bills/goals) ─────────────────
    // Transaction.idwallet, Bill.idwallet, Goal.idwallet đều FK → wallet
    final pendingWallets = await _db.walletDao.getPending(idaccount);
    for (final w in pendingWallets) {
      if (_isSyncBlocked(w.syncBlockedUntil)) continue;
      if (giu.vi.contains(w.id)) continue;
      final validId = toValidUuid(w.id);
      ops.add(SyncOperation(
        localId: w.id,
        entity: SyncEntityType.wallet,
        operation:
            w.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': w.name,
          'type': w.type,
          'balance': w.balance,
          'currency': w.currency,
          'icon': w.icon,
          'colour': w.colour,
          'is_default': w.isDefault,
          'is_deleted': w.isDeleted,
          'include_in_total': w.includeInTotal,
          // Chuỗi thô của SQLite ('active'/'inactive'); `walletForPush` dịch
          // sang từ vựng của server. Engine dựng payload thô, normalizer là
          // tầng hợp đồng — cùng khuôn `type` ngay trên. (G28, 2026-09-14.)
          'status': w.status,
          'updated_at': w.updatedAt.toUtc().toIso8601String(),
          'idaccount': w.idaccount > 0 ? w.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 1b. Bổ sung categories mà pending transactions tham chiếu ────────────
    // Chỉ bổ sung USER category (idaccount == currentIdaccount) chưa có trên backend.
    // KHÔNG bổ sung default/global categories (idaccount == 0) — backend đã có sẵn.
    final currentAccount = _taiKhoanPhien() ?? idaccount;
    final alreadyInBatch = ops.map((o) => o.localId).toSet();
    final pendingTxForCatCheck = await _db.transactionDao.getPending(idaccount);
    for (final t in pendingTxForCatCheck) {
      if (t.categoryId == null) continue;
      // G63: giao dịch bị giữ không lên lô, nên danh mục của nó cũng không cần
      // đi kèm. Thiếu dòng này là vòng đồng bộ NÓNG (nghiệm thu 2026-10-05):
      // giao dịch bị giữ nằm `pending` vô thời hạn → danh mục bị gửi lại ở mọi
      // chu kỳ → xung đột (không lỗi, nên không giãn cách) → server phát
      // `sync.completed` về chính máy này → `syncNow` → chạy bù → đẩy lại.
      if (giu.giaoDich.contains(t.id)) continue;
      final resolvedId = await resolveCategoryId(_db, t.categoryId);
      if (resolvedId == null) continue;
      if (alreadyInBatch.contains(resolvedId)) continue;
      final cat = await _db.categoryDao.getById(resolvedId);
      if (cat == null) continue;
      if (_isSyncBlocked(cat.syncBlockedUntil)) continue;
      // Chỉ push category thuộc user hiện tại — bỏ qua global/default (idaccount=0)
      if (cat.idaccount != currentAccount) continue;
      // Thêm category này vào batch để đảm bảo nó tồn tại trên backend
      String validClassify = cat.classify;
      if (validClassify == 'vay_no' || validClassify == 'vay-no') {
        validClassify = 'vay/no';
      }
      ops.add(SyncOperation(
        localId: cat.id,
        entity: SyncEntityType.category,
        operation: cat.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': toValidUuid(cat.id),
          'name': cat.name,
          'namecategory': cat.name,
          'classify': validClassify,
          'icon': cat.icon,
          'colour': cat.colour,
          'is_default': cat.isDefault,
          'is_deleted': cat.isDeleted,
          // Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy trên chính
          // hàng `category` (cột `Keyword`, `@db.Text`), và `/sync/push` đã
          // nhận nó ở cả nhánh tạo lẫn nhánh cập nhật.
          //
          // ⚠️ Chỉ gửi khi CÓ từ khoá. Chuỗi rỗng là lệnh XOÁ: backend cũng tự
          // học từ khoá qua `recordFeedback()` → `appendCategoryKeyword()`, nên
          // một chuỗi rỗng từ client quét sạch thứ server vừa học được.
          if ((tuKhoaTheoDanhMuc[cat.id] ?? const <String>[]).isNotEmpty)
            'keyword': tuKhoaTheoDanhMuc[cat.id]!.join(','),
          'isGroup': cat.isGroup,
          'parentId':
              cat.parentId != null ? toValidUuid(cat.parentId!) : null,
          'updated_at': cat.updatedAt.toUtc().toIso8601String(),
          'idaccount': currentAccount,
        },
        createdAt: now,
      ));
      alreadyInBatch.add(resolvedId);
    }

    // ── 3. Goals (sau wallet, và phải đứng TRƯỚC transactions) ───────────────
    //
    // Từ 2026-09-07 payload giao dịch mang `idgoal`, và cột ấy phía server có
    // khoá ngoại `fk_transaction_goal`. Đẩy giao dịch trước mục tiêu thì hàng bị
    // từ chối vì mục tiêu chưa tồn tại — đúng ca người dùng tạo mục tiêu rồi nạp
    // tiền trong lúc offline, cả hai cùng nằm chờ trong một lô. Cùng lý do khiến
    // categories phải đứng trước transactions. Có test canh thứ tự này.
    for (final g in pendingGoals) {
      if (_isSyncBlocked(g.syncBlockedUntil)) continue;
      if (giu.mucTieu.contains(g.id)) continue;
      final validId = toValidUuid(g.id);
      ops.add(SyncOperation(
        localId: g.id,
        entity: SyncEntityType.goal,
        operation:
            g.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'name': g.name,
          'target_amount': g.targetAmount,
          'current_amount': g.currentAmount,
          'start_date': g.startDate?.toUtc().toIso8601String(),
          'target_date': g.targetDate.toUtc().toIso8601String(),
          'idwallet': g.walletId != null ? toValidUuid(g.walletId!) : null,
          'cycle_take_money': g.cycleTakeMoney,
          'time_cycle_take_money':
              g.timeCycleTakeMoney?.toUtc().toIso8601String(),
          // Ba cột trích tự động đi CÙNG NHAU (G21, mở khoá 2026-09-07).
          // `auto_deposit_last_run` là cột chặn trích hai lần: bỏ nó lại thì
          // mỗi máy giữ một mốc riêng và cả hai cùng chuyển tiền khi tới kỳ —
          // hỏng nặng hơn hiện trạng "máy thứ hai không trích gì".
          'auto_deposit_amount': g.autoDepositAmount,
          'auto_deposit_wallet_id': g.autoDepositWalletId != null
              ? toValidUuid(g.autoDepositWalletId!)
              : null,
          'auto_deposit_last_run':
              g.autoDepositLastRun?.toUtc().toIso8601String(),
          // Thứ tự ưu tiên (2026-09-08). Cột `Priority` phía backend có từ
          // 2026-09-07. Đây là thứ tự người dùng tự sắp bằng thao tác kéo
          // thả — công sức bỏ ra, KHÔNG suy lại được, và không có mặc định
          // đúng nào — nên nó phải đi qua đường đồng bộ chứ không được làm
          // cột cục bộ như `auto_deposit_*` từng làm (G21).
          // `<= 0` về máy từ `Number(null)` của backend trước `7675b35` (G32).
          // Đẩy lại là giữ cái sai ấy trên server; gửi `null` để hàng tự lành —
          // backend nay giữ `null` khi đẩy (đo 2026-09-11).
          'priority': uuTienHopLe(g.priority),
          'status_complete': g.isCompleted ? 'True' : 'False',
          'recurrence': g.recurrence,
          'time_recurrence': g.timeRecurrence,
          'icon': g.icon,
          'color': g.colour,
          'note': g.note,
          'is_deleted': g.isDeleted,
          'updated_at': g.updatedAt.toUtc().toIso8601String(),
          'idaccount': g.idaccount > 0 ? g.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 4. Bills (sau category + wallet, và phải đứng TRƯỚC transactions) ────
    // idwallet/idcategory là NOT NULL trên backend — bắt buộc phải gửi kèm.
    // Lưu ý: form tạo/sửa bill hiện tại (bill_edit_page.dart) chưa cho chọn
    // ví/danh mục nên các giá trị này có thể vẫn null cho tới khi UI đó được
    // bổ sung — đây là việc ngoài phạm vi sync engine.
    for (final bill in pendingBills) {
      if (_isSyncBlocked(bill.syncBlockedUntil)) continue;
      if (giu.hoaDon.contains(bill.id)) continue;
      final validId = toValidUuid(bill.id);
      final validWalletId =
          bill.walletId != null ? toValidUuid(bill.walletId!) : null;
      final validCategoryId =
          bill.categoryId != null ? toValidUuid(bill.categoryId!) : null;
      ops.add(SyncOperation(
        localId: bill.id,
        entity: SyncEntityType.bill,
        operation: bill.isDeleted
            ? SyncOperationType.delete
            : SyncOperationType.update,
        payload: {
          'id': validId,
          'idwallet': validWalletId,
          'idcategory': validCategoryId,
          'name': bill.name,
          'amount': bill.amount,
          'start_date': bill.startDate?.toUtc().toIso8601String(),
          'due_date': bill.dueDate.toUtc().toIso8601String(),
          'pay_status': bill.payStatus,
          'recurrence': bill.isRecurrence,
          'time_recurrence': bill.timeRecurrence,
          'time_notification': bill.timeNotification,
          'icon': bill.icon,
          'color': bill.colour,
          'note': bill.note,
          // Chuỗi kỳ và ngày gốc — mở đường đồng bộ 2026-09-12. Hai cột này
          // client đã có từ v16/v18 nhưng chưa gửi, nên chuỗi kỳ của hoá đơn
          // lặp chết ở ranh giới một máy: máy khác nhận từng kỳ như một hoá
          // đơn mồ côi và phải suy ngày đến hạn bằng cách đoán.
          'previous_bill_id': bill.generatedFromBillId,
          'anchor_day': bill.anchorDay,
          // Ân hạn hoá đơn (2026-09-12, schema v21): ngày kết thúc kỳ tách
          // khỏi hạn trả. Cột server là @db.Date (KHÔNG giờ), khác
          // `due_date` (@db.Timestamp): gửi `toUtc()` thô của một mốc 03:00
          // giờ +07 là 20:00 UTC hôm TRƯỚC và server lưu lùi một ngày — im
          // lặng. Nên gửi nửa đêm UTC của NGÀY CỤC BỘ. Đo thật 2026-09-12.
          'period_end': _ngayCucBoUtcIso(bill.periodEnd),
          // Công tắc tự động trả — mở đường đồng bộ 2026-09-13 (bước 12). Cột
          // `bills.autoPayEnabled` có từ v17 và tới 2026-09-13 vẫn là cột
          // CỤC BỘ: bật trên máy A thì máy B không biết, và người dùng phải tự
          // nhớ bật lại ở từng máy.
          //
          // Mở được vì backend đã đặt chốt chống trả hai lần ở
          // `upsertTransaction` (`chanTraHaiLan`, CAN-LAM 20 §2.1, có từ
          // `7779999`): hai máy cùng bật thì chỉ khoản chi đầu tiên được nhận,
          // khoản thứ hai bị từ chối bằng `BILL_ALREADY_PAID` và
          // `BillPaymentConflictResolver` gỡ nó ở máy thua.
          //
          // Phải là `bool` THẬT: gửi chuỗi `'true'` thì backend đọc thành NULL
          // và bỏ qua trong im lặng — quy tắc 4 `CLAUDE.md`.
          'auto_pay': bill.autoPayEnabled,
          'is_deleted': bill.isDeleted,
          'updated_at': bill.updatedAt.toUtc().toIso8601String(),
          'idaccount':
              bill.idaccount > 0 ? bill.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 5. Transactions (sau category + wallet + goal + bill vì FK → cả 4) ───
    // `pendingTx` đọc ở mục 0 — trước mọi lần ghi, cùng ảnh chụp với phép giữ.
    for (final t in pendingTx) {
      if (_isSyncBlocked(t.syncBlockedUntil)) continue;
      if (giu.giaoDich.contains(t.id)) continue;
      final validId = toValidUuid(t.id);
      final validWalletId = toValidUuid(t.walletId);
      // Khoản chuyển ví không có danh mục — payload bỏ `categoryId` cho loại
      // này (xem `transactionForPush`) — nên KHÔNG hoãn nó vì danh mục. Bản
      // app trước 2026-09-05 từng gán `'cat_transfer'` (id không có thật) cho
      // mọi khoản chuyển; giữ nhánh hoãn ở đây là những hàng ấy nằm lại máy
      // vĩnh viễn trong khi số dư hai ví vẫn lên server.
      final isTransfer = t.type == 'transfer';
      final validCategoryId =
          isTransfer ? null : await resolveCategoryId(_db, t.categoryId);
      if (!isTransfer && t.categoryId != null && validCategoryId == null) {
        debugPrint(
          '[SyncEngine] Deferring transaction ${t.id}: '
          'category ${t.categoryId} is not available on backend yet.',
        );
        continue;
      }
      ops.add(SyncOperation(
        localId: t.id,
        entity: SyncEntityType.transaction,
        operation:
            t.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'wallet_id': validWalletId,
          'category_id': validCategoryId,
          // Ví đích khi type = 'transfer' — backend đọc trực tiếp
          // `idwallet_transfer` (bỏ qua nếu không phải giao dịch chuyển khoản).
          'idwallet_transfer':
              t.walletTransfer != null ? toValidUuid(t.walletTransfer!) : null,
          'idgoal': t.goalId != null ? toValidUuid(t.goalId!) : null,
          // Khoá nối tới hoá đơn — mở đường đồng bộ 2026-09-12, cùng khuôn
          // `idgoal` ngay trên. Không có nó thì máy khác không lần được từ hoá
          // đơn ngược về đúng khoản chi nó sinh ra, và hoàn tác thanh toán phải
          // từ chối. Hoá đơn được đẩy ở mục 4, TRƯỚC đây, vì cột này có khoá
          // ngoại `fk_transaction_bill`.
          'idbill': t.billId != null ? toValidUuid(t.billId!) : null,
          'amount': t.amount,
          'type': t.type,
          'note': t.note,
          'date': t.date.toUtc().toIso8601String(),
          'is_deleted': t.isDeleted,
          'updated_at': t.updatedAt.toUtc().toIso8601String(),
          'idaccount': t.idaccount > 0 ? t.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }

    // ── 6. Budgets (sau category + wallet) ────────────────────────────────────
    // Payload dùng đúng tên field Prisma của backend (idcategory, total_amount,
    // start, over_spending, ...) vì backend mapEntityFields() chỉ nhận diện
    // các key camelCase cụ thể (totalAmount, categoryId, ...) — gửi sẵn tên
    // snake_case cuối cùng để tránh lệ thuộc vào việc mapper có khớp hay không.
    for (final b in await _db.budgetDao.getPending(idaccount)) {
      if (_isSyncBlocked(b.syncBlockedUntil)) continue;
      final validId = toValidUuid(b.id);
      final validCatId =
          b.categoryId != null ? toValidUuid(b.categoryId!) : null;
      ops.add(SyncOperation(
        localId: b.id,
        entity: SyncEntityType.budget,
        operation:
            b.isDeleted ? SyncOperationType.delete : SyncOperationType.update,
        payload: {
          'id': validId,
          'idcategory': validCatId,
          'total_amount': b.amount,
          'spent': b.spent,
          'threshold_warning_amount': b.thresholdWarningAmount,
          'threshold_warning_percent': b.thresholdWarningPercent,
          'over_spending': b.overSpending,
          'over_amount': b.overAmount,
          'start': b.startDate.toUtc().toIso8601String(),
          'end': b.endDate?.toUtc().toIso8601String(),
          'recurrence': b.recurrence,
          'time_recurrence': b.timeRecurrence,
          'nexttime_recurrence':
              b.nextTimeRecurrence?.toUtc().toIso8601String(),
          'note': b.note,
          'is_deleted': b.isDeleted,
          'updated_at': b.updatedAt.toUtc().toIso8601String(),
          'idaccount': b.idaccount > 0 ? b.idaccount : idaccount,
        },
        createdAt: now,
      ));
    }



    return ops;
  }
}
